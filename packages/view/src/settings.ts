export type Speed = 1 | 2 | 4;

const KEY = 'wyrmslot.speed';

function read(): Speed {
  try {
    const v = Number(localStorage.getItem(KEY));
    return v === 2 || v === 4 ? v : 1;
  } catch {
    return 1;
  }
}

export const settings = {
  speed: read(),
  setSpeed(s: Speed): void {
    this.speed = s;
    try {
      localStorage.setItem(KEY, String(s));
    } catch {
      /* 저장 못 해도 진행 */
    }
  },
};
