import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { before, describe, it } from 'node:test'
import { spawnSync } from 'node:child_process'
import { binaries, demo, MontageError, probe, render } from './montage.mjs'

let dir, bins
const project = (clips, extra = {}) => {
  const f = join(dir, `p-${Math.random().toString(36).slice(2)}.json`)
  writeFileSync(f, JSON.stringify({ output: { path: 'o.mp4', width: 640, height: 360, preset: 'ultrafast' }, clips, ...extra }))
  return f
}

describe('montage headless', () => {
  before(() => {
    bins = binaries()
    dir = mkdtempSync(join(tmpdir(), 'montage-test-'))
    demo(dir) // fabrique a.mp4 (3 s, audio), b.mp4 (3 s, sans audio), music.wav et rend demo-out.mp4
  })

  it('rend un MP4 de la bonne durée avec vidéo et audio', () => {
    const info = probe(join(dir, 'demo-out.mp4'), bins)
    assert.ok(Math.abs(info.duration - 4.5) < 0.15, `durée ${info.duration}`) // 3 + 2 (2,5 s à x1,25) - 0,5 de fondu
    assert.equal(info.hasAudio, true)
    assert.equal(info.width, 640)
  })

  it('place le fondu au bon décalage (dry-run, sans rendu)', () => {
    const r = render(project([{ src: 'a.mp4' }, { src: 'b.mp4', transition: { type: 'wipeleft', duration: 0.5 } }]), { dryRun: true })
    assert.match(r.graph, /xfade=transition=wipeleft:duration=0\.5:offset=2\.5/)
    assert.equal(r.rendered, false)
  })

  it('accepte un clip sans piste audio et une image', () => {
    spawnSync(bins.ffmpeg, ['-y', '-loglevel', 'error', '-f', 'lavfi', '-i', 'color=c=red:s=320x240:d=1', '-frames:v', '1', join(dir, 'i.png')])
    const r = render(project([{ src: 'b.mp4', end: 1 }, { src: 'i.png', duration: 1, fit: 'contain' }]))
    assert.ok(Math.abs(probe(r.output, bins).duration - 2) < 0.15)
  })

  it('refuse un projet incohérent avec un message clair', () => {
    const bad = (clips, re, out) => assert.throws(() => render(project(clips), { dryRun: true, ...out }), (e) => e instanceof MontageError && re.test(e.message))
    bad([{ src: 'a.mp4' }, { src: 'b.mp4', transition: { duration: 5 } }], /trop longue/)
    bad([{ src: 'a.mp4', end: 99 }], /dépasse la durée/)
    bad([{ src: 'i.png' }], /duration/)
    bad([{ src: 'a.mp4', transition: { duration: 0.5 } }], /entrante/)
    bad([{ src: 'a.mp4', speed: 9 }], /speed/)
    bad([], /au moins un clip/)
  })
})
