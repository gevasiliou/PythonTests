#!/usr/bin/env python3
# Creates multiple connections to Titan with time difference 10 second.
# usage: 
# python3 multi_connect_test.py --connectto 127.0.0.1 --port 445
# python3 multi_connect_test.py --connectto 127.0.0.1 --port 445 --send-interval 5

import socket
import time
import argparse
import threading


def hold_connection(sock, conn_id, send_interval):
    try:
        while True:
            if send_interval > 0:
                msg = f"hello-from-{conn_id}\n".encode()
                sock.sendall(msg)
            time.sleep(send_interval if send_interval > 0 else 60)
    except Exception:
        pass
    finally:
        try:
            sock.close()
        except Exception:
            pass


def main():
    parser = argparse.ArgumentParser(description="Titan multi-connection tester - creates multiple connections to the same IP")
    parser.add_argument("--connectto", required=True, help="Target IP or hostname")
    parser.add_argument("--port", type=int, required=True, help="Target port")
    parser.add_argument("--count", type=int, default=5, help="Number of connections (default=5)")
    parser.add_argument("--interval", type=int, default=10, help="Seconds between connections (default=10)")
    parser.add_argument("--send-interval", type=int, default=0,
                        help="Seconds between keepalive messages (0 = no send, just hold open)")
    args = parser.parse_args()

    sockets = []

    print(f"[*] Starting test: {args.count} connections to {args.connectto}:{args.port}")
    print(f"[*] Interval between connections: {args.interval}s")

    for i in range(1, args.count + 1):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.connect((args.connectto, args.port))
            sockets.append(s)

            print(f"[+] Connection #{i} established")

            t = threading.Thread(
                target=hold_connection,
                args=(s, i, args.send_interval),
                daemon=True
            )
            t.start()

        except Exception as e:
            print(f"[!] Failed to connect #{i}: {e}")

        time.sleep(args.interval)

    print("[*] All connections created. Holding open... Press Ctrl+C to exit.")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n[*] Closing all sockets...")
        for s in sockets:
            try:
                s.close()
            except:
                pass


if __name__ == "__main__":
    main()
