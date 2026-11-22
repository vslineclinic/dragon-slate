import { expect, test } from 'vitest';
import type { RawGameData } from '../../packages/core/src/contracts/types.ts';
import { loadGameData } from '../../packages/core/src/data.ts';
import battle from '../../data/battle.json' with { type: 'json' };
import dragons from '../../data/dragons.json' with { type: 'json' };
import recipes from '../../data/recipes.json' with { type: 'json' };
import slot from '../../data/slot.json' with { type: 'json' };
import traits from '../../data/traits.json' with { type: 'json' };
import waves from '../../data/waves.json' with { type: 'json' };
import crossElementRecipe from './fixtures/bad-cross-element-t2.json' with { type: 'json' };
import duplicatePair from './fixtures/bad-duplicate-pair.json' with { type: 'json' };
import unknownRecipe from './fixtures/bad-unknown-id.json' with { type: 'json' };
import unreachableRecipe from './fixtures/bad-unreachable-species.json' with { type: 'json' };
import { lintData } from './lint.ts';

const realData = { dragons, traits, recipes, slot, waves, battle } as RawGameData;

test('real data passes', () => {
  expect(lintData(realData)).toEqual([]);
  const gameData = loadGameData(realData);
  expect(Object.keys(gameData.dragons)).toHaveLength(22);
  expect(Object.keys(gameData.traits)).toHaveLength(22);
  expect(gameData.recipes).toHaveLength(42);
});

test('detects duplicate pair', () => {
  expect(lintData({ ...realData, recipes: [...recipes, duplicatePair] })).toEqual([
    'recipe fire_wyvern+fire_drake -> fafnir: duplicate pair',
  ]);
});

test('detects unknown id', () => {
  expect(lintData({ ...realData, recipes: [...recipes, unknownRecipe] })).toEqual([
    'recipe fire_drake+ice_drake -> missing_dragon: unknown dragon id missing_dragon',
  ]);
});

test('detects unreachable species', () => {
  const remaining = recipes.filter((recipe) => recipe.result !== unreachableRecipe.result);
  expect(lintData({ ...realData, recipes: [...remaining, unreachableRecipe] })).toEqual([
    'unreachable species: beowulf_firedrake',
  ]);
});

test('detects cross-element t2 recipe', () => {
  expect(lintData({ ...realData, recipes: [...recipes, crossElementRecipe] })).toEqual([
    'recipe fire_drake+ice_wyvern -> beowulf_firedrake: element mismatch for t2 result',
  ]);
});

test('detects duplicate ids and unknown trait ids', () => {
  const raw = structuredClone(realData);
  const dragon = raw.dragons[0]!;
  raw.dragons.push({ ...dragon, traitId: 'tr_missing' });
  raw.traits.push(raw.traits[0]!);

  expect(lintData(raw)).toEqual([
    'duplicate trait id: tr_fire_drake',
    'duplicate dragon id: fire_drake',
    'dragon fire_drake: unknown traitId tr_missing',
  ]);
});

test('detects non-positive stats and weights and empty reroll costs', () => {
  const raw = structuredClone(realData);
  raw.dragons[0]!.stats.cooldownTicks = 0;
  raw.slot.weights.fire = -1;
  raw.slot.rerollCosts = [];

  expect(lintData(raw)).toEqual([
    'dragon fire_drake: cooldownTicks must be positive',
    'slot weight fire must be positive',
    'slot rerollCosts must not be empty',
  ]);
});
