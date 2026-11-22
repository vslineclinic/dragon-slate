import { defineConfig } from 'vite';

export default defineConfig({
  root: 'apps/web',
  base: './',
  publicDir: '../../assets',
  server: { fs: { allow: ['../..'] } },
  build: { outDir: '../../dist', emptyOutDir: true },
});
