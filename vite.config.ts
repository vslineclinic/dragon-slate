import { defineConfig } from 'vite';

export default defineConfig({
  root: 'apps/web',
  publicDir: false,
  server: { fs: { allow: ['../..'] } },
  build: { outDir: '../../dist', emptyOutDir: true },
});
