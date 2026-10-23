import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// `npm start` serves on http://localhost:3000 and `npm run build` writes to build/,
// the same port and folder the app used under create-react-app.
// allowedHosts: true accepts any Host header, as create-react-app's dev server did, so the
// app also loads through a load balancer or custom domain. Vite otherwise answers
// "Blocked request" (403) for any host other than localhost or an IP address.
export default defineConfig({
  // The load balancer serves the app at /dev, /stage, or /prod.
  // Jenkins sets VITE_BASE when it builds the image so the js and css use that prefix.
  // I left the fallback as / so npm start on my machine is unchanged.
  base: process.env.VITE_BASE || '/',
  plugins: [react()],
  server: { port: 3000, strictPort: true, host: true, allowedHosts: true },
  preview: { port: 3000, strictPort: true, host: true, allowedHosts: true },
  build: { outDir: 'build' },
})
