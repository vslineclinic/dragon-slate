import { expect, test } from 'vitest';
import { ELEMENTS, type Element, type RawGameData } from '../../packages/core/src/contracts/types.ts';
import { loadGameData } from '../../packages/core/src/data.ts';
import battle from '../../data/battle.json' with { type: 'json' };
import codex from '../../data/codex.json' with { type: 'json' };
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
  expect(Object.keys(gameData.dragons)).toHaveLength(52);
  expect(Object.keys(gameData.traits)).toHaveLength(52);
  expect(gameData.recipes).toHaveLength(165);
});

test('every element pair has one dual result with nine recipes', () => {
  const duals = realData.dragons.filter(({ tier }) => tier === 'dual');
  for (const [index, first] of ELEMENTS.entries()) {
    for (const second of ELEMENTS.slice(index + 1)) {
      const pair = duals.filter(({ elements }) => elements[0] === first && elements[1] === second);
      expect(pair).toHaveLength(1);
      expect(realData.recipes.filter(({ result }) => result === pair[0]!.id)).toHaveLength(9);
    }
  }
});

test('codex covers every dragon', () => {
  expect(codex.map(({ id }) => id)).toEqual(dragons.map(({ id }) => id));
  expect(lintData({ ...realData, codex })).toEqual([]);
});

test('detects codex unknown id', () => {
  const unknown = { ...codex[0]!, id: 'missing_dragon' };
  expect(lintData({ ...realData, codex: [...codex, unknown] })).toEqual([
    'codex: unknown dragon id missing_dragon',
  ]);
});

test('detects codex missing and duplicate ids', () => {
  const incompleteCodex = [...codex.slice(1), codex[1]!];
  expect(lintData({ ...realData, codex: incompleteCodex })).toEqual([
    'codex: duplicate dragon id fire_wyvern',
    'codex: missing dragon id fire_drake',
  ]);
});

test('detects empty codex text', () => {
  const blank = { ...codex[0]!, hintKo: '  ', loreKo: '' };
  expect(lintData({ ...realData, codex: [blank, ...codex.slice(1)] })).toEqual([
    'codex fire_drake: hintKo must not be empty',
    'codex fire_drake: loreKo must not be empty',
  ]);
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

test('rejects base dragons as ingredients for a dual result', () => {
  const recipe = { a: 'poison_drake', b: 'steel_drake', result: 'corrosion_dragon' };
  expect(lintData({ ...realData, recipes: [...recipes, recipe] })).toEqual([
    "recipe poison_drake+steel_drake -> corrosion_dragon: expected two tier 2 dragons matching the dual result's elements",
  ]);
});

test('rejects unknown dragon elements and slot symbols', () => {
  const raw = structuredClone(realData);
  raw.dragons.find(({ id }) => id === 'tiamat')!.elements.push('water' as Element);
  Object.assign(raw.slot.weights, { water: 1 });

  expect(lintData(raw)).toEqual([
    'dragon tiamat: unknown element water',
    'slot weight: unknown symbol water',
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
