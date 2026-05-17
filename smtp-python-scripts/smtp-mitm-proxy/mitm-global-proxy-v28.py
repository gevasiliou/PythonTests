#!/usr/bin/env python3
import socket, ssl, threading, argparse, sys, signal, datetime, os, time, ipaddress
import struct, json, requests, re, secrets, hashlib
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn
from urllib.parse import urlparse, parse_qs
from collections import deque

DASHBOARD_HTML = "dashboard28.html"
TITAN_VERSION  = 28

TCP_SNIFF_ENABLED = False
# ── v18: directional flags (unchanged from v17) ───────────────────────────
CLOSE_REMOTE_BY_CLIENT = False
CLOSE_CLIENT_BY_REMOTE = False

# ── v18: Dashboard globals ────────────────────────────────────────────────
LOG_BUFFER = deque(maxlen=2000)          # rolling log for dashboard
log_buffer_lock = threading.Lock()
LOG_SEQ = 0                             # monotonic sequence for incremental fetch
log_seq_lock = threading.Lock()

DASHBOARD_SESSIONS = {}                 # {token: expiry_timestamp}
dashboard_sessions_lock = threading.Lock()
DASHBOARD_USER      = None
DASHBOARD_PASS_HASH = None
DASHBOARD_PATH      = None             # path to titan-dashboard/ folder

TITAN_START_TIME    = time.time()

# Set in __main__ so dashboard/data can report them
TITAN_LISTEN_PORT   = 0
TITAN_REMOTE_SERVER = ""
TITAN_REMOTE_PORT   = 0

_ANSI_RE = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')

def _strip_ansi(s):
    return _ANSI_RE.sub('', s)

def tlog(msg, level="INFO"):
    """Print to stdout AND append a clean line to LOG_BUFFER for the dashboard."""
    global LOG_SEQ
    print(msg, flush=True)
    clean = _strip_ansi(msg).strip()
    # Remove leading [dd-mm-yyyy hh:mm:ss.mmm] timestamp if present
    clean = re.sub(r'^\[\d{2}-\d{2}-\d{4} \d{2}:\d{2}:\d{2}\.\d{3}\]', '', clean).strip()
    ts = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]
    with log_seq_lock:
        LOG_SEQ += 1
        seq = LOG_SEQ
    with log_buffer_lock:
        LOG_BUFFER.append({"seq": seq, "ts": ts, "level": level, "msg": clean})

def _check_dashboard_auth(handler):
    """Return True if request carries a valid dashboard session cookie."""
    if DASHBOARD_USER is None or DASHBOARD_PATH is None:
        return False
    cookie = handler.headers.get("Cookie", "")
    for part in cookie.split(";"):
        part = part.strip()
        if part.startswith("titan_session="):
            token = part[len("titan_session="):]
            with dashboard_sessions_lock:
                expiry = DASHBOARD_SESSIONS.get(token)
                if expiry and time.time() < expiry:
                    return True
    return False

def _redirect(handler, location, code=302):
    handler.send_response(code)
    handler.send_header("Location", location)
    handler.send_header("Content-Length", "0")
    handler.end_headers()

def _calc_uptime():
    secs = int(time.time() - TITAN_START_TIME)
    if secs < 60:   return f"{secs}s", secs
    if secs < 3600: return f"{secs//60}m {secs%60}s", secs
    return f"{secs//3600}h {(secs%3600)//60}m", secs

# ── Session / connection tracking ─────────────────────────────────────────
SESSION_HISTORY = deque(maxlen=1000)
session_history_lock = threading.Lock()

SESSION_HISTORY_PENDING = {}
session_history_pending_lock = threading.Lock()

PENDING_REMOTE_SOCKETS = {}                    
pending_remote_sockets_lock = threading.Lock() 

CLOSE_REASONS = {}
close_reasons_lock = threading.Lock()

VERBOSE_ENABLED = False
verbose_lock = threading.Lock()

VERBOSE_WATCH = set()   # conn_ids to verbosely log
verbose_watch_lock = threading.Lock()

HEXDUMP_WATCH      = set()  # conn_ids with per-id hexdump enabled
HEXDUMP_WATCH_PREV = {}     # {conn_id: bool} watch state before hex on
hexdump_watch_lock = threading.Lock()

TCP_WATCH      = set()   # <- add  conn_ids with per-id tcp sniff enabled
TCP_WATCH_PREV = {}      # <- add  {conn_id: bool} watch state before global tcp sniff on
tcp_watch_lock = threading.Lock()  # <- add

REMOTE_PORT_MAP      = {}                   # <- add  {ephemeral_port: conn_id}
remote_port_map_lock = threading.Lock()     # <- add

CLIENT_PORT_MAP      = {}
client_port_map_lock = threading.Lock()

TITAN_CHANGELOG = f"""\
TITAN TCP Proxy Changelog
Current Titan Version is v{TITAN_VERSION}

TODO:   Since after v26 tcp sniff is by default enabled (but not printed) we can now easily provide per-ID tcp-sniff printing.
        Provide Option to search rules file (by dashboard) for a specific IP or pattern like 31.67.*.*
        Configurable idle timeout watchdog that auto-disconnects connections where Idle exceeds a threshold.
        Change the logic of auto disconnect oldest in dashboard - now that we have "IDLE" counter in Active Connections, auto disconnect oldest can just
        check the IDLE time versus a treshold (i.e > 1 hour) and auto disconnect frozen clients
v28:    Session Blacklist : Add to this table the blocking attempts detected by titan for IPs that are blocked in rulesfile
v27:    Changes to tcp sniff - add detection of last client type tcp status with AF_PACKET (ack, etc).
        TCP Labels updated to include all combinations (i.e ACK, SYN, ACK/SYN, etc)
        Last Client Type (C.Type) Column added to Active & History Connection Tables.
        implementing per-ID TCP Sniff Logging (magenta color)
        new button in Dashboard Live Log to hide TCP Traffic (now separated from the regular traffic lines)
v26:    Last Remote Type column (R.Type) added to Active & History Connections (helps to detect anomalies in frozen connections using ACK, RST, FIN, SYN,PSH, etc)
        Fix a bug about temp blocking - ip was unblocked after X time, but the block table in dashboard was not updated.
        Fix a bug about scanners hitting httpexpose port causing python exception calls and ugly log lines
        Seperate titan changelog text from titan help text - new arg --changelog added (previously --help was printing changelog+help together)
v25:    Last Remote ts was inaccurate - previous implementation counts as Last Remote only payload responses (data bytes) - ACK, SYN, FIN are not counted 
        Provide Option to unblock an IP - not white-list it , just unblock it
        Column Last Remote now visible also in Session History Table.
v24:    Enhancements to tcp sniffer function to correctly differentate states of tcp (ack, syn,rst,fin, etc)
        WhiteList comment editing
        Active Connections Comment refresh live bug fixed
        Autoblocked Table became Session Blocked table that contains entries that were autoblocked but also user blocks
        Session History Table - new action "Remove all IPs rows" to massively remove from the list all IDs of the same IP
v23:    Enable per ID hex dump to avoid global enabling hex dump for all ids (log flood)
        Add Column LAST CLIENT to Session History
        Add "disconnect" action (id click & right click) in session history entries that show ACTIVE in Disconnected column.
        Fixed a bug that when watch was enabled but dashboard was refreshed , watch was appearing as disabled but in reality has been preserved
        enabled (prior enabling before refresh). Fix applies also to perID hex dump.
v22:    Provide IP Temp Block for a time period. Temp Blocks appear on Auto-Blocked Tables. User can "unblock" a previously temp blocked IP
        Provide "Watch" Button in active connections table - This enables verbose for particular ID = printing detailed message data of this ID.
        When watch is pressed it is changed to "watching". Re-pressing "watching" restores/turns off ID verbosing. 
        Enrich verbose data printing in the logs / live logs with including ID+IP so live log filtering can catch those lines
        Convert to clickable : ID column of Active Connections & History Connections dashboard tables (bring context right click menu)
        Convert to clickable : IP Column of auto-blocked table in dashboard (bring right click context menu)
        Changes to Titan Python Code: 
            if "add to blacklist" is pressed, check first if an entry is already present as block in --rulesfile to avoid duplicate block records
            Same logic (first check , then write) applied also to "add to whitelist" function.
            if "add to whitelist" is pressed, check and remove a previously block rule for the same IP to avoid allow + block lines in rulesfile for the same IP
            Same logic (remove opposite rule, write new rule) applies also to "add to blacklist" dashboard action.
v21:    Include Country Field for Abuse Auto Block dashboard table
        Possible to remove entry from Session History Table in dashboard (right click context menu)
        Provide grep style search in dashboard live log
        Provide Traffic button (on/off) to display/hide traffic messages on dashboard live log window - usefull to hide the trafic and inspect autoblocks, etc
        Improved close-reason detail on dashboard connection tables
        Disconnect confirmation modal for the Disc small button on the active connections table
        Dashboard Last Updated time changed to 24H clock from 12H clock (browser time)
v20:    Implementation to forcibly close remote socket if it has remained open due to remoteserver bug (session table only - right click Force Remote Close).
        Add helper texts in each previously "except Exception: pass" code block to avoid silent pass and print debuging messages
        New GET endpoint /dashboard/mobile for better support of dashboard in mobile phones (redirects to dashboard-mobile.html)
        Extend sorting on ALL dashboard table columns 
        Apply seperate Dashboard Refresh Intervals for connection tables (faster) and rest web page (slower)
v19:    Make the closeclientbyremote and closeremotebyclient dashboard badges in Dashboard to work like buttons and change behavior at runtime by dashboard.
v18:    Web dashboard served at http://vpsip:httpexpose port/dashboard (requires --dashboardpath and --dashboardauth).
        Separate HTML files — login.html and dashboard.html — stored in --dashboardpath folder.
        New --httpbind flag (default 127.0.0.1) to expose HTTP control externally (usage: --httpbind 0.0.0.0)
        New --dashboardauth user:password for browser-based access with session cookies.
        LOG_BUFFER: rolling 500-line log fed by tlog() for live dashboard log viewer.
        New endpoints: /dashboard, /dashboard/login, /dashboard/logout, /dashboard/log, /dashboard/data.
        fix: sessiontable sorting of inactive connection (sort by connection time instead of disconnected time).
v17:    Replaced --chainremotesockets with two independent directional flags: --closeremotebyclient / --closeclientbyremote.
        Default behavior (absence of --closeremotebyclient and --closeclientbyremote): pure v8 TCP isolation without forced upstream/downstream socket closing.
        remark: V17 seems that doing great with datakom PLCs (D500, 509, etc) and datakom cloud (titan forces closing of upstream/downstream sockets) 
v16:    SESSION_HISTORY_PENDING for accurate remote_status tracking (remote close sockets in later time than client disconnected time.
        Fixed /sessiontable missing natural client-close entries.
v15:    --chainremotesockets. Fixed /sessiontable missing forced-disconnect entries.
        new: --chainremotesockets CLI flag introduced — when enabled, remote (upstream) sockets are forcibly closed when the downstream socket closes; 
            disabled by default, making the v11 (chain) behavior opt-in rather than always-on
        change: pipe() upstream socket chaining is now conditional on --chainremotesockets. Both natural close and exception call destination.shutdown()
        fix:    forced disconnects via disconnect_ip() and disconnect_connection_id() now write to SESSION_HISTORY immediately at disconnect time, 
                instead of relying on bridge() finally block —  root cause of missing entries in /sessiontable and /closedconnectionstable when connections 
                were forcibly terminated
        fix: bridge() finally block now only writes to SESSION_HISTORY if info is not None — preventing duplicate entries from disconnect function
        improvement:    disconnect_ip() captures all metadata (last_client_ts, last_remote_ts, comment, connected_ts) before removing from ACTIVE_CONNECTIONS, 
                        so the session history record is complete even on forced disconnects
        improvement:    disconnect_connection_id() similarly captures all connection metadata before deleting the ACTIVE_CONNECTIONS entry, 
                        ensuring the immediately-written session history record is fully populated
v14:    Change to --abuseblock and --abuseapikey - Now --abuseblock has mandatory options <score> and <api-key-file> or <api-key-raw>
        Removed: --abuseapikey as a standalone CLI argument — the API key is now always provided as the second argument to --abuseblock
        improvement: --abuseblock now exits with an error immediately at startup if the API key cannot be loaded, rather than silently disabling abuse checking
        improvement: version number moved to a TITAN_VERSION constant — used dynamically in HTTP_PORT_HELP, the startup banner, and TITAN_DESCRIPTION
        improvement: TITAN_DESCRIPTION constant introduced to hold the full changelog and usage examples, used directly as the argparse description
        improvement: startup banner header now includes the version number dynamically from TITAN_VERSION
        improvement: usage examples in the changelog and help text updated to reflect the new --abuseblock two-argument syntax
v13:    --verbose CLI + /verbose endpoint.
        new: verbose mode introduced — disabled by default, only connect/disconnect/abuse messages are printed; byte data is suppressed entirely
        new: --verbose CLI flag added to enable verbose logging at startup - also new /verbose?enable/disable HTTP endpoint added to toggle verbose mode at runtime
        improvement: pipe() now gates all data output (both plain text and hexdump) behind the VERBOSE_ENABLED flag
        whitelist comment now stored in ACTIVE_CONNECTIONS at connection time in bridge() instead of checking whitelist on each read
        improvement: comment field added to session history records — /closedconnectionstable and /sessiontable now include a Comment column showing the whitelist comment for each connection
v12:    /sessiontable, /closedconnectionstable.
        new: session history introduced — last 1000 connections (active and closed) tracked in a deque (SESSION_HISTORY)
        new: close reason tracking introduced — CLOSE_REASONS dict records why each connection was closed, consumed by bridge() on disconnect and stored in session history
        new: /sessiontable endpoint — shows all last 1000 connections (both active and closed) in a single table with connected time, disconnected time, duration, last client/remote activity, and close reason
        new: /closedconnectionstable endpoint — shows only closed connections from session history with the same columns as /sessiontable
        new: /disconnectall endpoint — forcibly disconnects all active connections in one POST call
        improvement: bridge() finally block now records disconnection timestamp, calculates session duration, and writes a full session record into SESSION_HISTORY including close reason
        improvement: /statustable now merged with the old /upstreamtable behaviour — includes Upstream Idle column directly, making /upstreamtable redundant
        improvement: disconnect log message now includes close reason in the DISCONNECTED line printed to console
        improvement: RUNTIME_BLOCKLIST access now protected by a dedicated runtime_blocklist_lock instead of being accessed without a lock
        improvement: AUTO_BLOCKED_IPS access now protected by a dedicated auto_blocked_lock instead of being accessed without a lock
        improvement: auto_blocked_lock also applied to /autoblocked and /autoblockedtable endpoints for thread-safe reads
v11:    fix: pipe() now forces the opposite socket to close immediately when either side disconnects or errors — previously, half-open connections could linger
        improvement: connection activity tracking split into two separate timestamps — last_client_ts (CLIENT→REMOTE) and last_remote_ts (REMOTE→CLIENT) — replacing the single last_update_ts
        improvement: /statustable updated to show Last From Client and Last From Remote as separate columns instead of a single Last Update column
        improvement: /upstreamtable updated to show both last_client_ts and last_remote_ts columns, with idle time calculated from upstream (REMOTE→CLIENT) activity only — status label (NEW/ACTIVE/IDLE/STALE/DEAD) removed
        improvement: /status JSON response updated to return last_client_ts and last_remote_ts per connection instead of last_update_ts
v10:    new: allow-all mode introduced (/allowall?enable/disable)
        new: runtime abuse check toggle for newcomers (/newcomerabusecheck?enable/disable)
        new: upstream connection status table with idle time and status labels (/upstreamtable)
        improvement: disconnect reason strings added to all forced disconnects for better auditability
        improvement: /disconnect_id response now includes the disconnected IP alongside the ID
        improvement: /stats response now includes a live connected count from ACTIVE_CONNECTIONS
        fix: deadlock risk in disconnect_connection_id() — stats_lock now acquired after releasing active_lock
        change: hexdump endpoint syntax changed from /hexdump/on /hexdump/off to /hexdump?enable or ?disable
        change: timestamp format changed from YYYY-MM-DD to DD-MM-YYYY
v09:    Httpcontrol at port 9999 made Optional (--httpexpose <port>)
        Hardcoded rulesfile made Optional (--rulesfile <file>)
        Abusecheck (hardcoded score & key), converted to optional (--abuseblock <score> --abusekey <keyfile or raw key>) 
        new: Abuse caching 1hr TTL cache In-memory to avoid api hammering
        new: Runtime block list in case --rulesfile is not provided
        fix: set Whitelist priority Bug over blacklist (BL could previously override WL)
        fix: Fixed Timestamps Time to include Full date + time
        fix: Startup output Single line Full summary banner
v08(*): Last stable version — TCP isolation baseline (client sockets and remote sockets not managed by Titan)
v04:    --tcp-snif cli added - 
v03:    This version of Titan supports IP black-list &  white-list. IPs allow/block rules are stored in a local file rm-proxy-ip-list.
        For new IPs coming to Titan default action is allow.
v02:    pipe() signature(source, destination, label, color, conn_id, show_hex) Adds client_ip as a 7th parameter
        Log format in pipe()[ID:#N] LABEL:[ID:#N] (client_ip) LABEL: — client IP 
        now shown per data eventThread creation in bridge()Passes 6 args to pipePasses 7 args, adding addr[0] (the client IP)
v01:    Simple TCP transparent proxy - listens on one port , forwards data to remoteserver:remoteport.
        Args: --listenport <port> , --remoteserver <hostname or ip> , --remoteport <port>, --ssl (force ssl from Titan to upstream), --hexdump 
"""


TITAN_HELP = f"""\
Titan v{TITAN_VERSION} - Usage:
  # Legacy mode (v8 behavior, localhost API only):
  sudo python3 -u mitm-global-proxy-v18.py \\
    --listenport 443 --remoteserver 127.0.0.1 --remoteport 4450 \\
    --httpexpose 10001

  # With web dashboard (accessible from browser):
  sudo python3 -u mitm-global-proxy-v26.py \\
    --listenport 443 --remoteserver rm.com --remoteport 90 \\
    --abuseblock 50 /path/to/key --rulesfile /path/to/rules \\
    --httpexpose 10001 --httpbind 0.0.0.0 \\
    --dashboardpath /home/gv/pytests/titan-dashboard --closeclientbyremote --closeremotebyclient \\
    --dashboardauth admin:'mysecretpassword' 
    ps1: always include password in single quotes.
    ps2: for systemd services password should be included in double quotes and special chars like % should be escaped with % -> %%
    ps3: rules file include allow IP and block IP entries. Allow entries have higher priority over block entries.
"""

HTTP_PORT_HELP = f"""\
Titan v{TITAN_VERSION} Endpoints [when enabled with --httpexpose <port>]:
  GET  /status                    Active connections (json)
  GET  /statustable               Active connections (ascii table)
  GET  /closedconnectionstable    Closed connections (ascii table)
  GET  /sessiontable              All connections active+closed (ascii table)
  GET  /rules                     Allow/block rules (json)
  GET  /rulesallowtable           Allow rules (ascii table)
  GET  /rulesblockedtable         Block rules (ascii table)
  GET  /autoblocked               Auto-blocked IPs (json)
  GET  /autoblockedtable          Auto-blocked IPs (ascii table)
  POST /disconnect?ip=X           Disconnect all sessions for IP
  POST /disconnect_oldest?ip/ID=X Disconnect oldest, keep newest
  POST /disconnect_id?ID=X        Disconnect specific connection
  POST /disconnectall             Disconnect all (no blocking)
  POST /autodisconnectoldest      Per-IP keep newest
  POST /hexdump?enable|disable    Toggle hex dumping
  POST /verbose?enable|disable    Toggle verbose logging
  POST /allowall?enable|disable   Toggle allow-all mode
  POST /newcomerabusecheck?enable|disable  Toggle AbuseIPDB check

  Dashboard (requires --dashboardpath and --dashboardauth):
  GET  /dashboard                 Web dashboard (auth required)
  GET  /dashboard/login           Login page
  POST /dashboard/login           Login form handler
  POST /dashboard/logout          Logout
  GET  /dashboard/data            Dashboard JSON data (auth required)
  GET  /dashboard/log             Log lines JSON (auth required)
"""

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

ABUSE_API_KEY   = None
ABUSE_THRESHOLD = 80
AUTO_BLOCKED_IPS = []
auto_blocked_lock = threading.Lock()

TIMED_BLOCKLIST      = {}   # <- add  {ip: expiry_timestamp or None (session-only)}
timed_blocklist_lock = threading.Lock()  # <- add

ALLOWALL_ENABLED   = False
_ALLOWALL_SNAPSHOT = {}


# ── Helpers ───────────────────────────────────────────────────────────────

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
        if dur_secs < 60:   return f"{dur_secs}s"
        if dur_secs < 3600: return f"{dur_secs//60}m {dur_secs%60}s"
        return f"{dur_secs//3600}h {(dur_secs%3600)//60}m"
    except Exception:
        return "?"

def signal_handler(sig, frame):
    tlog(f"\n{GREEN}[{get_ts()}][*] Titan Proxy Shutting down...{RESET}", "INFO")
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)


# ── Rules ─────────────────────────────────────────────────────────────────

def parse_rule(line):
    parts = line.split()
    if len(parts) != 2: return None, None
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
            if ip == rule: return entry if return_entry else True
        else:
            if ip in rule: return entry if return_entry else True
    return None if return_entry else False

def load_rules():
    global WHITELIST, BLACKLIST, OLD_BLACKLIST, rules_mtime
    if RULEFILE is None:
        tlog(f"{YELLOW}[{get_ts()}][!] No Rule Files specified - all connections are allowed{RESET}", "INFO")
        return
    try:
        mtime = os.path.getmtime(RULEFILE)
    except FileNotFoundError: return
    except Exception as e:
        tlog(f"{RED}[{get_ts()}][!] load_rules(): mtime check failed: {e}{RESET}", "ERROR"); return
    if mtime == rules_mtime: return
    try:
        new_white, new_black = [], []
        with open(RULEFILE) as f:
            for raw in f:
                line = raw.split("#", 1)[0].strip()
                if not line: continue
                action, obj = parse_rule(line)
                if not obj: continue
                comment = raw.split("#", 1)[1].strip() if "#" in raw else ""
                entry = {"obj": obj, "comment": comment}
                if action == "allow":  new_white.append(entry)
                elif action == "block": new_black.append(entry)
        with rules_lock:
            WHITELIST = new_white; BLACKLIST = new_black
            newly_blocked = [e for e in BLACKLIST if e not in OLD_BLACKLIST]
            OLD_BLACKLIST = BLACKLIST.copy(); rules_mtime = mtime
        tlog(f"{YELLOW}[{get_ts()}][!] Rules reloaded from {RULEFILE}: "
             f"{len(WHITELIST)} allow, {len(BLACKLIST)} block{RESET}", "INFO")
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
                        except Exception: continue
                        if ip in rule: disconnect_ip(info["ip"], reason="added to block list")
    except Exception as e:
        tlog(f"{RED}[{get_ts()}][!] load_rules() failed: {e}{RESET}", "ERROR")

# new function — add after load_rules(), before rules_watcher()
def _refresh_active_comments():
    """After a whitelist change, update comment field for all active connections."""
    with active_lock, rules_lock:
        for cid, info in ACTIVE_CONNECTIONS.items():
            try:
                ip_obj = ipaddress.ip_address(info["ip"])
                entry = ip_in_list(ip_obj, WHITELIST, return_entry=True)
                info["comment"] = entry["comment"] if entry and entry["comment"] else ""
            except Exception:
                pass

def rules_watcher():
    while True:
        try: load_rules()
        except Exception as e:
            tlog(f"{RED}[{get_ts()}][!] Rule watcher error: {e}{RESET}", "ERROR")
        time.sleep(5)

# new function — add after rules_watcher()
def timed_block_watcher():
    while True:
        now = time.time()
        expired = []
        with timed_blocklist_lock:
            for ip, expiry in list(TIMED_BLOCKLIST.items()):
                if expiry is not None and now >= expiry:
                    expired.append(ip)
            for ip in expired:
                del TIMED_BLOCKLIST[ip]
        for ip in expired:
            with runtime_blocklist_lock:
                RUNTIME_BLOCKLIST.discard(ip)
            with auto_blocked_lock:                                          # <- add
                AUTO_BLOCKED_IPS[:] = [e for e in AUTO_BLOCKED_IPS         # <- add
                                       if not (e.get("ip") == ip           # <- add
                                       and e.get("type") == "temp")]       # <- add
            tlog(f"{YELLOW}[{get_ts()}][*] Temp block expired for {ip} — removed from blocklist{RESET}", "CONTROL")
        time.sleep(30)


# ── Disconnect functions ──────────────────────────────────────────────────

def disconnect_ip(ip_str, reason="block list"):
    with active_lock:
        to_kill = [cid for cid, info in ACTIVE_CONNECTIONS.items() if info["ip"] == ip_str]
    killed = 0
    for cid in to_kill:
        with active_lock:
            info = ACTIVE_CONNECTIONS.get(cid)
            sock = info.get("socket") if info else None
        if not sock: continue
       
        with close_reasons_lock: CLOSE_REASONS[cid] = reason
        try: sock.shutdown(socket.SHUT_RDWR)
        except OSError: pass
        except Exception as e:
            #print(f"{YELLOW}[{get_ts()}][dbg] shutdown() {ip_str}: {e}{RESET}", flush=True)
            tlog(f"{YELLOW}[{get_ts()}][dbg] shutdown() {ip_str}: {e}{RESET}", "ERROR")
        try: sock.close()
        except OSError: pass
        except Exception as e:
            #print(f"{YELLOW}[{get_ts()}][dbg] close() {ip_str}: {e}{RESET}", flush=True)
            tlog(f"{YELLOW}[{get_ts()}][dbg] close() {ip_str}: {e}{RESET}", "ERROR")
        last_client_ts = info.get("last_client_ts","") if info else ""
        last_remote_ts = info.get("last_remote_ts","") if info else ""
        last_client_type = info.get("last_client_type","?") if info else "?"
        conn_comment   = info.get("comment","")         if info else ""
        connected_ts   = info.get("connected_ts","")    if info else ""
        remote_sock_ref = info.get("remote_socket") if info else None
        
        with active_lock: _popped = ACTIVE_CONNECTIONS.pop(cid, None)
        if _popped is None:                                              # <- add
            tlog(f"{RED}[{get_ts()}][!] Forced disconnect of {ip_str} (ID:#{cid}) — {reason}{RESET}", "CONTROL")  # <- add
            killed += 1                                                  # <- add
            continue                                                     # <- add
        disconnected_ts = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]        
        
        duration = _calc_duration(connected_ts, disconnected_ts)
        remote_status = "closed" if CLOSE_REMOTE_BY_CLIENT else "open"
        entry_dict = {
            "id": cid, "ip": ip_str, "comment": conn_comment,
            "connected_ts": connected_ts, "disconnected_ts": disconnected_ts,
            "duration": duration, "last_client_ts": last_client_ts,
            "last_remote_ts": last_remote_ts, "close_reason": reason,
            "last_client_type": last_client_type,
            "remote_status": remote_status,
        }
        with session_history_lock: SESSION_HISTORY.append(entry_dict)
        if remote_status == "open":
            with session_history_pending_lock: SESSION_HISTORY_PENDING[cid] = entry_dict
            if remote_sock_ref is not None:
                with pending_remote_sockets_lock: PENDING_REMOTE_SOCKETS[cid] = remote_sock_ref
        tlog(f"{RED}[{get_ts()}][!] Forced disconnect of {ip_str} (ID:#{cid}) — {reason}{RESET}", "CONTROL")
        killed += 1
    return killed

def disconnect_connection_id(cid, reason="operator request"):
    with active_lock:
        info = ACTIVE_CONNECTIONS.get(cid)
        if not info: return False
        ip = info.get("ip","unknown"); sock = info["socket"]
        try: sock.shutdown(socket.SHUT_RDWR)
        except OSError: pass
        except Exception as e:
            #print(f"{YELLOW}[{get_ts()}][dbg] shutdown() ID {cid} ({ip}): {e}{RESET}", flush=True)
            tlog(f"{YELLOW}[{get_ts()}][dbg] shutdown() ID {cid} ({ip}): {e}{RESET}", "ERROR")
        try: sock.close()
        except OSError: pass
        except Exception as e:
            #print(f"{YELLOW}[{get_ts()}][dbg] close() ID {cid} ({ip}): {e}{RESET}", flush=True)
            tlog(f"{YELLOW}[{get_ts()}][dbg] close() ID {cid} ({ip}): {e}{RESET}", "ERROR")
        last_client_ts = info.get("last_client_ts",""); last_remote_ts = info.get("last_remote_ts","")
        conn_comment = info.get("comment",""); connected_ts = info.get("connected_ts","")
        last_client_type = info.get("last_client_type","?")
        remote_sock_ref = info.get("remote_socket")
        del ACTIVE_CONNECTIONS[cid]
    with close_reasons_lock: CLOSE_REASONS[cid] = reason
    disconnected_ts = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]
    duration = _calc_duration(connected_ts, disconnected_ts)
    remote_status = "closed" if CLOSE_REMOTE_BY_CLIENT else "open"
    entry_dict = {
        "id": cid, "ip": ip, "comment": conn_comment,
        "connected_ts": connected_ts, "disconnected_ts": disconnected_ts,
        "duration": duration, "last_client_ts": last_client_ts,
        "last_remote_ts": last_remote_ts, "close_reason": reason,
        "last_client_type": last_client_type,
        "remote_status": remote_status,
    }
    with session_history_lock: SESSION_HISTORY.append(entry_dict)
    if remote_status == "open":
        with session_history_pending_lock: SESSION_HISTORY_PENDING[cid] = entry_dict
        if remote_sock_ref is not None:
            with pending_remote_sockets_lock: PENDING_REMOTE_SOCKETS[cid] = remote_sock_ref
    tlog(f"{RED}[{get_ts()}][!] Forced disconnect of ID:#{cid} ({ip}) — {reason}{RESET}", "CONTROL")
    return True


# ── Pipe & Bridge ─────────────────────────────────────────────────────────

def format_hexdump(data):
    lines = []
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        hex_part   = " ".join(f"{b:02x}" for b in chunk)
        ascii_part = "".join(chr(b) if 32 <= b <= 126 else "." for b in chunk)
        lines.append(f"{CYAN}{i:04x}  {hex_part:<48}  |{ascii_part}|{RESET}")
    return "\n".join(lines)

def pipe(source, destination, label, color, conn_id, client_ip):
    _pipe_close_reason = "natural disc."
    _pipe_close_tag    = ""
    try:
        while True:
            data = source.recv(8192)
            if not data:
                _pipe_close_reason = "natural close [FIN]"
                _pipe_close_tag    = "[FIN]"
                if label == "CLIENT->REMOTE" and CLOSE_REMOTE_BY_CLIENT:
                    try: destination.shutdown(socket.SHUT_RDWR)
                    except Exception as e: tlog(f"{YELLOW}[{get_ts()}][!] [ID:#{conn_id}] shutdown() destination (no-data CLIENT->REMOTE): {e}{RESET}", "ERROR")
                elif label == "REMOTE->CLIENT" and CLOSE_CLIENT_BY_REMOTE:
                    try: destination.shutdown(socket.SHUT_RDWR)
                    except Exception as e: tlog(f"{YELLOW}[{get_ts()}][!] [ID:#{conn_id}] shutdown() destination (no-data REMOTE->CLIENT): {e}{RESET}", "ERROR")
                break
            with active_lock:
                info = ACTIVE_CONNECTIONS.get(conn_id)
                if info is not None:
                    ts_now = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]
                    if label == "CLIENT->REMOTE":
                        info["last_client_ts"] = ts_now
                        if info.get("remote_closed", False): break
                    else:
                        info["last_remote_ts"] = ts_now
            with rules_lock:
                entry   = ip_in_list(ipaddress.ip_address(client_ip), WHITELIST, return_entry=True)
                comment = f"  # {entry['comment']}" if entry and entry["comment"] else ""
            #print(f"{color}[{get_ts()}] [ID:#{conn_id}] ({client_ip}) {label}:{comment}{RESET}", flush=True)
            tlog(f"{color}[{get_ts()}] [ID:#{conn_id}] ({client_ip}) {label}:{comment}{RESET}", "INFO")
            with verbose_lock: show_verbose = VERBOSE_ENABLED
            with verbose_watch_lock: show_verbose = show_verbose or (conn_id in VERBOSE_WATCH)
            with hexdump_watch_lock: show_hex_watch = conn_id in HEXDUMP_WATCH
            if show_verbose:
                #with hexdump_lock: show_hex = HEXDUMP_ENABLED
                with hexdump_lock: show_hex = HEXDUMP_ENABLED or show_hex_watch
                if show_hex: 
                    #print(format_hexdump(data), flush=True)
                    #tlog(format_hexdump(data), "DATA")
                    tlog(f"[ID:#{conn_id}] ({client_ip}) {label} HEXDUMP:\n{format_hexdump(data)}", "DATA")
                else:
                    msg = data.decode(errors='ignore').strip()
                    if msg: 
                        #print(f"{color}{msg}{RESET}", flush=True)
                        #tlog(f"{color}{msg}{RESET}", "DATA")
                        tlog(f"{color}[ID:#{conn_id}] ({client_ip}) {label} DATA: {msg}{RESET}", "DATA")
            destination.sendall(data)

    except Exception as _e:                                              # <- modify (was: except Exception:)
        _eno = getattr(_e, 'errno', None)                               
        if isinstance(_e, ConnectionResetError) or _eno in (104, 10054):
            _pipe_close_reason = "natural close [RST]"                  
            _pipe_close_tag    = "[RST]"                                
        elif _eno is not None:                                          
            _pipe_close_reason = f"socket error [errno {_eno}]"        
            _pipe_close_tag    = f"[errno {_eno}]"                     
        else:                                                           
            _pipe_close_reason = f"socket error [{type(_e).__name__}]" 
            _pipe_close_tag    = f"[{type(_e).__name__}]"              
        if label == "CLIENT->REMOTE" and CLOSE_REMOTE_BY_CLIENT:
            try: destination.shutdown(socket.SHUT_RDWR)
            except Exception as e: tlog(f"{YELLOW}[{get_ts()}][!] [ID:#{conn_id}] shutdown() destination (error CLIENT->REMOTE): {e}{RESET}", "ERROR")
        elif label == "REMOTE->CLIENT" and CLOSE_CLIENT_BY_REMOTE:
            try: destination.shutdown(socket.SHUT_RDWR)
            except Exception as e: tlog(f"{YELLOW}[{get_ts()}][!] [ID:#{conn_id}] shutdown() destination (error REMOTE->CLIENT): {e}{RESET}", "ERROR")
    finally:
        if label == "REMOTE->CLIENT":
            if _pipe_close_tag == "[FIN]":                                       # <- add this line
                _rclose_type = "FIN"                                             # <- add this line
            elif _pipe_close_tag == "[RST]":                                     # <- add this line
                _rclose_type = "RST"                                             # <- add this line
            elif _pipe_close_tag:                                                 # <- add this line
                _rclose_type = _pipe_close_tag.strip("[]")                       # <- add this line
            else:                                                                 # <- add this line
                _rclose_type = "?"                                               # <- add this line
            with active_lock:                                                    # (anchor - unchanged)
                info = ACTIVE_CONNECTIONS.get(conn_id)                          # (anchor - unchanged)
                if info is not None:
                    info["remote_closed"] = True
                    info["last_remote_type"] = _rclose_type                      # <- add this line
                    tlog(f"{YELLOW}[{get_ts()}][*] [ID:#{conn_id}] Remote socket closed by remote server {_pipe_close_tag}{RESET}", "INFO")
            with session_history_pending_lock:                                   # <- add this line
                _pending = SESSION_HISTORY_PENDING.get(conn_id)                 # <- add this line
                if _pending is not None:                                         # <- add this line
                    _pending["last_remote_type"] = _rclose_type                 # <- add this line
        elif label == "CLIENT->REMOTE":
            with active_lock: info = ACTIVE_CONNECTIONS.pop(conn_id, None)
            if info is None: return
            with close_reasons_lock: close_reason = CLOSE_REASONS.pop(conn_id, None)
            if close_reason is None: close_reason = _pipe_close_reason
            disconnected_ts = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]
            duration = _calc_duration(info.get("connected_ts",""), disconnected_ts)
            remote_closed = info.get("remote_closed", False)
            remote_status = "closed" if remote_closed else "open"
            entry_dict = {
                "id": conn_id, "ip": client_ip, "comment": info.get("comment",""),
                "connected_ts": info.get("connected_ts",""), "disconnected_ts": disconnected_ts,
                "duration": duration, "last_client_ts": info.get("last_client_ts",""),
                "last_remote_ts": info.get("last_remote_ts",""),
                "last_remote_type": info.get("last_remote_type","?"),
                "last_client_type": info.get("last_client_type","?"),
                "close_reason": close_reason, "remote_status": remote_status,
            }
            with session_history_lock: SESSION_HISTORY.append(entry_dict)
            if remote_status == "open":
                with session_history_pending_lock: SESSION_HISTORY_PENDING[conn_id] = entry_dict
                with pending_remote_sockets_lock: PENDING_REMOTE_SOCKETS[conn_id] = destination 
            tlog(f"{RED}[{get_ts()}][-] [ID:#{conn_id}] DISCONNECTED {client_ip} "
                 f"— {close_reason} (remote: {remote_status}){RESET}", "DISCONNECT")


def bridge(client_sock, addr, client_ip, remote_host, remote_port, force_ssl, conn_id):
    global connection_count
    connected_ts = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]
    with rules_lock:
        entry = ip_in_list(ipaddress.ip_address(client_ip), WHITELIST, return_entry=True)
    tag          = " (white-listed)" if entry else "(newcommer)"
    comment      = f"  # {entry['comment']}" if entry and entry["comment"] else ""
    conn_comment = entry["comment"] if entry and entry["comment"] else ""
    with active_lock:
        ACTIVE_CONNECTIONS[conn_id] = {
            "ip": client_ip, "socket": client_sock,
            "connected_ts": connected_ts,
            "last_client_ts": connected_ts, "last_remote_ts": connected_ts,
            "last_remote_type": "?",
            "last_client_type": "?",
            "comment": conn_comment,
        }
    tlog(f"{GREEN}[{get_ts()}][+] [ID:#{conn_id}] CONNECTED: {client_ip}{tag}{comment} "
         f"(Active: {connection_count}){RESET}", "CONNECT")
    with client_port_map_lock:                  # <- add this line
        CLIENT_PORT_MAP[addr[1]] = conn_id      # <- add this line
        
    ephemeral_port = None                                              # <- add this line
    remote_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        remote_sock.connect((remote_host, remote_port))
        ephemeral_port = remote_sock.getsockname()[1]                  # <- add this line
        with remote_port_map_lock:                                     # <- add this line
            REMOTE_PORT_MAP[ephemeral_port] = conn_id                  # <- add this line

        if force_ssl:
            ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
            ctx.load_cert_chain(certfile=CERTFILE, keyfile=KEYFILE)
            c_conn = ctx.wrap_socket(client_sock, server_side=True)
            r_conn = ssl._create_unverified_context().wrap_socket(remote_sock, server_hostname=remote_host)
        else:
            c_conn, r_conn = client_sock, remote_sock
        with active_lock:
            if conn_id in ACTIVE_CONNECTIONS:
                ACTIVE_CONNECTIONS[conn_id]["remote_socket"] = r_conn
        t1 = threading.Thread(target=pipe, args=(c_conn, r_conn, "CLIENT->REMOTE", BLUE, conn_id, client_ip), daemon=True)
        t2 = threading.Thread(target=pipe, args=(r_conn, c_conn, "REMOTE->CLIENT", RED,  conn_id, client_ip), daemon=True)
        t1.start(); t2.start(); t1.join(); t2.join()
    except Exception as e:
        tlog(f"{RED}[{get_ts()}][!] [ID:#{conn_id}] Error: {e}{RESET}", "ERROR")
    finally:
        disconnected_ts = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]
        with counter_lock: connection_count -= 1
        if ephemeral_port is not None:                                 # <- add this line
            with remote_port_map_lock:                                 # <- add this line
                REMOTE_PORT_MAP.pop(ephemeral_port, None)              # <- add this line
        with client_port_map_lock:              # <- add this line
            CLIENT_PORT_MAP.pop(addr[1], None)  # <- add this line
        with verbose_watch_lock: VERBOSE_WATCH.discard(conn_id)
        with hexdump_watch_lock:
            HEXDUMP_WATCH.discard(conn_id)
            HEXDUMP_WATCH_PREV.pop(conn_id, None)
        with tcp_watch_lock:                        # <- add
            TCP_WATCH.discard(conn_id)              # <- add
            TCP_WATCH_PREV.pop(conn_id, None)       # <- add
        with active_lock: info = ACTIVE_CONNECTIONS.pop(conn_id, None)
        with close_reasons_lock: close_reason = CLOSE_REASONS.pop(conn_id, "natural disc.")
        if info is not None:
            duration = _calc_duration(connected_ts, disconnected_ts)
            with session_history_lock:
                SESSION_HISTORY.append({
                    "id": conn_id, "ip": client_ip, "comment": info.get("comment",""),
                    "connected_ts": connected_ts, "disconnected_ts": disconnected_ts,
                    "duration": duration, "last_client_ts": info.get("last_client_ts",""),
                    "last_remote_ts": info.get("last_remote_ts",""),
                    "last_remote_type": info.get("last_remote_type","?"),
                    "last_client_type": info.get("last_client_type","?"),
                    "close_reason": close_reason, "remote_status": "closed",
                })
            tlog(f"{RED}[{get_ts()}][-] [ID:#{conn_id}] DISCONNECTED {client_ip} "
                 f"(Active: {connection_count}) — {close_reason}{RESET}", "DISCONNECT")
        else:
            with session_history_pending_lock: pending_entry = SESSION_HISTORY_PENDING.pop(conn_id, None)
            with pending_remote_sockets_lock: PENDING_REMOTE_SOCKETS.pop(conn_id, None)
            if pending_entry is not None:
                pending_entry["remote_status"] = "closed"
                _p_ip      = pending_entry.get("ip", "?")
                _p_comment = pending_entry.get("comment", "")
                _p_comment_str = f" # {_p_comment}" if _p_comment else ""
                tlog(f"{YELLOW}[{get_ts()}][*] [ID:#{conn_id}] Remote socket now closed {_p_ip}{_p_comment_str}{RESET}", "CONTROL")
                #tlog(f"{YELLOW}[{get_ts()}][*] [ID:#{conn_id}] Remote socket now closed{RESET}", "INFO")
        for s in (client_sock, remote_sock):
            try: s.close()
            except Exception as e: tlog(f"{YELLOW}[{get_ts()}][!] [ID:#{conn_id}] close() in bridge() finally: {e}{RESET}", "ERROR")

# ── TCP Sniffer ───────────────────────────────────────────────────────────

def parse_ethernet_header(data):
    if len(data) < 14: return None, None, None
    dst_mac, src_mac, proto = struct.unpack('!6s6sH', data[:14])
    return dst_mac, src_mac, proto

def parse_ipv4_header(data):
    if len(data) < 20: return None
    ver_ihl = data[0]; ihl = (ver_ihl & 0x0F) * 4
    if len(data) < ihl: return None
    iph = struct.unpack('!BBHHHBBH4s4s', data[:20])
    return {'ihl': ihl, 'total_length': iph[2], 'proto': iph[6],
            'src_ip': socket.inet_ntoa(iph[8]), 'dst_ip': socket.inet_ntoa(iph[9])}

def parse_tcp_header(data):
    if len(data) < 20: return None
    tcph = struct.unpack('!HHLLBBHHH', data[:20])
    return {'src_port': tcph[0], 'dst_port': tcph[1], 'seq': tcph[2],
            'ack_seq': tcph[3], 'data_offset': (tcph[4] >> 4) * 4, 'flags': tcph[5],
            'window': tcph[6]}

def tcp_flag_labels(flags):
    fin = bool(flags & 0x01)
    syn = bool(flags & 0x02)
    rst = bool(flags & 0x04)
    psh = bool(flags & 0x08)
    ack = bool(flags & 0x10)
    urg = bool(flags & 0x20)
    if syn and ack:             return "SYN/ACK"    # <- modify
    if syn:                     return "SYN"         # <- modify
    if rst and ack:             return "RST/ACK"     # <- add
    if rst:                     return "RST"         # <- modify
    if fin and psh and ack:     return "FIN/PSH/ACK" # <- add
    if fin and ack:             return "FIN/ACK"     # <- add
    if fin:                     return "FIN"         # <- modify
    if psh and ack:             return "PSH/ACK"     # <- modify
    if urg and ack:             return "URG/ACK"     # <- add
    if ack:                     return "ACK"         # <- modify
    return None


def packet_sniffer(listen_port, remote_host, remote_port):
    try:
        try: remote_ip = socket.gethostbyname(remote_host)
        except Exception: remote_ip = remote_host
        sniffer = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.ntohs(3))
    except Exception as e:
        tlog(f"{RED}[{get_ts()}][!] TCP sniffer init failed: {e}{RESET}", "ERROR"); return
    tlog(f"{CYAN}[{get_ts()}][*] TCP sniffer ACTIVE on port {listen_port} (AF_PACKET){RESET}", "INFO")
    seen = {}
    while True:
        try: raw_data, _ = sniffer.recvfrom(65535)
        except Exception: continue
        _, _, eth_proto = parse_ethernet_header(raw_data)
        if eth_proto != 0x0800: continue
        ip_part = raw_data[14:]
        iphdr = parse_ipv4_header(ip_part)
        if not iphdr or iphdr['proto'] != 6: continue
        tcphdr = parse_tcp_header(ip_part[iphdr['ihl']:])
        if not tcphdr: continue
        sp, dp = tcphdr['src_port'], tcphdr['dst_port']
        if not (sp == listen_port or dp == listen_port or sp == remote_port or dp == remote_port): continue

        # Update last_remote_ts for ANY packet from remote (including pure ACKs Len=0)
        # This runs before dedup so every packet updates the timestamp
        if iphdr['src_ip'] == remote_ip and sp == remote_port:
            with remote_port_map_lock:
                cid = REMOTE_PORT_MAP.get(dp)
            if cid is not None:
                ts_now = datetime.datetime.now().strftime("%d-%m-%Y %H:%M:%S.%f")[:-3]
                with active_lock:
                    info = ACTIVE_CONNECTIONS.get(cid)
                    if info is not None:
                        info["last_remote_ts"] = ts_now
                        info["last_remote_type"] = tcp_flag_labels(tcphdr['flags']) or "?"

        if dp == listen_port:                                                # <- add this line
            with client_port_map_lock:                                       # <- add this line
                cid_c = CLIENT_PORT_MAP.get(sp)                              # <- add this line
            if cid_c is not None:                                            # <- add this line
                with active_lock:                                            # <- add this line
                    info_c = ACTIVE_CONNECTIONS.get(cid_c)                  # <- add this line
                    if info_c is not None:                                   # <- add this line
                        info_c["last_client_type"] = tcp_flag_labels(tcphdr['flags']) or "?"  # <- add this line

        label = tcp_flag_labels(tcphdr['flags'])
        if not label: label = "UNKNOWN"
        payload_len = iphdr['total_length'] - iphdr['ihl'] - tcphdr['data_offset']
        len_str = f" Len={payload_len}" if payload_len > 0 else " Len=0"
        key = (iphdr['src_ip'], sp, iphdr['dst_ip'], dp, tcphdr['flags'], tcphdr['seq'])
        now = time.time()
        if key in seen and now - seen[key] < 0.05:
            continue
        seen[key] = now
        if len(seen) > 500:
            seen = {k: v for k, v in seen.items() if now - v < 0.05}

        def pip(ip): return remote_host if ip == remote_ip else ip
        with remote_port_map_lock:                                                    # <- modify
            is_mine = (sp == listen_port or dp == listen_port or                     # <- modify
                       sp in REMOTE_PORT_MAP or dp in REMOTE_PORT_MAP)               # <- modify
        if not is_mine: continue                                                      # <- modify
        log_cid = None                                                                # <- add
        with remote_port_map_lock:                                                    # <- add
            log_cid = REMOTE_PORT_MAP.get(dp) or REMOTE_PORT_MAP.get(sp)             # <- add
        if log_cid is None:                                                           # <- add
            with client_port_map_lock:                                                # <- add
                log_cid = CLIENT_PORT_MAP.get(sp) or CLIENT_PORT_MAP.get(dp)         # <- add
        with tcp_watch_lock: per_id_enabled = log_cid in TCP_WATCH if log_cid else False  # <- add
        if TCP_SNIFF_ENABLED or per_id_enabled:                                       # <- modify
            id_tag = f" [ID:#{log_cid}]" if log_cid is not None else ""              # <- add
            tlog(f"{MAGENTA}[{get_ts()}] [TCP]{id_tag}"                          # <- modify
                 f" {pip(iphdr['src_ip'])}:{sp} -> {pip(iphdr['dst_ip'])}:{dp}"  # <- modify
                 f" [{label}] Seq={tcphdr['seq']} Ack={tcphdr['ack_seq']}"       # <- modify
                 f" Win={tcphdr['window']}{len_str}{RESET}", "TCP")               # <- modify            
        
# ── AbuseIPDB ─────────────────────────────────────────────────────────────

def add_block_rule(ip, score=None):
    try:
        comment = f" # auto block by abuse - score {score}" if score is not None else ""
        with open(RULEFILE, "a") as f: f.write(f"block {ip}{comment}\n")
        tlog(f"{RED}[{get_ts()}][!] Auto-added block rule for {ip}{comment}{RESET}", "ABUSE")
    except Exception as e:
        tlog(f"{RED}[{get_ts()}][!] Failed to write block rule for {ip}: {e}{RESET}", "ERROR")

def abuse_lookup(ip):
    try:
        r = requests.get("https://api.abuseipdb.com/api/v2/check",
                         headers={"Key": ABUSE_API_KEY, "Accept": "application/json"},
                         params={"ipAddress": ip, "maxAgeInDays": "90"}, timeout=3)
        #return r.json()["data"]["abuseConfidenceScore"]
        data = r.json()["data"]
        return data["abuseConfidenceScore"], data.get("countryCode","")
    except Exception as e:
        tlog(f"{RED}[{get_ts()}][!] AbuseIPDB lookup failed for {ip}: {e}{RESET}", "ERROR")
        return None, "" 
        #return None

def abuse_lookup_cached(ip):
    now = time.time()
    with abuse_cache_lock:
        entry = ABUSE_CACHE.get(ip)
        if entry and now - entry[1] < ABUSE_CACHE_TTL: 
            country = entry[2] if len(entry) > 2 else ""
            return entry[0], country, "cache" 
            #return entry[0], "cache"
    score, country = abuse_lookup(ip)
    #score = abuse_lookup(ip)
    if score is not None:
        #with abuse_cache_lock: ABUSE_CACHE[ip] = (score, now)
        with abuse_cache_lock: ABUSE_CACHE[ip] = (score, now, country)
    return score, country, "api" 
    #return score, "api"


def whois_lookup(ip):
    """Call ipinfo.io for IP geolocation/org data."""
    try:
        r = requests.get(f"https://ipinfo.io/{ip}/json", timeout=5)
        return r.json()
    except Exception as e:
        return {"error": str(e)}

def abuse_lookup_full(ip):
    """Full AbuseIPDB check returning all available fields."""
    if not ABUSE_API_KEY:
        return {"error": "No AbuseIPDB API key configured at startup"}
    try:
        r = requests.get(
            "https://api.abuseipdb.com/api/v2/check",
            headers={"Key": ABUSE_API_KEY, "Accept": "application/json"},
            params={"ipAddress": ip, "maxAgeInDays": "90"},
            timeout=5
        )
        return r.json().get("data", {})
    except Exception as e:
        return {"error": str(e)}

def dashboard_blacklist(ip):
    """Block IP — write to file and let rules_watcher disconnect, or runtime-only if no file."""
    if RULEFILE:
        #try:
            #with open(RULEFILE, "a") as f:
                #f.write(f"block {ip} #injected by dashboard\n")
        try:
            try:
                with open(RULEFILE, "r") as f: lines = f.readlines()
            except Exception: lines = []
            if any(f"block {ip}" in l for l in lines):
                return {"ip": ip, "status": "already blocked", "persistent": True, "file": RULEFILE, "note": "already present in rules file"}
            lines = [l for l in lines if f"allow {ip}" not in l]          # <- add
            with open(RULEFILE, "w") as f: f.writelines(lines)             # <- add
            with open(RULEFILE, "a") as f:
                f.write(f"block {ip} #injected by dashboard\n")
        #end of old try        
            tlog(f"{RED}[{get_ts()}][!] Dashboard blacklisted {ip} — added to {RULEFILE}{RESET}", "BLOCK")
            
            _bl_score, _bl_country = "—", "—"                                              # <- add
            if ABUSE_API_KEY:                                                                # <- add
                _s, _c, _ = abuse_lookup_cached(ip)                                        # <- add
                if _s is not None: _bl_score, _bl_country = str(_s), (_c or "—")         # <- add

            with auto_blocked_lock:
                if not any(e.get("ip") == ip and e.get("type") == "blacklist" for e in AUTO_BLOCKED_IPS):
                    AUTO_BLOCKED_IPS[:] = [e for e in AUTO_BLOCKED_IPS if e.get("ip") != ip]
                    AUTO_BLOCKED_IPS.append({"ip": ip, "score": _bl_score, "country": _bl_country,  # <- modify
                        "ts": get_ts(), "type": "blacklist", "expires": "—"})
            # rules_watcher will pick this up within 5 seconds and call disconnect_ip()
            return {"ip": ip, "status": "blocked", "persistent": True, "file": RULEFILE,
                    "note": "disconnect pending — rules watcher will apply within 5s"}
        except Exception as e:
            tlog(f"{RED}[{get_ts()}][!] Failed to write blacklist rule for {ip}: {e}{RESET}", "ERROR")
            return {"ip": ip, "status": "error", "persistent": False, "error": str(e)}
    else:
        # No rules file — add to runtime blocklist and disconnect manually
        with runtime_blocklist_lock:
            RUNTIME_BLOCKLIST.add(ip)
        disconnect_ip(ip, reason="dashboard blacklist")
        tlog(f"{RED}[{get_ts()}][!] Dashboard blacklisted {ip} — runtime only (no rules file){RESET}", "BLOCK")

        _rt_score, _rt_country = "—", "—"                                                  # <- add
        if ABUSE_API_KEY:                                                                    # <- add
            _s, _c, _ = abuse_lookup_cached(ip)                                            # <- add
            if _s is not None: _rt_score, _rt_country = str(_s), (_c or "—")             # <- add

        with auto_blocked_lock:
            if not any(e.get("ip") == ip and e.get("type") == "blacklist" for e in AUTO_BLOCKED_IPS):
                AUTO_BLOCKED_IPS[:] = [e for e in AUTO_BLOCKED_IPS if e.get("ip") != ip]
                AUTO_BLOCKED_IPS.append({"ip": ip, "score": _rt_score, "country": _rt_country,  # <- modify
                    "ts": get_ts(), "type": "blacklist", "expires": "—"})

        return {"ip": ip, "status": "blocked", "persistent": False,
                "note": "runtime block only — no rules file configured"}


def whitelist_ip(ip, comment="whitelisted by dashboard"):  # <- modify this line (add comment param)
    """Add IP to whitelist — write to file if available."""
    if RULEFILE:
        try:
            try:
                with open(RULEFILE, "r") as f: lines = f.readlines()
            except Exception: lines = []
            if any(f"allow {ip}" in l for l in lines):
                return {"ip": ip, "status": "already whitelisted", "persistent": True, "file": RULEFILE, "note": "already present in rules file"}
            lines = [l for l in lines if f"block {ip}" not in l]
            with open(RULEFILE, "w") as f: f.writelines(lines)
            comment_str = f" #{comment}" if comment else ""  # <- add this line
            with open(RULEFILE, "a") as f:
                f.write(f"allow {ip}{comment_str}\n")        # <- modify this line
            load_rules()
            _refresh_active_comments()                        # <- add this line
            tlog(f"{GREEN}[{get_ts()}][*] Dashboard whitelisted {ip} — added to {RULEFILE}{RESET}", "CONTROL")
            return {"ip": ip, "status": "whitelisted", "persistent": True, "file": RULEFILE}
        except Exception as e:
            tlog(f"{RED}[{get_ts()}][!] Failed to write whitelist rule for {ip}: {e}{RESET}", "ERROR")
            return {"ip": ip, "status": "error", "error": str(e)}
    else:
        tlog(f"{YELLOW}[{get_ts()}][*] Dashboard whitelist request for {ip} — no rules file{RESET}", "CONTROL")
        return {"ip": ip, "status": "error", "error": "No rules file configured"}

# new function — add after whitelist_ip()
def edit_whitelist_comment(ip, comment):
    """Edit the comment of an existing allow rule in the rules file."""
    if not RULEFILE:
        return {"ip": ip, "status": "error", "error": "No rules file configured"}
    try:
        try:
            with open(RULEFILE, "r") as f: lines = f.readlines()
        except Exception: lines = []
        new_lines = []
        found = False
        comment_str = f" #{comment}" if comment else ""
        for line in lines:
            stripped = line.split("#", 1)[0].strip()
            parts = stripped.split()
            if len(parts) == 2 and parts[0] == "allow" and parts[1] == ip:
                new_lines.append(f"allow {ip}{comment_str}\n")
                found = True
            else:
                new_lines.append(line)
        if not found:
            return {"ip": ip, "status": "error", "error": f"No allow rule found for {ip}"}
        with open(RULEFILE, "w") as f: f.writelines(new_lines)
        load_rules()
        _refresh_active_comments()
        tlog(f"{GREEN}[{get_ts()}][*] Dashboard edited whitelist comment for {ip} — '{comment}'{RESET}", "CONTROL")
        return {"ip": ip, "status": "updated", "comment": comment}
    except Exception as e:
        tlog(f"{RED}[{get_ts()}][!] Failed to edit whitelist comment for {ip}: {e}{RESET}", "ERROR")
        return {"ip": ip, "status": "error", "error": str(e)}


def unblock_ip(ip):
    """Remove block rule from rules file and runtime blocklist — does NOT whitelist."""
    removed_from_file = False
    if RULEFILE:
        try:
            try:
                with open(RULEFILE, "r") as f: lines = f.readlines()
            except Exception: lines = []
            new_lines = [l for l in lines if f"block {ip}" not in l]
            if len(new_lines) < len(lines):
                with open(RULEFILE, "w") as f: f.writelines(new_lines)
                removed_from_file = True
                load_rules()
                tlog(f"{GREEN}[{get_ts()}][*] Dashboard unblocked {ip} — block rule removed from {RULEFILE}{RESET}", "CONTROL")
            else:
                tlog(f"{YELLOW}[{get_ts()}][*] Dashboard unblock {ip} — no block rule found in file{RESET}", "CONTROL")
        except Exception as e:
            tlog(f"{RED}[{get_ts()}][!] Failed to unblock {ip}: {e}{RESET}", "ERROR")
            return {"ip": ip, "status": "error", "error": str(e)}
    with runtime_blocklist_lock:
        RUNTIME_BLOCKLIST.discard(ip)
    with auto_blocked_lock:
        AUTO_BLOCKED_IPS[:] = [e for e in AUTO_BLOCKED_IPS
                                #if not (e.get("ip") == ip and e.get("type") in ("auto", "blacklist"))]
                                if not (e.get("ip") == ip and e.get("type") in ("auto", "blacklist", "rulefile"))]
    return {
        "ip": ip, "status": "unblocked",
        "removed_from_file": removed_from_file,
        "note": f"block rule removed from {RULEFILE}" if removed_from_file else "removed from runtime blocklist only"
    }
    
# ── HTTP Handler ──────────────────────────────────────────────────────────

def make_table(rows, headers):
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row): widths[i] = max(widths[i], len(str(cell)))
    sep        = "+" + "+".join("-" * (w+2) for w in widths) + "+"
    header_row = "| " + " | ".join(h.ljust(widths[i]) for i,h in enumerate(headers)) + " |"
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

    def _serve_html(self, filename):
        """Serve an HTML file from DASHBOARD_PATH."""
        if not DASHBOARD_PATH:
            self._json(404, {"error": "Dashboard not configured"}); return
        filepath = os.path.join(DASHBOARD_PATH, filename)
        try:
            with open(filepath, "rb") as f: body = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except FileNotFoundError:
            self._json(404, {"error": f"File not found: {filename}"})
        except Exception as e:
            self._json(500, {"error": str(e)})

    def _require_auth(self):
        """Check auth, redirect to login if not authenticated. Returns True if auth OK."""
        if not _check_dashboard_auth(self):
            _redirect(self, "/dashboard/login")
            return False
        return True

    def do_GET(self):
        parsed = urlparse(self.path)
        path   = parsed.path

        # ── Dashboard routes ──────────────────────────────────────────────
        if path == "/dashboard" or path == "/dashboard/":
            if not self._require_auth(): return
            self._serve_html(DASHBOARD_HTML); return

        if path == "/dashboard/login":
            self._serve_html("login.html"); return

        if path == "/dashboard/data":
            if not self._require_auth(): return
            self._handle_dashboard_data(); return

        if path == "/dashboard/log":
            if not self._require_auth(): return
            self._handle_dashboard_log(parsed); return

        if path == "/dashboard/whitelist":
                    if not self._require_auth(): return
                    ip = parse_qs(parsed.query).get("ip", [None])[0]
                    if not ip: self._json(400, {"error": "missing ip"}); return
                    comment = parse_qs(parsed.query).get("comment", ["whitelisted by dashboard"])[0]
                    self._json(200, whitelist_ip(ip, comment)); return

        # ── Existing API routes ───────────────────────────────────────────
        if path == "/status":
            with active_lock, rules_lock, runtime_blocklist_lock:
                active = []
                for cid, info in ACTIVE_CONNECTIONS.items():
                    ip    = info["ip"]
                    entry = ip_in_list(ipaddress.ip_address(ip), WHITELIST, return_entry=True)
                    active.append({
                        "id": cid, "ip": ip,
                        "comment": entry["comment"] if entry and entry["comment"] else "",
                        "connected_ts":   info.get("connected_ts",""),
                        "last_client_ts": info.get("last_client_ts",""),
                        "last_remote_ts": info.get("last_remote_ts",""),
                    })
                status = {
                    "active": active, "rulesfile": RULEFILE,
                    "abuse_threshold": ABUSE_THRESHOLD, "abuseblock_enabled": ABUSEBLOCK_ENABLED,
                    "runtime_blocklist_size": len(RUNTIME_BLOCKLIST), "allowall": ALLOWALL_ENABLED,
                    "close_remote_by_client": CLOSE_REMOTE_BY_CLIENT,
                    "close_client_by_remote": CLOSE_CLIENT_BY_REMOTE,
                }
            self._json(200, status); return

        if path == "/rules":
            with rules_lock:
                allow = [str(e["obj"]) for e in WHITELIST]
                block = [str(e["obj"]) for e in BLACKLIST]
            self._json(200, {"allow": allow, "block": block}); return

        if path == "/autoblocked":
            with auto_blocked_lock: snapshot = list(AUTO_BLOCKED_IPS)
            self._json(200, {"autoblocked": snapshot}); return

        if path == "/autoblockedtable":
            with auto_blocked_lock: snapshot = list(AUTO_BLOCKED_IPS)
            self._table([[e.get("ip",""),e.get("score",""),e.get("ts","")] for e in snapshot],
                        ["IP","Score","Timestamp"]); return

        if path == "/rulesallowtable":
            with rules_lock: rows = [[str(e["obj"]),e["comment"]] for e in WHITELIST]
            self._table(rows, ["Allow Rule","Comment"]); return

        if path == "/rulesblockedtable":
            with rules_lock: rows = [[str(e["obj"]),e["comment"]] for e in BLACKLIST]
            self._table(rows, ["Block Rule","Comment"]); return

        if path == "/statustable":
            now = datetime.datetime.now(); rows = []
            with active_lock, rules_lock:
                for cid, info in ACTIVE_CONNECTIONS.items():
                    ip = info["ip"]
                    entry = ip_in_list(ipaddress.ip_address(ip), WHITELIST, return_entry=True)
                    comment = entry["comment"] if entry and entry["comment"] else ""
                    last_remote_ts = info.get("last_remote_ts","")
                    try:
                        idle_secs = int((now - datetime.datetime.strptime(last_remote_ts, "%d-%m-%Y %H:%M:%S.%f")).total_seconds())
                    except Exception: idle_secs = -1
                    idle_str = "?" if idle_secs < 0 else (f"{idle_secs}s" if idle_secs < 60 else
                               f"{idle_secs//60}m {idle_secs%60}s" if idle_secs < 3600 else
                               f"{idle_secs//3600}h {(idle_secs%3600)//60}m")
                    rows.append([cid, ip, comment, info.get("connected_ts",""),
                                 info.get("last_client_ts",""), last_remote_ts, idle_str])
            self._table(rows, ["ID","IP","Comment","Connected","Last From Client","Last From Remote","Upstream Idle"]); return

        if path == "/closedconnectionstable":
            with session_history_lock: snapshot = list(SESSION_HISTORY)
            rows = [[s.get("id",""),s.get("ip",""),s.get("comment",""),
                     s.get("connected_ts",""),s.get("disconnected_ts",""),s.get("duration",""),
                     s.get("last_client_ts",""),s.get("last_remote_ts",""),
                     s.get("close_reason",""),s.get("remote_status","?")] for s in snapshot]
            self._table(rows, ["ID","IP","Comment","Connected","Client Disc","Duration",
                                "Last Client","Last Remote","Reason","Remote"]); return

        if path == "/sessiontable":
            now = datetime.datetime.now(); rows = []
            with active_lock:
                for cid, info in ACTIVE_CONNECTIONS.items():
                    connected_ts = info.get("connected_ts","")
                    try:
                        dur_secs = int((now - datetime.datetime.strptime(connected_ts, "%d-%m-%Y %H:%M:%S.%f")).total_seconds())
                        dur = (f"{dur_secs}s" if dur_secs < 60 else f"{dur_secs//60}m {dur_secs%60}s"
                               if dur_secs < 3600 else f"{dur_secs//3600}h {(dur_secs%3600)//60}m")
                    except Exception: dur = "?"
                    remote_str = "closed" if info.get("remote_closed", False) else "open"
                    rows.append([cid, info.get("ip",""), info.get("comment",""),
                                 connected_ts, "--- ACTIVE ---", dur,
                                 info.get("last_client_ts",""), info.get("last_remote_ts",""),
                                 "active", remote_str])
            with session_history_lock: snapshot = list(SESSION_HISTORY)
            snapshot.sort(key=lambda s: s.get("id", 0))
            for s in snapshot:
                rows.append([s.get("id",""),s.get("ip",""),s.get("comment",""),
                             s.get("connected_ts",""),s.get("disconnected_ts",""),s.get("duration",""),
                             s.get("last_client_ts",""),s.get("last_remote_ts",""),
                             s.get("close_reason",""),s.get("remote_status","?")])
            self._table(rows, ["ID","IP","Comment","Client Conn","Client Disc","Duration",
                                "Last Client","Last Remote","Reason","Remote"]); return

        if path == "/help":
            body = HTTP_PORT_HELP.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type","text/plain")
            self.send_header("Content-Length",str(len(body)))
            self.end_headers(); self.wfile.write(body); return
        
        if path == "/dashboard/whois":
            if not self._require_auth(): return
            ip = parse_qs(parsed.query).get("ip", [None])[0]
            if not ip: self._json(400, {"error": "missing ip"}); return
            self._json(200, whois_lookup(ip)); return

        if path == "/dashboard/abusecheck":
            if not self._require_auth(): return
            ip = parse_qs(parsed.query).get("ip", [None])[0]
            if not ip: self._json(400, {"error": "missing ip"}); return
            self._json(200, abuse_lookup_full(ip)); return

        if path == "/dashboard/mobile":
            if not self._require_auth(): return
            self._serve_html("dashboard-mobile.html"); return
        
        
        if path == "/dashboard/connections":
            if not self._require_auth(): return                                     
            now = datetime.datetime.now()                                           
            active_list = []                                                        
            with active_lock, rules_lock:                                           
                for cid, info in ACTIVE_CONNECTIONS.items():                        
                    ip = info["ip"]                                                 
                    last_remote_ts = info.get("last_remote_ts","")                 
                    try:                                                            
                        idle_secs = int((now - datetime.datetime.strptime(last_remote_ts, "%d-%m-%Y %H:%M:%S.%f")).total_seconds()) 
                        idle_str = (f"{idle_secs}s" if idle_secs < 60 else        
                                    f"{idle_secs//60}m {idle_secs%60}s" if idle_secs < 3600 else 
                                    f"{idle_secs//3600}h {(idle_secs%3600)//60}m") 
                    except Exception: idle_str = "?"                               
                    try:                                                            
                        dur_secs = int((now - datetime.datetime.strptime(info.get("connected_ts",""), "%d-%m-%Y %H:%M:%S.%f")).total_seconds()) 
                        dur = (f"{dur_secs}s" if dur_secs < 60 else f"{dur_secs//60}m {dur_secs%60}s" 
                               if dur_secs < 3600 else f"{dur_secs//3600}h {(dur_secs%3600)//60}m") 
                    except Exception: dur = "?"                                    
                    active_list.append({                                            
                        "id": cid, "ip": ip, "comment": info.get("comment",""),
                        "connected_ts": info.get("connected_ts",""),
                        "last_client_ts": info.get("last_client_ts",""),
                        "last_remote_ts": last_remote_ts,
                        "last_remote_type": info.get("last_remote_type","?"),
                        "last_client_type": info.get("last_client_type","?"),
                        "duration": dur, "idle": idle_str,
                        "remote_closed": info.get("remote_closed", False),
                    })
            hist_active = []                                                        
            with active_lock:                                                       
                for cid, info in ACTIVE_CONNECTIONS.items():                       
                    try:                                                            
                        dur_secs = int((now - datetime.datetime.strptime(info.get("connected_ts",""), "%d-%m-%Y %H:%M:%S.%f")).total_seconds()) 
                        dur = (f"{dur_secs}s" if dur_secs < 60 else f"{dur_secs//60}m {dur_secs%60}s" 
                               if dur_secs < 3600 else f"{dur_secs//3600}h {(dur_secs%3600)//60}m") 
                    except Exception: dur = "?"                                    
                    
                    hist_active.append({
                        "id": cid, "ip": info.get("ip",""), "comment": info.get("comment",""),
                        "connected_ts": info.get("connected_ts",""), "disconnected_ts": "--- ACTIVE ---",
                        "duration": dur, "close_reason": "active",
                        "last_client_ts": info.get("last_client_ts",""),   # <- add
                        "last_remote_ts": info.get("last_remote_ts",""),
                        "last_remote_type": info.get("last_remote_type","?"),
                        "last_client_type": info.get("last_client_type","?"),
                        "remote_status": "closed" if info.get("remote_closed", False) else "open",
                    })
            with session_history_lock: hist_closed = list(SESSION_HISTORY)         
            hist_closed.sort(key=lambda s: s.get("id", 0))                        
            self._json(200, {                                                       
                "active":  active_list,                                            
                "history": hist_active + hist_closed,                              
                "active_count": len(active_list),                                  
            }); return                                                              

        self._json(404, {"error": "not found"})

    def _handle_dashboard_data(self):
        """Comprehensive JSON payload for the dashboard."""
        now = datetime.datetime.now()
        _, uptime_secs = _calc_uptime()

        # Active connections
        active_list = []
        with active_lock, rules_lock:
            for cid, info in ACTIVE_CONNECTIONS.items():
                ip = info["ip"]
                last_remote_ts = info.get("last_remote_ts","")
                try:
                    idle_secs = int((now - datetime.datetime.strptime(last_remote_ts, "%d-%m-%Y %H:%M:%S.%f")).total_seconds())
                    idle_str = (f"{idle_secs}s" if idle_secs < 60 else
                                f"{idle_secs//60}m {idle_secs%60}s" if idle_secs < 3600 else
                                f"{idle_secs//3600}h {(idle_secs%3600)//60}m")
                except Exception: idle_str = "?"
                try:
                    dur_secs = int((now - datetime.datetime.strptime(info.get("connected_ts",""), "%d-%m-%Y %H:%M:%S.%f")).total_seconds())
                    dur = (f"{dur_secs}s" if dur_secs < 60 else f"{dur_secs//60}m {dur_secs%60}s"
                           if dur_secs < 3600 else f"{dur_secs//3600}h {(dur_secs%3600)//60}m")
                except Exception: dur = "?"
                active_list.append({
                    "id": cid, "ip": ip,
                    "comment": info.get("comment",""),
                    "connected_ts":   info.get("connected_ts",""),
                    "last_client_ts": info.get("last_client_ts",""),
                    "last_remote_ts": last_remote_ts,
                    "last_remote_type": info.get("last_remote_type","?"),
                    "last_client_type": info.get("last_client_type","?"),
                    "duration": dur, "idle": idle_str,
                    "remote_closed": info.get("remote_closed", False),
                })

        # Session history — active first, then closed
        hist_active = []
        with active_lock:
            for cid, info in ACTIVE_CONNECTIONS.items():
                try:
                    dur_secs = int((now - datetime.datetime.strptime(info.get("connected_ts",""), "%d-%m-%Y %H:%M:%S.%f")).total_seconds())
                    dur = (f"{dur_secs}s" if dur_secs < 60 else f"{dur_secs//60}m {dur_secs%60}s"
                           if dur_secs < 3600 else f"{dur_secs//3600}h {(dur_secs%3600)//60}m")
                except Exception: dur = "?"
                
                hist_active.append({
                    "id": cid, "ip": info.get("ip",""), "comment": info.get("comment",""),
                    "connected_ts": info.get("connected_ts",""), "disconnected_ts": "--- ACTIVE ---",
                    "duration": dur, "close_reason": "active",
                    "last_client_ts": info.get("last_client_ts",""),   # <- add
                    "last_remote_ts": info.get("last_remote_ts",""),
                    "last_remote_type": info.get("last_remote_type","?"),
                    "last_client_type": info.get("last_client_type","?"),
                    "remote_status": "closed" if info.get("remote_closed", False) else "open",
                })
        with session_history_lock: hist_closed = list(SESSION_HISTORY)
        hist_closed.sort(key=lambda s: s.get("id", 0))
        history = hist_active + hist_closed

        with auto_blocked_lock: autoblocked = list(AUTO_BLOCKED_IPS)
        #with rules_lock: allow_count = len(WHITELIST); block_count = len(BLACKLIST)

        with rules_lock:
            allow_count        = len(WHITELIST)
            block_count        = len(BLACKLIST)
            whitelist_snapshot = [{"ip": str(e["obj"]), "comment": e["comment"]} for e in WHITELIST]

        with verbose_lock: verb = VERBOSE_ENABLED
        with hexdump_lock: hexd = HEXDUMP_ENABLED
        with verbose_watch_lock: watched     = set(VERBOSE_WATCH)      # <- add
        with hexdump_watch_lock: hex_watched = set(HEXDUMP_WATCH)      # <- add
        with tcp_watch_lock: tcp_watched = set(TCP_WATCH)

        payload = {
            "version": TITAN_VERSION,
            "uptime_seconds": uptime_secs,
            "listen_port": TITAN_LISTEN_PORT,
            "remote_server": f"{TITAN_REMOTE_SERVER}:{TITAN_REMOTE_PORT}",
            "rules_file": RULEFILE or "none",
            "flags": {
                "verbose":              verb,
                "hexdump":              hexd,
                "allowall":             ALLOWALL_ENABLED,
                "abuseblock_enabled":   ABUSEBLOCK_ENABLED,
                "abuse_threshold":      ABUSE_THRESHOLD,
                "close_remote_by_client": CLOSE_REMOTE_BY_CLIENT,
                "close_client_by_remote": CLOSE_CLIENT_BY_REMOTE,
                "tcp_sniff":              TCP_SNIFF_ENABLED,
            },
            "connections": {
                "active":  active_list,
                "history": history,
            },
            "watched_ids":     list(watched),       # <- add
            "hex_watched_ids": list(hex_watched),   # <- add
            "tcp_watched_ids": list(tcp_watched), 
            "autoblocked": autoblocked,
            "rules": {"allow_count": allow_count, "block_count": block_count},
            "whitelist": whitelist_snapshot,
        }
        self._json(200, payload)

    def _handle_dashboard_log(self, parsed):
        """Return log lines since a given sequence number."""
        qs = parse_qs(parsed.query)
        since = int(qs.get("since", ["0"])[0])
        with log_buffer_lock:
            lines = [l for l in LOG_BUFFER if l.get("seq", 0) > since]
        self._json(200, {"lines": lines, "count": len(lines)})

    def do_POST(self):
        #global HEXDUMP_ENABLED, ABUSEBLOCK_ENABLED, ALLOWALL_ENABLED, _ALLOWALL_SNAPSHOT
        global HEXDUMP_ENABLED, ABUSEBLOCK_ENABLED, ALLOWALL_ENABLED, _ALLOWALL_SNAPSHOT, ABUSE_THRESHOLD, TCP_SNIFF_ENABLED, CLOSE_REMOTE_BY_CLIENT, CLOSE_CLIENT_BY_REMOTE
        parsed = urlparse(self.path)
        qs     = parse_qs(parsed.query)
        path   = parsed.path

        # ── Dashboard login / logout ──────────────────────────────────────
        if path == "/dashboard/login":
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode('utf-8', errors='replace')
            params = parse_qs(body)
            username = params.get('username', [''])[0]
            password = params.get('password', [''])[0]
            pass_hash = hashlib.sha256(password.encode()).hexdigest()
            if (DASHBOARD_USER and username == DASHBOARD_USER and
                    DASHBOARD_PASS_HASH and pass_hash == DASHBOARD_PASS_HASH):
                token = secrets.token_hex(32)
                with dashboard_sessions_lock:
                    DASHBOARD_SESSIONS[token] = time.time() + 86400  # 24h
                    #DASHBOARD_SESSIONS[token] = time.time() + 604800  # becomes: 7 days <- modify
                self.send_response(302)
                self.send_header("Location", "/dashboard")
                self.send_header("Set-Cookie",
                    f"titan_session={token}; Path=/; HttpOnly; SameSite=Strict")
                self.send_header("Content-Length", "0")
                self.end_headers()
                tlog(f"{GREEN}[{get_ts()}][*] Dashboard login: user '{username}'{RESET}", "INFO")
            else:
                _redirect(self, "/dashboard/login?error=1")
            return

        if path == "/dashboard/logout":
            cookie = self.headers.get("Cookie", "")
            for part in cookie.split(";"):
                part = part.strip()
                if part.startswith("titan_session="):
                    token = part[len("titan_session="):]
                    with dashboard_sessions_lock: DASHBOARD_SESSIONS.pop(token, None)
            self.send_response(302)
            self.send_header("Location", "/dashboard/login")
            self.send_header("Set-Cookie", "titan_session=; Path=/; Max-Age=0")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        # ── Existing POST endpoints ───────────────────────────────────────
        if path == "/disconnect":
            ip = qs.get("ip", [None])[0]
            if not ip: self._json(400, {"error":"missing ip"}); return
            killed = disconnect_ip(ip, reason="HTTP operator request")
            self._json(200, {"ip": ip, "disconnected": killed}); return

        if path == "/disconnect_oldest":
            ip = qs.get("ip", [None])[0]; cid_raw = qs.get("ID", [None])[0]
            if cid_raw is not None:
                try: cid = int(cid_raw)
                except ValueError: self._json(400, {"error":"ID must be an integer"}); return
                with active_lock:
                    info = ACTIVE_CONNECTIONS.get(cid)
                    if not info: self._json(404, {"error":f"connection ID {cid} not found"}); return
                    ip = info["ip"]
            if not ip: self._json(400, {"error":"missing ip or ID"}); return
            matches = []
            with active_lock:
                for cid2, info2 in ACTIVE_CONNECTIONS.items():
                    if info2["ip"] == ip: matches.append((cid2, info2["connected_ts"]))
            if not matches: self._json(200, {"ip":ip,"disconnected":None,"reason":"no active connections"}); return
            from datetime import datetime as dt
            matches.sort(key=lambda x: dt.strptime(x[1], "%d-%m-%Y %H:%M:%S.%f"))
            newest_cid = matches[-1][0]
            disconnected = [cid2 for cid2,_ in matches[:-1]
                            if disconnect_connection_id(cid2, reason="HTTP operator — keep newest only")]
            self._json(200, {"ip":ip,"kept_id":newest_cid,"disconnected_ids":disconnected,"remaining_connections":1}); return

        if path == "/disconnect_id":
            cid_raw = qs.get("ID", [None])[0]
            if cid_raw is None: self._json(400, {"error":"missing ID"}); return
            try: cid = int(cid_raw)
            except ValueError: self._json(400, {"error":"ID must be an integer"}); return
            with active_lock:
                info = ACTIVE_CONNECTIONS.get(cid); ip = info["ip"] if info else None
            killed = disconnect_connection_id(cid, reason="HTTP operator request")
            if not killed: self._json(404, {"error":f"connection ID {cid} not found"}); return
            self._json(200, {"disconnected_id":cid,"ip":ip}); return

        if path == "/disconnectall":
            with active_lock:
                unique_ips = list(set(info["ip"] for info in ACTIVE_CONNECTIONS.values()))
            if not unique_ips:
                self._json(200, {"result":"ok","note":"No active connections","disconnected_ips":[]}); return
            total_killed = sum(disconnect_ip(ip, reason="HTTP operator — disconnectall") for ip in unique_ips)
            tlog(f"{YELLOW}[{get_ts()}][*] DISCONNECTALL — {total_killed} connections terminated{RESET}", "CONTROL")
            self._json(200, {"result":"ok","disconnected_ips":unique_ips,"total_disconnected":total_killed}); return

        if path == "/autodisconnectoldest":
            disconnected = {}
            with active_lock:
                ip_groups = {}
                for cid, info in ACTIVE_CONNECTIONS.items():
                    ip_groups.setdefault(info["ip"],[]).append((cid, info.get("connected_ts","")))
            from datetime import datetime as dt
            for ip, items in ip_groups.items():
                if len(items) <= 1: continue
                items.sort(key=lambda x: dt.strptime(x[1], "%d-%m-%Y %H:%M:%S.%f"))
                keep  = items[-1][0]
                killed = [cid for cid,_ in items[:-1]
                          if disconnect_connection_id(cid, reason="HTTP auto disconnect — keep newest only")]
                if killed: disconnected[ip] = {"kept_id":keep,"disconnected_ids":killed}
            self._json(200, {"result":"ok","disconnected_groups":disconnected}); return

        if path == "/hexdump":
            if parsed.query == "enable":
                with hexdump_lock: HEXDUMP_ENABLED = True
                tlog(f"{YELLOW}[{get_ts()}][*] HEXDUMP ENABLED via HTTP control{RESET}", "CONTROL")
                self._json(200, {"hexdump":True})
            elif parsed.query == "disable":
                with hexdump_lock: HEXDUMP_ENABLED = False
                tlog(f"{YELLOW}[{get_ts()}][*] HEXDUMP DISABLED via HTTP control{RESET}", "CONTROL")
                self._json(200, {"hexdump":False})
            else: self._json(400, {"error":"Use ?enable or ?disable","hexdump":HEXDUMP_ENABLED})
            return

        if path == "/verbose":
            global VERBOSE_ENABLED
            if parsed.query == "enable":
                with verbose_lock: VERBOSE_ENABLED = True
                tlog(f"{YELLOW}[{get_ts()}][*] Verbose logging ENABLED via HTTP control{RESET}", "CONTROL")
                self._json(200, {"verbose":True})
            elif parsed.query == "disable":
                with verbose_lock: VERBOSE_ENABLED = False
                with hexdump_watch_lock: hex_watched = set(HEXDUMP_WATCH)       # <- add case c
                if hex_watched:                                                  # <- add case c
                    with verbose_watch_lock: VERBOSE_WATCH.update(hex_watched)  # <- add case c
                tlog(f"{YELLOW}[{get_ts()}][*] Verbose logging DISABLED via HTTP control{RESET}", "CONTROL")
                self._json(200, {"verbose":False})
            else:
                with verbose_lock: current = VERBOSE_ENABLED
                self._json(400, {"error":"Use ?enable or ?disable","verbose":current})
            return

        if path == "/allowall":
            if parsed.query == "enable":
                if ALLOWALL_ENABLED: self._json(200, {"allowall":True,"note":"Already active"}); return
                _ALLOWALL_SNAPSHOT = {"ABUSEBLOCK_ENABLED": ABUSEBLOCK_ENABLED}
                ABUSEBLOCK_ENABLED = False; ALLOWALL_ENABLED = True
                tlog(f"{YELLOW}[{get_ts()}][*] ALLOWALL ENABLED — all IP checks suspended{RESET}", "CONTROL")
                self._json(200, {"allowall":True,"snapshot_saved":_ALLOWALL_SNAPSHOT,
                                 "note":"Blacklist, whitelist and abuse check suspended"})
            elif parsed.query == "disable":
                if not ALLOWALL_ENABLED: self._json(200, {"allowall":False,"note":"Already inactive"}); return
                ABUSEBLOCK_ENABLED = _ALLOWALL_SNAPSHOT.get("ABUSEBLOCK_ENABLED", False)
                ALLOWALL_ENABLED = False; _ALLOWALL_SNAPSHOT = {}
                tlog(f"{YELLOW}[{get_ts()}][*] ALLOWALL DISABLED — restored (abuseblock={ABUSEBLOCK_ENABLED}){RESET}", "CONTROL")
                self._json(200, {"allowall":False,"restored":{"abuseblock_enabled":ABUSEBLOCK_ENABLED},
                                 "note":"Rules file enforcement and abuse check restored"})
            else: self._json(400, {"error":"Use ?enable or ?disable","allowall":ALLOWALL_ENABLED})
            return

        if path == "/newcomerabusecheck":
            if parsed.query == "enable":
                if not ABUSE_API_KEY:
                    self._json(409, {"error":"Cannot enable — no AbuseIPDB API key at startup",
                                     "newcomer_abuse_check":False}); return
                ABUSEBLOCK_ENABLED = True
                tlog(f"{YELLOW}[{get_ts()}][*] Newcomer abuse check ENABLED — threshold: {ABUSE_THRESHOLD}{RESET}", "CONTROL")
                self._json(200, {"newcomer_abuse_check":True,"threshold":ABUSE_THRESHOLD})
            elif parsed.query == "disable":
                ABUSEBLOCK_ENABLED = False
                tlog(f"{YELLOW}[{get_ts()}][*] Newcomer abuse check DISABLED{RESET}", "CONTROL")
                self._json(200, {"newcomer_abuse_check":False,
                                 "note":"Blacklist, whitelist and runtime blocklist remain active"})
            else: self._json(400, {"error":"Use ?enable or ?disable","newcomer_abuse_check":ABUSEBLOCK_ENABLED})
            return
        
        if path == "/dashboard/blacklist":
            if not self._require_auth(): return
            ip = parse_qs(parsed.query).get("ip", [None])[0]
            if not ip: self._json(400, {"error": "missing ip"}); return
            self._json(200, dashboard_blacklist(ip)); return

        if path == "/dashboard/abuseconfig":
                    if not self._require_auth(): return
                    threshold_raw = parse_qs(parsed.query).get("threshold", [None])[0]
                    if threshold_raw is None: self._json(400, {"error": "missing threshold"}); return
                    try:
                        new_threshold = int(threshold_raw)
                        if not 0 <= new_threshold <= 100: raise ValueError
                    except ValueError:
                        self._json(400, {"error": "threshold must be integer 0-100"}); return
                    ABUSE_THRESHOLD = new_threshold
                    tlog(f"{YELLOW}[{get_ts()}][*] Abuse threshold updated to {ABUSE_THRESHOLD} via dashboard{RESET}", "CONTROL")
                    self._json(200, {"threshold": ABUSE_THRESHOLD}); return
        
        if path == "/tcpsniff":
            if parsed.query == "enable":
                if not any(t.name == 'packet_sniffer' for t in threading.enumerate()):
                    threading.Thread(target=packet_sniffer,
                                     args=(TITAN_LISTEN_PORT, TITAN_REMOTE_SERVER, TITAN_REMOTE_PORT),
                                     name='packet_sniffer', daemon=True).start()
                TCP_SNIFF_ENABLED = True
                tlog(f"{CYAN}[{get_ts()}][*] TCP Sniff ENABLED via dashboard{RESET}", "CONTROL")
                self._json(200, {"tcp_sniff": True})
            elif parsed.query == "disable":
                TCP_SNIFF_ENABLED = False
                with tcp_watch_lock: tcp_watched = set(TCP_WATCH)               # <- add
                if tcp_watched:                                                  # <- add
                    pass  # per-ID watches preserved — no action needed         # <- add
                tlog(f"{CYAN}[{get_ts()}][*] TCP Sniff DISABLED via dashboard — per-ID watches preserved{RESET}", "CONTROL")  # <- modify
                self._json(200, {"tcp_sniff": False, "per_id_watches": list(tcp_watched)})  # <- modify
            else:
                self._json(400, {"error": "Use ?enable or ?disable", "tcp_sniff": TCP_SNIFF_ENABLED})
            return

        if path == "/closeremotebyclient":
                    if parsed.query == "enable":
                        CLOSE_REMOTE_BY_CLIENT = True
                        tlog(f"{YELLOW}[{get_ts()}][*] CLOSE_REMOTE_BY_CLIENT ENABLED via dashboard{RESET}", "CONTROL")
                        self._json(200, {"close_remote_by_client": True})
                    elif parsed.query == "disable":
                        CLOSE_REMOTE_BY_CLIENT = False
                        tlog(f"{YELLOW}[{get_ts()}][*] CLOSE_REMOTE_BY_CLIENT DISABLED via dashboard{RESET}", "CONTROL")
                        self._json(200, {"close_remote_by_client": False})
                    else:
                        self._json(400, {"error": "Use ?enable or ?disable", "close_remote_by_client": CLOSE_REMOTE_BY_CLIENT})
                    return

        if path == "/closeclientbyremote":
            if parsed.query == "enable":
                CLOSE_CLIENT_BY_REMOTE = True
                tlog(f"{YELLOW}[{get_ts()}][*] CLOSE_CLIENT_BY_REMOTE ENABLED via dashboard{RESET}", "CONTROL")
                self._json(200, {"close_client_by_remote": True})
            elif parsed.query == "disable":
                CLOSE_CLIENT_BY_REMOTE = False
                tlog(f"{YELLOW}[{get_ts()}][*] CLOSE_CLIENT_BY_REMOTE DISABLED via dashboard{RESET}", "CONTROL")
                self._json(200, {"close_client_by_remote": False})
            else:
                self._json(400, {"error": "Use ?enable or ?disable", "close_client_by_remote": CLOSE_CLIENT_BY_REMOTE})
            return

        if path == "/dashboard/close_remote":
            if not self._require_auth(): return
            cid_raw = parse_qs(parsed.query).get("id", [None])[0]
            
            if cid_raw is None: self._json(400, {"error": "missing id"}); return
            
            try: cid = int(cid_raw)
            except ValueError: self._json(400, {"error": "id must be integer"}); return
            
            with pending_remote_sockets_lock: sock = PENDING_REMOTE_SOCKETS.pop(cid, None)
            if sock is None: self._json(404, {"error": f"no open remote socket for id {cid}"}); return

            with session_history_pending_lock:                                               # <- add
                _cr_entry = SESSION_HISTORY_PENDING.get(cid)                                # <- add
            _cr_ip      = _cr_entry.get("ip", "?")     if _cr_entry else "?"               # <- add
            _cr_comment = _cr_entry.get("comment", "") if _cr_entry else ""                 # <- add
            _cr_comment_str = f" # {_cr_comment}" if _cr_comment else ""                   # <- add

            try: sock.shutdown(socket.SHUT_RDWR)
            except Exception as e: tlog(f"{YELLOW}[{get_ts()}][!] close_remote: shutdown() failed for ID:#{cid} {_cr_ip}{_cr_comment_str}: {e}{RESET}", "ERROR")  # <- modify
            
            try: sock.close()
            except Exception as e: tlog(f"{YELLOW}[{get_ts()}][!] close_remote: close() failed for ID:#{cid} {_cr_ip}{_cr_comment_str}: {e}{RESET}", "ERROR")  # <- modify
            tlog(f"{YELLOW}[{get_ts()}][*] Operator force-closed remote socket for ID:#{cid} {_cr_ip}{_cr_comment_str}{RESET}", "CONTROL")  # <- modify
            self._json(200, {"id": cid, "status": "remote socket closed"}); return


        if path == "/dashboard/history/remove":
            if not self._require_auth(): return
            cid_raw = parse_qs(parsed.query).get("id", [None])[0]
            if cid_raw is None: self._json(400, {"error": "missing id"}); return
            try: cid = int(cid_raw)
            except ValueError: self._json(400, {"error": "id must be integer"}); return
            with session_history_lock:
                before = len(SESSION_HISTORY)
                to_keep = [e for e in SESSION_HISTORY if e.get("id") != cid]
                removed_entry = next((e for e in SESSION_HISTORY if e.get("id") == cid), None)
                SESSION_HISTORY.clear()
                SESSION_HISTORY.extend(to_keep)
                removed = before - len(SESSION_HISTORY)
            with session_history_pending_lock:
                SESSION_HISTORY_PENDING.pop(cid, None)
            if removed == 0:
                self._json(404, {"error": f"id {cid} not found in history"}); return
            _ip      = removed_entry.get("ip", "?")       if removed_entry else "?"
            _comment = removed_entry.get("comment", "")   if removed_entry else ""
            _comment_str = f" ({_comment})" if _comment else ""
            tlog(f"{YELLOW}[{get_ts()}][*] Dashboard removed ID:#{cid} {_ip}{_comment_str} from session history{RESET}", "CONTROL")
            self._json(200, {"id": cid, "removed": True}); return

        if path == "/dashboard/tempblock":
            if not self._require_auth(): return
            ip = parse_qs(parsed.query).get("ip", [None])[0]
            if not ip: self._json(400, {"error": "missing ip"}); return
            duration_raw = parse_qs(parsed.query).get("duration", ["0"])[0]
            try: duration = int(duration_raw)
            except ValueError: self._json(400, {"error": "duration must be integer seconds"}); return
            expiry = (time.time() + duration) if duration > 0 else None
            with timed_blocklist_lock:
                TIMED_BLOCKLIST[ip] = expiry
            with runtime_blocklist_lock:
                RUNTIME_BLOCKLIST.add(ip)
            disconnect_ip(ip, reason="temp block")
            expiry_str = datetime.datetime.fromtimestamp(expiry).strftime("%H:%M:%S") if expiry else "session"
            with auto_blocked_lock:
                AUTO_BLOCKED_IPS.append({
                    "ip": ip, "score": "—", "country": "—", "ts": get_ts(),
                    "type": "temp", "expires": expiry_str,
                })
            tlog(f"{YELLOW}[{get_ts()}][!] Temp block applied to {ip} — expires: {expiry_str}{RESET}", "CONTROL")
            self._json(200, {"ip": ip, "type": "temp", "expires": expiry_str}); return

        if path == "/dashboard/tempunblock":
            if not self._require_auth(): return
            ip = parse_qs(parsed.query).get("ip", [None])[0]
            if not ip: self._json(400, {"error": "missing ip"}); return
            with timed_blocklist_lock:
                was_present = ip in TIMED_BLOCKLIST
                TIMED_BLOCKLIST.pop(ip, None)
            with runtime_blocklist_lock:
                RUNTIME_BLOCKLIST.discard(ip)
            with auto_blocked_lock:
                AUTO_BLOCKED_IPS[:] = [e for e in AUTO_BLOCKED_IPS if not (e.get("ip") == ip and e.get("type") == "temp")]
            if not was_present: self._json(404, {"error": f"{ip} not in temp blocklist"}); return
            tlog(f"{YELLOW}[{get_ts()}][*] Temp block manually removed for {ip}{RESET}", "CONTROL")
            self._json(200, {"ip": ip, "unblocked": True}); return

        if path == "/dashboard/watch":
            if not self._require_auth(): return
            cid_raw = parse_qs(parsed.query).get("id", [None])[0]
            if cid_raw is None: self._json(400, {"error": "missing id"}); return
            try: cid = int(cid_raw)
            except ValueError: self._json(400, {"error": "id must be integer"}); return
            with active_lock: exists = cid in ACTIVE_CONNECTIONS
            if not exists: self._json(404, {"error": f"connection ID {cid} not active"}); return
            with verbose_watch_lock: VERBOSE_WATCH.add(cid)
            with active_lock: ip = ACTIVE_CONNECTIONS[cid].get("ip","?")
            tlog(f"{YELLOW}[{get_ts()}][*] Verbose watch ENABLED for ID:#{cid} ({ip}){RESET}", "CONTROL")
            self._json(200, {"id": cid, "ip": ip, "watch": True}); return

        if path == "/dashboard/unwatch":
            if not self._require_auth(): return
            cid_raw = parse_qs(parsed.query).get("id", [None])[0]
            if cid_raw is None: self._json(400, {"error": "missing id"}); return
            try: cid = int(cid_raw)
            except ValueError: self._json(400, {"error": "id must be integer"}); return
            
            with verbose_watch_lock:
                was_present = cid in VERBOSE_WATCH
                VERBOSE_WATCH.discard(cid)
            with hexdump_watch_lock:                # <- add: disable hex when watch disabled
                HEXDUMP_WATCH.discard(cid)          # <- add
                HEXDUMP_WATCH_PREV.pop(cid, None)   # <- add
            with active_lock: ip = ACTIVE_CONNECTIONS.get(cid, {}).get("ip","?")
            tlog(f"{YELLOW}[{get_ts()}][*] Verbose watch DISABLED for ID:#{cid} ({ip}){RESET}", "CONTROL")
            self._json(200, {"id": cid, "ip": ip, "watch": False}); return

        if path == "/dashboard/hexwatch":
            if not self._require_auth(): return
            cid_raw = parse_qs(parsed.query).get("id", [None])[0]
            if cid_raw is None: self._json(400, {"error": "missing id"}); return
            try: cid = int(cid_raw)
            except ValueError: self._json(400, {"error": "id must be integer"}); return
            with active_lock: exists = cid in ACTIVE_CONNECTIONS
            if not exists: self._json(404, {"error": f"connection ID {cid} not active"}); return
            with verbose_watch_lock: was_watching = cid in VERBOSE_WATCH
            with hexdump_watch_lock:
                HEXDUMP_WATCH.add(cid)
                HEXDUMP_WATCH_PREV[cid] = was_watching
            with verbose_lock: global_verbose = VERBOSE_ENABLED
            if not global_verbose:
                with verbose_watch_lock: VERBOSE_WATCH.add(cid)
            with active_lock: ip = ACTIVE_CONNECTIONS[cid].get("ip","?")
            tlog(f"{YELLOW}[{get_ts()}][*] Hex watch ENABLED for ID:#{cid} ({ip}) — was_watching={was_watching}{RESET}", "CONTROL")
            self._json(200, {"id": cid, "ip": ip, "hex_watch": True, "was_watching": was_watching}); return

        if path == "/dashboard/hexunwatch":
            if not self._require_auth(): return
            cid_raw = parse_qs(parsed.query).get("id", [None])[0]
            if cid_raw is None: self._json(400, {"error": "missing id"}); return
            try: cid = int(cid_raw)
            except ValueError: self._json(400, {"error": "id must be integer"}); return
            with hexdump_watch_lock:
                HEXDUMP_WATCH.discard(cid)
                was_watching = HEXDUMP_WATCH_PREV.pop(cid, False)
            if not was_watching:
                with verbose_watch_lock: VERBOSE_WATCH.discard(cid)
            with active_lock: ip = ACTIVE_CONNECTIONS.get(cid, {}).get("ip","?")
            tlog(f"{YELLOW}[{get_ts()}][*] Hex watch DISABLED for ID:#{cid} ({ip}) — watch_restored={was_watching}{RESET}", "CONTROL")
            self._json(200, {"id": cid, "ip": ip, "hex_watch": False, "watch_restored": was_watching}); return

        if path == "/dashboard/tcpwatch":                                        # <- add
            if not self._require_auth(): return                                  # <- add
            cid_raw = parse_qs(parsed.query).get("id", [None])[0]               # <- add
            if cid_raw is None: self._json(400, {"error": "missing id"}); return # <- add
            try: cid = int(cid_raw)                                              # <- add
            except ValueError: self._json(400, {"error": "id must be integer"}); return  # <- add
            with active_lock: exists = cid in ACTIVE_CONNECTIONS                 # <- add
            if not exists: self._json(404, {"error": f"connection ID {cid} not active"}); return  # <- add
            with tcp_watch_lock:                                                  # <- add
                was_watching = cid in TCP_WATCH                                  # <- add
                TCP_WATCH.add(cid)                                               # <- add
                TCP_WATCH_PREV[cid] = was_watching                               # <- add
            with active_lock: ip = ACTIVE_CONNECTIONS[cid].get("ip","?")        # <- add
            tlog(f"{CYAN}[{get_ts()}][*] TCP watch ENABLED for ID:#{cid} ({ip}){RESET}", "CONTROL")  # <- add
            self._json(200, {"id": cid, "ip": ip, "tcp_watch": True}); return   # <- add

        if path == "/dashboard/tcpunwatch":                                      # <- add
            if not self._require_auth(): return                                  # <- add
            cid_raw = parse_qs(parsed.query).get("id", [None])[0]               # <- add
            if cid_raw is None: self._json(400, {"error": "missing id"}); return # <- add
            try: cid = int(cid_raw)                                              # <- add
            except ValueError: self._json(400, {"error": "id must be integer"}); return  # <- add
            with tcp_watch_lock:                                                  # <- add
                TCP_WATCH.discard(cid)                                           # <- add
                TCP_WATCH_PREV.pop(cid, None)                                    # <- add
            with active_lock: ip = ACTIVE_CONNECTIONS.get(cid, {}).get("ip","?")  # <- add
            tlog(f"{CYAN}[{get_ts()}][*] TCP watch DISABLED for ID:#{cid} ({ip}){RESET}", "CONTROL")  # <- add
            self._json(200, {"id": cid, "ip": ip, "tcp_watch": False}); return  # <- add


        # new endpoint — add after /dashboard/history/remove block
        if path == "/dashboard/history/removeip":
            if not self._require_auth(): return
            ip = parse_qs(parsed.query).get("ip", [None])[0]
            if not ip: self._json(400, {"error": "missing ip"}); return
            with session_history_lock:
                before   = len(SESSION_HISTORY)
                to_keep  = [e for e in SESSION_HISTORY if e.get("ip") != ip]
                SESSION_HISTORY.clear()
                SESSION_HISTORY.extend(to_keep)
                removed  = before - len(SESSION_HISTORY)
            tlog(f"{YELLOW}[{get_ts()}][*] Dashboard removed {removed} history entries for IP {ip}{RESET}", "CONTROL")
            self._json(200, {"ip": ip, "removed": removed}); return

        if path == "/dashboard/whitelist/editcomment":
            if not self._require_auth(): return
            ip = parse_qs(parsed.query).get("ip", [None])[0]
            if not ip: self._json(400, {"error": "missing ip"}); return
            comment = parse_qs(parsed.query).get("comment", [""])[0]
            self._json(200, edit_whitelist_comment(ip, comment)); return

        if path == "/dashboard/unblock":
            if not self._require_auth(): return
            ip = parse_qs(parsed.query).get("ip", [None])[0]
            if not ip: self._json(400, {"error": "missing ip"}); return
            self._json(200, unblock_ip(ip)); return

        self._json(404, {"error": "not found"})

    def log_message(self, fmt, *args):
        return  # suppress default access log

class TitanHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True
    
    def handle_error(self, request, client_address):
        import traceback
        exc = sys.exc_info()[1]
        if isinstance(exc, ConnectionResetError): return  # <- add: silently ignore scanner noise
        tb  = traceback.format_exc()
        tlog(f"{YELLOW}[{get_ts()}][!] HTTP handler error from {client_address[0]}:{client_address[1]} — {type(exc).__name__}: {exc}{RESET}", "ERROR")
        tlog(f"{YELLOW}{tb}{RESET}", "ERROR")    

def http_control_loop():
    srv = TitanHTTPServer((HTTP_CTRL_HOST, HTTP_CTRL_PORT), TitanHTTPHandler)
    tlog(f"[*] Titan v{TITAN_VERSION} HTTP control on http://{HTTP_CTRL_HOST}:{HTTP_CTRL_PORT}", "INFO")
    srv.serve_forever()

# new functions — add before if __name__ == "__main__":

def _parse_args():
    parser = argparse.ArgumentParser(description=TITAN_HELP,
                                     formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument("--listenport",         type=int, required=False, default=None)
    parser.add_argument("--remoteserver",        required=False, default=None)
    parser.add_argument("--remoteport",          type=int, required=False, default=None)
    parser.add_argument("--ssl",                 action="store_true")
    parser.add_argument("--hexdump",             action="store_true")
    parser.add_argument("--tcp-sniff",           action="store_true",
                        help="Enable AF_PACKET TCP handshake logging (Linux/root)")
    parser.add_argument("--httpexpose",          type=int, metavar="HTTPPORT",
                        help="Enable HTTP control on given port")
    parser.add_argument("--httpbind",            type=str, default="127.0.0.1",
                        help="Bind address for HTTP control (default=127.0.0.1, use 0.0.0.0 for external)")
    parser.add_argument("--rulesfile",           type=str)
    parser.add_argument("--abuseblock",          nargs=2, metavar=("SCORE","APIKEY"))
    parser.add_argument("--verbose",             action="store_true")
    parser.add_argument("--closeremotebyclient", action="store_true")
    parser.add_argument("--closeclientbyremote", action="store_true")
    parser.add_argument("--dashboardpath",       type=str,
                        help="Path to titan-dashboard/ folder containing login.html and dashboard.html")
    parser.add_argument("--dashboardauth",       type=str, metavar="USER:PASSWORD",
                        help="Credentials for web dashboard (e.g. admin:mysecret)")
    parser.add_argument("--changelog",           action="store_true",
                        help="Print full version changelog and exit")
    return parser.parse_args()


def _setup_dashboard(args):
    global DASHBOARD_PATH, DASHBOARD_USER, DASHBOARD_PASS_HASH
    if args.dashboardpath:
        DASHBOARD_PATH = args.dashboardpath
    if args.dashboardauth:
        if ":" not in args.dashboardauth:
            print(f"{RED}[{get_ts()}][!] --dashboardauth must be user:password{RESET}", flush=True)
            sys.exit(1)
        DASHBOARD_USER, raw_pass = args.dashboardauth.split(":", 1)
        DASHBOARD_PASS_HASH = hashlib.sha256(raw_pass.encode()).hexdigest()

def _setup_abuseblock(args):
    global ABUSE_THRESHOLD, ABUSE_API_KEY, ABUSEBLOCK_ENABLED
    if args.abuseblock is not None:
        abuse_score_str, abuse_key_src = args.abuseblock
        try: ABUSE_THRESHOLD = int(abuse_score_str)
        except ValueError:
            print(f"{RED}[{get_ts()}][!] --abuseblock score must be an integer{RESET}", flush=True)
            sys.exit(1)
        ABUSE_API_KEY = load_api_key(abuse_key_src)
        if not ABUSE_API_KEY:
            print(f"{RED}[{get_ts()}][!] --abuseblock API key could not be loaded from: {abuse_key_src}{RESET}", flush=True)
            sys.exit(1)
        ABUSEBLOCK_ENABLED = True
        tlog(f"{YELLOW}[{get_ts()}][*] Abuse score check enabled — threshold: {ABUSE_THRESHOLD}{RESET}", "INFO")
    else:
        ABUSEBLOCK_ENABLED = False
        tlog(f"{YELLOW}[{get_ts()}][*] Abuse score check disabled{RESET}", "INFO")

def _setup_http_control(args):
    global HTTP_CTRL_PORT, HTTP_CTRL_HOST
    if args.httpexpose is not None:
        HTTP_CTRL_PORT = args.httpexpose
        HTTP_CTRL_HOST = args.httpbind
        return True
    return False

def _print_startup_banner(args, http_enabled, dashboard_status):
    tlog(f"{CYAN}[{get_ts()}][*] ---- Titan v{TITAN_VERSION} Startup Summary -------------------------", "INFO")
    tlog(f"{CYAN}[{get_ts()}][*] Listen Port:              {args.listenport}", "INFO")
    tlog(f"{CYAN}[{get_ts()}][*] Remote Server:            {args.remoteserver}:{args.remoteport}", "INFO")
    tlog(f"{CYAN}[{get_ts()}][*] HTTP Monitor/Control:     "
         f"{'Enabled on ' + HTTP_CTRL_HOST + ':' + str(HTTP_CTRL_PORT) if http_enabled else 'Disabled'}", "INFO")
    tlog(f"{CYAN}[{get_ts()}][*] Web Dashboard:            {dashboard_status}", "INFO")
    tlog(f"{CYAN}[{get_ts()}][*] Dashboard File:           {DASHBOARD_HTML}", "INFO")
    tlog(f"{CYAN}[{get_ts()}][*] Verbose Logging:          {'Enabled' if args.verbose else 'Disabled'}", "INFO")
    tlog(f"{CYAN}[{get_ts()}][*] Hexdump Mode:             {'Enabled' if args.hexdump else 'Disabled'}", "INFO")
    tlog(f"{CYAN}[{get_ts()}][*] TCP Sniff Logging:        {'Enabled' if args.tcp_sniff else 'Disabled (tracker always on)'}", "INFO")
    tlog(f"{CYAN}[{get_ts()}][*] Rules File:               {RULEFILE if RULEFILE else 'None (disabled)'}", "INFO")
    tlog(f"{CYAN}[{get_ts()}][*] Abuse Score Checking:     "
         f"{'Enabled (threshold ' + str(ABUSE_THRESHOLD) + ')' if ABUSEBLOCK_ENABLED else 'Disabled'}", "INFO")
    tlog(f"{CYAN}[{get_ts()}][*] Close Remote By Client:   {'Enabled' if args.closeremotebyclient else 'Disabled'}", "INFO")
    tlog(f"{CYAN}[{get_ts()}][*] Close Client By Remote:   {'Enabled' if args.closeclientbyremote else 'Disabled'}", "INFO")
    tlog(f"{CYAN}[{get_ts()}][*] -------------------------------------------------------", "INFO")


# ── Main ──────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    args = _parse_args()

    if args.changelog:                          # <- add
        print(TITAN_CHANGELOG); sys.exit(0)     # <- add

    if not args.listenport or not args.remoteserver or not args.remoteport:  # <- add
        print(f"error: At least --listenport, --remoteserver and --remoteport are required for titan proxy to run. Use --help for more options", flush=True)  # <- add
        sys.exit(1)

    TITAN_LISTEN_PORT   = args.listenport
    TITAN_REMOTE_SERVER = args.remoteserver
    TITAN_REMOTE_PORT   = args.remoteport

    if args.verbose:
        with verbose_lock: VERBOSE_ENABLED = True

    if args.closeremotebyclient: CLOSE_REMOTE_BY_CLIENT = True
    if args.closeclientbyremote: CLOSE_CLIENT_BY_REMOTE = True

    _setup_dashboard(args)
    http_enabled = _setup_http_control(args)
    RULEFILE = args.rulesfile if args.rulesfile else None
    _setup_abuseblock(args)

    if RULEFILE is not None:
        load_rules()
        threading.Thread(target=rules_watcher, daemon=True).start()
    else:
        tlog(f"{YELLOW}[{get_ts()}][*] No rules file provided — rule watcher disabled{RESET}", "INFO")

    threading.Thread(target=timed_block_watcher, daemon=True).start()

    if args.hexdump:
        with hexdump_lock: HEXDUMP_ENABLED = True

    # Sniffer always starts — needed for last_remote_ts tracking via AF_PACKET
    threading.Thread(target=packet_sniffer,
                     args=(args.listenport, args.remoteserver, args.remoteport),
                     name='packet_sniffer', daemon=True).start()
    if args.tcp_sniff:
        TCP_SNIFF_ENABLED = True  # enables [TCP] log lines; tracking runs regardless

    if http_enabled:
        threading.Thread(target=http_control_loop, daemon=True).start()
    else:
        tlog(f"{YELLOW}[{get_ts()}][*] HTTP control disabled (no --httpexpose){RESET}", "INFO")

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', args.listenport))
    server.listen(100)
    total_conn_ever = 0

    dashboard_status = "Disabled"
    if DASHBOARD_PATH and DASHBOARD_USER:
        dashboard_status = f"Enabled at http://{HTTP_CTRL_HOST}:{HTTP_CTRL_PORT}/dashboard"
    elif DASHBOARD_PATH or DASHBOARD_USER:
        dashboard_status = "Partially configured (need both --dashboardpath and --dashboardauth)"

    _print_startup_banner(args, http_enabled, dashboard_status)

    while True:
        try: c, a = server.accept()
        except Exception as e:
            tlog(f"{RED}[{get_ts()}][!] Accept error: {e}{RESET}", "ERROR"); continue

        client_ip = a[0]
        ip_obj    = ipaddress.ip_address(client_ip)

        if ALLOWALL_ENABLED:
            total_conn_ever += 1
            with counter_lock: connection_count += 1
            tlog(f"{GREEN}[{get_ts()}][+] ALLOWALL: {client_ip} accepted without checks{RESET}", "CONNECT")
            threading.Thread(target=bridge,
                             args=(c, a, client_ip, args.remoteserver, args.remoteport, args.ssl, total_conn_ever),
                             daemon=True).start()
            continue

        with runtime_blocklist_lock: in_blocklist = client_ip in RUNTIME_BLOCKLIST
        if in_blocklist:
            tlog(f"{RED}[{get_ts()}] RUNTIME BLOCKLIST: blocked {client_ip}{RESET}", "BLOCK")
            try: c.shutdown(socket.SHUT_RDWR)
            except Exception: pass
            #except Exception as e: tlog(f"{YELLOW}[{get_ts()}][!] shutdown() blocked {client_ip}: {e}{RESET}", "ERROR")
            try: c.close()
            except Exception: pass
            #except Exception as e: tlog(f"{YELLOW}[{get_ts()}][!] close() blocked {client_ip}: {e}{RESET}", "ERROR")
            continue

        with rules_lock:
            white_entry = ip_in_list(ip_obj, WHITELIST, return_entry=True)
            black_entry = ip_in_list(ip_obj, BLACKLIST, return_entry=True)
        is_white = bool(white_entry)

        if not is_white and black_entry:
            tlog(f"{RED}[{get_ts()}] BLOCKED ATTEMPT from {client_ip}{RESET}", "BLOCK")
            _rf_score, _rf_country = "—", "—"                                              # <- add
            if ABUSE_API_KEY:                                                                # <- add
                _s, _c, _ = abuse_lookup_cached(client_ip)                                 # <- add
                if _s is not None: _rf_score, _rf_country = str(_s), (_c or "—")         # <- add
            with auto_blocked_lock:
                if not any(e.get("ip") == client_ip for e in AUTO_BLOCKED_IPS):
                    AUTO_BLOCKED_IPS.append({
                        "ip": client_ip, "score": _rf_score, "country": _rf_country,       # <- modify
                        "ts": get_ts(), "type": "rulefile", "expires": "—"
                    })
            try: c.shutdown(socket.SHUT_RDWR)
            except Exception: pass
            try: c.close()
            except Exception: pass
            continue

        if not is_white and ABUSEBLOCK_ENABLED:
            score, country, source = abuse_lookup_cached(client_ip)
            if score is not None:
                tlog(f"{YELLOW}[{get_ts()}][INFO] AbuseIPDB score for {client_ip}: {score} (by {source}){RESET}", "ABUSE")
                if score >= ABUSE_THRESHOLD:
                    tlog(f"{RED}[{get_ts()}][!] {client_ip} flagged (score {score}) — auto-blocking{RESET}", "ABUSE")
                    if RULEFILE: add_block_rule(client_ip, score); load_rules()
                    else: tlog(f"{YELLOW}[{get_ts()}][*] No rules file — blocking in memory only{RESET}", "INFO")
                    disconnect_ip(client_ip, reason=f"AbuseIPDB auto-block (score {score})")
                    with runtime_blocklist_lock: RUNTIME_BLOCKLIST.add(client_ip)
                    with auto_blocked_lock: AUTO_BLOCKED_IPS.append({"ip":client_ip,"score":score,"country":country,"ts":get_ts()})
                    try: c.shutdown(socket.SHUT_RDWR)
                    except Exception: pass
                    #except Exception as e: tlog(f"{YELLOW}[{get_ts()}][!] shutdown() abuse block {client_ip}: {e}{RESET}", "ERROR")
                    try: c.close()
                    #except Exception as e: tlog(f"{YELLOW}[{get_ts()}][!] close() abuse block {client_ip}: {e}{RESET}", "ERROR")
                    except Exception: pass
                    continue

        total_conn_ever += 1
        with counter_lock: connection_count += 1
        threading.Thread(target=bridge,
                         args=(c, a, a[0], args.remoteserver, args.remoteport, args.ssl, total_conn_ever),
                         daemon=True).start()
