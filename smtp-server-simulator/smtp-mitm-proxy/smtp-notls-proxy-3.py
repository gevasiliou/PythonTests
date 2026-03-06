#!/usr/bin/env python3
import socket
import select
import datetime
import argparse
import sys
import signal
import base64
import re

# ANSI Colors
RED = '\033[91m'
BLUE = '\033[94m'
RESET = '\033[0m'
GREEN = '\033[92m'

def get_ts():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def try_decode_base64(data):
    """Attempt to decode Base64 strings, return None if not valid."""
    # Base64 regex pattern
    pattern = re.compile(r'^[A-Za-z0-9+/]+={0,2}$')
    if pattern.match(data) and len(data) > 4:
        try:
            return base64.b64decode(data).decode('utf-8')
        except:
            return None
    return None

def start_bridge(listen_port, remote_host, remote_port):
    listen_ip = '0.0.0.0'
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    def signal_handler(sig, frame):
        print(f"\n{GREEN}[*] Shutting down...{RESET}")
        server.close()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    
    server.bind((listen_ip, listen_port))
    server.listen(5)
    print(f"{GREEN}[*] Proxy Active on ALL INTERFACES:{listen_port}{RESET}")
    print(f"{GREEN}[*] Forwarding to {remote_host}:{remote_port}{RESET}")

    while True:
        plc_sock, addr = server.accept()
        print(f"\n{GREEN}[+] PLC CONNECTED: {addr[0]} at {get_ts()}{RESET}", flush=True)
        
        try:
            remote_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote_sock.connect((remote_host, remote_port))
            
            sockets = [plc_sock, remote_sock]
            while True:
                readable, _, _ = select.select(sockets, [], [], 0.1)
                for s in readable:
                    data = s.recv(4096)
                    if not data: raise Exception("Connection closed")
                    
                    msg = data.decode(errors='replace').strip()
                    if s is plc_sock:
                        print(f"{RED}PLC -> REMOTE: {msg}{RESET}", flush=True)
                        # Check for Base64 and decode
                        decoded = try_decode_base64(msg)
                        if decoded:
                            print(f"{GREEN}   [DECODED]: {decoded}{RESET}", flush=True)
                        remote_sock.sendall(data)
                    else:
                        print(f"{BLUE}REMOTE -> PLC: {msg}{RESET}", flush=True)
                        # Some server responses contain encoded challenges
                        decoded = try_decode_base64(msg)
                        if decoded:
                            print(f"{GREEN}   [DECODED]: {decoded}{RESET}", flush=True)
                        plc_sock.sendall(data)
        except Exception as e:
            print(f"[-] Connection Terminated: {e}", flush=True)
        finally:
            plc_sock.close()
            remote_sock.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="SMTP Troubleshooting Proxy with Base64 Decoding")
    parser.add_argument("--listenport", type=int, default=587)
    parser.add_argument("--remoteserver", required=True)
    parser.add_argument("--remoteport", type=int, default=587)
    args = parser.parse_args()
    start_bridge(args.listenport, args.remoteserver, args.remoteport)
