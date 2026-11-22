import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { expect, test } from 'vitest';

const forbidden = [
  /phaser/i,
  /\bdocument\b/,
  /\bwindow\b/,
  /\blocalStorage\b/,
  /\bMath\.(?:random|sin|cos|tan|pow|exp|log|sqrt)\b/,
  /\bDate\.now\b/,
  /\bperformance\.now\b/,
];

test('core source has no forbidden tokens', () => {
  const sourceDir = fileURLToPath(new URL('../src/', import.meta.url));
  const violations: string[] = [];

  for (const entry of readdirSync(sourceDir, { recursive: true, withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith('.ts')) continue;
    const path = join(entry.parentPath, entry.name);
    const source = readFileSync(path, 'utf8');
    for (const pattern of forbidden) {
      const matches = source.matchAll(new RegExp(pattern, pattern.flags + 'g'));
      for (const [token] of matches) violations.push(`${path}: ${token}`);
    }
  }

  expect(violations, violations.join('\n')).toEqual([]);
});
