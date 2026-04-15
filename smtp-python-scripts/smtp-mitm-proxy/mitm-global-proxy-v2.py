#!/usr/bin/env python3
import socket, ssl, threading, base64, re, argparse, sys, signal, datetime

# ANSI Colors
RED, BLUE, GREEN, YELLOW, CYAN, MAGENTA, RESET = '\033[91m', '\033[94m', '\033[92m', '\033[93m', '\033[96m', '\033[95m', '\033[0m'
CERTFILE = 'cert.pem'
KEYFILE = 'key.pem'

# Global counter for active connections
connection_count = 0
counter_lock = threading.Lock()

def get_ts():
    return datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]

def signal_handler(sig, frame):
    print(f"\n{GREEN}[*] Titan Proxy Shutting down...{RESET}")
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

def format_hexdump(data):
    lines = []
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        hex_part = " ".join(f"{b:02x}" for b in chunk)
        ascii_part = "".join(chr(b) if 32 <= b <= 126 else "." for b in chunk)
        lines.append(f"{CYAN}{i:04x}  {hex_part:<48}  |{ascii_part}|{RESET}")
    return "\n".join(lines)

def pipe(source, destination, label, color, conn_id, show_hex, client_ip):
    try:
        while True:
            data = source.recv(8192)
            if not data: break
            
            msg = data.decode(errors='ignore').strip()
            if msg:
                # Included Connection ID [ID: #] for tracking multi-resource loads
                print(f"{color}[{get_ts()}] [ID:#{conn_id}] ({client_ip}) {label}:{RESET}")
                if show_hex: print(format_hexdump(data))
                else: print(f"{color}{msg}{RESET}")
            
            destination.sendall(data)
    except: pass

def bridge(client_sock, addr, remote_host, remote_port, force_ssl, show_hex, conn_id):
    global connection_count
    print(f"{GREEN}[+] [ID:#{conn_id}] CONNECTED: {addr[0]} (Active: {connection_count}){RESET}")
    
    remote_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        remote_sock.connect((remote_host, remote_port))
        
        # SSL Mode (Direct)
        if force_ssl:
            ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
            ctx.load_cert_chain(certfile=CERTFILE, keyfile=KEYFILE)
            c_conn = ctx.wrap_socket(client_sock, server_side=True)
            r_conn = ssl._create_unverified_context().wrap_socket(remote_sock, server_hostname=remote_host)
        else:
            c_conn, r_conn = client_sock, remote_sock

        # START THE TUNNEL
        t1 = threading.Thread(target=pipe, args=(c_conn, r_conn, "CLIENT->REMOTE", BLUE, conn_id, show_hex, addr[0]), daemon=True)
        t2 = threading.Thread(target=pipe, args=(r_conn, c_conn, "REMOTE->CLIENT", RED, conn_id, show_hex, addr[0]), daemon=True)
        
        t1.start()
        t2.start()
        t1.join()
        t2.join()

    except Exception as e:
        print(f"{RED}[!] [ID:#{conn_id}] Error: {e}{RESET}")
    finally:
        with counter_lock:
            connection_count -= 1
        print(f"{MAGENTA}[-] [ID:#{conn_id}] DISCONNECTED (Active: {connection_count}){RESET}")
        for s in [client_sock, remote_sock]:
            try: s.close()
            except: pass

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Titan v11 Transparent Proxy")
    parser.add_argument("--listenport", type=int, required=True)
    parser.add_argument("--remoteserver", required=True)
    parser.add_argument("--remoteport", type=int, required=True)
    parser.add_argument("--ssl", action="store_true")
    parser.add_argument("--hexdump", action="store_true")
    
    args = parser.parse_args()
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', args.listenport))
    server.listen(100) # Higher backlog for web resources
    
    total_conn_ever = 0
    print(f"{GREEN}[*] TITAN v11 ACTIVE: {args.listenport} -> {args.remoteserver}:{args.remoteport}{RESET}")

    while True:
        c, a = server.accept()
        total_conn_ever += 1
        with counter_lock:
            connection_count += 1
        threading.Thread(target=bridge, args=(c, a, args.remoteserver, args.remoteport, args.ssl, args.hexdump, total_conn_ever), daemon=True).start()
