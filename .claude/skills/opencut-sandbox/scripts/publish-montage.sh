#!/usr/bin/env bash
# Dépose un montage terminé dans la copie de travail de la mémoire : MP4 final + projet JSON (pour le refaire).
# Garde-fous : refuse un MP4 > 40 Mo ; ne copie jamais les médias sources. N'envoie rien : le push reste une étape distincte.
#   bash publish-montage.sh <projet.json> <sujet> [fichier.mp4]
# Le MP4 est lu dans output.path du projet (relatif au JSON) sauf s'il est donné en 3e argument.
set -euo pipefail
PROJ="${1:?usage: publish-montage.sh <projet.json> <sujet> [fichier.mp4]}"
SUJET="${2:?sujet manquant (ex. vidtype-intro)}"
MAXMB="${MAXMB:-40}"
BASE="${DEST_BASE:-$HOME/memory/livrables/montage}"
MP4="${3:-$(python3 -c 'import json,sys,os;p=sys.argv[1];o=json.load(open(p)).get("output",{}).get("path","out/montage.mp4");print(os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(p)),o)))' "$PROJ")}"
[ -f "$MP4" ] || { echo "MP4 introuvable : $MP4" >&2; exit 1; }
SIZE=$(( $(stat -c %s "$MP4") / 1048576 ))
if [ "$SIZE" -ge "$MAXMB" ]; then
  echo "MP4 de ${SIZE} Mo (limite ${MAXMB} Mo) : ne pas le pousser sur GitHub. Le livrer par téléchargement (/mnt/user-data/outputs)." >&2; exit 3
fi
SLUG="$(python3 -c 'import sys,unicodedata,re;t=unicodedata.normalize("NFKD",sys.argv[1]).encode("ascii","ignore").decode().lower();print(re.sub(r"[^a-z0-9_-]+","-",t).strip("-") or "montage")' "$SUJET")"
D="$BASE/$(date +%F)-$SLUG"; mkdir -p "$D"
cp "$MP4" "$D/$(basename "$MP4")"; cp "$PROJ" "$D/projet.json"
INFO="$(ffprobe -v error -show_entries format=duration:stream=codec_type,width,height -of compact "$MP4" 2>/dev/null | tr '\n' ' ' || true)"
cat > "$D/README.md" << MD
# Montage $SLUG ($(date +%F))
- Sortie : \`$(basename "$MP4")\` (${SIZE} Mo) — $INFO
- Projet : \`projet.json\` (chemins relatifs ; les médias sources ne sont pas conservés).
- Refaire : \`make montage PROJECT=projet.json\` dans le fork Metba09/OpenCut (branche sandbox-skill), avec les sources replacées.
MD
echo "[opencut-sandbox] déposé dans $D"
echo "Étape suivante : cd ~/memory && . ~/.memenv && \$MS status   (puis push)"
