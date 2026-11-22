/**
 * Godot(GDScript) 이식이 TypeScript판과 같은 결과를 내는지 확인할 기준 자료를 만든다.
 * 실행: npm run parity → godot/tests/fixtures/*.json
 * 데이터(data/*.json)가 바뀌면 다시 실행해야 한다.
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { applyCommand, createRng, createRun } from '../../packages/core/src/index.ts';
import type { Command } from '../../packages/core/src/index.ts';
import { chooseCommand } from '../sim/bot.ts';
import { loadSimulationData } from '../sim/run.ts';

const out = new URL('../../godot/tests/fixtures/', import.meta.url);
mkdirSync(out, { recursive: true });
const write = (name: string, value: unknown) => writeFileSync(new URL(name, out), JSON.stringify(value) + '\n');

// 1) 난수
const rng = [1, 42, 123456789].map((seed) => {
  const r = createRng(seed);
  const u32 = Array.from({ length: 20 }, () => r.nextU32());
  const ints = Array.from({ length: 20 }, () => r.nextInt(6));
  const picks = Array.from({ length: 20 }, () => r.pickWeighted(['a', 'b', 'c'], (x) => ({ a: 1, b: 3, c: 6 })[x] as number));
  return { seed, u32, ints, picks, state: r.state() };
});
write('rng.json', rng);

// 2) 판 전체: 봇이 고른 명령과, 명령마다 나온 이벤트·상태 해시
const data = loadSimulationData();
const runs = [1, 7, 99].map((seed) => {
  let { state } = createRun(data, seed);
  const steps: { cmd: Command; events: unknown; state: unknown }[] = [];
  for (let i = 0; i < 80 && state.phase !== 'gameOver' && state.phase !== 'victory'; i++) {
    const cmd = chooseCommand(data, state);
    const r = applyCommand(data, state, cmd);
    const { log: _log, ...rest } = r.state;
    steps.push({ cmd, events: r.events, state: rest });
    state = r.state;
  }
  const first = createRun(data, seed);
  const { log: _l, ...start } = first.state;
  return { seed, start, startEvents: first.events, steps };
});
write('runs.json', runs);
console.log('parity fixtures written: rng.json, runs.json (' + runs.map((r) => r.steps.length).join('/') + ' steps)');
