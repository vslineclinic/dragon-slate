import type { Cell, Element, GameData, Grid, Offer, SymbolId } from './contracts/types.ts';
import type { Rng } from './rng.ts';
import { activeElements } from './data.ts';

/** 8줄: [col,row] (row는 보이는 0~2) */
export const LINES: readonly (readonly [number, number][])[] = [
  [[0, 0], [1, 0], [2, 0]],
  [[0, 1], [1, 1], [2, 1]],
  [[0, 2], [1, 2], [2, 2]],
  [[0, 0], [0, 1], [0, 2]],
  [[1, 0], [1, 1], [1, 2]],
  [[2, 0], [2, 1], [2, 2]],
  [[0, 0], [1, 1], [2, 2]],
  [[0, 2], [1, 1], [2, 0]],
];


function basesOf(data: GameData, el: Element | null): string[] {
  const out: string[] = [];
  for (const d of Object.values(data.dragons)) {
    if (d.tier === 'base' && (el === null || d.elements[0] === el)) out.push(d.id);
  }
  return out.sort();
}

function rollCell(data: GameData, rng: Rng, symbol: SymbolId): Cell {
  if (symbol === 'gold') return { symbol, speciesId: null };
  const pool = basesOf(data, symbol === 'wild' ? null : symbol);
  return { symbol, speciesId: pool[rng.nextInt(pool.length)] ?? null };
}

export function spinGrid(data: GameData, rng: Rng, forceLine: boolean): Grid {
  const elements = activeElements(data);
  const symbols: SymbolId[] = [...elements, 'gold', 'wild'];
  const reels: Cell[][] = [];
  for (let c = 0; c < 3; c++) {
    const reel: Cell[] = [];
    for (let i = 0; i < 5; i++) {
      const sym = rng.pickWeighted(symbols, (s) => data.slot.weights[s] ?? 0);
      reel.push(rollCell(data, rng, sym));
    }
    reels.push(reel);
  }
  if (forceLine) {
    const el = elements[rng.nextInt(elements.length)] as Element;
    for (let c = 0; c < 3; c++) (reels[c] as Cell[])[2] = rollCell(data, rng, el);
  }
  return { reels, offsets: [0, 0, 0] };
}

export function visible(grid: Grid, col: number, row: 0 | 1 | 2): Cell {
  const reel = grid.reels[col] as Cell[];
  return reel[1 + (grid.offsets[col] ?? 0) + row] as Cell;
}

function lineSymbol(grid: Grid, line: readonly [number, number][]): SymbolId | null {
  const syms = line.map(([c, r]) => visible(grid, c, r as 0 | 1 | 2).symbol);
  if (syms.every((s) => s === 'gold')) return 'gold';
  if (syms.includes('gold')) return null;
  const nonWild = syms.filter((s) => s !== 'wild');
  if (nonWild.length === 0) return 'wild';
  const first = nonWild[0] as SymbolId;
  return nonWild.every((s) => s === first) ? first : null;
}

/** 같은 결과 묶음별. 묶음 순서는 처음 맞은 줄 순서. */
export function evaluateLines(grid: Grid): { lines: number[]; element: SymbolId }[] {
  const out: { lines: number[]; element: SymbolId }[] = [];
  LINES.forEach((line, i) => {
    const s = lineSymbol(grid, line);
    if (s === null) return;
    const group = out.find((g) => g.element === s);
    if (group) group.lines.push(i);
    else out.push({ lines: [i], element: s });
  });
  return out;
}

export function nudge(grid: Grid, col: 0 | 1 | 2, dir: -1 | 1): Grid {
  const offsets = grid.offsets.slice();
  offsets[col] = Math.max(-1, Math.min(1, (offsets[col] ?? 0) + dir));
  return { reels: grid.reels, offsets };
}

export function offersFrom(data: GameData, grid: Grid): Offer[] {
  const out: Offer[] = [];
  for (let c = 0; c < 3; c++) {
    const cell = visible(grid, c, 1);
    if (cell.symbol === 'gold' || cell.speciesId === null) out.push({ kind: 'mana', amount: data.slot.goldOfferMana });
    else out.push({ kind: 'egg', speciesId: cell.speciesId });
  }
  return out;
}
