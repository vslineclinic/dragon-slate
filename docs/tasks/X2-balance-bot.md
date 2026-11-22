# 작업 카드 X2: 밸런스 봇

먼저 `AGENTS.md`를 읽어요.

## 목표
규칙 엔진(`packages/core`)으로 수천~수만 판을 자동으로 돌리는 휴리스틱 봇과, 결과를 마크다운 표로 내는 시뮬레이터를 만들어요.

## 고칠 파일 (새로 만듦)
`tools/sim/bot.ts`, `tools/sim/run.ts`, `tools/sim/report.ts`, `tools/sim/sim.test.ts`

## 건드리면 안 되는 파일
`packages/**`, `data/**`, `package.json`, `package-lock.json`, `docs/**` (단, `run.ts` 실행 결과로 `docs/balance/latest.md`를 쓰는 것은 실행 시 동작이라 괜찮아요. 이번 작업에서는 그 파일을 만들지 마세요)

## 참고할 계약
`packages/core/src/index.ts`에서 가져와요: `loadGameData`, `createRun`, `applyCommand`, `mergePreview`, `offersFrom`, `evaluateLines`, `nudge`, `toUnit`, 타입 `GameData`, `RunState`, `Command`, `GameEvent`, `RawGameData`. 데이터는 `data/*.json` 6개(`dragons`, `traits`, `recipes`, `slot`, `waves`, `battle`).

## 만들 것
- `bot.ts`: `export function chooseCommand(data: GameData, state: RunState): Command` — 봇의 다음 한 수. 반드시 받아들여지는 명령만 낸다.
- `run.ts`: `export function simulate(data: GameData, runs: number, seed: number): SimStats` — 판 i는 시드 `seed + i`. 판마다 명령을 최대 2000개까지 둔다(안전 장치). `node tools/sim/run.ts --runs 10000 --seed 1`로 실행하면 표를 stdout에 출력하고 `docs/balance/latest.md`에 쓴다(폴더가 없으면 만든다). 함수 export와 실행부는 분리한다(테스트에서 import할 때 실행되지 않게).
- `report.ts`: `export function toMarkdown(stats: SimStats): string`

## 봇 규칙 (단계 `state.phase`별)
- `spin`: 돌린다.
- `pick`: (1) 밀기가 남았고, 세로 줄 하나를 위나 아래로 밀어 맞은 줄 수가 늘어나면 가장 많이 늘어나는 밀기를 한다. (2) 아니면, 마력이 8 이상이고 이번 웨이브 스핀이 1번뿐이고 맞은 줄이 없으면 한 번 더 돌린다. (3) 아니면 제안을 고른다. 우선순위: 대기칸·둥지에 있는 용과 레시피(진화)를 이루는 알 > 둥지 용의 원소와 같은 알 > 첫 알 제안. 알인데 대기칸이 차 있으면 마력 제안을 고른다. 마력 제안이 없으면 대기칸에서 가장 약한 용을 놓아준다(이건 `manage`가 아니라서 불가하니, 그럴 때는 마력 제안 없는 경우에 한해 첫 제안을 고르고, 대기칸이 차서 거절될 상황은 피하도록 앞 웨이브의 `manage`에서 대기칸을 1칸 이상 비워 둔다).
- `manage`: (1) 진화 레시피가 되는 두 용(둥지·대기칸 어디든)이 있으면 합친다(둥지에 있는 쪽을 주인으로). (2) 대기칸이 꽉 찼으면 가장 약한 용을 둥지의 가장 강한 용에 흡수시킨다(둥지가 비었으면 놓아준다). (3) 열린 둥지 빈칸이 있으면 대기칸에서 가장 강한 용을 옮긴다. front 역할은 0~2번, back은 3~5번 칸을 먼저 쓴다(열려 있는 범위 안에서). (4) 둥지가 꽉 찼고 대기칸에 둥지의 가장 약한 용보다 강한 용이 있으면 바꾼다(move로 맞바꿈). (5) 대기칸을 1칸 이상 비워 둔다(꽉 차 있으면 가장 약한 것을 놓아준다). (6) 전투를 시작한다.
- 강함 비교는 `toUnit`의 `floor(hp/4) + floor(atk*20/cooldownTicks)`로 한다.

## SimStats 표 항목
클리어율, 평균 도달 웨이브, 평균 남은 생명(클리어한 판 기준), 5웨이브 끝났을 때 t2 이상 보유 비율, 1티어 첫 등장 웨이브 분포(없음 포함), 합치기 중 흡수 비율, 스핀당 줄 맞춤 비율(밀기 전·후), 종별 최종 둥지 등장률 상위 5·하위 5.

## 완료 기준 (테스트 이름)
- `same seed same stats` (runs 200 두 번 비교)
- `bot never issues rejected command` (runs 50, 모든 명령 결과에 `rejected` 이벤트가 없음)
- `report has all rows`

## 실행할 명령
`npm test`, `npm run typecheck`, 그리고 `node tools/sim/run.ts --runs 2000 --seed 1`이 1분 안에 끝나야 해요(이 명령이 쓰는 `docs/balance/latest.md`는 끝난 뒤 지워 주세요 — 작업 범위 밖 파일이에요).

## 결과 보고 형식
- 바꾼 파일 목록
- 위 명령 출력 꼬리(시뮬레이션 표 포함)
- 판단한 것과 이유
- (있으면) `## 계약 변경 요청`, `## 필요한 패키지`
