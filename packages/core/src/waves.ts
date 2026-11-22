import type { Unit } from './contracts/events.ts';
import type { DragonSpec, Element, GameData, WaveConfig } from './contracts/types.ts';
import { createRng, type Rng } from './rng.ts';

const ELEMENTS: readonly Element[] = ['fire', 'ice', 'lightning'];

export function isBoss(cfg: WaveConfig, wave: number): boolean {
  return wave <= cfg.maxWave && cfg.bossPct[String(wave)] !== undefined;
}

/** 정수 반복 곱으로 계산(플랫폼마다 같은 값) */
export function enemyPower(cfg: WaveConfig, wave: number): number {
  let p = cfg.basePower;
  for (let w = 2; w <= wave; w++) p = Math.floor((p * cfg.growthPct) / 100);
  if (isBoss(cfg, wave)) p = Math.floor((p * (cfg.bossPct[String(wave)] as number)) / 100);
  return p;
}

export function bossElement(seed: number, wave: number): Element {
  const rng = createRng((seed ^ Math.imul(wave, 7919)) >>> 0);
  return ELEMENTS[rng.nextInt(ELEMENTS.length)] as Element;
}

export function unitPower(u: Unit): number {
  return Math.floor(u.hp / 4) + Math.floor((u.atk * 20) / u.cooldownTicks);
}

function specUnit(spec: DragonSpec): Unit {
  return { speciesId: spec.id, elements: spec.elements.slice(), hp: spec.stats.hp, atk: spec.stats.atk, cooldownTicks: spec.stats.cooldownTicks, lifestealPct: 0 };
}

function sortedSpecs(data: GameData, pred: (d: DragonSpec) => boolean): DragonSpec[] {
  return Object.values(data.dragons).filter(pred).sort((a, b) => (a.id < b.id ? -1 : 1));
}

export function generateEnemies(data: GameData, wave: number, rng: Rng, seed: number): Unit[] {
  const count = Math.min(1 + Math.floor(wave / 2), 6);
  const pool = sortedSpecs(data, (d) => d.tier === 'base' || (wave > 5 && d.tier === 't2'));
  const units: Unit[] = [];
  if (isBoss(data.waves, wave)) {
    const el = bossElement(seed, wave);
    const boss = sortedSpecs(data, (d) => d.tier === 't1' && d.elements[0] === el)[0];
    if (boss) units.push(specUnit(boss));
  }
  while (units.length < count) units.push(specUnit(pool[rng.nextInt(pool.length)] as DragonSpec));
  const target = enemyPower(data.waves, wave);
  const sum = units.reduce((s, u) => s + unitPower(u), 0);
  const k = Math.max(50, Math.floor((target * 100) / sum));
  return units.map((u) => ({ ...u, hp: Math.floor((u.hp * k) / 100), atk: Math.max(1, Math.floor((u.atk * k) / 100)) }));
}
