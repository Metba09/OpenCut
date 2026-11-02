---
name: opencut-sandbox
description: Reprendre et faire évoluer le projet OpenCut (éditeur vidéo open source, fork Metba09/OpenCut) dans un sandbox Claude.ai isolé, hors-ligne, depuis le bundle hermétique stocké dans le dépôt de mémoire GitHub (livrables/opencut-sandbox). Utiliser dès que l'utilisateur parle d'OpenCut, de son repo, de apps/web, apps/api, de make check / make setup, de vendoring ou de bundle hors-ligne, de Cloudflare Workers, TanStack Start, wrangler ou Vite à exécuter dans le sandbox, ou veut modifier, tester, builder ou sauvegarder du code OpenCut en session Chat, ou monter / assembler / couper une vidéo (clips, transitions, textes, musique, sous-titres, export MP4) avec le repo OpenCut — même s'il ne cite pas le skill ni la mémoire.
---

# OpenCut en sandbox de session Chat

Le sandbox repart de zéro à chaque session et ne joint que GitHub et les registres de paquets. Ce skill ramène OpenCut
(web + API) à un état installé, testé et sauvegardable en quelques commandes, **sans réseau après le téléchargement du bundle**.
Le bundle (source + cache npm vendoré, ~141 Mo) n'est pas dans le skill : il vit dans `Metba09/claude-memory`,
dossier `livrables/opencut-sandbox/`. Le skill n'apporte que les scripts pour l'utiliser.

## Démarrer

1. Vérifier l'état : `bash scripts/doctor.sh` (chemin relatif au dossier de ce skill).
2. Si `~/.memenv` manque, rattacher la mémoire avec le skill `github-memory` (jeton GitHub fine-grained sur `claude-memory`).
   Ne jamais afficher ni écrire le jeton ailleurs que dans `~/.memenv`.
3. `bash scripts/bootstrap.sh [dossier]` (défaut `~/OpenCut`) : télécharge le bundle, extrait la source, lance `make setup`.
   Idempotent ; relançable sans casser.
4. `cd ~/OpenCut && make check` : doit finir par « TOUT EST VERT » (garde hors-réseau, typecheck, tests web + API, build web, build API).
   Si ce n'est pas vert avant toute modification, s'arrêter et lire `references/troubleshooting.md`.

## Travailler

- Commandes : `make setup` · `make check` · `make test` · `make build` · `make smoke` (API locale, `/health`).
- Outils : Node ≥ 22.12 et npm. Pas de bun, moon ni proto (non installés, serveurs inaccessibles).
- Lancer `make check` avant de conclure, puisqu'aucun hook ne le fait. Le dire à l'utilisateur si un test échoue ; ne pas le contourner.
- Le code est dans `apps/web` (TanStack Start, Vite 8, React 19, Tailwind 4, shadcn), `apps/api` (Elysia sur Workers).
  `CLAUDE.md` à la racine du projet décrit les écarts avec l'amont : le lire avant une modification structurante.
- Ajouter une dépendance : `npm install <pkg> --workspace apps/web --before=<date du jour − 7 jours>` (règle `minimumReleaseAge`
  du repo), puis `make vendor` pour régénérer le bundle. Ces deux étapes ont besoin du registre npm, joignable depuis le sandbox.
  Sans `make vendor`, la prochaine session ne pourra pas installer hors-ligne.

## Monter une vidéo

L'éditeur OpenCut n'existe pas encore (`/editor` = « Coming soon ») : le montage passe par `tools/montage/` du projet, un rendu
scripté (projet JSON -> FFmpeg -> MP4). Le dire à l'utilisateur dès qu'il demande « monter avec OpenCut », puis procéder ainsi :

1. Se procurer les médias (fichiers uploadés dans `/mnt/user-data/uploads`) et demander ce qui manque : ordre des plans, découpes,
   textes, musique, format de sortie. `node tools/montage/montage.mjs probe <média>` donne durée, dimensions, audio.
2. Écrire le projet JSON (`node tools/montage/montage.mjs init` donne un modèle ; format complet : `tools/montage/README.md`).
3. Valider sans rendre : `node tools/montage/montage.mjs projet.json --dry-run --print-graph`. Les incohérences sont refusées avec un message précis.
4. Rendre : `make montage PROJECT=projet.json`. Contrôler le résultat avec `ffprobe` et en extrayant 2 ou 3 images
   (`ffmpeg -ss <t> -i out.mp4 -frames:v 1 f.png`) pour vérifier textes et transitions avant de livrer.
5. Copier le MP4 dans `/mnt/user-data/outputs/` et le présenter (`present_files`). Pas dans la mémoire GitHub : trop lourd.

Limites à annoncer : une seule piste vidéo (pas de superposition d'images), pas d'effets par clip, pas d'animation de texte, pas
d'aperçu interactif ; rendu sur 1 cœur et 3 Go de RAM, donc éviter la 4K et les vidéos de plusieurs minutes sans prévenir.

## Sauvegarder (indispensable)

Tout disparaît avec le sandbox. Une fois `make check` vert :

1. `bash scripts/repack.sh [dossier]` : crée `opencut-source.tar.gz` dans `~/memory/livrables/opencut-sandbox/` (sans `node_modules`, `.env`, builds).
2. Si le lockfile a changé : `OUT=~/memory/livrables/opencut-sandbox make vendor` pour remplacer les morceaux du cache npm.
3. `cd ~/memory && . ~/.memenv && $MS status`, montrer la liste à l'utilisateur, puis `$MS push -m "livrables: opencut-sandbox <résumé>"`.

Les fichiers ne sont envoyés que par `memsync push` : le jeton ne couvre pas le fork `Metba09/OpenCut`.

## Ce qui ne marche pas ici

Le dire d'emblée plutôt que d'essayer : desktop `apps/desktop` (GPUI : ni GPU, ni affichage, ni toolchain Rust), `crates/media`
(prebuilt FFmpeg épinglé en 404, ffmpeg.org bloqué), déploiement Cloudflare et `moon run upload-logos` (secrets), `vite dev`
joignable depuis le navigateur de l'utilisateur (utiliser `make smoke` ou `curl` local). L'éditeur lui-même est encore une page
« Coming soon » dans l'amont : ne pas promettre de fonctionnalités vidéo qui n'existent pas.
