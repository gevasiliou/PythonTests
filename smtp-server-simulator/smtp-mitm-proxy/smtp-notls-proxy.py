import socket
import select
import sys

# --- CONFIGURATION ---
LOCAL_IP = '192.168.2.11'
LOCAL_PORT = 587
REMOTE_HOST = 'mail.datakom.com.tr'
REMOTE_PORT = 587
BUFFER_SIZE = 4096

def start_bridge():
    # Setup the local listener
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind((LOCAL_IP, LOCAL_PORT))
    except PermissionError:
        print(f"[!] Error: You need sudo/admin rights to bind to port {LOCAL_PORT}")
        return
    except Exception as e:
        print(f"[!] Bind Error: {e}")
        return

    server.listen(1)
    print(f"[*] Proxy Active on {LOCAL_IP}:{LOCAL_PORT}")
    print(f"[*] Forwarding to {REMOTE_HOST}:{REMOTE_PORT}")
    print("[*] Waiting for PLC to connect...\n")

    while True:
        plc_sock, addr = server.accept()
        print(f"\n[+] PLC CONNECTED: {addr[0]}")
        
        try:
            # Connect to Datakom immediately upon PLC connection
            remote_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            remote_sock.connect((REMOTE_HOST, REMOTE_PORT))
            print("[+] DATAKOM CONNECTED")

            sockets = [plc_sock, remote_sock]
            
            while True:
                # Watch both sides for data
                readable, _, _ = select.select(sockets, [], [], 1.0)
                
                for s in readable:
                    data = s.recv(BUFFER_SIZE)
                    if not data:
                        raise Exception("Connection closed by peer")

                    if s is plc_sock:
                        # Print what the PLC said
                        msg = data.decode(errors='replace').strip()
                        print(f"PLC -> [PROXY] -> DATAKOM: {msg}")
                        remote_sock.sendall(data)
                    else:
                        # Print what Datakom replied
                        msg = data.decode(errors='replace').strip()
                        print(f"DATAKOM -> [PROXY] -> PLC: {msg}")
                        plc_sock.sendall(data)
                        
        except Exception as e:
            print(f"[-] Connection Terminated: {e}")
        finally:
            plc_sock.close()
            remote_sock.close()
            print("[*] Ready for next connection...")

if __name__ == "__main__":
    try:
        start_bridge()
    except KeyboardInterrupt:
        print("\n[!] Shutting down.")
