const KEY = 'wyrmslot.discovered';

/** 발견 기록은 브라우저에만 저장(판과 무관한 도감) */
export function loadDiscovered(): Set<string> {
  try {
    const raw = localStorage.getItem(KEY);
    return new Set(raw ? (JSON.parse(raw) as string[]) : []);
  } catch {
    return new Set();
  }
}

/** 처음이면 true */
export function markDiscovered(id: string): boolean {
  const set = loadDiscovered();
  if (set.has(id)) return false;
  set.add(id);
  try {
    localStorage.setItem(KEY, JSON.stringify([...set]));
  } catch {
    /* 저장 못 해도 진행 */
  }
  return true;
}
