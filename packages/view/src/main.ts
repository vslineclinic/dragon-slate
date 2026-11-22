import Phaser from 'phaser';
import { loadGameData, type RawGameData } from '../../core/src/index.ts';
import dragons from '../../../data/dragons.json';
import traits from '../../../data/traits.json';
import recipes from '../../../data/recipes.json';
import slot from '../../../data/slot.json';
import waves from '../../../data/waves.json';
import battle from '../../../data/battle.json';
import rewards from '../../../data/rewards.json';
import bosses from '../../../data/bosses.json';
import codex from '../../../data/codex.json';
import calamity from '../../../data/calamity.json';
import { applyBuild } from './build.ts';
import { GameController } from './controller.ts';
import { GameScene } from './scenes/GameScene.ts';
import { TitleScene } from './scenes/TitleScene.ts';

const data = applyBuild(loadGameData({ dragons, traits, recipes, slot, waves, battle, rewards, bosses, calamity } as RawGameData));
const param = Number(new URLSearchParams(location.search).get('seed'));
const seed = Number.isFinite(param) && param > 0 ? param : Date.now() % 1_000_000_007;
const ctl = new GameController(data, seed);

const game = new Phaser.Game({
  type: Phaser.AUTO,
  parent: 'game',
  width: 1280,
  height: 720,
  backgroundColor: '#1b1f2a',
  scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
});
// ?seed= 가 있으면 시작 화면을 건너뛰고 바로 게임(시험·재현용)
const direct = Number.isFinite(param) && param > 0;
game.scene.add('title', TitleScene, !direct, { ctl, codex });
game.scene.add('game', GameScene, direct, { ctl, codex });
(window as unknown as { wyrm: unknown }).wyrm = { ctl, seed, game };
