# 작업 카드 X7: 6원소 52종 데이터 + 도감 문구

먼저 `AGENTS.md`를 읽고, `docs/superpowers/plans/2026-11-23-six-elements.md`의 "결정 사항"을 그대로 따라요.

## 고칠 파일
- `data/dragons.json`, `data/traits.json`, `data/recipes.json`, `data/slot.json`, `data/codex.json`
- `tools/lint-data/lint.ts`, `tools/lint-data/lint.test.ts` (숫자·원소 검사를 6원소에 맞게)
- 22종 기준 숫자를 기대하는 테스트가 `packages/core/test/`에 있으면 **고치지 말고** 결과에 파일·테스트 이름을 적어요(지휘자가 고침).

## 건드리면 안 되는 파일
`packages/**`(위 예외 포함), `package.json`, `data/battle.json`, `data/waves.json`, `data/bosses.json`, `data/rewards.json`, `data/calamity.json`

## 규칙
- 기존 22종은 id·이름·능력치·특성을 그대로 둬요. 단, 이중원소 `thermal_dragon`·`thunderbird`·`jiaolong`과 숨은 `tiamat`의 레시피는 아래 규칙으로 다시 만들어요(기존 것 포함되게).
- 새 30종: 계획서의 id·티어·역할·레시피 그대로. 원소 문자열은 `poison`, `steel`, `abyss`.
- 한국어 이름: 독 — 늪지 드레이크, 맹독 와이번, 히드라, 바실리스크, 코카트리스, 요르문간드 / 강철 — 강철 드레이크, 강철 와이번, 타라스크, 서해백룡 오윤, 질란트, 라돈 / 심연 — 심연 드레이크, 그림자 와이번, 아포피스, 브리트라, 레비아탄, 니드호그 / 이중 — 살라만더, 용광로룡, 아지 다하카, 빙독룡, 결정갑룡, 심해 서펜트, 뇌독룡, 티폰, 칠흑뇌룡, 부식철룡, 역병룡, 흑철룡.
- 능력치·특성 규칙은 기존과 같아요(base 100/10/20, t2 220/22/20, t1 480/48/18, dual 400/40/18, secret 900/90/16, role 보정 front hp×130%·atk×80%, back hp×80%·atk×125%; 특성 value base 10, t2 15, t1 25, dual 20, secret 30, kind 4종 고르게).
- 이중 레시피: 원소 쌍마다 그 두 원소의 2티어 3종 × 3종 = 9개. 15쌍 = 135개. 이중의 elements는 쌍의 두 원소(앞 원소는 아래 순서상 앞선 것): fire, ice, lightning, poison, steel, abyss.
- 숨은 tiamat: 6개 레시피(계획서). elements는 기존 그대로.
- 전체 레시피 165개, 드래곤 52종, 특성 52개.
- `slot.json`의 weights: fire·ice·lightning·poison·steel·abyss 각 12, gold 12, wild 16 (나머지 값 유지).
- `codex.json`: 새 30종 추가(기존 22종 문구 유지, 단 티아마트 hintKo는 새 레시피를 반영해 다시). 형식·말투는 기존과 같게. 원전이 불분명하면 "전해진다". 바실리스크·코카트리스·히드라·요르문간드·라돈·아포피스·브리트라·레비아탄·니드호그·티폰·아지 다하카·살라만더는 원전 신화를 짧게. D&D·FF 묘사 금지.
- 검사기: 원소 6개 허용, 52종·165개를 기준으로 테스트 갱신(`real data passes`).

## 완료 기준
`npm test`(core 쪽 숫자 기대 테스트 실패는 결과에 적기), `npm run typecheck`, `npm run lint:data` 결과를 보고.
