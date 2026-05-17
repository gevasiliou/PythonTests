from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.request

TARGET = "http://127.0.0.1:9999"
#this is a reverse proxy - listens on your vps IP port 8100 and whatever is passed after / is transfered locally 
#to http://127.0.0.1:9999 - is another way to achieve http monitor (GET) over your Titan proxy trough web.
#this version does not support POST requests - For POST check reverse-proxy-v2 

class P(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            r = urllib.request.urlopen(TARGET + self.path)
            body = r.read()
            self.send_response(r.status)
            for k, v in r.getheaders(): self.send_header(k, v)
            self.end_headers()
            self.wfile.write(body)
        except Exception as e:
            self.send_error(502, str(e))

HTTPServer(("0.0.0.0", 8100), P).serve_forever()
