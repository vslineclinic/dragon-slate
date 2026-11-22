import { describe, expect, test } from 'vitest';
import { loadGameData } from '../src/data.ts';
import type { RawGameData } from '../src/contracts/types.ts';
import mini from '../../../data/fixtures/mini.json' with { type: 'json' };

const clone = () => structuredClone(mini) as RawGameData;

describe('loadGameData', () => {
  test('loads mini fixture', () => {
    const d = loadGameData(clone());
    expect(Object.keys(d.dragons)).toHaveLength(3);
    expect(d.recipes).toHaveLength(1);
    expect(d.traits['tr_ember']?.kind).toBe('atkPct');
  });

  test('throws on unknown recipe id', () => {
    const raw = clone();
    raw.recipes[0]!.result = 'nope';
    expect(() => loadGameData(raw)).toThrow(/nope/);
  });

  test('throws on unknown traitId', () => {
    const raw = clone();
    raw.dragons[0]!.traitId = 'tr_missing';
    expect(() => loadGameData(raw)).toThrow(/tr_missing/);
  });
});
