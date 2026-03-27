#!/usr/bin/env python3
import smtplib
import ssl
import argparse
import base64
import sys
import re
from datetime import datetime

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

def get_ts():
    return f"{C.WHITE}[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}]{C.END}"

def log_plc(msg):
    stats.add_sent(msg)
    print(f"{get_ts()} {C.BLUE}[PLC ->] {msg}{C.END}")

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

def check_code(code, msg):
    if code >= 400:
        print(f"\n{get_ts()} {C.RED}[!] TERMINAL ERROR {code}: {msg}{C.END}")
        if code == 530:
            print(f"{C.YELLOW}[*] Suggestion: Check if --starttls is required for this port.{C.END}")
        sys.exit(1)

def perform_auth(server, args, literal_string):
    if not literal_string: return 500, "No Auth Method"
    cmd_upper = literal_string.upper()
    if 'LOGIN' in cmd_upper:
        log_info(f"Executing LOGIN sequence via {literal_string}")
        log_plc("AUTH LOGIN")
        code, resp = server.docmd("AUTH LOGIN"); log_srv(code, resp); check_code(code, resp)
        if code == 334:
            u_b64 = base64.b64encode(args.username.encode()).decode()
            log_plc(u_b64); log_decode(u_b64)
            code, resp = server.docmd(u_b64); log_srv(code, resp); check_code(code, resp)
        if code == 334:
            p_b64 = base64.b64encode(args.password.encode()).decode()
            log_plc(p_b64); log_decode(p_b64)
            code, resp = server.docmd(p_b64); log_srv(code, resp); check_code(code, resp)
        return code, resp
    elif 'PLAIN' in cmd_upper:
        log_info(f"Executing PLAIN sequence via {literal_string}")
        auth_str = f"\0{args.username}\0{args.password}"
        auth_b64 = base64.b64encode(auth_str.encode()).decode()
        log_plc(f"AUTH PLAIN {auth_b64}"); log_decode(auth_b64)
        code, resp = server.docmd("AUTH PLAIN", auth_b64); log_srv(code, resp); check_code(code, resp)
        return code, resp
    return 500, "Unsupported Method"

def get_ssl_context(verify=True):
    context = ssl.create_default_context()
    if not verify:
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
    return context

def mimic_plc():
    # Help Epilogue Content
    epilog_msg = f"""
{C.CYAN}Common PLC Configurations:{C.END}
  {C.GREEN}Gmail Port 587:{C.END} --remoteserver smtp.gmail.com --remoteport 587 --starttls
  {C.GREEN}Gmail Port 465:{C.END} --remoteserver smtp.gmail.com --remoteport 465 --fullssl
  {C.GREEN}Internal Relay:{C.END} --remoteserver 192.168.1.10 --remoteport 25 --plain

{C.CYAN}Troubleshooting:{C.END}
  {C.YELLOW}WRONG_VERSION_NUMBER:{C.END}   You used --fullssl on a port that expects --plain/--starttls.
  {C.YELLOW}Unexpectedly closed:{C.END}    You used --plain on a port that requires --fullssl (Implicit SSL).
  {C.YELLOW}Error 530:{C.END}               The server requires encryption before accepting your command.
    """

    parser = argparse.ArgumentParser(
        description='PLC Email Protocol Navigator v4.1.6',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=epilog_msg
    )

    # Mode Selection
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--plain', action='store_true', help='Standard TCP connection (Port 25/587). No encryption.')
    mode.add_argument('--starttls', action='store_true', help='Standard TCP connection, then upgrade to TLS (Port 587).')
    mode.add_argument('--fullssl', action='store_true', help='Implicit SSL/TLS connection from the start (Port 465).')

    # Connection Parameters
    parser.add_argument('--remoteserver', required=True, help='Hostname or IP of the SMTP server.')
    parser.add_argument('--remoteport', type=int, required=True, help='Port number (usually 25, 465, or 587).')
    parser.add_argument('--ehlo-name', default='PLC_STATION_01', help='Identity string for EHLO command (Default: PLC_STATION_01).')
    
    # Auth Parameters
    parser.add_argument('--username', help='SMTP Authentication username (Email address).')
    parser.add_argument('--password', help='SMTP Authentication password or App Password.')
    parser.add_argument('--auth', help='Force a specific AUTH method (e.g., LOGIN, PLAIN).')
    parser.add_argument('--no-verify', action='store_true', help='Ignore SSL certificate verification errors (Self-signed certs).')

    # Email Content
    parser.add_argument('--from-addr', dest='sender', required=True, help='Address to appear in MAIL FROM.')
    parser.add_argument('--to-addr', dest='recipient', required=True, help='Recipient address for RCPT TO.')
    parser.add_argument('--subject', default='PLC_STATION_01 Alarm', help='Subject line of the email.')
    parser.add_argument('--body', default="PLC_STATION_01 email body", help='Content of the email message.')

    args = parser.parse_args()
    email_body = sys.stdin.read() if not sys.stdin.isatty() else args.body
    use_verification = not args.no_verify
    attempt = 0
    start_time = datetime.now()

    while attempt < 2:
        try:
            if args.fullssl:
                log_info(f"Connecting via SMTPS. Verification: {'ON' if use_verification else 'OFF'}")
                server = smtplib.SMTP_SSL(args.remoteserver, args.remoteport, context=get_ssl_context(use_verification), timeout=60)
                w = getattr(server, 'welcome', None)
                if w: log_srv(220, w)
            else:
                log_info(f"Connecting via TCP to {args.remoteserver}:{args.remoteport}")
                server = smtplib.SMTP(timeout=60)
                code, resp = server.connect(args.remoteserver, args.remoteport)
                log_srv(code, resp); check_code(code, resp)
                server._host = args.remoteserver

            log_plc(f"EHLO {args.ehlo_name}")
            code, resp = server.ehlo(args.ehlo_name); log_srv(code, server.ehlo_resp); check_code(code, server.ehlo_resp)

            if args.starttls and "starttls" in server.esmtp_features:
                log_plc("STARTTLS")
                try:
                    code, resp = server.starttls(context=get_ssl_context(use_verification))
                    log_srv(code, resp); check_code(code, resp)
                    log_info("STARTTLS successful.")
                except ssl.SSLError as e:
                    if use_verification:
                        print(f"{get_ts()} {C.RED}[!] SSL VERIFY FAILED: {e}{C.END}")
                        log_info("Retrying with --no-verify...")
                        use_verification = False; attempt += 1
                        server.close(); continue
                    else: raise e
                log_plc(f"EHLO {args.ehlo_name}")
                code, resp = server.ehlo(args.ehlo_name); log_srv(code, server.ehlo_resp); check_code(code, server.ehlo_resp)
            break 
        except Exception as e:
            if "SSL" in str(e) and use_verification:
                use_verification = False; attempt += 1
                continue
            print(f"\n{get_ts()} {C.RED}[!] Error: {e}{C.END}"); sys.exit(1)

    try:
        if args.username and args.password:
            raw_lines = server.ehlo_resp.decode().splitlines()
            literal_auth_options = [match.group(1).strip() for line in raw_lines for match in [re.search(r'(AUTH.*)', line, re.I)] if match]
            
            selected_literal = None
            if args.auth:
                for opt in literal_auth_options:
                    if args.auth.upper() in opt.upper(): selected_literal = opt; break
            
            if not selected_literal and literal_auth_options:
                log_info("Auto-selecting best method...")
                for p_method in ['LOGIN', 'PLAIN']:
                    for opt in literal_auth_options:
                        if p_method in opt.upper(): selected_literal = opt; break
                    if selected_literal: break

            if selected_literal:
                log_info(f"Method: {selected_literal}")
                perform_auth(server, args, selected_literal)

        log_plc(f"MAIL FROM:<{args.sender}>")
        code, resp = server.mail(args.sender); log_srv(code, resp); check_code(code, resp)
        
        log_plc(f"RCPT TO:<{args.recipient}>")
        code, resp = server.rcpt(args.recipient); log_srv(code, resp); check_code(code, resp)
        
        log_info("Preparing DATA transaction...")
        msg = f"From: {args.sender}\r\nTo: {args.recipient}\r\nSubject: {args.subject}\r\n\r\n{email_body}"
        
        log_plc("DATA")
        for line in msg.splitlines(): log_plc(line)
        log_plc(".") 
        
        code, resp = server.data(msg)
        log_srv(code, resp); check_code(code, resp)
        
        log_plc("QUIT"); server.quit()
        
        duration = (datetime.now() - start_time).total_seconds()
        print(f"\n{C.WHITE}{'='*45}{C.END}")
        print(f"{C.GREEN}[+] Transaction Complete in {duration:.2f}s{C.END}")
        print(f"{C.CYAN}[i] Total Sent: {stats.sent} bytes{C.END}")
        print(f"{C.CYAN}[i] Total Recv: {stats.recv} bytes{C.END}")
        print(f"{C.WHITE}{'='*45}{C.END}")

    except Exception as e:
        if not isinstance(e, SystemExit):
            print(f"\n{get_ts()} {C.RED}[!] Protocol Error: {e}{C.END}"); sys.exit(1)

if __name__ == "__main__":
    mimic_plc()
