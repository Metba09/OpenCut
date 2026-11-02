import { describe, expect, it } from 'vitest'
import { cn } from './utils'

describe('cn', () => {
  it('fusionne les classes et résout les conflits Tailwind', () => {
    expect(cn('px-2', 'px-4')).toBe('px-4')
  })
  it('ignore les valeurs falsy', () => {
    expect(cn('a', false && 'b', undefined, 'c')).toBe('a c')
  })
})
