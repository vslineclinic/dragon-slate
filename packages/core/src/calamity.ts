import type { GameData } from './contracts/types.ts';

export interface CalamityMods { enemyPowerPct: number; bossPowerPct: number; winManaPct: number; rerollCostAdd: number; startLivesAdd: number }

export const NO_CALAMITY: CalamityMods = { enemyPowerPct: 0, bossPowerPct: 0, winManaPct: 0, rerollCostAdd: 0, startLivesAdd: 0 };

/** 1..level 단계의 수정치를 더한다 */
export function calamityMods(data: GameData, level: number): CalamityMods {
  const m = { ...NO_CALAMITY };
  for (const c of data.calamity) {
    if (c.level > level) continue;
    m.enemyPowerPct += c.enemyPowerPct ?? 0;
    m.bossPowerPct += c.bossPowerPct ?? 0;
    m.winManaPct += c.winManaPct ?? 0;
    m.rerollCostAdd += c.rerollCostAdd ?? 0;
    m.startLivesAdd += c.startLivesAdd ?? 0;
  }
  return m;
}
