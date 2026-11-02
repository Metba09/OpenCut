// Configuration dédiée aux tests : sans les plugins Cloudflare / TanStack Start /
// devtools de vite.config.ts, qui exigent un serveur de dev (workerd) et font
// échouer vitest au démarrage ("depsOptimizer is required in dev mode").
import { defineConfig } from 'vitest/config'
import viteReact from '@vitejs/plugin-react'

export default defineConfig({
  resolve: { tsconfigPaths: true },
  plugins: [viteReact()],
  test: {
    environment: 'jsdom',
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
    globals: false,
  },
})
