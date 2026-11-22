import Phaser from 'phaser';
import type { RunState } from '../../../core/src/index.ts';
import { UI } from '../layout.ts';
import { text } from '../ui.ts';

const KEY = 'wyrmslot.tutorial.done';

interface Step {
  when: (s: RunState) => boolean;
  msg: string;
  /** 말풍선 위치(왼쪽 위)와 화살표 끝 */
  at: { x: number; y: number };
  point: { x: number; y: number };
}

const STEPS: Step[] = [
  { when: (s) => s.phase === 'spin' && s.wave === 1, msg: '① 이 버튼을 눌러 룬 석판을 돌려요.', at: { x: 800, y: 556 }, point: { x: 1060, y: 652 } },
  { when: (s) => s.phase === 'pick', msg: '② 보라 띠의 알 3개가 오른쪽 카드로 나와요.\n하나를 고르세요. 노란 테두리가 추천이에요.', at: { x: 560, y: 248 }, point: { x: 930, y: 420 } },
  { when: (s) => s.phase === 'manage' && s.nest.every((n) => !n), msg: '③ 대기칸의 드래곤을 아래 둥지 칸으로 끌어 놓아요.\n같은 드래곤끼리 겹치면 합체해요!', at: { x: 30, y: 248 }, point: { x: 80, y: 600 } },
  { when: (s) => s.phase === 'manage' && s.nest.some((n) => n), msg: '④ 준비되면 전투 시작! 전투는 자동이에요.', at: { x: 300, y: 248 }, point: { x: 525, y: 500 } },
  { when: (s) => s.wave === 2 && s.phase === 'spin', msg: '⑤ 위쪽에 다음 보스 예보가 있어요. 눌러서 대응법을 보세요.\n이제 혼자 해 볼까요? 행운을 빌어요!', at: { x: 420, y: 60 }, point: { x: 600, y: 22 } },
];

/** 첫 판에만 나오는 단계별 말풍선. 해당 행동을 하면 다음 단계로, [건너뛰기]로 끝. */
export class Tutorial {
  private scene: Phaser.Scene;
  private step = 0;
  private done: boolean;
  private root: Phaser.GameObjects.Container | null = null;

  constructor(scene: Phaser.Scene) {
    this.scene = scene;
    let saved = false;
    try {
      saved = localStorage.getItem(KEY) === '1';
    } catch {
      /* 저장소 없으면 매번 안내 */
    }
    this.done = saved;
  }

  private ending = false;

  update(s: RunState): void {
    if (this.done) return;
    // 지금 상황에 맞는 단계 중 가장 앞선 것(지나간 단계로는 돌아가지 않음)
    let match = -1;
    for (let i = this.step; i < STEPS.length; i++) if (STEPS[i]!.when(s)) match = i;
    if (match < 0) return this.hide();
    this.step = match;
    this.show(STEPS[match]!);
    if (match === STEPS.length - 1 && !this.ending) {
      this.ending = true;
      this.scene.time.delayedCall(7000, () => this.finish());
    }
  }

  private show(step: Step): void {
    this.hide();
    const s = this.scene;
    const lines = step.msg.split('\n').length;
    const w = 440;
    const h = 30 + lines * 24 + 28;
    const g = s.add.graphics();
    g.fillStyle(0xfff3bf, 1).fillRoundedRect(0, 0, w, h, 12);
    g.lineStyle(3, 0x5f3dc4, 1).strokeRoundedRect(0, 0, w, h, 12);
    const tip = { x: step.point.x - step.at.x, y: step.point.y - step.at.y };
    g.lineStyle(4, 0xfff3bf, 1).lineBetween(w / 2, tip.y < 0 ? 0 : h, tip.x, tip.y);
    g.fillStyle(0xfff3bf, 1).fillCircle(tip.x, tip.y, 7);
    const t = text(s, 16, 14, step.msg, 17, '#1b1f2a').setLineSpacing(4);
    const skip = text(s, w - 14, h - 24, '안내 건너뛰기 ✕', 13, '#5f3dc4').setOrigin(1, 0).setInteractive({ useHandCursor: true });
    skip.on('pointerdown', () => this.finish());
    this.root = s.add.container(step.at.x, step.at.y, [g, t, skip]).setDepth(85);
    s.tweens.add({ targets: this.root, y: step.at.y - 4, duration: 600, yoyo: true, repeat: -1, ease: 'Sine.inOut' });
  }

  private hide(): void {
    this.root?.destroy(true);
    this.root = null;
  }

  finish(): void {
    this.done = true;
    this.hide();
    try {
      localStorage.setItem(KEY, '1');
    } catch {
      /* 무시 */
    }
  }
}
