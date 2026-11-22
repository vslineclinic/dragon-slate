export interface Rng {
  nextU32(): number;
  nextInt(maxExclusive: number): number;
  pickWeighted<T>(items: readonly T[], weight: (t: T) => number): T;
  state(): number;
}

/** mulberry32. 상태는 32비트 정수 하나라 저장·복원이 쉽다. */
export function createRng(seed: number, state?: number): Rng {
  let s = (state ?? seed) >>> 0;
  const nextU32 = (): number => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return (t ^ (t >>> 14)) >>> 0;
  };
  return {
    nextU32,
    nextInt: (max) => nextU32() % max,
    pickWeighted(items, weight) {
      let total = 0;
      for (const it of items) total += weight(it);
      let roll = nextU32() % total;
      for (const it of items) {
        roll -= weight(it);
        if (roll < 0) return it;
      }
      return items[items.length - 1] as (typeof items)[number];
    },
    state: () => s,
  };
}
