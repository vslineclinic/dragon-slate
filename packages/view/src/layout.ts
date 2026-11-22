import type { SymbolId, Tier } from '../../core/src/index.ts';

/** 영역(px, 1280×720 기준). 위 전투, 아래 왼쪽 둥지, 아래 오른쪽 석판. */
export const AREA = {
  hud: { x: 0, y: 0, w: 1280, h: 44 },
  battle: { x: 0, y: 44, w: 1280, h: 286 },
  nest: { x: 0, y: 330, w: 640, h: 390 },
  slab: { x: 640, y: 330, w: 640, h: 390 },
} as const;

export const COLOR: Record<SymbolId, number> = {
  fire: 0xe8590c,
  ice: 0x4dabf7,
  lightning: 0xfab005,
  gold: 0xd4af37,
  wild: 0x9775fa,
};

export const SYMBOL_LABEL: Record<SymbolId, string> = { fire: '불', ice: '얼음', lightning: '번개', gold: '금', wild: '여의주' };
export const ELEMENT_KO: Record<string, string> = { fire: '불', ice: '얼음', lightning: '번개' };
export const TIER_KO: Record<Tier, string> = { base: '기본', t2: '2티어', t1: '1티어', dual: '이중', secret: '???' };

export const UI = {
  panel: 0x232838,
  panelLine: 0x3a4157,
  text: '#e9ecf5',
  dim: '#8a93ab',
  font: '"Pretendard", "Noto Sans KR", "Malgun Gothic", sans-serif',
  minTouch: 48,
} as const;
