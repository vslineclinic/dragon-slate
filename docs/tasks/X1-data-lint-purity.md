# 작업 카드 X1: 실데이터 22종 · 데이터 검사기 · core 순수성 감사

먼저 `AGENTS.md`를 읽어요.

## 목표
게임 데이터 22종을 JSON으로 만들고, 그 데이터를 검사하는 도구와 core 규칙 코드 순수성 감사 테스트를 만들어요.

## 고칠 파일 (새로 만듦)
- `data/dragons.json`, `data/recipes.json`, `data/traits.json`, `data/slot.json`, `data/waves.json`, `data/battle.json`
- `tools/lint-data/lint.ts`, `tools/lint-data/lint.test.ts`, `tools/lint-data/fixtures/bad-*.json`
- `packages/core/test/purity.test.ts`

## 건드리면 안 되는 파일
`packages/core/src/**`, `packages/view/**`, `package.json`, `package-lock.json`, `data/fixtures/**`, `docs/**`

## 참고할 계약
- `packages/core/src/contracts/types.ts`의 `DragonSpec`, `TraitSpec`, `Recipe`, `SlotConfig`, `WaveConfig`, `BattleConfig`, `RawGameData`
- `packages/core/src/data.ts`의 `loadGameData`
- 파일 형식: `dragons.json`은 `DragonSpec[]`, `traits.json`은 `TraitSpec[]`, `recipes.json`은 `Recipe[]`, `slot.json`·`waves.json`·`battle.json`은 각 설정 객체 하나. 설정값은 `data/fixtures/mini.json`의 `slot`·`waves`·`battle`과 똑같이 써요.

## 데이터 규칙
22종 id, tier, role, 레시피:
- 화염: base `fire_drake`(마그마 드레이크, front), `fire_wyvern`(화염 와이번, back) / t2 `beowulf_firedrake`(베오울프 화룡, front) = fire_drake+fire_drake, `fafnir`(파프니르, support) = fire_drake+fire_wyvern, `xiuhcoatl`(시우코아틀, back) = fire_wyvern+fire_wyvern / t1 `zhulong`(촉룡, support) = fafnir+xiuhcoatl
- 빙결: `ice_drake`(빙하 드레이크), `ice_wyvern`(서리 와이번) / `palraiyuk`(팔라이유크, A+A, front), `north_black_dragon`(북해흑룡 오순, A+B, support), `azi_raoidita`(아지 라오이디타, B+B, back) / `kuraokami`(쿠라오카미) = north_black_dragon+azi_raoidita
- 번개: `storm_drake`(뇌운 드레이크), `storm_wyvern`(폭풍 와이번) / `beisir`(베이시르, A+A, front), `east_blue_dragon`(동해청룡 오광, A+B, support), `quetzalcoatl`(케찰코아틀, B+B, back) / `yinglong`(응룡) = east_blue_dragon+quetzalcoatl
- dual(role support): `thermal_dragon`(열충격룡, elements ["fire","ice"]) = 화염 t2 3종 × 빙결 t2 3종 9쌍, `thunderbird`(선더버드, ["fire","lightning"]) = 화염 t2 × 번개 t2 9쌍, `jiaolong`(교룡, ["ice","lightning"]) = 빙결 t2 × 번개 t2 9쌍
- secret `tiamat`(원초룡 티아마트, elements ["fire","ice","lightning"], support) = thermal_dragon+yinglong, thunderbird+kuraokami, jiaolong+zhulong
- 레시피는 모두 42개. 한 원소 종의 elements는 그 원소 하나.

능력치(정수 내림):
- 기본값: base hp 100 / atk 10 / cooldownTicks 20, t2 220/22/20, t1 480/48/18, dual 400/40/18, secret 900/90/16
- role 보정: front는 hp×130%·atk×80%, back은 hp×80%·atk×125%, support는 그대로

특성: 종마다 하나(id `tr_<종id>`, 22개). kind는 `atkPct`, `hpPct`, `hastePct`, `lifestealPct`를 고르게 쓰고, value는 base 10, t2 15, t1 25, dual 20, secret 30. nameKo는 짧은 한국어(예: "용암 갑각"). 화면 금지어(각인, 코어, 잭팟, 코인, 베팅, 칩)는 쓰지 않아요.

## 검사기
`export function lintData(raw: RawGameData): string[]` (문제 목록, 비면 통과). `node tools/lint-data/lint.ts`로 실행하면 `data/*.json` 6개를 읽어 검사하고, 문제가 있으면 줄마다 출력하고 exit 1, 없으면 "data ok: 22 dragons, 42 recipes"를 출력해요. 함수 export와 실행부는 `import.meta.main` 같은 것으로 분리해요(테스트에서 import할 때 실행되지 않게).

검사 항목: id 중복, 참조 없는 id(레시피·traitId), 순서 무관 중복 레시피, base에서 레시피로 닿지 않는 종, base·t2·t1 레시피의 재료와 결과 원소 불일치, 0 이하 가중치·능력치, 빈 `rerollCosts`.

## 순수성 감사
`packages/core/test/purity.test.ts`: `packages/core/src` 아래 `.ts` 파일을 전부 읽어 다음 토큰이 하나도 없는지 확인해요(주석 포함): `phaser`(대소문자 무시), `document`, `window`, `localStorage`, `Math.random`, `Date.now`, `performance.now`, `Math.sin`, `Math.cos`, `Math.tan`, `Math.pow`, `Math.exp`, `Math.log`, `Math.sqrt`. 걸리면 파일명과 토큰을 메시지에 보여 줘요.

## 완료 기준 (테스트 이름)
- `lint.test.ts`: `real data passes`, `detects duplicate pair`, `detects unknown id`, `detects unreachable species`, `detects cross-element t2 recipe`
- `purity.test.ts`: `core source has no forbidden tokens`

## 실행할 명령
`npm test`, `npm run typecheck`, `npm run lint:data`가 모두 통과해야 해요.

## 결과 보고 형식
- 바꾼 파일 목록
- 위 세 명령의 출력 꼬리
- 판단한 것과 이유
- (있으면) `## 계약 변경 요청`, `## 필요한 패키지`
