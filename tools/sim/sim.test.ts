import { expect, test } from 'vitest';
import { applyCommand, createRun } from '../../packages/core/src/index.ts';
import { chooseCommand } from './bot.ts';
import { toMarkdown } from './report.ts';
import { loadSimulationData, simulate } from './run.ts';

const data = loadSimulationData();

test('same seed same stats', () => {
  expect(simulate(data, 200, 1)).toEqual(simulate(data, 200, 1));
});

test('bot never issues rejected command', () => {
  for (let seed = 1; seed <= 50; seed++) {
    let { state } = createRun(data, seed);
    for (let step = 0; step < 2000 && state.phase !== 'victory' && state.phase !== 'gameOver'; step++) {
      const command = chooseCommand(data, state);
      const result = applyCommand(data, state, command);
      expect(result.events, `seed ${seed}, wave ${state.wave}, step ${step}, ${command.type}`)
        .not.toContainEqual(expect.objectContaining({ t: 'rejected' }));
      state = result.state;
    }
    expect(['victory', 'gameOver']).toContain(state.phase);
  }
});

test('report has all rows', () => {
  const markdown = toMarkdown(simulate(data, 10, 1));
  for (const label of [
    '클리어율',
    '첫 패배 웨이브 분포',
    '보스 웨이브별 첫 도전 승률',
    '판당 평균 전투 횟수 (재도전 포함)',
    '게임오버 웨이브 분포',
    '평균 남은 생명 (클리어 기준)',
    '5웨이브 종료 시 t2 이상 보유 비율',
    '1티어 첫 등장 웨이브 분포',
    '합치기 중 흡수 비율',
    '스핀당 줄 맞춤 비율 (밀기 전)',
    '스핀당 줄 맞춤 비율 (밀기 후)',
    '종별 최종 둥지 등장률 상위 5',
    '종별 최종 둥지 등장률 하위 5',
  ]) {
    expect(markdown).toContain(`| ${label} | `);
  }
  expect(markdown).not.toContain('평균 도달 웨이브');
  expect(markdown).toMatch(/없음 \d+판/);
});

test('report has boss win rates', () => {
  const stats = simulate(data, 10, 1);
  const markdown = toMarkdown(stats);
  for (const wave of [5, 10, 15, 20]) {
    expect(markdown).toMatch(new RegExp(`${wave}웨이브 (?:도전 없음|\\d+\\.\\d{2}%)`));
  }
  expect(stats.bossFirstAttempts[5]?.attempts).toBeGreaterThan(0);
});

test('first loss wave counted once per run', () => {
  const stats = simulate({
    ...data,
    waves: { ...data.waves, maxWave: 2, bossPct: { 2: 100, 4: 100 }, startLives: 5, lossLife: 1, bossLossLife: 2 },
    battle: { ...data.battle, maxTicks: 0 },
  }, 3, 1);

  expect(stats.firstLossWave).toEqual({ 1: 3, none: 0 });
  expect(stats.bossFirstAttempts).toEqual({ 2: { attempts: 3, wins: 0 } });
  expect(stats.averageBattles).toBe(3);
  expect(stats.gameOverWave).toEqual({ 2: 3 });
  expect(toMarkdown(stats)).toContain('2웨이브 0.00% (0/3)');

  // 적을 아주 약하게 해서 데이터와 상관없이 무패가 되게 한다
  const unbeaten = simulate({ ...data, waves: { ...data.waves, maxWave: 1, basePower: 1 } }, 3, 1);
  expect(unbeaten.firstLossWave).toEqual({ none: 3 });
  expect(unbeaten.gameOverWave).toEqual({});
  expect(toMarkdown(unbeaten)).toContain('패배 없이 클리어 3판');
});
