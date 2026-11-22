import Phaser from 'phaser';
import { bestNudge, evaluateLines, lineRewards, LINES, nudge, offersFrom, recommendOffer } from '../../../core/src/index.ts';
import type { GameEvent, Grid, RunState } from '../../../core/src/index.ts';
import type { GameController } from '../controller.ts';
import { AREA, COLOR, ELEMENT_KO, SYMBOL_LABEL, TIER_KO, UI } from '../layout.ts';
import { settings } from '../settings.ts';
import { button, text, type Button } from '../ui.ts';
import { pulse } from '../fx/juice.ts';
import { drawEgg, drawMark } from '../fx/icons.ts';
import { dragonImage } from '../fx/sprites.ts';

const CELL = 70;
const GAP = 6;
const TAB = 34;
const GX = AREA.slab.x + 30;
const GY = AREA.slab.y + 54; // 보이는 첫 행의 y
const RECO = 0xffd43b;

/** 룬 석판: 3×3 알, 줄마다 내리기/올리기 버튼, 제안 카드 3장, 돌리기 버튼 */
export class SlotPanel {
  private scene: Phaser.Scene;
  private ctl: GameController;
  private layer: Phaser.GameObjects.Container;
  private spinBtn: Button;
  private hint: Phaser.GameObjects.Text;
  private reward: Phaser.GameObjects.Text;

  constructor(scene: Phaser.Scene, ctl: GameController) {
    this.scene = scene;
    this.ctl = ctl;
    const a = AREA.slab;
    scene.add.rectangle(a.x, a.y, a.w, a.h, UI.panel).setOrigin(0).setStrokeStyle(1, UI.panelLine);
    this.layer = scene.add.container(0, 0);
    this.hint = text(scene, a.x + 290, a.y + 8, '', 14, UI.dim).setWordWrapWidth(330);
    this.reward = text(scene, a.x + 290, a.y + 30, '', 14, '#ffe066').setWordWrapWidth(330).setLineSpacing(2);
    this.spinBtn = button(scene, a.x + 290, a.y + 318, 330, 56, '', () => this.ctl.dispatch({ type: 'spin' }), 0x5f3dc4);
  }

  render(s: RunState, events: GameEvent[]): void {
    this.layer.removeAll(true);
    const spun = events.some((e) => e.t === 'spun');
    if (s.grid) this.drawGrid(s, s.grid, spun);
    else this.drawEmpty();
    this.drawOffers(s);
    const costs = this.ctl.data.slot.rerollCosts;
    const owned = s.nest.some((n) => n) || s.bench.some((b) => b);
    const base = owned ? (costs[Math.min(s.spinsThisWave, costs.length - 1)] ?? 0) : 0;
    const cost = base > 0 && s.freeSpins > 0 ? 0 : base;
    const canSpin = (s.phase === 'spin' || s.phase === 'pick') && s.mana >= cost;
    const price = cost === 0 ? (base > 0 ? '보상 무료 ' + s.freeSpins + '회' : '무료') : '마력 ' + cost;
    this.spinBtn.setLabel((s.phase === 'pick' ? '다시 돌리기' : '룬 석판 돌리기') + ' (' + price + ')');
    this.spinBtn.setEnabled(canSpin);
    const full = s.bench.every((b) => b);
    this.hint.setText(
      s.phase === 'spin' ? '석판을 돌리면 노란 줄의 알 3개 중 하나를 받아요.'
        : s.phase === 'pick' ? (full ? '대기칸이 꽉 찼어요. 왼쪽에서 끌어서 합치거나 놓아주세요.' : '노란 줄의 알 중 하나를 골라요.')
          : s.phase === 'manage' ? '둥지를 정리하고 전투를 시작해요.' : '',
    );
    this.reward.setText(this.rewardText(s));
  }

  /** 줄 맞춤이 무엇을 주는지 알려 주는 문구 */
  private rewardText(s: RunState): string {
    const d = this.ctl.data;
    const describe = (r: ReturnType<typeof lineRewards>) => {
      const eggs = r.eggs.map((e) => ELEMENT_KO[e.element] + (e.tier === 't2' ? ' 2티어 알' : ' 알')).join(', ');
      return [eggs, r.mana ? '마력 +' + r.mana : ''].filter(Boolean).join(' · ');
    };
    if (s.phase === 'spin') return '같은 그림 3개가 한 줄(가로·세로·대각)이면 보너스 알과 마력을 더 받아요. 드래곤이 빨리 모일수록 합체가 빨라져요.';
    if (s.phase !== 'pick' || !s.grid) return '';
    const now = lineRewards(d, s.grid);
    if (now.lines > 0) return '줄 맞춤 ' + now.lines + '줄! 알을 고르면 보너스도 함께 받아요: ' + describe(now);
    const reco = bestNudge(s.grid, s.nudgesLeft);
    if (reco) {
      const after = lineRewards(d, nudge(s.grid, reco.col, reco.dir));
      return '추천: ' + (reco.col + 1) + '번째 줄 ' + (reco.dir === -1 ? '▼' : '▲') + ' 버튼을 누르면 줄이 맞아요 → 보너스 ' + describe(after);
    }
    const goldOnly = now.mana;
    return (goldOnly ? '황금 칸 보너스: 마력 +' + goldOnly + '. ' : '') + (s.nudgesLeft > 0 ? '▼▲ 버튼은 숨은 알을 끌어와 그 줄을 한 칸 밀어요 (웨이브당 1번).' : '');
  }

  private cellXY(col: number, row: number): { x: number; y: number } {
    return { x: GX + col * (CELL + GAP), y: GY + row * (CELL + GAP) };
  }

  private drawEmpty(): void {
    for (let c = 0; c < 3; c++) {
      for (let r = 0; r < 3; r++) {
        const { x, y } = this.cellXY(c, r);
        const g = this.scene.add.graphics({ x, y });
        g.fillStyle(0x1e2230, 1).fillRoundedRect(0, 0, CELL, CELL, 12);
        g.lineStyle(2, 0x3a4157, 1).strokeEllipse(CELL / 2, CELL / 2, CELL * 0.62, CELL * 0.78);
        this.layer.add(g);
      }
    }
  }

  private drawGrid(s: RunState, grid: Grid, animate: boolean): void {
    const hitCells = new Set<string>();
    for (const g of evaluateLines(grid)) for (const li of g.lines) for (const [c, r] of LINES[li] ?? []) hitCells.add(c + ',' + r);
    const reco = s.phase === 'pick' ? bestNudge(grid, s.nudgesLeft) : null;
    const dur = 260 / settings.speed;

    // 가운데 줄(받을 수 있는 알) 표시
    const mid = this.cellXY(0, 1);
    this.layer.add(this.scene.add.rectangle(mid.x - 5, mid.y - 4, 3 * CELL + 2 * GAP + 10, CELL + 8).setOrigin(0).setStrokeStyle(3, 0xfab005, 0.9));

    for (let c = 0; c < 3; c++) {
      const reel = grid.reels[c] ?? [];
      const off = grid.offsets[c] ?? 0;
      for (let r = 0; r < 3; r++) {
        const cell = reel[1 + off + r];
        if (!cell) continue;
        const { x, y } = this.cellXY(c, r);
        const egg = drawEgg(this.scene, x, y, CELL, CELL, cell.symbol);
        this.layer.add(egg);
        if (hitCells.has(c + ',' + r)) {
          const ring = this.scene.add.rectangle(x - 2, y - 2, CELL + 4, CELL + 4).setOrigin(0).setStrokeStyle(4, 0xfff3bf, 1);
          this.layer.add(ring);
          this.scene.time.delayedCall(animate ? dur * 2.3 : 0, () => egg.active && pulse(egg));
        }
        if (animate) {
          egg.setScale(1, 0.1);
          egg.y = y + CELL / 2;
          this.ctl.busy = true;
          this.scene.tweens.add({ targets: egg, scaleY: 1, y, duration: dur, delay: c * dur * 0.6, ease: 'Back.out' });
        }
      }
      if (s.phase === 'pick' && s.nudgesLeft > 0) {
        // 위 버튼: 숨은 위칸을 끌어내림(dir -1), 아래 버튼: 숨은 아래칸을 끌어올림(dir +1)
        const above = reel[off];
        const below = reel[off + 4];
        if (above && off > -1) this.nudgeTab(c, -1, above.symbol, reco?.col === c && reco.dir === -1);
        if (below && off < 1) this.nudgeTab(c, 1, below.symbol, reco?.col === c && reco.dir === 1);
      }
    }
    if (animate) this.scene.time.delayedCall(dur * 2.3, () => (this.ctl.busy = false));
  }

  private nudgeTab(col: number, dir: -1 | 1, sym: Parameters<typeof drawMark>[1], recommended: boolean): void {
    const x = GX + col * (CELL + GAP);
    const y = dir === -1 ? GY - TAB - 6 : GY + 3 * (CELL + GAP);
    const g = this.scene.add.graphics({ x, y });
    g.fillStyle(recommended ? 0x5c4a00 : 0x2b3045, 1).fillRoundedRect(0, 0, CELL, TAB, 8);
    g.lineStyle(2, recommended ? RECO : 0x4c5470, 1).strokeRoundedRect(0, 0, CELL, TAB, 8);
    g.fillStyle(COLOR[sym], 1).fillCircle(CELL / 2 + 12, TAB / 2, 11);
    drawMark(g, sym, CELL / 2 + 12, TAB / 2, 13, 0x1b1f2a);
    const label = text(this.scene, x + CELL / 2 - 12, y + TAB / 2, dir === -1 ? '▼' : '▲', 18, recommended ? '#ffe066' : UI.text).setOrigin(0.5);
    const hit = this.scene.add.rectangle(x, y, CELL, Math.max(TAB, 40), 0x000000, 0).setOrigin(0, dir === -1 ? 0.15 : 0);
    hit.setInteractive({ useHandCursor: true });
    hit.on('pointerdown', () => this.ctl.dispatch({ type: 'nudge', col: col as 0 | 1 | 2, dir }));
    this.layer.add([g, label, hit]);
    if (recommended) {
      const badge = text(this.scene, x + CELL / 2, dir === -1 ? y - 10 : y + TAB + 10, '추천', 12, '#ffe066').setOrigin(0.5);
      this.layer.add(badge);
      this.scene.tweens.add({ targets: [g, label], alpha: 0.55, duration: 450, yoyo: true, repeat: -1 });
    }
  }

  private drawOffers(s: RunState): void {
    const a = AREA.slab;
    const x0 = a.x + 290;
    const offers = s.grid ? offersFrom(this.ctl.data, s.grid) : [];
    const reco = s.phase === 'pick' ? recommendOffer(this.ctl.data, s) : null;
    for (let i = 0; i < 3; i++) {
      const y = a.y + 86 + i * 76;
      const o = offers[i];
      const isReco = reco?.index === i;
      const bg = this.scene.add.rectangle(x0, y, 330, 68, 0x2b3045).setOrigin(0).setStrokeStyle(isReco ? 3 : 1, isReco ? RECO : UI.panelLine);
      this.layer.add(bg);
      if (!o) continue;
      if (o.kind === 'egg') {
        const spec = this.ctl.data.dragons[o.speciesId];
        const el = spec?.elements[0] ?? 'fire';
        const pic = dragonImage(this.scene, o.speciesId, x0 + 34, y + 34, 60, true);
        this.layer.add(pic ?? drawEgg(this.scene, x0 + 6, y + 6, 56, 56, el));
        this.layer.add(text(this.scene, x0 + 72, y + 10, (spec?.nameKo ?? o.speciesId) + ' 알', 18));
        this.layer.add(text(this.scene, x0 + 72, y + 38, TIER_KO[spec?.tier ?? 'base'] + ' · ' + SYMBOL_LABEL[el], 13, UI.dim));
      } else {
        this.layer.add(drawEgg(this.scene, x0 + 6, y + 6, 56, 56, 'gold'));
        this.layer.add(text(this.scene, x0 + 72, y + 22, '마력 +' + o.amount, 19));
      }
      if (isReco && reco) {
        const why = reco.reason === 'recipe' ? '추천 · 합치면 ' + (this.ctl.data.dragons[reco.result ?? '']?.nameKo ?? '진화') : '추천 · 둥지와 같은 원소';
        this.layer.add(text(this.scene, x0 + 324, y + 40, why, 12, '#ffe066').setOrigin(1, 0));
      }
      bg.setInteractive({ useHandCursor: true });
      bg.on('pointerdown', () => this.ctl.dispatch({ type: 'pick', index: i as 0 | 1 | 2 }));
    }
  }
}
