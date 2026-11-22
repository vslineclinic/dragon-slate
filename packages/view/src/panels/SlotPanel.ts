import Phaser from 'phaser';
import { bestNudge, evaluateLines, lineRewards, LINES, nudge, offersFrom, recommendOffer, spinCost } from '../../../core/src/index.ts';
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
    this.reward = text(scene, a.x + 290, a.y + 30, '', 13, '#ffe066').setWordWrapWidth(330).setLineSpacing(2);
    this.spinBtn = button(scene, a.x + 290, a.y + 318, 330, 56, '', () => this.ctl.dispatch({ type: 'spin' }), 0x5f3dc4);
  }

  private last: RunState | null = null;

  render(s: RunState, events: GameEvent[]): void {
    this.last = s;
    this.layer.removeAll(true);
    const spun = events.some((e) => e.t === 'spun');
    if (s.grid) this.drawGrid(s, s.grid, spun);
    else this.drawEmpty();
    this.drawOffers(s);
    const costs = this.ctl.data.slot.rerollCosts;
    const owned = s.nest.some((n) => n) || s.bench.some((b) => b);
    const base = owned ? (costs[Math.min(s.spinsThisWave, costs.length - 1)] ?? 0) : 0;
    const cost = spinCost(this.ctl.data, s);
    const canSpin = (s.phase === 'spin' || s.phase === 'pick') && s.mana >= cost;
    const price = cost === 0 ? (base > 0 ? '보상 무료 ' + s.freeSpins + '회' : '무료') : '마력 ' + cost;
    this.spinBtn.setLabel((s.phase === 'pick' ? '다시 돌리기' : '룬 석판 돌리기') + ' (' + price + ')');
    this.spinBtn.setEnabled(canSpin);
    const full = s.bench.every((b) => b);
    this.hint.setText(
      s.phase === 'spin' ? '석판을 돌리면 알 3개가 나와요.'
        : s.phase === 'pick' ? (full ? '대기칸이 꽉 찼어요. 끌어서 합치거나 놓아주세요.' : '보라 띠의 알 3개 중 하나를 카드에서 골라요.')
          : s.phase === 'manage' ? '둥지를 정리하고 전투를 시작해요.' : '',
    );
    // 안내가 두 줄이 되어도 겹치지 않게 보상 문구를 바로 아래에 붙인다
    this.reward.setText(this.rewardText(s)).setY(this.hint.y + this.hint.height + 4);
  }

  /** 줄 맞춤이 무엇을 주는지 알려 주는 문구 */
  private rewardText(s: RunState): string {
    const d = this.ctl.data;
    const describe = (r: ReturnType<typeof lineRewards>) => {
      const eggs = r.eggs.map((e) => ELEMENT_KO[e.element] + (e.tier === 't2' ? ' 2티어 알 1개' : ' 알 1개')).join(', ');
      const mana = r.mana ? '마력 ' + r.mana : '';
      return eggs && mana ? eggs + '와 ' + mana : eggs || mana;
    };
    if (s.phase === 'spin') return '같은 그림 3개가 한 줄이면 알과 마력을 더 받아요. 가로·세로·대각선 모두 돼요.';
    if (s.phase !== 'pick' || !s.grid) return '';
    const now = lineRewards(d, s.grid);
    if (now.lines > 0) {
      const usesWild = evaluateLines(s.grid).some((g) => g.lines.some((li) => (LINES[li] ?? []).some(([c, r]) => {
        const reel = s.grid!.reels[c];
        return reel?.[1 + (s.grid!.offsets[c] ?? 0) + r]?.symbol === 'wild';
      })));
      const groups = evaluateLines(s.grid)
        .map((g) => (g.element === 'gold' ? '황금' : g.element === 'wild' ? '여의주' : ELEMENT_KO[g.element]) + ' ' + g.lines.length + '줄')
        .join(', ');
      return groups + ' 맞춤! 알을 고르면 함께 받아요: ' + describe(now) + '.' + (usesWild ? '\n분홍 여의주는 어떤 그림으로든 쳐요.' : '');
    }
    const reco = bestNudge(s.grid, s.nudgesLeft);
    if (reco) {
      const after = lineRewards(d, nudge(s.grid, reco.col, reco.dir));
      return '추천: ' + (reco.col + 1) + '번째 줄의 ' + (reco.dir === -1 ? '▼' : '▲') + '를 누르면 줄이 맞아요(보너스: ' + describe(after) + ').';
    }
    const goldOnly = now.mana;
    return (goldOnly ? '황금 칸 보너스: 마력 +' + goldOnly + '. ' : '') + (s.nudgesLeft > 0 ? '▼▲를 누르면 숨은 알이 들어오며 줄이 한 칸 밀려요(웨이브당 1번).' : '');
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
    // 매칭 표시와 헷갈리지 않게 테두리 대신 옅은 보라 띠 + 이름표로 표시한다
    const mid = this.cellXY(0, 1);
    this.layer.add(this.scene.add.rectangle(mid.x - 6, mid.y - 3, 3 * CELL + 2 * GAP + 12, CELL + 6, 0x7048e8, 0.28).setOrigin(0));
    this.layer.add(
      text(this.scene, mid.x + 3 * CELL + 2 * GAP + 4, mid.y + CELL / 2, '받을\n알 ▶', 12, '#d0bfff').setOrigin(0, 0.5).setLineSpacing(-2),
    );

    for (let c = 0; c < 3; c++) {
      const reel = grid.reels[c] ?? [];
      const off = grid.offsets[c] ?? 0;
      for (let r = 0; r < 3; r++) {
        const cell = reel[1 + off + r];
        if (!cell) continue;
        const { x, y } = this.cellXY(c, r);
        const egg = drawEgg(this.scene, x, y, CELL, CELL, cell.symbol);
        this.layer.add(egg);
        if (cell.symbol === 'wild' || cell.symbol === 'gold') {
          const tag = text(this.scene, x + CELL / 2, y + CELL - 9, cell.symbol === 'wild' ? '만능' : '마력', 11, '#ffffff')
            .setOrigin(0.5)
            .setBackgroundColor('#000000aa')
            .setPadding(3, 0, 3, 0);
          this.layer.add(tag);
          if (animate) {
            tag.setAlpha(0);
            this.scene.time.delayedCall(dur * 2.3, () => tag.active && tag.setAlpha(1));
          }
        }
        if (hitCells.has(c + ',' + r)) this.scene.time.delayedCall(animate ? dur * 2.3 : 0, () => egg.active && pulse(egg));
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
    // 맞은 줄을 실제 선으로 긋는다(원소색). 여의주가 끼어 있어도 어느 줄인지 보이게.
    const strokes = this.scene.add.graphics();
    for (const g of evaluateLines(grid)) {
      const color = COLOR[g.element];
      for (const li of g.lines) {
        const cells = LINES[li] ?? [];
        const pts = cells.map(([cc, rr]) => {
          const p = this.cellXY(cc, rr);
          return { x: p.x + CELL / 2, y: p.y + CELL / 2 };
        });
        for (let k = 0; k < pts.length - 1; k++) {
          const p1 = pts[k]!, p2 = pts[k + 1]!;
          strokes.lineStyle(8, 0xffffff, 0.95).lineBetween(p1.x, p1.y, p2.x, p2.y);
          strokes.lineStyle(4, color, 1).lineBetween(p1.x, p1.y, p2.x, p2.y);
        }
        for (const p of pts) {
          strokes.fillStyle(0xffffff, 1).fillCircle(p.x, p.y, 10);
          strokes.fillStyle(color, 1).fillCircle(p.x, p.y, 7);
        }
      }
    }
    strokes.setAlpha(animate ? 0 : 0.9);
    this.layer.add(strokes);
    if (animate) this.scene.time.delayedCall(dur * 2.3, () => strokes.active && this.scene.tweens.add({ targets: strokes, alpha: 0.9, duration: 200 }));
    if (animate) {
      // 연출 중에만 석판을 누르면 바로 결과로. 연출이 끝나면 이 영역을 없애 밀기 버튼을 가리지 않게 한다.
      const top = this.cellXY(0, 0);
      const skip = this.scene.add.rectangle(top.x - 10, top.y - 50, 3 * (CELL + GAP) + 20, 3 * (CELL + GAP) + 100, 0x000000, 0.001).setOrigin(0).setInteractive();
      const done = this.scene.time.delayedCall(dur * 2.3, () => {
        this.ctl.busy = false;
        if (skip.active) skip.destroy();
      });
      skip.on('pointerdown', () => {
        done.remove(false);
        this.ctl.busy = false;
        if (this.last) this.render(this.last, []);
      });
      this.layer.add(skip);
    }
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
