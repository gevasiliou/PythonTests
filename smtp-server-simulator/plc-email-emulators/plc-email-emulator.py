#!/usr/bin/env python3
import smtplib
import ssl
import argparse
import base64
import sys
import hmac
import hashlib
import socket

def mimic_plc():
    parser = argparse.ArgumentParser(description='PLC Email Sender Mimic (Industrial SMTP Debugger)')
    
    # Connection Infrastructure
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--plain', action='store_true', help='Stay in plaintext throughout')
    group.add_argument('--starttls', action='store_true', help='Attempt STARTTLS if offered')
    group.add_argument('--fullssl', action='store_true', help='Connect via SMTPS (Implicit SSL)')

    # Network & Identity
    parser.add_argument('--remoteserver', required=True, help='SMTP Server IP/Hostname')
    parser.add_argument('--remoteport', type=int, required=True, help='SMTP Port')
    parser.add_argument('--ehlo-name', default='PLC_STATION_01', help='The name sent in EHLO banner')
    parser.add_argument('--timeout', type=int, default=10, help='Connection timeout in seconds')

    # Security (Certs)
    parser.add_argument('--cert', help='Path to client cert.pem')
    parser.add_argument('--key', help='Path to client key.pem')
    parser.add_argument('--no-verify', action='store_true', help='Skip SSL certificate verification')

    # Auth Info
    parser.add_argument('--username', help='Username for AUTH')
    parser.add_argument('--password', help='Password for AUTH')
    parser.add_argument('--auth', choices=['LOGIN', 'PLAIN', 'CRAM-MD5'], help='Force specific AUTH method')

    # Email Payload
    parser.add_argument('--from-addr', dest='sender', required=True, help='MAIL FROM address')
    parser.add_argument('--to-addr', dest='recipient', required=True, help='RCPT TO address')
    parser.add_argument('--subject', default='PLC Alarm Notification', help='Email Subject')
    parser.add_argument('--body', help='Email Body (if missing, reads from STDIN/Pipe)')

    args = parser.parse_args()

    # --- 1. PREPARE SSL CONTEXT ---
    context = ssl.create_default_context()
    if args.no_verify:
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
    if args.cert and args.key:
        context.load_cert_chain(certfile=args.cert, keyfile=args.key)

    # --- 2. PREPARE BODY ---
    if not sys.stdin.isatty():
        email_body = sys.stdin.read()
    else:
        email_body = args.body or "Automated PLC status update: All systems normal."

    try:
        # --- 3. INITIAL CONNECTION ---
        if args.fullssl:
            print(f"[*] Connecting via Full SSL to {args.remoteserver}:{args.remoteport}...")
            server = smtplib.SMTP_SSL(args.remoteserver, args.remoteport, context=context, timeout=args.timeout)
        else:
            print(f"[*] Connecting via Plain Socket to {args.remoteserver}:{args.remoteport}...")
            server = smtplib.SMTP(args.remoteserver, args.remoteport, timeout=args.timeout)

        server.set_debuglevel(1)  # Show raw SMTP traffic
        
        # Wait for initial 220
        server.ehlo(args.ehlo_name)

        # --- 4. STARTTLS LOGIC ---
        if args.starttls:
            if server.has_ext("STARTTLS"):
                print("[*] Server offers STARTTLS. Upgrading...")
                server.starttls(context=context)
                print("[*] SSL Wrap complete. Re-sending EHLO...")
                server.ehlo(args.ehlo_name)
            else:
                print("[!] STARTTLS requested but NOT offered by server. Proceeding in PLAIN.")

        # --- 5. AUTHENTICATION LOGIC ---
        if args.username and args.password:
            if args.auth == 'LOGIN':
                print("[*] Forcing AUTH LOGIN sequence...")
                u = base64.b64encode(args.username.encode()).decode()
                p = base64.b64encode(args.password.encode()).decode()
                code, resp = server.docmd("AUTH LOGIN")
                if code == 334: code, resp = server.docmd(u)
                if code == 334: code, resp = server.docmd(p)
                if code != 235: print(f"[!] Auth Failed: {code} {resp}"); sys.exit(1)

            elif args.auth == 'PLAIN':
                print("[*] Forcing AUTH PLAIN...")
                auth_str = f"\0{args.username}\0{args.password}"
                auth_b64 = base64.b64encode(auth_str.encode()).decode()
                code, resp = server.docmd("AUTH PLAIN", auth_b64)
                if code != 235: print(f"[!] Auth Failed: {code} {resp}"); sys.exit(1)

            elif args.auth == 'CRAM-MD5':
                print("[*] Forcing AUTH CRAM-MD5...")
                code, challenge_b64 = server.docmd("AUTH", "CRAM-MD5")
                if code == 334:
                    challenge = base64.b64decode(challenge_b64)
                    hashed = hmac.new(args.password.encode(), challenge, hashlib.md5).hexdigest()
                    response = base64.b64encode(f"{args.username} {hashed}".encode()).decode()
                    code, resp = server.docmd(response)
                if code != 235: print(f"[!] Auth Failed: {code} {resp}"); sys.exit(1)
            
            else:
                # Default smtplib smart-login
                server.login(args.username, args.password)

        # --- 6. MAIL TRANSACTION ---
        print("[*] Sending Mail Envelope...")
        server.mail(args.sender)
        server.rcpt(args.recipient)
        
        # Build Data Header
        full_msg = f"From: {args.sender}\r\nTo: {args.recipient}\r\nSubject: {args.subject}\r\n\r\n{email_body}"
        
        server.data(full_msg)
        print("[+] Message accepted for delivery.")

        server.quit()

    except Exception as e:
        print(f"\n[!] PLC Mimic Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    mimic_plc()
