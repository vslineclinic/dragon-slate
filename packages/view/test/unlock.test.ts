import { describe, expect, test } from 'vitest';
import { nextUnlocked } from '../src/calamity-store.ts';

describe('calamity unlock', () => {
  test('unlock only on victory', () => {
    expect(nextUnlocked(0, 'gameOver', 0, 5)).toBe(0);
    expect(nextUnlocked(0, 'victory', 0, 5)).toBe(1);
  });
  test('clearing a lower level never lowers unlocks', () => {
    expect(nextUnlocked(3, 'victory', 1, 5)).toBe(3);
  });
  test('capped at max level', () => {
    expect(nextUnlocked(5, 'victory', 5, 5)).toBe(5);
    expect(nextUnlocked(1, 'victory', 1, 1)).toBe(1);
  });
});
