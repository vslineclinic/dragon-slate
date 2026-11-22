import type { GameData } from '../../core/src/index.ts';

/** 데모 빌드 여부(`vite build --mode demo` → apps/web/.env.demo 의 VITE_DEMO=1) */
export const IS_DEMO = import.meta.env.VITE_DEMO === '1';

/** 데모 설정: 10웨이브, 재앙 최대 1단계, 데모 마지막 보스 배율 */
export const DEMO = { maxWave: 10, maxCalamity: 1, finalBossPct: 465 } as const;

export function applyBuild(data: GameData): GameData {
  if (!IS_DEMO) return data;
  return {
    ...data,
    waves: { ...data.waves, maxWave: DEMO.maxWave, bossPct: { ...data.waves.bossPct, [String(DEMO.maxWave)]: DEMO.finalBossPct } },
    calamity: data.calamity.filter((c) => c.level <= DEMO.maxCalamity),
  };
}
