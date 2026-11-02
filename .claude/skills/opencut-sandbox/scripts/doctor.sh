#!/usr/bin/env bash
# État du poste : mémoire rattachée ? bundle disponible ? projet installé ? Ne modifie rien, n'affiche aucun secret.
TARGET="${1:-$HOME/OpenCut}"
ok(){ printf '  ✔ %s\n' "$*"; }; ko(){ printf '  ✘ %s\n' "$*"; }
echo "Mémoire GitHub"
if [ -f "$HOME/.memenv" ]; then . "$HOME/.memenv"; ok "~/.memenv présent (dépôt : ${MEM_REPO:-?})"
  [ -n "${MS:-}" ] && $MS doctor 2>&1 | sed "s/${GH_TOKEN:-@@none@@}/[TOKEN]/g" | sed 's/^/    /'
else ko "~/.memenv absent : rattacher la mémoire (skill github-memory)"; fi
echo "Outils"
command -v node >/dev/null && ok "node $(node -v), npm $(npm -v)" || ko "node absent"
command -v unshare >/dev/null && ok "unshare disponible (test hors-réseau possible)" || ko "unshare absent"
echo "Projet ($TARGET)"
if [ -f "$TARGET/package-lock.json" ]; then ok "source présente"
  [ -f "$TARGET/node_modules/.opencut-setup-stamp" ] && ok "dépendances installées" || ko "dépendances non installées : make setup"
else ko "source absente : bash scripts/bootstrap.sh"; fi
