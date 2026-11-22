import Phaser from 'phaser';
import { UI } from './layout.ts';

export interface Button {
  root: Phaser.GameObjects.Container;
  setLabel(text: string): void;
  setEnabled(on: boolean): void;
}

export function text(scene: Phaser.Scene, x: number, y: number, s: string, size = 18, color: string = UI.text): Phaser.GameObjects.Text {
  return scene.add.text(x, y, s, { fontFamily: UI.font, fontSize: size + 'px', color });
}

export function button(scene: Phaser.Scene, x: number, y: number, w: number, h: number, label: string, onClick: () => void, fill = 0x3b5bdb): Button {
  const bg = scene.add.rectangle(0, 0, w, Math.max(h, UI.minTouch), fill).setOrigin(0).setStrokeStyle(2, 0xffffff, 0.15);
  const t = text(scene, w / 2, Math.max(h, UI.minTouch) / 2, label, 18).setOrigin(0.5);
  const root = scene.add.container(x, y, [bg, t]);
  let enabled = true;
  bg.setInteractive({ useHandCursor: true });
  bg.on('pointerdown', () => {
    if (enabled) onClick();
  });
  return {
    root,
    setLabel: (s) => t.setText(s),
    setEnabled(on) {
      enabled = on;
      bg.setAlpha(on ? 1 : 0.35);
      t.setAlpha(on ? 1 : 0.5);
    },
  };
}
