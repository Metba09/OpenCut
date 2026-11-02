#!/usr/bin/env bash
# Projet OpenCut installé dans un sandbox vierge. Seul accès réseau : GitHub.
#   bash bootstrap.sh [dossier-cible]      défaut : ~/OpenCut
# 1) voie normale : clone du fork public (sans jeton) puis `make setup`, qui télécharge le bundle npm depuis la branche
#    `sandbox-bundle` du fork ; 2) repli : mémoire privée (~/.memenv). Idempotent.
#   OPENCUT_FORK / OPENCUT_BRANCH (défaut Metba09/OpenCut, sandbox-skill) pour viser un autre dépôt.
set -euo pipefail
TARGET="${1:-$HOME/OpenCut}"
FORK="${OPENCUT_FORK:-https://github.com/Metba09/OpenCut.git}"
BRANCH="${OPENCUT_BRANCH:-sandbox-skill}"

if [ -f "$TARGET/node_modules/.opencut-setup-stamp" ]; then
  echo "[opencut-sandbox] déjà installé dans $TARGET (lancer 'make check' pour vérifier)"; exit 0
fi

if [ -f "$TARGET/package-lock.json" ] || git clone -q --depth 1 --single-branch --branch "$BRANCH" "$FORK" "$TARGET" 2>/dev/null; then
  echo "[opencut-sandbox] source depuis le fork ($BRANCH)"
  cd "$TARGET" && bash scripts/setup.sh
  echo "[opencut-sandbox] prêt dans $TARGET : lancer 'make check'."; exit 0
fi

echo "[opencut-sandbox] fork inaccessible, repli sur la mémoire privée" >&2
[ -f "$HOME/.memenv" ] || { echo "~/.memenv absent : rattacher la mémoire (skill github-memory) ou vérifier l'accès au fork." >&2; exit 1; }
. "$HOME/.memenv"
B="${OPENCUT_BUNDLE_DIR:-}"
if [ -z "$B" ] || [ ! -f "$B/SHA256SUMS" ]; then
  DEST="$(mktemp -d)"
  $MS sparse livrables/opencut-sandbox --dest "$DEST" 2>&1 | sed "s/${GH_TOKEN}/[TOKEN]/g" | tail -2
  B="$(find "$DEST" -type d -name opencut-sandbox | head -1)"
fi
[ -n "$B" ] && [ -f "$B/opencut-source.tar.gz" ] || { echo "livrables/opencut-sandbox introuvable ou vide dans la mémoire." >&2; exit 1; }
mkdir -p "$TARGET"; tar -xzf "$B/opencut-source.tar.gz" -C "$TARGET"
cd "$TARGET" && OPENCUT_BUNDLE_DIR="$B" bash scripts/setup.sh
echo "[opencut-sandbox] prêt dans $TARGET : lancer 'make check'."
