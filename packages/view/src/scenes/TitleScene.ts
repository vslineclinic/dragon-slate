import Phaser from 'phaser';
import type { GameController } from '../controller.ts';
import { DexOverlay, type CodexEntry } from '../panels/DexOverlay.ts';
import { dragonImage, preloadDragons } from '../fx/sprites.ts';
import { UI } from '../layout.ts';
import { button, text } from '../ui.ts';

/** 시작 화면: 제목, 세 줄 안내, 시작·도감 */
export class TitleScene extends Phaser.Scene {
  private ctl!: GameController;
  private codex: CodexEntry[] = [];

  constructor() {
    super('title');
  }

  init(data: { ctl: GameController; codex: CodexEntry[] }): void {
    this.ctl = data.ctl;
    this.codex = data.codex;
  }

  preload(): void {
    preloadDragons(this, this.ctl.data);
  }

  create(): void {
    this.add.rectangle(0, 0, 1280, 720, 0x141824).setOrigin(0);
    const show: [string, number, number, number][] = [
      ['zhulong', 250, 300, 230],
      ['kuraokami', 1030, 300, 230],
      ['yinglong', 640, 210, 170],
    ];
    for (const [id, x, y, size] of show) dragonImage(this, id, x, y, size, x < 640)?.setAlpha(0.9);
    text(this, 640, 330, 'Wyrmslot', 76, '#fff3bf').setOrigin(0.5).setStroke('#5f3dc4', 10);
    text(this, 640, 395, '룬 석판 드래곤 로그라이트', 22, UI.dim).setOrigin(0.5);
    text(
      this,
      640,
      470,
      '① 룬 석판을 돌려 알을 받고   ② 드래곤 둘을 합쳐 신화룡을 찾고   ③ 자동 전투로 20웨이브를 버텨요',
      18,
      UI.text,
    ).setOrigin(0.5);
    button(this, 520, 530, 240, 64, '시작하기', () => this.start(), 0x5f3dc4);
    const dex = new DexOverlay(this, this.ctl, this.codex);
    button(this, 540, 610, 200, 52, '드래곤 도감', () => dex.open(), 0x2b3045);
  }

  private start(): void {
    this.ctl.restart(Date.now() % 1_000_000_007);
    this.scene.start('game', { ctl: this.ctl, codex: this.codex });
  }
}
