import Phaser from 'phaser';
import type { GameEvent, RunState } from '../../../core/src/index.ts';
import type { GameController } from '../controller.ts';
import { Hud } from '../panels/Hud.ts';
import { SlotPanel } from '../panels/SlotPanel.ts';
import { NestPanel } from '../panels/NestPanel.ts';
import { BattlePanel } from '../panels/BattlePanel.ts';
import { markDiscovered } from '../codex-store.ts';
import { pulse } from '../fx/juice.ts';
import { button, text } from '../ui.ts';
import { UI } from '../layout.ts';
import { preloadDragons } from '../fx/sprites.ts';
import { DexOverlay, type CodexEntry } from '../panels/DexOverlay.ts';
import { showResult } from '../panels/ResultOverlay.ts';

export class GameScene extends Phaser.Scene {
  private ctl!: GameController;
  private hud!: Hud;
  private slot!: SlotPanel;
  private nest!: NestPanel;
  private battle!: BattlePanel;
  private banner!: Phaser.GameObjects.Text;
  private toast!: Phaser.GameObjects.Text;


  constructor() {
    super('game');
  }

  private dex!: DexOverlay;
  private codex: CodexEntry[] = [];

  init(data: { ctl: GameController; codex?: CodexEntry[] }): void {
    this.ctl = data.ctl;
    this.codex = data.codex ?? [];
  }

  preload(): void {
    preloadDragons(this, this.ctl.data);
  }

  create(): void {
    this.battle = new BattlePanel(this, this.ctl.data);
    this.hud = new Hud(this, this.ctl.data);
    this.hud.onBossInfo = (msg) => this.flash(msg);
    this.dex = new DexOverlay(this, this.ctl, this.codex);
    button(this, 952, 0, 80, 44, '도감', () => (this.dex.isOpen() ? this.dex.close() : !this.ctl.busy && this.dex.open()), 0x2b3045);
    this.slot = new SlotPanel(this, this.ctl);
    this.nest = new NestPanel(this, this.ctl);
    this.banner = text(this, 640, 170, '', 40, '#fff3bf').setOrigin(0.5).setAlign('center').setDepth(60).setStroke('#5f3dc4', 8).setAlpha(0);
    this.toast = text(this, 640, 250, '', 22, '#ffd8a8').setOrigin(0.5).setAlign('center').setDepth(50).setBackgroundColor('#000000aa').setPadding(10, 6, 10, 6).setAlpha(0);
    const off = this.ctl.on((events, state) => void this.onChange(events, state));
    this.events.once('shutdown', off);
    this.ctl.restart(this.ctl.state.seed);
  }

  private async onChange(events: GameEvent[], state: RunState): Promise<void> {
    for (const e of events) {
      if (e.t === 'rejected') this.flash(REJECT_KO[e.reason] ?? '할 수 없어요');
      if (e.t === 'evolved' && markDiscovered(e.inst.speciesId)) this.discover(this.ctl.data.dragons[e.inst.speciesId]?.nameKo ?? e.inst.speciesId);
    }
    const bonus = events.filter((e) => e.t === 'gained' && e.via === 'bonus');
    const lineMana = events.reduce((n, e) => n + (e.t === 'mana' && ['line', 'goldLine', 'wildLine', 'goldCells', 'benchFull'].includes(e.reason) ? e.delta : 0), 0);
    if (bonus.length || lineMana) {
      const names = bonus.map((e) => (e.t === 'gained' ? (this.ctl.data.dragons[e.inst.speciesId]?.nameKo ?? '') + ' 알' : ''));
      const converted = events.some((e) => e.t === 'mana' && e.reason === 'benchFull');
      this.flash('보너스! ' + [...names, lineMana ? '마력 +' + lineMana : ''].filter(Boolean).join(' · ') + (converted ? '\n(대기칸이 꽉 차서 보너스 알은 마력으로 바뀌었어요)' : ''));
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
      const reward = events.find((e) => e.t === 'reward');
      if (reward && reward.t === 'reward') await this.showReward(reward.reward.nameKo, this.rewardDetail(reward.reward.kind, reward.reward.amount, reward.detail));
      this.ctl.busy = false;
    }
    for (const e of events) {
      if (e.t !== 'waveStart') continue;
      this.hud.setBossPreview(e.wave, e.bossPreview, e.boss);
      if (e.boss) this.flash('예보: ' + (e.wave + 4) + '웨이브에 「' + e.boss.nameKo + '」\n' + e.boss.hintKo);
    }
    this.render(state, events);
    if (state.phase === 'gameOver' || state.phase === 'victory') this.ending(state);
  }

  private render(state: RunState, events: GameEvent[]): void {
    this.hud.render(state);
    this.slot.render(state, events);
    this.nest.render(state);
    this.battle.showIdle(state);
  }

  private rewardDetail(kind: string, amount: number, detail: string | null): string {
    const d = this.ctl.data;
    if (kind === 'mana') return '마력 +' + amount;
    if (kind === 'egg' || kind === 't2egg') return (d.dragons[detail ?? '']?.nameKo ?? '드래곤') + ' 알을 얻었어요';
    if (kind === 'trait') return detail ? '특성 「' + (d.traits[detail]?.nameKo ?? detail) + '」을 계승했어요' : '마력 +3';
    if (kind === 'nudge') return '다음 웨이브 밀기 +' + amount;
    if (kind === 'freeSpin') return '다시 돌리기 ' + amount + '회 무료';
    return '생명 +' + amount + ' (가득 차 있으면 마력 +3)';
  }

  /** 보상 상자: 흔들리다 열리며 내용이 나온다 */
  private showReward(title: string, detail: string): Promise<void> {
    return new Promise((resolve) => {
      const box = this.add.container(640, 190).setDepth(70);
      const g = this.add.graphics();
      g.fillStyle(0x5f3dc4, 1).fillRoundedRect(-46, -30, 92, 60, 10);
      g.fillStyle(0xffd43b, 1).fillRect(-46, -6, 92, 10).fillRect(-6, -30, 12, 60);
      box.add(g);
      const label = this.add
        .text(640, 250, '', { fontFamily: UI.font, fontSize: '24px', color: '#fff3bf', align: 'center', stroke: '#000000', strokeThickness: 5 })
        .setOrigin(0.5)
        .setDepth(70);
      this.tweens.add({
        targets: box,
        angle: { from: -8, to: 8 },
        duration: 90,
        yoyo: true,
        repeat: 3,
        onComplete: () => {
          this.tweens.add({ targets: box, scale: 1.4, alpha: 0, duration: 220 });
          label.setText('웨이브 보상: ' + title + '\n' + detail).setScale(0.6);
          this.tweens.add({ targets: label, scale: 1, duration: 220, ease: 'Back.out' });
          this.time.delayedCall(1400, () => {
            box.destroy();
            this.tweens.add({ targets: label, alpha: 0, duration: 250, onComplete: () => { label.destroy(); resolve(); } });
          });
        },
      });
    });
  }

  private announce(msg: string): void {
    this.banner.setText(msg).setAlpha(1).setScale(0.7);
    this.tweens.killTweensOf(this.banner);
    this.tweens.add({ targets: this.banner, scale: 1, duration: 220, ease: 'Back.out' });
    this.tweens.add({ targets: this.banner, alpha: 0, delay: 900, duration: 300 });
  }

  private result: Phaser.GameObjects.Container | null = null;

  private ending(state: RunState): void {
    this.result?.destroy(true);
    this.result = showResult(
      this,
      this.ctl,
      state,
      () => {
        this.result?.destroy(true);
        this.result = null;
        this.ctl.restart((this.ctl.state.seed * 7 + 13) % 1_000_000_007);
      },
      () => this.scene.start('title', { ctl: this.ctl, codex: this.codex }),
    );
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
    this.tweens.add({ targets: this.toast, alpha: 0, delay: 1600, duration: 400 });
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
