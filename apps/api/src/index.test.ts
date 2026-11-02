import { describe, expect, it } from 'vitest'
import app from './index'

// Appel direct du handler fetch : aucun port ouvert, aucun réseau.
const call = (path: string, init?: RequestInit) =>
  app.fetch(new Request(`http://localhost${path}`, init))

describe('API', () => {
  it('GET / renvoie status ok', async () => {
    const res = await call('/')
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ status: 'ok' })
  })
  it('GET /health renvoie healthy', async () => {
    const body = (await (await call('/health')).json()) as { healthy: boolean }
    expect(body.healthy).toBe(true)
  })
  it('POST /echo renvoie le corps valide', async () => {
    const res = await call('/echo', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ message: 'salut' }),
    })
    expect(await res.json()).toEqual({ message: 'salut' })
  })
  it('POST /echo rejette un corps invalide', async () => {
    const res = await call('/echo', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ message: 42 }),
    })
    expect(res.status).toBeGreaterThanOrEqual(400)
  })
})
