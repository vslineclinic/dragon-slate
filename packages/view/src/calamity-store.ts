import type { Phase } from '../../core/src/index.ts';

const KEY = 'wyrmslot.calamity.unlocked';

/** 판이 끝났을 때 새로 열린 최고 재앙 단계. 이긴 판만 다음 단계를 연다. */
export function nextUnlocked(current: number, phase: Phase, playedLevel: number, maxLevel: number): number {
  if (phase !== 'victory') return current;
  return Math.max(current, Math.min(maxLevel, playedLevel + 1));
}

export function loadUnlocked(): number {
  try {
    const v = Number(localStorage.getItem(KEY));
    return Number.isInteger(v) && v > 0 ? v : 0;
  } catch {
    return 0;
  }
}

export function saveUnlocked(level: number): void {
  try {
    localStorage.setItem(KEY, String(level));
  } catch {
    /* 저장 못 해도 진행 */
  }
}
