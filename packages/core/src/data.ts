import { ELEMENTS, type Element, type GameData, type RawGameData } from './contracts/types.ts';

/** 기본종이 있는 원소만(ELEMENTS 순서) */
const activeCache = new WeakMap<GameData['dragons'], Element[]>();

export function activeElements(data: GameData): Element[] {
  const hit = activeCache.get(data.dragons);
  if (hit) return hit;
  const used = new Set(Object.values(data.dragons).filter((d) => d.tier === 'base').map((d) => d.elements[0]));
  const out = ELEMENTS.filter((e) => used.has(e));
  activeCache.set(data.dragons, out);
  return out;
}

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
  return { dragons, traits, recipes: raw.recipes, slot: raw.slot, waves: raw.waves, battle: raw.battle, rewards: raw.rewards ?? [], bosses: raw.bosses ?? [], calamity: raw.calamity ?? [] };
}
