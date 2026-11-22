import Phaser from 'phaser';
import type { BattleEvent, BattleResult, GameData, RunState, Unit } from '../../../core/src/index.ts';
import { AREA, COLOR, UI } from '../layout.ts';
import { settings } from '../settings.ts';
import { button, text, type Button } from '../ui.ts';
import { damageNumber, hitFlash, hitstop, shake } from '../fx/juice.ts';
import { drawMark } from '../fx/icons.ts';
import { dragonImage } from '../fx/sprites.ts';

const UW = 116;
const UH = 70;
const MS_PER_TICK = 50;

interface View { box: Phaser.GameObjects.Rectangle; bar: Phaser.GameObjects.Rectangle; root: Phaser.GameObjects.Container; hp: number; max: number; x: number; y: number }

/** 위쪽 전투 영역. 왼쪽 아군 6칸, 오른쪽 적 6칸. core가 미리 계산한 이벤트를 틱 순서로 재생한다. */
export class BattlePanel {
  private scene: Phaser.Scene;
  private data: GameData;
  private layer: Phaser.GameObjects.Container;
  private caption: Phaser.GameObjects.Text;
  private skipBtn: Button;
  private views: { ally: (View | null)[]; enemy: (View | null)[] } = { ally: [], enemy: [] };
  private skipping = false;

  constructor(scene: Phaser.Scene, data: GameData) {
    this.scene = scene;
    this.data = data;
    const a = AREA.battle;
    scene.add.rectangle(a.x, a.y, a.w, a.h, 0x161a24).setOrigin(0);
    scene.add.rectangle(640, a.y + 10, 2, a.h - 20, 0x2b3045).setOrigin(0.5, 0);
    this.layer = scene.add.container(0, 0);
    this.caption = text(scene, 640, a.y + a.h - 26, '', 16, UI.dim).setOrigin(0.5);
    this.skipBtn = button(scene, 1140, a.y + 8, 124, 44, '건너뛰기 ▶▶', () => (this.skipping = true), 0x2b3045);
    this.skipBtn.root.setVisible(false);
  }

  private slotXY(side: 'ally' | 'enemy', idx: number): { x: number; y: number } {
    const front = idx < 3;
    const row = idx % 3;
    const col = side === 'ally' ? (front ? 480 : 340) : front ? 684 : 824;
    return { x: col, y: AREA.battle.y + 16 + row * 86 };
  }

  private drawUnits(allies: (Unit | null)[], enemies: (Unit | null)[]): void {
    this.layer.removeAll(true);
    const make = (side: 'ally' | 'enemy', u: Unit | null, i: number): View | null => {
      if (!u) return null;
      const { x, y } = this.slotXY(side, i);
      const el = u.elements[0] ?? 'fire';
      const box = this.scene.add.rectangle(0, 0, UW, UH, 0x1e2230).setOrigin(0).setStrokeStyle(3, COLOR[el], side === 'ally' ? 1 : 0.7);
      const mark = this.scene.add.graphics();
      mark.fillStyle(COLOR[el], 1).fillCircle(UW - 18, 20, 12);
      drawMark(mark, el, UW - 18, 20, 14, 0x1b1f2a);
      const name = text(this.scene, 6, 8, this.data.dragons[u.speciesId]?.nameKo ?? u.speciesId, 13, UI.text).setWordWrapWidth(UW - 40);
      const barBg = this.scene.add.rectangle(6, UH - 14, UW - 12, 8, 0x000000, 0.5).setOrigin(0);
      const bar = this.scene.add.rectangle(6, UH - 14, UW - 12, 8, 0x51cf66).setOrigin(0);
      const img = dragonImage(this.scene, u.speciesId, 34, 32, 60, side === 'ally');
      if (img) {
        name.setPosition(64, 8).setFontSize(12).setWordWrapWidth(UW - 68);
        mark.destroy();
      }
      const root = this.scene.add.container(x, y, img ? [box, img, name, barBg, bar] : [box, mark, name, barBg, bar]);
      this.layer.add(root);
      return { box, bar, root, hp: u.hp, max: u.hp, x, y };
    };
    this.views = { ally: allies.map((u, i) => make('ally', u, i)), enemy: enemies.map((u, i) => make('enemy', u, i)) };
  }

  /** 전투가 없을 때: 내 둥지를 보여 준다 */
  showIdle(s: RunState): void {
    const allies = s.nest.map((n) => (n ? ({ speciesId: n.speciesId, elements: this.data.dragons[n.speciesId]?.elements ?? ['fire'], hp: 1, atk: 0, cooldownTicks: 1, lifestealPct: 0 } as Unit) : null));
    this.drawUnits(allies, []);
    const boss = this.data.waves.bossPct[String(s.wave)] !== undefined;
    this.caption.setText(s.phase === 'gameOver' || s.phase === 'victory' ? '' : '다음 전투: 웨이브 ' + s.wave + (boss ? ' (심판 보스)' : ''));
  }

  play(result: BattleResult, boss: boolean): Promise<void> {
    this.drawUnits(result.allies, result.enemies);
    this.caption.setText(boss ? '심판 보스 전투!' : '전투 중');
    this.skipping = false;
    this.skipBtn.root.setVisible(true);
    const byTick = new Map<number, BattleEvent[]>();
    for (const e of result.events) {
      const list = byTick.get(e.tick) ?? [];
      list.push(e);
      byTick.set(e.tick, list);
    }
    return new Promise((resolve) => {
      let clock = 0;
      let done = 0;
      let paused = 0;
      const timer = this.scene.time.addEvent({
        delay: 16,
        loop: true,
        callback: () => {
          if (paused > 0) {
            paused -= 16;
            return;
          }
          clock += (16 / MS_PER_TICK) * settings.speed;
          const until = this.skipping ? result.ticks : Math.min(Math.floor(clock), result.ticks);
          while (done < until) {
            done++;
            for (const e of byTick.get(done) ?? []) if (this.apply(e, !this.skipping)) paused = 60;
          }
          if (done >= result.ticks) {
            timer.remove();
            this.skipBtn.root.setVisible(false);
            resolve();
          }
        },
      });
    });
  }

  /** 이벤트 하나를 화면에 반영. 처치면 true(잠깐 멈춤) */
  private apply(e: BattleEvent, animate: boolean): boolean {
    if (e.kind === 'death') {
      const v = (e.side === 'ally' ? this.views.ally : this.views.enemy)[e.idx];
      if (v) v.root.setAlpha(0.25);
      if (animate) void hitstop(this.scene, 60);
      return animate;
    }
    if (e.kind === 'enrage') {
      if (animate) {
        this.scene.cameras.main.flash(250, 200, 30, 30);
        this.caption.setText('광폭화! 적 공격력 상승');
      }
      return false;
    }
    if (e.kind === 'hazard') {
      const v = this.views.ally[e.idx];
      if (!v) return false;
      v.hp = Math.max(0, v.hp - e.dmg);
      v.bar.width = Math.max(0, ((UW - 12) * v.hp) / v.max);
      if (animate) {
        v.box.setFillStyle(0x7048e8);
        this.scene.time.delayedCall(120, () => v.box.active && v.box.setFillStyle(0x1e2230));
        if (settings.speed < 4) damageNumber(this.scene, v.x + UW / 2, v.y, e.dmg, false);
        this.caption.setText(HAZARD_KO[e.name]);
      }
      return false;
    }
    const atk = (e.side === 'ally' ? this.views.ally : this.views.enemy)[e.src];
    const def = (e.side === 'ally' ? this.views.enemy : this.views.ally)[e.dst];
    if (!def) return false;
    def.hp = Math.max(0, def.hp - e.dmg);
    def.bar.width = Math.max(0, ((UW - 12) * def.hp) / def.max);
    if (atk && e.heal > 0) {
      atk.hp = Math.min(atk.max, atk.hp + e.heal);
      atk.bar.width = ((UW - 12) * atk.hp) / atk.max;
    }
    if (!animate) return false;
    if (atk) {
      const dx = e.side === 'ally' ? 18 : -18;
      this.scene.tweens.add({ targets: atk.root, x: atk.x + dx, duration: 70 / settings.speed, yoyo: true });
    }
    hitFlash(def.box);
    if (settings.speed < 4) damageNumber(this.scene, def.x + UW / 2, def.y, e.dmg, e.mult > 100);
    if (e.mult > 100 && def.max > 400) shake(this.scene, 0.004, 120);
    return false;
  }
}

const HAZARD_KO: Record<'burn' | 'rowBlast' | 'pulse', string> = {
  burn: '화염 낙인! 가장 약한 드래곤이 탄다',
  rowBlast: '용암탄! 한 줄 전체 피해',
  pulse: '월식의 파동! 아군 전체 피해',
};
