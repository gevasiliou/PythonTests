#!/usr/bin/env python3
import smtplib
import ssl
import argparse
import base64
import sys
import hmac
import hashlib
from datetime import datetime

# ANSI Color Codes
class C:
    BLUE = '\033[94m'    # PLC Commands
    RED = '\033[91m'     # Server Responses
    GREEN = '\033[92m'   # Success
    YELLOW = '\033[93m'  # Warnings/Info
    WHITE = '\033[97m'   # Timestamps
    CYAN = '\033[96m'    # Decoded Info
    END = '\033[0m'      # Reset

def get_ts():
    """Generates a high-precision timestamp"""
    return f"{C.WHITE}[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}]{C.END}"

def log_plc(msg):
    """Logs outgoing PLC commands in Blue with Timestamp"""
    print(f"{get_ts()} {C.BLUE}[PLC ->] {msg}{C.END}")

def log_decode(b64_str):
    """Decodes a b64 string and logs it in Cyan for verification"""
    try:
        decoded = base64.b64decode(b64_str).decode('utf-8', errors='replace')
        # Replace null bytes with visual markers for PLAIN auth troubleshooting
        decoded = decoded.replace('\x00', '[NULL]')
        print(f"{get_ts()} {C.CYAN}[DECODED] {decoded}{C.END}")
    except Exception:
        print(f"{get_ts()} {C.CYAN}[DECODED] (Could not decode as UTF-8){C.END}")

def log_srv(code, msg):
    """Logs incoming Server responses in Red with Timestamp"""
    if isinstance(msg, bytes):
        msg = msg.decode('utf-8', errors='ignore').strip()
    
    lines = str(msg).splitlines()
    for i, line in enumerate(lines):
        sep = "-" if i < len(lines) - 1 else " "
        print(f"{get_ts()} {C.RED}[SRV <-] {code}{sep}{line}{C.END}")

def mimic_plc():
    custom_epilog = f"""
{C.YELLOW}DEBUGGING NOTES:{C.END}
  * {C.CYAN}[DECODED]{C.END} lines show the raw text inside Base64 packets.
  * In {C.BLUE}AUTH PLAIN{C.END}, {C.CYAN}[NULL]{C.END} represents the required zero-byte separators.
  * Timestamps help identify if a server is lagging or dropping the connection.
  * Usage examples: python3 plc-email-emulator.py --remoteserver mail.datakom.com.tr --remoteport 587 --from-addr somebody@domain.com --to-addr somebody@domain.gr --plain --auth CRAM-MD5 --username D500 --password pass

  * Alternatives:
  www
  www
  www
    """

    parser = argparse.ArgumentParser(
        description='PLC Email Sender Mimic - Full Transparency v1.8',
        epilog=custom_epilog,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--plain', action='store_true', help="connect in plain text")
    group.add_argument('--starttls', action='store_true', help="connect with starttls if server supports this")
    group.add_argument('--fullssl', action='store_true', help="connect with full ssl from the beginning")

    parser.add_argument('--remoteserver', required=True)
    parser.add_argument('--remoteport', type=int, required=True)
    parser.add_argument('--ehlo-name', default='PLC_STATION_01')
    parser.add_argument('--timeout', type=int, default=60)
    parser.add_argument('--username')
    parser.add_argument('--password')
    parser.add_argument('--auth', choices=['LOGIN', 'PLAIN', 'CRAM-MD5'])
    parser.add_argument('--no-verify', action='store_true')
    parser.add_argument('--from-addr', dest='sender', required=True)
    parser.add_argument('--to-addr', dest='recipient', required=True)
    parser.add_argument('--subject', default='PLC_STATION_01 Alarm')
    parser.add_argument('--body', default="PLC_STATION_01 email body with PLC errors")

    args = parser.parse_args()
    email_body = sys.stdin.read() if not sys.stdin.isatty() else (args.body or "PLC Test Message")

    start_time = datetime.now()
    context = ssl.create_default_context()
    if args.no_verify:
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE

    try:
        # 1. INITIAL CONNECTION
        if args.fullssl:
            print(f"{get_ts()} {C.YELLOW}[*] Connecting via SMTPS (Implicit SSL)...{C.END}")
            server = smtplib.SMTP_SSL(args.remoteserver, args.remoteport, context=context, timeout=args.timeout)
            log_srv(220, server.welcome)
        else:
            print(f"{get_ts()} {C.YELLOW}[*] Connecting via Plain TCP...{C.END}")
            server = smtplib.SMTP(timeout=args.timeout)
            code, resp = server.connect(args.remoteserver, args.remoteport)
            log_srv(code, resp)
            server._host = args.remoteserver

        server.set_debuglevel(0)

        # 2. EHLO
        log_plc(f"EHLO {args.ehlo_name}")
        code, resp = server.ehlo(args.ehlo_name)
        log_srv(code, resp)

        # 3. STARTTLS
        if args.starttls:
            if "starttls" in server.esmtp_features:
                log_plc("STARTTLS")
                code, resp = server.starttls(context=context)
                log_srv(code, resp)
                log_plc(f"EHLO {args.ehlo_name} (Post-TLS)")
                code, resp = server.ehlo(args.ehlo_name)
                log_srv(code, resp)
            else:
                print(f"{get_ts()} {C.YELLOW}[!] WARNING: STARTTLS not offered. Proceeding in PLAIN.{C.END}")

        # 4. AUTHENTICATION (UNMASKED + DECODED)
        if args.username and args.password:
            supported_raw = server.esmtp_features.get('auth', '').upper()
            supported_methods = [m.split('=')[-1] for m in supported_raw.split()]
            chosen_auth = args.auth.upper() if args.auth else None

            if chosen_auth and chosen_auth not in supported_methods:
                print(f"{get_ts()} {C.YELLOW}[!] WARNING: {chosen_auth} not supported.{C.END}")
                if supported_methods:
                    chosen_auth = supported_methods[0]
                    print(f"{get_ts()} {C.YELLOW}[*] Falling back to: {chosen_auth}{C.END}")
                else:
                    print(f"{get_ts()} {C.RED}[!] ERROR: No auth methods available.{C.END}")
                    sys.exit(1)
            
            if not chosen_auth:
                for best in ['CRAM-MD5', 'LOGIN', 'PLAIN']:
                    if best in supported_methods:
                        chosen_auth = best
                        break

            if chosen_auth == 'LOGIN':
                u_b64 = base64.b64encode(args.username.encode()).decode()
                p_b64 = base64.b64encode(args.password.encode()).decode()
                log_plc("AUTH LOGIN")
                code, resp = server.docmd("AUTH LOGIN")
                log_srv(code, resp)
                if code == 334:
                    log_plc(u_b64)
                    log_decode(u_b64)
                    code, resp = server.docmd(u_b64)
                    log_srv(code, resp)
                if code == 334:
                    log_plc(p_b64)
                    log_decode(p_b64)
                    code, resp = server.docmd(p_b64)
                    log_srv(code, resp)

            elif chosen_auth == 'PLAIN':
                auth_str = f"\0{args.username}\0{args.password}"
                auth_b64 = base64.b64encode(auth_str.encode()).decode()
                log_plc(f"AUTH PLAIN {auth_b64}")
                log_decode(auth_b64)
                code, resp = server.docmd("AUTH PLAIN", auth_b64)
                log_srv(code, resp)

            elif chosen_auth == 'CRAM-MD5':
                log_plc("AUTH CRAM-MD5")
                code, chall_b64 = server.docmd("AUTH", "CRAM-MD5")
                log_srv(code, chall_b64)
                if code == 334:
                    chall = base64.b64decode(chall_b64)
                    hashed = hmac.new(args.password.encode(), chall, hashlib.md5).hexdigest()
                    resp_b64 = base64.b64encode(f"{args.username} {hashed}".encode()).decode()
                    log_plc(resp_b64)
                    log_decode(resp_b64)
                    code, resp = server.docmd(resp_b64)
                    log_srv(code, resp)

        # 5. MAIL
        log_plc(f"MAIL FROM:<{args.sender}>")
        code, resp = server.mail(args.sender)
        log_srv(code, resp)
        log_plc(f"RCPT TO:<{args.recipient}>")
        code, resp = server.rcpt(args.recipient)
        log_srv(code, resp)
        log_plc("DATA")
        msg = f"From: {args.sender}\r\nTo: {args.recipient}\r\nSubject: {args.subject}\r\n\r\n{email_body}"
        code, resp = server.data(msg)
        log_srv(code, resp)

        # 6. QUIT
        log_plc("QUIT")
        code, resp = server.quit()
        log_srv(code, resp)
        
        duration = datetime.now() - start_time
        print(f"{get_ts()} {C.GREEN}[+] Email Sent! Total Time: {duration.total_seconds():.2f}s{C.END}")

    except Exception as e:
        print(f"\n{get_ts()} {C.RED}[!] Error: {e}{C.END}")
        sys.exit(1)

if __name__ == "__main__":
    mimic_plc()
