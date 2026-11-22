import type { Command, RejectReason } from './contracts/commands.ts';
import type { GameEvent } from './contracts/events.ts';
import type { BossSpec, DragonInst, Element, GameData, RunState, SlotRef } from './contracts/types.ts';
import { simulateBattle, toUnit } from './battle.ts';
import { merge } from './fusion.ts';
import { createRng, type Rng } from './rng.ts';
import { evaluateLines, nudge, offersFrom, spinGrid, visible } from './slot.ts';
import { bossElement, generateEnemies, isBoss } from './waves.ts';
import { calamityMods } from './calamity.ts';
import { activeElements } from './data.ts';

const NEST_SIZE = 6;
const BENCH_SIZE = 4;
const START_NEST_OPEN = 3;

type Result = { state: RunState; events: GameEvent[] };

function bossSpecPreview(data: GameData, wave: number): BossSpec | null {
  if ((wave - 1) % 5 !== 0) return null;
  return data.bosses.find((b) => b.wave === wave + 4) ?? null;
}

function bossPreview(data: GameData, seed: number, wave: number): Element | null {
  if ((wave - 1) % 5 !== 0) return null;
  return isBoss(data.waves, wave + 4) ? bossElement(seed, wave + 4, activeElements(data)) : null;
}

export function createRun(data: GameData, seed: number, calamity = 0): Result {
  const mods = calamityMods(data, calamity);
  const state: RunState = {
    seed: seed >>> 0,
    rngState: seed >>> 0,
    calamity,
    wave: 1,
    phase: 'spin',
    lives: Math.max(1, data.waves.startLives + mods.startLivesAdd),
    mana: data.waves.startMana,
    nest: new Array<DragonInst | null>(NEST_SIZE).fill(null),
    nestOpen: START_NEST_OPEN,
    bench: new Array<DragonInst | null>(BENCH_SIZE).fill(null),
    grid: null,
    spinsThisWave: 0,
    nudgesLeft: data.slot.nudgesPerWave,
    pity: 0,
    nextUid: 1,
    bonusNudges: 0,
    freeSpins: 0,
    discovered: [],
    log: [],
  };
  return { state, events: [{ t: 'waveStart', wave: 1, bossPreview: bossPreview(data, state.seed, 1), boss: bossSpecPreview(data, 1) }] };
}

export function stateHash(state: RunState): string {
  const { log: _log, ...rest } = state;
  return JSON.stringify(rest);
}

function zoneOf(s: RunState, ref: SlotRef): (DragonInst | null)[] {
  return ref.zone === 'nest' ? s.nest : s.bench;
}

function validRef(s: RunState, ref: SlotRef): RejectReason | null {
  const size = ref.zone === 'nest' ? NEST_SIZE : BENCH_SIZE;
  if (!Number.isInteger(ref.index) || ref.index < 0 || ref.index >= size) return 'emptySlot';
  if (ref.zone === 'nest' && ref.index >= s.nestOpen) return 'slotLocked';
  return null;
}

function dragonCount(s: RunState): number {
  return s.nest.filter((n) => n !== null).length + s.bench.filter((b) => b !== null).length;
}

const ARRANGE_PHASES = ['manage', 'pick', 'spin'];

function sameRef(a: SlotRef, b: SlotRef): boolean {
  return a.zone === b.zone && a.index === b.index;
}

function speciesOfTier(data: GameData, el: string, tier: 'base' | 't2'): string[] {
  return Object.values(data.dragons)
    .filter((d) => d.tier === tier && d.elements[0] === el)
    .map((d) => d.id)
    .sort();
}

function addToBench(s: RunState, speciesId: string, via: 'pick' | 'bonus', events: GameEvent[]): boolean {
  const idx = s.bench.indexOf(null);
  if (idx < 0) return false;
  const inst: DragonInst = { uid: s.nextUid++, speciesId, traits: [], bonusPct: 0 };
  s.bench[idx] = inst;
  events.push({ t: 'gained', inst, to: { zone: 'bench', index: idx }, via });
  return true;
}

function addMana(s: RunState, delta: number, reason: string, events: GameEvent[]): void {
  if (delta === 0) return;
  s.mana += delta;
  events.push({ t: 'mana', delta, reason });
}

/** 보상 무료 다시 돌리기를 쓰기 전의 비용 */
function paidSpinCost(data: GameData, s: RunState): number {
  const costs = data.slot.rerollCosts;
  // 드래곤이 하나도 없으면 다시 돌리기는 무료(첫 판 막힘 방지)
  const base = dragonCount(s) === 0 ? 0 : (costs[Math.min(s.spinsThisWave, costs.length - 1)] ?? 0);
  return base > 0 ? base + calamityMods(data, s.calamity).rerollCostAdd : 0;
}

/** 지금 돌리면 드는 마력. 화면·봇·규칙이 모두 이 함수를 쓴다. */
export function spinCost(data: GameData, s: RunState): number {
  const paid = paidSpinCost(data, s);
  return paid > 0 && s.freeSpins > 0 ? 0 : paid;
}

function doSpin(data: GameData, s: RunState, rng: Rng, events: GameEvent[]): RejectReason | null {
  if (s.phase !== 'spin' && s.phase !== 'pick') return 'wrongPhase';
  const cost = spinCost(data, s);
  if (cost === 0 && paidSpinCost(data, s) > 0) s.freeSpins--;
  if (s.mana < cost) return 'notEnoughMana';
  s.mana -= cost;
  const grid = spinGrid(data, rng, s.pity >= data.slot.pityThreshold);
  const lines = evaluateLines(grid);
  s.pity = lines.length === 0 ? s.pity + 1 : 0;
  s.spinsThisWave++;
  s.grid = grid;
  s.phase = 'pick';
  events.push({ t: 'spun', grid, cost });
  if (cost > 0) events.push({ t: 'mana', delta: -cost, reason: 'reroll' });
  for (const g of lines) events.push({ t: 'lineHit', lines: g.lines, element: g.element });
  return null;
}

function doNudge(s: RunState, col: 0 | 1 | 2, dir: -1 | 1, events: GameEvent[]): RejectReason | null {
  if (s.phase !== 'pick' || !s.grid) return 'wrongPhase';
  if (s.nudgesLeft <= 0) return 'noNudgeLeft';
  s.grid = nudge(s.grid, col, dir);
  s.nudgesLeft--;
  events.push({ t: 'nudged', grid: s.grid });
  for (const g of evaluateLines(s.grid)) events.push({ t: 'lineHit', lines: g.lines, element: g.element });
  return null;
}

function doPick(data: GameData, s: RunState, index: number, rng: Rng, events: GameEvent[]): RejectReason | null {
  if (s.phase !== 'pick' || !s.grid) return 'wrongPhase';
  const offer = offersFrom(data, s.grid)[index];
  if (!offer) return 'emptySlot';
  if (offer.kind === 'egg' && s.bench.indexOf(null) < 0) return 'benchFull';
  if (offer.kind === 'egg') addToBench(s, offer.speciesId, 'pick', events);
  else addMana(s, offer.amount, 'goldOffer', events);

  let converted = 0;
  for (const g of evaluateLines(s.grid)) {
    if (g.element === 'gold') addMana(s, data.slot.goldLineMana, 'goldLine', events);
    else if (g.element === 'wild') addMana(s, data.slot.wildLineMana, 'wildLine', events);
    else {
      const pool = speciesOfTier(data, g.element, g.lines.length >= 2 ? 't2' : 'base');
      const species = pool[rng.nextInt(pool.length)];
      if (species !== undefined && !addToBench(s, species, 'bonus', events)) converted++;
      addMana(s, data.slot.lineMana, 'line', events);
    }
  }
  addMana(s, converted, 'benchFull', events);
  let gold = 0;
  for (let c = 0; c < 3; c++) for (const r of [0, 1, 2] as const) if (visible(s.grid, c, r).symbol === 'gold') gold++;
  addMana(s, gold * data.slot.goldMana, 'goldCells', events);

  if (dragonCount(s) === 0) return 'needDragon';
  s.grid = null;
  s.phase = 'manage';
  return null;
}

function doMerge(data: GameData, s: RunState, main: SlotRef, material: SlotRef, events: GameEvent[]): RejectReason | null {
  if (!ARRANGE_PHASES.includes(s.phase)) return 'wrongPhase';
  if (sameRef(main, material)) return 'sameSlot';
  const bad = validRef(s, main) ?? validRef(s, material);
  if (bad) return bad;
  const a = zoneOf(s, main)[main.index];
  const b = zoneOf(s, material)[material.index];
  if (!a || !b) return 'emptySlot';
  const r = merge(data, a, b, s.nextUid);
  if (r.kind === 'evolve') s.nextUid++;
  zoneOf(s, main)[main.index] = r.inst;
  zoneOf(s, material)[material.index] = null;
  if (r.kind === 'evolve') {
    const firstTime = !s.discovered.includes(r.inst.speciesId);
    if (firstTime) s.discovered.push(r.inst.speciesId);
    events.push({ t: 'evolved', inst: r.inst, at: main, firstTime });
  } else {
    events.push({ t: 'absorbed', inst: r.inst, at: main, trait: r.trait });
  }
  return null;
}

function doMove(s: RunState, from: SlotRef, to: SlotRef): RejectReason | null {
  if (!ARRANGE_PHASES.includes(s.phase)) return 'wrongPhase';
  if (sameRef(from, to)) return 'sameSlot';
  const bad = validRef(s, from) ?? validRef(s, to);
  if (bad) return bad;
  const a = zoneOf(s, from)[from.index] ?? null;
  if (!a) return 'emptySlot';
  const b = zoneOf(s, to)[to.index] ?? null;
  zoneOf(s, to)[to.index] = a;
  zoneOf(s, from)[from.index] = b;
  return null;
}

function doRelease(data: GameData, s: RunState, from: SlotRef, events: GameEvent[]): RejectReason | null {
  if (!ARRANGE_PHASES.includes(s.phase)) return 'wrongPhase';
  const bad = validRef(s, from);
  if (bad) return bad;
  const a = zoneOf(s, from)[from.index];
  if (!a) return 'emptySlot';
  if (dragonCount(s) <= 1) return 'needDragon';
  zoneOf(s, from)[from.index] = null;
  const tier = data.dragons[a.speciesId]?.tier ?? 'base';
  addMana(s, data.waves.releaseMana[tier] ?? 0, 'release', events);
  return null;
}

/** 웨이브 승리 보상 하나를 가중치로 뽑아 적용한다 */
function grantReward(data: GameData, s: RunState, rng: Rng, boss: boolean, events: GameEvent[]): void {
  const pool = data.rewards.filter((r) => (boss ? r.bossWeight : r.weight) > 0);
  if (pool.length === 0) return;
  const reward = rng.pickWeighted(pool, (r) => (boss ? r.bossWeight : r.weight));
  let detail: string | null = null;
  const fallback = () => addMana(s, 3, 'reward', events);
  if (reward.kind === 'mana') addMana(s, reward.amount, 'reward', events);
  else if (reward.kind === 'egg' || reward.kind === 't2egg') {
    const tier = reward.kind === 'egg' ? 'base' : 't2';
    const pool2 = Object.values(data.dragons).filter((d) => d.tier === tier).map((d) => d.id).sort();
    const species = pool2[rng.nextInt(pool2.length)];
    if (species) {
      detail = species;
      if (!addToBench(s, species, 'bonus', events)) addMana(s, tier === 'base' ? 1 : 2, 'benchFull', events);
    }
  } else if (reward.kind === 'trait') {
    const targets = [...s.nest, ...s.bench].filter((d): d is DragonInst => d !== null && d.traits.length < data.battle.maxTraits);
    const target = targets[rng.nextInt(Math.max(1, targets.length))];
    const own = target ? data.dragons[target.speciesId]?.traitId : undefined;
    const choices = target ? Object.keys(data.traits).sort().filter((t) => t !== own && !target.traits.includes(t)) : [];
    const trait = choices[rng.nextInt(Math.max(1, choices.length))];
    if (target && trait) {
      target.traits.push(trait);
      detail = trait;
    } else fallback();
  } else if (reward.kind === 'nudge') s.bonusNudges += reward.amount;
  else if (reward.kind === 'freeSpin') s.freeSpins += reward.amount;
  else if (reward.kind === 'life') {
    if (s.lives < data.waves.startLives) s.lives = Math.min(data.waves.startLives, s.lives + reward.amount);
    else fallback();
  }
  events.push({ t: 'reward', reward, detail });
}

function doBattle(data: GameData, s: RunState, rng: Rng, events: GameEvent[]): RejectReason | null {
  if (s.phase !== 'manage') return 'wrongPhase';
  if (!s.nest.some((n, i) => n !== null && i < s.nestOpen)) return 'nestEmpty';
  const allies = s.nest.map((n, i) => (n && i < s.nestOpen ? toUnit(data, n) : null));
  const mods = calamityMods(data, s.calamity);
  const enemies = generateEnemies(data, s.wave, rng, s.seed, mods);
  const rules = isBoss(data.waves, s.wave) ? data.bosses.find((b) => b.wave === s.wave)?.rules : undefined;
  const result = simulateBattle(data.battle, allies, enemies, rules);
  events.push({ t: 'battle', result });
  const won = result.winner === 'ally';
  if (won) {
    addMana(s, Math.floor((data.waves.winMana * (100 + mods.winManaPct)) / 100), 'win', events);
    if (s.wave < data.waves.maxWave) grantReward(data, s, rng, isBoss(data.waves, s.wave), events);
  }
  else {
    s.lives -= isBoss(data.waves, s.wave) ? data.waves.bossLossLife : data.waves.lossLife;
    if (s.lives < 0) s.lives = 0;
    events.push({ t: 'lives', lives: s.lives });
    addMana(s, data.waves.lossMana, 'loss', events);
  }
  if (data.waves.nestUnlockAfter.includes(s.wave) && s.nestOpen < NEST_SIZE) {
    s.nestOpen++;
    events.push({ t: 'nestUnlocked', open: s.nestOpen });
  }
  if (s.lives <= 0) {
    s.phase = 'gameOver';
    events.push({ t: 'gameOver' });
    return null;
  }
  if (s.wave >= data.waves.maxWave) {
    if (won) {
      s.phase = 'victory';
      events.push({ t: 'victory' });
      return null;
    }
  } else {
    s.wave++;
  }
  s.spinsThisWave = 0;
  s.nudgesLeft = data.slot.nudgesPerWave + s.bonusNudges;
  s.bonusNudges = 0;
  s.phase = 'spin';
  events.push({ t: 'waveStart', wave: s.wave, bossPreview: bossPreview(data, s.seed, s.wave), boss: bossSpecPreview(data, s.wave) });
  return null;
}

/** 입력 state는 바꾸지 않는다. 거절이면 같은 state 객체와 rejected 이벤트를 돌려준다. */
export function applyCommand(data: GameData, state: RunState, cmd: Command): Result {
  const s = structuredClone(state);
  const rng = createRng(s.seed, s.rngState);
  const events: GameEvent[] = [];
  let reason: RejectReason | null;
  switch (cmd.type) {
    case 'spin': reason = doSpin(data, s, rng, events); break;
    case 'nudge': reason = doNudge(s, cmd.col, cmd.dir, events); break;
    case 'pick': reason = doPick(data, s, cmd.index, rng, events); break;
    case 'merge': reason = doMerge(data, s, cmd.main, cmd.material, events); break;
    case 'move': reason = doMove(s, cmd.from, cmd.to); break;
    case 'release': reason = doRelease(data, s, cmd.from, events); break;
    case 'startBattle': reason = doBattle(data, s, rng, events); break;
  }
  if (reason) return { state, events: [{ t: 'rejected', reason }] };
  s.rngState = rng.state();
  s.log.push(structuredClone(cmd));
  return { state: s, events };
}
