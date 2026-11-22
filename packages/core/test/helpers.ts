import { loadGameData } from '../src/data.ts';
import type { Cell, GameData, Grid, RawGameData, SymbolId } from '../src/contracts/types.ts';
import mini from '../../../data/fixtures/mini.json' with { type: 'json' };

/** 테스트용 데이터: mini 픽스처에 빙결·번개 기본종을 더한 것 */
export function testData(): GameData {
  const raw = structuredClone(mini) as RawGameData;
  const extra = [
    ['ice_drake', 'ice', 'front'],
    ['ice_wyvern', 'ice', 'back'],
    ['storm_drake', 'lightning', 'front'],
    ['storm_wyvern', 'lightning', 'back'],
  ] as const;
  for (const [id, el, role] of extra) {
    raw.dragons.push({ id, nameKo: id, tier: 'base', elements: [el], role, stats: { hp: 100, atk: 10, cooldownTicks: 20 }, traitId: 'tr_ember' });
  }
  return loadGameData(raw);
}

/** 보이는 3×3(행 우선 rows[row][col])으로 Grid를 만든다. 숨은 칸은 gold. */
export function gridFrom(rows: SymbolId[][]): Grid {
  const reels: Cell[][] = [];
  for (let c = 0; c < 3; c++) {
    const reel: Cell[] = [{ symbol: 'gold', speciesId: null }];
    for (let r = 0; r < 3; r++) {
      const s = rows[r]![c]!;
      reel.push({ symbol: s, speciesId: s === 'gold' ? null : s === 'wild' ? 'fire_drake' : s + '_x' });
    }
    reel.push({ symbol: 'gold', speciesId: null });
    reels.push(reel);
  }
  return { reels, offsets: [0, 0, 0] };
}
