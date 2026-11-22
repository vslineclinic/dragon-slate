import type { GameData, RawGameData } from './contracts/types.ts';

/** 배열을 id 맵으로 바꾸고, 참조가 없는 id가 있으면 throw */
export function loadGameData(raw: RawGameData): GameData {
  const dragons: GameData['dragons'] = {};
  for (const d of raw.dragons) dragons[d.id] = d;
  const traits: GameData['traits'] = {};
  for (const t of raw.traits) traits[t.id] = t;
  for (const d of raw.dragons) {
    if (!traits[d.traitId]) throw new Error('dragon ' + d.id + ': unknown traitId ' + d.traitId);
  }
  for (const r of raw.recipes) {
    for (const id of [r.a, r.b, r.result]) {
      if (!dragons[id]) throw new Error('recipe ' + r.a + '+' + r.b + ': unknown dragon id ' + id);
    }
  }
  return { dragons, traits, recipes: raw.recipes, slot: raw.slot, waves: raw.waves, battle: raw.battle };
}
