---
name: opencut-sandbox
description: Reprendre et faire évoluer le projet OpenCut (éditeur vidéo open source, fork Metba09/OpenCut) dans un sandbox Claude.ai isolé, hors-ligne, depuis le bundle hermétique stocké dans le dépôt de mémoire GitHub (livrables/opencut-sandbox). Utiliser dès que l'utilisateur parle d'OpenCut, de son repo, de apps/web, apps/api, de make check / make setup, de vendoring ou de bundle hors-ligne, de Cloudflare Workers, TanStack Start, wrangler ou Vite à exécuter dans le sandbox, ou veut modifier, tester, builder ou sauvegarder du code OpenCut en session Chat, ou monter / assembler / couper une vidéo (clips, transitions, textes, musique, sous-titres, export MP4) avec le repo OpenCut — même s'il ne cite pas le skill ni la mémoire.
---

# OpenCut en sandbox de session Chat

Le sandbox repart de zéro à chaque session et ne joint que GitHub et les registres de paquets. Ce skill ramène OpenCut
(web + API + montage vidéo headless) à un état installé, testé et sauvegardable, **sans réseau après le téléchargement du bundle**.
Tout vient du fork public `Metba09/OpenCut` : le code sur la branche `sandbox-skill`, le cache npm vendoré (~146 Mo) sur la branche
orpheline `sandbox-bundle`. Aucun jeton n'est nécessaire pour lire. Repli : la mémoire privée `claude-memory`
(`livrables/opencut-sandbox/`) si le fork est inaccessible.

## Démarrer

1. Vérifier l'état : `bash scripts/doctor.sh` (chemin relatif au dossier de ce skill).
2. `bash scripts/bootstrap.sh [dossier]` (défaut `~/OpenCut`) : clone le fork, puis `make setup` télécharge le bundle une fois et
   installe hors-ligne. Idempotent ; relançable sans casser. Le repli mémoire exige `~/.memenv` (skill `github-memory`) ; ne jamais
   afficher ni écrire un jeton ailleurs que dans `~/.memenv`.
3. `cd ~/OpenCut && make check` : doit finir par « TOUT EST VERT » (garde hors-réseau, typecheck, tests web + API + montage, builds).
   Si ce n'est pas vert avant toute modification, s'arrêter et lire `references/troubleshooting.md`.

## Travailler

- Commandes : `make setup` · `make check` · `make test` · `make build` · `make smoke` (API locale, `/health`).
- Outils : Node ≥ 22.12 et npm. Pas de bun, moon ni proto (non installés, serveurs inaccessibles).
- Lancer `make check` avant de conclure, puisqu'aucun hook ne le fait. Le dire à l'utilisateur si un test échoue ; ne pas le contourner.
- Le code est dans `apps/web` (TanStack Start, Vite 8, React 19, Tailwind 4, shadcn), `apps/api` (Elysia sur Workers).
  `CLAUDE.md` à la racine du projet décrit les écarts avec l'amont : le lire avant une modification structurante.
- Ajouter une dépendance : `npm install <pkg> --workspace apps/web --before=<date du jour − 7 jours>` (règle `minimumReleaseAge`
  du repo), puis `make vendor` pour régénérer le bundle (voir « Sauvegarder »). Ces deux étapes ont besoin du registre npm.

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

1. **Dans le fork** (si l'utilisateur fournit un jeton fine-grained Contents RW sur `Metba09/OpenCut`) : `git add -A && git commit`, puis
   `git -c http.extraheader="Authorization: Basic $(printf 'x-access-token:%s' "$TOKEN" | base64 -w0)" push fork <branche>`.
   Le jeton reste dans une variable de la commande : jamais dans `.git/config`, un fichier ou une réponse. Pousser sur une branche,
   pas sur `main` (qui doit rester alignée sur l'amont), sauf demande explicite.
2. **Dans la mémoire privée** (copie de secours, sans jeton fork) : `bash scripts/repack.sh [dossier]`, puis
   `cd ~/memory && . ~/.memenv && $MS status`, montrer la liste, `$MS push -m "livrables: opencut-sandbox <résumé>"`.
3. Si le lockfile a changé : `make vendor`, puis `GH_PUSH_TOKEN=... bash scripts/publish-bundle.sh` (remplace la branche `sandbox-bundle`)
   et, pour la mémoire, `OUT=~/memory/livrables/opencut-sandbox make vendor`. Sans cela, la prochaine session ne pourra pas installer hors-ligne.

## Ce qui ne marche pas ici

Le dire d'emblée plutôt que d'essayer : desktop `apps/desktop` (GPUI : ni GPU, ni affichage, ni toolchain Rust), `crates/media`
(prebuilt FFmpeg épinglé en 404, ffmpeg.org bloqué), déploiement Cloudflare et `moon run upload-logos` (secrets), `vite dev`
joignable depuis le navigateur de l'utilisateur (utiliser `make smoke` ou `curl` local). L'éditeur lui-même est encore une page
« Coming soon » dans l'amont : ne pas promettre de fonctionnalités vidéo qui n'existent pas.
