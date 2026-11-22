import type { SlotRef } from './types.ts';

export type Command =
  | { type: 'spin' }
  | { type: 'nudge'; col: 0 | 1 | 2; dir: -1 | 1 }
  | { type: 'pick'; index: 0 | 1 | 2 }
  | { type: 'merge'; main: SlotRef; material: SlotRef }
  | { type: 'move'; from: SlotRef; to: SlotRef }
  | { type: 'release'; from: SlotRef }
  | { type: 'startBattle' };

export type RejectReason =
  | 'wrongPhase'
  | 'notEnoughMana'
  | 'noNudgeLeft'
  | 'benchFull'
  | 'emptySlot'
  | 'slotLocked'
  | 'nestEmpty'
  | 'sameSlot'
  | 'needDragon';
