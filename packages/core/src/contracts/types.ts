import type { Command } from './commands.ts';

export type Element = 'fire' | 'ice' | 'lightning' | 'poison' | 'steel' | 'abyss';
/** 원소 순서(화면·도감 정렬용). 실제로 쓰이는 원소는 activeElements(data)로 구한다 */
export const ELEMENTS: readonly Element[] = ['fire', 'ice', 'lightning', 'poison', 'steel', 'abyss'];
export type SymbolId = Element | 'gold' | 'wild';
export type Tier = 'base' | 't2' | 't1' | 'dual' | 'secret';
export type Role = 'front' | 'back' | 'support';
export type TraitKind = 'atkPct' | 'hpPct' | 'hastePct' | 'lifestealPct';

export interface Stats { hp: number; atk: number; cooldownTicks: number }
export interface DragonSpec { id: string; nameKo: string; tier: Tier; elements: Element[]; role: Role; stats: Stats; traitId: string }
export interface TraitSpec { id: string; nameKo: string; kind: TraitKind; value: number }
export interface Recipe { a: string; b: string; result: string }
/** 심판 보스 기믹. 피해는 대상 최대 체력의 %(정수 내림, 최소 1) */
export interface BossRules {
  healCutPct?: number;
  healCutFromTick?: number;
  burn?: { everyTicks: number; pct: number };
  rowBlast?: { everyTicks: number; pct: number };
  allySlowPct?: number;
  enrage?: { atTick: number; atkPct: number };
  pulse?: { everyTicks: number; pct: number };
}
export interface BossSpec { wave: number; nameKo: string; descKo: string; hintKo: string; rules: BossRules }
/** 재앙 단계 수정치. 고른 단계까지 누적 적용 */
export interface CalamitySpec { level: number; nameKo: string; descKo: string; enemyPowerPct?: number; bossPowerPct?: number; winManaPct?: number; rerollCostAdd?: number; startLivesAdd?: number }
export type RewardKind = 'mana' | 'egg' | 't2egg' | 'trait' | 'nudge' | 'freeSpin' | 'life';
/** 웨이브 승리 보상. weight는 일반 웨이브, bossWeight는 심판 보스 웨이브 확률 가중치 */
export interface RewardSpec { id: string; nameKo: string; kind: RewardKind; amount: number; weight: number; bossWeight: number }

export interface SlotConfig {
  weights: Partial<Record<SymbolId, number>>;
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
  /** 원소별로 이기는 원소 목록 */
  beats: Partial<Record<Element, Element[]>>;
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
  rewards: RewardSpec[];
  bosses: BossSpec[];
  calamity: CalamitySpec[];
}

export interface RawGameData {
  dragons: DragonSpec[];
  traits: TraitSpec[];
  recipes: Recipe[];
  slot: SlotConfig;
  waves: WaveConfig;
  battle: BattleConfig;
  rewards?: RewardSpec[];
  bosses?: BossSpec[];
  calamity?: CalamitySpec[];
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
  /** 재앙 단계(0 = 없음) */
  calamity: number;
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
  /** 보상으로 받은, 다음 웨이브에 더해질 밀기 */
  bonusNudges: number;
  /** 보상으로 받은 무료 다시 돌리기 */
  freeSpins: number;
  discovered: string[];
  log: Command[];
}
