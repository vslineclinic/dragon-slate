import Phaser from 'phaser';
import { evaluateLines, LINES, offersFrom } from '../../../core/src/index.ts';
import type { GameEvent, Grid, RunState } from '../../../core/src/index.ts';
import type { GameController } from '../controller.ts';
import { AREA, COLOR, SYMBOL_LABEL, TIER_KO, UI } from '../layout.ts';
import { settings } from '../settings.ts';
import { button, text, type Button } from '../ui.ts';
import { pulse } from '../fx/juice.ts';

const CELL = 70;
const GAP = 6;
const GX = AREA.slab.x + 30;
const GY = AREA.slab.y + 16;

/** 룬 석판: 3×3(+위아래로 살짝 보이는 칸), 제안 카드 3장, 돌리기 버튼 */
export class SlotPanel {
  private scene: Phaser.Scene;
  private ctl: GameController;
  private layer: Phaser.GameObjects.Container;
  private spinBtn: Button;
  private hint: Phaser.GameObjects.Text;

  constructor(scene: Phaser.Scene, ctl: GameController) {
    this.scene = scene;
    this.ctl = ctl;
    const a = AREA.slab;
    scene.add.rectangle(a.x, a.y, a.w, a.h, UI.panel).setOrigin(0).setStrokeStyle(1, UI.panelLine);
    this.layer = scene.add.container(0, 0);
    this.hint = text(scene, a.x + 290, a.y + 16, '', 16, UI.dim);
    this.spinBtn = button(scene, a.x + 290, a.y + 318, 330, 56, '', () => this.ctl.dispatch({ type: 'spin' }), 0x5f3dc4);
  }

  /** 상태 전체를 다시 그린다. animate면 석판이 도는 짧은 연출을 넣는다. */
  render(s: RunState, events: GameEvent[]): void {
    this.layer.removeAll(true);
    const spun = events.some((e) => e.t === 'spun');
    if (s.grid) this.drawGrid(s, s.grid, spun);
    else this.drawEmpty();
    this.drawOffers(s);
    const costs = this.ctl.data.slot.rerollCosts;
    const owned = s.nest.some((n) => n) || s.bench.some((b) => b);
    const cost = owned ? (costs[Math.min(s.spinsThisWave, costs.length - 1)] ?? 0) : 0;
    const canSpin = (s.phase === 'spin' || s.phase === 'pick') && s.mana >= cost;
    this.spinBtn.setLabel(s.phase === 'pick' ? '다시 돌리기 (마력 ' + cost + ')' : cost === 0 ? '룬 석판 돌리기 (무료)' : '룬 석판 돌리기 (마력 ' + cost + ')');
    this.spinBtn.setEnabled(canSpin);
    this.hint.setText(
      s.phase === 'spin' ? '석판을 돌려 알을 받아요'
        : s.phase === 'pick' ? (s.bench.every((b) => b) ? '대기칸이 꽉 찼어요. 끌어서 합치거나 놓아주세요' : '가운데 줄에서 알 하나를 골라요') + '\n위·아래 흐린 칸을 누르면 밀기 (남은 ' + s.nudgesLeft + '회)'
          : s.phase === 'manage' ? '둥지를 정리하고 전투를 시작해요' : '',
    );
  }

  private cellXY(col: number, row: number): { x: number; y: number } {
    return { x: GX + col * (CELL + GAP), y: GY + (row + 1) * (CELL + GAP) };
  }

  private drawEmpty(): void {
    for (let c = 0; c < 3; c++) {
      for (let r = 0; r < 3; r++) {
        const { x, y } = this.cellXY(c, r);
        this.layer.add(this.scene.add.rectangle(x, y, CELL, CELL, 0x2b3045).setOrigin(0).setStrokeStyle(1, UI.panelLine));
      }
    }
  }

  private drawGrid(s: RunState, grid: Grid, animate: boolean): void {
    const hitCells = new Set<string>();
    for (const g of evaluateLines(grid)) for (const li of g.lines) for (const [c, r] of LINES[li] ?? []) hitCells.add(c + ',' + r);
    const dur = 260 / settings.speed;
    for (let c = 0; c < 3; c++) {
      const reel = grid.reels[c] ?? [];
      const off = grid.offsets[c] ?? 0;
      for (let i = 0; i < reel.length; i++) {
        const row = i - 1 - off; // 보이는 행 0~2, 위 -1, 아래 3
        if (row < -1 || row > 3) continue;
        const cell = reel[i];
        if (!cell) continue;
        const peek = row < 0 || row > 2;
        const { x, y } = this.cellXY(c, row);
        const box = this.scene.add.rectangle(x, y, CELL, CELL, COLOR[cell.symbol]).setOrigin(0);
        box.setAlpha(peek ? 0.28 : 1);
        if (!peek && row === 1) box.setStrokeStyle(3, 0xffffff, 0.55);
        if (!peek && hitCells.has(c + ',' + row)) {
          box.setStrokeStyle(5, 0xfff3bf, 1);
          this.scene.time.delayedCall(animate ? dur * 2.3 : 0, () => box.active && pulse(box));
        }
        const label = text(this.scene, x + CELL / 2, y + CELL / 2, SYMBOL_LABEL[cell.symbol], 17, '#111').setOrigin(0.5).setAlpha(peek ? 0.5 : 1);
        this.layer.add([box, label]);
        if (peek && s.phase === 'pick' && s.nudgesLeft > 0) {
          const dir = row < 0 ? -1 : 1;
          const arrow = text(this.scene, x + CELL / 2, y + (row < 0 ? CELL - 12 : 12), row < 0 ? '▼' : '▲', 18, '#ffffff').setOrigin(0.5);
          box.setInteractive({ useHandCursor: true });
          box.on('pointerdown', () => this.ctl.dispatch({ type: 'nudge', col: c as 0 | 1 | 2, dir }));
          this.layer.add(arrow);
        }
        if (animate && !peek) {
          box.setScale(1, 0.1);
          label.setAlpha(0);
          this.ctl.busy = true;
          this.scene.tweens.add({ targets: box, scaleY: 1, duration: dur, delay: c * dur * 0.6, ease: 'Back.out' });
          this.scene.tweens.add({ targets: label, alpha: 1, duration: dur, delay: c * dur * 0.6 });
        }
      }
    }
    if (animate) this.scene.time.delayedCall(dur * 2.3, () => (this.ctl.busy = false));
  }

  private drawOffers(s: RunState): void {
    const a = AREA.slab;
    const x0 = a.x + 290;
    const offers = s.grid ? offersFrom(this.ctl.data, s.grid) : [];
    for (let i = 0; i < 3; i++) {
      const y = a.y + 74 + i * 78;
      const o = offers[i];
      const bg = this.scene.add.rectangle(x0, y, 330, 68, 0x2b3045).setOrigin(0).setStrokeStyle(1, UI.panelLine);
      this.layer.add(bg);
      if (!o) continue;
      if (o.kind === 'egg') {
        const spec = this.ctl.data.dragons[o.speciesId];
        const el = spec?.elements[0] ?? 'fire';
        this.layer.add(this.scene.add.rectangle(x0 + 8, y + 8, 52, 52, COLOR[el]).setOrigin(0));
        this.layer.add(text(this.scene, x0 + 72, y + 10, (spec?.nameKo ?? o.speciesId) + ' 알', 19));
        this.layer.add(text(this.scene, x0 + 72, y + 38, TIER_KO[spec?.tier ?? 'base'] + ' · ' + SYMBOL_LABEL[el], 14, UI.dim));
      } else {
        this.layer.add(this.scene.add.rectangle(x0 + 8, y + 8, 52, 52, COLOR.gold).setOrigin(0));
        this.layer.add(text(this.scene, x0 + 72, y + 20, '마력 +' + o.amount, 20));
      }
      bg.setInteractive({ useHandCursor: true });
      bg.on('pointerdown', () => this.ctl.dispatch({ type: 'pick', index: i as 0 | 1 | 2 }));
    }
  }
}
