import { readFileSync } from 'node:fs';
import { ELEMENTS, type RawGameData, type Recipe } from '../../packages/core/src/contracts/types.ts';

type LintDataInput = RawGameData & {
  codex?: { id: string; hintKo: string; loreKo: string }[];
};

export function lintData(raw: LintDataInput): string[] {
  const issues: string[] = [];
  const dragons = new Map<string, RawGameData['dragons'][number]>();
  const traits = new Set<string>();
  const reachable = new Set<string>();
  const elements = new Set<string>(ELEMENTS);
  const symbols = new Set<string>([...ELEMENTS, 'gold', 'wild']);

  for (const trait of raw.traits) {
    if (traits.has(trait.id)) issues.push(`duplicate trait id: ${trait.id}`);
    traits.add(trait.id);
  }

  for (const dragon of raw.dragons) {
    if (dragons.has(dragon.id)) issues.push(`duplicate dragon id: ${dragon.id}`);
    dragons.set(dragon.id, dragon);
    if (dragon.tier === 'base') reachable.add(dragon.id);
    if (!traits.has(dragon.traitId)) {
      issues.push(`dragon ${dragon.id}: unknown traitId ${dragon.traitId}`);
    }
    for (const element of dragon.elements) {
      if (!elements.has(element)) issues.push(`dragon ${dragon.id}: unknown element ${element}`);
    }
    for (const [stat, value] of Object.entries(dragon.stats)) {
      if (value <= 0) issues.push(`dragon ${dragon.id}: ${stat} must be positive`);
    }
  }

  const pairs = new Set<string>();
  const knownRecipes: Recipe[] = [];
  for (const recipe of raw.recipes) {
    const { a, b, result } = recipe;
    const label = `recipe ${a}+${b} -> ${result}`;
    const pair = JSON.stringify([a, b].sort());
    if (pairs.has(pair)) issues.push(`${label}: duplicate pair`);
    pairs.add(pair);

    for (const id of new Set([a, b, result])) {
      if (!dragons.has(id)) issues.push(`${label}: unknown dragon id ${id}`);
    }

    const first = dragons.get(a);
    const second = dragons.get(b);
    const target = dragons.get(result);
    if (!first || !second || !target) continue;
    knownRecipes.push(recipe);

    if (target.tier === 'base' || target.tier === 't2' || target.tier === 't1') {
      const element = target.elements[0];
      const matches = [first, second, target].every(
        (dragon) => dragon.elements.length === 1 && dragon.elements[0] === element,
      );
      if (!matches) issues.push(`${label}: element mismatch for ${target.tier} result`);
    }
    if (target.tier === 'dual') {
      const [firstElement] = first.elements;
      const [secondElement] = second.elements;
      const matches = first.tier === 't2' && second.tier === 't2'
        && first.elements.length === 1 && second.elements.length === 1
        && firstElement && secondElement && firstElement !== secondElement
        && target.elements.length === 2
        && target.elements.includes(firstElement) && target.elements.includes(secondElement);
      if (!matches) issues.push(`${label}: expected two tier 2 dragons matching the dual result's elements`);
    }
  }

  let previousSize: number;
  do {
    previousSize = reachable.size;
    for (const { a, b, result } of knownRecipes) {
      if (reachable.has(a) && reachable.has(b)) reachable.add(result);
    }
  } while (reachable.size !== previousSize);

  for (const id of dragons.keys()) {
    if (!reachable.has(id)) issues.push(`unreachable species: ${id}`);
  }

  if (raw.codex !== undefined) {
    const codexIds = new Set<string>();
    for (const { id, hintKo, loreKo } of raw.codex) {
      if (!dragons.has(id)) issues.push(`codex: unknown dragon id ${id}`);
      if (codexIds.has(id)) issues.push(`codex: duplicate dragon id ${id}`);
      codexIds.add(id);
      if (typeof hintKo !== 'string' || !hintKo.trim()) {
        issues.push(`codex ${id}: hintKo must not be empty`);
      }
      if (typeof loreKo !== 'string' || !loreKo.trim()) {
        issues.push(`codex ${id}: loreKo must not be empty`);
      }
    }
    for (const id of dragons.keys()) {
      if (!codexIds.has(id)) issues.push(`codex: missing dragon id ${id}`);
    }
  }

  for (const [symbol, weight] of Object.entries(raw.slot.weights)) {
    if (!symbols.has(symbol)) issues.push(`slot weight: unknown symbol ${symbol}`);
    if (weight <= 0) issues.push(`slot weight ${symbol} must be positive`);
  }
  if (raw.slot.rerollCosts.length === 0) issues.push('slot rerollCosts must not be empty');

  return issues;
}

function readData<K extends keyof LintDataInput>(key: K): LintDataInput[K] {
  const path = new URL(`../../data/${key}.json`, import.meta.url);
  return JSON.parse(readFileSync(path, 'utf8'));
}

function readOptionalCodex(): LintDataInput['codex'] {
  try {
    return readData('codex');
  } catch (error) {
    if (error instanceof Error && 'code' in error && error.code === 'ENOENT') return undefined;
    throw error;
  }
}

if (import.meta.main) {
  const raw: LintDataInput = {
    dragons: readData('dragons'),
    traits: readData('traits'),
    recipes: readData('recipes'),
    slot: readData('slot'),
    waves: readData('waves'),
    battle: readData('battle'),
    codex: readOptionalCodex(),
  };
  const issues = lintData(raw);
  if (issues.length > 0) {
    for (const issue of issues) console.error(issue);
    process.exitCode = 1;
  } else {
    console.log(`data ok: ${raw.dragons.length} dragons, ${raw.recipes.length} recipes`);
  }
}
