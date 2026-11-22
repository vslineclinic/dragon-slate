import { describe, expect, test } from 'vitest';
import { applyCommand, createRun } from '../src/run.ts';
import { loadGameData } from '../src/data.ts';
import type { GameEvent } from '../src/contracts/events.ts';
import type { DragonInst, GameData, RawGameData, RewardSpec, RunState } from '../src/contracts/types.ts';
import dragons from '../../../data/dragons.json' with { type: 'json' };
import traits from '../../../data/traits.json' with { type: 'json' };
import recipes from '../../../data/recipes.json' with { type: 'json' };
import slot from '../../../data/slot.json' with { type: 'json' };
import waves from '../../../data/waves.json' with { type: 'json' };
import battle from '../../../data/battle.json' with { type: 'json' };
import rewards from '../../../data/rewards.json' with { type: 'json' };

const make = (rw: RewardSpec[]): GameData => loadGameData({ dragons, traits, recipes, slot, waves, battle, rewards: rw } as RawGameData);
const only = (kind: RewardSpec['kind'], amount = 1): RewardSpec[] => [{ id: kind, nameKo: kind, kind, amount, weight: 1, bossWeight: 1 }];
const big = (uid: number, bonusPct = 300): DragonInst => ({ uid, speciesId: 'tiamat', traits: [], bonusPct });
const winState = (d: GameData, wave = 2): RunState => ({ ...createRun(d, 3).state, wave, phase: 'manage', nest: [big(1), big(2), null, null, null, null] });
const rewardOf = (ev: GameEvent[]) => ev.find((e) => e.t === 'reward');

describe('wave rewards', () => {
  test('real reward table loads and a win grants exactly one reward', () => {
    const d = make(rewards as RewardSpec[]);
    const r = applyCommand(d, winState(d), { type: 'startBattle' });
    expect(r.events.filter((e) => e.t === 'reward')).toHaveLength(1);
  });

  test('loss gives no reward', () => {
    const d = make(only('mana'));
    const s: RunState = { ...createRun(d, 3).state, wave: 4, phase: 'manage', nest: [{ uid: 1, speciesId: 'fire_wyvern', traits: [], bonusPct: 0 }, null, null, null, null, null] };
    expect(rewardOf(applyCommand(d, s, { type: 'startBattle' }).events)).toBeUndefined();
  });

  test('boss win uses boss weights', () => {
    const rw: RewardSpec[] = [
      { id: 'a', nameKo: 'a', kind: 'mana', amount: 1, weight: 1, bossWeight: 0 },
      { id: 'b', nameKo: 'b', kind: 't2egg', amount: 1, weight: 0, bossWeight: 1 },
    ];
    const d = make(rw);
    expect(rewardOf(applyCommand(d, winState(d, 5), { type: 'startBattle' }).events)).toMatchObject({ reward: { id: 'b' } });
    expect(rewardOf(applyCommand(d, winState(d, 2), { type: 'startBattle' }).events)).toMatchObject({ reward: { id: 'a' } });
  });

  test('egg reward lands on the bench', () => {
    const d = make(only('t2egg'));
    const r = applyCommand(d, winState(d), { type: 'startBattle' });
    const egg = r.state.bench.find((b) => b);
    expect(egg && d.dragons[egg.speciesId]?.tier).toBe('t2');
  });

  test('nudge reward adds a nudge next wave', () => {
    const d = make(only('nudge'));
    const r = applyCommand(d, winState(d), { type: 'startBattle' });
    expect(r.state.nudgesLeft).toBe(d.slot.nudgesPerWave + 1);
  });

  test('free spin reward makes next paid reroll free', () => {
    const d = make(only('freeSpin'));
    let s = applyCommand(d, winState(d), { type: 'startBattle' }).state;
    s = { ...s, mana: 0 };
    s = applyCommand(d, s, { type: 'spin' }).state; // 웨이브 첫 스핀은 원래 무료
    const r = applyCommand(d, s, { type: 'spin' });
    expect(r.events).toContainEqual(expect.objectContaining({ t: 'spun', cost: 0 }));
    expect(r.state.freeSpins).toBe(0);
  });

  test('life reward at full lives turns into mana', () => {
    const d = make(only('life'));
    const s = winState(d);
    const r = applyCommand(d, s, { type: 'startBattle' });
    expect(r.state.lives).toBe(d.waves.startLives);
    expect(r.events).toContainEqual({ t: 'mana', delta: 3, reason: 'reward' });
    const hurt = applyCommand(d, { ...s, lives: 2 }, { type: 'startBattle' });
    expect(hurt.state.lives).toBe(3);
  });

  test('trait reward adds a new trait to a nest dragon', () => {
    const d = make(only('trait'));
    const r = applyCommand(d, winState(d), { type: 'startBattle' });
    const traitsNow = r.state.nest.filter((n) => n).flatMap((n) => n!.traits);
    expect(traitsNow).toHaveLength(1);
    expect(traitsNow[0]).not.toBe(d.dragons['tiamat']!.traitId);
  });

  test('no reward on final victory', () => {
    const d = make(only('mana'));
    const r = applyCommand(d, { ...winState(d, d.waves.maxWave), nest: [big(1, 5000), big(2, 5000), null, null, null, null] }, { type: 'startBattle' });
    expect(r.state.phase).toBe('victory');
    expect(rewardOf(r.events)).toBeUndefined();
  });
});
