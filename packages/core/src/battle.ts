import type { BattleEvent, BattleResult, Unit } from './contracts/events.ts';
import type { BattleConfig, DragonInst, Element, GameData } from './contracts/types.ts';

const BEATS: Record<Element, Element> = { fire: 'ice', ice: 'lightning', lightning: 'fire' };

export function elementMult(cfg: BattleConfig, atk: Element, def: Element): number {
  if (BEATS[atk] === def) return cfg.strongPct;
  if (BEATS[def] === atk) return cfg.weakPct;
  return 100;
}

/** 종 고유 특성 + 계승 특성을 모두 적용한다. */
export function toUnit(data: GameData, inst: DragonInst): Unit {
  const spec = data.dragons[inst.speciesId];
  if (!spec) throw new Error('unknown species ' + inst.speciesId);
  let hpPct = 0, atkPct = 0, hastePct = 0, lifestealPct = 0;
  for (const id of [spec.traitId, ...inst.traits]) {
    const t = data.traits[id];
    if (!t) continue;
    if (t.kind === 'hpPct') hpPct += t.value;
    else if (t.kind === 'atkPct') atkPct += t.value;
    else if (t.kind === 'hastePct') hastePct += t.value;
    else lifestealPct += t.value;
  }
  return {
    speciesId: spec.id,
    elements: spec.elements.slice(),
    hp: Math.floor((spec.stats.hp * (100 + inst.bonusPct + hpPct)) / 100),
    atk: Math.floor((spec.stats.atk * (100 + inst.bonusPct + atkPct)) / 100),
    cooldownTicks: Math.max(5, Math.floor((spec.stats.cooldownTicks * (100 - hastePct)) / 100)),
    lifestealPct,
  };
}

interface Fighter { unit: Unit; hp: number; timer: number }

function prepare(units: (Unit | null)[]): (Fighter | null)[] {
  return units.map((u) => (u ? { unit: u, hp: u.hp, timer: 0 } : null));
}

function firstAlive(side: (Fighter | null)[]): number {
  return side.findIndex((f) => f !== null && f.hp > 0);
}

export function simulateBattle(cfg: BattleConfig, allies: (Unit | null)[], enemies: (Unit | null)[]): BattleResult {
  const sides = { ally: prepare(allies), enemy: prepare(enemies) };
  const events: BattleEvent[] = [];
  let tick = 0;
  let winner: 'ally' | 'enemy' | null = null;
  while (winner === null && tick < cfg.maxTicks) {
    tick++;
    for (const side of ['ally', 'enemy'] as const) {
      const mine = sides[side];
      const theirs = sides[side === 'ally' ? 'enemy' : 'ally'];
      for (let i = 0; i < mine.length; i++) {
        const f = mine[i];
        if (!f || f.hp <= 0) continue;
        f.timer++;
        if (f.timer < f.unit.cooldownTicks) continue;
        const dst = firstAlive(theirs);
        if (dst < 0) break;
        f.timer = 0;
        const target = theirs[dst] as Fighter;
        const mult = elementMult(cfg, f.unit.elements[0] as Element, target.unit.elements[0] as Element);
        const dmg = Math.max(1, Math.floor((f.unit.atk * mult) / 100));
        target.hp -= dmg;
        const heal = Math.min(Math.floor((dmg * f.unit.lifestealPct) / 100), f.unit.hp - f.hp);
        f.hp += heal;
        events.push({ tick, kind: 'attack', side, src: i, dst, dmg, mult, heal });
        if (target.hp <= 0) events.push({ tick, kind: 'death', side: side === 'ally' ? 'enemy' : 'ally', idx: dst });
      }
    }
    if (firstAlive(sides.enemy) < 0) winner = 'ally';
    else if (firstAlive(sides.ally) < 0) winner = 'enemy';
  }
  return { winner: winner ?? 'enemy', ticks: tick, allies, enemies, events };
}
