#!/usr/bin/env python3
import socket, ssl, threading, argparse, sys, signal, datetime, os, time, ipaddress, struct, json, requests
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from collections import deque


# v17: two independent directional flags replacing CHAIN_REMOTE_SOCKETS
CLOSE_REMOTE_BY_CLIENT = False   # --closeremotebyclient  : client close → force remote close
CLOSE_CLIENT_BY_REMOTE = False   # --closeclientbyremote  : remote close → force client close

SESSION_HISTORY = deque(maxlen=1000)
session_history_lock = threading.Lock()

# Holds references to SESSION_HISTORY entry dicts for connections whose
# remote socket may still be open after the client disconnected.
# When bridge() finally runs (t2.join() unblocks = remote closed),
# the existing dict is updated in-place via this reference.
SESSION_HISTORY_PENDING = {}   # {conn_id: reference to dict already in SESSION_HISTORY}
session_history_pending_lock = threading.Lock()

CLOSE_REASONS = {}  # {conn_id: reason} — set by disconnect functions, read by pipe/bridge finally
close_reasons_lock = threading.Lock()

VERBOSE_ENABLED = False
verbose_lock = threading.Lock()

TITAN_VERSION = 17
TITAN_DESCRIPTION = f"""\
Titan v{TITAN_VERSION} - Change Log:
v17:    Replaced --chainremotesockets with two independent directional flags:
        --closeremotebyclient : when client closes, Titan also closes the remote socket (v14 behavior)
        --closeclientbyremote : when remote closes, Titan also closes the client socket (new — useful
                                for passive clients like SMTP, Modbus server-push, etc.)
        Default behavior (neither flag): pure v8 TCP isolation — each side closes independently.
        All four combinations are supported.
        /stats endpoint removed — counter ownership was ambiguous across multiple code paths.
        All other v16 features preserved: SESSION_HISTORY_PENDING, remote_status tracking,
        /sessiontable active+closed with Remote column, /closedconnectionstable, all disconnect
        endpoints, verbose/hexdump/abuseblock/rulesfile/allowall.

v16:    Accurate remote socket state tracking in /sessiontable and /closedconnectionstable.
        SESSION_HISTORY_PENDING mechanism for in-place update of remote_status when remote
        eventually closes after a forced disconnect.
        Fixed /sessiontable missing natural client-close entries when remote socket stayed open
        (pipe() CLIENT->REMOTE finally now writes SESSION_HISTORY immediately).

v15:    --chainremotesockets switch (disabled by default).
        Fixed /sessiontable missing forced-disconnect entries (disconnect functions write
        SESSION_HISTORY immediately; bridge() finally skips if already written).

v14:    --abuseblock takes two mandatory args (SCORE APIKEY), eliminating --abuseapikey.

v13:    --verbose CLI flag + /verbose?enable|disable endpoint.
        Direction lines always printed; data content gated on verbose.

v12:    /sessiontable (active + closed rolling buffer of 1000).
        /closedconnectionstable (closed only).

v11:    pipe() force-closes opposite socket on disconnect (symmetric chaining).

v10:    No upstream socket manipulation by pipe().

v09:    Core mandatory switches only; all others optional.

v08:    Last known stable version — AbuseIPDB built-in, HTTP monitor always-on.

Titan Usage examples:
# Production (v8 legacy behavior — TCP isolation, no socket chaining):
sudo nohup python3 -u mitm-global-proxy-v17.py \\
  --listenport 65443 --remoteserver rm.com --remoteport 90 \\
  --abuseblock 50 /home/gv/pytests/abuseipdb.key \\
  --rulesfile /home/gv/pytests/rm-proxy-ip-3.list \\
  --httpexpose 10001 > proxy17.log 2>&1 &

# With client→remote chaining (v14 behavior):
sudo python3 -u mitm-global-proxy-v17.py \\
  --listenport 445 --remoteserver 127.0.0.1 --remoteport 4450 \\
  --closeremotebyclient --httpexpose 10001

# With remote→client chaining (passive client protection):
sudo python3 -u mitm-global-proxy-v17.py \\
  --listenport 445 --remoteserver 127.0.0.1 --remoteport 4450 \\
  --closeclientbyremote --httpexpose 10001

# Fully symmetric (both directions):
sudo python3 -u mitm-global-proxy-v17.py \\
  --listenport 445 --remoteserver 127.0.0.1 --remoteport 4450 \\
  --closeremotebyclient --closeclientbyremote --httpexpose 10001

PS1: For local tests run: nc -l -k -p 4450  or  python3 titan-test-server.py --port 4450
PS2: Recommended to run as a systemd service for auto-restart.
"""

HTTP_PORT_HELP = f"""\
Titan v{TITAN_VERSION} Endpoints [when enabled with --httpexpose <port> (default port=9999)]:
  /status                               GET     List active connections (json)
  /statustable                          GET     List active connections (ascii table)
  /closedconnectionstable               GET     List closed connections (ascii table)
  /sessiontable                         GET     List all last 1000 connections (active & closed - ascii table)
  /rules                                GET     Show allow/block rules (json)
  /rulesallowtable                      GET     Show allow rules (ascii table)
  /rulesblockedtable                    GET     Show blocked rules (ascii table)
  /autoblocked                          GET     Autoblocked IPs in running session (json)
  /autoblockedtable                     GET     Autoblocked IPs in running session (ascii table)
  /disconnect?ip=X                      POST    Disconnect all sessions for given IP
  /disconnect_oldest?ip=X or ID=X       POST    Disconnect oldest session for IP or ID (keeps newest)
  /disconnect_id?ID=X                   POST    Disconnect specific connection ID
  /disconnectall                        POST    Forcibly disconnect ALL active connections (no blocking)
  /autodisconnectoldest                 POST    Per-IP: keep newest, disconnect older connections
  /hexdump?enable/disable               POST    Enable/Disable hex data dumping
  /verbose?enable/disable               POST    Enable/Disable verbose data logging (default=disable)
  /allowall?enable/disable              POST    Enable/Disable allow all IPs (bypasses all checks)
  /newcomerabusecheck?enable/disable    POST    Enable/Disable AbuseIPDB newcomer check at runtime

Usage examples:
    curl -s http://127.0.0.1:9999/statustable
    curl -s http://127.0.0.1:9999/sessiontable
    curl -s -X POST "http://127.0.0.1:9999/disconnect?ip=78.87.123.42"
    curl -s -X POST "http://127.0.0.1:9999/disconnect_id?ID=2"
    curl -s -X POST "http://127.0.0.1:9999/disconnectall"
    curl -s -X POST "http://127.0.0.1:9999/verbose?enable"
    curl -s -X POST "http://127.0.0.1:9999/allowall?enable"
"""

# ANSI Colors
RED, BLUE, GREEN, YELLOW, CYAN, MAGENTA, RESET = (
    '\033[91m', '\033[94m', '\033[92m', '\033[93m', '\033[96m', '\033[95m', '\033[0m'
)

CERTFILE = 'cert.pem'
KEYFILE  = 'key.pem'
RULEFILE = None

HTTP_CTRL_HOST = "127.0.0.1"
HTTP_CTRL_PORT = 9999

RUNTIME_BLOCKLIST = set()
runtime_blocklist_lock = threading.Lock()
ABUSEBLOCK_ENABLED = False

ABUSE_CACHE     = {}
ABUSE_CACHE_TTL = 3600
abuse_cache_lock = threading.Lock()

connection_count = 0
counter_lock = threading.Lock()

WHITELIST    = []
BLACKLIST    = []
OLD_BLACKLIST = []
rules_mtime  = 0
rules_lock   = threading.Lock()

ACTIVE_CONNECTIONS = {}
active_lock = threading.Lock()

HEXDUMP_ENABLED = False
hexdump_lock = threading.Lock()

ABUSE_API_KEY  = None
ABUSE_THRESHOLD = 80
AUTO_BLOCKED_IPS = []
auto_blocked_lock = threading.Lock()

ALLOWALL_ENABLED  = False
_ALLOWALL_SNAPSHOT = {}


# ── helpers ──────────────────────────────────────────────────────────────────

def load_api_key(source=None):
    if source:
        if os.path.isfile(source):
            try:
                with open(source, "r") as f:
                    return f.read().strip()
            except Exception:
                pass
        else:
            return source.strip()
    return None


def get_ts():
    return datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]


def log(msg):
    print(f"[{get_ts()}] {msg}", flush=True)


def _calc_duration(connected_ts, disconnected_ts):
    try:
        dt_conn = datetime.datetime.strptime(connected_ts, "%d-%m-%Y %H:%M:%S.%f")
        dt_disc = datetime.datetime.strptime(disconnected_ts, "%d-%m-%Y %H:%M:%S.%f")
        dur_secs = int((dt_disc - dt_conn).total_seconds())
        if dur_secs < 60:
            return f"{dur_secs}s"
        elif dur_secs < 3600:
            return f"{dur_secs // 60}m {dur_secs % 60}s"
        else:
            return f"{dur_secs // 3600}h {(dur_secs % 3600) // 60}m"
    except Exception:
        return "?"


def signal_handler(sig, frame):
    print(f"\n{GREEN}[{get_ts()}][*] Titan Proxy Shutting down...{RESET}")
    sys.exit(0)


signal.signal(signal.SIGINT, signal_handler)


# ── rules ────────────────────────────────────────────────────────────────────

def parse_rule(line):
    parts = line.split()
    if len(parts) != 2:
        return None, None
    action, value = parts
    try:
        obj = ipaddress.ip_network(value, strict=False) if "/" in value else ipaddress.ip_address(value)
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


def load_rules():
    global WHITELIST, BLACKLIST, OLD_BLACKLIST, rules_mtime
    if RULEFILE is None:
        print(f"{YELLOW}[{get_ts()}][!] No Rule Files specified - all connections are allowed{RESET}")
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
        new_white, new_black = [], []
        with open(RULEFILE) as f:
            for raw in f:
                line = raw.split("#", 1)[0].strip()
                if not line:
                    continue
                action, obj = parse_rule(line)
                if not obj:
                    continue
                comment = raw.split("#", 1)[1].strip() if "#" in raw else ""
                entry = {"obj": obj, "comment": comment}
                if action == "allow":
                    new_white.append(entry)
                elif action == "block":
                    new_black.append(entry)

        with rules_lock:
            WHITELIST = new_white
            BLACKLIST = new_black
            newly_blocked = [e for e in BLACKLIST if e not in OLD_BLACKLIST]
            OLD_BLACKLIST = BLACKLIST.copy()
            rules_mtime = mtime

        print(f"{YELLOW}[{get_ts()}][!] Rules reloaded from {RULEFILE}: "
              f"{len(WHITELIST)} allow, {len(BLACKLIST)} block{RESET}")

        for entry in newly_blocked:
            rule = entry["obj"]
            if isinstance(rule, (ipaddress.IPv4Network, ipaddress.IPv6Network)) and rule.prefixlen == 0:
                continue
            if isinstance(rule, (ipaddress.IPv4Address, ipaddress.IPv6Address)):
                disconnect_ip(str(rule), reason="added to block list")
            else:
                with active_lock:
                    for cid, info in list(ACTIVE_CONNECTIONS.items()):
                        try:
                            ip = ipaddress.ip_address(info["ip"])
                        except Exception:
                            continue
                        if ip in rule:
                            disconnect_ip(info["ip"], reason="added to block list")
    except Exception as e:
        print(f"{RED}[{get_ts()}][!] load_rules() failed: {e}{RESET}")


def rules_watcher():
    while True:
        try:
            load_rules()
        except Exception as e:
            print(f"{RED}[{get_ts()}][!] Rule watcher error: {e}{RESET}")
        time.sleep(5)


# ── disconnect functions ──────────────────────────────────────────────────────

def disconnect_ip(ip_str, reason="block list"):
    with active_lock:
        to_kill = [cid for cid, info in ACTIVE_CONNECTIONS.items() if info["ip"] == ip_str]

    killed = 0
    for cid in to_kill:
        with active_lock:
            info = ACTIVE_CONNECTIONS.get(cid)
            sock = info.get("socket") if info else None
        if not sock:
            continue

        with close_reasons_lock:
            CLOSE_REASONS[cid] = reason

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

        last_client_ts = info.get("last_client_ts", "") if info else ""
        last_remote_ts = info.get("last_remote_ts", "") if info else ""
        conn_comment   = info.get("comment", "") if info else ""
        connected_ts   = info.get("connected_ts", "") if info else ""

        with active_lock:
            ACTIVE_CONNECTIONS.pop(cid, None)

        disconnected_ts = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]
        duration = _calc_duration(connected_ts, disconnected_ts)

        # We closed the client socket. Remote status depends on --closeremotebyclient.
        remote_status = "closed" if CLOSE_REMOTE_BY_CLIENT else "open"

        entry_dict = {
            "id": cid,
            "ip": ip_str,
            "comment": conn_comment,
            "connected_ts": connected_ts,
            "disconnected_ts": disconnected_ts,
            "duration": duration,
            "last_client_ts": last_client_ts,
            "last_remote_ts": last_remote_ts,
            "close_reason": reason,
            "remote_status": remote_status,
        }

        with session_history_lock:
            SESSION_HISTORY.append(entry_dict)

        if remote_status == "open":
            with session_history_pending_lock:
                SESSION_HISTORY_PENDING[cid] = entry_dict

        print(f"{RED}[{get_ts()}][!] Forced disconnect of {ip_str} (ID:#{cid}) — {reason}{RESET}")
        killed += 1

    return killed


def disconnect_connection_id(cid, reason="operator request"):
    with active_lock:
        info = ACTIVE_CONNECTIONS.get(cid)
        if not info:
            return False
        ip   = info.get("ip", "unknown")
        sock = info["socket"]
        try:
            sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        except Exception as e:
            print(f"{YELLOW}[{get_ts()}][dbg] shutdown() ID {cid} ({ip}): {e}{RESET}")
        try:
            sock.close()
        except OSError:
            pass
        except Exception as e:
            print(f"{YELLOW}[{get_ts()}][dbg] close() ID {cid} ({ip}): {e}{RESET}")

        last_client_ts = info.get("last_client_ts", "")
        last_remote_ts = info.get("last_remote_ts", "")
        conn_comment   = info.get("comment", "")
        connected_ts   = info.get("connected_ts", "")
        del ACTIVE_CONNECTIONS[cid]

    with close_reasons_lock:
        CLOSE_REASONS[cid] = reason

    disconnected_ts = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]
    duration = _calc_duration(connected_ts, disconnected_ts)

    remote_status = "closed" if CLOSE_REMOTE_BY_CLIENT else "open"

    entry_dict = {
        "id": cid,
        "ip": ip,
        "comment": conn_comment,
        "connected_ts": connected_ts,
        "disconnected_ts": disconnected_ts,
        "duration": duration,
        "last_client_ts": last_client_ts,
        "last_remote_ts": last_remote_ts,
        "close_reason": reason,
        "remote_status": remote_status,
    }

    with session_history_lock:
        SESSION_HISTORY.append(entry_dict)

    if remote_status == "open":
        with session_history_pending_lock:
            SESSION_HISTORY_PENDING[cid] = entry_dict

    print(f"{RED}[{get_ts()}][!] Forced disconnect of ID:#{cid} ({ip}) — {reason}{RESET}")
    return True


# ── pipe & bridge ─────────────────────────────────────────────────────────────

def format_hexdump(data):
    lines = []
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        hex_part  = " ".join(f"{b:02x}" for b in chunk)
        ascii_part = "".join(chr(b) if 32 <= b <= 126 else "." for b in chunk)
        lines.append(f"{CYAN}{i:04x}  {hex_part:<48}  |{ascii_part}|{RESET}")
    return "\n".join(lines)


def pipe(source, destination, label, color, conn_id, client_ip):
    try:
        while True:
            data = source.recv(8192)
            if not data:
                # Source closed — propagate to destination if the relevant flag is set
                if label == "CLIENT->REMOTE" and CLOSE_REMOTE_BY_CLIENT:
                    try:
                        destination.shutdown(socket.SHUT_RDWR)
                    except Exception:
                        pass
                elif label == "REMOTE->CLIENT" and CLOSE_CLIENT_BY_REMOTE:
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
                        if info.get("remote_closed", False):
                            break
                    else:
                        info["last_remote_ts"] = ts_now

            with rules_lock:
                entry  = ip_in_list(ipaddress.ip_address(client_ip), WHITELIST, return_entry=True)
                comment = f"  # {entry['comment']}" if entry and entry["comment"] else ""

            print(f"{color}[{get_ts()}] [ID:#{conn_id}] ({client_ip}) {label}:{comment}{RESET}")

            with verbose_lock:
                show_verbose = VERBOSE_ENABLED
            if show_verbose:
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
        # Exception on source — propagate to destination if flag set
        if label == "CLIENT->REMOTE" and CLOSE_REMOTE_BY_CLIENT:
            try:
                destination.shutdown(socket.SHUT_RDWR)
            except Exception:
                pass
        elif label == "REMOTE->CLIENT" and CLOSE_CLIENT_BY_REMOTE:
            try:
                destination.shutdown(socket.SHUT_RDWR)
            except Exception:
                pass

    finally:
        if label == "REMOTE->CLIENT":
            # Mark remote as closed so CLIENT->REMOTE finally can read the flag
            with active_lock:
                info = ACTIVE_CONNECTIONS.get(conn_id)
                if info is not None:
                    info["remote_closed"] = True
                    print(f"{YELLOW}[{get_ts()}][*] [ID:#{conn_id}] Remote socket closed by remote server{RESET}")

        elif label == "CLIENT->REMOTE":
            # Client side gone — write SESSION_HISTORY immediately so /sessiontable
            # reflects reality without waiting for t2.join() to unblock.
            with active_lock:
                info = ACTIVE_CONNECTIONS.pop(conn_id, None)

            if info is None:
                # Forced disconnect already handled everything — nothing to do
                return

            with close_reasons_lock:
                close_reason = CLOSE_REASONS.pop(conn_id, "natural disc.")

            disconnected_ts = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]
            duration = _calc_duration(info.get("connected_ts", ""), disconnected_ts)

            remote_closed = info.get("remote_closed", False)
            remote_status = "closed" if remote_closed else "open"

            entry_dict = {
                "id": conn_id,
                "ip": client_ip,
                "comment": info.get("comment", ""),
                "connected_ts": info.get("connected_ts", ""),
                "disconnected_ts": disconnected_ts,
                "duration": duration,
                "last_client_ts": info.get("last_client_ts", ""),
                "last_remote_ts": info.get("last_remote_ts", ""),
                "close_reason": close_reason,
                "remote_status": remote_status,
            }

            with session_history_lock:
                SESSION_HISTORY.append(entry_dict)

            if remote_status == "open":
                with session_history_pending_lock:
                    SESSION_HISTORY_PENDING[conn_id] = entry_dict

            print(f"{MAGENTA}[{get_ts()}][-] [ID:#{conn_id}] DISCONNECTED {client_ip} "
                  f"— {close_reason} (remote: {remote_status}){RESET}")


def bridge(client_sock, addr, client_ip, remote_host, remote_port, force_ssl, conn_id):
    global connection_count

    connected_ts = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]

    with rules_lock:
        entry = ip_in_list(ipaddress.ip_address(client_ip), WHITELIST, return_entry=True)

    tag         = " (white-listed)" if entry else "(newcommer)"
    comment     = f"  # {entry['comment']}" if entry and entry["comment"] else ""
    conn_comment = entry["comment"] if entry and entry["comment"] else ""

    with active_lock:
        ACTIVE_CONNECTIONS[conn_id] = {
            "ip": client_ip,
            "socket": client_sock,
            "connected_ts": connected_ts,
            "last_client_ts": connected_ts,
            "last_remote_ts": connected_ts,
            "comment": conn_comment,
        }

    print(f"{GREEN}[{get_ts()}][+] [ID:#{conn_id}] CONNECTED: {client_ip}{tag}{comment} "
          f"(Active: {connection_count}){RESET}")

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
        t2 = threading.Thread(target=pipe, args=(r_conn, c_conn, "REMOTE->CLIENT", RED,  conn_id, client_ip), daemon=True)

        t1.start()
        t2.start()
        t1.join()
        t2.join()

    except Exception as e:
        print(f"{RED}[{get_ts()}][!] [ID:#{conn_id}] Error: {e}{RESET}")

    finally:
        disconnected_ts = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]

        with counter_lock:
            connection_count -= 1

        with active_lock:
            info = ACTIVE_CONNECTIONS.pop(conn_id, None)

        with close_reasons_lock:
            close_reason = CLOSE_REASONS.pop(conn_id, "natural disc.")

        if info is not None:
            # pipe() CLIENT->REMOTE never ran (e.g. remote_sock.connect() failed),
            # or some other edge case — write SESSION_HISTORY here.
            duration = _calc_duration(connected_ts, disconnected_ts)
            with session_history_lock:
                SESSION_HISTORY.append({
                    "id": conn_id,
                    "ip": client_ip,
                    "comment": info.get("comment", ""),
                    "connected_ts": connected_ts,
                    "disconnected_ts": disconnected_ts,
                    "duration": duration,
                    "last_client_ts": info.get("last_client_ts", ""),
                    "last_remote_ts": info.get("last_remote_ts", ""),
                    "close_reason": close_reason,
                    "remote_status": "closed",
                })
            print(f"{MAGENTA}[{get_ts()}][-] [ID:#{conn_id}] DISCONNECTED {client_ip} "
                  f"(Active: {connection_count}) — {close_reason}{RESET}")

        else:
            # pipe() CLIENT->REMOTE already wrote SESSION_HISTORY.
            # t2.join() unblocking here means remote socket finally closed.
            with session_history_pending_lock:
                pending_entry = SESSION_HISTORY_PENDING.pop(conn_id, None)
            if pending_entry is not None:
                pending_entry["remote_status"] = "closed"
                print(f"{YELLOW}[{get_ts()}][*] [ID:#{conn_id}] Remote socket now closed{RESET}")

        for s in (client_sock, remote_sock):
            try:
                s.close()
            except Exception:
                pass


# ── TCP sniffer ───────────────────────────────────────────────────────────────

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
    return {
        'ihl': ihl,
        'total_length': iph[2],
        'proto': iph[6],
        'src_ip': socket.inet_ntoa(iph[8]),
        'dst_ip': socket.inet_ntoa(iph[9]),
    }


def parse_tcp_header(data):
    if len(data) < 20:
        return None
    tcph = struct.unpack('!HHLLBBHHH', data[:20])
    return {
        'src_port': tcph[0],
        'dst_port': tcph[1],
        'seq': tcph[2],
        'ack_seq': tcph[3],
        'data_offset': (tcph[4] >> 4) * 4,
        'flags': tcph[5],
    }


def tcp_flag_labels(flags):
    syn = bool(flags & 0x02)
    ack = bool(flags & 0x10)
    fin = bool(flags & 0x01)
    rst = bool(flags & 0x04)
    if syn and ack: return "SYN/ACK"
    if syn:         return "SYN"
    if fin:         return "FIN"
    if rst:         return "RST"
    if ack:         return "ACK"
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
            raw_data, _ = sniffer.recvfrom(65535)
        except Exception:
            continue
        _, _, eth_proto = parse_ethernet_header(raw_data)
        if eth_proto != 0x0800:
            continue
        ip_part = raw_data[14:]
        iphdr = parse_ipv4_header(ip_part)
        if not iphdr or iphdr['proto'] != 6:
            continue
        tcphdr = parse_tcp_header(ip_part[iphdr['ihl']:])
        if not tcphdr:
            continue
        sp, dp = tcphdr['src_port'], tcphdr['dst_port']
        if not (sp == listen_port or dp == listen_port or sp == remote_port or dp == remote_port):
            continue
        label = tcp_flag_labels(tcphdr['flags'])
        if not label:
            continue
        def pip(ip):
            return remote_host if ip == remote_ip else ip
        src_ip = iphdr['src_ip']
        dst_ip = iphdr['dst_ip']
        print(f"{YELLOW}[{get_ts()}] [TCP] [{label}] {pip(src_ip)}:{sp} -> {pip(dst_ip)}:{dp}{RESET}")


# ── AbuseIPDB ────────────────────────────────────────────────────────────────

def add_block_rule(ip, score=None):
    try:
        comment = f" # auto block by abuse - score {score}" if score is not None else ""
        with open(RULEFILE, "a") as f:
            f.write(f"block {ip}{comment}\n")
        print(f"{RED}[{get_ts()}][!] Auto-added block rule for {ip}{comment}{RESET}")
    except Exception as e:
        print(f"{RED}[{get_ts()}][!] Failed to write block rule for {ip}: {e}{RESET}")


def abuse_lookup(ip):
    try:
        r = requests.get(
            "https://api.abuseipdb.com/api/v2/check",
            headers={"Key": ABUSE_API_KEY, "Accept": "application/json"},
            params={"ipAddress": ip, "maxAgeInDays": "90"},
            timeout=3
        )
        return r.json()["data"]["abuseConfidenceScore"]
    except Exception as e:
        print(f"{RED}[{get_ts()}][!] AbuseIPDB lookup failed for {ip}: {e}{RESET}")
        return None


def abuse_lookup_cached(ip):
    now = time.time()
    with abuse_cache_lock:
        entry = ABUSE_CACHE.get(ip)
        if entry and now - entry[1] < ABUSE_CACHE_TTL:
            return entry[0], "cache"
    score = abuse_lookup(ip)
    if score is not None:
        with abuse_cache_lock:
            ABUSE_CACHE[ip] = (score, now)
    return score, "api"


# ── HTTP handler ──────────────────────────────────────────────────────────────

def make_table(rows, headers):
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(str(cell)))
    sep        = "+" + "+".join("-" * (w + 2) for w in widths) + "+"
    header_row = "| " + " | ".join(h.ljust(widths[i]) for i, h in enumerate(headers)) + " |"
    data_rows  = ["| " + " | ".join(str(row[i]).ljust(widths[i]) for i in range(len(headers))) + " |"
                  for row in rows]
    return "\n".join([sep, header_row, sep] + data_rows + [sep])


class TitanHTTPHandler(BaseHTTPRequestHandler):

    def _json(self, code, payload):
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _table(self, rows, headers):
        body = make_table(rows, headers).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/status":
            with active_lock, rules_lock, runtime_blocklist_lock:
                active = []
                for cid, info in ACTIVE_CONNECTIONS.items():
                    ip    = info["ip"]
                    entry = ip_in_list(ipaddress.ip_address(ip), WHITELIST, return_entry=True)
                    active.append({
                        "id": cid, "ip": ip,
                        "comment": entry["comment"] if entry and entry["comment"] else "",
                        "connected_ts":   info.get("connected_ts", ""),
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
                    "close_remote_by_client": CLOSE_REMOTE_BY_CLIENT,
                    "close_client_by_remote": CLOSE_CLIENT_BY_REMOTE,
                }
            self._json(200, status)

        elif parsed.path == "/rules":
            with rules_lock:
                allow = [str(e["obj"]) for e in WHITELIST]
                block = [str(e["obj"]) for e in BLACKLIST]
            self._json(200, {"allow": allow, "block": block})

        elif parsed.path == "/autoblocked":
            with auto_blocked_lock:
                snapshot = list(AUTO_BLOCKED_IPS)
            self._json(200, {"autoblocked": snapshot})

        elif parsed.path == "/autoblockedtable":
            with auto_blocked_lock:
                snapshot = list(AUTO_BLOCKED_IPS)
            self._table([[e.get("ip",""), e.get("score",""), e.get("ts","")] for e in snapshot],
                        ["IP", "Score", "Timestamp"])

        elif parsed.path == "/rulesallowtable":
            with rules_lock:
                rows = [[str(e["obj"]), e["comment"]] for e in WHITELIST]
            self._table(rows, ["Allow Rule", "Comment"])

        elif parsed.path == "/rulesblockedtable":
            with rules_lock:
                rows = [[str(e["obj"]), e["comment"]] for e in BLACKLIST]
            self._table(rows, ["Block Rule", "Comment"])

        elif parsed.path == "/statustable":
            now  = datetime.datetime.now()
            rows = []
            with active_lock, rules_lock:
                for cid, info in ACTIVE_CONNECTIONS.items():
                    ip             = info["ip"]
                    connected_ts   = info.get("connected_ts", "")
                    last_client_ts = info.get("last_client_ts", "")
                    last_remote_ts = info.get("last_remote_ts", "")
                    entry   = ip_in_list(ipaddress.ip_address(ip), WHITELIST, return_entry=True)
                    comment = entry["comment"] if entry and entry["comment"] else ""
                    try:
                        last_dt   = datetime.datetime.strptime(last_remote_ts, "%d-%m-%Y %H:%M:%S.%f")
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
                    rows.append([cid, ip, comment, connected_ts, last_client_ts, last_remote_ts, idle_str])
            self._table(rows, ["ID", "IP", "Comment", "Connected",
                                "Last From Client", "Last From Remote", "Upstream Idle"])

        elif parsed.path == "/closedconnectionstable":
            with session_history_lock:
                snapshot = list(SESSION_HISTORY)
            rows = [[s.get("id",""), s.get("ip",""), s.get("comment",""),
                     s.get("connected_ts",""), s.get("disconnected_ts",""),
                     s.get("duration",""), s.get("last_client_ts",""),
                     s.get("last_remote_ts",""), s.get("close_reason",""),
                     s.get("remote_status","?")] for s in snapshot]
            self._table(rows, ["ID", "IP", "Comment", "Connected", "Client Disc",
                                "Duration", "Last Client", "Last Remote", "Reason", "Remote"])

        elif parsed.path == "/sessiontable":
            now  = datetime.datetime.now()
            rows = []
            with active_lock:
                for cid, info in ACTIVE_CONNECTIONS.items():
                    ip             = info.get("ip", "")
                    connected_ts   = info.get("connected_ts", "")
                    last_client_ts = info.get("last_client_ts", "")
                    last_remote_ts = info.get("last_remote_ts", "")
                    try:
                        dt_conn  = datetime.datetime.strptime(connected_ts, "%d-%m-%Y %H:%M:%S.%f")
                        dur_secs = int((now - dt_conn).total_seconds())
                        if dur_secs < 60:
                            duration = f"{dur_secs}s"
                        elif dur_secs < 3600:
                            duration = f"{dur_secs // 60}m {dur_secs % 60}s"
                        else:
                            duration = f"{dur_secs // 3600}h {(dur_secs % 3600) // 60}m"
                    except Exception:
                        duration = "?"
                    
                    remote_str = "closed" if info.get("remote_closed", False) else "open"

                    rows.append([cid, ip, info.get("comment",""),
                                 connected_ts, "--- ACTIVE ---", duration,
                                 last_client_ts, last_remote_ts, "active", remote_str])
                    
            with session_history_lock:
                snapshot = list(SESSION_HISTORY)
            for s in snapshot:
                rows.append([s.get("id",""), s.get("ip",""), s.get("comment",""),
                             s.get("connected_ts",""), s.get("disconnected_ts",""),
                             s.get("duration",""), s.get("last_client_ts",""),
                             s.get("last_remote_ts",""), s.get("close_reason",""),
                             s.get("remote_status","?")])
            self._table(rows, ["ID", "IP", "Comment", "Client Conn", "Client Disc",
                                "Duration", "Last Client", "Last Remote", "Reason", "Remote"])

        elif parsed.path == "/help":
            body = HTTP_PORT_HELP.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):
        global HEXDUMP_ENABLED, ABUSEBLOCK_ENABLED, ALLOWALL_ENABLED, _ALLOWALL_SNAPSHOT

        parsed = urlparse(self.path)
        qs     = parse_qs(parsed.query)

        if parsed.path == "/disconnect":
            ip = qs.get("ip", [None])[0]
            if not ip:
                self._json(400, {"error": "missing ip"})
                return
            killed = disconnect_ip(ip, reason="HTTP operator request")
            self._json(200, {"ip": ip, "disconnected": killed})

        elif parsed.path == "/disconnect_oldest":
            ip      = qs.get("ip",  [None])[0]
            cid_raw = qs.get("ID",  [None])[0]
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
            if not ip:
                self._json(400, {"error": "missing ip or ID"})
                return
            matches = []
            with active_lock:
                for cid2, info2 in ACTIVE_CONNECTIONS.items():
                    if info2["ip"] == ip:
                        matches.append((cid2, info2["connected_ts"]))
            if not matches:
                self._json(200, {"ip": ip, "disconnected": None, "reason": "no active connections"})
                return
            from datetime import datetime as dt
            matches.sort(key=lambda x: dt.strptime(x[1], "%d-%m-%Y %H:%M:%S.%f"))
            newest_cid   = matches[-1][0]
            disconnected = []
            for cid2, _ in matches[:-1]:
                if disconnect_connection_id(cid2, reason="HTTP operator — keep newest only"):
                    disconnected.append(cid2)
            self._json(200, {"ip": ip, "kept_id": newest_cid,
                             "disconnected_ids": disconnected, "remaining_connections": 1})

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
            with active_lock:
                info = ACTIVE_CONNECTIONS.get(cid)
                ip   = info["ip"] if info else None
            killed = disconnect_connection_id(cid, reason="HTTP operator request")
            if not killed:
                self._json(404, {"error": f"connection ID {cid} not found"})
                return
            self._json(200, {"disconnected_id": cid, "ip": ip})

        elif parsed.path == "/disconnectall":
            with active_lock:
                unique_ips = list(set(info["ip"] for info in ACTIVE_CONNECTIONS.values()))
            if not unique_ips:
                self._json(200, {"result": "ok", "note": "No active connections", "disconnected_ips": []})
                return
            total_killed = sum(disconnect_ip(ip, reason="HTTP operator — disconnectall")
                               for ip in unique_ips)
            print(f"{YELLOW}[{get_ts()}][*] DISCONNECTALL — {total_killed} connections terminated{RESET}")
            self._json(200, {"result": "ok", "disconnected_ips": unique_ips,
                             "total_disconnected": total_killed})

        elif parsed.path == "/autodisconnectoldest":
            disconnected = {}
            with active_lock:
                ip_groups = {}
                for cid, info in ACTIVE_CONNECTIONS.items():
                    ip_groups.setdefault(info["ip"], []).append((cid, info.get("connected_ts","")))
            from datetime import datetime as dt
            for ip, items in ip_groups.items():
                if len(items) <= 1:
                    continue
                items.sort(key=lambda x: dt.strptime(x[1], "%d-%m-%Y %H:%M:%S.%f"))
                keep   = items[-1][0]
                killed = [cid for cid, _ in items[:-1]
                          if disconnect_connection_id(cid, reason="HTTP auto disconnect — keep newest only")]
                if killed:
                    disconnected[ip] = {"kept_id": keep, "disconnected_ids": killed}
            self._json(200, {"result": "ok", "disconnected_groups": disconnected})

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
                self._json(400, {"error": "Use ?enable or ?disable", "hexdump": HEXDUMP_ENABLED})

        elif parsed.path == "/verbose":
            global VERBOSE_ENABLED
            if parsed.query == "enable":
                with verbose_lock:
                    VERBOSE_ENABLED = True
                print(f"{YELLOW}[{get_ts()}][*] Verbose logging ENABLED via HTTP control{RESET}")
                self._json(200, {"verbose": True})
            elif parsed.query == "disable":
                with verbose_lock:
                    VERBOSE_ENABLED = False
                print(f"{YELLOW}[{get_ts()}][*] Verbose logging DISABLED via HTTP control{RESET}")
                self._json(200, {"verbose": False})
            else:
                with verbose_lock:
                    current = VERBOSE_ENABLED
                self._json(400, {"error": "Use ?enable or ?disable", "verbose": current})

        elif parsed.path == "/allowall":
            if parsed.query == "enable":
                if ALLOWALL_ENABLED:
                    self._json(200, {"allowall": True, "note": "Already active"})
                    return
                _ALLOWALL_SNAPSHOT = {"ABUSEBLOCK_ENABLED": ABUSEBLOCK_ENABLED}
                ABUSEBLOCK_ENABLED = False
                ALLOWALL_ENABLED   = True
                print(f"{YELLOW}[{get_ts()}][*] ALLOWALL ENABLED — all IP checks suspended{RESET}")
                self._json(200, {"allowall": True, "snapshot_saved": _ALLOWALL_SNAPSHOT,
                                 "note": "Blacklist, whitelist and abuse check suspended"})
            elif parsed.query == "disable":
                if not ALLOWALL_ENABLED:
                    self._json(200, {"allowall": False, "note": "Already inactive"})
                    return
                ABUSEBLOCK_ENABLED = _ALLOWALL_SNAPSHOT.get("ABUSEBLOCK_ENABLED", False)
                ALLOWALL_ENABLED   = False
                _ALLOWALL_SNAPSHOT = {}
                print(f"{YELLOW}[{get_ts()}][*] ALLOWALL DISABLED — "
                      f"previous behavior restored (abuseblock={ABUSEBLOCK_ENABLED}){RESET}")
                self._json(200, {"allowall": False,
                                 "restored": {"abuseblock_enabled": ABUSEBLOCK_ENABLED},
                                 "note": "Rules file enforcement and abuse check restored"})
            else:
                self._json(400, {"error": "Use ?enable or ?disable", "allowall": ALLOWALL_ENABLED})

        elif parsed.path == "/newcomerabusecheck":
            if parsed.query == "enable":
                if not ABUSE_API_KEY:
                    self._json(409, {"error": "Cannot enable — no AbuseIPDB API key at startup",
                                     "newcomer_abuse_check": False})
                    return
                ABUSEBLOCK_ENABLED = True
                print(f"{YELLOW}[{get_ts()}][*] Newcomer abuse check ENABLED — threshold: {ABUSE_THRESHOLD}{RESET}")
                self._json(200, {"newcomer_abuse_check": True, "threshold": ABUSE_THRESHOLD})
            elif parsed.query == "disable":
                ABUSEBLOCK_ENABLED = False
                print(f"{YELLOW}[{get_ts()}][*] Newcomer abuse check DISABLED{RESET}")
                self._json(200, {"newcomer_abuse_check": False,
                                 "note": "Blacklist, whitelist and runtime blocklist remain active"})
            else:
                self._json(400, {"error": "Use ?enable or ?disable",
                                 "newcomer_abuse_check": ABUSEBLOCK_ENABLED})

        else:
            self._json(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        return


def http_control_loop():
    srv = HTTPServer((HTTP_CTRL_HOST, HTTP_CTRL_PORT), TitanHTTPHandler)
    log(f"[*] Titan v{TITAN_VERSION} HTTP control on http://{HTTP_CTRL_HOST}:{HTTP_CTRL_PORT}")
    srv.serve_forever()


# ── main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=TITAN_DESCRIPTION,
                                     formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--listenport",          type=int, required=True,
                        help="Listening port of proxy")
    parser.add_argument("--remoteserver",         required=True,
                        help="Address to forward data to")
    parser.add_argument("--remoteport",           type=int, required=True,
                        help="Port of remote server")
    parser.add_argument("--ssl",                  action="store_true")
    parser.add_argument("--hexdump",              action="store_true",
                        help="Enable hex data dumping")
    parser.add_argument("--tcp-sniff",            action="store_true",
                        help="Enable AF_PACKET TCP handshake logging (Linux/root)")
    parser.add_argument("--httpexpose",           type=int, metavar="HTTPPORT",
                        help="Enable HTTP control on given port")
    parser.add_argument("--rulesfile",            type=str,
                        help="Rules file for allow/block entries")
    parser.add_argument("--abuseblock",           nargs=2, metavar=("SCORE", "APIKEY"),
                        help="Enable AbuseIPDB check. Example: --abuseblock 80 /path/to/key.txt")
    parser.add_argument("--verbose",              action="store_true",
                        help="Enable verbose data logging (default=disabled)")
    parser.add_argument("--closeremotebyclient",  action="store_true",
                        help="When client closes, force remote socket close (default=disabled)")
    parser.add_argument("--closeclientbyremote",  action="store_true",
                        help="When remote closes, force client socket close (default=disabled)")
    args = parser.parse_args()

    if args.verbose:
        with verbose_lock:
            VERBOSE_ENABLED = True

    if args.closeremotebyclient:
        CLOSE_REMOTE_BY_CLIENT = True

    if args.closeclientbyremote:
        CLOSE_CLIENT_BY_REMOTE = True

    if args.httpexpose is not None:
        HTTP_CTRL_PORT = args.httpexpose
        http_enabled = True
    else:
        http_enabled = False

    RULEFILE = args.rulesfile if args.rulesfile else None

    if args.abuseblock is not None:
        abuse_score_str, abuse_key_src = args.abuseblock
        try:
            ABUSE_THRESHOLD = int(abuse_score_str)
        except ValueError:
            print(f"{RED}[{get_ts()}][!] --abuseblock score must be an integer{RESET}")
            sys.exit(1)
        ABUSE_API_KEY = load_api_key(abuse_key_src)
        if not ABUSE_API_KEY:
            print(f"{RED}[{get_ts()}][!] --abuseblock API key could not be loaded from: {abuse_key_src}{RESET}")
            sys.exit(1)
        ABUSEBLOCK_ENABLED = True
        print(f"{YELLOW}[{get_ts()}][*] Abuse score check enabled — threshold: {ABUSE_THRESHOLD}{RESET}")
    else:
        ABUSEBLOCK_ENABLED = False
        print(f"{YELLOW}[{get_ts()}][*] Abuse score check disabled{RESET}")

    if RULEFILE is not None:
        load_rules()
        threading.Thread(target=rules_watcher, daemon=True).start()
    else:
        print(f"{YELLOW}[{get_ts()}][*] No rules file provided — rule watcher disabled{RESET}")

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
        print(f"{YELLOW}[{get_ts()}][*] HTTP control disabled (no --httpexpose){RESET}")

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', args.listenport))
    server.listen(100)
    total_conn_ever = 0

    print(f"{CYAN}[{get_ts()}][*] ---- Titan v{TITAN_VERSION} Startup Summary -------------------------")
    print(f"{CYAN}[{get_ts()}][*] Listen Port:              {args.listenport}")
    print(f"{CYAN}[{get_ts()}][*] Remote Server:            {args.remoteserver}:{args.remoteport}")
    print(f"{CYAN}[{get_ts()}][*] HTTP Monitor/Control:     "
          f"{'Enabled on port ' + str(HTTP_CTRL_PORT) if http_enabled else 'Disabled'}")
    print(f"{CYAN}[{get_ts()}][*] Verbose Logging:          {'Enabled' if args.verbose else 'Disabled'}")
    print(f"{CYAN}[{get_ts()}][*] Hexdump Mode:             {'Enabled' if args.hexdump else 'Disabled'}")
    print(f"{CYAN}[{get_ts()}][*] TCP Sniff Mode:           {'Enabled' if args.tcp_sniff else 'Disabled'}")
    print(f"{CYAN}[{get_ts()}][*] Rules File:               "
          f"{RULEFILE if RULEFILE else 'None (disabled)'}")
    print(f"{CYAN}[{get_ts()}][*] Abuse Score Checking:     "
          f"{'Enabled (threshold ' + str(ABUSE_THRESHOLD) + ')' if ABUSEBLOCK_ENABLED else 'Disabled'}")
    print(f"{CYAN}[{get_ts()}][*] Close Remote By Client:   {'Enabled' if args.closeremotebyclient else 'Disabled'}")
    print(f"{CYAN}[{get_ts()}][*] Close Client By Remote:   {'Enabled' if args.closeclientbyremote else 'Disabled'}")
    print(f"{CYAN}[{get_ts()}][*] -------------------------------------------------------")

    if args.tcp_sniff:
        print(f"{CYAN}[{get_ts()}][*] TCP handshake logging ENABLED (--tcp-sniff){RESET}")

    while True:
        try:
            c, a = server.accept()
        except Exception as e:
            print(f"{RED}[{get_ts()}][!] Accept error: {e}{RESET}")
            continue

        client_ip = a[0]
        ip_obj    = ipaddress.ip_address(client_ip)

        if ALLOWALL_ENABLED:
            total_conn_ever += 1
            with counter_lock:
                connection_count += 1
            print(f"{GREEN}[{get_ts()}][+] ALLOWALL: {client_ip} accepted without checks{RESET}")
            threading.Thread(
                target=bridge,
                args=(c, a, client_ip, args.remoteserver, args.remoteport, args.ssl, total_conn_ever),
                daemon=True
            ).start()
            continue

        with runtime_blocklist_lock:
            in_blocklist = client_ip in RUNTIME_BLOCKLIST
        if in_blocklist:
            print(f"{RED}[{get_ts()}] RUNTIME BLOCKLIST: blocked {client_ip}{RESET}")
            try: c.shutdown(socket.SHUT_RDWR)
            except Exception: pass
            try: c.close()
            except Exception: pass
            continue

        with rules_lock:
            white_entry = ip_in_list(ip_obj, WHITELIST, return_entry=True)
            black_entry = ip_in_list(ip_obj, BLACKLIST, return_entry=True)
        is_white = bool(white_entry)

        if not is_white and black_entry:
            print(f"{RED}[{get_ts()}] BLOCKED ATTEMPT from {client_ip}{RESET}")
            try: c.shutdown(socket.SHUT_RDWR)
            except Exception: pass
            try: c.close()
            except Exception: pass
            continue

        if not is_white and ABUSEBLOCK_ENABLED:
            score, source = abuse_lookup_cached(client_ip)
            if score is not None:
                print(f"{YELLOW}[{get_ts()}][INFO] AbuseIPDB score for {client_ip}: {score} (by {source}){RESET}")
                if score >= ABUSE_THRESHOLD:
                    print(f"{RED}[{get_ts()}][!] {client_ip} flagged (score {score}) — auto-blocking{RESET}")
                    if RULEFILE:
                        add_block_rule(client_ip, score)
                        load_rules()
                    else:
                        print(f"{YELLOW}[{get_ts()}][*] No rules file — blocking in memory only{RESET}")
                    disconnect_ip(client_ip, reason=f"AbuseIPDB auto-block (score {score})")
                    with runtime_blocklist_lock:
                        RUNTIME_BLOCKLIST.add(client_ip)
                    with auto_blocked_lock:
                        AUTO_BLOCKED_IPS.append({"ip": client_ip, "score": score, "ts": get_ts()})
                    continue

        total_conn_ever += 1
        with counter_lock:
            connection_count += 1

        threading.Thread(
            target=bridge,
            args=(c, a, a[0], args.remoteserver, args.remoteport, args.ssl, total_conn_ever),
            daemon=True
        ).start()
