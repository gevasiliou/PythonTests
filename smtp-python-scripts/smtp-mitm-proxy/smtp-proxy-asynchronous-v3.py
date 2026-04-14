#!/usr/bin/env python3
# In this V3 , we allow specific IPs to get connected and make use of this proxy.
# Allowed IPs are stored in a local file named "smtp-proxy-allowed-ip"
# This sounds silly, but when this script is exposed on the global internet you will get
# million of hits by bots and attackers - without IP filtering the --remoteserver most probably will ban you.
import socket, ssl, threading, base64, re, argparse, sys, signal, datetime
import logging
import ipaddress

# ANSI Colors --
RED, BLUE, GREEN, YELLOW, RESET = '\033[91m', '\033[94m', '\033[92m', '\033[93m', '\033[0m'
CERTFILE = 'cert.pem'
KEYFILE = 'key.pem'

def load_allowed_ips(filename="smtp-proxy-allowed-ip"):
    allowed = []
    try:
        with open(filename, "r") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                allowed.append(ipaddress.ip_network(line, strict=False))
    except Exception as e:
        print(f"Could not load allowed IP list: {e}")
    return allowed

def get_ts():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def signal_handler(sig, frame):
    print(f"\n{GREEN}[*] Gracefully shutting down...{RESET}")
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

def try_decode(data):
    try:
        if len(data) > 4 and re.match(r'^[A-Za-z0-9+/]+={0,2}$', data.decode().strip()):
            return base64.b64decode(data).decode('utf-8', errors='ignore')
    except:
        pass
    return None

def pipe(source, destination, label, color):
    try:
        while True:
            data = source.recv(8192)
            if not data:
                break

            msg = data.decode(errors='ignore').strip()
            if msg:
                print(f"{color}{label}: {msg}{RESET}")
                decoded = try_decode(data)
                if decoded:
                    print(f"{GREEN}   [DECODED]: {decoded}{RESET}")

            destination.sendall(data)
    except:
        pass

def bridge(client_sock, addr, remote_host, remote_port, use_starttls):
    print(f"\n{GREEN}[+] PLC CONNECTED: {addr[0]} at {get_ts()}{RESET}")
    remote_sock = None
    try:
        remote_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        remote_sock.connect((remote_host, remote_port))

        banner = remote_sock.recv(4096)
        print(f"{RED}REMOTE -> PLC: {banner.decode(errors='ignore').strip()}{RESET}")
        client_sock.sendall(banner)

        if not use_starttls:
            print(f"{YELLOW}[*] Non-Encrypted Mode: Establishing Transparent Pipe...{RESET}")
            threading.Thread(target=pipe, args=(client_sock, remote_sock, "PLC -> REMOTE", BLUE), daemon=True).start()
            pipe(remote_sock, client_sock, "REMOTE -> PLC", RED)
            return

        while True:
            data = client_sock.recv(4096)
            if not data:
                break

            msg = data.decode(errors='ignore').strip()
            print(f"{BLUE}PLC -> REMOTE: {msg}{RESET}")

            if b"STARTTLS" in data.upper():
                remote_sock.sendall(data)
                resp = remote_sock.recv(4096)
                print(f"{RED}REMOTE -> PLC: {resp.decode(errors='ignore').strip()}{RESET}")
                client_sock.sendall(b"220 2.0.0 Ready to start TLS\r\n")

                context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
                context.load_cert_chain(certfile=CERTFILE, keyfile=KEYFILE)
                client_ssl = context.wrap_socket(client_sock, server_side=True)

                remote_ctx = ssl._create_unverified_context()
                remote_ssl = remote_ctx.wrap_socket(remote_sock, server_hostname=remote_host)

                print(f"{GREEN}[*] TLS Tunnel Established. Decrypting Traffic...{RESET}")

                threading.Thread(target=pipe, args=(client_ssl, remote_ssl, "DEC (PLC->REMOTE)", BLUE), daemon=True).start()
                pipe(remote_ssl, client_ssl, "DEC (REMOTE->PLC)", RED)
                return

            remote_sock.sendall(data)
            resp = remote_sock.recv(4096)
            if resp:
                print(f"{RED}REMOTE -> PLC: {resp.decode(errors='ignore').strip()}{RESET}")
                client_sock.sendall(resp)

    except Exception as e:
        print(f"{RED}[!] Connection error: {e}{RESET}")
    finally:
        try:
            client_sock.close()
        except:
            pass
        if remote_sock:
            try:
                remote_sock.close()
            except:
                pass


# ============================================================
#                LOGGING EXTENSION (ADD-ON)
# ============================================================

LOG_ENABLED = False

def init_logging(filename):
    global LOG_ENABLED
    LOG_ENABLED = True

    handler = logging.FileHandler(filename, mode='a')
    handler.setLevel(logging.INFO)
    handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] [%(threadName)s] %(message)s"))

    # REAL-TIME FLUSH FIX
    def emit_with_flush(record, orig_emit=handler.emit):
        orig_emit(record)
        handler.flush()

    handler.emit = emit_with_flush

    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    logger.handlers = [handler]

    logging.info("=== SMTP Proxy Logging Initialized ===")

    class LogRedirector:
        def write(self, msg):
            msg = msg.strip()
            if msg:
                logging.info(msg)
        def flush(self):
            pass

    sys.stdout = LogRedirector()
    sys.stderr = LogRedirector()

def log_event(message):
    if LOG_ENABLED:
        logging.info(message)

def log_packet(direction, data):
    if LOG_ENABLED:
        try:
            preview = data[:200].decode(errors="ignore").replace("\n", "\\n")
        except:
            preview = str(data[:200])
        logging.info(f"{direction}: {preview}")

def log_exception(context, exc):
    if LOG_ENABLED:
        logging.error(f"{context}: {exc}", exc_info=True)


# ============================================================
#         WRAPPERS (ONLY ENABLED WHEN LOGGING IS ON)
# ============================================================

_original_pipe = pipe
_original_bridge = bridge

def enable_wrappers():
    global pipe, bridge

    def pipe_with_logging(source, destination, label, color):
        try:
            while True:
                data = source.recv(8192)
                if not data:
                    return
                log_packet(label, data)
                destination.sendall(data)
        except Exception as e:
            log_exception("pipe", e)
            return

    def bridge_with_logging(client_sock, addr, remote_host, remote_port, use_starttls):
        log_event(f"New connection from {addr[0]}")
        try:
            return _original_bridge(client_sock, addr, remote_host, remote_port, use_starttls)
        except Exception as e:
            log_exception("bridge", e)

    pipe = pipe_with_logging
    bridge = bridge_with_logging


# ============================================================
#                        MAIN
# ============================================================

if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="Universal SMTP Transparent Proxy",
        formatter_class=lambda prog: argparse.HelpFormatter(prog, max_help_position=80)
    )
    parser.add_argument("--listenport", type=int, default=587)
    parser.add_argument("--remoteserver", required=True)
    parser.add_argument("--remoteport", type=int, default=587)
    parser.add_argument("--starttls", action="store_true")
    parser.add_argument("--log", metavar="FILE", help="Enable logging to FILE (disables console output)")
    args = parser.parse_args()

    if args.log:
        init_logging(args.log)
        enable_wrappers()
        log_event("Proxy started")

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', args.listenport))
    server.listen(5)

    #print(f"{GREEN}[*] Universal Proxy Active: {args.listenport} -> {args.remoteserver}{RESET}")
    print(f"[{get_ts()}] {GREEN}[*] Universal Proxy Active: {args.listenport} -> {args.remoteserver}{RESET}")


    while True:
        try:
            ALLOWED_NETS = load_allowed_ips()
            if not ALLOWED_NETS:
                print("[!] WARNING: No allowed IPs loaded. Proxy will reject all clients.")
            client, addr = server.accept()
            ip = ipaddress.ip_address(addr[0])
            if not any(ip in net for net in ALLOWED_NETS):
#                print(f"[!] Rejecting unauthorized client: {addr[0]}")
                print(f"{get_ts()} [!] Rejecting unauthorized client: {addr[0]}")
                client.close()
                continue
            threading.Thread(target=bridge, args=(client, addr, args.remoteserver, args.remoteport, args.starttls), daemon=True).start()
        except Exception as e:
            print(f"Server Error: {e}")
            log_exception("server", e)
