#!/usr/bin/env python3
"""BlueMaia: avaliações de clientes para bluemaia.ch (só biblioteca padrão do Python).

Público, atrás do Caddy e do Cloudflare Tunnel, só em 127.0.0.1:8093.
  GET  /api/bewertungen   -> avaliações APROVADAS (nunca as pendentes)
  POST /api/bewertungen   -> nova avaliação, fica PENDENTE
A aprovação NÃO existe aqui: faz-se na ferramenta privada BlueMaia Rechnungen (rede de casa / Tailscale).
"""
import json, os, re, sqlite3, threading, time, datetime
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

DB = os.environ.get("BM_REVIEWS_DB", "/srv/bluemaia-avaliacoes/data/avaliacoes.sqlite")
PORT = int(os.environ.get("BM_REVIEWS_PORT", "8093"))
HOST = "127.0.0.1"
LOCK = threading.Lock()
RATE = {}                 # IP -> [instantes]; só em memória, nunca gravado
MAX_PER_HOUR = 3
MAX_PENDING = 100         # trava contra inundação de spam
LANGS = ("pt", "de", "en", "es")


def db():
    os.makedirs(os.path.dirname(DB), exist_ok=True)
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    c.execute("PRAGMA journal_mode=WAL")
    c.execute("""CREATE TABLE IF NOT EXISTS reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT, created TEXT NOT NULL, name TEXT NOT NULL, ort TEXT,
        stars INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5), text TEXT NOT NULL, lang TEXT,
        status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
        decided TEXT)""")
    return c


def clean(s, n):
    s = re.sub(r"[\x00-\x08\x0b-\x1f\x7f]", "", str(s or ""))
    s = re.sub(r"[ \t]+", " ", s).strip()
    s = re.sub(r"\n{3,}", "\n\n", s)
    return s[:n]


def limited(ip):
    now = time.time()
    hits = [t for t in RATE.get(ip, []) if now - t < 3600]
    RATE[ip] = hits
    if len(RATE) > 5000:
        RATE.clear()
    if len(hits) >= MAX_PER_HOUR:
        return True
    hits.append(now)
    return False


class H(BaseHTTPRequestHandler):
    server_version = "BlueMaia"

    def log_message(self, fmt, *args):
        pass

    def send(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.split("?")[0] != "/api/bewertungen":
            return self.send(404, {"error": "not found"})
        with LOCK, db() as c:
            rows = c.execute("SELECT name, ort, stars, text, created FROM reviews WHERE status='approved' "
                             "ORDER BY created DESC LIMIT 50").fetchall()
        self.send(200, {"reviews": [{"name": r["name"], "ort": r["ort"] or "", "stars": r["stars"],
                                     "text": r["text"], "date": r["created"][:7]} for r in rows]})

    def do_POST(self):
        if self.path != "/api/bewertungen":
            return self.send(404, {"error": "not found"})
        try:
            n = int(self.headers.get("Content-Length") or 0)
            if n > 8000:
                return self.send(413, {"error": "too_large"})
            d = json.loads(self.rfile.read(n) or b"{}")
            if d.get("website"):                       # campo-armadilha: só robôs o preenchem
                return self.send(200, {"ok": True})
            if float(d.get("t") or 0) < 4:             # formulário enviado em menos de 4 s
                return self.send(400, {"error": "too_fast"})
            name, ort, text = clean(d.get("name"), 60), clean(d.get("ort"), 60), clean(d.get("text"), 800)
            stars = int(d.get("stars") or 0)
            lang = d.get("lang") if d.get("lang") in LANGS else None
            if len(name) < 2 or len(text) < 10 or not 1 <= stars <= 5 or d.get("consent") is not True:
                return self.send(400, {"error": "invalid"})
            if re.search(r"https?://|www\.", text + name + ort, re.I):
                return self.send(400, {"error": "links"})
            ip = self.headers.get("CF-Connecting-IP") or self.client_address[0]
            with LOCK:
                if limited(ip):
                    return self.send(429, {"error": "rate"})
                with db() as c:
                    if c.execute("SELECT COUNT(*) FROM reviews WHERE status='pending'").fetchone()[0] >= MAX_PENDING:
                        return self.send(503, {"error": "busy"})
                    c.execute("INSERT INTO reviews (created, name, ort, stars, text, lang) VALUES (?,?,?,?,?,?)",
                              (datetime.datetime.now().isoformat(timespec="seconds"), name, ort, stars, text, lang))
            self.send(200, {"ok": True})
        except (ValueError, TypeError, json.JSONDecodeError):
            self.send(400, {"error": "invalid"})


if __name__ == "__main__":
    with db():
        pass
    print(f"BlueMaia avaliações: http://{HOST}:{PORT}  (DB: {DB})", flush=True)
    ThreadingHTTPServer((HOST, PORT), H).serve_forever()
