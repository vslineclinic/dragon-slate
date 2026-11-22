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
import { GameController } from './controller.ts';
import { GameScene } from './scenes/GameScene.ts';

const data = loadGameData({ dragons, traits, recipes, slot, waves, battle, rewards, bosses } as RawGameData);
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
game.scene.add('game', GameScene, true, { ctl });
(window as unknown as { wyrm: unknown }).wyrm = { ctl, seed, game };
