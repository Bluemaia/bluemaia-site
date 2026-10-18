#!/usr/bin/env bash
# Publica no site as alterações feitas no vault (pasta sincronizada pelo Syncthing).
# Uso (na Orange Pi):  bash publicar.sh "descrição da alteração"
set -euo pipefail
MSG="${1:-Atualização do site}"
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="/srv/bluemaia-site"
rsync -a --exclude ".git" --exclude "*.sync-conflict-*" "$SRC/" "$DEST/"
cd "$DEST"
chmod -R o+rX public
git add -A
if git diff --cached --quiet; then echo "Sem alterações para publicar."; exit 0; fi
git commit -qm "$MSG"
git push -q
echo "Publicado: $(git log --oneline -1)"
curl -sI http://127.0.0.1:8081 | head -1
