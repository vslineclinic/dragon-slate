import { describe, expect, test } from 'vitest';
import { bestNudge, evolvablePairs, lineRewards, recommendOffer } from '../src/hints.ts';
import { createRun } from '../src/run.ts';
import type { DragonInst, Grid, RunState, SymbolId } from '../src/contracts/types.ts';
import { gridFrom, testData } from './helpers.ts';

const F = 'fire', I = 'ice', L = 'lightning', G = 'gold';
const inst = (uid: number, speciesId: string): DragonInst => ({ uid, speciesId, traits: [], bonusPct: 0 });

/** gridFrom은 숨은 칸을 금으로 채운다. 밀기 테스트용으로 숨은 칸을 바꾼다. */
function withHidden(g: Grid, col: number, top: SymbolId, bottom: SymbolId): Grid {
  const reels = g.reels.map((r) => r.slice());
  reels[col]![0] = { symbol: top, speciesId: null };
  reels[col]![4] = { symbol: bottom, speciesId: null };
  return { reels, offsets: g.offsets.slice() };
}

describe('hints', () => {
  test('bestNudge finds the nudge that completes a line', () => {
    // 세로 1번 줄 보이는 [F, I, G], 숨은 위칸 L. 아래로 밀면(dir -1) 보이는 [L, F, I] → 가운데 줄 F,F,F
    const g = withHidden(gridFrom([[L, F, I], [F, I, F], [L, G, I]]), 1, L, G);
    expect(bestNudge(g, 1)).toEqual({ col: 1, dir: -1, lines: 1 });
  });

  test('bestNudge returns null when nothing improves or no nudges left', () => {
    const g = gridFrom([[F, I, L], [I, L, F], [L, F, I]]);
    expect(bestNudge(g, 1)).toBeNull();
    const h = withHidden(gridFrom([[L, F, I], [F, I, F], [L, G, I]]), 1, L, G);
    expect(bestNudge(h, 0)).toBeNull();
  });

  test('recommendOffer prefers the egg that completes a recipe', () => {
    const d = testData();
    const s: RunState = { ...createRun(d, 1).state, phase: 'pick', bench: [inst(1, 'fire_drake'), null, null, null], grid: gridFrom([[I, L, I], [I, F, L], [L, I, F]]) };
    // gridFrom 종 이름은 원소_x 라 레시피가 없음 → 실제 종으로 바꾼다
    s.grid!.reels[1]![2] = { symbol: 'fire', speciesId: 'fire_drake' };
    expect(recommendOffer(d, s)).toEqual({ index: 1, reason: 'recipe', result: 'beowulf_firedrake' });
  });

  test('recommendOffer falls back to nest element, then null', () => {
    const d = testData();
    const base = createRun(d, 1).state;
    const g = gridFrom([[I, L, I], [I, L, G], [L, I, F]]);
    g.reels[0]![2] = { symbol: 'ice', speciesId: 'ice_drake' };
    g.reels[1]![2] = { symbol: 'lightning', speciesId: 'storm_drake' };
    const s: RunState = { ...base, phase: 'pick', nest: [inst(1, 'storm_wyvern'), null, null, null, null, null], grid: g };
    expect(recommendOffer(d, s)).toEqual({ index: 1, reason: 'element', result: null });
    expect(recommendOffer(d, { ...s, nest: [null, null, null, null, null, null] })).toBeNull();
  });

  test('lineRewards summarizes what picking now would give', () => {
    const d = testData();
    // 가로 0줄 불 3개(1줄) + 가운데 칸 황금 1개
    expect(lineRewards(d, gridFrom([[F, F, F], [I, G, L], [L, I, I]]))).toEqual({ lines: 1, eggs: [{ element: 'fire', tier: 'base' }], mana: 2 + 1 });
    // 불 2줄(가로0 + 세로0) → 2티어 알
    expect(lineRewards(d, gridFrom([[F, F, F], [F, L, I], [F, I, L]])).eggs).toEqual([{ element: 'fire', tier: 't2' }]);
    // 줄 없음, 황금 칸 없음
    expect(lineRewards(d, gridFrom([[F, I, L], [I, L, F], [F, F, I]]))).toEqual({ lines: 0, eggs: [], mana: 0 });
  });

  test('evolvablePairs lists recipe pairs across nest and bench', () => {
    const d = testData();
    const s: RunState = { ...createRun(d, 1).state, nest: [inst(1, 'fire_drake'), null, null, null, null, null], bench: [inst(2, 'fire_drake'), inst(3, 'ice_drake'), null, null] };
    expect(evolvablePairs(d, s)).toEqual([{ a: { zone: 'nest', index: 0 }, b: { zone: 'bench', index: 0 }, result: 'beowulf_firedrake' }]);
  });
});
