import Phaser from 'phaser';
import type { GameEvent, RunState } from '../../../core/src/index.ts';
import type { GameController } from '../controller.ts';
import { Hud } from '../panels/Hud.ts';
import { SlotPanel } from '../panels/SlotPanel.ts';
import { NestPanel } from '../panels/NestPanel.ts';
import { BattlePanel } from '../panels/BattlePanel.ts';
import { markDiscovered } from '../codex-store.ts';
import { pulse } from '../fx/juice.ts';
import { button, text, type Button } from '../ui.ts';

export class GameScene extends Phaser.Scene {
  private ctl!: GameController;
  private hud!: Hud;
  private slot!: SlotPanel;
  private nest!: NestPanel;
  private battle!: BattlePanel;
  private banner!: Phaser.GameObjects.Text;
  private toast!: Phaser.GameObjects.Text;
  private endBtn!: Button;

  constructor() {
    super('game');
  }

  init(data: { ctl: GameController }): void {
    this.ctl = data.ctl;
  }

  create(): void {
    this.battle = new BattlePanel(this, this.ctl.data);
    this.hud = new Hud(this, this.ctl.data);
    this.slot = new SlotPanel(this, this.ctl);
    this.nest = new NestPanel(this, this.ctl);
    this.banner = text(this, 640, 170, '', 40, '#fff3bf').setOrigin(0.5).setAlign('center').setDepth(60).setStroke('#5f3dc4', 8).setAlpha(0);
    this.toast = text(this, 640, 300, '', 22, '#ffd8a8').setOrigin(0.5).setDepth(50);
    this.endBtn = button(this, 540, 230, 200, 56, '새 판 시작', () => this.ctl.restart((this.ctl.state.seed * 7 + 13) % 1_000_000_007), 0x2f9e44);
    this.endBtn.root.setDepth(61).setVisible(false);
    this.ctl.on((events, state) => void this.onChange(events, state));
    this.ctl.restart(this.ctl.state.seed);
  }

  private async onChange(events: GameEvent[], state: RunState): Promise<void> {
    for (const e of events) {
      if (e.t === 'rejected') this.flash(REJECT_KO[e.reason] ?? '할 수 없어요');
      if (e.t === 'evolved' && markDiscovered(e.inst.speciesId)) this.discover(this.ctl.data.dragons[e.inst.speciesId]?.nameKo ?? e.inst.speciesId);
    }
    const fight = events.find((e) => e.t === 'battle');
    if (fight && fight.t === 'battle') {
      this.ctl.busy = true;
      const lead = fight.result.enemies[0];
      const boss = lead ? this.ctl.data.dragons[lead.speciesId]?.tier === 't1' : false;
      await this.battle.play(fight.result, boss);
      const lost = events.find((e) => e.t === 'lives');
      this.announce(fight.result.winner === 'ally' ? '승리!' : '패배' + (lost && lost.t === 'lives' ? '\n생명 ' + lost.lives + ' 남음' : ''));
      await new Promise((r) => this.time.delayedCall(700, r));
      this.ctl.busy = false;
    }
    for (const e of events) if (e.t === 'waveStart') this.hud.setBossPreview(e.wave, e.bossPreview);
    if (events.some((e) => e.t === 'waveStart' && e.wave === 1 && state.log.length === 0)) this.endBtn.root.setVisible(false);
    this.render(state, events);
    if (state.phase === 'gameOver') this.ending('게임 오버\n웨이브 ' + state.wave + '까지');
    if (state.phase === 'victory') this.ending('클리어!\n발견 ' + state.discovered.length + '종');
  }

  private render(state: RunState, events: GameEvent[]): void {
    this.hud.render(state);
    this.slot.render(state, events);
    this.nest.render(state);
    this.battle.showIdle(state);
  }

  private announce(msg: string): void {
    this.banner.setText(msg).setAlpha(1).setScale(0.7);
    this.tweens.killTweensOf(this.banner);
    this.tweens.add({ targets: this.banner, scale: 1, duration: 220, ease: 'Back.out' });
    this.tweens.add({ targets: this.banner, alpha: 0, delay: 900, duration: 300 });
  }

  private ending(msg: string): void {
    this.tweens.killTweensOf(this.banner);
    this.banner.setText(msg).setAlpha(1).setScale(1);
    this.endBtn.root.setVisible(true);
  }

  private discover(name: string): void {
    this.banner.setText('새로 발견!\n' + name).setAlpha(1).setScale(0.6);
    this.tweens.killTweensOf(this.banner);
    this.tweens.add({ targets: this.banner, scale: 1, duration: 250, ease: 'Back.out' });
    this.tweens.add({ targets: this.banner, alpha: 0, delay: 1500, duration: 400 });
    pulse(this.banner);
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
  needDragon: '드래곤이 최소 1마리는 있어야 해요',
};
