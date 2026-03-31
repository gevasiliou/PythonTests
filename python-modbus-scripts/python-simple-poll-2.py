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
    # MBAP: Transaction ID (2) + Protocol ID (2) + Length (2) + Unit ID (1)
    mbap = struct.pack(">HHHB", transaction_id, 0x0000, 6, unit_id)
    # PDU: Function Code (1) + Start Register (2) + Count (2)
    pdu = struct.pack(">BHH", function_code, start_reg, count)
    return mbap + pdu

def check_modbus_exception(response: bytes):
    """
    Detects Modbus exception frames.
    Returns (is_exception, function, code, description)
    """
    if len(response) < 9:
        return (False, None, None, None)

    fc = response[7]

    # Exception frames have FC = original FC + 0x80
    if fc & 0x80:
        exc_code = response[8]
        desc = MODBUS_EXCEPTIONS.get(exc_code, "Unknown Exception")
        return (True, fc & 0x7F, exc_code, desc)

    return (False, None, None, None)

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
    parser.add_argument("--regfunction", choices=["holding", "input"], default="holding")

    args = parser.parse_args()

    function_code = 3 if args.regfunction == "holding" else 4

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

    # Send request
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(3)
        sock.connect((args.deviceIP, args.port))
        sock.sendall(request)

        # Read MBAP header first (7 bytes)
        mbap = sock.recv(7)
        if len(mbap) < 7:
            print("[!] Incomplete MBAP header received")
            return

        # Extract length field
        _, _, length, _ = struct.unpack(">HHHB", mbap)

        # Read remaining PDU bytes
        pdu = sock.recv(length - 1)  # minus Unit ID already read
        response = mbap + pdu

        print("\n=== Raw Modbus TCP Response ===")
        print(f"MBAP + PDU HEX : {hexify(response)}")

        # ------------------------------------------------------------
        # Exception detection
        # ------------------------------------------------------------
        is_exc, fc, exc_code, desc = check_modbus_exception(response)

        if is_exc:
            print("\n[!] Modbus Exception Received")
            print(f"    Function: {fc:02X}")
            print(f"    Exception Code: {exc_code} ({desc})")

            # Helpful hint for the most common real-world case
            if exc_code == 4:
                print("    Hint: Device rejected the request. "
                      "Try reducing --count or check register boundaries.")
            return

    except Exception as e:
        print(f"[!] Error: {e}")
    finally:
        try:
            sock.close()
        except:
            pass

if __name__ == "__main__":
    main()
