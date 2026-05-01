#!/usr/bin/env python3
import socket, ssl, threading, argparse, sys, signal, datetime, os, time, ipaddress, struct, json, requests
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

HTTP_PORT_HELP = """\
Titan v11 - updated pipe() forcing close upstream sockets when downstream sockets are closed (naturally or forced).
Titan v11 Endpoints [when enabled with --httpexpose <port>(default port=9999)]:
  /stats                                GET     Show counters about current session (json)
  /status                               GET     List active connections (json)
  /statustable                          GET     List active connections (ascii table)
  /rules                                GET     Show allow/block rules (json)
  /rulesallowtable                      GET     Show allow rules (ascii table)
  /rulesblockedtable                    GET     Show blocked rules (ascii table)
  /autoblocked                          GET     Autoblocked IPs in running session (json)
  /autoblockedtable                     GET     Autoblocked IPs in running session (ascii table)
  /disconnect?ip=X                      POST    Disconnect all sessions for given IP 
  /disconnect_oldest?ip=X or ID=X       POST    Disconnect oldest session for a given IP or given ID (keeps only the newest one)
  /disconnect_id?ID=X                   POST    Disconnect specific given connection ID
  /hexdump?enable/disable               POST    Enables or Disables bytes hexdump in screen & logs
  /autodisconnectoldest                 POST    Automaticall checks ALL active connections and autodisconnects old connections, keeping only the newest
  /newcomerabusecheck?disable/enable    POST    Enable/Disable newcomer abusecheck in runtime (default=enable) - When disabled, rules file is active but abuse check for new IPs is skipped
  /allowall?enable/disable              POST    Enable/Disable allow all IPs (default=disable) - When enabled abuse check skipped, rulesfile is ignored = everybody is allowed!

Usage examples (when --httpexpose is enabled):
  curl -X POST http://127.0.0.1:9999/hexdump/off
  curl -X POST "http://127.0.0.1:9999/disconnect?ip=78.87.123.42"
  curl -s -X POST "http://127.0.0.1:9999/disconnect_id?ID=2"
  curl -s http://127.0.0.1:9999/stats
  curl -s http://127.0.0.1:9999/rules
  curl -s http://127.0.0.1:9999/status
"""

# ANSI Colors
RED, BLUE, GREEN, YELLOW, CYAN, MAGENTA, RESET = (
    '\033[91m', '\033[94m', '\033[92m', '\033[93m', '\033[96m', '\033[95m', '\033[0m'
)

CERTFILE = 'cert.pem'
KEYFILE = 'key.pem'
RULEFILE = None

# HTTP control
HTTP_CTRL_HOST = "127.0.0.1"
HTTP_CTRL_PORT = 9999  # default port - used only if --httpexpose is provided

# New in 15.7: runtime in-memory blocklist + abuseblock flag
RUNTIME_BLOCKLIST = set()
ABUSEBLOCK_ENABLED = False

# AbuseIPDB runtime cache (NEW)
ABUSE_CACHE = {}   # { ip: (score, timestamp) }
ABUSE_CACHE_TTL = 3600  # seconds (1 hour)
abuse_cache_lock = threading.Lock()

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

# AbuseIPDB settings
def load_api_key(source=None):
    # Priority 1: environment variable
    #key = os.getenv("ABUSE_API_KEY")
    #if key:
    #    return key.strip()

    # Priority 2: CLI argument (file OR raw key)
    if source:
        # If it's a valid file path → read it
        if os.path.isfile(source):
            try:
                with open(source, "r") as f:
                    return f.read().strip()
            except Exception:
                pass
        else:
            # Treat directly as API key
            return source.strip()

    return None

ABUSE_API_KEY = load_api_key()
ABUSE_THRESHOLD = 80
AUTO_BLOCKED_IPS = []

ALLOWALL_ENABLED = False
_ALLOWALL_SNAPSHOT = {}  # stores state before allowall was activated

def get_ts():
    return datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]
    #return datetime.datetime.now().strftime("%H:%M:%S.%f")[:-3]


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


#def disconnect_ip(ip_str):
def disconnect_ip(ip_str, reason="block list"):
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
        except OSError:
            pass
        except Exception as e:
            print(f"{YELLOW}[{get_ts()}][dbg] shutdown() {ip_str}: {e}{RESET}")
        try:
            sock.close()
        except OSError:
            pass
        except Exception as e:
            print(f"{YELLOW}[{get_ts()}][dbg] close() {ip_str}: {e}{RESET}")

        with active_lock:
            ACTIVE_CONNECTIONS.pop(cid, None)
        #print(f"{RED}[{get_ts()}][!] Forced disconnect of {ip_str} — newly added to block list{RESET}")
        print(f"{RED}[{get_ts()}][!] Forced disconnect of {ip_str} (ID:#{cid}) — {reason}{RESET}")
        killed += 1

    if killed:
        with stats_lock:
            STATS["disconnected"] += killed

    return killed


"""
def disconnect_connection_id(cid, reason="operator request"):
    with active_lock:
        info = ACTIVE_CONNECTIONS.get(cid)
        if not info:
            return False

        ip = info.get("ip", "unknown")
        sock = info["socket"]

        try:
            sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass  # expected — socket already closed or broken
        except Exception as e:
            print(f"{YELLOW}[{get_ts()}][dbg] shutdown() ID {cid} ({ip}): {e}{RESET}")

        try:
            sock.close()
        except OSError:
            pass  # expected
        except Exception as e:
            print(f"{YELLOW}[{get_ts()}][dbg] close() ID {cid} ({ip}): {e}{RESET}")

        del ACTIVE_CONNECTIONS[cid]

        # >>> ADD THIS BLOCK <<<
        with stats_lock:
            STATS["disconnected"] += 1
        # <<< END >>>

        #print(f"[{get_ts()}][!] Forced disconnect of connection ID {cid} ({ip})")
        print(f"{RED}[{get_ts()}][!] Forced disconnect of ID:#{cid} ({ip}) — {reason}{RESET}")
        return True
"""

def disconnect_connection_id(cid, reason="operator request"):
    with active_lock:
        info = ACTIVE_CONNECTIONS.get(cid)
        if not info:
            return False

        ip = info.get("ip", "unknown")
        sock = info["socket"]

        try:
            sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass  # expected — socket already closed or broken
        except Exception as e:
            print(f"{YELLOW}[{get_ts()}][dbg] shutdown() ID {cid} ({ip}): {e}{RESET}")

        try:
            sock.close()
        except OSError:
            pass  # expected
        except Exception as e:
            print(f"{YELLOW}[{get_ts()}][dbg] close() ID {cid} ({ip}): {e}{RESET}")

        del ACTIVE_CONNECTIONS[cid]

    # active_lock released before acquiring stats_lock — no nested lock risk
    with stats_lock:
        STATS["disconnected"] += 1

    print(f"{RED}[{get_ts()}][!] Forced disconnect of ID:#{cid} ({ip}) — {reason}{RESET}")
    return True

def load_rules():
    global WHITELIST, BLACKLIST, OLD_BLACKLIST, rules_mtime
    if RULEFILE is None:
        print(f"{YELLOW}[{get_ts()}][!] No Rule Files specified - all connections are allowed")
        return
    
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

        print(f"{YELLOW}[{get_ts()}][!] Rules reloaded from file {RULEFILE}: {len(WHITELIST)} allow, {len(BLACKLIST)} block{RESET}")

        for entry in newly_blocked:
            rule = entry["obj"]
            if isinstance(rule, (ipaddress.IPv4Network, ipaddress.IPv6Network)) and rule.prefixlen == 0:
                continue

            if isinstance(rule, (ipaddress.IPv4Address, ipaddress.IPv6Address)):
                #disconnect_ip(str(rule))
                disconnect_ip(str(rule), reason="newly added to block list")
            else:
                with active_lock:
                    for cid, info in list(ACTIVE_CONNECTIONS.items()):
                        try:
                            ip = ipaddress.ip_address(info["ip"])
                        except Exception:
                            continue
                        if ip in rule:
                            #disconnect_ip(info["ip"])
                            disconnect_ip(info["ip"], reason="newly added to block list")

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
                # Either side closed — force close the other side immediately
                try:
                    destination.shutdown(socket.SHUT_RDWR)
                except Exception:
                    pass
                break

            with active_lock:
                info = ACTIVE_CONNECTIONS.get(conn_id)
                if info is not None:
                    ts_now = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]
                    if label == "CLIENT->REMOTE":
                        info["last_client_ts"] = ts_now
                    else:
                        info["last_remote_ts"] = ts_now

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
        # Exception on either side — force close the other side
        try:
            destination.shutdown(socket.SHUT_RDWR)
        except Exception:
            pass

def bridge(client_sock, addr, client_ip, remote_host, remote_port, force_ssl, conn_id):
    global connection_count

    #connected_ts = get_ts()
    #connected_ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]

    connected_ts = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]
    with active_lock:
        ACTIVE_CONNECTIONS[conn_id] = {
            "ip": client_ip,
            "socket": client_sock,
            "connected_ts": connected_ts,
            "last_client_ts": connected_ts,  # updated by CLIENT->REMOTE pipe
            "last_remote_ts": connected_ts,  # updated by REMOTE->CLIENT pipe
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

def abuse_lookup_cached(ip):
    now = time.time()

    with abuse_cache_lock:
        entry = ABUSE_CACHE.get(ip)
        if entry:
            score, ts = entry
            if now - ts < ABUSE_CACHE_TTL:
                return score, "cache"

    # Not cached or expired → API call
    score = abuse_lookup(ip)

    if score is not None:
        with abuse_cache_lock:
            ABUSE_CACHE[ip] = (score, now)

    return score, "api"

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
            with active_lock, rules_lock, stats_lock:
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
                        "last_client_ts": info.get("last_client_ts", ""),
                        "last_remote_ts": info.get("last_remote_ts", ""),
                    })
                status = {
                    "active": active,
                    "rulesfile": RULEFILE,
                    "abuse_threshold": ABUSE_THRESHOLD,
                    "abuseblock_enabled": ABUSEBLOCK_ENABLED,
                    "runtime_blocklist_size": len(RUNTIME_BLOCKLIST),
                    "allowall": ALLOWALL_ENABLED,
                    "stats": dict(STATS),
                }
            self._json(200, status)

        elif parsed.path == "/rules":
            with rules_lock:
                allow = [str(e["obj"]) for e in WHITELIST]
                block = [str(e["obj"]) for e in BLACKLIST]
            self._json(200, {"allow": allow, "block": block})
        
#        elif parsed.path == "/stats":
#            with stats_lock:
#                stats_copy = dict(STATS)
#            self._json(200, stats_copy)
        
        elif parsed.path == "/stats":
            with stats_lock, counter_lock, active_lock:
                stats_copy = dict(STATS)
                #stats_copy["connected"] = connection_count  # real-time active count
                stats_copy["connected"] = len(ACTIVE_CONNECTIONS)
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
                    last_client_ts = info.get("last_client_ts", "")
                    last_remote_ts = info.get("last_remote_ts", "")
                    rows.append([cid, ip, comment, connected_ts, last_client_ts, last_remote_ts])

            headers = ["ID", "IP", "Comment", "Connected", "Last From Client", "Last From Remote"]
            table = make_table(rows, headers)

            body = table.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        elif parsed.path == "/upstreamtable":
            now = datetime.datetime.now()
            rows = []

            with active_lock:
                for cid, info in ACTIVE_CONNECTIONS.items():
                    ip = info["ip"]
                    connected_ts = info.get("connected_ts", "")
                    last_client_ts = info.get("last_client_ts", "")
                    last_remote_ts = info.get("last_remote_ts", "")

                    # Status based purely on upstream (REMOTE->CLIENT) activity
                    try:
                        last_dt = datetime.datetime.strptime(last_remote_ts, "%d-%m-%Y %H:%M:%S.%f")
                        idle_secs = int((now - last_dt).total_seconds())
                    except Exception:
                        idle_secs = -1
                    if idle_secs < 0:
                        idle_str = "?"
                    elif idle_secs < 60:
                        idle_str = f"{idle_secs}s"
                    elif idle_secs < 3600:
                        idle_str = f"{idle_secs // 60}m {idle_secs % 60}s"
                    else:
                        idle_str = f"{idle_secs // 3600}h {(idle_secs % 3600) // 60}m"

                    rows.append([cid, ip, connected_ts, last_client_ts, last_remote_ts, idle_str])

            headers = ["ID", "IP", "Connected", "Last From Client", "Last From Remote", "Upstream Idle"]
            table = make_table(rows, headers)

            body = table.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        
        elif parsed.path == "/help":
            help_text = HTTP_PORT_HELP
            body = help_text.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        
        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):
        #global HEXDUMP_ENABLED
        global HEXDUMP_ENABLED, ABUSEBLOCK_ENABLED, ALLOWALL_ENABLED, _ALLOWALL_SNAPSHOT

        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)

        if parsed.path == "/disconnect":
            ip = qs.get("ip", [None])[0]
            if not ip:
                self._json(400, {"error": "missing ip"})
                return
            #killed = disconnect_ip(ip)
            killed = disconnect_ip(ip, reason="HTTP operator request")
            self._json(200, {"ip": ip, "disconnected": killed})

        elif parsed.path == "/disconnect_oldest":
            # Accept either IP or ID
            ip = qs.get("ip", [None])[0]
            cid_raw = qs.get("ID", [None])[0]

            # If ID is provided, resolve IP from ACTIVE_CONNECTIONS
            if cid_raw is not None:
                try:
                    cid = int(cid_raw)
                except ValueError:
                    self._json(400, {"error": "ID must be an integer"})
                    return

                with active_lock:
                    info = ACTIVE_CONNECTIONS.get(cid)
                    if not info:
                        self._json(404, {"error": f"connection ID {cid} not found"})
                        return
                    ip = info["ip"]

            # If no IP found at all, error
            if not ip:
                self._json(400, {"error": "missing ip or ID"})
                return

            # find all connections for this IP
            matches = []
            with active_lock:
                for cid2, info2 in ACTIVE_CONNECTIONS.items():
                    if info2["ip"] == ip:
                        matches.append((cid2, info2["connected_ts"]))

            if not matches:
                self._json(200, {"ip": ip, "disconnected": None, "reason": "no active connections"})
                return

            # sort by connected_ts (oldest first)
            from datetime import datetime
            #matches.sort(key=lambda x: datetime.strptime(x[1], "%H:%M:%S.%f"))
            #matches.sort(key=lambda x: datetime.datetime.strptime(x[1], "%Y-%m-%d %H:%M:%S.%f"))
            matches.sort(key=lambda x: datetime.strptime(x[1], "%d-%m-%Y %H:%M:%S.%f"))

            # newest connection is the LAST one
            newest_cid = matches[-1][0]

            # disconnect all except newest
            disconnected = []
            for cid2, ts in matches[:-1]:
                #if disconnect_connection_id(cid2):
                if disconnect_connection_id(cid2, reason="HTTP operator — keep newest only"):
                    disconnected.append(cid2)

            self._json(200, {
                "ip": ip,
                "kept_id": newest_cid,
                "disconnected_ids": disconnected,
                "remaining_connections": 1
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

            # Grab IP before disconnect deletes the entry
            with active_lock:
                info = ACTIVE_CONNECTIONS.get(cid)
                ip = info["ip"] if info else None

            #killed = disconnect_connection_id(cid)
            killed = disconnect_connection_id(cid, reason="HTTP operator request")

            if not killed:
                self._json(404, {"error": f"connection ID {cid} not found"})
                return

            #self._json(200, {"disconnected_id": cid})
            self._json(200, {"disconnected_id": cid, "ip": ip})
            return
        
        elif parsed.path == "/autodisconnectoldest":
            disconnected = {}
            with active_lock:
                # build per-IP groups
                ip_groups = {}
                for cid, info in ACTIVE_CONNECTIONS.items():
                    ip = info["ip"]
                    ts = info.get("connected_ts", "")
                    ip_groups.setdefault(ip, []).append((cid, ts))

            from datetime import datetime

            for ip, items in ip_groups.items():
                if len(items) <= 1:
                    continue

                # sort oldest → newest
                #items.sort(key=lambda x: datetime.strptime(x[1], "%Y-%m-%d %H:%M:%S.%f"))
                items.sort(key=lambda x: datetime.strptime(x[1], "%d-%m-%Y %H:%M:%S.%f"))

                # keep newest
                keep = items[-1][0]
                to_kill = [cid for cid, _ in items[:-1]]

                killed = []
                for cid in to_kill:
                    #if disconnect_connection_id(cid):
                    if disconnect_connection_id(cid, reason="HTTP auto disconnect — keep newest only"):
                        killed.append(cid)

                if killed:
                    disconnected[ip] = {
                        "kept_id": keep,
                        "disconnected_ids": killed
                    }

            self._json(200, {
                "result": "ok",
                "disconnected_groups": disconnected
            })
            return
        
        elif parsed.path == "/hexdump":
            if parsed.query == "enable":
                with hexdump_lock:
                    HEXDUMP_ENABLED = True
                print(f"{YELLOW}[{get_ts()}][*] HEXDUMP ENABLED via HTTP control{RESET}")
                self._json(200, {"hexdump": True})

            elif parsed.query == "disable":
                with hexdump_lock:
                    HEXDUMP_ENABLED = False
                print(f"{YELLOW}[{get_ts()}][*] HEXDUMP DISABLED via HTTP control{RESET}")
                self._json(200, {"hexdump": False})

            else:
                self._json(400, {
                    "error": "Missing parameter. Use ?enable or ?disable",
                    "hexdump": HEXDUMP_ENABLED
                })
        
        elif parsed.path == "/allowall":
                    if parsed.query == "enable":
                        if ALLOWALL_ENABLED:
                            self._json(200, {
                                "allowall": True,
                                "note": "Already active"
                            })
                            return
                        # Snapshot current state before overriding
                        _ALLOWALL_SNAPSHOT = {
                            "ABUSEBLOCK_ENABLED": ABUSEBLOCK_ENABLED,
                        }
                        ABUSEBLOCK_ENABLED = False
                        ALLOWALL_ENABLED = True
                        print(f"{YELLOW}[{get_ts()}][*] ALLOWALL ENABLED via HTTP control — "
                              f"all IP checks suspended, all newcomers accepted{RESET}")
                        self._json(200, {
                            "allowall": True,
                            "snapshot_saved": _ALLOWALL_SNAPSHOT,
                            "note": "Blacklist, whitelist and abuse check suspended"
                        })
                    elif parsed.query == "disable":
                        if not ALLOWALL_ENABLED:
                            self._json(200, {
                                "allowall": False,
                                "note": "Already inactive"
                            })
                            return
                        # Restore from snapshot
                        ABUSEBLOCK_ENABLED = _ALLOWALL_SNAPSHOT.get("ABUSEBLOCK_ENABLED", False)
                        ALLOWALL_ENABLED = False
                        _ALLOWALL_SNAPSHOT = {}
                        print(f"{YELLOW}[{get_ts()}][*] ALLOWALL DISABLED via HTTP control — "
                              f"previous behavior restored (abuseblock={ABUSEBLOCK_ENABLED}){RESET}")
                        self._json(200, {
                            "allowall": False,
                            "restored": {
                                "abuseblock_enabled": ABUSEBLOCK_ENABLED,
                            },
                            "note": "Rules file enforcement and abuse check restored to pre-allowall state"
                        })
                    else:
                        self._json(400, {
                            "error": "Missing parameter. Use ?enable or ?disable",
                            "allowall": ALLOWALL_ENABLED
                        })

        elif parsed.path == "/newcomerabusecheck":
                    if parsed.query == "enable":
                        if not ABUSE_API_KEY:
                            self._json(409, {
                                "error": "Cannot enable — no AbuseIPDB API key was provided at startup",
                                "newcomer_abuse_check": False
                            })
                            return
                        ABUSEBLOCK_ENABLED = True
                        print(f"{YELLOW}[{get_ts()}][*] Newcomer abuse check ENABLED via HTTP control — "
                              f"threshold: {ABUSE_THRESHOLD}{RESET}")
                        self._json(200, {"newcomer_abuse_check": True, "threshold": ABUSE_THRESHOLD})
                    elif parsed.query == "disable":
                        ABUSEBLOCK_ENABLED = False
                        print(f"{YELLOW}[{get_ts()}][*] Newcomer abuse check DISABLED via HTTP control — "
                              f"blacklist/whitelist/runtime-blocklist still enforced{RESET}")
                        self._json(200, {
                            "newcomer_abuse_check": False,
                            "note": "Blacklist, whitelist and runtime blocklist remain active"
                        })
                    else:
                        self._json(400, {
                            "error": "Missing parameter. Use ?enable or ?disable",
                            "newcomer_abuse_check": ABUSEBLOCK_ENABLED
                        })

        else:
            self._json(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        return


def http_control_loop():
    srv = HTTPServer((HTTP_CTRL_HOST, HTTP_CTRL_PORT), TitanHTTPHandler)
    log(f"[*] Titan v11 HTTP control on http://{HTTP_CTRL_HOST}:{HTTP_CTRL_PORT}")
    srv.serve_forever()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="""Titan v11 Proxy
    This version of Titan is using AbuseIPDB API to check new IPs abuse score.
    Known IPs (allow or blocked) are not re-tested for abuse.
    If an ip (newcomer) has abuse score > threshold then this new IP is auto blocked.
    HTTP control is optional and must be explicitly enabled with --httpexpose <port>.
    """, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--listenport", type=int, required=True, help="Mandatory Option - Listening Port of Proxy")
    parser.add_argument("--remoteserver", required=True, help="Mandatory Option - address to forward data transparently")
    parser.add_argument("--remoteport", type=int, required=True, help="Mandatory Option - port of remote server server for data forwarding")
    parser.add_argument("--ssl", action="store_true")
    parser.add_argument("--hexdump", action="store_true", help="Enable hex data dumping on the screen")
    parser.add_argument("--tcp-sniff", action="store_true", help="Enable AF_PACKET TCP handshake logging (Linux only, requires root)")
    parser.add_argument("--httpexpose", type=int,  metavar="HTTPPORT", help=HTTP_PORT_HELP)

    # New in 15.7: override rules file path
    parser.add_argument("--rulesfile", type=str, help="Rules file for allow/block entries (default = none)")

    # New in 15.7: configurable AbuseIPDB threshold
    parser.add_argument("--abuseblock", type=int, help="Enable AbuseIPDB auto-check & block with given threshold abuse score")
    parser.add_argument("--abuseapikey", type=str, help="Path to AbuseIPDB API key file OR raw API key")
    
    args = parser.parse_args()

    # HTTP control: only enabled if --httpexpose is provided
    if args.httpexpose is not None:
        HTTP_CTRL_PORT = args.httpexpose
        http_enabled = True
    else:
        http_enabled = False

    if args.rulesfile:
        RULEFILE = args.rulesfile
    else:
        RULEFILE = None

    if args.abuseblock is not None:
        ABUSE_THRESHOLD = args.abuseblock
        ABUSEBLOCK_ENABLED = True
        print(f"{YELLOW}[{get_ts()}][*] Abuse score switch enabled - abuse score threshold set to {ABUSE_THRESHOLD}")
    else:
        ABUSEBLOCK_ENABLED = False
        print(f"{YELLOW}[{get_ts()}][*] Abuse score switch not provided — all newcomer IPs will be allowed without AbuseIPDB checking")

    ABUSE_API_KEY = load_api_key(args.abuseapikey)
    # Graceful downgrade if key missing
    if ABUSEBLOCK_ENABLED and not ABUSE_API_KEY:
        print(f"{YELLOW}[{get_ts()}][!] AbuseIPDB switch enabled but no API key provided - disabling abuse check{RESET}")
        ABUSEBLOCK_ENABLED = False

    if RULEFILE is not None:
        load_rules()
        watcher_thread = threading.Thread(target=rules_watcher, daemon=True)
        watcher_thread.start()
    else:
        print(f"{YELLOW}[{get_ts()}][*] No block/allow IP rules file provided — rule watcher disabled")

    if args.hexdump:
        with hexdump_lock:
            HEXDUMP_ENABLED = True

    if args.tcp_sniff:
        threading.Thread(
            target=packet_sniffer,
            args=(args.listenport, args.remoteserver, args.remoteport),
            daemon=True
        ).start()

    if http_enabled:
        threading.Thread(target=http_control_loop, daemon=True).start()
    else:
        print(f"{YELLOW}[{get_ts()}][*] HTTP control interface disabled (no --httpexpose provided){RESET}")

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', args.listenport))
    server.listen(100)

    total_conn_ever = 0
    print(f"{CYAN}[{get_ts()}][*] ---- Titan Startup Summary ----")

    print(f"{CYAN}[{get_ts()}][*] Listen Port:            {args.listenport}")
    print(f"{CYAN}[{get_ts()}][*] Remote Server:          {args.remoteserver}:{args.remoteport}")
    print(f"{CYAN}[{get_ts()}][*] HTTP Monitor/Control:       "
          f"{'Enabled on port ' + str(HTTP_CTRL_PORT) if http_enabled else 'Disabled'}")

    print(f"{CYAN}[{get_ts()}][*] Hexdump Mode:           {'Enabled' if args.hexdump else 'Disabled'}")
    print(f"{CYAN}[{get_ts()}][*] TCP Sniff Mode:         {'Enabled' if args.tcp_sniff else 'Disabled'}")

    print(f"{CYAN}[{get_ts()}][*] Rules File:             "
          f"{RULEFILE if RULEFILE is not None else 'None (rules disabled)'}")

    print(f"{CYAN}[{get_ts()}][*] Abuse Score Checking:   "
          f"{'Enabled (threshold ' + str(ABUSE_THRESHOLD) + ')' if ABUSEBLOCK_ENABLED else 'Disabled'}")

    print(f"{CYAN}[{get_ts()}][*] --------------------------------")


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

        # ✅ ALLOWALL: skip all checks, bridge immediately
        if ALLOWALL_ENABLED:
            total_conn_ever += 1
            with counter_lock:
                connection_count += 1
            with stats_lock:
                STATS["accepted"] += 1
            print(f"{GREEN}[{get_ts()}][+] ALLOWALL: {client_ip} accepted without checks{RESET}")
            threading.Thread(
                target=bridge,
                args=(c, a, client_ip, args.remoteserver, args.remoteport, args.ssl, total_conn_ever),
                daemon=True
            ).start()
            continue

        # Runtime in-memory blocklist check
        if client_ip in RUNTIME_BLOCKLIST:
            print(f"{RED}[{get_ts()}] RUNTIME BLOCKLIST: blocked {client_ip}{RESET}")
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

        with rules_lock:
            white_entry = ip_in_list(ip_obj, WHITELIST, return_entry=True)
            black_entry = ip_in_list(ip_obj, BLACKLIST, return_entry=True)

        is_white = bool(white_entry)

        # ✅ FIX: whitelist has absolute priority
        if not is_white and black_entry:
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

        # Only unknown (non-whitelisted) IPs get AbuseIPDB check
        if not is_white and ABUSEBLOCK_ENABLED:
            score, source = abuse_lookup_cached(client_ip)
            if score is not None:
                print(f"{YELLOW}[{get_ts()}][INFO] AbuseIPDB score for {client_ip}: {score} (by {source}){RESET}")
                if score >= ABUSE_THRESHOLD:
                    print(f"{RED}[{get_ts()}][!] {client_ip} flagged by AbuseIPDB (score {score}) — auto-blocking{RESET}")

                    if RULEFILE is not None:
                        # Persistent mode
                        add_block_rule(client_ip, score)
                        load_rules()
                    else:
                        # In-memory only
                        print(f"{YELLOW}[{get_ts()}][*] No rules file — auto-blocking {client_ip} in memory only{RESET}")

                    #disconnect_ip(client_ip)
                    disconnect_ip(client_ip, reason=f"AbuseIPDB auto-block (score {score})")
                    RUNTIME_BLOCKLIST.add(client_ip)

                    with stats_lock:
                        STATS["abuse_autoblocked"] += 1
                        AUTO_BLOCKED_IPS.append({
                            "ip": client_ip,
                            "score": score,
                            "ts": get_ts()
                        })

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
