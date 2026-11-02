#!/var/jb/usr/bin/python3
"""Local, read-only troubleshooting dashboard for iOS Hotspot Keepalive."""
from http.server import BaseHTTPRequestHandler, HTTPServer
from html import escape
from pathlib import Path
import subprocess
LOG = Path("/var/jb/var/log")
def tail(name):
    try: return escape("\n".join((LOG / name).read_text(errors="replace").splitlines()[-35:]))
    except Exception as err: return escape(str(err))
class View(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/", "/status"):
            self.send_error(404); return
        try:
            result = subprocess.run(["/var/jb/usr/local/bin/misctl", "status"], capture_output=True, text=True, timeout=3)
            status = escape((result.stdout + result.stderr).strip())
        except Exception as err: status = escape(str(err))
        page = """<!doctype html><html lang="tr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Hotspot Keepalive</title><style>body{font-family:-apple-system,sans-serif;background:#101725;color:#f4f6ff;max-width:740px;margin:auto;padding:20px}pre{background:#1c2a42;padding:14px;border-radius:12px;white-space:pre-wrap;overflow-wrap:anywhere;font-size:12px}a{color:#96cfff}small{color:#b1bed0}</style><h2>Hotspot Keepalive v0.2</h2><small>Yalnızca bu iPhone üzerinde: http://127.0.0.1:8765</small><p>Çalışan bağlantı koruma ayarları değiştirilmez.</p><h3>Hotspot durumu</h3><pre>""" + status + """</pre><h3>Güç yönetimi</h3><pre>""" + tail("keepawake.log") + """</pre><h3>Bağlı istemciler</h3><pre>""" + tail("hshold.log") + """</pre><p>Proxy kodu mevcuttur ancak varsayılan olarak kapalıdır. VPN yönlendirmesi güvenlik nedeniyle pakete eklenmemiştir.</p><a href="/">Yenile</a></html>"""
        data=page.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type","text/html; charset=utf-8")
        self.send_header("Content-Length",str(len(data)))
        self.end_headers()
        self.wfile.write(data)
HTTPServer(("127.0.0.1",8765), View).serve_forever()
