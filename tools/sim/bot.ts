import {
  evaluateLines, findRecipe, mergePreview, nudge, offersFrom, toUnit,
  type Command, type DragonInst, type GameData, type Grid, type RunState, type SlotRef,
} from '../../packages/core/src/index.ts';

const columns = [0, 1, 2] as const;
const directions = [-1, 1] as const;
const frontSlots = [0, 1, 2, 3, 4, 5];
const backSlots = [3, 4, 5, 0, 1, 2];

type NudgeCommand = Extract<Command, { type: 'nudge' }>;
type OccupiedSlot = { inst: DragonInst; ref: SlotRef };

function occupied(state: RunState, zone: SlotRef['zone']): OccupiedSlot[] {
  const slots = zone === 'nest' ? state.nest.slice(0, state.nestOpen) : state.bench;
  return slots.flatMap((inst, index) => inst ? [{ inst, ref: { zone, index } }] : []);
}

function lineCount(lines: ReturnType<typeof evaluateLines>): number {
  return lines.reduce((count, group) => count + group.lines.length, 0);
}

function choosePick(data: GameData, state: RunState, grid: Grid): Command {
  const lines = evaluateLines(grid);
  const offers = offersFrom(data, grid);
  const nest = occupied(state, 'nest');
  const owned = [...nest, ...occupied(state, 'bench')];
  const benchHasSpace = state.bench.includes(null);
  const needsDragon = owned.length === 0;
  const canRecruit = (hasEgg: boolean, groups: typeof lines): boolean =>
    hasEgg || groups.some(({ element }) => element !== 'gold' && element !== 'wild');

  let bestNudge: NudgeCommand | undefined;
  let recruitingNudge: NudgeCommand | undefined;
  let bestCount = lineCount(lines);
  if (state.nudgesLeft > 0) {
    for (const col of columns) {
      for (const dir of directions) {
        const shifted = nudge(grid, col, dir);
        const shiftedLines = evaluateLines(shifted);
        const command = { type: 'nudge', col, dir } as const;
        const count = lineCount(shiftedLines);
        if (needsDragon) {
          const hasEgg = offersFrom(data, shifted).some((offer) => offer.kind === 'egg');
          if (!canRecruit(hasEgg, shiftedLines)) continue;
          recruitingNudge ??= command;
        }
        if (count > bestCount) {
          bestCount = count;
          bestNudge = command;
        }
      }
    }
  }
  if (bestNudge) return bestNudge;

  const costs = data.slot.rerollCosts;
  const cost = costs[Math.min(state.spinsThisWave, costs.length - 1)] ?? 0;
  if (state.mana >= Math.max(8, cost) && state.spinsThisWave === 1 && lines.length === 0) {
    return { type: 'spin' };
  }
  if (needsDragon && !canRecruit(offers.some((offer) => offer.kind === 'egg'), lines)) {
    if (recruitingNudge) return recruitingNudge;
    if (state.mana >= cost) return { type: 'spin' };
    throw new Error('No affordable way to recruit a dragon before battle');
  }

  const nestElements = new Set(nest.flatMap(({ inst }) => data.dragons[inst.speciesId]?.elements ?? []));
  let bestIndex: (typeof columns)[number] | undefined;
  let bestPriority = -1;
  for (const index of columns) {
    const offer = offers[index];
    if (!offer || (offer.kind === 'egg' && !benchHasSpace)) continue;

    let priority = 0;
    if (offer.kind === 'egg') {
      const matchesRecipe = owned.some(({ inst }) => findRecipe(data, inst.speciesId, offer.speciesId) !== undefined);
      const matchesElement = data.dragons[offer.speciesId]?.elements.some((element) => nestElements.has(element));
      priority = matchesRecipe ? 3 : matchesElement ? 2 : 1;
    }
    if (priority > bestPriority) {
      bestPriority = priority;
      bestIndex = index;
    }
  }
  if (bestIndex === undefined) throw new Error('No legal offer to pick with a full bench');
  return { type: 'pick', index: bestIndex };
}

function strength(data: GameData, inst: DragonInst): number {
  const { hp, atk, cooldownTicks } = toUnit(data, inst);
  return Math.floor(hp / 4) + Math.floor(atk * 20 / cooldownTicks);
}

function chooseManage(data: GameData, state: RunState): Command {
  const nest = occupied(state, 'nest');
  const bench = occupied(state, 'bench');
  // Nest slots come first, so an evolution keeps its main dragon in the nest when possible.
  const owned = [...nest, ...bench];
  for (const [index, main] of owned.entries()) {
    for (const material of owned.slice(index + 1)) {
      if (mergePreview(data, main.inst, material.inst).kind === 'evolve') {
        return { type: 'merge', main: main.ref, material: material.ref };
      }
    }
  }

  const rank = (slots: OccupiedSlot[]) => slots
    .map((slot) => ({ ...slot, strength: strength(data, slot.inst) }))
    .sort((a, b) => b.strength - a.strength);
  const rankedNest = rank(nest);
  const rankedBench = rank(bench);
  const strongestNest = rankedNest[0];
  const weakestBench = rankedBench.at(-1);
  if (!state.bench.includes(null) && weakestBench) {
    return strongestNest
      ? { type: 'merge', main: strongestNest.ref, material: weakestBench.ref }
      : { type: 'release', from: weakestBench.ref };
  }

  const strongestBench = rankedBench[0];
  if (strongestBench) {
    const role = data.dragons[strongestBench.inst.speciesId]?.role;
    const order = role === 'back' ? backSlots : frontSlots;
    const emptyIndex = order.find((index) => index < state.nestOpen && state.nest[index] === null);
    if (emptyIndex !== undefined) {
      return { type: 'move', from: strongestBench.ref, to: { zone: 'nest', index: emptyIndex } };
    }
    const weakestNest = rankedNest.at(-1);
    if (weakestNest && strongestBench.strength > weakestNest.strength) {
      return { type: 'move', from: strongestBench.ref, to: weakestNest.ref };
    }
  }

  // Full benches are handled above, and moving or swapping preserves that vacancy.
  if (!strongestNest) throw new Error('No dragon available for battle');
  return { type: 'startBattle' };
}

export function chooseCommand(data: GameData, state: RunState): Command {
  switch (state.phase) {
    case 'spin': return { type: 'spin' };
    case 'pick':
      if (state.grid) return choosePick(data, state, state.grid);
      break;
    case 'manage': return chooseManage(data, state);
  }
  throw new Error(`No bot command for phase ${state.phase}`);
}
