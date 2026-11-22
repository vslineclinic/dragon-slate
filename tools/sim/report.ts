import type { SimStats } from './run.ts';

function pct(rate: number): string {
  return `${(rate * 100).toFixed(2)}%`;
}

export function toMarkdown(stats: SimStats): string {
  const firstTier1 = Object.entries(stats.firstTier1Wave)
    .filter(([wave]) => wave !== 'none')
    .sort(([a], [b]) => Number(a) - Number(b))
    .map(([wave, count]) => `${wave}웨이브 ${count}판`);
  firstTier1.push(`없음 ${stats.firstTier1Wave.none ?? 0}판`);

  const species = Object.entries(stats.finalNestRates);
  const ranking = (direction: 1 | -1) => species
    .slice()
    .sort(([a, rateA], [b, rateB]) => direction * (rateA - rateB) || (a < b ? -1 : Number(a > b)))
    .slice(0, 5)
    .map(([id, rate]) => `${id} ${pct(rate)}`)
    .join(', ');

  return [
    '# 밸런스 시뮬레이션',
    '',
    `총 ${stats.runs}판`,
    '',
    '| 지표 | 결과 |',
    '| --- | --- |',
    `| 클리어율 | ${pct(stats.clearRate)} |`,
    `| 평균 도달 웨이브 | ${stats.averageWaveReached.toFixed(2)} |`,
    `| 평균 남은 생명 (클리어 기준) | ${stats.averageLivesOnClear.toFixed(2)} |`,
    `| 5웨이브 종료 시 t2 이상 보유 비율 | ${pct(stats.tier2PlusAtWave5Rate)} |`,
    `| 1티어 첫 등장 웨이브 분포 | ${firstTier1.join(', ')} |`,
    `| 합치기 중 흡수 비율 | ${pct(stats.absorptionRate)} |`,
    `| 스핀당 줄 맞춤 비율 (밀기 전) | ${pct(stats.spinHitRateBeforeNudge)} |`,
    `| 스핀당 줄 맞춤 비율 (밀기 후) | ${pct(stats.spinHitRateAfterNudge)} |`,
    `| 종별 최종 둥지 등장률 상위 5 | ${ranking(-1)} |`,
    `| 종별 최종 둥지 등장률 하위 5 | ${ranking(1)} |`,
    '',
  ].join('\n');
}
