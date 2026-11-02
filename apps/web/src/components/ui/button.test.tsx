import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { Button } from './button'

describe('Button', () => {
  it('se rend avec son libellé', () => {
    render(<Button>Exporter</Button>)
    expect(screen.getByRole('button', { name: 'Exporter' })).toBeTruthy()
  })
})
