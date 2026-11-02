#!/usr/bin/env bash
# Projet -> opencut-source.tar.gz dans la copie de travail de la mémoire. N'envoie rien : le push reste explicite.
#   bash repack.sh [dossier-projet]        défaut : ~/OpenCut
#   DEST=<dossier> pour changer la destination (défaut ~/memory/livrables/opencut-sandbox)
set -euo pipefail
SRC="${1:-$HOME/OpenCut}"
DEST="${DEST:-$HOME/memory/livrables/opencut-sandbox}"
[ -f "$SRC/package-lock.json" ] || { echo "projet introuvable dans $SRC" >&2; exit 1; }
mkdir -p "$DEST"
# .env et les builds ne partent jamais ; le dossier .git non plus (la source suffit).
tar -C "$SRC" -czf "$DEST/opencut-source.tar.gz" \
  --exclude=./node_modules --exclude='./apps/*/node_modules' --exclude=./.git --exclude=./bundle --exclude=./vendor \
  --exclude=./.env --exclude='./apps/*/.env' --exclude='./apps/*/dist' --exclude='./apps/*/.wrangler' \
  --exclude='./apps/*/.tanstack' --exclude=./target --exclude=./.cache .
echo "[opencut-sandbox] $(du -h "$DEST/opencut-source.tar.gz" | cut -f1) -> $DEST/opencut-source.tar.gz"
if grep -rIlE 'github_pat_|ghp_[A-Za-z0-9]{20}' "$SRC" --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=vendor --exclude-dir=bundle 2>/dev/null | head -1 | grep -q .; then
  echo "⚠ un jeton GitHub semble présent dans le projet : ne pas pousser avant de l'avoir retiré." >&2; exit 2
fi
echo "Étape suivante : cd ~/memory && . ~/.memenv && \$MS status   (puis push après accord)"
