import type { DragonInst, GameData } from './contracts/types.ts';

/** 순서 무관 */
export function findRecipe(data: GameData, a: string, b: string): string | undefined {
  for (const r of data.recipes) {
    if ((r.a === a && r.b === b) || (r.a === b && r.b === a)) return r.result;
  }
  return undefined;
}

function absorbedTrait(data: GameData, main: DragonInst, material: DragonInst): string | null {
  const trait = data.dragons[material.speciesId]?.traitId ?? null;
  if (trait === null || main.traits.includes(trait) || main.traits.length >= data.battle.maxTraits) return null;
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
