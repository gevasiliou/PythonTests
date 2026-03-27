#!/usr/bin/env python3
import socket
import select
import datetime
import argparse
import sys

# ANSI Colors for terminal visibility
RED = '\033[91m'
BLUE = '\033[94m'
RESET = '\033[0m'
GREEN = '\033[92m'

def get_ts():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def get_local_ip():
    """Auto-detect the local IP address by checking the route to Google DNS."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

def start_bridge(listen_port, remote_host, remote_port):
    local_ip = get_local_ip()
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind((local_ip, listen_port))
    except PermissionError:
        print(f"{RED}[!] Error: Permission denied. Please run with 'sudo'.{RESET}")
        sys.exit(1)
        
    server.listen(1)
    print(f"{GREEN}[*] Proxy Active on {local_ip}:{listen_port}{RESET}")
    print(f"{GREEN}[*] Forwarding to {remote_host}:{remote_port}{RESET}")

    while True:
        print(f"\n[*] Waiting for PLC... [{get_ts()}]")
        plc_sock, addr = server.accept()
        print(f"{GREEN}[+] PLC CONNECTED: {addr[0]} at {get_ts()}{RESET}")
        
        try:
            remote_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote_sock.connect((remote_host, remote_port))
            print(f"{GREEN}[+] REMOTE SERVER CONNECTED{RESET}")

            sockets = [plc_sock, remote_sock]
            while True:
                readable, _, _ = select.select(sockets, [], [], 1.0)
                for s in readable:
                    data = s.recv(4096)
                    if not data: raise Exception("Connection closed by peer")
                    
                    msg = data.decode(errors='replace').strip()
                    if s is plc_sock:
                        print(f"{RED}PLC -> REMOTE: {msg}{RESET}")
                        remote_sock.sendall(data)
                    else:
                        print(f"{BLUE}REMOTE -> PLC: {msg}{RESET}")
                        plc_sock.sendall(data)
        except Exception as e:
            print(f"[-] Connection Terminated: {e}")
        finally:
            plc_sock.close()
            remote_sock.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="SMTP Troubleshooting Proxy")
    parser.add_argument("--listenport", type=int, default=587, help="Port to listen on (default: 587)")
    parser.add_argument("--remoteserver", help="Remote SMTP server hostname (REQUIRED)")
    parser.add_argument("--remoteport", type=int, default=587, help="Remote SMTP port (default: 587)")

    # Print help automatically if no arguments are provided
    if len(sys.argv) == 1:
        print("--- SMTP Proxy Debugger ---")
        parser.print_help()
        sys.exit(0)

    args = parser.parse_args()
    
    if not args.remoteserver:
        print(f"{RED}[!] Error: --remoteserver is required.{RESET}")
        parser.print_help()
        sys.exit(1)
        
    start_bridge(args.listenport, args.remoteserver, args.remoteport)
