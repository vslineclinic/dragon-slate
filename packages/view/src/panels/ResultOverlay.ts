import Phaser from 'phaser';
import { toUnit, unitPower } from '../../../core/src/index.ts';
import type { RunState } from '../../../core/src/index.ts';
import type { GameController } from '../controller.ts';
import { dragonImage } from '../fx/sprites.ts';
import { UI } from '../layout.ts';
import { button, text } from '../ui.ts';
import { IS_DEMO } from '../build.ts';

/** 판 결과: 도달 웨이브, 이번 판 발견, 가장 강한 드래곤, 새 판·처음으로 */
export function showResult(scene: Phaser.Scene, ctl: GameController, s: RunState, onNew: () => void, onTitle: () => void): Phaser.GameObjects.Container {
  const d = ctl.data;
  const root = scene.add.container(0, 0).setDepth(95);
  root.add(scene.add.rectangle(0, 0, 1280, 720, 0x000000, 0.7).setOrigin(0).setInteractive());
  root.add(scene.add.rectangle(290, 110, 700, 500, 0x1b1f2a).setOrigin(0).setStrokeStyle(2, UI.panelLine));
  const won = s.phase === 'victory';
  root.add(text(scene, 640, 160, won ? '클리어!' : '게임 오버', 44, won ? '#fff3bf' : '#ffa8a8').setOrigin(0.5));
  const sub = won && IS_DEMO ? '데모 클리어! 정식판에서는 20웨이브, 심판 보스 4종, 재앙 5단계가 기다려요.' : won ? d.waves.maxWave + '웨이브를 모두 버텼어요' : s.wave + '웨이브까지 버텼어요';
  root.add(text(scene, 640, 215, sub, 18, UI.text).setOrigin(0.5).setWordWrapWidth(640).setAlign('center'));
  const owned = [...s.nest, ...s.bench].filter((x): x is NonNullable<typeof x> => x !== null);
  const best = owned.sort((a, b) => unitPower(toUnit(d, b)) - unitPower(toUnit(d, a)))[0];
  if (best) {
    const img = dragonImage(scene, best.speciesId, 470, 360, 170, true);
    if (img) root.add(img);
    root.add(text(scene, 470, 455, '가장 강한 드래곤\n' + (d.dragons[best.speciesId]?.nameKo ?? best.speciesId), 17, UI.text).setOrigin(0.5, 0).setAlign('center'));
  }
  const found = s.discovered.map((id) => d.dragons[id]?.nameKo ?? id);
  root.add(text(scene, 600, 280, '이번 판에서 만든 드래곤 ' + found.length + '종', 18, '#ffd8a8'));
  root.add(text(scene, 600, 312, found.length ? found.join(', ') : '없음', 16, UI.dim).setWordWrapWidth(360).setLineSpacing(4));
  root.add(button(scene, 380, 530, 240, 58, '새 판 시작', onNew, 0x2f9e44).root);
  root.add(button(scene, 660, 530, 240, 58, '처음으로', onTitle, 0x2b3045).root);
  return root;
}
