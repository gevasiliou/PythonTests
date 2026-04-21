#!/usr/bin/env python3
import socket, ssl, threading, argparse, sys, signal, datetime, os, time, ipaddress, struct, json, requests
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

''' Multi-Line Comment
'''

# ANSI Colors
RED, BLUE, GREEN, YELLOW, CYAN, MAGENTA, RESET = (
    '\033[91m', '\033[94m', '\033[92m', '\033[93m', '\033[96m', '\033[95m', '\033[0m'
)

CERTFILE = 'cert.pem'
KEYFILE = 'key.pem'
RULEFILE = 'rm-proxy-ip-list'

# HTTP control
HTTP_CTRL_HOST = "127.0.0.1"
HTTP_CTRL_PORT = 9999

# AbuseIPDB settings
ABUSE_API_KEY = "430afd618fc099e20b869c0def897dd691b721758a0d49c41712217b032f184cf23d79c1de6dddba"
ABUSE_THRESHOLD = 80
AUTO_BLOCKED_IPS = []

connection_count = 0
counter_lock = threading.Lock()

# Each entry: {"obj": ipaddress object, "comment": str}
WHITELIST = []
BLACKLIST = []
OLD_BLACKLIST = []
rules_mtime = 0
rules_lock = threading.Lock()

ACTIVE_CONNECTIONS = {}
active_lock = threading.Lock()

HEXDUMP_ENABLED = False
hexdump_lock = threading.Lock()

STATS = {
    "accepted": 0,
    "blocked": 0,
    "disconnected": 0,
    "abuse_autoblocked": 0
}
stats_lock = threading.Lock()


def get_ts():
    return datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]


def log(msg):
    print(f"[{get_ts()}] {msg}", flush=True)


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
    except Exception:
        return None, None


def ip_in_list(ip, lst, return_entry=False):
    for entry in lst:
        rule = entry["obj"]
        if isinstance(rule, (ipaddress.IPv4Address, ipaddress.IPv6Address)):
            if ip == rule:
                return entry if return_entry else True
        else:
            if ip in rule:
                return entry if return_entry else True
    return None if return_entry else False


def check_rules(ip_str):
    ip = ipaddress.ip_address(ip_str)
    with rules_lock:
        if ip_in_list(ip, WHITELIST):
            return "ALLOW"
        if ip_in_list(ip, BLACKLIST):
            return "BLOCK"
    return "ALLOW"


def disconnect_ip(ip_str):
    with active_lock:
        to_kill = [cid for cid, info in ACTIVE_CONNECTIONS.items() if info["ip"] == ip_str]

    killed = 0
    for cid in to_kill:
        with active_lock:
            sock = ACTIVE_CONNECTIONS.get(cid, {}).get("socket")
        if not sock:
            continue
        try:
            sock.shutdown(socket.SHUT_RDWR)
        except Exception:
            pass
        try:
            sock.close()
        except Exception:
            pass
        with active_lock:
            ACTIVE_CONNECTIONS.pop(cid, None)
        print(f"{RED}[{get_ts()}][!] Forced disconnect of {ip_str} — newly added to block list{RESET}")
        killed += 1

    if killed:
        with stats_lock:
            STATS["disconnected"] += killed

    return killed

def disconnect_connection_id(cid):
    with active_lock:
        info = ACTIVE_CONNECTIONS.get(cid)
        if not info:
            return False

        ip = info.get("ip", "unknown")
        sock = info["socket"]

        try:
            sock.close()
        except:
            pass

        del ACTIVE_CONNECTIONS[cid]

        print(f"[{get_ts()}][!] Forced disconnect of connection ID {cid} ({ip})")
        return True



def load_rules():
    global WHITELIST, BLACKLIST, OLD_BLACKLIST, rules_mtime
    try:
        mtime = os.path.getmtime(RULEFILE)
    except FileNotFoundError:
        return
    except Exception as e:
        print(f"{RED}[{get_ts()}][!] load_rules(): mtime check failed: {e}{RESET}")
        return

    if mtime == rules_mtime:
        return

    try:
        new_white = []
        new_black = []

        with open(RULEFILE) as f:
            for raw in f:
                line = raw.split("#", 1)[0].strip()
                if not line:
                    continue
                action, obj = parse_rule(line)
                if not obj:
                    continue
                comment = ""
                if "#" in raw:
                    try:
                        comment = raw.split("#", 1)[1].strip()
                    except Exception:
                        comment = ""
                entry = {"obj": obj, "comment": comment}
                if action == "allow":
                    new_white.append(entry)
                elif action == "block":
                    new_black.append(entry)

        with rules_lock:
            WHITELIST = new_white
            BLACKLIST = new_black

            newly_blocked = []
            for entry in BLACKLIST:
                if entry not in OLD_BLACKLIST:
                    newly_blocked.append(entry)

            OLD_BLACKLIST = BLACKLIST.copy()
            rules_mtime = mtime

        print(f"{YELLOW}[{get_ts()}][!] Rules reloaded: {len(WHITELIST)} allow, {len(BLACKLIST)} block{RESET}")

        for entry in newly_blocked:
            rule = entry["obj"]
            if isinstance(rule, (ipaddress.IPv4Network, ipaddress.IPv6Network)) and rule.prefixlen == 0:
                continue

            if isinstance(rule, (ipaddress.IPv4Address, ipaddress.IPv6Address)):
                disconnect_ip(str(rule))
            else:
                with active_lock:
                    for cid, info in list(ACTIVE_CONNECTIONS.items()):
                        try:
                            ip = ipaddress.ip_address(info["ip"])
                        except Exception:
                            continue
                        if ip in rule:
                            disconnect_ip(info["ip"])

    except Exception as e:
        print(f"{RED}[{get_ts()}][!] load_rules() failed: {e}{RESET}")


def rules_watcher():
    while True:
        try:
            load_rules()
        except Exception as e:
            print(f"{RED}[{get_ts()}][!] Rule watcher error: {e}{RESET}")
        time.sleep(5)


def format_hexdump(data):
    lines = []
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        hex_part = " ".join(f"{b:02x}" for b in chunk)
        ascii_part = "".join(chr(b) if 32 <= b <= 126 else "." for b in chunk)
        lines.append(f"{CYAN}{i:04x}  {hex_part:<48}  |{ascii_part}|{RESET}")
    return "\n".join(lines)


def pipe(source, destination, label, color, conn_id, client_ip):
    try:
        while True:
            data = source.recv(8192)
            if not data:
                break

            with active_lock:
                info = ACTIVE_CONNECTIONS.get(conn_id)
                if info is not None:
                    info["last_update_ts"] = get_ts()

            with rules_lock:
                entry = ip_in_list(ipaddress.ip_address(client_ip), WHITELIST, return_entry=True)
                comment = f"  # {entry['comment']}" if entry and entry["comment"] else ""

            print(f"{color}[{get_ts()}] [ID:#{conn_id}] ({client_ip}) {label}:{comment}{RESET}")

            with hexdump_lock:
                show_hex = HEXDUMP_ENABLED
            if show_hex:
                print(format_hexdump(data))
            else:
                msg = data.decode(errors='ignore').strip()
                if msg:
                    print(f"{color}{msg}{RESET}")
            destination.sendall(data)
    except Exception:
        pass


def bridge(client_sock, addr, client_ip, remote_host, remote_port, force_ssl, conn_id):
    global connection_count

    connected_ts = get_ts()
    with active_lock:
        ACTIVE_CONNECTIONS[conn_id] = {
            "ip": client_ip,
            "socket": client_sock,
            "connected_ts": connected_ts,
            "last_update_ts": connected_ts,
        }


    with rules_lock:
        entry = ip_in_list(ipaddress.ip_address(client_ip), WHITELIST, return_entry=True)

    tag = " (white-listed)" if entry else "(newcommer)"
    comment = f"  # {entry['comment']}" if entry and entry["comment"] else ""

    print(f"{GREEN}[{get_ts()}][+] [ID:#{conn_id}] CONNECTED: {client_ip}{tag}{comment} (Active: {connection_count}){RESET}")

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

        t1 = threading.Thread(target=pipe, args=(c_conn, r_conn, "CLIENT->REMOTE", BLUE, conn_id, client_ip), daemon=True)
        t2 = threading.Thread(target=pipe, args=(r_conn, c_conn, "REMOTE->CLIENT", RED, conn_id, client_ip), daemon=True)

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
            try:
                s.close()
            except Exception:
                pass

        with stats_lock:
            STATS["disconnected"] += 1


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
        except Exception:
            remote_ip = remote_host

        sniffer = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.ntohs(3))
    except Exception as e:
        print(f"{RED}[{get_ts()}][!] TCP sniffer init failed: {e}{RESET}")
        return

    print(f"{CYAN}[{get_ts()}][*] TCP handshake sniffer ACTIVE on port {listen_port} (AF_PACKET){RESET}")

    while True:
        try:
            raw_data, addr = sniffer.recvfrom(65535)
        except Exception:
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


def add_block_rule(ip, score=None):
    try:
        comment = f" # auto block by abuse - score {score}" if score is not None else ""
        with open(RULEFILE, "a") as f:
            f.write(f"block {ip}{comment}\n")
        print(f"{RED}[{get_ts()}][!] Auto-added block rule for {ip}{comment}{RESET}")
    except Exception as e:
        print(f"{RED}[{get_ts()}][!] Failed to write block rule for {ip}: {e}{RESET}")


def abuse_lookup(ip):
    url = "https://api.abuseipdb.com/api/v2/check"
    headers = {
        "Key": ABUSE_API_KEY,
        "Accept": "application/json"
    }
    params = {
        "ipAddress": ip,
        "maxAgeInDays": "90"
    }
    try:
        r = requests.get(url, headers=headers, params=params, timeout=3)
        data = r.json()
        return data["data"]["abuseConfidenceScore"]
    except Exception as e:
        print(f"{RED}[{get_ts()}][!] AbuseIPDB lookup failed for {ip}: {e}{RESET}")
        return None

def make_table(rows, headers):
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(str(cell)))
    sep = "+" + "+".join("-" * (w + 2) for w in widths) + "+"
    header_row = "| " + " | ".join(h.ljust(widths[i]) for i, h in enumerate(headers)) + " |"
    data_rows = []
    for row in rows:
        data_rows.append("| " + " | ".join(str(row[i]).ljust(widths[i]) for i in range(len(headers))) + " |")
    return "\n".join([sep, header_row, sep] + data_rows + [sep])

class TitanHTTPHandler(BaseHTTPRequestHandler):
    def _json(self, code, payload):
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/status":
            with active_lock, rules_lock:
                active = []
                for cid, info in ACTIVE_CONNECTIONS.items():
                    ip = info["ip"]
                    entry = ip_in_list(ipaddress.ip_address(ip), WHITELIST, return_entry=True)
                    comment = entry["comment"] if entry and entry["comment"] else ""
                    connected_ts = info.get("connected_ts", "")
                    last_update_ts = info.get("last_update_ts", "")
                    active.append({
                        "id": cid,
                        "ip": ip,
                        "comment": comment,
                        "connected_ts": connected_ts,
                        "last_update_ts": last_update_ts,
                    })
            self._json(200, {"active": active})

        elif parsed.path == "/rules":
            with rules_lock:
                allow = [str(e["obj"]) for e in WHITELIST]
                block = [str(e["obj"]) for e in BLACKLIST]
            self._json(200, {"allow": allow, "block": block})
        elif parsed.path == "/stats":
            with stats_lock:
                stats_copy = dict(STATS)
            self._json(200, stats_copy)
        elif parsed.path == "/autoblocked":
            self._json(200, {"autoblocked": AUTO_BLOCKED_IPS})
        elif parsed.path == "/autoblockedtable":
            rows = []
            for entry in AUTO_BLOCKED_IPS:
                ip = entry.get("ip", "")
                score = entry.get("score", "")
                ts = entry.get("ts", "")
                rows.append([ip, score, ts])

            headers = ["IP", "Score", "Timestamp"]
            table = make_table(rows, headers)

            body = table.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        elif parsed.path == "/rulesallowtable":
            with rules_lock:
                rows = []
                for entry in WHITELIST:
                    obj = str(entry["obj"])
                    comment = entry["comment"]
                    rows.append([obj, comment])

            headers = ["Allow Rule", "Comment"]
            table = make_table(rows, headers)

            body = table.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        elif parsed.path == "/rulesblockedtable":
            with rules_lock:
                rows = []
                for entry in BLACKLIST:
                    obj = str(entry["obj"])
                    comment = entry["comment"]
                    rows.append([obj, comment])

            headers = ["Block Rule", "Comment"]
            table = make_table(rows, headers)
            body = table.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        elif parsed.path == "/statustable":
            with active_lock, rules_lock:
                rows = []
                for cid, info in ACTIVE_CONNECTIONS.items():
                    ip = info["ip"]
                    entry = ip_in_list(ipaddress.ip_address(ip), WHITELIST, return_entry=True)
                    comment = entry["comment"] if entry and entry["comment"] else ""
                    connected_ts = info.get("connected_ts", "")
                    last_update_ts = info.get("last_update_ts", "")
                    rows.append([cid, ip, comment, connected_ts, last_update_ts])

            headers = ["ID", "IP", "Comment", "Connected", "Last Update"]
            table = make_table(rows, headers)

            body = table.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):
        global HEXDUMP_ENABLED

        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)

        if parsed.path == "/disconnect":
            ip = qs.get("ip", [None])[0]
            if not ip:
                self._json(400, {"error": "missing ip"})
                return
            killed = disconnect_ip(ip)
            self._json(200, {"ip": ip, "disconnected": killed})
        elif parsed.path == "/disconnect_oldest":
            ip = qs.get("ip", [None])[0]
            if not ip:
                self._json(400, {"error": "missing ip"})
                return

            # find all connections for this IP
            matches = []
            with active_lock:
                for cid, info in ACTIVE_CONNECTIONS.items():
                    if info["ip"] == ip:
                        matches.append((cid, info["connected_ts"]))

            if not matches:
                self._json(200, {"ip": ip, "disconnected": None, "reason": "no active connections"})
                return

            # sort by connected_ts (oldest first)
            matches.sort(key=lambda x: x[1])
            oldest_cid = matches[0][0]

            # disconnect only that connection
            killed = disconnect_connection_id(oldest_cid)

            self._json(200, {
                "ip": ip,
                "disconnected_id": oldest_cid,
                "remaining_connections": len(matches) - 1
            })
            return
        elif parsed.path == "/disconnect_id":
            cid_raw = qs.get("ID", [None])[0]
            if cid_raw is None:
                self._json(400, {"error": "missing ID"})
                return

            try:
                cid = int(cid_raw)
            except ValueError:
                self._json(400, {"error": "ID must be an integer"})
                return

            killed = disconnect_connection_id(cid)

            if not killed:
                self._json(404, {"error": f"connection ID {cid} not found"})
                return

            self._json(200, {"disconnected_id": cid})
            return
        elif parsed.path == "/hexdump/on":
            with hexdump_lock:
                HEXDUMP_ENABLED = True
            self._json(200, {"hexdump": True})

        elif parsed.path == "/hexdump/off":
            with hexdump_lock:
                HEXDUMP_ENABLED = False
            self._json(200, {"hexdump": False})

        else:
            self._json(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        return


def http_control_loop():
    srv = HTTPServer((HTTP_CTRL_HOST, HTTP_CTRL_PORT), TitanHTTPHandler)
    log(f"[*] Titan v15.3 HTTP control on http://{HTTP_CTRL_HOST}:{HTTP_CTRL_PORT}")
    srv.serve_forever()


if __name__ == "__main__":
    #parser = argparse.ArgumentParser(description="Titan v15.3 Proxy (packet-aware + forced disconnect + AbuseIPDB + HTTP control)")
    parser = argparse.ArgumentParser(description="""Titan v15.3 Proxy
    This version of Titan is using AbuseIPDB API to check new IPs abuse score
    Known IPs (allow or blocked) are not re-tested for abuse.
    If an ip (newcomer) has abuse score > 80% then this new IP is auto blocked (auto appended to file rm-proxy-ip-list with block entry and #auto-block comment).
    """, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--listenport", type=int, required=True)
    parser.add_argument("--remoteserver", required=True)
    parser.add_argument("--remoteport", type=int, required=True)
    parser.add_argument("--ssl", action="store_true")
    parser.add_argument("--hexdump", action="store_true")
    parser.add_argument("--tcp-sniff", action="store_true", help="Enable AF_PACKET TCP handshake logging (Linux only, requires root)")
    #parser.add_argument("--http-port", type=int, default=HTTP_CTRL_PORT)
    parser.add_argument("--http-port", type=int, default=HTTP_CTRL_PORT, help="""
        HTTP control port for Titan."
        Default: 9999
        Used for /status, /rules, /statustable, etc.
        Endpoint	            Method	    Purpose
        /status	                GET	        List active connections (json)
        /statustable            GET         List active connections (ascii table)
        /rules	                GET	        Show allow/block rules (json)
        /rulesallowtable        GET         Show allow rules (ascii table)
        /rulesblockedtable      GET         Show blocked rules (ascii table)
        /stats	                GET	        Show counters - json (accepted, blocked, abuse, etc.)
        /autoblocked            GET         Get's autoblocked IPs in json format (current session)
        /autoblockedtable       GET         Get's autoblocked IPs in ascii table (current session)
        /disconnect?ip=X	    POST	    Force disconnect an IP
        /disconnect_oldest?ip=X POST    Force disconnect oldest IP session (IP based)
        /disconnect_id?id=X     POST    Force disconnect a specific connection ID 
        /hexdump/on	            POST	    Enable hexdump
        /hexdump/off	        POST	    Disable hexdump
        
        Usage examples:
        curl -X POST http://127.0.0.1:9999/hexdump/off
        curl -X POST "http://127.0.0.1:9999/disconnect?ip=78.87.123.42"
        curl -s -X POST "http://127.0.0.1:9999/disconnect_id?ID=2"
        curl -s http://127.0.0.1:9999/stats
        curl -s http://127.0.0.1:9999/rules
        curl -s http://127.0.0.1:9999/status
        """)

    args = parser.parse_args()

    HTTP_CTRL_PORT = args.http_port

    load_rules()
    watcher_thread = threading.Thread(target=rules_watcher, daemon=True)
    watcher_thread.start()

    if args.hexdump:
        with hexdump_lock:
            HEXDUMP_ENABLED = True

    if args.tcp_sniff:
        threading.Thread(
            target=packet_sniffer,
            args=(args.listenport, args.remoteserver, args.remoteport),
            daemon=True
        ).start()

    threading.Thread(target=http_control_loop, daemon=True).start()

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', args.listenport))
    server.listen(100)

    total_conn_ever = 0
    print(f"{GREEN}[{get_ts()}][*] TITAN v15.3 ACTIVE: {args.listenport} -> {args.remoteserver}:{args.remoteport}{RESET}")
    if args.tcp_sniff:
        print(f"{CYAN}[{get_ts()}][*] TCP handshake logging ENABLED (--tcp-sniff){RESET}")

    while True:
        try:
            c, a = server.accept()
        except Exception as e:
            print(f"{RED}[{get_ts()}][!] Accept error: {e}{RESET}")
            continue

        client_ip = a[0]
        ip_obj = ipaddress.ip_address(client_ip)

        with rules_lock:
            white_entry = ip_in_list(ip_obj, WHITELIST, return_entry=True)
            black_entry = ip_in_list(ip_obj, BLACKLIST, return_entry=True)

        # Explicit blacklist → block immediately, no AbuseIPDB
        if black_entry:
            print(f"{RED}[{get_ts()}] BLOCKED ATTEMPT from {client_ip}{RESET}")
            with stats_lock:
                STATS["blocked"] += 1
            try:
                c.shutdown(socket.SHUT_RDWR)
            except Exception:
                pass
            try:
                c.close()
            except Exception:
                pass
            continue

        is_white = bool(white_entry)

        # Only unknown IPs get AbuseIPDB check
        if not is_white:
            score = abuse_lookup(client_ip)
            if score is not None:
                print(f"{YELLOW}[{get_ts()}][INFO] AbuseIPDB score for {client_ip}: {score}{RESET}")
                if score >= ABUSE_THRESHOLD:
                    print(f"{RED}[{get_ts()}][!] {client_ip} flagged by AbuseIPDB (score {score}) — auto-blocking{RESET}")
                    add_block_rule(client_ip, score)
                    load_rules()
                    disconnect_ip(client_ip)
                    with stats_lock:
                        STATS["abuse_autoblocked"] += 1
                        # NEW: record autoblocked IP
                        AUTO_BLOCKED_IPS.append({
                            "ip": client_ip,
                            "score": score,
                            "ts": get_ts()
                        })
                    try:
                        c.shutdown(socket.SHUT_RDWR)
                    except Exception:
                        pass
                    try:
                        c.close()
                    except Exception:
                        pass
                    continue

        total_conn_ever += 1
        with counter_lock:
            connection_count += 1
        with stats_lock:
            STATS["accepted"] += 1

        threading.Thread(
            target=bridge,
            args=(c, a, a[0], args.remoteserver, args.remoteport, args.ssl, total_conn_ever),
            daemon=True
        ).start()
