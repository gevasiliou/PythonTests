import argparse
from pymodbus.client import ModbusTcpClient
from pymodbus.pdu import ReadHoldingRegistersRequest


def main():
    parser = argparse.ArgumentParser(
        description="Read 2 Modbus holding registers and decode them as Float32"
    )
    parser.add_argument(
        "--deviceIP",
        required=True,
        help="IP address of the Modbus TCP device"
    )
    parser.add_argument(
        "--port",
        type=int,
        default=502,
        help="Modbus TCP port (default: 502)"
    )
    parser.add_argument(
        "--startingregister",
        type=int,
        default=10341,
        help="Starting holding register address"
    )
    parser.add_argument(
        "--slave",
        type=int,
        default=1,
        help="Modbus slave/unit ID"
    )
    parser.add_argument(
        "--count",
        type=int,
        default=2,
        help="Number of registers to read (default: 2 for Float32)"
    )
    parser.add_argument(
        "--offsetminus1",
        action="store_true",
        help="Subtract 1 from the provided register address before reading"
    )

    args = parser.parse_args()

    register = args.startingregister

    if args.offsetminus1:
        register -= 1

    print(f"[*] Connecting to {args.deviceIP}:{args.port}")
    print(f"[*] Slave ID: {args.slave}")
    print(f"[*] Reading register: {register}")

    client = ModbusTcpClient(host=args.deviceIP, port=args.port, timeout=5)

    try:
        if not client.connect():
            print("[!] Connection failed")
            return

        request = ReadHoldingRegistersRequest(
            address=register,
            count=args.count
        )

        # Recent pymodbus versions no longer accept slave/unit in the constructor.
        # It must be attached to the request object before execute().
        request.slave_id = args.slave

        # In pymodbus 3.12.x execute() expects: execute(slave_id, request)
        response = client.execute(args.slave, request)

        if response is None:
            print("[!] No response received from device")
            return

        if response.isError():
            print(f"[!] Modbus exception returned: {response}")
            return

        if not hasattr(response, "registers"):
            print(f"[!] Unexpected response object: {response}")
            return

        regs = response.registers
        print(f"[+] Raw registers: {regs}")

        if len(regs) >= 2:
            try:
                value_big = client.convert_from_registers(
                    regs[:2],
                    data_type=client.DATATYPE.FLOAT32,
                    word_order="big"
                )
                print(f"[+] Float32 (big word order): {value_big}")
            except Exception as e:
                print(f"[!] Failed to decode big-endian Float32: {e}")

            try:
                value_little = client.convert_from_registers(
                    regs[:2],
                    data_type=client.DATATYPE.FLOAT32,
                    word_order="little"
                )
                print(f"[+] Float32 (little word order): {value_little}")
            except Exception as e:
                print(f"[!] Failed to decode little-endian Float32: {e}")

        if len(regs) == 1:
            print(f"[+] UINT16 value: {regs[0]}")

    except Exception as e:
        print(f"[!] Script error: {e}")

    finally:
        client.close()
        print("[*] Connection closed")


if __name__ == "__main__":
    main()
