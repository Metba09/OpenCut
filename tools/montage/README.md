# montage — montage vidéo headless (sandbox, hors-ligne)

Pas un éditeur graphique : un projet JSON décrit la timeline, `montage.mjs` le compile en graphe FFmpeg et rend un MP4.
Zéro dépendance npm ; il faut seulement `ffmpeg` (et idéalement `ffprobe`). Repli automatique sur le binaire du paquet pip
`imageio-ffmpeg` ; ou `FFMPEG_BIN` / `FFPROBE_BIN`. Cela correspond au « headless mode » annoncé par la feuille de route d'OpenCut,
mais ce n'est **pas** le moteur de l'éditeur OpenCut (qui n'existe pas encore).

```sh
make montage PROJECT=mon-projet.json      # rendu
make montage-demo                         # démo synthétique (aucun fichier requis)
node tools/montage/montage.mjs init       # écrit un projet d'exemple
node tools/montage/montage.mjs mon.json --dry-run --print-graph   # valide et affiche le graphe, sans rendre
node tools/montage/montage.mjs probe media/plan.mp4               # durée, dimensions, audio
```

## Format du projet
Chemins relatifs au dossier du fichier JSON.

| Champ | Rôle |
|---|---|
| `output` | `path` (défaut `out/montage.mp4`), `width`, `height` (pairs), `fps`, `crf`, `preset` |
| `clips[]` | dans l'ordre de lecture |
| `clips[].src` | vidéo ou image (`png jpg jpeg webp bmp`) |
| `clips[].start` / `end` | découpe en secondes dans le média source (défaut : tout le clip) |
| `clips[].duration` | **obligatoire pour une image** : durée d'affichage |
| `clips[].speed` | 0.25 à 4 (défaut 1), audio ralenti/accéléré de façon cohérente |
| `clips[].volume` | gain audio du clip (défaut 1) |
| `clips[].fit` | `cover` (recadre, défaut) ou `contain` (bandes noires) |
| `clips[].transition` | `{type, duration}` entre le clip précédent et celui-ci : `fade fadeblack fadewhite dissolve wipeleft wiperight wipeup wipedown slideleft slideright slideup slidedown circleopen circleclose pixelize radial smoothleft smoothright` |
| `clips[].texts[]` | `{text, start, end, position: top\|center\|bottom, size, color, box, fontfile}` ; temps relatifs au clip |
| `music` | `{src, volume (0.3), fadeOut}` ; bouclée et coupée à la durée du montage |
| `subtitles` | fichier `.srt` incrusté |

Un clip sans piste audio reçoit du silence. Les erreurs (transition plus longue qu'un clip, `end` hors du média, image sans durée,
dimensions impaires…) sont refusées avant rendu avec un message précis.

## Limites
Une seule piste vidéo à la fois (montage séquentiel), pas de superposition d'images, pas d'effets par clip (étalonnage, stabilisation),
pas d'animation de texte. Le rendu tourne sur 1 cœur : compter environ 1 à 3 fois la durée de la vidéo en 720p (`preset: veryfast`).
Aucune garantie pour des vidéos de plusieurs minutes en 4K dans un sandbox de 3 Go de RAM.
