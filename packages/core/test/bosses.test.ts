import { describe, expect, test } from 'vitest';
import { applyCommand, createRun } from '../src/run.ts';
import { loadGameData } from '../src/data.ts';
import type { BossSpec, DragonInst, GameData, RawGameData, RunState } from '../src/contracts/types.ts';
import dragons from '../../../data/dragons.json' with { type: 'json' };
import traits from '../../../data/traits.json' with { type: 'json' };
import recipes from '../../../data/recipes.json' with { type: 'json' };
import slot from '../../../data/slot.json' with { type: 'json' };
import waves from '../../../data/waves.json' with { type: 'json' };
import battle from '../../../data/battle.json' with { type: 'json' };
import bosses from '../../../data/bosses.json' with { type: 'json' };

const data: GameData = loadGameData({ dragons, traits, recipes, slot, waves, battle, bosses: bosses as BossSpec[] } as RawGameData);
const inst = (uid: number, speciesId: string, bonusPct = 0): DragonInst => ({ uid, speciesId, traits: [], bonusPct });
const at = (wave: number, nest: (DragonInst | null)[]): RunState => ({ ...createRun(data, 3).state, wave, phase: 'manage', nestOpen: 6, nest });

describe('judgement bosses', () => {
  test('boss data loads four bosses', () => {
    expect(data.bosses.map((b) => b.wave)).toEqual([5, 10, 15, 20]);
  });

  test('boss wave passes its rules to battle', () => {
    const team = [inst(1, 'palraiyuk', 400), inst(2, 'palraiyuk', 400), null, inst(3, 'palraiyuk', 400), null, null];
    const r = applyCommand(data, at(10, team), { type: 'startBattle' });
    const fight = r.events.find((e) => e.t === 'battle');
    expect(fight && fight.t === 'battle' && fight.result.events.some((e) => e.kind === 'hazard' && e.name === 'rowBlast')).toBe(true);
  });

  test('normal wave has no hazards', () => {
    const r = applyCommand(data, at(7, [inst(1, 'tiamat', 100), null, null, null, null, null]), { type: 'startBattle' });
    const fight = r.events.find((e) => e.t === 'battle');
    expect(fight && fight.t === 'battle' && fight.result.events.some((e) => e.kind === 'hazard')).toBe(false);
  });

  test('waveStart previews boss spec on waves 1 6 11 16', () => {
    expect(createRun(data, 3).events).toContainEqual(expect.objectContaining({ t: 'waveStart', wave: 1, boss: expect.objectContaining({ wave: 5, nameKo: '홍염의 가뭄' }) }));
    const r = applyCommand(data, at(15, [inst(1, 'tiamat', 400), inst(2, 'tiamat', 400), null, null, null, null]), { type: 'startBattle' });
    expect(r.events).toContainEqual(expect.objectContaining({ t: 'waveStart', wave: 16, boss: expect.objectContaining({ wave: 20 }) }));
    const mid = applyCommand(data, at(2, [inst(1, 'tiamat', 400), null, null, null, null, null]), { type: 'startBattle' });
    expect(mid.events).toContainEqual(expect.objectContaining({ t: 'waveStart', wave: 3, boss: null }));
  });

  test('run lasts 20 waves', () => {
    expect(data.waves.maxWave).toBe(20);
    const r = applyCommand(data, at(10, [inst(1, 'tiamat', 400), inst(2, 'tiamat', 400), null, null, null, null]), { type: 'startBattle' });
    expect(r.state.wave).toBe(11);
  });

  test('nest unlocks after 15', () => {
    const s = { ...at(15, [inst(1, 'tiamat', 400), inst(2, 'tiamat', 400), null, null, null, null]), nestOpen: 5 };
    expect(applyCommand(data, s, { type: 'startBattle' }).state.nestOpen).toBe(6);
  });
});
