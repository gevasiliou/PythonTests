#!/usr/bin/env python3
"""
Titan UDP - A lightweight UDP proxy / listener
Receives UDP datagrams, prints them (--hexdump / --ascii), and optionally
forwards them to a remote UDP server (--remoteserver / --remoteport).

Usage examples:
    # Listen only, hexdump output
    python titan_udp.py --port 162 --hexdump

    # Listen only, ascii output
    python titan_udp.py --port 162 --ascii

    # Both views at once
    python titan_udp.py --port 162 --hexdump --ascii

    # Listen + forward + hexdump
    python titan_udp.py --port 162 --remoteserver 192.168.1.100 --remoteport 162 --hexdump --verbose
"""

import socket
import argparse
import sys
import datetime


# ─────────────────────────────────────────────
#  Display Helpers
# ─────────────────────────────────────────────

def display_hexdump(data: bytes, sender_ip: str, sender_port: int) -> None:
    """Print data as classic hex dump: offset | hex bytes | ascii sidebar."""
    print(f"\n[UDP] {sender_ip}:{sender_port} → {len(data)} bytes")
    print(f"      {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    for offset in range(0, len(data), 16):
        chunk = data[offset:offset + 16]

        # Hex section — two groups of 8, separated by extra space
        hex_left  = " ".join(f"{b:02X}" for b in chunk[:8])
        hex_right = " ".join(f"{b:02X}" for b in chunk[8:])
        hex_part  = f"{hex_left:<23}  {hex_right:<23}"

        # ASCII sidebar — printable chars or dot
        ascii_part = "".join(chr(b) if 32 <= b < 127 else "." for b in chunk)

        print(f"  {offset:04X}  {hex_part}  |{ascii_part}|")

    print()


def display_ascii(data: bytes, sender_ip: str, sender_port: int) -> None:
    """Print data as ASCII — non-printable bytes shown as dots."""
    ascii_str = "".join(chr(b) if 32 <= b < 127 else "." for b in data)
    print(f"\n[UDP] {sender_ip}:{sender_port} → {len(data)} bytes")
    print(f"      {ascii_str}")
    print()


# ─────────────────────────────────────────────
#  Forwarding
# ─────────────────────────────────────────────

def forward_datagram(data: bytes, remote_host: str, remote_port: int, verbose: bool) -> None:
    """Send datagram to remote UDP server using a fresh socket."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as fwd_sock:
            fwd_sock.sendto(data, (remote_host, remote_port))
            if verbose:
                print(f"  [FWD] → {remote_host}:{remote_port}  ({len(data)} bytes)")
    except Exception as e:
        print(f"  [FWD ERROR] Could not forward to {remote_host}:{remote_port} — {e}")


# ─────────────────────────────────────────────
#  Main Listener Loop
# ─────────────────────────────────────────────

def run_listener(args: argparse.Namespace) -> None:
    """Bind to local UDP port and process incoming datagrams."""

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    try:
        sock.bind(("0.0.0.0", args.port))
    except PermissionError:
        print(f"[ERROR] Permission denied binding to port {args.port}.")
        print("        Ports below 1024 require root. Try: sudo python titan_udp.py ...")
        sys.exit(1)
    except OSError as e:
        print(f"[ERROR] Could not bind to port {args.port}: {e}")
        sys.exit(1)

    print(f"[Titan UDP] Listening on UDP port {args.port}")

    if args.remoteserver:
        print(f"[Titan UDP] Forwarding to {args.remoteserver}:{args.remoteport}")

    if args.hexdump:
        print("[Titan UDP] Output mode: hexdump")

    if args.ascii:
        print("[Titan UDP] Output mode: ascii")

    if not args.hexdump and not args.ascii:
        print("[Titan UDP] No output mode selected — use --hexdump or --ascii to see data")

    print("[Titan UDP] Waiting for datagrams... (Ctrl+C to stop)\n")

    try:
        while True:
            # 65535 is max UDP payload size
            data, (sender_ip, sender_port) = sock.recvfrom(65535)

            if args.verbose and not args.hexdump:
                print(f"[UDP] {sender_ip}:{sender_port} → {len(data)} bytes  "
                      f"@ {datetime.datetime.now().strftime('%H:%M:%S')}")

            if args.hexdump:
                display_hexdump(data, sender_ip, sender_port)

            if args.ascii:
                display_ascii(data, sender_ip, sender_port)

            if args.remoteserver:
                forward_datagram(data, args.remoteserver, args.remoteport, args.verbose)

    except KeyboardInterrupt:
        print("\n[Titan UDP] Stopped by user.")
    finally:
        sock.close()


# ─────────────────────────────────────────────
#  Argument Parsing
# ─────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Titan UDP — lightweight UDP proxy / listener",
        formatter_class=argparse.RawTextHelpFormatter
    )

    parser.add_argument(
        "--port", type=int, required=True,
        help="Local UDP port to listen on (e.g. 162 for SNMP traps)"
    )
    parser.add_argument(
        "--remoteserver", type=str, default=None,
        help="Remote host to forward datagrams to (optional)"
    )
    parser.add_argument(
        "--remoteport", type=int, default=None,
        help="Remote UDP port to forward to (required if --remoteserver is set)"
    )
    parser.add_argument(
        "--hexdump", action="store_true",
        help="Print received bytes as hex dump with ASCII sidebar"
    )
    parser.add_argument(
        "--ascii", action="store_true",
        help="Print received bytes as ASCII (non-printable shown as dots)"
    )
    parser.add_argument(
        "--verbose", action="store_true",
        help="Print sender IP, port and byte count for each datagram"
    )

    args = parser.parse_args()

    # Validate: --remoteport required when --remoteserver is given
    if args.remoteserver and not args.remoteport:
        parser.error("--remoteport is required when --remoteserver is specified")

    # Validate port range
    if not (1 <= args.port <= 65535):
        parser.error("--port must be between 1 and 65535")

    if args.remoteport and not (1 <= args.remoteport <= 65535):
        parser.error("--remoteport must be between 1 and 65535")

    return args


# ─────────────────────────────────────────────
#  Entry Point
# ─────────────────────────────────────────────

if __name__ == "__main__":
    args = parse_args()
    run_listener(args)
