#!/usr/bin/env bash
# Corre NA ORANGE PI DA SUÍÇA. Descarrega o RustDesk oficial para Windows (GitHub rustdesk/rustdesk)
# e publica-o em bluemaia.ch/downloads/ com a configuração da BlueMaia no NOME do ficheiro
# (rustdesk-host=...,key=....exe): o cliente só tem de o abrir. Não passa pelo vault (ficheiro grande).
# Uso: bash atualizar-cliente-rustdesk.sh      (repetir quando sair uma versão nova do RustDesk)
set -euo pipefail
SITE=/srv/bluemaia-site
KEY=$(cat "$HOME/rustdesk-chave-publica.txt")
case "$KEY" in ""|*/*) echo "Chave em ~/rustdesk-chave-publica.txt em falta ou inválida."; exit 1 ;; esac
NAME="rustdesk-host=rd.bluemaia.ch,key=${KEY}.exe"

echo "== 1/3 Versão mais recente"
J=$(curl -fsSL https://api.github.com/repos/rustdesk/rustdesk/releases/latest)
TAG=$(echo "$J" | grep -m1 -oE '"tag_name": *"[^"]+"' | cut -d'"' -f4)
URL=$(echo "$J" | grep -oE 'https://[^"]+/rustdesk-[0-9.]+-x86_64\.exe' | head -1)
[ -n "$URL" ] || { echo "Não encontrei o .exe x86_64 na versão $TAG."; exit 1; }
echo "RustDesk $TAG: $URL"

echo "== 2/3 Descarregar e verificar"
TMP=$(mktemp -d); curl -fsSL -o "$TMP/c.exe" "$URL"
SIZE=$(stat -c %s "$TMP/c.exe")
[ "$SIZE" -gt 5000000 ] && [ "$(head -c2 "$TMP/c.exe")" = "MZ" ] || { echo "Ficheiro inesperado ($SIZE bytes)."; exit 1; }
mkdir -p "$SITE/public/downloads"
mv "$TMP/c.exe" "$SITE/public/downloads/$NAME"; rm -rf "$TMP"
echo "$TAG" > "$SITE/public/downloads/rustdesk-versao.txt"
chmod -R o+rX "$SITE/public/downloads"
echo "$(du -h "$SITE/public/downloads/$NAME" | cut -f1)  $NAME"

echo "== 3/3 Publicar (GitHub → Suíça e Portugal)"
cd "$SITE"
git add public/downloads
if git diff --cached --quiet; then echo "Já estava publicada esta versão."; exit 0; fi
git commit -qm "Cliente RustDesk $TAG para a ajuda remota"
git push -q
echo "Publicado: $(git log --oneline -1)"
curl -s -o /dev/null -w "Teste local: HTTP %{http_code}\n" "http://127.0.0.1:8181/downloads/$NAME"
