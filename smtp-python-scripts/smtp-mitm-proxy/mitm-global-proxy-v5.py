#!/usr/bin/env python3
import socket, ssl, threading, argparse, sys, signal, datetime, os, time, ipaddress, struct

# In this version of Titan , we have the IP allow/block logic reading IPs from a local file
# We also have the new switch --tcp-sniff that will print tcp handshakes even without payload.
# new feature: when an IP is blocked in the local file rm-proxy-ip-list then the script forces disconnection of this IP 
# if connected on the next rule reload by evaluating only the new block entries inserted into ip-list file. 

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
OLD_BLACKLIST = []
rules_mtime = 0
rules_lock = threading.Lock()

ACTIVE_CONNECTIONS = {}
active_lock = threading.Lock()

def get_ts():
    return datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]

def signal_handler(sig, frame):
    print(f"\n{GREEN}[{get_ts()}][*] Titan Proxy Shutting down...{RESET}")
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

# ---------------------------
# Forced Disconnect Engine
# ---------------------------

def disconnect_ip(ip_str):
    with active_lock:
        to_kill = [cid for cid, info in ACTIVE_CONNECTIONS.items() if info["ip"] == ip_str]

    for cid in to_kill:
        with active_lock:
            sock = ACTIVE_CONNECTIONS[cid]["socket"]
        try:
            sock.shutdown(socket.SHUT_RDWR)
        except:
            pass
        try:
            sock.close()
        except:
            pass

        print(f"{RED}[{get_ts()}][!] Forced disconnect of {ip_str} — newly added to block list{RESET}")

def load_rules():
    global WHITELIST, BLACKLIST, OLD_BLACKLIST, rules_mtime
    try:
        mtime = os.path.getmtime(RULEFILE)
        if mtime != rules_mtime:
            new_white = []
            new_black = []

            with open(RULEFILE) as f:
                for line in f:
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

                # Detect newly added blocked IPs
                newly_blocked = []
                for rule in BLACKLIST:
                    if rule not in OLD_BLACKLIST:
                        newly_blocked.append(rule)

                OLD_BLACKLIST = BLACKLIST.copy()
                rules_mtime = mtime

            print(f"{YELLOW}[{get_ts()}] [!] Rules reloaded: {len(WHITELIST)} allow, {len(BLACKLIST)} block{RESET}")

            # Forced disconnect for newly added blocked IPs
            for rule in newly_blocked:
                if isinstance(rule, ipaddress.IPv4Address):
                    disconnect_ip(str(rule))
                else:
                    # CIDR block
                    with active_lock:
                        for cid, info in ACTIVE_CONNECTIONS.items():
                            ip = ipaddress.ip_address(info["ip"])
                            if ip in rule:
                                disconnect_ip(info["ip"])

    except FileNotFoundError:
        pass

def rules_watcher():
    while True:
        load_rules()
        time.sleep(5)

# ---------------------------
# Hexdump
# ---------------------------

def format_hexdump(data):
    lines = []
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        hex_part = " ".join(f"{b:02x}" for b in chunk)
        ascii_part = "".join(chr(b) if 32 <= b <= 126 else "." for b in chunk)
        lines.append(f"{CYAN}{i:04x}  {hex_part:<48}  |{ascii_part}|{RESET}")
    return "\n".join(lines)

# ---------------------------
# Proxy Pipe
# ---------------------------

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

# ---------------------------
# Connection Bridge
# ---------------------------

def bridge(client_sock, addr, client_ip, remote_host, remote_port, force_ssl, show_hex, conn_id):
    global connection_count

    with active_lock:
        ACTIVE_CONNECTIONS[conn_id] = {"ip": client_ip, "socket": client_sock}

    print(f"{GREEN}[{get_ts()}][+] [ID:#{conn_id}] CONNECTED: {client_ip} (Active: {connection_count}){RESET}")

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

        t1 = threading.Thread(target=pipe, args=(c_conn, r_conn, "CLIENT->REMOTE", BLUE, conn_id, show_hex, client_ip), daemon=True)
        t2 = threading.Thread(target=pipe, args=(r_conn, c_conn, "REMOTE->CLIENT", RED, conn_id, show_hex, client_ip), daemon=True)

        t1.start()
        t2.start()
        t1.join()
        t2.join()

    except Exception as e:
        print(f"{RED}[{get_ts()}][!] [ID:#{conn_id}] Error: {e}{RESET}")

    finally:
        with counter_lock:
            connection_count -= 1

        with active_lock:
            ACTIVE_CONNECTIONS.pop(conn_id, None)

        print(f"{MAGENTA}[{get_ts()}][-] [ID:#{conn_id}] DISCONNECTED {client_ip} (Active: {connection_count}){RESET}")

        for s in (client_sock, remote_sock):
            try: s.close()
            except: pass

# ---------------------------
# AF_PACKET TCP Handshake Sniffer
# ---------------------------

def parse_ethernet_header(data):
    if len(data) < 14:
        return None, None, None
    dst_mac, src_mac, proto = struct.unpack('!6s6sH', data[:14])
    return dst_mac, src_mac, proto

def parse_ipv4_header(data):
    if len(data) < 20:
        return None
    ver_ihl = data[0]
    ihl = (ver_ihl & 0x0F) * 4
    if len(data) < ihl:
        return None
    iph = struct.unpack('!BBHHHBBH4s4s', data[:20])
    total_length = iph[2]
    proto = iph[6]
    src_ip = socket.inet_ntoa(iph[8])
    dst_ip = socket.inet_ntoa(iph[9])
    return {
        'ihl': ihl,
        'total_length': total_length,
        'proto': proto,
        'src_ip': src_ip,
        'dst_ip': dst_ip
    }

def parse_tcp_header(data):
    if len(data) < 20:
        return None
    tcph = struct.unpack('!HHLLBBHHH', data[:20])
    src_port = tcph[0]
    dst_port = tcph[1]
    seq = tcph[2]
    ack_seq = tcph[3]
    offset_reserved = tcph[4]
    doff = (offset_reserved >> 4) * 4
    flags = tcph[5]
    return {
        'src_port': src_port,
        'dst_port': dst_port,
        'seq': seq,
        'ack_seq': ack_seq,
        'data_offset': doff,
        'flags': flags
    }

def tcp_flag_labels(flags):
    syn = bool(flags & 0x02)
    ack = bool(flags & 0x10)
    fin = bool(flags & 0x01)
    rst = bool(flags & 0x04)

    if syn and ack:
        return "SYN/ACK"
    if syn:
        return "SYN"
    if fin:
        return "FIN"
    if rst:
        return "RST"
    if ack:
        return "ACK"
    return None

def packet_sniffer(listen_port, remote_host, remote_port):
    try:
        try:
            remote_ip = socket.gethostbyname(remote_host)
        except:
            remote_ip = remote_host

        sniffer = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.ntohs(3))
    except Exception as e:
        print(f"{RED}[{get_ts()}][!] TCP sniffer init failed: {e}{RESET}")
        return

    print(f"{CYAN}[{get_ts()}][*] TCP handshake sniffer ACTIVE on port {listen_port} (AF_PACKET){RESET}")

    while True:
        try:
            raw_data, addr = sniffer.recvfrom(65535)
        except:
            continue

        dst_mac, src_mac, eth_proto = parse_ethernet_header(raw_data)
        if eth_proto != 0x0800:
            continue

        ip_part = raw_data[14:]
        iphdr = parse_ipv4_header(ip_part)
        if not iphdr or iphdr['proto'] != 6:
            continue

        tcp_part = ip_part[iphdr['ihl']:]
        tcphdr = parse_tcp_header(tcp_part)
        if not tcphdr:
            continue

        src_ip = iphdr['src_ip']
        dst_ip = iphdr['dst_ip']
        src_port = tcphdr['src_port']
        dst_port = tcphdr['dst_port']
        flags = tcphdr['flags']

        if not (
            src_port == listen_port or dst_port == listen_port or
            src_port == remote_port or dst_port == remote_port
        ):
            continue

        label = tcp_flag_labels(flags)
        if not label:
            continue

        def pretty_ip(ip):
            if ip == remote_ip:
                return f"{remote_host}"
            return ip

        ts = get_ts()
        print(f"{YELLOW}[{ts}] [TCP] [{label}] {pretty_ip(src_ip)}:{src_port} -> {pretty_ip(dst_ip)}:{dst_port}{RESET}")

# ---------------------------
# Main
# ---------------------------

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Titan v14.1 Transparent Proxy (packet-aware + forced disconnect)")
    parser.add_argument("--listenport", type=int, required=True)
    parser.add_argument("--remoteserver", required=True)
    parser.add_argument("--remoteport", type=int, required=True)
    parser.add_argument("--ssl", action="store_true")
    parser.add_argument("--hexdump", action="store_true")
    parser.add_argument("--tcp-sniff", action="store_true", help="Enable AF_PACKET TCP handshake logging (Linux only, requires root)")
    args = parser.parse_args()

    load_rules()
    threading.Thread(target=rules_watcher, daemon=True).start()

    if args.tcp_sniff:
        threading.Thread(
            target=packet_sniffer,
            args=(args.listenport, args.remoteserver, args.remoteport),
            daemon=True
        ).start()

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', args.listenport))
    server.listen(100)

    total_conn_ever = 0
    print(f"{GREEN}[{get_ts()}][*] TITAN v14.1 ACTIVE: {args.listenport} -> {args.remoteserver}:{args.remoteport}{RESET}")
    if args.tcp_sniff:
        print(f"{CYAN}[{get_ts()}][*] TCP handshake logging ENABLED (--tcp-sniff){RESET}")

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
