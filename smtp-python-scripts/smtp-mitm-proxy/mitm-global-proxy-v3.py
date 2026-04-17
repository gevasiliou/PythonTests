#!/usr/bin/env python3
import socket, ssl, threading, argparse, sys, signal, datetime, os, time, ipaddress

# ANSI Colors
RED, BLUE, GREEN, YELLOW, CYAN, MAGENTA, RESET = (
    '\033[91m','\033[94m','\033[92m','\033[93m','\033[96m','\033[95m','\033[0m'
)

CERTFILE = 'cert.pem'
KEYFILE = 'key.pem'
RULEFILE = 'rm-proxy-ip-list'

connection_count = 0
counter_lock = threading.Lock()

WHITELIST = []
BLACKLIST = []
rules_mtime = 0
rules_lock = threading.Lock()

def get_ts():
    return datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]

def signal_handler(sig, frame):
    print(f"\n{GREEN}[*] Titan Proxy Shutting down...{RESET}")
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

def parse_rule(line):
    parts = line.split()
    if len(parts) != 2:
        return None, None
    action, value = parts
    try:
        if "/" in value:
            obj = ipaddress.ip_network(value, strict=False)
        else:
            obj = ipaddress.ip_address(value)
        return action, obj
    except:
        return None, None

def load_rules():
    global WHITELIST, BLACKLIST, rules_mtime
    try:
        mtime = os.path.getmtime(RULEFILE)
        if mtime != rules_mtime:
            new_white = []
            new_black = []
            with open(RULEFILE) as f:
                for line in f:
                    #line = line.strip()
                    line = line.split("#", 1)[0].strip()
                    if not line or line.startswith("#"):
                        continue
                    action, obj = parse_rule(line)
                    if action == "allow" and obj:
                        new_white.append(obj)
                    elif action == "block" and obj:
                        new_black.append(obj)
            with rules_lock:
                WHITELIST = new_white
                BLACKLIST = new_black
                rules_mtime = mtime
            print(f"{YELLOW}[!] Rules reloaded: {len(WHITELIST)} allow, {len(BLACKLIST)} block{RESET}")
    except FileNotFoundError:
        pass

def rules_watcher():
    while True:
        load_rules()
        time.sleep(5)

def ip_in_list(ip, lst):
    for rule in lst:
        if isinstance(rule, ipaddress.IPv4Address):
            if ip == rule:
                return True
        else:
            if ip in rule:
                return True
    return False

def check_rules(ip_str):
    ip = ipaddress.ip_address(ip_str)
    with rules_lock:
        if ip_in_list(ip, WHITELIST):
            return "ALLOW"
        if ip_in_list(ip, BLACKLIST):
            return "BLOCK"
    return "ALLOW"

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
            if not data:
                break
            print(f"{color}[{get_ts()}] [ID:#{conn_id}] ({client_ip}) {label}:{RESET}")
            if show_hex:
                print(format_hexdump(data))
            else:
                msg = data.decode(errors='ignore').strip()
                if msg:
                    print(f"{color}{msg}{RESET}")
            destination.sendall(data)
    except:
        pass

def bridge(client_sock, addr, client_ip, remote_host, remote_port, force_ssl, show_hex, conn_id):
    global connection_count
    print(f"{GREEN}[+] [ID:#{conn_id}] CONNECTED: {addr[0]} (Active: {connection_count}){RESET}")

    remote_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        remote_sock.connect((remote_host, remote_port))

        if force_ssl:
            ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
            ctx.load_cert_chain(certfile=CERTFILE, keyfile=KEYFILE)
            c_conn = ctx.wrap_socket(client_sock, server_side=True)
            r_conn = ssl._create_unverified_context().wrap_socket(remote_sock, server_hostname=remote_host)
        else:
            c_conn, r_conn = client_sock, remote_sock

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
        print(f"{MAGENTA}[-] [ID:#{conn_id}] DISCONNECTED {client_ip} (Active: {connection_count}){RESET}")
        for s in (client_sock, remote_sock):
            try: s.close()
            except: pass

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Titan v13 Transparent Proxy")
    parser.add_argument("--listenport", type=int, required=True)
    parser.add_argument("--remoteserver", required=True)
    parser.add_argument("--remoteport", type=int, required=True)
    parser.add_argument("--ssl", action="store_true")
    parser.add_argument("--hexdump", action="store_true")
    args = parser.parse_args()

    load_rules()
    threading.Thread(target=rules_watcher, daemon=True).start()

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', args.listenport))
    server.listen(100)

    total_conn_ever = 0
    print(f"{GREEN}[*] TITAN v13 ACTIVE: {args.listenport} -> {args.remoteserver}:{args.remoteport}{RESET}")

    while True:
        c, a = server.accept()
        client_ip = a[0]

        decision = check_rules(client_ip)

        if decision == "BLOCK":
            print(f"{RED}[{get_ts()}] BLOCKED ATTEMPT from {client_ip}{RESET}")
            try:
                c.shutdown(socket.SHUT_RDWR)
            except:
                pass
            c.close()
            continue

        total_conn_ever += 1
        with counter_lock:
            connection_count += 1

        threading.Thread(
            target=bridge,
            args=(c, a, a[0], args.remoteserver, args.remoteport, args.ssl, args.hexdump, total_conn_ever),
            daemon=True
        ).start()
        
