import type { DragonInst, Element, GameData, Grid, RunState, SlotRef } from './contracts/types.ts';
import { findRecipe } from './fusion.ts';
import { evaluateLines, nudge, offersFrom, visible } from './slot.ts';

/** 추천 표시용 도우미. 상태를 바꾸지 않는다. */

function lineCount(g: Grid): number {
  return evaluateLines(g).reduce((n, x) => n + x.lines.length, 0);
}

/** 맞은 줄 수를 가장 많이 늘리는 밀기. 늘어나지 않으면 null */
export function bestNudge(grid: Grid, nudgesLeft: number): { col: 0 | 1 | 2; dir: -1 | 1; lines: number } | null {
  if (nudgesLeft <= 0) return null;
  const now = lineCount(grid);
  let best: { col: 0 | 1 | 2; dir: -1 | 1; lines: number } | null = null;
  for (const col of [0, 1, 2] as const) {
    for (const dir of [-1, 1] as const) {
      const off = grid.offsets[col] ?? 0;
      if (off + dir < -1 || off + dir > 1) continue;
      const n = lineCount(nudge(grid, col, dir));
      if (n > now && (!best || n > best.lines)) best = { col, dir, lines: n };
    }
  }
  return best;
}

function owned(s: RunState): { ref: SlotRef; inst: DragonInst }[] {
  const out: { ref: SlotRef; inst: DragonInst }[] = [];
  s.nest.forEach((inst, index) => inst && out.push({ ref: { zone: 'nest', index }, inst }));
  s.bench.forEach((inst, index) => inst && out.push({ ref: { zone: 'bench', index }, inst }));
  return out;
}

/** 고를 만한 알: 가진 용과 진화 레시피를 이루는 알 > 둥지 원소와 같은 알 */
export function recommendOffer(data: GameData, s: RunState): { index: number; reason: 'recipe' | 'element'; result: string | null } | null {
  if (!s.grid) return null;
  const offers = offersFrom(data, s.grid);
  const mine = owned(s);
  for (let i = 0; i < offers.length; i++) {
    const o = offers[i];
    if (o?.kind !== 'egg') continue;
    for (const m of mine) {
      const result = findRecipe(data, o.speciesId, m.inst.speciesId);
      if (result) return { index: i, reason: 'recipe', result };
    }
  }
  const nestEls = new Set(s.nest.flatMap((n) => (n ? (data.dragons[n.speciesId]?.elements.slice(0, 1) ?? []) : [])));
  for (let i = 0; i < offers.length; i++) {
    const o = offers[i];
    if (o?.kind === 'egg' && nestEls.has(data.dragons[o.speciesId]?.elements[0] ?? 'fire')) return { index: i, reason: 'element', result: null };
  }
  return null;
}

/** 지금 합치면 진화하는 쌍 */
export function evolvablePairs(data: GameData, s: RunState): { a: SlotRef; b: SlotRef; result: string }[] {
  const mine = owned(s);
  const out: { a: SlotRef; b: SlotRef; result: string }[] = [];
  for (let i = 0; i < mine.length; i++) {
    for (let j = i + 1; j < mine.length; j++) {
      const result = findRecipe(data, mine[i]!.inst.speciesId, mine[j]!.inst.speciesId);
      if (result) out.push({ a: mine[i]!.ref, b: mine[j]!.ref, result });
    }
  }
  return out;
}

/** 지금 알을 고르면 줄 맞춤으로 함께 받는 것(알 종류와 마력). run.ts의 고르기 정산과 같은 규칙. */
export function lineRewards(data: GameData, grid: Grid): { lines: number; eggs: { element: Element; tier: 'base' | 't2' }[]; mana: number } {
  let lines = 0;
  let mana = 0;
  const eggs: { element: Element; tier: 'base' | 't2' }[] = [];
  for (const g of evaluateLines(grid)) {
    lines += g.lines.length;
    if (g.element === 'gold') mana += data.slot.goldLineMana;
    else if (g.element === 'wild') mana += data.slot.wildLineMana;
    else {
      eggs.push({ element: g.element, tier: g.lines.length >= 2 ? 't2' : 'base' });
      mana += data.slot.lineMana;
    }
  }
  for (let c = 0; c < 3; c++) for (const r of [0, 1, 2] as const) if (visible(grid, c, r).symbol === 'gold') mana += data.slot.goldMana;
  return { lines, eggs, mana };
}
