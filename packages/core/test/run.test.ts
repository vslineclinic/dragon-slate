import { describe, expect, test } from 'vitest';
import { applyCommand, createRun, stateHash } from '../src/run.ts';
import { loadGameData } from '../src/data.ts';
import { bossElement } from '../src/waves.ts';
import type { Command } from '../src/contracts/commands.ts';
import type { GameEvent } from '../src/contracts/events.ts';
import type { Cell, DragonInst, GameData, Grid, RawGameData, RunState, SymbolId } from '../src/contracts/types.ts';
import dragons from '../../../data/dragons.json' with { type: 'json' };
import traits from '../../../data/traits.json' with { type: 'json' };
import recipes from '../../../data/recipes.json' with { type: 'json' };
import slot from '../../../data/slot.json' with { type: 'json' };
import waves from '../../../data/waves.json' with { type: 'json' };
import battle from '../../../data/battle.json' with { type: 'json' };

const data: GameData = loadGameData({ dragons, traits, recipes, slot, waves, battle } as RawGameData);
const SPECIES: Record<string, string | null> = { fire: 'fire_drake', ice: 'ice_drake', lightning: 'storm_drake', wild: 'fire_drake', gold: null };

function gridOf(rows: SymbolId[][]): Grid {
  const reels: Cell[][] = [];
  for (let c = 0; c < 3; c++) {
    const reel: Cell[] = [{ symbol: 'gold', speciesId: null }];
    for (let r = 0; r < 3; r++) {
      const s = rows[r]![c]!;
      reel.push({ symbol: s, speciesId: SPECIES[s] ?? null });
    }
    reel.push({ symbol: 'gold', speciesId: null });
    reels.push(reel);
  }
  return { reels, offsets: [0, 0, 0] };
}

const inst = (uid: number, speciesId: string, bonusPct = 0): DragonInst => ({ uid, speciesId, traits: [], bonusPct });
const fresh = (seed = 1): RunState => createRun(data, seed).state;
const run = (s: RunState, cmd: Command) => applyCommand(data, s, cmd);
const rejected = (events: GameEvent[]) => events.find((e) => e.t === 'rejected');
const F = 'fire', I = 'ice', L = 'lightning';

describe('run state machine', () => {
  test('createRun previews first boss', () => {
    const { state, events } = createRun(data, 9);
    expect(state).toMatchObject({ wave: 1, phase: 'spin', lives: 5, mana: 3, nestOpen: 3 });
    expect(events).toContainEqual({ t: 'waveStart', wave: 1, bossPreview: bossElement(9, 5) });
  });

  test('pick before spin rejected wrongPhase', () => {
    const s = fresh();
    const r = run(s, { type: 'pick', index: 0 });
    expect(rejected(r.events)).toEqual({ t: 'rejected', reason: 'wrongPhase' });
    expect(r.state).toBe(s);
  });

  test('first spin free, second costs 2', () => {
    const a = run(fresh(), { type: 'spin' });
    expect(a.state.mana).toBe(3);
    expect(a.state.phase).toBe('pick');
    const b = run(a.state, { type: 'spin' });
    expect(b.state.mana).toBe(1);
  });

  test('reroll rejected without mana', () => {
    let s = run(fresh(), { type: 'spin' }).state;
    s = run(s, { type: 'spin' }).state;
    const r = run(s, { type: 'spin' });
    expect(rejected(r.events)).toEqual({ t: 'rejected', reason: 'notEnoughMana' });
  });

  test('nudge only once per wave', () => {
    const s = run(fresh(), { type: 'spin' }).state;
    const a = run(s, { type: 'nudge', col: 1, dir: 1 });
    expect(a.state.grid?.offsets).toEqual([0, 1, 0]);
    expect(rejected(run(a.state, { type: 'nudge', col: 0, dir: 1 }).events)).toEqual({ t: 'rejected', reason: 'noNudgeLeft' });
  });

  test('bonus eggs convert to mana when bench is full', () => {
    const s: RunState = { ...fresh(), phase: 'pick', grid: gridOf([[F, F, F], [I, L, I], [L, I, L]]), bench: [inst(1, 'fire_drake'), inst(2, 'fire_drake'), inst(3, 'fire_drake'), null], nextUid: 4 };
    const r = run(s, { type: 'pick', index: 0 });
    expect(r.state.bench[3]?.speciesId).toBe('ice_drake');
    expect(r.state.mana).toBe(3 + 2 + 1);
    expect(r.events).toContainEqual({ t: 'mana', delta: 1, reason: 'benchFull' });
    expect(r.state.phase).toBe('manage');
    expect(r.state.grid).toBeNull();
  });

  test('pick rejected when bench full', () => {
    const s: RunState = { ...fresh(), phase: 'pick', grid: gridOf([[I, L, I], [F, I, L], [L, F, F]]), bench: [inst(1, 'fire_drake'), inst(2, 'fire_drake'), inst(3, 'fire_drake'), inst(4, 'fire_drake')] };
    expect(rejected(run(s, { type: 'pick', index: 0 }).events)).toEqual({ t: 'rejected', reason: 'benchFull' });
  });

  test('two lines of one element give a t2 egg', () => {
    const s: RunState = { ...fresh(), phase: 'pick', grid: gridOf([[F, F, F], [F, L, I], [F, I, L]]) };
    const r = run(s, { type: 'pick', index: 1 });
    const bonus = r.events.find((e) => e.t === 'gained' && e.via === 'bonus');
    expect(bonus && bonus.t === 'gained' && data.dragons[bonus.inst.speciesId]?.tier).toBe('t2');
  });

  test('startBattle rejected when nest empty', () => {
    const s: RunState = { ...fresh(), phase: 'manage' };
    expect(rejected(run(s, { type: 'startBattle' }).events)).toEqual({ t: 'rejected', reason: 'nestEmpty' });
  });

  test('spin rejected during battle phase', () => {
    const s: RunState = { ...fresh(), phase: 'battle' };
    expect(rejected(run(s, { type: 'spin' }).events)).toEqual({ t: 'rejected', reason: 'wrongPhase' });
  });

  test('merge into locked nest slot rejected', () => {
    const s: RunState = { ...fresh(), phase: 'manage', bench: [inst(1, 'fire_drake'), null, null, null] };
    expect(rejected(run(s, { type: 'move', from: { zone: 'bench', index: 0 }, to: { zone: 'nest', index: 4 } }).events)).toEqual({ t: 'rejected', reason: 'slotLocked' });
    const t: RunState = { ...s, nest: [null, null, null, null, inst(2, 'fire_drake'), null] };
    expect(rejected(run(t, { type: 'merge', main: { zone: 'nest', index: 4 }, material: { zone: 'bench', index: 0 } }).events)).toEqual({ t: 'rejected', reason: 'slotLocked' });
  });

  test('first evolution marks discovered once', () => {
    let s: RunState = { ...fresh(), phase: 'manage', bench: [inst(1, 'fire_drake'), inst(2, 'fire_drake'), inst(3, 'fire_drake'), inst(4, 'fire_drake')], nextUid: 5 };
    const a = run(s, { type: 'merge', main: { zone: 'bench', index: 0 }, material: { zone: 'bench', index: 1 } });
    expect(a.events).toContainEqual(expect.objectContaining({ t: 'evolved', firstTime: true }));
    expect(a.state.bench[0]?.speciesId).toBe('beowulf_firedrake');
    expect(a.state.bench[1]).toBeNull();
    s = a.state;
    const b = run(s, { type: 'merge', main: { zone: 'bench', index: 2 }, material: { zone: 'bench', index: 3 } });
    expect(b.events).toContainEqual(expect.objectContaining({ t: 'evolved', firstTime: false }));
    expect(b.state.discovered).toEqual(['beowulf_firedrake']);
  });

  test('release gives mana by tier', () => {
    const s: RunState = { ...fresh(), phase: 'manage', bench: [inst(1, 'fafnir'), null, null, null] };
    const r = run(s, { type: 'release', from: { zone: 'bench', index: 0 } });
    expect(r.state.mana).toBe(3 + 2);
    expect(r.state.bench[0]).toBeNull();
  });

  test('boss loss costs 2 lives and nest unlocks after wave 5', () => {
    const s: RunState = { ...fresh(), wave: 5, phase: 'manage', nest: [inst(1, 'fire_wyvern'), null, null, null, null, null] };
    const r = run(s, { type: 'startBattle' });
    expect(r.state.lives).toBe(3);
    expect(r.state.nestOpen).toBe(4);
    expect(r.state.wave).toBe(6);
    expect(r.state.phase).toBe('spin');
    expect(r.events).toContainEqual({ t: 'waveStart', wave: 6, bossPreview: bossElement(s.seed, 10) });
  });

  test('lives zero ends run', () => {
    const s: RunState = { ...fresh(), wave: 4, lives: 1, phase: 'manage', nest: [inst(1, 'fire_wyvern'), null, null, null, null, null] };
    const r = run(s, { type: 'startBattle' });
    expect(r.state.phase).toBe('gameOver');
    expect(r.events).toContainEqual({ t: 'gameOver' });
  });

  test('victory after winning maxWave', () => {
    const big = (uid: number) => inst(uid, 'tiamat', 300);
    const s: RunState = { ...fresh(), wave: 10, phase: 'manage', nestOpen: 5, nest: [big(1), big(2), big(3), null, null, null] };
    const r = run(s, { type: 'startBattle' });
    expect(r.state.phase).toBe('victory');
    expect(r.events).toContainEqual({ t: 'victory' });
  });

  test('replay determinism', () => {
    const script = (start: RunState) => {
      let s = start;
      for (let i = 0; i < 30 && s.phase !== 'gameOver' && s.phase !== 'victory'; i++) {
        let cmd: Command;
        if (s.phase === 'spin') cmd = { type: 'spin' };
        else if (s.phase === 'pick') cmd = { type: 'pick', index: (i % 3) as 0 | 1 | 2 };
        else {
          const from = s.bench.findIndex((b) => b !== null);
          const to = s.nest.findIndex((n, idx) => n === null && idx < s.nestOpen);
          cmd = from >= 0 && to >= 0 ? { type: 'move', from: { zone: 'bench', index: from }, to: { zone: 'nest', index: to } } : { type: 'startBattle' };
        }
        s = run(s, cmd).state;
      }
      return s;
    };
    const a = script(fresh(77));
    const b = script(fresh(77));
    expect(stateHash(a)).toBe(stateHash(b));
    let c = fresh(77);
    for (const cmd of a.log) c = run(c, cmd).state;
    expect(stateHash(c)).toBe(stateHash(a));
    expect(a.log.length).toBeGreaterThan(10);
  });
});
