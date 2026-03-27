#!/usr/bin/env python3
import smtplib
import ssl
import argparse
import base64
import sys
import hmac
import hashlib
from datetime import datetime

class C:
    BLUE = '\033[94m'
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    WHITE = '\033[97m'
    CYAN = '\033[96m'
    END = '\033[0m'

class WireSpy:
    def __init__(self, original_send, show_hex=False):
        self.original_send = original_send
        self.show_hex = show_hex
        self.total_sent = 0

    def send(self, data):
        ts = "[" + datetime.now().strftime('%H:%M:%S.%f')[:-3] + "]"
        display_data = data.decode('utf-8', errors='replace').rstrip('\r\n')
        
        if display_data:
            print(C.WHITE + ts + C.END + " " + C.BLUE + "[PLC ->] " + display_data + C.END)
            if self.show_hex:
                hex_dump = " ".join(["%02x" % b for b in data])
                print(" " * 14 + C.YELLOW + "[HEX] " + hex_dump + C.END)
        
        self.total_sent += len(data)
        return self.original_send(data)

def get_ts():
    return C.WHITE + "[" + datetime.now().strftime('%H:%M:%S.%f')[:-3] + "]" + C.END

def log_info(msg):
    print(get_ts() + " " + C.GREEN + "[*] INFO: " + msg + C.END)

def log_decode(b64_str, label="DECODED"):
    try:
        if not b64_str: return
        decoded = base64.b64decode(b64_str).decode('utf-8', errors='replace')
        # Compatibility fix: Avoid backslashes in f-strings
        clean_msg = decoded.replace('\x00', '[NULL]')
        print(get_ts() + " " + C.CYAN + "[" + label + "] " + clean_msg + C.END)
    except: pass

def log_srv(code, msg):
    if isinstance(msg, bytes): 
        msg = msg.decode('utf-8', errors='ignore').strip()
    lines = str(msg).splitlines()
    for i, line in enumerate(lines):
        sep = "-" if i < len(lines) - 1 else " "
        print(get_ts() + " " + C.RED + "[SRV <-] " + str(code) + sep + line + C.END)
        if str(code) == "334":
            log_decode(line, label="SRV CHALLENGE")

def wrap_socket(server, show_hex):
    server.sock.send = WireSpy(server.sock.send, show_hex).send

def mimic_plc():
    parser = argparse.ArgumentParser(description='PLC Email Navigator v4.7')
    # Fixed Group Indentation and Syntax
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--plain', action='store_true')
    group.add_argument('--starttls', action='store_true')
    group.add_argument('--fullssl', action='store_true')
    
    parser.add_argument('--remoteserver', required=True)
    parser.add_argument('--remoteport', type=int, required=True)
    parser.add_argument('--ehlo-name', default='PLC_STATION_01')
    parser.add_argument('--username')
    parser.add_argument('--password')
    parser.add_argument('--from-addr', required=True)
    parser.add_argument('--to-addr', required=True)
    parser.add_argument('--subject', default='PLC Alarm')
    parser.add_argument('--body', default='PLC Test Body')
    parser.add_argument('--hex', action='store_true')
    parser.add_argument('--no-verify', action='store_true')

    args = parser.parse_args()
    ctx = ssl.create_default_context()
    if args.no_verify:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

    try:
        if args.fullssl:
            log_info("Connecting via SMTPS...")
            server = smtplib.SMTP_SSL(args.remoteserver, args.remoteport, context=ctx)
            wrap_socket(server, args.hex)
            log_srv(220, getattr(server, 'welcome', b"Connected"))
        else:
            log_info("Connecting via TCP to " + args.remoteserver + "...")
            server = smtplib.SMTP(timeout=60)
            code, resp = server.connect(args.remoteserver, args.remoteport)
            wrap_socket(server, args.hex)
            log_srv(code, resp)

        server.ehlo(args.ehlo_name)
        log_srv(250, server.ehlo_resp)

        if args.starttls and "starttls" in server.esmtp_features:
            server.starttls(context=ctx)
            log_info("STARTTLS successful.")
            wrap_socket(server, args.hex)
            server.ehlo(args.ehlo_name)
            log_srv(250, server.ehlo_resp)

        if args.username and args.password:
            log_info("Auth: LOGIN")
            code, resp = server.docmd("AUTH LOGIN"); log_srv(code, resp)
            if code == 334:
                u = base64.b64encode(args.username.encode()).decode()
                code, resp = server.docmd(u); log_srv(code, resp)
            if code == 334:
                p = base64.b64encode(args.password.encode()).decode()
                code, resp = server.docmd(p); log_srv(code, resp)

        code, resp = server.mail(args.from_addr); log_srv(code, resp)
        code, resp = server.rcpt(args.to_addr); log_srv(code, resp)
        
        log_info("Executing DATA transaction...")
        code, resp = server.docmd("DATA"); log_srv(code, resp)
        if code == 354:
            payload = "From: " + args.from_addr + "\r\nTo: " + args.to_addr + "\r\nSubject: " + args.subject + "\r\n\r\n" + args.body + "\r\n.\r\n"
            server.send(payload.encode('utf-8'))
            code, resp = server.getreply(); log_srv(code, resp)
        
        server.quit()
        print("\n" + C.GREEN + "[+] Complete. Total Bytes Sent: " + str(server.sock.send.__self__.total_sent) + C.END)

    except Exception as e:
        print("\n" + C.RED + "[!] Session Error: " + str(e) + C.END); sys.exit(1)

if __name__ == "__main__":
    mimic_plc()
