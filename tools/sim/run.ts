import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import {
  applyCommand, createRun, isBoss, loadGameData,
  type GameData, type RawGameData,
} from '../../packages/core/src/index.ts';
import { chooseCommand } from './bot.ts';
import { toMarkdown } from './report.ts';

const commandLimit = 2000;

export interface SimStats {
  runs: number;
  clearRate: number;
  firstLossWave: Record<string, number>;
  bossFirstAttempts: Record<number, { attempts: number; wins: number }>;
  averageBattles: number;
  gameOverWave: Record<string, number>;
  averageLivesOnClear: number;
  tier2PlusAtWave5Rate: number;
  firstTier1Wave: Record<string, number>;
  absorptionRate: number;
  spinHitRateBeforeNudge: number;
  spinHitRateAfterNudge: number;
  finalNestRates: Record<string, number>;
}

function ratio(numerator: number, denominator: number): number {
  return denominator === 0 ? 0 : numerator / denominator;
}

export function simulate(data: GameData, runs: number, seed: number, calamity = 0): SimStats {
  if (!Number.isSafeInteger(runs) || runs < 0 || !Number.isSafeInteger(seed)
    || !Number.isSafeInteger(seed + Math.max(0, runs - 1))) {
    throw new RangeError('Expected a nonnegative integer run count and safe integer seeds');
  }

  let clears = 0;
  let battles = 0;
  let livesOnClear = 0;
  let tier2PlusAtWave5 = 0;
  let absorptions = 0;
  let evolutions = 0;
  let spins = 0;
  let hitsBeforeNudge = 0;
  let hitsAfterNudge = 0;
  const firstLossWave: Record<string, number> & { none: number } = { none: 0 };
  const gameOverWave: Record<string, number> = {};
  const bossFirstAttempts = new Map(Object.keys(data.waves.bossPct)
    .map(Number)
    .filter((wave) => isBoss(data.waves, wave))
    .map((wave) => [wave, { attempts: 0, wins: 0 }]));
  const firstTier1Wave: Record<string, number> = { none: 0 };
  const finalNestCounts = new Map(Object.keys(data.dragons).map((id) => [id, 0]));

  for (let i = 0; i < runs; i++) {
    const runSeed = seed + i;
    let { state } = createRun(data, runSeed, calamity);
    let firstLoss: number | undefined;
    let previousBattleWave: number | undefined;
    let firstTier1: number | undefined;
    let checkedWave5 = false;
    let currentSpinHit = false;

    for (let step = 0; step < commandLimit; step++) {
      if (state.phase === 'victory' || state.phase === 'gameOver') break;
      const wave = state.wave;
      const result = applyCommand(data, state, chooseCommand(data, state));
      state = result.state;
      // The simulator never replays commands. Avoid cloning the growing log on every step.
      state.log.length = 0;

      const hit = result.events.some((event) => event.t === 'lineHit');
      for (const event of result.events) {
        switch (event.t) {
          case 'rejected':
            throw new Error(`Bot command rejected (seed ${runSeed}, wave ${wave}): ${event.reason}`);
          case 'spun':
            spins++;
            if (hit) hitsBeforeNudge++;
            currentSpinHit = hit;
            if (hit) hitsAfterNudge++;
            break;
          case 'nudged':
            hitsAfterNudge += Number(hit) - Number(currentSpinHit);
            currentSpinHit = hit;
            break;
          case 'absorbed':
            absorptions++;
            break;
          case 'evolved':
            evolutions++;
            // Evolutions and gained eggs both count as first appearances.
            // falls through
          case 'gained':
            if (firstTier1 === undefined && data.dragons[event.inst.speciesId]?.tier === 't1') firstTier1 = wave;
            break;
          case 'battle': {
            battles++;
            const won = event.result.winner === 'ally';
            if (!won) firstLoss ??= wave;
            const boss = bossFirstAttempts.get(wave);
            if (boss && wave !== previousBattleWave) {
              boss.attempts++;
              if (won) boss.wins++;
            }
            previousBattleWave = wave;
            if (wave === 5 && !checkedWave5) {
              checkedWave5 = true;
              const hasTier2Plus = [...state.nest, ...state.bench].some((inst) => {
                const tier = inst && data.dragons[inst.speciesId]?.tier;
                return tier === 't2' || tier === 't1' || tier === 'dual' || tier === 'secret';
              });
              if (hasTier2Plus) tier2PlusAtWave5++;
            }
            break;
          }
        }
      }
    }

    if (state.phase === 'victory') {
      clears++;
      livesOnClear += state.lives;
      if (firstLoss === undefined) firstLossWave.none++;
    }
    if (firstLoss !== undefined) {
      firstLossWave[firstLoss] = (firstLossWave[firstLoss] ?? 0) + 1;
    }
    if (state.phase === 'gameOver') {
      gameOverWave[state.wave] = (gameOverWave[state.wave] ?? 0) + 1;
    }
    const firstWave = firstTier1 === undefined ? 'none' : String(firstTier1);
    firstTier1Wave[firstWave] = (firstTier1Wave[firstWave] ?? 0) + 1;
    const finalSpecies = new Set(state.nest.flatMap((inst) => inst ? [inst.speciesId] : []));
    for (const id of finalSpecies) finalNestCounts.set(id, (finalNestCounts.get(id) ?? 0) + 1);
  }

  return {
    runs,
    clearRate: ratio(clears, runs),
    firstLossWave,
    bossFirstAttempts: Object.fromEntries(bossFirstAttempts),
    averageBattles: ratio(battles, runs),
    gameOverWave,
    averageLivesOnClear: ratio(livesOnClear, clears),
    tier2PlusAtWave5Rate: ratio(tier2PlusAtWave5, runs),
    firstTier1Wave,
    absorptionRate: ratio(absorptions, absorptions + evolutions),
    spinHitRateBeforeNudge: ratio(hitsBeforeNudge, spins),
    spinHitRateAfterNudge: ratio(hitsAfterNudge, spins),
    finalNestRates: Object.fromEntries(Array.from(finalNestCounts, ([id, count]) => [id, ratio(count, runs)])),
  };
}

function readData<K extends keyof RawGameData>(key: K): RawGameData[K] {
  return JSON.parse(readFileSync(new URL(`../../data/${key}.json`, import.meta.url), 'utf8'));
}

export function loadSimulationData(): GameData {
  return loadGameData({
    dragons: readData('dragons'),
    traits: readData('traits'),
    recipes: readData('recipes'),
    slot: readData('slot'),
    waves: readData('waves'),
    battle: readData('battle'),
    rewards: readData('rewards'),
    bosses: readData('bosses'),
    calamity: readData('calamity'),
  });
}

function main(args: string[]): void {
  let runs = 10000;
  let seed = 1;
  let calamity = 0;
  let maxWave = 0;
  let finalBossPct = 0;
  for (let i = 0; i < args.length; i += 2) {
    const option = args[i];
    const value = args[i + 1];
    if (!['--runs', '--seed', '--calamity', '--max-wave', '--final-boss-pct'].includes(option ?? '') || !value || !/^-?\d+$/.test(value)) {
      throw new Error('Usage: node tools/sim/run.ts --runs 10000 --seed 1 [--calamity 0] [--max-wave 10] [--final-boss-pct 340]');
    }
    if (option === '--runs') runs = Number(value);
    else if (option === '--seed') seed = Number(value);
    else if (option === '--calamity') calamity = Number(value);
    else if (option === "--max-wave") maxWave = Number(value);
    else finalBossPct = Number(value);
  }
  const data = loadSimulationData();
  if (maxWave > 0) data.waves = { ...data.waves, maxWave };
  if (finalBossPct > 0) data.waves = { ...data.waves, bossPct: { ...data.waves.bossPct, [String(data.waves.maxWave)]: finalBossPct } };
  const markdown = toMarkdown(simulate(data, runs, seed, calamity));
  mkdirSync(new URL('../../docs/balance/', import.meta.url), { recursive: true });
  writeFileSync(new URL('../../docs/balance/latest.md', import.meta.url), markdown);
  process.stdout.write(markdown);
}

if (import.meta.main) main(process.argv.slice(2));
