#!/usr/bin/env bash
# Instala (uma vez) o serviço de avaliações do site na Orange Pi e atualiza o Caddy.
# Uso (na Orange Pi, dentro da pasta bluemaia-site do vault):  bash setup-avaliacoes.sh
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
SITE=/srv/bluemaia-site
DATA=/srv/bluemaia-avaliacoes/data
PORT=8093

if ss -ltn | grep -q ":$PORT "; then echo "A porta $PORT já está ocupada. Pára aqui e avisa o Claude."; exit 1; fi

echo "== 1/4 Copiar o código para $SITE"
rsync -a --exclude ".git" --exclude "*.sync-conflict-*" "$SRC/" "$SITE/"
chmod -R o+rX "$SITE/public"

echo "== 2/4 Pasta de dados (fora do repositório, nunca vai para o GitHub)"
sudo install -d -o "$USER" -g "$USER" -m 700 /srv/bluemaia-avaliacoes "$DATA"

echo "== 3/4 Serviço systemd bluemaia-avaliacoes (só 127.0.0.1:$PORT)"
sudo tee /etc/systemd/system/bluemaia-avaliacoes.service >/dev/null <<UNIT
[Unit]
Description=BlueMaia avaliacoes (site)
After=network-online.target

[Service]
User=$USER
Environment=BM_REVIEWS_DB=$DATA/avaliacoes.sqlite
Environment=BM_REVIEWS_PORT=$PORT
ExecStart=/usr/bin/python3 $SITE/avaliacoes/server.py
Restart=on-failure
NoNewPrivileges=yes
ProtectSystem=strict
ReadWritePaths=/srv/bluemaia-avaliacoes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable --now bluemaia-avaliacoes

echo "== 4/4 Caddy com a rota /api/bewertungen"
sudo cp "$SITE/Caddyfile" /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null
sudo systemctl restart caddy
sleep 2
systemctl is-active bluemaia-avaliacoes caddy
curl -s http://127.0.0.1:8081/api/bewertungen; echo
echo "Feito. Se apareceu {\"reviews\": []}, está a funcionar. Agora publica o site: bash publicar.sh \"Sites e avaliações\""
