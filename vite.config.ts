import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { defineConfig, type Plugin } from 'vite';

/** 빌드 폴더를 Godot가 가져오지 않게 .gdignore를 다시 써 둔다(emptyOutDir가 지우므로) */
function godotIgnore(): Plugin {
  let outDir = '';
  return {
    name: 'godot-ignore',
    configResolved(c) {
      outDir = resolve(c.root, c.build.outDir);
    },
    closeBundle() {
      writeFileSync(resolve(outDir, '.gdignore'), '');
    },
  };
}

export default defineConfig({
  root: 'apps/web',
  base: './',
  publicDir: '../../assets',
  server: { fs: { allow: ['../..'] } },
  build: { outDir: '../../dist', emptyOutDir: true },
  plugins: [godotIgnore()],
});
