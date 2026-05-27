#!/usr/bin/env python3
import argparse
import struct
import socket
import sys
import time
from datetime import datetime

# --- Modbus Exception Codes ---
MODBUS_EXCEPTIONS = {
    1:  "Illegal Function",
    2:  "Illegal Data Address",
    3:  "Illegal Data Value",
    4:  "Slave Device Failure and/or bad request",
    5:  "Acknowledge",
    6:  "Slave Device Busy",
    8:  "Memory Parity Error",
    10: "Gateway Path Unavailable",
    11: "Gateway Target Device Failed to Respond"
}


# =============================================================================
# Logger
# =============================================================================

class Logger:
    """Centralised output handler: stdout + optional file, with timestamps."""

    def __init__(self, enable_timestamp=False, quiet=False, log_path=None):
        self.enable_timestamp = enable_timestamp
        self.quiet = quiet
        self._fh = None

        if log_path:
            try:
                self._fh = open(log_path, 'a', encoding='utf-8')
            except Exception as e:
                print(f'[!] Failed to open log file {log_path}: {e}')

    def print(self, *args, **kwargs):
        sep = kwargs.get('sep', ' ')
        end = kwargs.get('end', '\n')
        body = sep.join(str(a) for a in args)

        if self.enable_timestamp:
            ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            msg = f"[{ts}] {body}{end}"
        else:
            msg = f"{body}{end}"

        if not self.quiet:
            sys.stdout.write(msg)
            sys.stdout.flush()

        if self._fh is not None:
            self._fh.write(msg)
            self._fh.flush()

    def close(self):
        if self._fh is not None:
            self._fh.close()
            self._fh = None


# =============================================================================
# Helpers
# =============================================================================

def printable_ascii(byte_data):
    return ''.join(chr(b) if 32 <= b <= 126 else '.' for b in byte_data)


def hexdump(byte_data):
    return ' '.join(f'{b:02X}' for b in byte_data)


def function_name(fc):
    return {
        1: "Read Coils",
        2: "Read Discrete Inputs",
        3: "Read Holding Registers",
        4: "Read Input Registers"
    }.get(fc, "Unknown")


def reorder_bytes_for_format(r0, r1, fmt):
    """Return a 4-byte sequence for the given 32-bit word-order format."""
    A = (r0 >> 8) & 0xFF
    B =  r0       & 0xFF
    C = (r1 >> 8) & 0xFF
    D =  r1       & 0xFF
    return {
        "abcd": bytes([A, B, C, D]),
        "cdab": bytes([C, D, A, B]),
        "badc": bytes([B, A, D, C]),
        "dcba": bytes([D, C, B, A]),
    }[fmt]


def reorder_bytes_for_format_64(r0, r1, r2, r3, fmt):
    """
    Return an 8-byte sequence for the given 64-bit word-order format.
    Formats mirror the 32-bit naming convention, extended to 4 words:
      abcdefgh - Big Endian standard        : r0_hi r0_lo r1_hi r1_lo r2_hi r2_lo r3_hi r3_lo
      ghefcdab - Big Endian word-swap       : r3_hi r3_lo r2_hi r2_lo r1_hi r1_lo r0_hi r0_lo
      badcfehg - Little Endian byte-swap    : byte-swap inside each 16-bit word
      hgfedcba - Little Endian full reverse : full byte reversal
    """
    words = []
    for r in (r0, r1, r2, r3):
        words.append((r >> 8) & 0xFF)
        words.append(r & 0xFF)
    A, B, C, D, E, F, G, H = words
    return {
        "abcdefgh": bytes([A, B, C, D, E, F, G, H]),
        "ghefcdab": bytes([G, H, E, F, C, D, A, B]),
        "badcfehg": bytes([B, A, D, C, F, E, H, G]),
        "hgfedcba": bytes([H, G, F, E, D, C, B, A]),
    }[fmt]


def decode_bcd_register(reg):
    """
    Decode a 16-bit register as packed BCD (4 nibbles = 4 decimal digits).
    Returns the integer value if all nibbles are valid (0-9), else None.
    Example: 0x1234 -> 1234
    """
    result = 0
    for shift in (12, 8, 4, 0):
        nibble = (reg >> shift) & 0xF
        if nibble > 9:
            return None
        result = result * 10 + nibble
    return result


def decode_ipv4_from_two_registers(r0, r1):
    """
    Interpret two consecutive 16-bit registers as a packed IPv4 address.
    Each register holds 2 octets: hi byte = first octet, lo byte = second.
    Example: r0=0xC0A8, r1=0x0101 -> 192.168.1.1
    """
    o1 = (r0 >> 8) & 0xFF
    o2 =  r0       & 0xFF
    o3 = (r1 >> 8) & 0xFF
    o4 =  r1       & 0xFF
    return f"{o1}.{o2}.{o3}.{o4}"


# Epoch plausibility window: 2000-01-01 to 2100-01-01 in Unix seconds
_EPOCH_MIN = 946684800
_EPOCH_MAX = 4102444800

def decode_epoch(value):
    """
    If value falls within a plausible Unix epoch range (year 2000-2100),
    return a formatted datetime string, else return None.
    """
    if _EPOCH_MIN <= value <= _EPOCH_MAX:
        try:
            return datetime.utcfromtimestamp(value).strftime("%Y-%m-%d %H:%M:%S UTC")
        except Exception:
            return None
    return None


# =============================================================================
# Modbus framing
# =============================================================================

def build_modbus_request(transaction_id, unit_id, function_code, register, count):
    pdu  = struct.pack(">BHH", function_code, register, count)
    mbap = struct.pack(">HHHB", transaction_id, 0x0000, len(pdu) + 1, unit_id)
    return mbap + pdu


def recv_modbus_response(sock):
    """
    Length-aware receive: read the 7-byte MBAP header first, then read
    exactly as many additional bytes as the Length field says (minus the
    1-byte Unit ID that is already counted inside Length).

    This prevents silent truncation on slow or fragmented TCP paths.
    """
    # --- MBAP header (7 bytes) ---
    header = b''
    while len(header) < 7:
        chunk = sock.recv(7 - len(header))
        if not chunk:
            raise ConnectionError("Connection closed while reading MBAP header")
        header += chunk

    # Length field = Unit ID (1 byte) + PDU bytes.
    # Unit ID is already included in the 7-byte header we just read,
    # so we only need (pdu_length - 1) more bytes for the PDU itself.
    pdu_length = struct.unpack(">H", header[4:6])[0]
    remaining  = pdu_length - 1   # subtract the Unit ID already read

    body = b''
    while len(body) < remaining:
        chunk = sock.recv(remaining - len(body))
        if not chunk:
            raise ConnectionError("Connection closed while reading PDU")
        body += chunk

    return header + body


def send_modbus_request(ip, port, frame, retries, timeout, logger):
    """
    Open a TCP connection, send *frame*, receive the response.
    Retries up to *retries* times on any socket/IO error.
    Returns the raw response bytes, or raises on total failure.
    """
    last_exc = None
    for attempt in range(1, retries + 1):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(timeout)
            s.connect((ip, port))
            s.sendall(frame)
            resp = recv_modbus_response(s)
            s.close()
            return resp
        except Exception as e:
            last_exc = e
            logger.print(f'[!] Attempt {attempt}/{retries} failed: {e}')
            if attempt < retries:
                time.sleep(1)
    raise last_exc


# =============================================================================
# Response parsing
# =============================================================================

def parse_modbus_response(resp, logger):
    if resp is None or len(resp) < 7:
        logger.print("[!] Error: Response too short to contain MBAP header")
        return None

    pdu = resp[7:]
    if len(pdu) < 1:
        logger.print("[!] Error: Response contains no PDU")
        return None

    function_code = pdu[0]

    # Exception frame
    if function_code & 0x80:
        if len(pdu) < 2:
            logger.print("[!] Error: Exception frame missing exception code")
            return None
        exc_code = pdu[1]
        explanation = MODBUS_EXCEPTIONS.get(exc_code, "Unknown Exception")
        logger.print("\n[!] Modbus Exception Received")
        logger.print(f"    Function      : {function_code & 0x7F:02X}")
        logger.print(f"    Exception Code: {exc_code} ({explanation})")
        return None

    # Normal response
    if len(pdu) < 2:
        logger.print("[!] Error: Normal response missing byte count")
        return None

    byte_count = pdu[1]
    if len(pdu) < 2 + byte_count:
        logger.print("[!] Error: Response shorter than byte count indicates")
        return None

    data = pdu[2:2 + byte_count]

    registers = []
    for i in range(0, byte_count, 2):
        if i + 1 >= len(data):
            logger.print("[!] Error: Odd number of bytes in register data")
            return None
        registers.append(struct.unpack(">H", data[i:i+2])[0])

    return function_code, byte_count, registers, data


# =============================================================================
# Raw frame display
# =============================================================================

def show_raw_frames(slave, register, count, function_code,
                    request_frame, response_frame, verbose, logger):

    is_exception = (
        response_frame is not None and
        len(response_frame) >= 8 and
        (response_frame[7] & 0x80)
    )

    logger.print('\n=== Raw Modbus TCP Query ===')
    logger.print(f'MBAP + PDU HEX : {hexdump(request_frame)}')

    if verbose and not is_exception:
        logger.print('Breakdown:')
        logger.print(f'  Transaction ID : {request_frame[0]:02X}{request_frame[1]:02X}')
        logger.print(f'  Protocol ID    : {request_frame[2]:02X}{request_frame[3]:02X}')
        logger.print(f'  Length         : {request_frame[4]:02X}{request_frame[5]:02X}')
        logger.print(f'  Unit ID        : {slave:02X}')
        logger.print(f'  Function Code  : {function_code:02X}')
        logger.print(f'  Start Register : {register} (0x{register:04X})')
        logger.print(f'  Register Count : {count} (0x{count:04X})')

    logger.print('\n=== Raw Modbus TCP Response ===')
    if response_frame is None:
        logger.print('No response received')
        return

    logger.print(f'MBAP + PDU HEX : {hexdump(response_frame)}')

    if is_exception:
        return

    if verbose:
        fc         = response_frame[7]
        byte_count = response_frame[8]
        pdu        = response_frame[7:]
        data_bytes = response_frame[9:]

        logger.print('Breakdown:')
        logger.print(f'  Transaction ID : {response_frame[0]:02X}{response_frame[1]:02X}')
        logger.print(f'  Protocol ID    : {response_frame[2]:02X}{response_frame[3]:02X}')
        logger.print(f'  Length         : {response_frame[4]:02X}{response_frame[5]:02X}')
        logger.print(f'  Unit ID        : {slave:02X}')
        logger.print(f'  Function Code  : {fc:02X}')
        logger.print(f'  Byte Count     : {byte_count} (0x{byte_count:02X})')
        logger.print(f'  PDU HEX        : {hexdump(pdu)}')
        logger.print(f'  PDU DATA HEX   : {hexdump(data_bytes)}')

        if any(32 <= b <= 126 for b in data_bytes):
            logger.print(f'  PDU DATA ASCII : {printable_ascii(data_bytes)}')
        else:
            logger.print('  PDU DATA ASCII : <non-printable>')


# =============================================================================
# Register decode helpers
# =============================================================================

def decode_register_16bit(idx, reg, startreg, logger):
    """Print the full 16-bit breakdown for a single register."""
    uint16    = reg
    int16     = reg if reg < 0x8000 else reg - 0x10000
    reg_bytes = struct.pack('>H', reg)
    hi        = (reg >> 8) & 0xFF
    lo        =  reg       & 0xFF
    real_reg  = startreg + idx

    logger.print(f'\n--- Register {real_reg} ---')
    logger.print(f'UINT16         : {uint16}')
    logger.print(f'INT16          : {int16}')
    logger.print(f'HEX            : 0x{reg:04X}')
    logger.print(f'BIN            : {reg:016b}')
    logger.print(f'ASCII          : {printable_ascii(reg_bytes)}')
    logger.print(f'8-bit HI/LO    : {hi}  {lo}')

    # BCD decode (per individual register)
    bcd_val = decode_bcd_register(reg)
    if bcd_val is not None:
        logger.print(f'BCD            : {bcd_val}')
    else:
        logger.print(f'BCD            : <invalid - contains non-BCD nibble>')


def decode_32bit_block(r0, r1, real_reg1, real_reg2, floatformat, logger):
    """Print float32, uint32, int32, IPv4, epoch, hex and ASCII for one register pair."""
    float_formats = ["abcd", "cdab", "badc", "dcba"]
    formats_to_run = float_formats if floatformat == "auto" else [floatformat]

    logger.print(f"\n--- 32-bit block for registers {real_reg1}–{real_reg2} ---")

    # FLOAT32
    if floatformat == "auto":
        logger.print("Float32 AUTO mode (all formats):")
    for fmt in formats_to_run:
        try:
            b   = reorder_bytes_for_format(r0, r1, fmt)
            val = struct.unpack(">f", b)[0]
            logger.print(f'FLOAT32 {fmt.upper():4s} : {val}')
        except Exception:
            logger.print(f'FLOAT32 {fmt.upper():4s} : <invalid>')

    # INTEGER
    logger.print("\nInteger 32-bit interpretations:")
    for fmt in formats_to_run:
        try:
            b   = reorder_bytes_for_format(r0, r1, fmt)
            u   = struct.unpack(">I", b)[0]
            i32 = struct.unpack(">i", b)[0]
            logger.print(f'UINT32 {fmt.upper():4s} : {u}')
            logger.print(f'INT32  {fmt.upper():4s} : {i32}')
        except Exception:
            logger.print(f'UINT32 {fmt.upper():4s} : <invalid>')
            logger.print(f'INT32  {fmt.upper():4s} : <invalid>')

    # IPv4 decode (ABCD only - canonical byte order for packed IPs)
    ipv4_str = decode_ipv4_from_two_registers(r0, r1)
    logger.print(f"\nIPv4 (ABCD hi/lo each reg)         : {ipv4_str}")

    # Unix epoch -> datetime (check all 32-bit format interpretations)
    logger.print("\nUnix epoch interpretations (if plausible):")
    epoch_found = False
    for fmt in formats_to_run:
        try:
            b = reorder_bytes_for_format(r0, r1, fmt)
            u = struct.unpack(">I", b)[0]
            dt = decode_epoch(u)
            if dt:
                logger.print(f'  EPOCH {fmt.upper():4s} : {u} -> {dt}')
                epoch_found = True
        except Exception:
            pass
    if not epoch_found:
        logger.print(f'  (no format yields a plausible epoch in 2000-2100)')

    # HEX + ASCII
    logger.print("\nHEX / ASCII representations:")
    for fmt in formats_to_run:
        b = reorder_bytes_for_format(r0, r1, fmt)
        logger.print(f'HEX   {fmt.upper():4s} : {hexdump(b)}')
        logger.print(f'ASCII {fmt.upper():4s} : {printable_ascii(b)}')


def decode_64bit_block(r0, r1, r2, r3, real_reg0, real_reg3, floatformat, logger):
    """
    Print float64 (double), int64, uint64 and epoch interpretations
    for a group of four consecutive registers.
    """
    fmt64_all  = ["abcdefgh", "ghefcdab", "badcfehg", "hgfedcba"]
    # Map 32-bit floatformat selection to the 64-bit equivalent
    fmt64_map  = {
        "abcd": "abcdefgh",
        "cdab": "ghefcdab",
        "badc": "badcfehg",
        "dcba": "hgfedcba",
        "auto": "auto"
    }
    fmt64_sel  = fmt64_map.get(floatformat, "auto")
    fmts_to_run = fmt64_all if fmt64_sel == "auto" else [fmt64_sel]

    logger.print(f"\n--- 64-bit block for registers {real_reg0}–{real_reg3} ---")

    # FLOAT64 (double precision)
    if fmt64_sel == "auto":
        logger.print("Float64 (double) AUTO mode (all formats):")
    for fmt in fmts_to_run:
        try:
            b   = reorder_bytes_for_format_64(r0, r1, r2, r3, fmt)
            val = struct.unpack(">d", b)[0]
            logger.print(f'FLOAT64 {fmt.upper()} : {val}')
        except Exception:
            logger.print(f'FLOAT64 {fmt.upper()} : <invalid>')

    # INT64 / UINT64
    logger.print("\nInteger 64-bit interpretations:")
    for fmt in fmts_to_run:
        try:
            b    = reorder_bytes_for_format_64(r0, r1, r2, r3, fmt)
            u64  = struct.unpack(">Q", b)[0]
            i64  = struct.unpack(">q", b)[0]
            logger.print(f'UINT64 {fmt.upper()} : {u64}')
            logger.print(f'INT64  {fmt.upper()} : {i64}')
        except Exception:
            logger.print(f'UINT64 {fmt.upper()} : <invalid>')
            logger.print(f'INT64  {fmt.upper()} : <invalid>')

    # Unix epoch as 64-bit (millisecond epoch common in Java/industrial systems)
    logger.print("\nUnix epoch 64-bit interpretations (if plausible):")
    epoch_found = False
    for fmt in fmts_to_run:
        try:
            b   = reorder_bytes_for_format_64(r0, r1, r2, r3, fmt)
            u64 = struct.unpack(">Q", b)[0]
            # Try as seconds
            dt_sec = decode_epoch(u64)
            if dt_sec:
                logger.print(f'  EPOCH-sec  {fmt.upper()} : {u64} -> {dt_sec}')
                epoch_found = True
            # Try as milliseconds (divide by 1000)
            u64_ms = u64 // 1000
            dt_ms = decode_epoch(u64_ms)
            if dt_ms and u64_ms != u64:
                logger.print(f'  EPOCH-ms   {fmt.upper()} : {u64} -> {dt_ms} (as milliseconds)')
                epoch_found = True
        except Exception:
            pass
    if not epoch_found:
        logger.print(f'  (no format yields a plausible epoch in 2000-2100)')


def decode_multi_register_summary(regs, logger):
    """Print the combined multi-register hex / ASCII / UTF views."""
    all_bytes = b''.join(struct.pack('>H', r) for r in regs)

    # ABCD raw
    logger.print("\nFull HEX (all registers ABCD)      : " + hexdump(all_bytes))

    # CDAB — swap 16-bit words within each 32-bit pair
    cdab = bytearray()
    for i in range(0, len(all_bytes), 4):
        if i + 3 < len(all_bytes):
            cdab.extend(all_bytes[i+2:i+4])
            cdab.extend(all_bytes[i:i+2])
    logger.print("Full HEX (pairs CDAB)              : " + hexdump(cdab))

    # BADC — byte-swap inside each 16-bit word
    badc = bytearray()
    for i in range(0, len(all_bytes), 2):
        badc.append(all_bytes[i+1])
        badc.append(all_bytes[i])
    logger.print("Full HEX (pairs - byte swap BADC)  : " + hexdump(badc))

    # DCBA per 32-bit pair
    dcba_pairs = bytearray()
    for i in range(0, len(all_bytes), 4):
        if i + 3 < len(all_bytes):
            dcba_pairs.append(all_bytes[i+3])
            dcba_pairs.append(all_bytes[i+2])
            dcba_pairs.append(all_bytes[i+1])
            dcba_pairs.append(all_bytes[i])
    logger.print("Full HEX (pairs DCBA)              : " + hexdump(dcba_pairs))

    # Full reverse
    logger.print("Full HEX (all registers DCBA)      : " + hexdump(all_bytes[::-1]))

    # 8-bit unsigned
    logger.print("8-bit unsigned integers ABCD       : " +
                 " ".join(str(b) for b in all_bytes))

    # ASCII
    if any(32 <= b <= 126 for b in all_bytes):
        logger.print("Full ASCII (all registers ABCD)    : " + printable_ascii(all_bytes))
    else:
        logger.print("Full ASCII (all registers ABCD)    : <non-printable>")

    # UTF-16 BE
    try:
        logger.print("Full UTF16-BE (all registers ABCD) : " +
                     all_bytes.decode('utf-16-be', errors='replace'))
    except Exception:
        logger.print("Full UTF16-BE (all registers ABCD) : <decode error>")

    # UTF-16 LE
    try:
        logger.print("Full UTF16-LE (all registers ABCD) : " +
                     all_bytes.decode('utf-16-le', errors='replace'))
    except Exception:
        logger.print("Full UTF16-LE (all registers ABCD) : <decode error>")

    # UTF-8
    try:
        logger.print("Full UTF8 (all registers ABCD)     : " +
                     all_bytes.decode('utf-8', errors='replace'))
    except Exception:
        logger.print("Full UTF8 (all registers ABCD)     : <decode error>")


def decode_registers(regs, floatformat, startreg, logger):
    """Top-level decode dispatcher — calls the three helpers above."""
    logger.print(f'\n[+] Raw registers: {regs}')

    # --- Per-register 16-bit breakdown (includes BCD) ---
    for idx, reg in enumerate(regs):
        decode_register_16bit(idx, reg, startreg, logger)

    # --- 32-bit pairwise (float32, int32, uint32, IPv4, epoch) ---
    if len(regs) >= 2:
        logger.print('\n=== Combined 32-bit interpretations (pairwise) ===')
        for i in range(0, len(regs) - 1, 2):
            decode_32bit_block(
                regs[i], regs[i+1],
                startreg + i, startreg + i + 1,
                floatformat, logger
            )

    # --- 64-bit quad-register groups (float64, int64, uint64, epoch) ---
    if len(regs) >= 4:
        logger.print('\n=== Combined 64-bit interpretations (quad registers) ===')
        for i in range(0, len(regs) - 3, 4):
            decode_64bit_block(
                regs[i], regs[i+1], regs[i+2], regs[i+3],
                startreg + i, startreg + i + 3,
                floatformat, logger
            )

    # --- Full multi-register summary (hex / ASCII / UTF) ---
    decode_multi_register_summary(regs, logger)


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Universal Modbus TCP register inspector',
        epilog=(
            "Examples:\n"
            "  (a) python3 python-modbus-poll-13.py --deviceIP 192.168.1.10 --startingregister 100 --count 4\n"
            "  (b) python3 python-modbus-poll-13.py --deviceIP 10.0.0.5 --startingregister 300 --regfunction 04 --raw\n"
            "  (c) python3 python-modbus-poll-13.py --deviceIP 10.242.105.67 --startingregister 10622 --slave 0 --raw --log query.log --timestamp\n"
            "  (d) python3 python-modbus-poll-13.py --deviceIP 10.242.105.67 --startingregister 10341 --slave 0 --raw --log query.log --timestamp --floatformat abcd\n"
            "  (e) python3 python-modbus-poll-13.py --deviceIP 172.28.228.221 --startingregister 7 --count 10 --slave 1 --raw\n"
            "  (f) python3 python-modbus-poll-13.py --deviceIP 10.242.105.67 --slave 1 --raw --startingregister 1036 --count 6 --verbose\n"
            "  (g) python3 python-modbus-poll-13.py --deviceIP 192.168.1.10 --startingregister 100 --count 4 --interval 5\n"
            "  (h) python3 python-modbus-poll-13.py --deviceIP 192.168.1.10 --startingregister 100 --retries 5 --timeout 10\n"
            "  (i) python3 python-modbus-poll-13.py --deviceIP 192.168.1.10 --startingregister 100 --count 8 --verbose\n"
            "      (count 8 = four 32-bit pairs AND two 64-bit quads decoded automatically)\n"
            "\n"
            "Notes:\n"
            "  - --interval N polls continuously every N seconds (Ctrl-C to stop).\n"
            "    The TCP connection is kept alive between polls; reconnected automatically on failure.\n"
            "  - --retries defaults to 3. Each failed attempt waits 1 s before retrying.\n"
            "  - --timeout sets the per-attempt socket timeout in seconds (default 5).\n"
            "    Slow serial gateways may need --timeout 10 or higher.\n"
            "  - Raw mode (--raw) prints full MBAP + PDU frames for debugging.\n"
            "    hex query of (c) example sent by python to device is like this:\n"
            "        MBAP + PDU HEX : 00 01 00 00 00 06 00 03 28 65 00 02\n"
            "        Device Response:\n"
            "        MBAP + PDU HEX : 00 01 00 00 00 07 00 03 04 05 E7 00 00\n"
            "    For troubleshooting, you can manually send raw query to your client (in hex) and expect the result:\n"
            "        printf '\\x00\\x01\\x00\\x00\\x00\\x06\\x00\\x03\\x28\\x65\\x00\\x02' | ncat 10.242.105.67 502 | xxd\n"
            "        00000000: 0001 0000 0007 0003 0405 e700 00         .............\n"
            "    Once you have the hex response, you can also check the response with something like this:\n"
            "        echo \"54 65 6C 74 6F 6E 69 6B 61 2D 52 55 54 39 35 30 2E 63 6F 6D\" | xxd -r -p && echo\n"
            "  - If --regfunction is not specified, Holding Registers (FC03) are used by default.\n"
            "  - Offset mode (--offsetminus1) subtracts 1 from the starting register.\n"
            "  - In some PLCs, even if Slave ID = 1 is configured within PLC, you need to poll with SlaveID 0\n"
            "  - Modbus Registers are always 16bit words = INT = 1 Register. Float Numbers require 32bits = 2 consecutive 16bit registers\n"
            "    This is the reason why this script polls for 2 registers as default - to handle floats\n"
            "    Especially for floats, endian makes great impact - Use --floatformat to select the correct interpretation or 'auto' to show all\n"
            "  - Some devices pack in one word (16bit=1 register) two different 8bit values and you need to apply 8bit decoding in this case\n"
            "    This is quite usual in registers containing IPs. i.e Teltonika IP = Register394+395 = 4 x 8 bits\n"
            "    Register 394 returns in hex C0A8 and this makes meaning only if decoded as 8bit -> C0 = 192 , A8=168 (similarly for register 395)\n"
            "    This is why you always need the register map of the device you are polling to be able to correctly decode the returned hex value by the device\n"
            "  - When dealing with registers 32bit that contain time in seconds (i.e Teltonika Uptime Register 1) you can convert the seconds returned:\n"
            "    secs=23871; printf \"%02dh %02dm %02ds\" $((secs/3600)) $(((secs%3600)/60)) $((secs%60))\n"
            "    Result: 06h 37m 51s (Teltonika web page was indicating 06h 38m 07s, just human delay switching from terminal to browser)\n"
            "  - BCD (Binary Coded Decimal): shown per register in --verbose mode. Common in older PLCs (Siemens S5, Mitsubishi, Omron).\n"
            "    A register value of 0x1234 in BCD means 1234 decimal. If any nibble > 9 it is flagged as invalid BCD.\n"
            "  - IPv4: in --verbose mode the 32-bit block shows the two registers decoded as packed IPv4 (hi/lo byte per register).\n"
            "    Example: r0=0xC0A8, r1=0x0101 -> 192.168.1.1\n"
            "  - Unix epoch: in --verbose mode, all 32-bit and 64-bit integer interpretations are checked against the\n"
            "    year 2000-2100 window and displayed as UTC datetime if plausible. 64-bit millisecond epochs are also checked.\n"
            "  - 64-bit types (FLOAT64/double, INT64, UINT64): decoded automatically in --verbose mode whenever 4 or more\n"
            "    registers are polled, using the same word-order formats extended to 4 words (abcdefgh / ghefcdab / badcfehg / hgfedcba).\n"
        ),
        formatter_class=argparse.RawTextHelpFormatter
    )

    parser.add_argument('--deviceIP',         required=True)
    parser.add_argument('--port',             type=int, default=502,
                        help='Modbus TCP port (default: 502)')
    parser.add_argument('--startingregister', type=int, required=True)
    parser.add_argument('--count',            type=int, default=2,
                        help='Number of registers to read (default: 2)')
    parser.add_argument('--slave',            type=int, default=1,
                        help='Slave / Unit ID (default: 1)')
    parser.add_argument('--offsetminus1',     action='store_true',
                        help='Subtract 1 from starting register before sending')
    parser.add_argument('--raw',              action='store_true',
                        help='Print raw MBAP + PDU hex frames')
    parser.add_argument('--verbose',          action='store_true',
                        help='Full register breakdown and multi-format decoding (BCD, IPv4, epoch, 64-bit, UTF)')
    parser.add_argument('--regfunction',
                        choices=['01', '02', '03', '04'], default='03',
                        help=(
                            "Modbus Function Code:\n"
                            "  01 = Read Coils\n"
                            "  02 = Read Discrete Inputs\n"
                            "  03 = Read Holding Registers (default)\n"
                            "  04 = Read Input Registers"
                        ))
    parser.add_argument('--floatformat',
                        choices=['abcd', 'cdab', 'badc', 'dcba', 'auto'], default='auto',
                        help=(
                            "32-bit float word order:\n"
                            "  abcd = Big Endian (standard)      r0_hi r0_lo r1_hi r1_lo\n"
                            "  cdab = Big Endian word-swap        r1_hi r1_lo r0_hi r0_lo\n"
                            "  badc = Little Endian byte-swap     r0_lo r0_hi r1_lo r1_hi\n"
                            "  dcba = Little Endian full reverse  r1_lo r1_hi r0_lo r0_hi\n"
                            "  auto = show all formats (default)"
                        ))
    parser.add_argument('--interval',  type=float, default=0,
                        help='Poll every N seconds continuously (0 = single shot, default: 0)')
    parser.add_argument('--retries',   type=int,   default=3,
                        help='Retry attempts on connection/IO failure (default: 3)')
    parser.add_argument('--timeout',   type=float, default=5,
                        help='Socket timeout in seconds per attempt (default: 5)')
    parser.add_argument('--log',       metavar='FILENAME',
                        help='Append all output to this log file')
    parser.add_argument('--timestamp', action='store_true',
                        help='Prefix every output line with a timestamp')
    parser.add_argument('--quiet',     action='store_true',
                        help='Suppress terminal output (log file still receives output)')

    args = parser.parse_args()

    logger = Logger(
        enable_timestamp=args.timestamp,
        quiet=args.quiet,
        log_path=args.log
    )

    function_map = {'01': 1, '02': 2, '03': 3, '04': 4}
    function_code = function_map[args.regfunction]

    register = args.startingregister
    if args.offsetminus1:
        register -= 1

    continuous = args.interval > 0
    poll_count = 0

    logger.print("\n" + "=" * 70)
    logger.print("New polling session started")
    logger.print(
        f"Target : {args.deviceIP}:{args.port}  "
        f"SlaveID={args.slave}  "
        f"StartReg={register}  "
        f"Count={args.count}  "
        f"FC={args.regfunction} ({function_code:02X} - {function_name(function_code)})"
    )
    if continuous:
        logger.print(f"Mode   : continuous, interval={args.interval}s  (Ctrl-C to stop)")
    else:
        logger.print("Mode   : single shot")
    logger.print(f"Retries: {args.retries}  Timeout: {args.timeout}s")

    if args.verbose:
        logger.print("\n=== Modbus Polling Parameters ===")
        logger.print(f"[*] Device IP       : {args.deviceIP}")
        logger.print(f"[*] Port            : {args.port}")
        logger.print(f"[*] Slave ID        : {args.slave}")
        logger.print(f"[*] Start Register  : {register}")
        logger.print(f"[*] Register Count  : {args.count}")
        logger.print(f"[*] Offset -1       : {'YES' if args.offsetminus1 else 'NO'}")
        logger.print(f"[*] Raw Frames      : {'YES' if args.raw else 'NO'}")
        logger.print(f"[*] Reg Function    : {args.regfunction} ({function_code:02X} - {function_name(function_code)})")
        logger.print(f"[*] Float Format    : {args.floatformat}")
        logger.print(f"[*] Interval        : {args.interval}s")
        logger.print(f"[*] Retries         : {args.retries}")
        logger.print(f"[*] Timeout         : {args.timeout}s")
        logger.print(f"[*] Timestamping    : {'YES' if args.timestamp else 'NO'}")
        logger.print(f"[*] Quiet Mode      : {'YES' if args.quiet else 'NO'}")
        if args.log:
            logger.print(f"[*] Log File        : {args.log}")
        logger.print("=================================\n")

    # -------------------------------------------------------------------------
    # Persistent socket for continuous mode; None = reconnect each poll
    # -------------------------------------------------------------------------
    persistent_sock = None

    def open_socket():
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(args.timeout)
        s.connect((args.deviceIP, args.port))
        return s

    def poll_once(transaction_id):
        """Execute one complete poll cycle. Returns parsed registers or None."""
        nonlocal persistent_sock

        request_frame = build_modbus_request(
            transaction_id, args.slave, function_code, register, args.count
        )

        # --- Send with retry logic ---
        response_frame = None
        last_exc = None

        for attempt in range(1, args.retries + 1):
            try:
                if continuous:
                    # Reuse persistent socket; reconnect if it died
                    if persistent_sock is None:
                        logger.print(f'[*] Connecting to {args.deviceIP}:{args.port}')
                        persistent_sock = open_socket()
                    persistent_sock.sendall(request_frame)
                    response_frame = recv_modbus_response(persistent_sock)
                else:
                    # Single-shot: fresh connection every time (retries handled here)
                    logger.print(f'[*] Connecting to {args.deviceIP}:{args.port}')
                    s = open_socket()
                    s.sendall(request_frame)
                    response_frame = recv_modbus_response(s)
                    s.close()

                break  # success

            except Exception as e:
                last_exc = e
                logger.print(f'[!] Attempt {attempt}/{args.retries} failed: {e}')

                # Kill the dead persistent socket so next attempt reconnects
                if continuous and persistent_sock is not None:
                    try:
                        persistent_sock.close()
                    except Exception:
                        pass
                    persistent_sock = None

                if attempt < args.retries:
                    time.sleep(1)

        if response_frame is None:
            logger.print(f'[!] All {args.retries} attempts failed. Last error: {last_exc}')
            return None

        # --- Raw frames ---
        if args.raw:
            parsed = parse_modbus_response(response_frame, logger)
            show_raw_frames(
                args.slave, register, args.count, function_code,
                request_frame, response_frame,
                verbose=args.verbose,
                logger=logger
            )
            if parsed is None:
                return None

        # --- Parse ---
        parsed = parse_modbus_response(response_frame, logger)
        if parsed is None:
            return None

        fc, byte_count, regs, data = parsed

        if args.verbose:
            decode_registers(regs, args.floatformat, args.startingregister, logger)
        else:
            logger.print(f"\n[+] Raw registers: {regs}")

        return regs

    # -------------------------------------------------------------------------
    # Poll loop
    # -------------------------------------------------------------------------
    try:
        while True:
            poll_count += 1

            if continuous:
                logger.print(f"\n{'=' * 70}")
                logger.print(f"Poll #{poll_count}")

            poll_once(transaction_id=poll_count)

            if not continuous:
                break

            time.sleep(args.interval)

    except KeyboardInterrupt:
        logger.print(f'\n[*] Interrupted by user after {poll_count} poll(s).')

    finally:
        if persistent_sock is not None:
            try:
                persistent_sock.close()
            except Exception:
                pass

        logger.print('\n[*] Session ended.')
        logger.print("=" * 70)
        logger.close()


if __name__ == '__main__':
    main()
