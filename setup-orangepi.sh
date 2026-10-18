#!/usr/bin/env bash
# Instala o site da BlueMaia na Orange Pi (Ubuntu 24.04).
# Uso:  bash setup-orangepi.sh UTILIZADOR_GITHUB
set -euo pipefail

GH_USER="${1:?Indica o utilizador do GitHub: bash setup-orangepi.sh UTILIZADOR}"
REPO="bluemaia-site"
SRC="$(cd "$(dirname "$0")" && pwd)"      # pasta sincronizada pelo Syncthing
DEST="/srv/bluemaia-site"
KEY="$HOME/.ssh/bluemaia_deploy"

echo "== 1/6 Instalar git e caddy"
sudo apt-get update -qq
sudo apt-get install -y -qq git caddy rsync curl

echo "== 2/6 Chave SSH só para este repositório (deploy key)"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
[ -f "$KEY" ] || ssh-keygen -t ed25519 -N "" -C "orangepi-bluemaia" -f "$KEY" >/dev/null
grep -q "Host github-bluemaia" "$HOME/.ssh/config" 2>/dev/null || cat >> "$HOME/.ssh/config" <<CFG

Host github-bluemaia
  HostName github.com
  User git
  IdentityFile $KEY
  IdentitiesOnly yes
CFG
chmod 600 "$HOME/.ssh/config"
ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
echo
echo "Chave pública (cola-a no GitHub como Deploy key, com 'Allow write access'):"
echo "------------------------------------------------------------------"
cat "$KEY.pub"
echo "------------------------------------------------------------------"
read -rp "Depois de adicionares a chave no GitHub, carrega em Enter... "

echo "== 3/6 Criar o repositório local em $DEST e enviar para o GitHub"
sudo mkdir -p "$DEST" && sudo chown "$USER:$USER" "$DEST"
rsync -a --delete --exclude ".git" --exclude "*.sync-conflict-*" "$SRC/" "$DEST/"
cd "$DEST"
[ -d .git ] || git init -q -b main
git config user.name "BlueMaia Digital"
git config user.email "framaia@bluemaia.ch"
git add -A
git commit -qm "Site BlueMaia Digital: primeira versão" || true
git remote remove origin 2>/dev/null || true
git remote add origin "git@github-bluemaia:$GH_USER/$REPO.git"
git push -u origin main

echo "== 4/6 Configurar o Caddy (só localhost:8081)"
sudo cp "$DEST/Caddyfile" /etc/caddy/Caddyfile
sudo chmod o+rx /srv "$DEST" && chmod -R o+rX "$DEST/public"
sudo systemctl enable caddy
sudo systemctl restart caddy

echo "== 5/6 Atualizar automaticamente a partir do GitHub (a cada 5 min)"
( crontab -l 2>/dev/null | grep -v bluemaia-site; echo "*/5 * * * * git -C $DEST pull -q --ff-only && chmod -R o+rX $DEST/public" ) | crontab -

echo "== 6/6 Teste"
curl -sI http://127.0.0.1:8081 | head -1
echo
echo "Feito. O site está a correr em http://127.0.0.1:8081 (só dentro da Orange Pi)."
echo "Próximo passo: instalar o cloudflared com o comando do painel do Cloudflare."
