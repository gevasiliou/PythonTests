import socket, ssl, argparse, pam, base64, os, smtplib, subprocess, sys, pwd, grp, datetime, logging, re
from email.message import EmailMessage
from email import message_from_string

# --- LOGGING SETUP ---
LOG_FILE = "smtp_proxy.log"
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler(sys.stdout)]
)

def log_server(msg): 
    # Print server responses in blue for the terminal, but log them normally
    print(f"\033[94mSERVER: {msg.strip()}\033[0m")

# --- UTILS ---
def generate_self_signed_cert():
    if not os.path.exists("cert.pem"):
        logging.info("Generating self-signed certificate for TLS...")
        cmd = ["openssl", "req", "-x509", "-newkey", "rsa:4096", "-keyout", "key.pem",
               "-out", "cert.pem", "-days", "365", "-nodes", "-subj", "/C=GR/O=Samba/CN=localhost"]
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def user_exists(username):
    try:
        pwd.getpwnam(username)
        return True
    except KeyError:
        return False

def deliver_local(username, raw_content):
    """Appends email to /var/mail and handles ownership so the user can read it."""
    try:
        mailbox_path = f"/var/mail/{username}"
        user_info = pwd.getpwnam(username)
        target_uid = user_info.pw_uid
        
        # Determine standard 'mail' group GID
        try:
            target_gid = grp.getgrnam("mail").gr_gid
        except KeyError:
            target_gid = user_info.pw_gid

        timestamp = datetime.datetime.now().strftime("%a %b %d %H:%M:%S %Y")
        mbox_header = f"From PLC-Proxy {timestamp}\n"
        
        # Append to mailbox
        with open(mailbox_path, "a", encoding="utf-8") as mbox:
            mbox.write(mbox_header + raw_content + "\n\n")
        
        # Set ownership so 'gv' can read it via 'mail' command
        os.chown(mailbox_path, target_uid, target_gid)
        os.chmod(mailbox_path, 0o600)
        
        logging.info(f"Local delivery successful to {mailbox_path} (Owner: {username})")
    except Exception as e:
        logging.error(f"Local delivery/chown failed for {username}: {e}")

def relay_to_remote(raw_content, args):
    logging.info(f"Attempting relay via {args.remote_host}...")
    try:
        orig = message_from_string(raw_content)
        new_msg = EmailMessage()
        new_msg.set_content(orig.get_payload())
        new_msg['Subject'] = orig['Subject'] or "PLC Alert"
        new_msg['From'] = args.remote_user
        new_msg['To'] = args.to or orig['To'] or args.remote_user

        context = ssl.create_default_context()
        if args.remote_full_ssl:
            with smtplib.SMTP_SSL(args.remote_host, args.remote_port, context=context) as srv:
                srv.login(args.remote_user, args.remote_password)
                srv.send_message(new_msg)
        else:
            with smtplib.SMTP(args.remote_host, args.remote_port) as srv:
                if args.remote_starttls: srv.starttls(context=context)
                if args.remote_user: srv.login(args.remote_user, args.remote_password)
                srv.send_message(new_msg)
        logging.info("Remote relay successful.")
    except Exception as e:
        logging.error(f"Relay failed: {e}")

# --- SERVER ENGINE ---
def start_proxy(args):
    generate_self_signed_cert()
    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_sock.bind(('0.0.0.0', args.port))
    server_sock.listen(5)
    logging.info(f"Proxy active on port {args.port} | Mode: {'STRICT' if args.strict else 'FLEX'}")

    while True:
        client_conn, addr = server_sock.accept()
        is_encrypted = False
        session_context = {"local_user": None}
        
        # Port 465 logic
        if args.port == 465:
            try:
                ssl_ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
                ssl_ctx.load_cert_chain("cert.pem", "key.pem")
                client_conn = ssl_ctx.wrap_socket(client_conn, server_side=True)
                is_encrypted = True
            except Exception as e:
                logging.error(f"Implicit SSL error: {e}"); client_conn.close(); continue

        with client_conn:
            client_conn.sendall(b"220 samba-proxy ESMTP Ready\r\n")
            while True:
                try:
                    data = client_conn.recv(4096)
                    if not data: break
                    line = data.decode(errors='replace').strip()
                    cmd = line.upper()

                    if cmd.startswith("EHLO") or cmd.startswith("HELO"):
                        features = ["250-samba-proxy", "250-SIZE 40960000"]
                        if args.port == 587 and not is_encrypted: features.append("250-STARTTLS")
                        if not args.strict or is_encrypted: features.append("250-AUTH LOGIN")
                        resp = "\r\n".join(features) + "\r\n"
                        client_conn.sendall(resp.encode()); log_server(resp)

                    elif cmd == "STARTTLS" and args.port == 587:
                        client_conn.sendall(b"220 Ready to start TLS\r\n")
                        ssl_ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
                        ssl_ctx.load_cert_chain("cert.pem", "key.pem")
                        client_conn = ssl_ctx.wrap_socket(client_conn, server_side=True)
                        is_encrypted = True; logging.info("STARTTLS successful.")

                    elif cmd == "AUTH LOGIN":
                        if args.strict and not is_encrypted:
                            client_conn.sendall(b"530 5.7.0 Must issue STARTTLS first\r\n"); continue
                        client_conn.sendall(b"334 VXNlcm5hbWU6\r\n")
                        user_b64 = client_conn.recv(1024).strip()
                        user = base64.b64decode(user_b64).decode()
                        client_conn.sendall(b"334 UGFzc3dvcmQ6\r\n")
                        pass_b64 = client_conn.recv(1024).strip()
                        pw = base64.b64decode(pass_b64).decode()
                        if pam.pam().authenticate(user, pw):
                            client_conn.sendall(b"235 2.7.0 Auth success\r\n"); logging.info(f"Auth success: {user}")
                        else:
                            client_conn.sendall(b"535 5.7.8 Auth failed\r\n"); logging.warning(f"Auth failed: {user}")

                    elif cmd.startswith("MAIL FROM:"):
                        client_conn.sendall(b"250 2.1.0 Ok\r\n")

                    elif cmd.startswith("RCPT TO:"):
                        # Capture local user if @localhost
                        match = re.search(r'<([^@>]+)@localhost>', line, re.I)
                        if match:
                            target = match.group(1)
                            if user_exists(target):
                                session_context["local_user"] = target
                                client_conn.sendall(b"250 2.1.5 Ok\r\n")
                            else:
                                client_conn.sendall(b"550 5.1.1 User unknown\r\n")
                                logging.warning(f"Unknown local user: {target}")
                        else:
                            client_conn.sendall(b"250 2.1.0 Ok\r\n")

                    elif cmd == "DATA":
                        client_conn.sendall(b"354 Send data\r\n")
                        buf = b""
                        while b"\r\n.\r\n" not in buf: buf += client_conn.recv(4096)
                        email_content = buf.decode(errors='replace')
                        
                        # Trigger local delivery first
                        if session_context["local_user"]:
                            deliver_local(session_context["local_user"], email_content)
                        
                        # Trigger relay if configured
                        if args.remote_host:
                            relay_to_remote(email_content, args)
                        
                        client_conn.sendall(b"250 2.0.0 Ok\r\n")

                    elif cmd == "QUIT":
                        client_conn.sendall(b"221 Bye\r\n"); break
                except Exception as e:
                    logging.error(f"Error: {e}"); break

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Professional Hybrid SMTP Proxy")
    parser.add_argument("--port", type=int, default=587, help="Listen port")
    parser.add_argument("--strict", action="store_true", help="RFC mode: hide AUTH until TLS")
    parser.add_argument("--remote-host", help="Upstream SMTP relay")
    parser.add_argument("--remote-port", type=int, default=587)
    parser.add_argument("--remote-user")
    parser.add_argument("--remote-password")
    parser.add_argument("--remote-starttls", action="store_true")
    parser.add_argument("--remote-full-ssl", action="store_true")
    parser.add_argument("--to", help="Redirect all relay mail to this address")
    
    args = parser.parse_args()
    try:
        start_proxy(args)
    except KeyboardInterrupt:
        logging.info("Server manually stopped.")
