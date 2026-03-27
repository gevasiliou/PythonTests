#!/usr/bin/env python3
import smtplib
import ssl
import argparse
import base64
import sys
import hmac
import hashlib
import re
from datetime import datetime

# ANSI Color Codes
class C:
    BLUE = '\033[94m'    
    RED = '\033[91m'     
    GREEN = '\033[92m'   
    YELLOW = '\033[93m'  
    WHITE = '\033[97m'   
    CYAN = '\033[96m'    
    END = '\033[0m'      

class ByteTracker:
    def __init__(self):
        self.sent = 0
        self.recv = 0
    def add_sent(self, data):
        self.sent += len(str(data).encode('utf-8'))
    def add_recv(self, data):
        self.recv += len(str(data).encode('utf-8'))

stats = ByteTracker()
SHOW_HEX = False

def get_ts():
    return f"{C.WHITE}[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}]{C.END}"

def to_hex(s):
    """Converts string to a readable hex dump format."""
    return " ".join(f"{ord(c):02x}" for c in s)

def log_plc(msg, is_data=False):
    """Logs the exact string sent. If --hex is on, shows the byte breakdown."""
    stats.add_sent(msg)
    print(f"{get_ts()} {C.BLUE}[PLC ->] {msg}{C.END}")
    if SHOW_HEX:
        # Append the SMTP standard CRLF to the hex view if it's a command
        hex_str = to_hex(msg) + " 0d 0a" 
        print(f"{' '*14} {C.YELLOW}[HEX] {hex_str}{C.END}")

def log_info(msg):
    print(f"{get_ts()} {C.GREEN}[*] INFO: {msg}{C.END}")

def log_decode(b64_str, label="DECODED"):
    try:
        if not b64_str or len(b64_str) < 2: return
        decoded = base64.b64decode(b64_str).decode('utf-8', errors='replace')
        decoded = decoded.replace('\x00', '[NULL]')
        print(f"{get_ts()} {C.CYAN}[{label}] {decoded}{C.END}")
    except Exception: pass

def log_srv(code, msg):
    stats.add_recv(f"{code} {msg}")
    if isinstance(msg, bytes):
        msg = msg.decode('utf-8', errors='ignore').strip()
    lines = str(msg).splitlines()
    for i, line in enumerate(lines):
        sep = "-" if i < len(lines) - 1 else " "
        print(f"{get_ts()} {C.RED}[SRV <-] {code}{sep}{line}{C.END}")
        if str(code) == "334":
            log_decode(line, label="SRV CHALLENGE")

def perform_auth(server, args, literal_string):
    cmd_upper = literal_string.upper()
    if 'LOGIN' in cmd_upper:
        log_info(f"Executing LOGIN sequence via {literal_string}")
        log_plc("AUTH LOGIN")
        code, resp = server.docmd("AUTH LOGIN"); log_srv(code, resp)
        if code == 334:
            u_b64 = base64.b64encode(args.username.encode()).decode()
            log_plc(u_b64); log_decode(u_b64)
            code, resp = server.docmd(u_b64); log_srv(code, resp)
        if code == 334:
            p_b64 = base64.b64encode(args.password.encode()).decode()
            log_plc(p_b64); log_decode(p_b64)
            code, resp = server.docmd(p_b64); log_srv(code, resp)
        return code, resp
    elif 'PLAIN' in cmd_upper:
        log_info(f"Executing PLAIN sequence via {literal_string}")
        auth_str = f"\0{args.username}\0{args.password}"
        auth_b64 = base64.b64encode(auth_str.encode()).decode()
        log_plc(f"AUTH PLAIN {auth_b64}"); log_decode(auth_b64)
        return server.docmd("AUTH PLAIN", auth_b64)
    elif 'CRAM-MD5' in cmd_upper:
        log_info(f"Executing CRAM-MD5 sequence via {literal_string}")
        log_plc("AUTH CRAM-MD5")
        code, chall_b64 = server.docmd("AUTH", "CRAM-MD5"); log_srv(code, chall_b64)
        if code == 334:
            chall = base64.b64decode(chall_b64)
            hashed = hmac.new(args.password.encode(), chall, hashlib.md5).hexdigest()
            resp_str = f"{args.username} {hashed}"
            resp_b64 = base64.b64encode(resp_str.encode()).decode()
            log_plc(resp_b64); log_decode(resp_b64, label="PLC RESPONSE")
            return server.docmd(resp_b64)
    return 500, "Unknown Method"

def get_ssl_context(verify=True):
    context = ssl.create_default_context()
    if not verify:
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
    return context

def mimic_plc():
    global SHOW_HEX
    parser = argparse.ArgumentParser(description='PLC Email Protocol Navigator v4.1')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--plain', action='store_true')
    group.add_argument('--starttls', action='store_true')
    group.add_argument('--fullssl', action='store_true')
    parser.add_argument('--remoteserver', required=True)
    parser.add_argument('--remoteport', type=int, required=True)
    parser.add_argument('--ehlo-name', default='PLC_STATION_01')
    parser.add_argument('--username')
    parser.add_argument('--password')
    parser.add_argument('--auth')
    parser.add_argument('--no-verify', action='store_true')
    parser.add_argument('--hex', action='store_true', help='Show hexadecimal dump of sent bytes')
    parser.add_argument('--from-addr', dest='sender', required=True)
    parser.add_argument('--to-addr', dest='recipient', required=True)
    parser.add_argument('--subject', default='PLC_STATION_01 Alarm')
    parser.add_argument('--body', default="PLC_STATION_01 email body")

    args = parser.parse_args()
    SHOW_HEX = args.hex
    email_body = sys.stdin.read() if not sys.stdin.isatty() else (args.body or "PLC Test Message")
    
    use_verification = not args.no_verify
    attempt = 0
    server = None
    start_time = datetime.now()

    while attempt < 2:
        try:
            if args.fullssl:
                log_info(f"Connecting via SMTPS (Implicit SSL). Verification: {'ON' if use_verification else 'OFF'}")
                server = smtplib.SMTP_SSL(args.remoteserver, args.remoteport, context=get_ssl_context(use_verification), timeout=60)
                welcome_msg = getattr(server, 'welcome', b"220 (Implicit SSL Connected)")
                log_srv(220, welcome_msg)
            else:
                log_info(f"Connecting via TCP to {args.remoteserver}:{args.remoteport}")
                server = smtplib.SMTP(timeout=60)
                code, resp = server.connect(args.remoteserver, args.remoteport)
                log_srv(code, resp)
                server._host = args.remoteserver

            log_plc(f"EHLO {args.ehlo_name}")
            code, resp = server.ehlo(args.ehlo_name); log_srv(code, server.ehlo_resp)

            if args.starttls and "starttls" in server.esmtp_features:
                log_plc("STARTTLS")
                try:
                    code, resp = server.starttls(context=get_ssl_context(use_verification))
                    log_srv(code, resp)
                    log_info("STARTTLS successful. Connection is now encrypted.")
                except ssl.SSLError as e:
                    if use_verification:
                        print(f"{get_ts()} {C.RED}[!] SSL VERIFY FAILED: {e}{C.END}")
                        log_info("Retrying with --no-verify...")
                        use_verification = False; attempt += 1
                        server.close(); continue
                    else: raise e
                log_plc(f"EHLO {args.ehlo_name}")
                code, resp = server.ehlo(args.ehlo_name); log_srv(code, server.ehlo_resp)
            break 
        except Exception as e:
            if "SSL" in str(e) and use_verification:
                use_verification = False; attempt += 1
                if server: server.close()
                continue
            print(f"\n{get_ts()} {C.RED}[!] Error: {e}{C.END}"); sys.exit(1)

    try:
        if args.username and args.password:
            raw_lines = server.ehlo_resp.decode().splitlines()
            literal_auth_options = []
            auth_pattern = re.compile(r'(AUTH.*)', re.IGNORECASE)
            for line in raw_lines:
                match = auth_pattern.search(line)
                if match:
                    raw_string = match.group(1).strip()
                    if ' ' in raw_string and not raw_string.startswith("AUTH="):
                        parts = raw_string.split()
                        if len(parts) > 1 and parts[0].upper() == "AUTH":
                            for m in parts[1:]: literal_auth_options.append(f"AUTH {m}")
                        else: literal_auth_options.append(raw_string)
                    else: literal_auth_options.append(raw_string)

            literal_auth_options = sorted(list(set(literal_auth_options)))
            selected_literal = None

            if args.auth:
                for opt in literal_auth_options:
                    if args.auth.upper() in opt.upper():
                        selected_literal = opt; break
            
            if not selected_literal and not args.auth:
                log_info("Auto-selecting best method...")
                for p_method in ['CRAM-MD5', 'LOGIN', 'PLAIN']:
                    for opt in literal_auth_options:
                        if p_method in opt.upper():
                            selected_literal = opt; break
                    if selected_literal: 
                        log_info(f"Auto-selected: {selected_literal}")
                        break

            auth_code, auth_resp = perform_auth(server, args, selected_literal)
            if not isinstance(auth_resp, str): log_srv(auth_code, auth_resp)

        log_plc(f"MAIL FROM:<{args.sender}>")
        code, resp = server.mail(args.sender); log_srv(code, resp)
        
        log_plc(f"RCPT TO:<{args.recipient}>")
        code, resp = server.rcpt(args.recipient); log_srv(code, resp)
        
        log_plc("DATA")
        msg = f"From: {args.sender}\r\nTo: {args.recipient}\r\nSubject: {args.subject}\r\n\r\n{email_body}"
        
        for line in msg.splitlines():
            log_plc(line)
        log_plc(".") 
        
        code, resp = server.data(msg); log_srv(code, resp)
        log_plc("QUIT"); server.quit()
        
        duration = (datetime.now() - start_time).total_seconds()
        print(f"\n{C.WHITE}{'='*45}{C.END}")
        print(f"{C.GREEN}[+] Transaction Complete in {duration:.2f}s{C.END}")
        print(f"{C.CYAN}[i] Total Sent: {stats.sent} bytes{C.END}")
        print(f"{C.CYAN}[i] Total Recv: {stats.recv} bytes{C.END}")
        print(f"{C.WHITE}{'='*45}{C.END}")

    except Exception as e:
        print(f"\n{get_ts()} {C.RED}[!] Protocol Error: {e}{C.END}"); sys.exit(1)

if __name__ == "__main__":
    mimic_plc()
