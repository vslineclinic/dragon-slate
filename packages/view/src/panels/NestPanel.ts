import Phaser from 'phaser';
import { evolvablePairs, mergePreview } from '../../../core/src/index.ts';
import { drawMark } from '../fx/icons.ts';
import { dragonImage } from '../fx/sprites.ts';
import type { DragonInst, RunState, SlotRef } from '../../../core/src/index.ts';
import type { GameController } from '../controller.ts';
import { AREA, COLOR, TIER_KO, UI } from '../layout.ts';
import { button, text, type Button } from '../ui.ts';

const W = 120;
const H = 88;

interface Rect { x: number; y: number; w: number; h: number }
type Target = { kind: 'slot'; ref: SlotRef } | { kind: 'release' };

/** 둥지 2행×3칸(위 후열 3~5, 아래 전열 0~2), 대기칸 4칸, 놓아주기 칸, 전투 시작 */
export class NestPanel {
  private scene: Phaser.Scene;
  private ctl: GameController;
  private layer: Phaser.GameObjects.Container;
  private preview: Phaser.GameObjects.Text;
  private battleBtn: Button;
  private releaseRect: Rect;
  private reco = new Map<string, string>();

  constructor(scene: Phaser.Scene, ctl: GameController) {
    this.scene = scene;
    this.ctl = ctl;
    const a = AREA.nest;
    scene.add.rectangle(a.x, a.y, a.w, a.h, UI.panel).setOrigin(0).setStrokeStyle(1, UI.panelLine);
    text(scene, a.x + 20, a.y + 8, '둥지  (위: 후열 · 아래: 전열)', 15, UI.dim);
    text(scene, a.x + 20, a.y + 236, '대기칸', 15, UI.dim);
    this.releaseRect = { x: a.x + 430, y: a.y + 34, w: 190, h: H };
    const r = this.releaseRect;
    scene.add.rectangle(r.x, r.y, r.w, r.h, 0x3b2a2a).setOrigin(0).setStrokeStyle(2, 0xff8787, 0.5);
    text(scene, r.x + r.w / 2, r.y + r.h / 2, '여기에 놓으면\n놓아주기 (마력)', 15, '#ffc9c9').setOrigin(0.5).setAlign('center');
    this.battleBtn = button(scene, a.x + 430, a.y + 140, 190, 72, '전투 시작', () => this.ctl.dispatch({ type: 'startBattle' }), 0xc92a2a);
    this.layer = scene.add.container(0, 0);
    this.preview = text(scene, 0, 0, '', 17, '#fff3bf').setDepth(40).setBackgroundColor('#000000cc').setPadding(6, 4, 6, 4).setVisible(false);
  }

  private slotRect(ref: SlotRef): Rect {
    const a = AREA.nest;
    if (ref.zone === 'bench') return { x: a.x + 20 + ref.index * (W + 10), y: a.y + 260, w: W, h: H };
    const row = ref.index >= 3 ? 0 : 1; // 후열(3~5) 위, 전열(0~2) 아래
    const col = ref.index % 3;
    return { x: a.x + 20 + col * (W + 10), y: a.y + 34 + row * (H + 8), w: W, h: H };
  }

  private allRefs(): SlotRef[] {
    const refs: SlotRef[] = [];
    for (let i = 0; i < 6; i++) refs.push({ zone: 'nest', index: i });
    for (let i = 0; i < 4; i++) refs.push({ zone: 'bench', index: i });
    return refs;
  }

  private targetAt(x: number, y: number): Target | null {
    const inside = (r: Rect) => x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h;
    if (inside(this.releaseRect)) return { kind: 'release' };
    for (const ref of this.allRefs()) if (inside(this.slotRect(ref))) return { kind: 'slot', ref };
    return null;
  }

  private instAt(s: RunState, ref: SlotRef): DragonInst | null {
    return (ref.zone === 'nest' ? s.nest : s.bench)[ref.index] ?? null;
  }

  render(s: RunState): void {
    this.layer.removeAll(true);
    const manage = s.phase === 'manage' || s.phase === 'pick' || s.phase === 'spin';
    const key = (r: SlotRef) => r.zone + r.index;
    const evolve = new Map<string, string>();
    for (const p of evolvablePairs(this.ctl.data, s)) {
      const name = this.ctl.data.dragons[p.result]?.nameKo ?? p.result;
      evolve.set(key(p.a), name);
      evolve.set(key(p.b), name);
    }
    this.reco = evolve;
    for (const ref of this.allRefs()) {
      const r = this.slotRect(ref);
      const locked = ref.zone === 'nest' && ref.index >= s.nestOpen;
      this.layer.add(this.scene.add.rectangle(r.x, r.y, r.w, r.h, locked ? 0x1a1d27 : 0x2b3045).setOrigin(0).setStrokeStyle(1, UI.panelLine));
      if (locked) this.layer.add(text(this.scene, r.x + r.w / 2, r.y + r.h / 2, '잠김', 15, '#5c6378').setOrigin(0.5));
      const inst = this.instAt(s, ref);
      if (inst) this.layer.add(this.card(s, ref, inst, manage));
    }
    this.battleBtn.setEnabled(s.phase === 'manage' && s.nest.some((n, i) => n !== null && i < s.nestOpen));
  }

  private card(s: RunState, ref: SlotRef, inst: DragonInst, draggable: boolean): Phaser.GameObjects.Container {
    const spec = this.ctl.data.dragons[inst.speciesId];
    const r = this.slotRect(ref);
    const els = spec?.elements ?? ['fire'];
    const g = this.scene.add.graphics();
    g.fillStyle(0x1e2230, 1).fillRoundedRect(0, 0, W, H, 10);
    els.forEach((el, i) => g.fillStyle(COLOR[el], 1).fillRect(10 + i * ((W - 20) / els.length), 0, (W - 20) / els.length, 6));
    g.lineStyle(2, COLOR[els[0] ?? 'fire'], 0.9).strokeRoundedRect(0, 0, W, H, 10);
    els.forEach((el, i) => {
      g.fillStyle(COLOR[el], 1).fillCircle(W - 18 - i * 22, 26, 10);
      drawMark(g, el, W - 18 - i * 22, 26, 12, 0x1b1f2a);
    });
    const parts: Phaser.GameObjects.GameObject[] = [g];
    const evolveTo = this.reco.get(ref.zone + ref.index);
    if (evolveTo) {
      const glow = this.scene.add.rectangle(-3, -3, W + 6, H + 6).setOrigin(0).setStrokeStyle(3, 0xffd43b, 1);
      parts.push(glow);
      this.scene.tweens.add({ targets: glow, alpha: 0.3, duration: 500, yoyo: true, repeat: -1 });
    }
    const tier = spec?.tier ?? 'base';
    const img = dragonImage(this.scene, inst.speciesId, W / 2 - 6, 38, 62, true);
    const dots = '●'.repeat(inst.traits.length) + '○'.repeat(Math.max(0, this.ctl.data.battle.maxTraits - inst.traits.length));
    if (img) {
      parts.push(img);
      parts.push(text(this.scene, 6, 8, TIER_KO[tier], 11, tier === 'base' ? UI.dim : '#ffd8a8'));
      parts.push(text(this.scene, W / 2, 70, spec?.nameKo ?? inst.speciesId, 12, UI.text).setOrigin(0.5, 0));
      parts.push(text(this.scene, 6, 52, dots + (inst.bonusPct ? '\n+' + inst.bonusPct + '%' : ''), 10, UI.dim));
    } else {
      parts.push(text(this.scene, 8, 12, spec?.nameKo ?? inst.speciesId, 14, UI.text).setWordWrapWidth(W - 40));
      parts.push(text(this.scene, 8, 50, TIER_KO[tier], 12, tier === 'base' ? UI.dim : '#ffd8a8'));
      parts.push(text(this.scene, 8, 68, dots + (inst.bonusPct ? '  +' + inst.bonusPct + '%' : ''), 12, UI.dim));
    }
    if (evolveTo) parts.push(text(this.scene, W - 6, 52, '합체\n가능', 10, '#ffe066').setOrigin(1, 0).setAlign('right'));
    const c = this.scene.add.container(r.x, r.y, parts);
    if (!draggable) return c;
    c.setSize(W, H);
    c.setInteractive(new Phaser.Geom.Rectangle(W / 2, H / 2, W, H), Phaser.Geom.Rectangle.Contains);
    this.scene.input.setDraggable(c);
    c.on('dragstart', () => c.setDepth(30).setAlpha(0.85));
    c.on('drag', (p: Phaser.Input.Pointer, dx: number, dy: number) => {
      c.setPosition(dx, dy);
      this.showPreview(s, ref, inst, p.x, p.y);
    });
    c.on('dragend', (p: Phaser.Input.Pointer) => {
      this.preview.setVisible(false);
      c.setPosition(r.x, r.y).setAlpha(1).setDepth(0);
      this.drop(s, ref, p.x, p.y);
    });
    return c;
  }

  private showPreview(s: RunState, from: SlotRef, inst: DragonInst, x: number, y: number): void {
    const t = this.targetAt(x, y);
    let msg = '';
    if (t?.kind === 'release') {
      const tier = this.ctl.data.dragons[inst.speciesId]?.tier ?? 'base';
      msg = '놓아주기: 마력 +' + (this.ctl.data.waves.releaseMana[tier] ?? 0);
    } else if (t?.kind === 'slot' && !(t.ref.zone === from.zone && t.ref.index === from.index)) {
      const other = this.instAt(s, t.ref);
      if (t.ref.zone === 'nest' && t.ref.index >= s.nestOpen) msg = '잠긴 칸';
      else if (other) {
        const p = mergePreview(this.ctl.data, other, inst);
        if (p.kind === 'evolve') msg = '진화 → ' + (this.ctl.data.dragons[p.result]?.nameKo ?? p.result);
        else {
          const tier = this.ctl.data.dragons[inst.speciesId]?.tier ?? 'base';
          const trait = p.trait ? this.ctl.data.traits[p.trait]?.nameKo : null;
          msg = '흡수: 능력치 +' + (this.ctl.data.battle.absorbBonusPct[tier] ?? 0) + '%' + (trait ? ', 특성 「' + trait + '」' : '');
        }
      } else msg = '이동';
    }
    this.preview.setText(msg).setPosition(x + 16, y - 40).setVisible(msg !== '');
  }

  private drop(s: RunState, from: SlotRef, x: number, y: number): void {
    const t = this.targetAt(x, y);
    if (!t) return;
    if (t.kind === 'release') {
      this.ctl.dispatch({ type: 'release', from });
      return;
    }
    if (t.ref.zone === from.zone && t.ref.index === from.index) return;
    if (this.instAt(s, t.ref)) this.ctl.dispatch({ type: 'merge', main: t.ref, material: from });
    else this.ctl.dispatch({ type: 'move', from, to: t.ref });
  }
}
