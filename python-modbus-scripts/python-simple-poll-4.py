#!/usr/bin/env python3
import socket
import struct
import argparse
import sys

# ------------------------------------------------------------
# Modbus exception dictionary
# ------------------------------------------------------------
MODBUS_EXCEPTIONS = {
    1: "Illegal Function",
    2: "Illegal Data Address",
    3: "Illegal Data Value",
    4: "Slave Device Failure",
    5: "Acknowledge",
    6: "Slave Device Busy",
    8: "Memory Parity Error",
    10: "Gateway Path Unavailable",
    11: "Gateway Target Device Failed to Respond"
}

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
def hexify(data: bytes) -> str:
    return " ".join(f"{b:02X}" for b in data)

def build_modbus_request(transaction_id, unit_id, function_code, start_reg, count):
    mbap = struct.pack(">HHHB", transaction_id, 0x0000, 6, unit_id)
    pdu = struct.pack(">BHH", function_code, start_reg, count)
    return mbap + pdu

def check_modbus_exception(response: bytes):
    if len(response) < 9:
        return (False, None, None, None)

    fc = response[7]
    if fc & 0x80:
        exc_code = response[8]
        desc = MODBUS_EXCEPTIONS.get(exc_code, "Unknown Exception")
        return (True, fc & 0x7F, exc_code, desc)

    return (False, None, None, None)

def decode_uint16_int16_single(pdu: bytes):
    if len(pdu) < 2:
        return None, None

    byte_count = pdu[1]
    data = pdu[2:2 + byte_count]

    if len(data) != 2:
        return None, None

    val = struct.unpack(">H", data)[0]
    val_signed = val if val < 0x8000 else val - 0x10000
    return val, val_signed

# ------------------------------------------------------------
# Polling function (returns status + optional values)
# ------------------------------------------------------------
def poll_once(ip, port, slave, reg, count, function_code, show_raw=False):
    request = build_modbus_request(
        transaction_id=1,
        unit_id=slave,
        function_code=function_code,
        start_reg=reg,
        count=count
    )

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        sock.connect((ip, port))
        sock.sendall(request)

        mbap = sock.recv(7)
        if len(mbap) < 7:
            return ("ERR", "Incomplete MBAP")

        _, _, length, _ = struct.unpack(">HHHB", mbap)
        pdu = sock.recv(length - 1)
        response = mbap + pdu

        if show_raw:
            print("\n=== Raw Modbus TCP Query ===")
            print(f"MBAP + PDU HEX : {hexify(request)}")
            print("=== Raw Modbus TCP Response ===")
            print(f"MBAP + PDU HEX : {hexify(response)}")

        is_exc, fc, exc_code, desc = check_modbus_exception(response)
        if is_exc:
            return ("EXC", f"{exc_code} ({desc})")

        # For FC03/FC04 and count==1, decode UINT16/INT16
        if function_code in (3, 4) and count == 1:
            u16, i16 = decode_uint16_int16_single(pdu)
            if u16 is None:
                return ("ERR", "Invalid PDU")
            return ("OK", u16, i16)

        # For other cases (count > 1 or other FC), just say OK
        return ("OK", None, None)

    except Exception as e:
        return ("ERR", str(e))

    finally:
        try:
            sock.close()
        except:
            pass

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Simple raw Modbus TCP poller")
    parser.add_argument("--deviceIP", required=True)
    parser.add_argument("--port", type=int, default=502)
    parser.add_argument("--slave", type=int, required=True)
    parser.add_argument("--startingregister", type=int, required=True)
    parser.add_argument("--count", type=int, default=1)

    parser.add_argument(
        "--regfunction",
        choices=["01", "02", "03", "04"],
        default="03",
        help=(
            "Modbus Function Code:\n"
            "  01 = Read Coils\n"
            "  02 = Read Discrete Inputs\n"
            "  03 = Read Holding Registers\n"
            "  04 = Read Input Registers\n"
            "Default = 03"
        )
    )

    parser.add_argument(
        "--looprange",
        type=int,
        help="Poll all registers from startingregister up to this register (count is forced to 1)"
    )

    args = parser.parse_args()
    function_code = int(args.regfunction)

    print(f"[*] Connecting to {args.deviceIP}:{args.port}")

    # LOOP MODE: table output, count forced to 1
    if args.looprange:
        print("\nRegister | UINT16 | INT16")
        print("---------------------------")

        for reg in range(args.startingregister, args.looprange + 1):
            result = poll_once(args.deviceIP, args.port, args.slave, reg, 1, function_code, show_raw=False)

            if result[0] == "OK":
                _, u16, i16 = result
                if u16 is not None:
                    print(f"{reg:<8} | {u16:<6} | {i16}")
                else:
                    print(f"{reg:<8} | OK     |")
            elif result[0] == "EXC":
                _, msg = result
                exc_num = msg.split()[0]
                print(f"{reg:<8} | EXC {exc_num}")
            else:
                _, msg = result
                print(f"{reg:<8} | ERR {msg}")
        return

    # SINGLE POLL MODE: honor --count, show raw frames
    print(f"\n[*] Polling Register {args.startingregister} (Count={args.count}) , FC={function_code:02d}")
    result = poll_once(
        args.deviceIP,
        args.port,
        args.slave,
        args.startingregister,
        args.count,
        function_code,
        show_raw=True
    )

    if result[0] == "OK":
        _, u16, i16 = result
        if u16 is not None:
            print(f"\n[+] Decoded UINT16: {u16}")
            print(f"[+] Decoded INT16 : {i16}")
        else:
            print("\n[+] Poll successful (no simple decode for this count/FC).")
    elif result[0] == "EXC":
        _, msg = result
        exc_num = msg.split()[0]
        print(f"\n[!] Modbus Exception: {msg} (EXC {exc_num})")
    else:
        _, msg = result
        print(f"\n[!] Error: {msg}")

if __name__ == "__main__":
    main()
