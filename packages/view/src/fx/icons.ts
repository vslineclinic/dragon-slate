import Phaser from 'phaser';
import type { SymbolId } from '../../../core/src/index.ts';
import { COLOR } from '../layout.ts';

/** 원소 문양을 그린다. (cx, cy) 중심, s = 대략적인 크기(px) */
export function drawMark(g: Phaser.GameObjects.Graphics, sym: SymbolId, cx: number, cy: number, s: number, color = 0xffffff): void {
  const u = s / 2;
  g.fillStyle(color, 1);
  g.lineStyle(Math.max(2, s / 12), color, 1);
  if (sym === 'fire') {
    const pts = [
      [0, -1], [0.35, -0.35], [0.55, 0.1], [0.5, 0.5], [0.2, 0.85], [-0.2, 0.85], [-0.5, 0.5], [-0.55, 0.05], [-0.3, -0.25], [-0.1, 0.05],
    ].map(([x, y]) => new Phaser.Math.Vector2(cx + x! * u, cy + y! * u));
    g.fillPoints(pts, true);
  } else if (sym === 'ice') {
    for (let i = 0; i < 3; i++) {
      const a = (Math.PI / 3) * i;
      const dx = Math.cos(a) * u, dy = Math.sin(a) * u;
      g.lineBetween(cx - dx, cy - dy, cx + dx, cy + dy);
      for (const k of [1, -1]) {
        const bx = cx + k * dx * 0.55, by = cy + k * dy * 0.55;
        const b = 0.32 * u;
        g.lineBetween(bx, by, bx + Math.cos(a + k * 2.4) * b * k, by + Math.sin(a + k * 2.4) * b * k);
        g.lineBetween(bx, by, bx + Math.cos(a - k * 2.4) * b * k, by + Math.sin(a - k * 2.4) * b * k);
      }
    }
  } else if (sym === 'lightning') {
    const pts = [[0.15, -1], [-0.5, 0.1], [-0.05, 0.1], [-0.2, 1], [0.5, -0.15], [0.05, -0.15], [0.3, -1]].map(
      ([x, y]) => new Phaser.Math.Vector2(cx + x! * u, cy + y! * u),
    );
    g.fillPoints(pts, true);
  } else if (sym === 'poison') {
    // 독: 물방울 + 작은 거품
    const pts = [[0, -1], [0.45, -0.1], [0.6, 0.35], [0.4, 0.8], [0, 0.95], [-0.4, 0.8], [-0.6, 0.35], [-0.45, -0.1]].map(
      ([x, y]) => new Phaser.Math.Vector2(cx + x! * u, cy + y! * u),
    );
    g.fillPoints(pts, true);
    g.fillCircle(cx + u * 0.75, cy - u * 0.55, u * 0.16);
  } else if (sym === 'steel') {
    // 강철: 방패
    const pts = [[-0.75, -0.8], [0.75, -0.8], [0.7, 0.15], [0, 0.95], [-0.7, 0.15]].map(([x, y]) => new Phaser.Math.Vector2(cx + x! * u, cy + y! * u));
    g.fillPoints(pts, true);
  } else if (sym === 'abyss') {
    // 심연: 고리 + 눈동자
    g.strokeCircle(cx, cy, u * 0.78);
    g.fillEllipse(cx, cy, u * 0.5, u * 0.9);
  } else if (sym === 'gold') {
    g.fillStyle(0xfff3bf, 1);
    g.fillEllipse(cx, cy, s * 0.62, s * 0.8);
    g.fillStyle(0xffffff, 0.9);
    g.fillEllipse(cx - s * 0.1, cy - s * 0.16, s * 0.14, s * 0.22);
  } else {
    g.fillStyle(0xf3f0ff, 1);
    g.fillCircle(cx, cy, u * 0.72);
    g.fillStyle(0x9775fa, 0.55);
    g.fillCircle(cx + u * 0.15, cy + u * 0.15, u * 0.45);
    g.fillStyle(0xffffff, 1);
    g.fillCircle(cx - u * 0.28, cy - u * 0.28, u * 0.16);
  }
}

/** 석판 칸: 원소색 알 + 문양 */
export function drawEgg(scene: Phaser.Scene, x: number, y: number, w: number, h: number, sym: SymbolId): Phaser.GameObjects.Graphics {
  const g = scene.add.graphics({ x, y });
  g.fillStyle(0x1e2230, 1);
  g.fillRoundedRect(0, 0, w, h, 12);
  const c = COLOR[sym];
  g.fillStyle(Phaser.Display.Color.IntegerToColor(c).darken(35).color, 1);
  g.fillEllipse(w / 2, h / 2 + 3, w * 0.7, h * 0.86);
  g.fillStyle(c, 1);
  g.fillEllipse(w / 2, h / 2, w * 0.66, h * 0.82);
  g.fillStyle(0xffffff, 0.25);
  g.fillEllipse(w / 2 - w * 0.12, h / 2 - h * 0.2, w * 0.18, h * 0.24);
  drawMark(g, sym, w / 2, h / 2 + 2, Math.min(w, h) * 0.42, sym === 'gold' || sym === 'wild' ? 0xffffff : 0x1b1f2a);
  return g;
}
