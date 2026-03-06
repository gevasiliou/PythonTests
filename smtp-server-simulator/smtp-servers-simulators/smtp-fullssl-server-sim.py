import socket
import datetime
import os
import ssl
import base64

# --- CONFIGURATION ---
HOST = '0.0.0.0'
PORT = 465
SAVE_DIRECTORY = "./logs"
CERT_FILE = "cert.pem"
KEY_FILE = "key.pem"
TIMEOUT = 10.0

# --- FIXED SMTP RESPONSES ---
R_BANNER = "220 srv-ssl-debug ok\r\n"
# Note the last line uses a SPACE after 250, not a hyphen
R_EHLO = "250-samba\r\n250-AUTH LOGIN\r\n250 SIZE 40960000\r\n" 
R_AUTH_USER_REQ = "334 VXNlcm5hbWU6\r\n"
R_AUTH_PASS_REQ = "334 UGFzc3dvcmQ6\r\n"
R_AUTH_OK = "235 Authenticated\r\n"
R_OK = "250 ok\r\n"
R_DATA_START = "354 End data\r\n"
R_QUEUED = "250 2.0.0 Ok: queued\r\n"

def send_log(conn, msg):
    print(f"\033[94mSERVER: {msg.strip()}\033[0m")
    conn.sendall(msg.encode())

def handle_client(newsock, addr):
    print(f"\n{'-'*50}")
    print(f"[*] New Connection from {addr}")
    
    # Using a permissive context for PLCs
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    context.load_cert_chain(certfile=CERT_FILE, keyfile=KEY_FILE)
    
    try:
        print("[*] Attempting SSL Handshake...")
        conn = context.wrap_socket(newsock, server_side=True)
        conn.settimeout(TIMEOUT)
        print("\033[92m[+] SSL Handshake SUCCESSFUL!\033[0m")
        
        send_log(conn, R_BANNER)

        while True:
            data = conn.recv(4096)
            if not data: break
            
            raw_cmd = data.decode(errors='replace').strip()
            print(f"CLIENT: {raw_cmd}")

            cmd = raw_cmd.upper()
            if cmd.startswith(("EHLO", "HELO")):
                send_log(conn, R_EHLO)
            
            elif cmd.startswith("AUTH LOGIN"):
                send_log(conn, R_AUTH_USER_REQ)
                user_b64 = conn.recv(1024).decode().strip()
                print(f"DEBUG: User: {base64.b64decode(user_b64).decode(errors='ignore')}")
                
                send_log(conn, R_AUTH_PASS_REQ)
                pass_b64 = conn.recv(1024).decode().strip()
                print(f"DEBUG: Pass: {base64.b64decode(pass_b64).decode(errors='ignore')}")
                
                send_log(conn, R_AUTH_OK)
            
            elif cmd.startswith(("MAIL FROM", "RCPT TO", "NOOP")):
                send_log(conn, R_OK)
            
            elif cmd.startswith("DATA"):
                send_log(conn, R_DATA_START)
                body = b""
                while b"\r\n.\r\n" not in body:
                    chunk = conn.recv(4096)
                    if not chunk: break
                    body += chunk
                print(f"\033[93m[!] EMAIL RECEIVED\033[0m")
                send_log(conn, R_QUEUED)
            
            elif cmd.startswith("QUIT"):
                send_log(conn, "221 Bye\r\n")
                break
            else:
                send_log(conn, "500 Command unrecognized\r\n")

    except ssl.SSLError as e:
        print(f"\033[91m[!] SSL ERROR: {e}\033[0m")
    except Exception as e:
        print(f"[!] General Error: {e}")
    finally:
        newsock.close()
        print(f"[*] Connection closed.")

def run_simulator():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((HOST, PORT))
        s.listen(5)
        print(f"[*] Port 465 Implicit SSL Simulator (Fixed EHLO) Active...")
        while True:
            newsock, addr = s.accept()
            handle_client(newsock, addr)

if __name__ == "__main__":
    run_simulator()
