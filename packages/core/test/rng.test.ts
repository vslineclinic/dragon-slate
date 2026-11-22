import { describe, expect, test } from 'vitest';
import { createRng } from '../src/rng.ts';

describe('rng', () => {
  test('same seed gives same sequence', () => {
    const a = createRng(42);
    const b = createRng(42);
    for (let i = 0; i < 1000; i++) expect(a.nextU32()).toBe(b.nextU32());
  });

  test('state restore continues sequence', () => {
    const r = createRng(42);
    for (let i = 0; i < 100; i++) r.nextU32();
    const copy = createRng(42, r.state());
    expect(copy.nextU32()).toBe(r.nextU32());
  });

  test('nextInt stays in range', () => {
    const r = createRng(7);
    const seen = new Set<number>();
    for (let i = 0; i < 10000; i++) {
      const v = r.nextInt(6);
      expect(v).toBeGreaterThanOrEqual(0);
      expect(v).toBeLessThan(6);
      seen.add(v);
    }
    expect(seen.size).toBe(6);
  });

  test('pickWeighted follows weights', () => {
    const r = createRng(9);
    const items = [{ w: 1 }, { w: 3 }];
    let second = 0;
    for (let i = 0; i < 40000; i++) if (r.pickWeighted(items, (x) => x.w) === items[1]) second++;
    const ratio = second / 40000;
    expect(ratio).toBeGreaterThan(0.72);
    expect(ratio).toBeLessThan(0.78);
  });
});
