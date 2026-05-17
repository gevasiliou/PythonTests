from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.request

# Ensure this matches your Titan --httpexpose port
# this version supports GET bu also supports POST by browser forms.
TARGET = "http://127.0.0.1:9999"

class P(BaseHTTPRequestHandler):
    def proxy_request(self, method):
        try:
            url = TARGET + self.path
            
            # 1. Read data if it's a POST request
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length) if method == "POST" else None
            
            # 2. Prepare the request to Titan
            req = urllib.request.Request(url, data=post_data, method=method)
            
            # 3. Copy headers from your browser to Titan
            for k, v in self.headers.items():
                if k.lower() not in ['host', 'content-length']:
                    req.add_header(k, v)

            # 4. Execute and get response
            with urllib.request.urlopen(req) as r:
                self.send_response(r.status)
                for k, v in r.getheaders():
                    self.send_header(k, v)
                self.end_headers()
                self.wfile.write(r.read())

        except Exception as e:
            self.send_error(502, f"Proxy Error: {str(e)}")

    def do_GET(self):
        self.proxy_request("GET")

    def do_POST(self):
        self.proxy_request("POST")

print(f"[*] HTTP Reverse Proxy active on port 8100 -> {TARGET}")
HTTPServer(("0.0.0.0", 8100), P).serve_forever()
