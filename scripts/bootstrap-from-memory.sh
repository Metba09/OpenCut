#!/usr/bin/env bash
# Session Chat vierge -> projet prêt, depuis le dépôt de mémoire (seul accès réseau : GitHub).
# Prérequis : ~/.memenv (GH_TOKEN + MEM_REPO) ; le jeton ne doit jamais être affiché.
#   bash bootstrap-from-memory.sh [dossier-cible]   (défaut : ~/OpenCut)
# Si ce script n'est pas encore présent : memsync sparse livrables/opencut-sandbox --dest /tmp/ocs
set -euo pipefail
[ -f "$HOME/.memenv" ] || { echo "~/.memenv absent : rattacher la mémoire d'abord (/github-memory)." >&2; exit 1; }
. "$HOME/.memenv"
TARGET="${1:-$HOME/OpenCut}"
DEST="$(mktemp -d)"
$MS sparse livrables/opencut-sandbox --dest "$DEST"
B="$(find "$DEST" -type d -name opencut-sandbox | head -1)"
[ -n "$B" ] || { echo "livrables/opencut-sandbox introuvable dans la mémoire." >&2; exit 1; }
mkdir -p "$TARGET"
tar -xzf "$B/opencut-source.tar.gz" -C "$TARGET"
cd "$TARGET"
OPENCUT_BUNDLE_DIR="$B" bash scripts/setup.sh
echo "Prêt dans $TARGET : lancer 'make check'."
