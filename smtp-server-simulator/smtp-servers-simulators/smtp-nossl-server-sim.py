import socket
import datetime
import os
import base64

# --- CONFIGURATION ---
HOST = '0.0.0.0'
PORT = 587
SAVE_DIRECTORY = "./logs"

# SMTP Response Constants
R_BANNER = "220 samba ok\r\n"
R_EHLO = "250-AUTH LOGIN\r\n250-SIZE 40960000\r\n250-HELP\r\n250 STARTTLS\r\n"
R_AUTH_USER = "334 VXNlcm5hbWU6\r\n"
R_AUTH_PASS = "334 UGFzc3dvcmQ6\r\n"
R_AUTH_OK = "235 Authenticated\r\n"
R_OK = "250 ok\r\n"
R_DATA_START = "354 End data with <CR><LF>.<CR><LF>\r\n"
R_QUEUED = "250 2.0.0 Ok: queued\r\n"

def send_log(conn, msg):
    print(f"\033[94mSERVER: {msg.strip()}\033[0m") # Blue text for server
    conn.sendall(msg.encode())

def save_email(content):
    if not os.path.exists(SAVE_DIRECTORY): os.makedirs(SAVE_DIRECTORY)
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    path = f"{SAVE_DIRECTORY}/email_{ts}.html"
    with open(path, "w", encoding="utf-8") as f: f.write(content)
    print(f"\n[!] HTML saved to: {path}")

def run_simulator():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            s.bind((HOST, PORT))
        except OSError:
            print("Error: Maybe Port 587 is busy (Postfix running?) or you run this script without sudo")
            return
        
        s.listen(1)
        print(f"[*] Intelligent SMTP Simulator on {PORT}...")

        while True:
            conn, addr = s.accept()
            with conn:
                print(f"\n[*] Connection from {addr}")
                send_log(conn, R_BANNER)

                while True:
                    data = conn.recv(4096)
                    if not data: break
                    
                    raw_cmd = data.decode(errors='replace').strip()
                    cmd = raw_cmd.upper()
                    print(f"PLC: {raw_cmd}")

                    # --- LOGIC CONTROL ---
                    
                    if cmd.startswith("EHLO") or cmd.startswith("HELO"):
                        send_log(conn, R_EHLO)

                    elif cmd.startswith("AUTH LOGIN"):
                        # Only enter Auth sequence if PLC requested it
                        send_log(conn, R_AUTH_USER)
                        u_b64 = conn.recv(1024).decode().strip()
                        print(f"PLC (User): {u_b64}")
                        
                        send_log(conn, R_AUTH_PASS)
                        p_b64 = conn.recv(1024).decode().strip()
                        print(f"PLC (Pass): {p_b64}")
                        
                        send_log(conn, R_AUTH_OK)

                    elif cmd.startswith("MAIL FROM") or cmd.startswith("RCPT TO"):
                        send_log(conn, R_OK)

                    elif cmd.startswith("DATA"):
                        send_log(conn, R_DATA_START)
                        
                        # Capture until CRLF.CRLF
                        email_body = b""
                        while b"\r\n.\r\n" not in email_body:
                            chunk = conn.recv(4096)
                            if not chunk: break
                            email_body += chunk
                        
                        decoded = email_body.decode(errors='replace')
                        print("\n" + "="*15 + " EMAIL BODY " + "="*15)
                        print(decoded)
                        print("="*42 + "\n")
                        
                        if "<html>" in decoded.lower():
                            html = "<html>" + decoded.split("<html>")[-1].split("</html>")[0] + "</html>"
                            save_email(html)
                        
                        send_log(conn, R_QUEUED)

                    elif cmd.startswith("QUIT"):
                        send_log(conn, "221 Bye\r\n")
                        break
                    
                    else:
                        send_log(conn, "500 Command not recognized\r\n")

if __name__ == "__main__":
    try:
        run_simulator()
    except KeyboardInterrupt:
        print("\n[*] Stopped.")
