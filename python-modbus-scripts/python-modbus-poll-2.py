import argparse
import struct
from pymodbus.client import ModbusTcpClient
from pymodbus.pdu import ReadHoldingRegistersRequest


def printable_ascii(byte_data):
    return ''.join(chr(b) if 32 <= b <= 126 else '.' for b in byte_data)


def decode_registers(regs):
    print(f"\n[+] Raw registers: {regs}")

    for idx, reg in enumerate(regs):
        uint16 = reg
        int16 = reg if reg < 0x8000 else reg - 0x10000

        reg_bytes = struct.pack('>H', reg)

        print(f"\n--- Register {idx + 1} ---")
        print(f"UINT16         : {uint16}")
        print(f"INT16          : {int16}")
        print(f"HEX            : 0x{reg:04X}")
        print(f"BIN            : {reg:016b}")
        print(f"ASCII          : {printable_ascii(reg_bytes)}")

        # Common engineering scaling guesses
        print(f"Scaled /10     : {uint16 / 10}")
        print(f"Scaled /100    : {uint16 / 100}")
        print(f"Scaled /1000   : {uint16 / 1000}")

    if len(regs) >= 2:
        r0 = regs[0]
        r1 = regs[1]

        # Big-endian word order: reg0 then reg1
        be_bytes = struct.pack('>HH', r0, r1)

        # Swapped word order: reg1 then reg0
        swapped_bytes = struct.pack('>HH', r1, r0)

        print("\n=== Combined 32-bit interpretations ===")

        try:
            print(f"UINT32 BE      : {struct.unpack('>I', be_bytes)[0]}")
            print(f"UINT32 SWAP    : {struct.unpack('>I', swapped_bytes)[0]}")
        except Exception:
            pass

        try:
            print(f"INT32 BE       : {struct.unpack('>i', be_bytes)[0]}")
            print(f"INT32 SWAP     : {struct.unpack('>i', swapped_bytes)[0]}")
        except Exception:
            pass

        try:
            print(f"FLOAT32 BE     : {struct.unpack('>f', be_bytes)[0]}")
            print(f"FLOAT32 SWAP   : {struct.unpack('>f', swapped_bytes)[0]}")
        except Exception:
            pass

        print(f"HEX BE         : {' '.join(f'{b:02X}' for b in be_bytes)}")
        print(f"HEX SWAP       : {' '.join(f'{b:02X}' for b in swapped_bytes)}")
        print(f"ASCII BE       : {printable_ascii(be_bytes)}")
        print(f"ASCII SWAP     : {printable_ascii(swapped_bytes)}")

        # Show common engineering scale guesses for 32-bit integers
        try:
            val32 = struct.unpack('>I', be_bytes)[0]
            print(f"Scaled UINT32 /10   : {val32 / 10}")
            print(f"Scaled UINT32 /100  : {val32 / 100}")
            print(f"Scaled UINT32 /1000 : {val32 / 1000}")
        except Exception:
            pass


def main():
    parser = argparse.ArgumentParser(
        description="Universal Modbus TCP register inspector"
    )

    parser.add_argument("--deviceIP", required=True, help="Device IP address")
    parser.add_argument("--port", type=int, default=502, help="Modbus TCP port")
    parser.add_argument("--startingregister", type=int, required=True,
                        help="Starting register address")
    parser.add_argument("--count", type=int, default=2,
                        help="Number of registers to read")
    parser.add_argument("--slave", type=int, default=0,
                        help="Modbus slave / unit ID")
    parser.add_argument("--offsetminus1", action="store_true",
                        help="Subtract 1 from register before reading")

    args = parser.parse_args()

    register = args.startingregister
    if args.offsetminus1:
        register -= 1

    print(f"[*] Connecting to {args.deviceIP}:{args.port}")
    print(f"[*] Slave ID        : {args.slave}")
    print(f"[*] Start Register  : {register}")
    print(f"[*] Register Count  : {args.count}")

    client = ModbusTcpClient(host=args.deviceIP, port=args.port, timeout=5)

    try:
        if not client.connect():
            print("[!] Connection failed")
            return

        request = ReadHoldingRegistersRequest(
            address=register,
            count=args.count
        )

        response = client.execute(args.slave, request)

        if response is None:
            print("[!] No response received from device")
            return

        if response.isError():
            print(f"[!] Modbus exception: {response}")
            return

        if not hasattr(response, 'registers'):
            print(f"[!] Unexpected response type: {response}")
            return

        decode_registers(response.registers)

    except KeyboardInterrupt:
        print("\n[!] Interrupted by user")

    except Exception as e:
        print(f"[!] Script error: {e}")

    finally:
        client.close()
        print("\n[*] Connection closed")


if __name__ == '__main__':
    main()
