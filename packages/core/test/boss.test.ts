import { describe, expect, test } from 'vitest';
import { simulateBattle } from '../src/battle.ts';
import type { Unit } from '../src/contracts/events.ts';
import { testData } from './helpers.ts';

const cfg = testData().battle;
const u = (hp: number, atk: number, cd: number, lifestealPct = 0): Unit => ({ speciesId: 'x', elements: ['fire'], hp, atk, cooldownTicks: cd, lifestealPct });
const wall = () => u(100000, 1, 100000);

describe('boss rules', () => {
  test('burn hits lowest hp ally every N ticks', () => {
    const r = simulateBattle(cfg, [u(100, 1, 100000), u(50, 1, 100000)], [wall()], { burn: { everyTicks: 10, pct: 8 } });
    const burns = r.events.filter((e) => e.kind === 'hazard');
    expect(burns[0]).toEqual({ tick: 10, kind: 'hazard', name: 'burn', idx: 1, dmg: 4 });
    expect(burns[1]).toMatchObject({ tick: 20, idx: 1 });
  });

  test('rowBlast alternates front and back rows', () => {
    const r = simulateBattle(cfg, [u(100, 1, 100000), null, null, u(100, 1, 100000)], [wall()], { rowBlast: { everyTicks: 10, pct: 10 } });
    const hz = r.events.filter((e) => e.kind === 'hazard');
    expect(hz[0]).toEqual({ tick: 10, kind: 'hazard', name: 'rowBlast', idx: 0, dmg: 10 });
    expect(hz[1]).toEqual({ tick: 20, kind: 'hazard', name: 'rowBlast', idx: 3, dmg: 10 });
  });

  test('ally slow lengthens cooldown', () => {
    const r = simulateBattle(cfg, [u(100, 5, 10)], [wall()], { allySlowPct: 50 });
    expect(r.events.find((e) => e.kind === 'attack')).toMatchObject({ tick: 15, side: 'ally' });
  });

  test('enrage multiplies enemy damage after tick', () => {
    const r = simulateBattle(cfg, [u(1000, 1, 100000)], [u(100000, 10, 10)], { enrage: { atTick: 15, atkPct: 200 } });
    const hits = r.events.filter((e) => e.kind === 'attack' && e.side === 'enemy');
    expect(hits[0]).toMatchObject({ tick: 10, dmg: 10 });
    expect(hits[1]).toMatchObject({ tick: 20, dmg: 20 });
    expect(r.events.filter((e) => e.kind === 'enrage')).toEqual([{ tick: 15, kind: 'enrage' }]);
  });

  test('heal cut reduces lifesteal', () => {
    const r = simulateBattle(cfg, [u(100, 20, 10, 50)], [u(100000, 30, 5)], { healCutPct: 50, healCutFromTick: 0 });
    const ally = r.events.filter((e) => e.kind === 'attack' && e.side === 'ally');
    expect(ally[0]).toMatchObject({ tick: 10, heal: 5 });
  });

  test('hazard kills emit single death and end battle', () => {
    const r = simulateBattle(cfg, [u(10, 1, 100000)], [wall()], { pulse: { everyTicks: 5, pct: 100 } });
    expect(r.events.filter((e) => e.kind === 'death')).toEqual([{ tick: 5, kind: 'death', side: 'ally', idx: 0 }]);
    expect(r.winner).toBe('enemy');
    expect(r.ticks).toBe(5);
  });

  test('no rules means unchanged result', () => {
    const a = [u(300, 12, 10), u(200, 15, 13)];
    const e = [u(250, 11, 9), u(220, 14, 17)];
    expect(JSON.stringify(simulateBattle(cfg, a, e, {}))).toBe(JSON.stringify(simulateBattle(cfg, a, e)));
  });
});
