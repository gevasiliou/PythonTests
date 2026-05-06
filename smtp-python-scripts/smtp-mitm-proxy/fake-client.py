#!/usr/bin/env python3
"""
Titan Test Client — enhanced multi-connection tester with interactive CLI.

Creates multiple connections to Titan proxy, holds them open,
optionally sends periodic data, and allows interactive control.

Usage:
    python3 titan-test-client.py --connectto 127.0.0.1 --port 445
    python3 titan-test-client.py --connectto 127.0.0.1 --port 445 --count 5 --interval 2 --send-interval 30

Interactive commands:
    list                — show all active connections
    history             — show recently disconnected connections
    close <ID>          — close a specific connection by ID
    closeall            — close all connections
    reconnect <ID>      — reconnect a previously disconnected connection (restores original send_interval)
    send <ID> <message> — send a message on a specific connection
    sendall <message>   — send a message on all connections
    connect             — open one more connection with default send_interval
    quit                — close all and exit
"""

import socket
import time
import argparse
import threading
import datetime
import sys

# ANSI Colors
RED, GREEN, YELLOW, CYAN, MAGENTA, RESET = (
    '\033[91m', '\033[92m', '\033[93m', '\033[96m', '\033[95m', '\033[0m'
)

CONNECTIONS = {}   # {conn_id: {"socket", "addr", "connected_ts", "send_interval"}}
conn_lock = threading.Lock()

# Remembers send_interval and disconnected_ts for reconnect <ID>
DISCONNECTED_HISTORY = {}  # {conn_id: {"send_interval": int, "disconnected_ts": str}}
history_lock = threading.Lock()

conn_counter = 0
counter_lock = threading.Lock()

TARGET_HOST = None
TARGET_PORT = None
DEFAULT_SEND_INTERVAL = 0


def get_ts():
    return datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]


def hold_connection(sock, conn_id):
    """Hold connection open, send periodic data if send_interval > 0."""
    try:
        while True:
            with conn_lock:
                info = CONNECTIONS.get(conn_id)
                if not info:
                    break
                send_interval = info.get("send_interval", 0)

            if send_interval > 0:
                try:
                    msg = f"[titan-test-client] hello-from-conn-{conn_id}\n".encode()
                    sock.sendall(msg)
                    print(f"{CYAN}[{get_ts()}][#{conn_id}] SENT: hello-from-conn-{conn_id}{RESET}")
                except Exception:
                    break
                time.sleep(send_interval)
            else:
                time.sleep(1)

    except Exception:
        pass
    finally:
        with conn_lock:
            info = CONNECTIONS.pop(conn_id, None)

        try:
            sock.close()
        except Exception:
            pass

        if info is not None:
            # Record in history so reconnect <ID> can restore send_interval
            with history_lock:
                DISCONNECTED_HISTORY[conn_id] = {
                    "send_interval": info.get("send_interval", 0),
                    "disconnected_ts": get_ts(),
                }
            print(f"{RED}[{get_ts()}][-] Connection #{conn_id} — closed or error. "
                  f"Active: {len(CONNECTIONS)} "
                  f"(use 'reconnect {conn_id}' to reconnect){RESET}")


def recv_loop(sock, conn_id):
    """Receive and print any data from server."""
    try:
        while True:
            data = sock.recv(8192)
            if not data:
                break
            msg = data.decode(errors='ignore').strip()
            if msg:
                print(f"{MAGENTA}[{get_ts()}][#{conn_id}] RECV: {msg}{RESET}")
    except Exception:
        pass


def make_connection(send_interval=None, forced_id=None):
    """
    Open a new connection.
    forced_id: if provided, reuse this ID (for reconnect command).
    """
    global conn_counter
    if send_interval is None:
        send_interval = DEFAULT_SEND_INTERVAL

    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((TARGET_HOST, TARGET_PORT))
    except Exception as e:
        print(f"{RED}[!] Failed to connect: {e}{RESET}")
        return None

    if forced_id is not None:
        conn_id = forced_id
    else:
        with counter_lock:
            conn_counter += 1
            conn_id = conn_counter

    connected_ts = get_ts()

    with conn_lock:
        CONNECTIONS[conn_id] = {
            "socket":        s,
            "addr":          f"{TARGET_HOST}:{TARGET_PORT}",
            "connected_ts":  connected_ts,
            "send_interval": send_interval,
        }

    # Remove from disconnected history if reconnecting
    with history_lock:
        DISCONNECTED_HISTORY.pop(conn_id, None)

    t1 = threading.Thread(target=hold_connection, args=(s, conn_id), daemon=True)
    t2 = threading.Thread(target=recv_loop,       args=(s, conn_id), daemon=True)
    t1.start()
    t2.start()

    if send_interval > 0:
        print(f"{GREEN}[{get_ts()}][+] Connection #{conn_id} established to "
              f"{TARGET_HOST}:{TARGET_PORT} (send every {send_interval}s){RESET}")
    else:
        print(f"{GREEN}[{get_ts()}][+] Connection #{conn_id} established to "
              f"{TARGET_HOST}:{TARGET_PORT} (no periodic send){RESET}")

    return conn_id


def cmd_list():
    with conn_lock:
        if not CONNECTIONS:
            print(f"{YELLOW}[*] No active connections{RESET}")
            return
        print(f"\n{'ID':<6} {'Target':<25} {'Send Interval':<15} {'Connected'}")
        print("-" * 70)
        for cid, info in sorted(CONNECTIONS.items()):
            si     = info.get("send_interval", 0)
            si_str = f"{si}s" if si > 0 else "none"
            print(f"{cid:<6} {info['addr']:<25} {si_str:<15} {info['connected_ts']}")
        print()


def cmd_history():
    with history_lock:
        if not DISCONNECTED_HISTORY:
            print(f"{YELLOW}[*] No disconnected connections in history{RESET}")
            return
        print(f"\n{'ID':<6} {'Send Interval':<15} {'Disconnected'}")
        print("-" * 50)
        for cid, info in sorted(DISCONNECTED_HISTORY.items()):
            si     = info.get("send_interval", 0)
            si_str = f"{si}s" if si > 0 else "none"
            print(f"{cid:<6} {si_str:<15} {info['disconnected_ts']}")
        print()


def cmd_close(conn_id):
    with conn_lock:
        info = CONNECTIONS.get(conn_id)
        if not info:
            print(f"{RED}[!] Connection #{conn_id} not found{RESET}")
            return
        sock = info["socket"]
        del CONNECTIONS[conn_id]

    # Operator-initiated close — do NOT add to DISCONNECTED_HISTORY
    # (reconnect should only be available for unexpected disconnects,
    #  but we still store it so the user CAN reconnect if they want)
    with history_lock:
        DISCONNECTED_HISTORY[conn_id] = {
            "send_interval": info.get("send_interval", 0),
            "disconnected_ts": get_ts(),
        }

    try:
        sock.shutdown(socket.SHUT_RDWR)
    except Exception:
        pass
    try:
        sock.close()
    except Exception:
        pass
    print(f"{MAGENTA}[{get_ts()}][!] Connection #{conn_id} closed by operator "
          f"(use 'reconnect {conn_id}' to reconnect){RESET}")


def cmd_closeall():
    with conn_lock:
        ids   = list(CONNECTIONS.keys())
        items = {cid: info for cid, info in CONNECTIONS.items()}
        CONNECTIONS.clear()

    for cid, info in items.items():
        sock = info["socket"]
        with history_lock:
            DISCONNECTED_HISTORY[cid] = {
                "send_interval": info.get("send_interval", 0),
                "disconnected_ts": get_ts(),
            }
        try:
            sock.shutdown(socket.SHUT_RDWR)
        except Exception:
            pass
        try:
            sock.close()
        except Exception:
            pass
        print(f"{MAGENTA}[{get_ts()}][!] Connection #{cid} closed{RESET}")

    if ids:
        print(f"{YELLOW}[*] Closed {len(ids)} connection(s){RESET}")
    else:
        print(f"{YELLOW}[*] No active connections to close{RESET}")


def cmd_reconnect(conn_id):
    # Check not already active
    with conn_lock:
        if conn_id in CONNECTIONS:
            print(f"{YELLOW}[!] Connection #{conn_id} is already active{RESET}")
            return

    # Look up send_interval from history
    with history_lock:
        history = DISCONNECTED_HISTORY.get(conn_id)

    if history is None:
        print(f"{RED}[!] No history found for connection #{conn_id} — "
              f"use 'connect' to open a new connection{RESET}")
        return

    send_interval = history.get("send_interval", DEFAULT_SEND_INTERVAL)
    print(f"{YELLOW}[*] Reconnecting #{conn_id} with send_interval={send_interval}s...{RESET}")
    make_connection(send_interval=send_interval)


def cmd_send(conn_id, message):
    with conn_lock:
        info = CONNECTIONS.get(conn_id)
        if not info:
            print(f"{RED}[!] Connection #{conn_id} not found{RESET}")
            return
        sock = info["socket"]

    try:
        sock.sendall(f"{message}\n".encode())
        print(f"{CYAN}[{get_ts()}][#{conn_id}] SENT: {message}{RESET}")
    except Exception as e:
        print(f"{RED}[!] Send failed on #{conn_id}: {e}{RESET}")


def cmd_sendall(message):
    with conn_lock:
        items = [(cid, info["socket"]) for cid, info in CONNECTIONS.items()]

    if not items:
        print(f"{YELLOW}[*] No active connections{RESET}")
        return

    for cid, sock in items:
        try:
            sock.sendall(f"{message}\n".encode())
            print(f"{CYAN}[{get_ts()}][#{cid}] SENT: {message}{RESET}")
        except Exception as e:
            print(f"{RED}[!] Send failed on #{cid}: {e}{RESET}")


def initial_connect_loop(count, interval, send_interval):
    for i in range(count):
        make_connection(send_interval)
        if i < count - 1:
            time.sleep(interval)
    print(f"\n{GREEN}[*] All {count} connections created.{RESET}")
    print(f"{CYAN}Commands: list | history | close <ID> | closeall | "
          f"reconnect <ID> | send <ID> <msg> | sendall <msg> | connect | quit{RESET}\n")


def interactive_loop():
    while True:
        try:
            line = input("fake-client > ").strip()
        except (EOFError, KeyboardInterrupt):
            print(f"\n{GREEN}[*] Closing all and exiting...{RESET}")
            cmd_closeall()
            sys.exit(0)

        if not line:
            continue

        parts = line.split(None, 2)
        cmd   = parts[0].lower()

        if cmd == "list":
            cmd_list()

        elif cmd == "history":
            cmd_history()

        elif cmd == "close":
            if len(parts) < 2:
                print(f"{RED}[!] Usage: close <ID>{RESET}")
                continue
            try:
                cmd_close(int(parts[1]))
            except ValueError:
                print(f"{RED}[!] ID must be an integer{RESET}")

        elif cmd == "closeall":
            cmd_closeall()

        elif cmd == "reconnect":
            if len(parts) < 2:
                print(f"{RED}[!] Usage: reconnect <ID>{RESET}")
                continue
            try:
                cmd_reconnect(int(parts[1]))
            except ValueError:
                print(f"{RED}[!] ID must be an integer{RESET}")

        elif cmd == "send":
            if len(parts) < 3:
                print(f"{RED}[!] Usage: send <ID> <message>{RESET}")
                continue
            try:
                cmd_send(int(parts[1]), parts[2])
            except ValueError:
                print(f"{RED}[!] ID must be an integer{RESET}")

        elif cmd == "sendall":
            if len(parts) < 2:
                print(f"{RED}[!] Usage: sendall <message>{RESET}")
                continue
            cmd_sendall(parts[1] if len(parts) == 2 else " ".join(parts[1:]))

        elif cmd == "connect":
            make_connection()

        elif cmd == "quit":
            print(f"{GREEN}[*] Closing all and exiting...{RESET}")
            cmd_closeall()
            sys.exit(0)

        else:
            print(f"{RED}[!] Unknown command: {cmd}{RESET}")
            print(f"{CYAN}Commands: list | history | close <ID> | closeall | "
                  f"reconnect <ID> | send <ID> <msg> | sendall <msg> | connect | quit{RESET}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Titan Test Client — interactive multi-connection tester")
    parser.add_argument("--connectto",     required=True,
                        help="Target IP or hostname")
    parser.add_argument("--port",          type=int, required=True,
                        help="Target port")
    parser.add_argument("--count",         type=int, default=5,
                        help="Number of initial connections (default=5)")
    parser.add_argument("--interval",      type=int, default=2,
                        help="Seconds between connections (default=2)")
    parser.add_argument("--send-interval", type=int, default=0,
                        help="Seconds between periodic sends per connection (0=disabled, default=0)")
    args = parser.parse_args()

    TARGET_HOST           = args.connectto
    TARGET_PORT           = args.port
    DEFAULT_SEND_INTERVAL = args.send_interval

    print(f"{GREEN}[{get_ts()}][*] Titan Test Client starting{RESET}")
    print(f"{CYAN}[{get_ts()}][*] Target: {TARGET_HOST}:{TARGET_PORT} | "
          f"Connections: {args.count} | "
          f"Interval: {args.interval}s | "
          f"Send interval: {args.send_interval}s{RESET}")

    t = threading.Thread(
        target=initial_connect_loop,
        args=(args.count, args.interval, args.send_interval),
        daemon=True
    )
    t.start()
    t.join()

    interactive_loop()
