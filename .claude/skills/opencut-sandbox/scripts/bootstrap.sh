#!/usr/bin/env bash
# Mémoire GitHub -> projet OpenCut installé. Seul accès réseau : GitHub (téléchargement du bundle).
#   bash bootstrap.sh [dossier-cible]      défaut : ~/OpenCut
# Idempotent : si le projet est déjà installé, ne retélécharge rien.
set -euo pipefail
[ -f "$HOME/.memenv" ] || { echo "~/.memenv absent : rattacher la mémoire d'abord (skill github-memory)." >&2; exit 1; }
. "$HOME/.memenv"
TARGET="${1:-$HOME/OpenCut}"

if [ -f "$TARGET/node_modules/.opencut-setup-stamp" ]; then
  echo "[opencut-sandbox] déjà installé dans $TARGET (lancer 'make check' pour vérifier)"; exit 0
fi

B="${OPENCUT_BUNDLE_DIR:-}"
if [ -z "$B" ] || [ ! -f "$B/SHA256SUMS" ]; then
  DEST="$(mktemp -d)"
  $MS sparse livrables/opencut-sandbox --dest "$DEST" 2>&1 | sed "s/${GH_TOKEN}/[TOKEN]/g" | tail -2
  B="$(find "$DEST" -type d -name opencut-sandbox | head -1)"
fi
[ -n "$B" ] && [ -f "$B/opencut-source.tar.gz" ] || { echo "livrables/opencut-sandbox introuvable ou vide dans la mémoire." >&2; exit 1; }

mkdir -p "$TARGET"
tar -xzf "$B/opencut-source.tar.gz" -C "$TARGET"
cd "$TARGET"
OPENCUT_BUNDLE_DIR="$B" bash scripts/setup.sh
echo "[opencut-sandbox] prêt dans $TARGET : lancer 'make check'."
