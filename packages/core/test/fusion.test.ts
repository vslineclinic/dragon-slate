import { describe, expect, test } from 'vitest';
import { findRecipe, merge, mergePreview } from '../src/fusion.ts';
import type { DragonInst, DragonSpec, GameData, Tier } from '../src/contracts/types.ts';
import { testData } from './helpers.ts';

function data(): GameData {
  const d = testData();
  const add = (id: string, tier: Tier, el: DragonSpec['elements'], traitId: string) => {
    d.dragons[id] = { id, nameKo: id, tier, elements: el, role: 'support', stats: { hp: 200, atk: 20, cooldownTicks: 20 }, traitId };
    d.traits[traitId] = { id: traitId, nameKo: traitId, kind: 'hpPct', value: 15 };
  };
  add('fafnir', 't2', ['fire'], 'tr_fafnir');
  add('xiuhcoatl', 't2', ['fire'], 'tr_xiuh');
  add('zhulong', 't1', ['fire'], 'tr_zhu');
  add('palraiyuk', 't2', ['ice'], 'tr_pal');
  add('thermal_dragon', 'dual', ['fire', 'ice'], 'tr_thermal');
  d.dragons['ice_drake']!.traitId = 'tr_icy';
  d.traits['tr_icy'] = { id: 'tr_icy', nameKo: 'icy', kind: 'hastePct', value: 10 };
  d.recipes.push(
    { a: 'fire_drake', b: 'fire_wyvern', result: 'fafnir' },
    { a: 'fafnir', b: 'xiuhcoatl', result: 'zhulong' },
    { a: 'fafnir', b: 'palraiyuk', result: 'thermal_dragon' },
  );
  return d;
}

const inst = (uid: number, speciesId: string, traits: string[] = [], bonusPct = 0): DragonInst => ({ uid, speciesId, traits, bonusPct });

describe('fusion', () => {
  test('A+A evolves to t2', () => {
    const r = merge(data(), inst(1, 'fire_drake'), inst(2, 'fire_drake'), 9);
    expect(r).toEqual({ inst: { uid: 9, speciesId: 'beowulf_firedrake', traits: [], bonusPct: 0 }, kind: 'evolve', trait: null });
  });

  test('order does not matter', () => {
    const d = data();
    expect(findRecipe(d, 'fire_wyvern', 'fire_drake')).toBe('fafnir');
    expect(findRecipe(d, 'fire_drake', 'fire_wyvern')).toBe('fafnir');
    expect(findRecipe(d, 'fire_wyvern', 'fire_wyvern')).toBeUndefined();
  });

  test('t2 pair evolves to t1', () => {
    expect(mergePreview(data(), inst(1, 'xiuhcoatl'), inst(2, 'fafnir'))).toEqual({ kind: 'evolve', result: 'zhulong' });
  });

  test('cross element t2 gives dual', () => {
    expect(merge(data(), inst(1, 'palraiyuk'), inst(2, 'fafnir'), 5).inst.speciesId).toBe('thermal_dragon');
  });

  test('no recipe absorbs trait and bonus', () => {
    const r = merge(data(), inst(1, 'fafnir'), inst(2, 'ice_drake'), 9);
    expect(r).toEqual({ inst: { uid: 1, speciesId: 'fafnir', traits: ['tr_icy'], bonusPct: 12 }, kind: 'absorb', trait: 'tr_icy' });
    expect(mergePreview(data(), inst(1, 'fafnir'), inst(2, 'ice_drake'))).toEqual({ kind: 'absorb', trait: 'tr_icy' });
  });

  test('absorb skips duplicate trait', () => {
    const r = merge(data(), inst(1, 'fafnir', ['tr_icy'], 12), inst(2, 'ice_drake'), 9);
    expect(r.inst).toEqual({ uid: 1, speciesId: 'fafnir', traits: ['tr_icy'], bonusPct: 24 });
    expect(r.trait).toBeNull();
  });

  test('absorb respects maxTraits but still adds bonus', () => {
    const r = merge(data(), inst(1, 'zhulong', ['tr_a', 'tr_b'], 0), inst(2, 'fafnir'), 9);
    expect(r.inst).toEqual({ uid: 1, speciesId: 'zhulong', traits: ['tr_a', 'tr_b'], bonusPct: 25 });
    expect(r.trait).toBeNull();
  });

  test('absorb does not copy main species own trait', () => {
    const r = merge(data(), inst(1, 'fafnir'), inst(2, 'fafnir'), 9);
    expect(r.trait).toBeNull();
    expect(r.inst.traits).toEqual([]);
  });

  test('evolve keeps main traits and resets bonus', () => {
    const r = merge(data(), inst(1, 'fire_drake', ['tr_icy'], 36), inst(2, 'fire_drake', ['tr_x'], 12), 7);
    expect(r.inst).toEqual({ uid: 7, speciesId: 'beowulf_firedrake', traits: ['tr_icy'], bonusPct: 0 });
  });
});
