import path from 'node:path'
import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import { visualizer } from 'rollup-plugin-visualizer'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const repoRoot = path.resolve(__dirname, '../..')
  const env = loadEnv(mode, repoRoot, '')
  const siteUrl = env.VITE_PUBLIC_SITE_URL?.replace(/\/$/, '') ?? ''
  const ogImageUrl = siteUrl ? `${siteUrl}/galwan-icon.png` : '/galwan-icon.png'
  const analyze = env.ANALYZE === 'true'

  return {
    envDir: repoRoot,
    plugins: [
      react(),
      {
        name: 'inject-og-image',
        transformIndexHtml(html) {
          return html.replaceAll('__OG_IMAGE_URL__', ogImageUrl)
        },
      },
      ...(analyze
        ? [
            visualizer({
              filename: 'dist/bundle-stats.html',
              gzipSize: true,
              brotliSize: true,
              open: true,
            }),
          ]
        : []),
    ],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src'),
      },
    },
  }
})
