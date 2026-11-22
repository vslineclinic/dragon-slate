import Phaser from 'phaser';
import type { GameEvent, RunState } from '../../../core/src/index.ts';
import type { GameController } from '../controller.ts';
import { Hud } from '../panels/Hud.ts';
import { SlotPanel } from '../panels/SlotPanel.ts';
import { text } from '../ui.ts';

export class GameScene extends Phaser.Scene {
  private ctl!: GameController;
  private hud!: Hud;
  private slot!: SlotPanel;
  private toast!: Phaser.GameObjects.Text;

  constructor() {
    super('game');
  }

  init(data: { ctl: GameController }): void {
    this.ctl = data.ctl;
  }

  create(): void {
    this.hud = new Hud(this, this.ctl.data);
    this.slot = new SlotPanel(this, this.ctl);
    this.toast = text(this, 640, 300, '', 22, '#ffd8a8').setOrigin(0.5).setDepth(50);
    this.ctl.on((events, state) => this.onChange(events, state));
    this.hud.setBossPreview(1, null);
    this.ctl.restart(this.ctl.state.seed);
  }

  private onChange(events: GameEvent[], state: RunState): void {
    for (const e of events) {
      if (e.t === 'waveStart') this.hud.setBossPreview(e.wave, e.bossPreview);
      if (e.t === 'rejected') this.flash(REJECT_KO[e.reason] ?? '할 수 없어요');
    }
    this.hud.render(state);
    this.slot.render(state, events);
  }

  flash(msg: string): void {
    this.toast.setText(msg).setAlpha(1);
    this.tweens.killTweensOf(this.toast);
    this.tweens.add({ targets: this.toast, alpha: 0, delay: 900, duration: 400 });
  }
}

const REJECT_KO: Record<string, string> = {
  wrongPhase: '지금은 할 수 없어요',
  notEnoughMana: '마력이 모자라요',
  noNudgeLeft: '이번 웨이브 밀기를 다 썼어요',
  benchFull: '대기칸이 꽉 찼어요',
  emptySlot: '빈칸이에요',
  slotLocked: '아직 잠긴 칸이에요',
  nestEmpty: '둥지에 드래곤을 1마리 이상 놓아요',
  sameSlot: '같은 칸이에요',
};
