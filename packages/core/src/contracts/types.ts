import type { Command } from './commands.ts';

export type Element = 'fire' | 'ice' | 'lightning';
export type SymbolId = Element | 'gold' | 'wild';
export type Tier = 'base' | 't2' | 't1' | 'dual' | 'secret';
export type Role = 'front' | 'back' | 'support';
export type TraitKind = 'atkPct' | 'hpPct' | 'hastePct' | 'lifestealPct';

export interface Stats { hp: number; atk: number; cooldownTicks: number }
export interface DragonSpec { id: string; nameKo: string; tier: Tier; elements: Element[]; role: Role; stats: Stats; traitId: string }
export interface TraitSpec { id: string; nameKo: string; kind: TraitKind; value: number }
export interface Recipe { a: string; b: string; result: string }

export interface SlotConfig {
  weights: Record<SymbolId, number>;
  pityThreshold: number;
  nudgesPerWave: number;
  rerollCosts: number[];
  lineMana: number;
  goldMana: number;
  goldLineMana: number;
  wildLineMana: number;
  goldOfferMana: number;
}

export interface WaveConfig {
  maxWave: number;
  basePower: number;
  growthPct: number;
  bossPct: Record<string, number>;
  startLives: number;
  lossLife: number;
  bossLossLife: number;
  nestUnlockAfter: number[];
  winMana: number;
  lossMana: number;
  startMana: number;
  releaseMana: Record<Tier, number>;
}

export interface BattleConfig {
  ticksPerSecond: number;
  maxTicks: number;
  strongPct: number;
  weakPct: number;
  absorbBonusPct: Record<Tier, number>;
  maxTraits: number;
}

export interface GameData {
  dragons: Record<string, DragonSpec>;
  traits: Record<string, TraitSpec>;
  recipes: Recipe[];
  slot: SlotConfig;
  waves: WaveConfig;
  battle: BattleConfig;
}

export interface RawGameData {
  dragons: DragonSpec[];
  traits: TraitSpec[];
  recipes: Recipe[];
  slot: SlotConfig;
  waves: WaveConfig;
  battle: BattleConfig;
}

export interface DragonInst { uid: number; speciesId: string; traits: string[]; bonusPct: number }
export type Zone = 'nest' | 'bench';
export interface SlotRef { zone: Zone; index: number }

/** 원소·여의주 칸은 스핀 때 종이 정해짐, 황금은 null */
export interface Cell { symbol: SymbolId; speciesId: string | null }
/** reels[col][0..4], 보이는 행 = 1+offset .. 3+offset */
export interface Grid { reels: Cell[][]; offsets: number[] }
export type Offer = { kind: 'egg'; speciesId: string } | { kind: 'mana'; amount: number };

export type Phase = 'spin' | 'pick' | 'manage' | 'battle' | 'gameOver' | 'victory';

export interface RunState {
  seed: number;
  rngState: number;
  wave: number;
  phase: Phase;
  lives: number;
  mana: number;
  nest: (DragonInst | null)[];
  nestOpen: number;
  bench: (DragonInst | null)[];
  grid: Grid | null;
  spinsThisWave: number;
  nudgesLeft: number;
  pity: number;
  nextUid: number;
  discovered: string[];
  log: Command[];
}
