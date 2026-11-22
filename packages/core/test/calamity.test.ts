import { describe, expect, test } from 'vitest';
import { applyCommand, createRun, spinCost, stateHash } from '../src/run.ts';
import { calamityMods } from '../src/calamity.ts';
import { loadGameData } from '../src/data.ts';
import { enemyPower } from '../src/waves.ts';
import type { CalamitySpec, DragonInst, GameData, RawGameData } from '../src/contracts/types.ts';
import dragons from '../../../data/dragons.json' with { type: 'json' };
import traits from '../../../data/traits.json' with { type: 'json' };
import recipes from '../../../data/recipes.json' with { type: 'json' };
import slot from '../../../data/slot.json' with { type: 'json' };
import waves from '../../../data/waves.json' with { type: 'json' };
import battle from '../../../data/battle.json' with { type: 'json' };
import calamity from '../../../data/calamity.json' with { type: 'json' };

const data: GameData = loadGameData({ dragons, traits, recipes, slot, waves, battle, calamity: calamity as CalamitySpec[] } as RawGameData);
const inst = (uid: number, speciesId: string): DragonInst => ({ uid, speciesId, traits: [], bonusPct: 0 });

describe('calamity levels', () => {
  test('calamity 0 changes nothing', () => {
    const a = createRun(data, 5).state;
    const b = createRun(data, 5, 0).state;
    expect(stateHash(b)).toBe(stateHash(a));
    expect(calamityMods(data, 0)).toEqual({ enemyPowerPct: 0, bossPowerPct: 0, winManaPct: 0, rerollCostAdd: 0, startLivesAdd: 0 });
  });

  test('level 1 raises enemy power 15%', () => {
    expect(enemyPower(data.waves, 3, calamityMods(data, 1))).toBe(Math.floor((enemyPower(data.waves, 3) * 115) / 100));
  });

  test('levels stack', () => {
    expect(calamityMods(data, 5)).toEqual({ enemyPowerPct: 30, bossPowerPct: 25, winManaPct: -20, rerollCostAdd: 1, startLivesAdd: -1 });
    expect(createRun(data, 5, 5).state).toMatchObject({ calamity: 5, lives: data.waves.startLives - 1 });
  });

  test('boss power adds on boss waves only', () => {
    const m = calamityMods(data, 3);
    expect(enemyPower(data.waves, 5, m)).toBe(Math.floor((Math.floor((enemyPower(data.waves, 5) * 115) / 100) * 125) / 100));
    expect(enemyPower(data.waves, 4, m)).toBe(Math.floor((enemyPower(data.waves, 4) * 115) / 100));
  });

  test('reroll cost add skips free first spin', () => {
    let s = { ...createRun(data, 5, 2).state, bench: [inst(1, 'fire_drake'), null, null, null], mana: 10 };
    const first = applyCommand(data, s, { type: 'spin' });
    expect(first.events).toContainEqual(expect.objectContaining({ t: 'spun', cost: 0 }));
    s = first.state;
    expect(applyCommand(data, s, { type: 'spin' }).events).toContainEqual(expect.objectContaining({ t: 'spun', cost: 3 }));
  });

  test('spinCost matches what spin charges', () => {
    const base = { ...createRun(data, 5, 2).state, bench: [inst(1, 'fire_drake'), null, null, null], mana: 10 };
    expect(spinCost(data, base)).toBe(0);
    const after = applyCommand(data, base, { type: 'spin' }).state;
    expect(spinCost(data, after)).toBe(3);
    expect(spinCost(data, { ...after, freeSpins: 1 })).toBe(0);
    expect(spinCost(data, { ...after, bench: [null, null, null, null] })).toBe(0);
  });

  test('win mana reduced at level 2', () => {
    const big = (uid: number) => ({ uid, speciesId: 'tiamat', traits: [], bonusPct: 400 });
    const s = { ...createRun(data, 5, 2).state, phase: 'manage' as const, nest: [big(1), big(2), null, null, null, null] };
    expect(applyCommand(data, s, { type: 'startBattle' }).events).toContainEqual({ t: 'mana', delta: 4, reason: 'win' });
  });

  test('start lives never below 1', () => {
    const d = { ...data, calamity: [{ level: 1, nameKo: 'x', descKo: 'x', startLivesAdd: -99 }] };
    expect(createRun(d, 1, 1).state.lives).toBe(1);
  });
});
