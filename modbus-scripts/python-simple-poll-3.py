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

def decode_register_values(pdu: bytes, count: int):
    """
    Basic decoding:
      - UINT16 list
      - INT16 list
      - FLOAT32 (ABCD) if count == 2
    """
    if len(pdu) < 2:
        return

    byte_count = pdu[1]
    data = pdu[2:2 + byte_count]

    if len(data) != count * 2:
        print("[!] Warning: Byte count mismatch")
        return

    # Extract registers
    regs = []
    for i in range(0, len(data), 2):
        regs.append(struct.unpack(">H", data[i:i+2])[0])

    print("\n[+] Decoded Values")
    print(f"  UINT16 : {regs}")

    int16_list = [(r if r < 0x8000 else r - 0x10000) for r in regs]
    print(f"  INT16  : {int16_list}")

    # FLOAT32 only when exactly 2 registers
    if count == 2:
        raw_bytes = data
        try:
            f = struct.unpack(">f", raw_bytes)[0]
            print(f"  FLOAT32 (ABCD) : {f}")
        except:
            print("  FLOAT32 (ABCD) : <invalid>")

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

    args = parser.parse_args()
    function_code = int(args.regfunction)

    print(f"[*] Connecting to {args.deviceIP}:{args.port} , "
          f"Polling Register {args.startingregister} , Count {args.count} , "
          f"RegFunction {function_code:02d}")

    # Build request
    tx_id = 1
    request = build_modbus_request(
        transaction_id=tx_id,
        unit_id=args.slave,
        function_code=function_code,
        start_reg=args.startingregister,
        count=args.count
    )

    print("\n=== Raw Modbus TCP Query ===")
    print(f"MBAP + PDU HEX : {hexify(request)}")

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(3)
        sock.connect((args.deviceIP, args.port))
        sock.sendall(request)

        # Read MBAP header
        mbap = sock.recv(7)
        if len(mbap) < 7:
            print("[!] Incomplete MBAP header received")
            return

        _, _, length, _ = struct.unpack(">HHHB", mbap)

        # Read PDU
        pdu = sock.recv(length - 1)
        response = mbap + pdu

        print("\n=== Raw Modbus TCP Response ===")
        print(f"MBAP + PDU HEX : {hexify(response)}")

        # Exception detection
        is_exc, fc, exc_code, desc = check_modbus_exception(response)
        if is_exc:
            print("\n[!] Modbus Exception Received")
            print(f"    Function: {fc:02X}")
            print(f"    Exception Code: {exc_code} ({desc})")
            if exc_code == 4:
                print("    Hint: Device rejected the request. Reduce --count or poll another register.")
            return

        # ------------------------------------------------------------
        # Basic decoding (only for FC03/FC04)
        # ------------------------------------------------------------
        if function_code in (3, 4):
            decode_register_values(pdu, args.count)

    except Exception as e:
        print(f"[!] Error: {e}")
    finally:
        try:
            sock.close()
        except:
            pass

if __name__ == "__main__":
    main()
