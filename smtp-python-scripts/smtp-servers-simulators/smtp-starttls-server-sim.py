import socket
import datetime
import os
import ssl
import base64

# --- CONFIGURATION ---
HOST = '0.0.0.0'
PORT = 587
SAVE_DIRECTORY = "./logs"
CERT_FILE = "cert.pem"
KEY_FILE = "key.pem"
TIMEOUT = 10.0  # Seconds to wait for client data

# SMTP Response Constants
R_BANNER = "220 samba ok\r\n"
R_EHLO = "250-samba\r\n250-AUTH LOGIN\r\n250-SIZE 40960000\r\n250-HELP\r\n250 STARTTLS\r\n"
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

def save_email(content):
    if not os.path.exists(SAVE_DIRECTORY): os.makedirs(SAVE_DIRECTORY)
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    path = f"{SAVE_DIRECTORY}/email_{ts}.html"
    with open(path, "w", encoding="utf-8") as f: f.write(content)
    print(f"\n[!] HTML saved to: {path}")

def handle_client(conn, addr):
    # Setup SSL Context
    context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    context.load_cert_chain(certfile=CERT_FILE, keyfile=KEY_FILE)
    
    conn.settimeout(TIMEOUT)
    print(f"\n[*] Connection from {addr}")
    
    try:
        send_log(conn, R_BANNER)
        current_conn = conn 

        while True:
            try:
                data = current_conn.recv(4096)
                if not data: break
                
                raw_cmd = data.decode(errors='replace').strip()
                cmd = raw_cmd.upper()
                print(f"CLIENT: {raw_cmd}")

                if cmd.startswith("EHLO") or cmd.startswith("HELO"):
                    send_log(current_conn, R_EHLO)

                elif cmd.startswith("NOOP"):
                    send_log(current_conn, "250 OK\r\n")

                elif cmd.startswith("STARTTLS"):
                    send_log(current_conn, R_STARTTLS_READY)
                    print("[*] Initiating SSL Handshake...")
                    # Wrap the socket and maintain timeout on the new SSLObject
                    current_conn = context.wrap_socket(current_conn, server_side=True)
                    current_conn.settimeout(TIMEOUT)
                    print("[*] Connection is now ENCRYPTED.")

                elif cmd.startswith("AUTH LOGIN"):
                    send_log(current_conn, R_AUTH_USER)
                    u_b64 = current_conn.recv(1024).decode().strip()
                    user = base64.b64decode(u_b64).decode(errors='ignore')
                    print(f"CLIENT (User): {u_b64} -> \033[92m{user}\033[0m")
                    
                    send_log(current_conn, R_AUTH_PASS)
                    p_b64 = current_conn.recv(1024).decode().strip()
                    pw = base64.b64decode(p_b64).decode(errors='ignore')
                    print(f"CLIENT (Pass): {p_b64} -> \033[92m{pw}\033[0m")
                    
                    send_log(current_conn, R_AUTH_OK)

                elif cmd.startswith("MAIL FROM") or cmd.startswith("RCPT TO"):
                    send_log(current_conn, R_OK)

                elif cmd.startswith("DATA"):
                    send_log(current_conn, R_DATA_START)
                    email_body = b""
                    while b"\r\n.\r\n" not in email_body:
                        chunk = current_conn.recv(4096)
                        if not chunk: break
                        email_body += chunk
                    
                    decoded = email_body.decode(errors='replace')
                    print("\n" + "="*15 + " EMAIL BODY " + "="*15)
                    print(decoded)
                    print("="*42 + "\n")
                    
                    if "<html>" in decoded.lower():
                        html = "<html>" + decoded.lower().split("<html>")[-1].split("</html>")[0] + "</html>"
                        save_email(html)
                    
                    send_log(current_conn, R_QUEUED)

                elif cmd.startswith("QUIT"):
                    send_log(current_conn, "221 Bye\r\n")
                    break
                else:
                    send_log(current_conn, "500 Command not recognized\r\n")
            
            except socket.timeout:
                print(f"[!] Connection timed out after {TIMEOUT}s. Closing.")
                break
            except ssl.SSLError as e:
                print(f"[!] SSL Error: {e}")
                break

    except Exception as e:
        print(f"[!] General Error: {e}")
    finally:
        conn.close()
        print(f"[*] Connection with {addr} closed.")

def run_simulator():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            s.bind((HOST, PORT))
        except OSError:
            print(f"Error: Port {PORT} is busy or requires sudo.")
            return
        
        s.listen(5)
        print(f"[*] Intelligent STARTTLS SMTP Simulator on {PORT} (Timeout: {TIMEOUT}s)...")

        while True:
            client_socket, addr = s.accept()
            handle_client(client_socket, addr)

if __name__ == "__main__":
    try:
        run_simulator()
    except KeyboardInterrupt:
        print("\n[*] Stopped.")
