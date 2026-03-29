#!/usr/bin/env python3
import argparse
import struct
import socket
import sys
from datetime import datetime

log_file_handle = None
ENABLE_TIMESTAMP = False
QUIET_MODE = False


def log_print(*args, **kwargs):
    """Print to stdout and optionally to log file, with optional timestamps."""
    global log_file_handle, ENABLE_TIMESTAMP, QUIET_MODE

    sep = kwargs.get('sep', ' ')
    end = kwargs.get('end', '\n')

    msg_body = sep.join(str(a) for a in args)

    if ENABLE_TIMESTAMP:
        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        msg = f"[{ts}] {msg_body}{end}"
    else:
        msg = f"{msg_body}{end}"

    # Terminal output (unless quiet)
    if not QUIET_MODE:
        sys.stdout.write(msg)
        sys.stdout.flush()

    # Log file output
    if log_file_handle is not None:
        log_file_handle.write(msg)
        log_file_handle.flush()


def printable_ascii(byte_data):
    return ''.join(chr(b) if 32 <= b <= 126 else '.' for b in byte_data)


def hexdump(byte_data):
    return ' '.join(f'{b:02X}' for b in byte_data)


def build_modbus_request(transaction_id, unit_id, function_code, register, count):
    pdu = struct.pack(">BHH", function_code, register, count)
    length = len(pdu) + 1
    mbap = struct.pack(">HHHB", transaction_id, 0x0000, length, unit_id)
    return mbap + pdu


def send_modbus_request(ip, port, frame):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(5)
    s.connect((ip, port))
    s.sendall(frame)
    resp = s.recv(260)
    s.close()
    return resp


def parse_modbus_response(resp):
    function_code = resp[7]
    byte_count = resp[8]
    data = resp[9:9 + byte_count]

    registers = []
    for i in range(0, byte_count, 2):
        reg = struct.unpack(">H", data[i:i+2])[0]
        registers.append(reg)

    return function_code, byte_count, registers, data


def show_raw_frames(slave, register, count, function_code, request_frame, response_frame, registers):
    log_print('\n=== Raw Modbus TCP Query ===')
    log_print(f'MBAP + PDU HEX : {hexdump(request_frame)}')

    log_print('Breakdown:')
    log_print(f'  Transaction ID : {request_frame[0]:02X}{request_frame[1]:02X}')
    log_print(f'  Protocol ID    : {request_frame[2]:02X}{request_frame[3]:02X}')
    log_print(f'  Length         : {request_frame[4]:02X}{request_frame[5]:02X}')
    log_print(f'  Unit ID        : {slave:02X}')
    log_print(f'  Function Code  : {function_code:02X} ({function_name(function_code)})')
    log_print(f'  Start Register : {register} (0x{register:04X})')
    log_print(f'  Register Count : {count} (0x{count:04X})')

    log_print('\n=== Raw Modbus TCP Response ===')
    if response_frame is None:
        log_print('No response received')
        return

    log_print(f'MBAP + PDU HEX : {hexdump(response_frame)}')

    fc = response_frame[7]
    byte_count = response_frame[8]

    log_print('Breakdown:')
    log_print(f'  Transaction ID : {response_frame[0]:02X}{response_frame[1]:02X}')
    log_print(f'  Protocol ID    : {response_frame[2]:02X}{response_frame[3]:02X}')
    log_print(f'  Length         : {response_frame[4]:02X}{response_frame[5]:02X}')
    log_print(f'  Unit ID        : {slave:02X}')
    log_print(f'  Function Code  : {fc:02X}')
    log_print(f'  Byte Count     : {byte_count} (0x{byte_count:02X})')

    for idx, reg in enumerate(registers):
        actual_register = register + idx
        log_print(
            f'  Register {actual_register:5d} : '
            f'{reg:6d}   '
            f'(0x{reg:04X})'
        )

    pdu = response_frame[7:]
    log_print(f'  PDU ASCII      : {printable_ascii(pdu)}')


def function_name(fc):
    return {
        1: "Read Coils",
        2: "Read Discrete Inputs",
        3: "Read Holding Registers",
        4: "Read Input Registers"
    }.get(fc, "Unknown")


def decode_registers(regs):
    log_print(f'\n[+] Raw registers: {regs}')

    for idx, reg in enumerate(regs):
        uint16 = reg
        int16 = reg if reg < 0x8000 else reg - 0x10000
        reg_bytes = struct.pack('>H', reg)

        log_print(f'\n--- Register {idx + 1} ---')
        log_print(f'UINT16         : {uint16}')
        log_print(f'INT16          : {int16}')
        log_print(f'HEX            : 0x{reg:04X}')
        log_print(f'BIN            : {reg:016b}')
        log_print(f'ASCII          : {printable_ascii(reg_bytes)}')
        log_print(f'Scaled /10     : {uint16 / 10}')
        log_print(f'Scaled /100    : {uint16 / 100}')
        log_print(f'Scaled /1000   : {uint16 / 1000}')

    if len(regs) >= 2:
        r0, r1 = regs[0], regs[1]
        be_bytes = struct.pack('>HH', r0, r1)
        swapped_bytes = struct.pack('>HH', r1, r0)

        log_print('\n=== Combined 32-bit interpretations ===')
        try:
            log_print(f'UINT32 BE      : {struct.unpack(">I", be_bytes)[0]}')
            log_print(f'UINT32 SWAP    : {struct.unpack(">I", swapped_bytes)[0]}')
        except:
            pass

        try:
            log_print(f'INT32 BE       : {struct.unpack(">i", be_bytes)[0]}')
            log_print(f'INT32 SWAP     : {struct.unpack(">i", swapped_bytes)[0]}')
        except:
            pass

        try:
            log_print(f'FLOAT32 BE     : {struct.unpack(">f", be_bytes)[0]}')
            log_print(f'FLOAT32 SWAP   : {struct.unpack(">f", swapped_bytes)[0]}')
        except:
            pass

        log_print(f'HEX BE         : {hexdump(be_bytes)}')
        log_print(f'HEX SWAP       : {hexdump(swapped_bytes)}')
        log_print(f'ASCII BE       : {printable_ascii(be_bytes)}')
        log_print(f'ASCII SWAP     : {printable_ascii(swapped_bytes)}')

        try:
            val32 = struct.unpack(">I", be_bytes)[0]
            log_print(f'Scaled UINT32 /10   : {val32 / 10}')
            log_print(f'Scaled UINT32 /100  : {val32 / 100}')
            log_print(f'Scaled UINT32 /1000 : {val32 / 1000}')
        except:
            pass


def main():
    global log_file_handle, ENABLE_TIMESTAMP, QUIET_MODE

    parser = argparse.ArgumentParser(
        description='Universal Modbus TCP register inspector',
        epilog=(
            "Examples:\n"
            "  (a) python3 python-modbus-poll-6.py --deviceIP 192.168.1.10 --startingregister 100 --count 4\n"
            "  (b) python3 python-modbus-poll-6.py --deviceIP 10.0.0.5 --startingregister 300 --regfunction input --raw\n"
            "  (c) python3 python-modbus-poll-6.py --deviceIP 10.242.105.67 --startingregister 10341 --slave 0 --raw\n"
            "\n"
            "Notes:\n"
            "  - Raw mode (--raw) prints full MBAP + PDU frames for debugging.\n"
            "    hex query of (c) example send by python to device is like this:\n"
            "        MBAP + PDU HEX : 00 01 00 00 00 06 00 03 28 65 00 02\n"
            "        Device Response:\n"
            "        MBAP + PDU HEX : 00 01 00 00 00 07 00 03 04 05 E7 00 00\n"
            "    For troubleshooting, you can manually send raw query to your client (in hex) and expect the result: \n"
            "        printf '\\x00\\x01\\x00\\x00\\x00\\x06\\x00\\x03\\x28\\x65\\x00\\x02' | ncat 10.242.105.67 502 | xxd \n"
            "        00000000: 0001 0000 0007 0003 0405 e700 00         .............\n"
            "  - If --regfunction is not specified, Holding Registers (FC03) are used by default.\n"
            "  - Offset mode (--offsetminus1) subtracts 1 from the starting register.\n"
            "  - In some PLCs , even if Slave ID = 1 is configured within PLC, you need to poll with SlaveID 0\n"
        ),
        formatter_class=argparse.RawTextHelpFormatter
    )

    parser.add_argument('--deviceIP', required=True)
    parser.add_argument('--port', type=int, default=502, help="Optional, default port = 502")
    parser.add_argument('--startingregister', type=int, required=True)
    parser.add_argument('--count', type=int, default=2, help="Default = 2")
    parser.add_argument('--slave', type=int, default=0, help="Default = 0")
    parser.add_argument('--offsetminus1', action='store_true')
    parser.add_argument('--raw', action='store_true')

    parser.add_argument(
        '--regfunction',
        choices=['holding', 'input', 'coil', 'discrete'],
        default='holding',
        help='Register function: holding (FC03), input (FC04), coil (FC01), discrete (FC02) [default=holding]'
    )

    parser.add_argument(
        '--log',
        metavar='FILENAME',
        help='Also write all output to the specified log file (append mode)'
    )

    parser.add_argument(
        '--timestamp',
        action='store_true',
        help='Enable timestamps in output and log [default=no timestamps]'
    )

    parser.add_argument(
        '--quiet',
        action='store_true',
        help='Suppress terminal output (log file still receives full output)'
    )

    args = parser.parse_args()

    ENABLE_TIMESTAMP = args.timestamp
    QUIET_MODE = args.quiet

    if args.log:
        try:
            log_file_handle = open(args.log, 'a', encoding='utf-8')
        except Exception as e:
            print(f'[!] Failed to open log file {args.log}: {e}')
            return

    register = args.startingregister
    if args.offsetminus1:
        register -= 1

    function_map = {
        'holding': 3,
        'input': 4,
        'coil': 1,
        'discrete': 2
    }

    function_code = function_map[args.regfunction]

    # Separator line
    log_print("\n" + "=" * 70)

    # Print full switch summary
    log_print("=== Modbus Polling Parameters ===")
    log_print(f"[*] Device IP       : {args.deviceIP}")
    log_print(f"[*] Port            : {args.port}")
    log_print(f"[*] Slave ID        : {args.slave}")
    log_print(f"[*] Start Register  : {register}")
    log_print(f"[*] Register Count  : {args.count}")
    log_print(f"[*] Offset -1       : {'YES' if args.offsetminus1 else 'NO'}")
    log_print(f"[*] Raw Frames      : {'YES' if args.raw else 'NO'}")
    log_print(f"[*] Reg Function    : {args.regfunction} ({function_code:02X} - {function_name(function_code)})")
    log_print(f"[*] Timestamping    : {'YES' if args.timestamp else 'NO'}")
    log_print(f"[*] Quiet Mode      : {'YES' if args.quiet else 'NO'}")
    if args.log:
        log_print(f"[*] Log File        : {args.log}")
    log_print("=================================\n")

    log_print(f'[*] Connecting to {args.deviceIP}:{args.port}')

    transaction_id = 1
    request_frame = build_modbus_request(
        transaction_id,
        args.slave,
        function_code,
        register,
        args.count
    )

    try:
        response_frame = send_modbus_request(args.deviceIP, args.port, request_frame)
    except Exception as e:
        log_print(f'[!] Connection error: {e}')
        if log_file_handle:
            log_file_handle.close()
        return

    if args.raw:
        try:
            fc, byte_count, regs, data = parse_modbus_response(response_frame)
            show_raw_frames(args.slave, register, args.count, function_code,
                            request_frame, response_frame, regs)
        except Exception:
            log_print('[!] Failed to parse raw response')
            if log_file_handle:
                log_file_handle.close()
            return

    try:
        fc, byte_count, regs, data = parse_modbus_response(response_frame)
    except Exception as e:
        log_print(f'[!] Failed to parse response: {e}')
        if log_file_handle:
            log_file_handle.close()
        return

    decode_registers(regs)

    log_print('\n[*] Connection closed')

    if log_file_handle:
        log_file_handle.close()


if __name__ == '__main__':
    main()
