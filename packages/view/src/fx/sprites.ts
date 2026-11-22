import Phaser from 'phaser';
import type { GameData } from '../../../core/src/index.ts';

const key = (id: string) => 'dragon_' + id;

/** assets/dragons/<id>.png 를 불러온다. 없는 그림은 조용히 건너뛴다(문양으로 대신 그림). */
export function preloadDragons(scene: Phaser.Scene, data: GameData): void {
  scene.load.on('loaderror', () => undefined);
  for (const id of Object.keys(data.dragons)) scene.load.image(key(id), 'dragons/' + id + '.png');
}

/** 그림이 있으면 (cx, cy) 중심에 size 크기로 놓은 이미지를, 없으면 null */
export function dragonImage(scene: Phaser.Scene, id: string, cx: number, cy: number, size: number, flip = false): Phaser.GameObjects.Image | null {
  if (!scene.textures.exists(key(id))) return null;
  const img = scene.add.image(cx, cy, key(id));
  img.setScale(size / Math.max(img.width, img.height));
  if (flip) img.setFlipX(true);
  return img;
}
