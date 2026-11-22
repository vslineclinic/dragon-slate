# 작업 카드 X3: 밸런스 지표 보강

먼저 `AGENTS.md`를 읽어요.

## 목표
한 판이 20웨이브, 심판 보스 4종(5·10·15·20)이 생겼어요. 지금 리포트의 "평균 도달 웨이브"는 패배해도 웨이브가 진행돼서 의미가 없어요. 보스 난이도를 볼 수 있는 지표로 바꿔요.

## 고칠 파일
`tools/sim/run.ts`, `tools/sim/report.ts`, `tools/sim/sim.test.ts` (필요하면 `tools/sim/bot.ts`)

## 건드리면 안 되는 파일
`packages/**`, `data/**`, `package.json`, `docs/**` (실행 결과로 `docs/balance/latest.md`를 쓰는 기존 동작은 유지, 이번 작업에서 그 파일은 남기지 마세요)

## 바꿀 지표
- 제거: "평균 도달 웨이브"
- 추가: 첫 패배 웨이브 분포(패배 없이 클리어 포함, 판당 한 번만 셈), 보스 웨이브(5·10·15·20)별 **첫 도전 승률**, 판당 평균 전투 횟수(재도전 포함), 게임오버가 난 웨이브 분포.
- 보스 웨이브 여부는 `data.waves.bossPct`에 키가 있고 `maxWave` 이하인지로 판단해요.

## 완료 기준 (테스트 이름)
- `report has boss win rates`
- `first loss wave counted once per run`
- 기존 테스트 유지(`same seed same stats`, `bot never issues rejected command`, `report has all rows` — 행 목록이 바뀌면 이 테스트도 맞게 고쳐요)

## 실행할 명령
`npm test`, `npm run typecheck`, `node tools/sim/run.ts --runs 2000 --seed 1`(1분 이내, 결과 표를 보고에 붙이고 생성된 파일은 지워요)

## 결과 보고 형식
바꾼 파일, 명령 출력 꼬리(표 포함), 판단한 것.
