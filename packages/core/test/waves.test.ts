import { describe, expect, test } from 'vitest';
import { bossElement, enemyPower, generateEnemies, isBoss, unitPower } from '../src/waves.ts';
import { createRng } from '../src/rng.ts';
import type { GameData, Tier } from '../src/contracts/types.ts';
import { testData } from './helpers.ts';

function data(): GameData {
  const d = testData();
  const add = (id: string, tier: Tier, el: 'fire' | 'ice' | 'lightning') => {
    d.dragons[id] = { id, nameKo: id, tier, elements: [el], role: 'support', stats: { hp: 480, atk: 48, cooldownTicks: 18 }, traitId: 'tr_ember' };
  };
  add('zhulong', 't1', 'fire');
  add('kuraokami', 't1', 'ice');
  add('yinglong', 't1', 'lightning');
  add('palraiyuk', 't2', 'ice');
  return d;
}

const EL3 = ['fire', 'ice', 'lightning'] as const;

describe('waves', () => {
  test('power wave1=100 wave2=118 wave3=139', () => {
    const cfg = data().waves;
    expect(enemyPower(cfg, 1)).toBe(100);
    expect(enemyPower(cfg, 2)).toBe(118);
    expect(enemyPower(cfg, 3)).toBe(139);
  });

  test('boss wave5 applies 165', () => {
    const cfg = data().waves;
    // 100→118→139→164→193, ×165% = 318
    expect(enemyPower(cfg, 5)).toBe(318);
  });

  test('isBoss 5 and 10 only within maxWave 10', () => {
    const cfg = data().waves;
    const bosses = [];
    for (let w = 1; w <= 20; w++) if (isBoss(cfg, w)) bosses.push(w);
    expect(bosses).toEqual([5, 10]);
  });

  test('bossElement stable per seed', () => {
    expect(bossElement(123, 5, EL3)).toBe(bossElement(123, 5, EL3));
    const seen = new Set<string>();
    for (let s = 1; s <= 50; s++) seen.add(bossElement(s, 10, EL3));
    expect(seen.size).toBe(3);
  });

  test('enemy total power within 10% of target', () => {
    const d = data();
    for (const wave of [1, 3, 6, 9]) {
      const units = generateEnemies(d, wave, createRng(wave), 77);
      expect(units).toHaveLength(Math.min(1 + Math.floor(wave / 2), 6));
      const total = units.reduce((s, x) => s + unitPower(x), 0);
      const target = enemyPower(d.waves, wave);
      expect(Math.abs(total - target) / target).toBeLessThan(0.1);
    }
  });

  test('early waves use base species only', () => {
    const d = data();
    for (const u of generateEnemies(d, 4, createRng(4), 1)) expect(d.dragons[u.speciesId]?.tier).toBe('base');
  });

  test('boss slot 0 is t1 of boss element', () => {
    const d = data();
    const units = generateEnemies(d, 10, createRng(1), 42);
    const spec = d.dragons[units[0]!.speciesId]!;
    expect(spec.tier).toBe('t1');
    expect(spec.elements[0]).toBe(bossElement(42, 10, EL3));
  });
});
