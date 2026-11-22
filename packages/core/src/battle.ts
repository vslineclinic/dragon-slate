import type { BattleEvent, BattleResult, Unit } from './contracts/events.ts';
import type { BattleConfig, BossRules, DragonInst, Element, GameData } from './contracts/types.ts';

export function elementMult(cfg: BattleConfig, atk: Element, def: Element): number {
  if (cfg.beats[atk]?.includes(def)) return cfg.strongPct;
  if (cfg.beats[def]?.includes(atk)) return cfg.weakPct;
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

function hazardDamage(f: Fighter, pct: number): number {
  return Math.max(1, Math.floor((f.unit.hp * pct) / 100));
}

export function simulateBattle(cfg: BattleConfig, allies: (Unit | null)[], enemies: (Unit | null)[], rules: BossRules = {}): BattleResult {
  const sides = { ally: prepare(allies), enemy: prepare(enemies) };
  if (rules.allySlowPct) {
    for (const f of sides.ally) if (f) f.unit = { ...f.unit, cooldownTicks: Math.floor((f.unit.cooldownTicks * (100 + rules.allySlowPct)) / 100) };
  }
  const events: BattleEvent[] = [];
  let tick = 0;
  let winner: 'ally' | 'enemy' | null = null;
  let blastFront = true;
  let enraged = false;
  const hurtAlly = (idx: number, dmg: number, name: 'burn' | 'rowBlast' | 'pulse') => {
    const f = sides.ally[idx];
    if (!f || f.hp <= 0) return;
    f.hp -= dmg;
    events.push({ tick, kind: 'hazard', name, idx, dmg });
    if (f.hp <= 0) events.push({ tick, kind: 'death', side: 'ally', idx });
  };
  while (winner === null && tick < cfg.maxTicks) {
    tick++;
    // 1) 보스 기믹
    if (rules.burn && tick % rules.burn.everyTicks === 0) {
      let low = -1;
      sides.ally.forEach((f, i) => {
        if (f && f.hp > 0 && (low < 0 || f.hp < (sides.ally[low] as Fighter).hp)) low = i;
      });
      if (low >= 0) hurtAlly(low, hazardDamage(sides.ally[low] as Fighter, rules.burn.pct), 'burn');
    }
    if (rules.rowBlast && tick % rules.rowBlast.everyTicks === 0) {
      const row = blastFront ? [0, 1, 2] : [3, 4, 5];
      blastFront = !blastFront;
      for (const i of row) {
        const f = sides.ally[i];
        if (f && f.hp > 0) hurtAlly(i, hazardDamage(f, rules.rowBlast.pct), 'rowBlast');
      }
    }
    if (rules.pulse && tick % rules.pulse.everyTicks === 0) {
      sides.ally.forEach((f, i) => {
        if (f && f.hp > 0) hurtAlly(i, hazardDamage(f, rules.pulse!.pct), 'pulse');
      });
    }
    if (rules.enrage && !enraged && tick >= rules.enrage.atTick) {
      enraged = true;
      events.push({ tick, kind: 'enrage' });
    }
    if (firstAlive(sides.ally) < 0) {
      winner = 'enemy';
      break;
    }
    // 2) 아군, 3) 적 공격
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
        let dmg = Math.max(1, Math.floor((f.unit.atk * mult) / 100));
        if (side === 'enemy' && enraged && rules.enrage) dmg = Math.floor((dmg * rules.enrage.atkPct) / 100);
        target.hp -= dmg;
        let raw = Math.floor((dmg * f.unit.lifestealPct) / 100);
        if (side === 'ally' && rules.healCutPct && tick >= (rules.healCutFromTick ?? 0)) raw = Math.floor((raw * (100 - rules.healCutPct)) / 100);
        const heal = Math.max(0, Math.min(raw, f.unit.hp - f.hp));
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
