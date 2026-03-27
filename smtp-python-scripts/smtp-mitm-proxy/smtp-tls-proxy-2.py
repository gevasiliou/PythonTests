#!/usr/bin/env python3
import socket, ssl, threading, base64, re, argparse, sys

# ANSI Colors
RED, BLUE, GREEN, RESET = '\033[91m', '\033[94m', '\033[92m', '\033[0m'
CERTFILE = 'cert.pem'
KEYFILE = 'key.pem'

def try_decode(data):
    pattern = re.compile(r'^[A-Za-z0-9+/]+={0,2}$')
    if pattern.match(data) and len(data) > 4:
        try: return base64.b64decode(data).decode('utf-8')
        except: return None
    return None

def bridge(client_sock, remote_host, remote_port):
    remote_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    remote_sock.connect((remote_host, remote_port))
    
    # Forward Initial Banner
    banner = remote_sock.recv(4096)
    client_sock.sendall(banner)
    
    while True:
        data = client_sock.recv(4096)
        if not data: break
        
        # Log Plaintext Request
        msg = data.decode(errors='ignore').strip()
        print(f"{RED}PLC -> REMOTE: {msg}{RESET}")
        decoded = try_decode(msg)
        if decoded: print(f"{GREEN}   [DECODED]: {decoded}{RESET}")

        if b"STARTTLS" in data.upper():
            remote_sock.sendall(data)
            # Read server's 220 response and forward to client
            server_resp = remote_sock.recv(4096)
            client_sock.sendall(server_resp)
            
            # Upgrade to SSL (Server side for Teltonika)
            context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
            context.load_cert_chain(certfile=CERTFILE, keyfile=KEYFILE)
            client_ssl = context.wrap_socket(client_sock, server_side=True)
            
            # Upgrade to SSL (Client side for Mail Server)
            client_ctx = ssl._create_unverified_context()
            remote_ssl = client_ctx.wrap_socket(remote_sock, server_hostname=remote_host)
            
            # Encrypted Relay Loop
            while True:
                # 1. Client to Server
                data = client_ssl.recv(4096)
                if not data: break
                msg = data.decode(errors='ignore').strip()
                print(f"{BLUE}DEC (PLC->REMOTE): {msg}{RESET}")
                decoded = try_decode(msg)
                if decoded: print(f"{GREEN}   [DECODED]: {decoded}{RESET}")
                remote_ssl.sendall(data)
                
                # 2. Server to Client
                resp = remote_ssl.recv(4096)
                if resp:
                    resp_msg = resp.decode(errors='ignore').strip()
                    print(f"{RED}DEC (REMOTE->PLC): {resp_msg}{RESET}")
                    decoded_resp = try_decode(resp_msg)
                    if decoded_resp: print(f"{GREEN}   [DECODED]: {decoded_resp}{RESET}")
                    client_ssl.sendall(resp)
            break
        else:
            remote_sock.sendall(data)
            client_sock.sendall(remote_sock.recv(4096))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Professional TLS SMTP Proxy")
    parser.add_argument("--listenport", type=int, default=587)
    parser.add_argument("--remoteserver", required=True)
    parser.add_argument("--remoteport", type=int, default=587)
    args = parser.parse_args()

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(('0.0.0.0', args.listenport))
    except PermissionError:
        print(f"{RED}Error: Run with sudo for port {args.listenport}{RESET}")
        sys.exit(1)
        
    server.listen(5)
    print(f"{GREEN}[*] TLS SMTP Proxy Active: 0.0.0.0:{args.listenport} -> {args.remoteserver}:{args.remoteport}{RESET}")

    while True:
        client, addr = server.accept()
        threading.Thread(target=bridge, args=(client, args.remoteserver, args.remoteport)).start()
