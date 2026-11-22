import Phaser from 'phaser';
import type { BossSpec, Element, GameData, RunState } from '../../../core/src/index.ts';
import { AREA, ELEMENT_KO, UI } from '../layout.ts';
import { settings, type Speed } from '../settings.ts';
import { button, text, type Button } from '../ui.ts';

export class Hud {
  private wave: Phaser.GameObjects.Text;
  private lives: Phaser.GameObjects.Text;
  private mana: Phaser.GameObjects.Text;
  private boss: Phaser.GameObjects.Text;
  private speedBtns: { s: Speed; b: Button }[] = [];
  private data: GameData;
  private preview: { wave: number; el: Element; spec: BossSpec | null } | null = null;
  onBossInfo: (msg: string) => void = () => undefined;

  constructor(scene: Phaser.Scene, data: GameData) {
    this.data = data;
    const a = AREA.hud;
    scene.add.rectangle(a.x, a.y, a.w, a.h, 0x151925).setOrigin(0);
    this.wave = text(scene, 16, 10, '', 20);
    this.lives = text(scene, 180, 10, '', 20, '#ff8787');
    this.mana = text(scene, 340, 10, '', 20, '#b197fc');
    this.boss = text(scene, 470, 12, '', 16, '#ffc078');
    this.boss.setInteractive({ useHandCursor: true }).on('pointerdown', () => {
      const p = this.preview?.spec;
      if (p) this.onBossInfo(p.nameKo + '\n' + p.descKo + '\n대응: ' + p.hintKo);
    });
    ([1, 2, 4] as Speed[]).forEach((s, i) => {
      const b = button(scene, 1040 + i * 78, 0, 70, 44, s + 'x', () => {
        settings.setSpeed(s);
        this.refreshSpeed();
      }, 0x2b3045);
      this.speedBtns.push({ s, b });
    });
    this.refreshSpeed();
  }

  setBossPreview(wave: number, el: Element | null, spec: BossSpec | null = null): void {
    if (el) this.preview = { wave: wave + 4, el, spec };
    else if (this.preview && wave > this.preview.wave) this.preview = null;
  }

  render(s: RunState): void {
    this.wave.setText('웨이브 ' + s.wave + ' / ' + this.data.waves.maxWave);
    this.lives.setText('생명 ' + '♥'.repeat(Math.max(0, s.lives)));
    this.mana.setText('마력 ' + s.mana);
    const p = this.preview;
    this.boss.setText(p ? p.wave + '웨이브 보스: ' + (p.spec ? p.spec.nameKo + ' · ' : '') + ELEMENT_KO[p.el] + ' 원소' + (p.spec ? '  (눌러서 보기)' : '') : '');
  }

  private refreshSpeed(): void {
    for (const { s, b } of this.speedBtns) b.root.setAlpha(settings.speed === s ? 1 : 0.45);
  }
}
