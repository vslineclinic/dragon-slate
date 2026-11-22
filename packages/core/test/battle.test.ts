import { describe, expect, test } from 'vitest';
import { elementMult, simulateBattle, toUnit } from '../src/battle.ts';
import type { Unit } from '../src/contracts/events.ts';
import type { Element } from '../src/contracts/types.ts';
import { testData } from './helpers.ts';

const cfg = testData().battle;
const u = (el: Element, hp: number, atk: number, cd = 10, lifestealPct = 0): Unit => ({ speciesId: 'x', elements: [el], hp, atk, cooldownTicks: cd, lifestealPct });

describe('battle', () => {
  test('fire beats ice 135', () => {
    expect(elementMult(cfg, 'fire', 'ice')).toBe(135);
    expect(elementMult(cfg, 'ice', 'lightning')).toBe(135);
    expect(elementMult(cfg, 'lightning', 'fire')).toBe(135);
    expect(elementMult(cfg, 'fire', 'fire')).toBe(100);
  });

  test('ice vs fire 75', () => {
    expect(elementMult(cfg, 'ice', 'fire')).toBe(75);
  });

  test('first hit uses element multiplier and floor', () => {
    const r = simulateBattle(cfg, [u('fire', 100, 10)], [u('ice', 1000, 1, 1000)]);
    const first = r.events.find((e) => e.kind === 'attack' && e.side === 'ally');
    expect(first).toMatchObject({ tick: 10, src: 0, dst: 0, dmg: 13, mult: 135 });
  });

  test('targets front row first', () => {
    const enemies = [null, null, u('fire', 50, 1, 1000), u('fire', 50, 1, 1000)];
    const r = simulateBattle(cfg, [u('fire', 100, 10)], enemies);
    const first = r.events.find((e) => e.kind === 'attack' && e.side === 'ally');
    expect(first).toMatchObject({ dst: 2 });
  });

  test('timeout is enemy win', () => {
    const r = simulateBattle(cfg, [u('fire', 10000, 1, 100)], [u('fire', 10000, 1, 100)]);
    expect(r.winner).toBe('enemy');
    expect(r.ticks).toBe(cfg.maxTicks);
  });

  test('lifesteal heals but not over max', () => {
    const r = simulateBattle(cfg, [u('fire', 100, 20, 10, 50)], [u('fire', 1000, 30, 15)]);
    const heals = r.events.filter((e) => e.kind === 'attack' && e.side === 'ally');
    expect(heals[0]).toMatchObject({ heal: 0 });
    expect(heals[1]).toMatchObject({ heal: 10 });
  });

  test('haste shortens cooldown with floor 5', () => {
    const d = testData();
    d.traits['tr_haste'] = { id: 'tr_haste', nameKo: 'h', kind: 'hastePct', value: 99 };
    const unit = toUnit(d, { uid: 1, speciesId: 'fire_drake', traits: ['tr_haste'], bonusPct: 0 });
    expect(unit.cooldownTicks).toBe(5);
  });

  test('toUnit applies bonus and stat traits', () => {
    const d = testData();
    d.traits['tr_hp'] = { id: 'tr_hp', nameKo: 'h', kind: 'hpPct', value: 20 };
    d.traits['tr_ls'] = { id: 'tr_ls', nameKo: 'l', kind: 'lifestealPct', value: 15 };
    const unit = toUnit(d, { uid: 1, speciesId: 'fire_drake', traits: ['tr_hp', 'tr_ls'], bonusPct: 10 });
    // fire_drake: hp 130 atk 8; 고유 특성 tr_ember(atkPct 10)는 종 자체 특성이라 늘 적용
    expect(unit).toEqual({ speciesId: 'fire_drake', elements: ['fire'], hp: 169, atk: 9, cooldownTicks: 20, lifestealPct: 15 });
  });

  test('identical input identical events', () => {
    const a = simulateBattle(cfg, [u('fire', 300, 12), u('ice', 200, 15, 13)], [u('lightning', 250, 11, 9), u('ice', 220, 14, 17)]);
    const b = simulateBattle(cfg, [u('fire', 300, 12), u('ice', 200, 15, 13)], [u('lightning', 250, 11, 9), u('ice', 220, 14, 17)]);
    expect(JSON.stringify(a)).toBe(JSON.stringify(b));
  });

  test('death event emitted once', () => {
    const r = simulateBattle(cfg, [u('fire', 100, 50, 5)], [u('fire', 60, 1, 1000)]);
    expect(r.events.filter((e) => e.kind === 'death')).toEqual([{ tick: 10, kind: 'death', side: 'enemy', idx: 0 }]);
    expect(r.winner).toBe('ally');
  });
});
