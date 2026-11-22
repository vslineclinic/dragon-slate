import { describe, expect, test } from 'vitest';
import { createRng } from '../src/rng.ts';
import { evaluateLines, nudge, offersFrom, spinGrid, visible } from '../src/slot.ts';
import { gridFrom, testData } from './helpers.ts';

const F = 'fire', I = 'ice', L = 'lightning', G = 'gold', W = 'wild';

describe('rune slab', () => {
  test('detects horizontal line with wild substitute', () => {
    const g = gridFrom([[G, I, L], [F, W, F], [I, G, L]]);
    expect(evaluateLines(g)).toEqual([{ lines: [1], element: 'fire' }]);
  });

  test('detects two lines sharing a cell', () => {
    const g = gridFrom([[I, I, I], [I, F, L], [I, L, F]]);
    expect(evaluateLines(g)).toEqual([{ lines: [0, 3], element: 'ice' }]);
  });

  test('gold breaks element line', () => {
    const g = gridFrom([[F, G, F], [I, L, I], [L, I, L]]);
    expect(evaluateLines(g)).toEqual([]);
  });

  test('three gold is gold line', () => {
    const g = gridFrom([[G, G, G], [I, L, F], [L, F, I]]);
    expect(evaluateLines(g)).toEqual([{ lines: [0], element: 'gold' }]);
  });

  test('three wild is wild line', () => {
    const g = gridFrom([[I, L, F], [W, W, W], [L, I, L]]);
    expect(evaluateLines(g)).toEqual([{ lines: [1], element: 'wild' }]);
  });

  test('nudge shifts visible window and clamps', () => {
    const g = gridFrom([[F, I, L], [I, L, F], [L, F, I]]);
    const up = nudge(g, 0, -1);
    expect(up.offsets).toEqual([-1, 0, 0]);
    expect(visible(up, 0, 0).symbol).toBe('gold');
    expect(visible(up, 0, 1).symbol).toBe('fire');
    expect(nudge(up, 0, -1).offsets).toEqual([-1, 0, 0]);
    expect(g.offsets).toEqual([0, 0, 0]);
  });

  test('forceLine guarantees a line', () => {
    const d = testData();
    for (let seed = 1; seed <= 1000; seed++) {
      expect(evaluateLines(spinGrid(d, createRng(seed), true)).length).toBeGreaterThanOrEqual(1);
    }
  });

  test('offers come from visible center row after nudge', () => {
    const d = testData();
    const g = gridFrom([[F, I, L], [I, G, F], [L, F, I]]);
    expect(offersFrom(d, g)).toEqual([
      { kind: 'egg', speciesId: 'ice_x' },
      { kind: 'mana', amount: 3 },
      { kind: 'egg', speciesId: 'fire_x' },
    ]);
    const shifted = nudge(g, 0, 1);
    expect(offersFrom(d, shifted)[0]).toEqual({ kind: 'egg', speciesId: 'lightning_x' });
  });

  test('spun cells carry species of their element', () => {
    const d = testData();
    const g = spinGrid(d, createRng(3), false);
    for (const reel of g.reels) {
      expect(reel).toHaveLength(5);
      for (const cell of reel) {
        if (cell.symbol === 'gold') expect(cell.speciesId).toBeNull();
        else if (cell.symbol === 'wild') expect(d.dragons[cell.speciesId!]?.tier).toBe('base');
        else expect(d.dragons[cell.speciesId!]?.elements[0]).toBe(cell.symbol);
      }
    }
  });

  test('hit rate is sane', () => {
    const d = testData();
    const rng = createRng(11);
    let hits = 0;
    for (let i = 0; i < 10000; i++) if (evaluateLines(spinGrid(d, rng, false)).length > 0) hits++;
    expect(hits / 10000).toBeGreaterThan(0.25);
    expect(hits / 10000).toBeLessThan(0.75);
  });
});
