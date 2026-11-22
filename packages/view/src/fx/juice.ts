import Phaser from 'phaser';
import { UI } from '../layout.ts';

/** 흰색 번쩍임 */
export function hitFlash(target: Phaser.GameObjects.Rectangle, ms = 80, base = 0x1e2230): void {
  // 겹친 번쩍임이 서로의 색을 '원래 색'으로 저장하지 않도록 고정 바탕색으로 되돌린다
  target.setFillStyle(0xffffff);
  target.scene.time.delayedCall(ms, () => target.active && target.setFillStyle(base));
}

/** 위로 튀어 오르며 사라지는 숫자. strong이면 크게 */
export function damageNumber(scene: Phaser.Scene, x: number, y: number, dmg: number, strong: boolean): void {
  const t = scene.add
    .text(x + Phaser.Math.Between(-14, 14), y + 10, String(dmg), {
      fontFamily: UI.font,
      fontSize: (strong ? 28 : 20) + 'px',
      color: strong ? '#ffd43b' : '#ffffff',
      stroke: '#000000',
      strokeThickness: 4,
    })
    .setOrigin(0.5)
    .setDepth(45);
  scene.tweens.add({ targets: t, y: y - 26, alpha: 0, duration: 650, ease: 'Cubic.out', onComplete: () => t.destroy() });
}

/** 처치 순간 잠깐 멈춤 */
export function hitstop(scene: Phaser.Scene, ms: number): Promise<void> {
  scene.tweens.timeScale = 0.05;
  return new Promise((resolve) =>
    window.setTimeout(() => {
      scene.tweens.timeScale = 1;
      resolve();
    }, ms),
  );
}

export function shake(scene: Phaser.Scene, intensity: number, ms: number): void {
  scene.cameras.main.shake(ms, intensity);
}

/** 강조 펄스: 줄 맞춤 칸, 새로 발견 */
export function pulse(target: Phaser.GameObjects.Components.Transform & Phaser.GameObjects.GameObject): void {
  target.scene.tweens.add({ targets: target, scaleX: 1.08, scaleY: 1.08, duration: 120, yoyo: true, repeat: 1 });
}
