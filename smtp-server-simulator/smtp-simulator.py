import socket
import datetime
import os
import ssl
import base64
import argparse
import sys

# --- CONFIGURATION ---
CERT_FILE = "cert.pem"
KEY_FILE = "key.pem"
TIMEOUT = 60.0

# SMTP Responses
R_BANNER = "220 samba-unified-sim ok\r\n"
R_EHLO_NO_TLS = "250-samba\r\n250-AUTH LOGIN\r\n250 SIZE 40960000\r\n"
R_EHLO_STARTTLS = "250-samba\r\n250-AUTH LOGIN\r\n250-SIZE 40960000\r\n250 STARTTLS\r\n"
R_STARTTLS_READY = "220 2.0.0 Ready to start TLS\r\n"
R_AUTH_USER = "334 VXNlcm5hbWU6\r\n"
R_AUTH_PASS = "334 UGFzc3dvcmQ6\r\n"
R_AUTH_OK = "235 Authenticated\r\n"
R_OK = "250 ok\r\n"
R_DATA_START = "354 End data with <CR><LF>.<CR><LF>\r\n"
R_QUEUED = "250 2.0.0 Ok: queued\r\n"

def send_log(conn, msg):
    print(f"\033[94mSERVER: {msg.strip()}\033[0m")
    conn.sendall(msg.encode())

def handle_client(conn, addr, mode):
    print(f"\n{'='*50}\n[*] New connection: {addr} | Mode: {mode.upper()}")
    
    context = None
    if mode in ['starttls', 'fullssl']:
        context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        try:
            context.load_cert_chain(certfile=CERT_FILE, keyfile=KEY_FILE)
        except FileNotFoundError:
            print(f"\033[91m[!] Error: SSL files missing. Run OpenSSL command in --help.\033[0m")
            conn.close()
            return

    current_conn = conn
    current_conn.settimeout(TIMEOUT)

    try:
        # Initial SSL wrap for FULLSSL mode
        if mode == 'fullssl':
            current_conn = context.wrap_socket(conn, server_side=True)
            print("\033[92m[+] SSL Encrypted (Implicit)\033[0m")

        send_log(current_conn, R_BANNER)

        while True:
            data = current_conn.recv(4096)
            if not data: break
            
            raw_cmd = data.decode(errors='replace').strip()
            cmd = raw_cmd.upper()
            
            # Print every client message for visibility
            print(f"CLIENT: {raw_cmd}")

            if cmd.startswith(("EHLO", "HELO")):
                resp = R_EHLO_STARTTLS if mode == 'starttls' else R_EHLO_NO_TLS
                send_log(current_conn, resp)
            
            elif cmd.startswith("STARTTLS") and mode == 'starttls':
                send_log(current_conn, R_STARTTLS_READY)
                # Upgrade plaintext connection to SSL
                current_conn = context.wrap_socket(current_conn, server_side=True)
                print("\033[92m[+] STARTTLS Upgrade Successful\033[0m")
            
            elif cmd.startswith("AUTH LOGIN"):
                # Handle Username challenge
                send_log(current_conn, R_AUTH_USER)
                u_b64 = current_conn.recv(1024).decode().strip()
                print(f"CLIENT: {u_b64}")
                try:
                    u_dec = base64.b64decode(u_b64).decode(errors='replace')
                    print(f"\033[93mDEBUG: Decoded Username: {u_dec}\033[0m")
                except:
                    print("\033[91m[!] Failed to decode Username\033[0m")
                
                # Handle Password challenge
                send_log(current_conn, R_AUTH_PASS)
                p_b64 = current_conn.recv(1024).decode().strip()
                print(f"CLIENT: {p_b64}")
                try:
                    p_dec = base64.b64decode(p_b64).decode(errors='replace')
                    print(f"\033[93mDEBUG: Decoded Password: {p_dec}\033[0m")
                except:
                    print("\033[91m[!] Failed to decode Password\033[0m")
                
                send_log(current_conn, R_AUTH_OK)
            
            elif cmd.startswith(("MAIL FROM", "RCPT TO", "NOOP")):
                send_log(current_conn, R_OK)
            
            elif cmd.startswith("DATA"):
                send_log(current_conn, R_DATA_START)
                email_body = b""
                while b"\r\n.\r\n" not in email_body:
                    chunk = current_conn.recv(4096)
                    if not chunk: break
                    email_body += chunk
                
                # Print the received email content to terminal
                print("\n\033[36m" + "-"*25 + " EMAIL CONTENT START " + "-"*25)
                print(email_body.decode(errors='replace'))
                print("-" * 25 + " EMAIL CONTENT END " + "-" * 25 + "\033[0m\n")
                
                send_log(current_conn, R_QUEUED)
            
            elif cmd.startswith("QUIT"):
                send_log(current_conn, "221 Bye\r\n")
                break
            else:
                if raw_cmd: # Avoid logging empty heartbeats
                    send_log(current_conn, "500 Command unrecognized\r\n")

    except Exception as e:
        print(f"\033[91m[!] Session Error: {e}\033[0m")
    finally:
        current_conn.close()

def main():
    help_description = (
        "SSL SETUP:\n"
        "Generate certs for --starttls or --fullssl:\n"
        "  openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes\n\n"
        "TEST YOUR SMTP SIMULATOR SERVER WITH BELLOW COMMANDS FROM ANOTHER TERMINAL:\n"
        "  \033[95m[--nossl mode]\033[0m\n"
        "  1.  echo -e \"From: test@lan\\nTo: you@lan\\nSubject: test\\n\\nbody\" | curl --url \"smtp://127.0.0.1:587\" --mail-from \"test@lan\" --mail-rcpt \"you@lan\" --upload-file - --user \"user:password\" --insecure --trace-ascii - \n"
        "  2.  swaks --server 127.0.0.1 --port 587 --to test@domain.com --from sender@domain.com --auth LOGIN --auth-user \"user\" --auth-password \"yourpassword\" \n"
        "  3.  telnet 127.0.0.1 587 / With telnet you have to provide manually (by hand) the commands ehlo, mail from, rcpt to , data. \n"
        "  Tip: You can also run a manual dummy smtp server with netcat: sudo ncat -v -l -p 587 -C /obviously you have to provide all server commands by hand like 220 welcome, 250-AUTH LOGIN, etc\n\n"
        "  \033[95m[--starttls mode]\033[0m\n"
        "  1.  echo -e \"From: test@lan\\nTo: you@lan\\nSubject: test\\n\\nbody\" | curl --url \"smtp://127.0.0.1:587\" --ssl-reqd --mail-from \"test@lan\" --mail-rcpt \"you@lan\" --upload-file - --user \"user:password\" --insecure --trace-ascii - \n"
        "  2.  swaks --server 127.0.0.1 --port 587 --to test@domain.com --from sender@domain.com --tls --auth LOGIN --auth-user \"user\" --auth-password \"yourpassword\" \n"
        "  Tip1: ncat can not be used here since ncat can not switch to ssl in the middle as starttls requires\n"
        "  Tip2: for compatibility to old plcs/IoT devices in this mode smtp server simulator will offer STARTTLS and AUTH LOGIN just after client ehlo \n"
        "        This is not typical behavior for STARTTLS servers. In typical STARTTLS servers, AUTH LOGIN is provided only after succesfull TLS upgrade (STARTTLS)\n"
        "        This script will proceed to AUTH LOGIN if client skips STARTTLS\n\n"
        "  \033[95m[--fullssl mode]\033[0m\n"
        "  1.  echo -e \"From: somebody@example.gr\\nTo: someone@example.gr\\nSubject: Test Email\\n\\nThis is the body\" | curl --verbose --url \"smtps://127.0.0.1:465\" --mail-from \"somebody@example.gr\" --mail-rcpt \"someone@example.gr\" --user \"someuser:somepassword\" --upload-file - --insecure \n"
        "  2.  swaks --to someone@localhost --from gv@localhost --server 127.0.0.1:465 --tls-on-connect --auth LOGIN --auth-user \"gv\" --auth-password \"whatever\" \n"
        "  Tip: You can also run a manual dummy mail server with netcat including full ssl: sudo ncat -v -l -p 465 -C --ssl \n\n"
        """
        TYPICAL SERVER / CLIENT SMTP COMMANDS
		SERVER								CLIENT
		-------------------------------------------------------------------------------------------------------
		220 Welcome message & list of commands				ehlo (for ssl) or helo (no ssl)
		250-HELP							HELP
		211 Help:->Supported Commands: 					reply to HELP
		250-AUTH LOGIN							AUTH LOGIN
		250 STARTTLS							STARTTLS
		334 VXNlcm5hbWU6						username in base64 encoding
		334 UGFzc3dvcmQ6						password in base64 encoding
		235 Authenticated						MAIL FROM:<gv@localhost>
		250 OK								RCPT TO:<gv@localhost>
		250 OK								DATA
		354 Start mail input; end with <CRLF>.<CRLF>			email headers , subject, body ending with a single dot .
		250 Requested mail action Ok, queued				QUIT
		221 Closing Channel, Bye
        """
    )

    parser = argparse.ArgumentParser(
       # description=help_description,
       description="Multi-mode SMTP Server Simulator for PLC/Application Debugging.",
       epilog=help_description,
       formatter_class=argparse.RawTextHelpFormatter,
       usage="sudo python3 smtp-simulator.py --nossl | --starttls | --fullssl [-p PORT]"
    )
    
    def custom_error(message):
        print(f"\033[91m[!] ERROR: {message}\033[0m")
        print("\033[93m Usage Example: sudo python3 smtp-simulator.py --nossl | --starttls | --fullssl [-p PORT] \033[0m")
        print("\033[93m Run with --help to see full instructions. \033[0m")
        sys.exit(2)

    parser.error = custom_error
    
    parser.add_argument("-p", "--port", type=int, help="Port to listen on (port 587 is used by default for --nossl and --starttls / port 465 is used by default for --fullssl)")
    mode_group = parser.add_mutually_exclusive_group(required=True)
    mode_group.add_argument("--nossl", action="store_true", help="Plain text SMTP")
    mode_group.add_argument("--starttls", action="store_true", help="Explicit SSL (STARTTLS)")
    mode_group.add_argument("--fullssl", action="store_true", help="Implicit SSL (SMTPS / full ssl)")

    args = parser.parse_args()
    mode = 'nossl' if args.nossl else 'starttls' if args.starttls else 'fullssl'
    port = args.port or (465 if mode == 'fullssl' else 587)

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            s.bind(('0.0.0.0', port))
            s.listen(5)
            print(f"\033[95m[!] Running in {mode.upper()} mode on port {port}\033[0m")
            while True:
                client_sock, addr = s.accept()
                handle_client(client_sock, addr, mode)
        except Exception as e:
            print(f"\033[91m[!] Server Error: {e}\033[0m")

if __name__ == "__main__":
    main()
