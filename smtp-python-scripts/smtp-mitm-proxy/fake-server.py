#!/usr/bin/env python3
"""
Titan Test Server — fake multi-connection TCP server for testing Titan v16.

Accepts multiple simultaneous connections, holds them all open,
and allows closing specific connections on demand.

Usage:
    python3 titan-test-server.py --port 4450

Interactive commands (type and press Enter):
    list         — show all active connections
    close <ID>   — close a specific connection by ID
    closeall     — close all connections
    quit         — shut down the server
"""

import socket
import threading
import argparse
import datetime
import sys

# ANSI Colors
RED, GREEN, YELLOW, CYAN, MAGENTA, RESET = (
    '\033[91m', '\033[92m', '\033[93m', '\033[96m', '\033[95m', '\033[0m'
)

CONNECTIONS = {}   # {conn_id: {"socket": sock, "addr": addr, "connected_ts": ts}}
conn_lock = threading.Lock()
conn_counter = 0
counter_lock = threading.Lock()


def get_ts():
    return datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]


def handle_client(sock, addr, conn_id):
    """Receive data and print it. Hold connection open until explicitly closed."""
    print(f"{GREEN}[{get_ts()}][+] Connection #{conn_id} from {addr[0]}:{addr[1]}{RESET}")
    try:
        while True:
            data = sock.recv(8192)
            if not data:
                print(f"{YELLOW}[{get_ts()}][-] Connection #{conn_id} — client closed{RESET}")
                break
            msg = data.decode(errors='ignore').strip()
            if msg:
                print(f"{CYAN}[{get_ts()}][#{conn_id}] DATA: {msg}{RESET}")
    except Exception as e:
        # Only print if it wasn't a deliberate close
        with conn_lock:
            still_active = conn_id in CONNECTIONS
        if still_active:
            print(f"{YELLOW}[{get_ts()}][-] Connection #{conn_id} — exception: {e}{RESET}")
    finally:
        with conn_lock:
            CONNECTIONS.pop(conn_id, None)
        try:
            sock.close()
        except Exception:
            pass
        print(f"{RED}[{get_ts()}][-] Connection #{conn_id} removed. Active: {len(CONNECTIONS)}{RESET}")


def accept_loop(server_sock):
    global conn_counter
    while True:
        try:
            sock, addr = server_sock.accept()
        except Exception:
            break

        with counter_lock:
            conn_counter += 1
            conn_id = conn_counter

        connected_ts = get_ts()

        with conn_lock:
            CONNECTIONS[conn_id] = {
                "socket": sock,
                "addr": addr,
                "connected_ts": connected_ts,
            }

        t = threading.Thread(target=handle_client, args=(sock, addr, conn_id), daemon=True)
        t.start()


def cmd_list():
    with conn_lock:
        if not CONNECTIONS:
            print(f"{YELLOW}[*] No active connections{RESET}")
            return
        print(f"\n{'ID':<6} {'IP':<20} {'Port':<8} {'Connected'}")
        print("-" * 60)
        for cid, info in sorted(CONNECTIONS.items()):
            ip   = info["addr"][0]
            port = info["addr"][1]
            ts   = info["connected_ts"]
            print(f"{cid:<6} {ip:<20} {port:<8} {ts}")
        print()


def cmd_close(conn_id):
    with conn_lock:
        info = CONNECTIONS.get(conn_id)
        if not info:
            print(f"{RED}[!] Connection #{conn_id} not found{RESET}")
            return
        sock = info["socket"]
        # Remove first so handle_client doesn't print spurious error
        del CONNECTIONS[conn_id]

    try:
        sock.shutdown(socket.SHUT_RDWR)
    except Exception:
        pass
    try:
        sock.close()
    except Exception:
        pass
    print(f"{MAGENTA}[{get_ts()}][!] Connection #{conn_id} closed by server{RESET}")


def cmd_closeall():
    with conn_lock:
        ids = list(CONNECTIONS.keys())
        socks = {cid: info["socket"] for cid, info in CONNECTIONS.items()}
        CONNECTIONS.clear()

    for cid, sock in socks.items():
        try:
            sock.shutdown(socket.SHUT_RDWR)
        except Exception:
            pass
        try:
            sock.close()
        except Exception:
            pass
        print(f"{MAGENTA}[{get_ts()}][!] Connection #{cid} closed by server{RESET}")

    if ids:
        print(f"{YELLOW}[*] Closed {len(ids)} connection(s){RESET}")
    else:
        print(f"{YELLOW}[*] No active connections to close{RESET}")


def interactive_loop():
    print(f"\n{CYAN}Commands: list | close <ID> | closeall | quit{RESET}\n")
    while True:
        try:
            line = input("fake-server > ").strip()
        except (EOFError, KeyboardInterrupt):
            print(f"\n{GREEN}[*] Shutting down...{RESET}")
            sys.exit(0)

        if not line:
            continue

        parts = line.split()
        cmd = parts[0].lower()

        if cmd == "list":
            cmd_list()

        elif cmd == "close":
            if len(parts) < 2:
                print(f"{RED}[!] Usage: close <ID>{RESET}")
                continue
            try:
                conn_id = int(parts[1])
            except ValueError:
                print(f"{RED}[!] ID must be an integer{RESET}")
                continue
            cmd_close(conn_id)

        elif cmd == "closeall":
            cmd_closeall()

        elif cmd == "quit":
            print(f"{GREEN}[*] Shutting down...{RESET}")
            sys.exit(0)

        else:
            print(f"{RED}[!] Unknown command: {cmd}{RESET}")
            print(f"{CYAN}Commands: list | close <ID> | closeall | quit{RESET}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Titan Test Server — fake multi-connection TCP server")
    parser.add_argument("--port", type=int, default=4450, help="Port to listen on (default: 4450)")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host to bind to (default: 0.0.0.0)")
    args = parser.parse_args()

    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_sock.bind((args.host, args.port))
    server_sock.listen(100)

    print(f"{GREEN}[{get_ts()}][*] Titan Test Server listening on {args.host}:{args.port}{RESET}")
    print(f"{CYAN}[{get_ts()}][*] Waiting for connections from Titan proxy...{RESET}")

    accept_thread = threading.Thread(target=accept_loop, args=(server_sock,), daemon=True)
    accept_thread.start()

    interactive_loop()
