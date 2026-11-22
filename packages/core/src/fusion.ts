import type { DragonInst, GameData } from './contracts/types.ts';

const recipeCache = new WeakMap<GameData['recipes'], Map<string, string>>();

/** 순서 무관. 레시피 표는 데이터마다 한 번만 맵으로 만든다(첫 일치 우선). */
export function findRecipe(data: GameData, a: string, b: string): string | undefined {
  let map = recipeCache.get(data.recipes);
  if (!map) {
    map = new Map();
    for (const r of data.recipes) {
      const k1 = r.a + '|' + r.b;
      const k2 = r.b + '|' + r.a;
      if (!map.has(k1)) map.set(k1, r.result);
      if (!map.has(k2)) map.set(k2, r.result);
    }
    recipeCache.set(data.recipes, map);
  }
  return map.get(a + '|' + b);
}

function absorbedTrait(data: GameData, main: DragonInst, material: DragonInst): string | null {
  const trait = data.dragons[material.speciesId]?.traitId ?? null;
  const own = data.dragons[main.speciesId]?.traitId;
  if (trait === null || trait === own || main.traits.includes(trait) || main.traits.length >= data.battle.maxTraits) return null;
  return trait;
}

export function mergePreview(
  data: GameData,
  main: DragonInst,
  material: DragonInst,
): { kind: 'evolve'; result: string } | { kind: 'absorb'; trait: string | null } {
  const result = findRecipe(data, main.speciesId, material.speciesId);
  if (result !== undefined) return { kind: 'evolve', result };
  return { kind: 'absorb', trait: absorbedTrait(data, main, material) };
}

export function merge(
  data: GameData,
  main: DragonInst,
  material: DragonInst,
  newUid: number,
): { inst: DragonInst; kind: 'evolve' | 'absorb'; trait: string | null } {
  const preview = mergePreview(data, main, material);
  if (preview.kind === 'evolve') {
    return { inst: { uid: newUid, speciesId: preview.result, traits: main.traits.slice(), bonusPct: 0 }, kind: 'evolve', trait: null };
  }
  const tier = data.dragons[material.speciesId]?.tier ?? 'base';
  const traits = preview.trait === null ? main.traits.slice() : [...main.traits, preview.trait];
  const bonusPct = main.bonusPct + (data.battle.absorbBonusPct[tier] ?? 0);
  return { inst: { uid: main.uid, speciesId: main.speciesId, traits, bonusPct }, kind: 'absorb', trait: preview.trait };
}
