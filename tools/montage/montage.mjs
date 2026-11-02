#!/usr/bin/env node
// Montage vidéo headless pour OpenCut (sandbox Claude.ai, hors-ligne) : un projet JSON décrit la timeline,
// ce script le compile en un graphe de filtres FFmpeg et rend un MP4. Aucune dépendance npm ; FFmpeg suffit.
//
//   node tools/montage/montage.mjs <projet.json> [--dry-run] [--print-graph] [--out fichier.mp4]
//   node tools/montage/montage.mjs init [projet.json]    écrit un projet d'exemple
//   node tools/montage/montage.mjs demo [dossier]        fabrique des clips synthétiques et rend un montage complet
//   node tools/montage/montage.mjs probe <média>         durée, dimensions, audio
//
// Format du projet : voir tools/montage/README.md.
import { spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { basename, dirname, extname, join, resolve } from 'node:path'

const IMAGE_EXT = new Set(['.png', '.jpg', '.jpeg', '.webp', '.bmp'])
const TRANSITIONS = new Set([
  'fade', 'fadeblack', 'fadewhite', 'dissolve', 'wipeleft', 'wiperight', 'wipeup', 'wipedown',
  'slideleft', 'slideright', 'slideup', 'slidedown', 'circleopen', 'circleclose', 'pixelize', 'radial', 'smoothleft', 'smoothright',
])
const FONTS = [
  '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
  '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
  '/usr/share/fonts/truetype/freefont/FreeSansBold.ttf',
]

export class MontageError extends Error {}
const fail = (message) => { throw new MontageError(message) }
const num = (v, d) => (v === undefined || v === null ? d : Number(v))
const r3 = (x) => Math.round(x * 1000) / 1000

// ---------- binaires -------------------------------------------------------------------------------------------
function findBin(name, envVar) {
  const candidates = [process.env[envVar], name].filter(Boolean)
  for (const c of candidates) if (spawnSync(c, ['-version'], { stdio: 'ignore' }).status === 0) return c
  if (name === 'ffmpeg') { // repli : binaire embarqué dans le paquet pip imageio-ffmpeg
    const py = spawnSync('python3', ['-c', 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())'], { encoding: 'utf8' })
    const p = py.status === 0 ? py.stdout.trim() : ''
    if (p && existsSync(p)) return p
  }
  return null
}
export function binaries() {
  const ffmpeg = findBin('ffmpeg', 'FFMPEG_BIN')
  if (!ffmpeg) fail("ffmpeg introuvable. Installer : `apt-get install -y ffmpeg` ou `pip install --break-system-packages imageio-ffmpeg`, ou définir FFMPEG_BIN.")
  return { ffmpeg, ffprobe: findBin('ffprobe', 'FFPROBE_BIN') }
}

// ---------- sondage d'un média ---------------------------------------------------------------------------------
export function probe(file, bins = binaries()) {
  if (!existsSync(file)) fail(`média introuvable : ${file}`)
  if (IMAGE_EXT.has(extname(file).toLowerCase())) return { duration: null, hasAudio: false, image: true }
  if (bins.ffprobe) {
    const r = spawnSync(bins.ffprobe, ['-v', 'error', '-show_entries', 'format=duration:stream=codec_type,width,height', '-of', 'json', file], { encoding: 'utf8' })
    if (r.status !== 0) fail(`ffprobe a échoué sur ${file} : ${r.stderr.trim()}`)
    const j = JSON.parse(r.stdout)
    const v = (j.streams ?? []).find((s) => s.codec_type === 'video')
    return { duration: Number(j.format?.duration), hasAudio: (j.streams ?? []).some((s) => s.codec_type === 'audio'), width: v?.width, height: v?.height, image: false }
  }
  const r = spawnSync(bins.ffmpeg, ['-hide_banner', '-i', file], { encoding: 'utf8' }) // sans ffprobe : on lit la sortie de ffmpeg
  const m = /Duration:\s*(\d+):(\d+):([\d.]+)/.exec(r.stderr)
  if (!m) fail(`durée illisible pour ${file}`)
  return { duration: +m[1] * 3600 + +m[2] * 60 + +m[3], hasAudio: /Stream #.*Audio:/.test(r.stderr), image: false }
}

// ---------- validation et normalisation ------------------------------------------------------------------------
export function normalize(project, baseDir, bins) {
  if (!project || typeof project !== 'object') fail('projet vide ou invalide.')
  const out = project.output ?? {}
  const output = {
    path: resolve(baseDir, out.path ?? 'out/montage.mp4'),
    width: num(out.width, 1280), height: num(out.height, 720), fps: num(out.fps, 30),
    crf: num(out.crf, 23), preset: out.preset ?? 'veryfast',
  }
  if (output.width % 2 || output.height % 2) fail('output.width et output.height doivent être pairs (H.264).')
  if (!Array.isArray(project.clips) || project.clips.length === 0) fail('"clips" doit contenir au moins un clip.')

  const clips = project.clips.map((c, i) => {
    const where = `clips[${i}]`
    if (!c.src) fail(`${where}.src manquant.`)
    const src = resolve(baseDir, c.src)
    const info = probe(src, bins)
    const speed = num(c.speed, 1)
    if (!(speed >= 0.25 && speed <= 4)) fail(`${where}.speed doit être entre 0.25 et 4.`)
    const start = num(c.start, 0)
    let end
    if (info.image) {
      if (!(num(c.duration, 0) > 0)) fail(`${where} : une image exige "duration" > 0.`)
      end = start + num(c.duration, 0) * speed
    } else {
      end = num(c.end, info.duration)
      if (end > info.duration + 0.05) fail(`${where}.end (${end}s) dépasse la durée du média (${r3(info.duration)}s).`)
    }
    if (!(end > start)) fail(`${where} : end doit être supérieur à start.`)
    const tr = c.transition ?? null
    if (tr && i === 0) fail('clips[0] ne peut pas avoir de transition entrante.')
    if (tr && !TRANSITIONS.has(tr.type ?? 'fade')) fail(`${where}.transition.type inconnu : ${tr.type}. Valeurs : ${[...TRANSITIONS].join(', ')}`)
    return {
      src, image: info.image, hasAudio: info.hasAudio, start, end, speed, volume: num(c.volume, 1),
      fit: c.fit ?? 'cover', duration: r3((end - start) / speed),
      transition: tr ? { type: tr.type ?? 'fade', duration: num(tr.duration, 0.5) } : null,
      texts: (c.texts ?? []).map((t, j) => {
        if (!t.text) fail(`${where}.texts[${j}].text manquant.`)
        return { size: 48, color: 'white', position: 'bottom', start: 0, ...t }
      }),
    }
  })
  clips.forEach((c, i) => {
    if (!c.transition) return
    const t = c.transition.duration
    if (!(t > 0)) fail(`clips[${i}].transition.duration doit être > 0.`)
    if (t >= c.duration || t >= clips[i - 1].duration) fail(`clips[${i}] : transition de ${t}s trop longue pour des clips de ${clips[i - 1].duration}s et ${c.duration}s.`)
  })
  const music = project.music?.src ? { ...project.music, src: resolve(baseDir, project.music.src) } : null
  if (music && !existsSync(music.src)) fail(`musique introuvable : ${music.src}`)
  const subtitles = project.subtitles ? resolve(baseDir, project.subtitles) : null
  if (subtitles && !existsSync(subtitles)) fail(`sous-titres introuvables : ${subtitles}`)
  return { output, clips, music, subtitles }
}

// ---------- compilation vers un graphe FFmpeg ------------------------------------------------------------------
const esc = (p) => p.replace(/\\/g, '\\\\').replace(/:/g, '\\:').replace(/'/g, "\\'") // chemin dans une option de filtre

function atempoChain(speed) {
  const parts = []
  let s = speed
  while (s > 2) { parts.push('atempo=2'); s /= 2 }
  while (s < 0.5) { parts.push('atempo=0.5'); s /= 0.5 }
  if (Math.abs(s - 1) > 1e-9) parts.push(`atempo=${r3(s)}`)
  return parts
}

function drawtext(t, tmp, k) {
  const file = join(tmp, `text-${k}.txt`)
  writeFileSync(file, String(t.text))
  const font = t.fontfile ?? FONTS.find(existsSync)
  const y = { top: 'h*0.08', center: '(h-text_h)/2', bottom: 'h-text_h-h*0.08' }[t.position] ?? fail(`position de texte inconnue : ${t.position}`)
  const o = [`textfile='${esc(file)}'`, ...(font ? [`fontfile='${esc(font)}'`] : []), `fontsize=${t.size}`, `fontcolor=${t.color}`, 'x=(w-text_w)/2', `y=${y}`]
  if (t.box !== false) o.push('box=1', 'boxcolor=black@0.45', 'boxborderw=14')
  if (t.end !== undefined) o.push(`enable='between(t,${t.start},${t.end})'`)
  else if (t.start) o.push(`enable='gte(t,${t.start})'`)
  return `drawtext=${o.join(':')}`
}

export function buildCommand(plan, bins, tmp) {
  const { output: o, clips, music, subtitles } = plan
  const args = ['-y', '-hide_banner', '-loglevel', 'error', '-stats']
  clips.forEach((c) => {
    if (c.image) args.push('-loop', '1', '-framerate', String(o.fps), '-t', String(c.duration * c.speed + c.start), '-i', c.src)
    else args.push('-i', c.src)
  })
  if (music) args.push('-stream_loop', '-1', '-i', music.src)

  const g = []
  let textIdx = 0
  clips.forEach((c, i) => {
    const fitv = c.fit === 'contain'
      ? `scale=${o.width}:${o.height}:force_original_aspect_ratio=decrease,pad=${o.width}:${o.height}:(ow-iw)/2:(oh-ih)/2:black`
      : `scale=${o.width}:${o.height}:force_original_aspect_ratio=increase,crop=${o.width}:${o.height}`
    const v = [`trim=start=${c.start}:end=${c.end}`, `setpts=(PTS-STARTPTS)/${c.speed}`, `fps=${o.fps}`, fitv, 'setsar=1', 'format=yuv420p',
      ...c.texts.map((t) => drawtext(t, tmp, textIdx++))]
    g.push(`[${i}:v]${v.join(',')}[v${i}]`)
    if (c.hasAudio && !c.image) {
      const a = [`atrim=start=${c.start}:end=${c.end}`, 'asetpts=PTS-STARTPTS', ...atempoChain(c.speed), `volume=${c.volume}`,
        'aresample=48000', 'aformat=sample_fmts=fltp:channel_layouts=stereo']
      g.push(`[${i}:a]${a.join(',')}[a${i}]`)
    } else {
      g.push(`anullsrc=r=48000:cl=stereo:d=${c.duration},aformat=sample_fmts=fltp:channel_layouts=stereo[a${i}]`)
    }
  })

  let vcur = 'v0', acur = 'a0', dur = clips[0].duration
  for (let i = 1; i < clips.length; i++) {
    const c = clips[i]
    if (c.transition) {
      const t = c.transition.duration
      g.push(`[${vcur}][v${i}]xfade=transition=${c.transition.type}:duration=${t}:offset=${r3(dur - t)}[vx${i}]`)
      g.push(`[${acur}][a${i}]acrossfade=d=${t}[ax${i}]`)
      dur = dur + c.duration - t
    } else {
      g.push(`[${vcur}][v${i}]concat=n=2:v=1:a=0[vx${i}]`)
      g.push(`[${acur}][a${i}]concat=n=2:v=0:a=1[ax${i}]`)
      dur += c.duration
    }
    vcur = `vx${i}`; acur = `ax${i}`
  }
  dur = r3(dur)

  const vfinal = subtitles ? [`subtitles='${esc(subtitles)}'`] : []
  g.push(`[${vcur}]${[...vfinal, 'format=yuv420p'].join(',')}[vout]`)
  if (music) {
    const m = clips.length
    const fo = num(music.fadeOut, 0)
    const chain = [`atrim=duration=${dur}`, 'asetpts=PTS-STARTPTS', `volume=${num(music.volume, 0.3)}`, 'aresample=48000',
      'aformat=sample_fmts=fltp:channel_layouts=stereo', ...(fo > 0 ? [`afade=t=out:st=${r3(Math.max(0, dur - fo))}:d=${fo}`] : [])]
    g.push(`[${m}:a]${chain.join(',')}[mus]`)
    g.push(`[${acur}][mus]amix=inputs=2:duration=first:normalize=0[aout]`)
  } else {
    g.push(`[${acur}]anull[aout]`)
  }

  const graphFile = join(tmp, 'graph.txt')
  const graph = g.join(';\n')
  writeFileSync(graphFile, graph)
  args.push('-filter_complex_script', graphFile, '-map', '[vout]', '-map', '[aout]', '-t', String(dur),
    '-c:v', 'libx264', '-preset', o.preset, '-crf', String(o.crf), '-pix_fmt', 'yuv420p', '-r', String(o.fps),
    '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', o.path)
  return { args, graph, duration: dur }
}

// ---------- exécution -------------------------------------------------------------------------------------------
export function render(projectPath, opts = {}) {
  const bins = binaries()
  const file = resolve(projectPath)
  if (!existsSync(file)) fail(`projet introuvable : ${file}`)
  let raw
  try { raw = JSON.parse(readFileSync(file, 'utf8')) } catch (e) { fail(`JSON invalide dans ${file} : ${e.message}`) }
  if (opts.out) raw.output = { ...(raw.output ?? {}), path: opts.out }
  const plan = normalize(raw, dirname(file), bins)
  const tmp = mkdtempSync(join(tmpdir(), 'montage-'))
  const cmd = buildCommand(plan, bins, tmp)
  if (opts.printGraph) console.log(cmd.graph)
  if (opts.dryRun) return { ...cmd, plan, output: plan.output.path, rendered: false }
  mkdirSync(dirname(plan.output.path), { recursive: true })
  const r = spawnSync(bins.ffmpeg, cmd.args, { stdio: ['ignore', 'inherit', 'inherit'] })
  if (r.status !== 0) fail(`ffmpeg a échoué (code ${r.status}). Relancer avec --print-graph pour inspecter le graphe.`)
  return { ...cmd, plan, output: plan.output.path, rendered: true }
}

// ---------- exemple et démo -------------------------------------------------------------------------------------
const EXAMPLE = {
  output: { path: 'out/montage.mp4', width: 1280, height: 720, fps: 30, crf: 23 },
  clips: [
    { src: 'media/intro.mp4', start: 0, end: 5, texts: [{ text: 'Mon titre', start: 0.5, end: 4, position: 'center', size: 72 }] },
    { src: 'media/plan2.mp4', start: 2, end: 9, speed: 1, volume: 1, transition: { type: 'fade', duration: 0.6 } },
    { src: 'media/photo.jpg', duration: 3, fit: 'contain', transition: { type: 'slideleft', duration: 0.5 } },
  ],
  music: { src: 'media/musique.mp3', volume: 0.25, fadeOut: 2 },
  subtitles: 'media/sous-titres.srt',
}

export function demo(dir) {
  const bins = binaries()
  mkdirSync(dir, { recursive: true })
  const gen = (name, args) => {
    const r = spawnSync(bins.ffmpeg, ['-y', '-hide_banner', '-loglevel', 'error', ...args, join(dir, name)], { stdio: 'inherit' })
    if (r.status !== 0) fail(`génération de ${name} impossible.`)
  }
  gen('a.mp4', ['-f', 'lavfi', '-i', 'testsrc2=s=640x360:r=30:d=3', '-f', 'lavfi', '-i', 'sine=f=440:d=3', '-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-shortest'])
  gen('b.mp4', ['-f', 'lavfi', '-i', 'smptebars=s=640x360:r=30:d=3', '-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p']) // sans piste audio
  gen('music.wav', ['-f', 'lavfi', '-i', 'sine=f=220:d=4'])
  writeFileSync(join(dir, 'demo.json'), JSON.stringify({
    output: { path: 'demo-out.mp4', width: 640, height: 360, fps: 30, preset: 'ultrafast' },
    clips: [
      { src: 'a.mp4', texts: [{ text: 'OpenCut headless', start: 0.3, end: 2.5, position: 'center', size: 40 }] },
      { src: 'b.mp4', end: 2.5, speed: 1.25, transition: { type: 'fade', duration: 0.5 } },
    ],
    music: { src: 'music.wav', volume: 0.2, fadeOut: 1 },
  }, null, 2))
  return render(join(dir, 'demo.json'))
}

// ---------- CLI -------------------------------------------------------------------------------------------------
function main(argv) {
  const [cmd, ...rest] = argv
  try {
    if (!cmd || cmd === '--help' || cmd === '-h') {
      console.log(readFileSync(new URL(import.meta.url), 'utf8').split('\n').slice(1, 9).map((l) => l.replace(/^\/\/ ?/, '')).join('\n'))
      return 0
    }
    if (cmd === 'init') {
      const f = resolve(rest[0] ?? 'montage.json')
      if (existsSync(f)) fail(`${f} existe déjà.`)
      writeFileSync(f, JSON.stringify(EXAMPLE, null, 2) + '\n'); console.log(`exemple écrit : ${f}`); return 0
    }
    if (cmd === 'probe') { console.log(JSON.stringify(probe(resolve(rest[0] ?? fail('probe <média>'))), null, 2)); return 0 }
    if (cmd === 'demo') {
      const res = demo(resolve(rest[0] ?? join(tmpdir(), 'montage-demo')))
      console.log(`démo rendue : ${res.output} (${res.duration}s)`); return 0
    }
    const opts = { dryRun: rest.includes('--dry-run'), printGraph: rest.includes('--print-graph'), out: rest.includes('--out') ? rest[rest.indexOf('--out') + 1] : undefined }
    const res = render(cmd, opts)
    console.log(res.rendered ? `OK : ${res.output} (${res.duration}s)` : `dry-run : ${res.plan.clips.length} clip(s), ${res.duration}s, sortie ${res.output}`)
    return 0
  } catch (e) {
    if (e instanceof MontageError) { console.error(`montage : ${e.message}`); return 1 }
    throw e
  }
}

if (process.argv[1] && basename(process.argv[1]) === 'montage.mjs') process.exitCode = main(process.argv.slice(2))
