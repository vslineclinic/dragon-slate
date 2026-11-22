import type { RejectReason } from './commands.ts';
import type { DragonInst, Element, Grid, RewardSpec, SlotRef, SymbolId } from './types.ts';

export interface Unit { speciesId: string; elements: Element[]; hp: number; atk: number; cooldownTicks: number; lifestealPct: number }

export type BattleEvent =
  | { tick: number; kind: 'attack'; side: 'ally' | 'enemy'; src: number; dst: number; dmg: number; mult: number; heal: number }
  | { tick: number; kind: 'death'; side: 'ally' | 'enemy'; idx: number };

export interface BattleResult {
  winner: 'ally' | 'enemy';
  ticks: number;
  allies: (Unit | null)[];
  enemies: (Unit | null)[];
  events: BattleEvent[];
}

export type GameEvent =
  | { t: 'spun'; grid: Grid; cost: number }
  | { t: 'nudged'; grid: Grid }
  | { t: 'lineHit'; lines: number[]; element: SymbolId }
  | { t: 'gained'; inst: DragonInst; to: SlotRef; via: 'pick' | 'bonus' }
  | { t: 'mana'; delta: number; reason: string }
  | { t: 'evolved'; inst: DragonInst; at: SlotRef; firstTime: boolean }
  | { t: 'absorbed'; inst: DragonInst; at: SlotRef; trait: string | null }
  | { t: 'battle'; result: BattleResult }
  | { t: 'lives'; lives: number }
  /** detail: 받은 종 id, 특성 id 등 */
  | { t: 'reward'; reward: RewardSpec; detail: string | null }
  | { t: 'nestUnlocked'; open: number }
  | { t: 'waveStart'; wave: number; bossPreview: Element | null }
  | { t: 'gameOver' }
  | { t: 'victory' }
  | { t: 'rejected'; reason: RejectReason };
