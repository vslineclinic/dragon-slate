# 작업 카드 X4: 도감 문구 초안 + 검사기

먼저 `AGENTS.md`를 읽어요.

## 목표
도감에 보여 줄 22종의 힌트·설명 문구를 만들고, 데이터 검사기가 그 파일을 확인하게 해요.

## 고칠 파일
- 새로 만듦: `data/codex.json`
- 고침: `tools/lint-data/lint.ts`, `tools/lint-data/lint.test.ts` (필요하면 `tools/lint-data/fixtures/` 추가)

## 건드리면 안 되는 파일
`packages/**`, `data/` 안의 다른 파일, `package.json`, `docs/**`

## 형식
`[{ "id": "<data/dragons.json의 id>", "hintKo": "...", "loreKo": "..." }]` — 22개, dragons.json 순서대로.
- `hintKo`: 이 드래곤을 어떻게 만드는지 **레시피를 직접 말하지 않고** 신화·이미지로 돌려 말하는 한 문장. `data/recipes.json`을 보고 재료의 특징을 암시해요. 기본종은 "룬 석판에서 얻을 수 있다"는 뜻이면 돼요. 예: 촉룡 → "탐욕의 불꽃과 청록 불뱀이 함께하면, 눈을 뜨면 낮이 되는 용이 깨어난다."
- `loreKo`: 두 문장 이내. 원전(신화·전설) 소개와 이 게임에서의 성격. 원전이 불확실하면 단정하지 말고 "~로 전해진다"처럼 써요. 베이시르는 원전이 불분명하니 게임 속 창작 설정으로 써요.
- 금지: D&D·파이널판타지 등 특정 게임의 묘사, 화면 금지어(잭팟, 코인, 베팅, 칩, 각인, 코어).
- 말투: 짧고 담백한 한국어.

## 검사기 추가
`lintData`가 `codex`(선택 필드)를 받으면: id가 dragons에 있는지, 22종 모두 있는지, hintKo·loreKo가 비어 있지 않은지 확인. `node tools/lint-data/lint.ts`가 `data/codex.json`도 읽어요(없으면 건너뜀).

## 완료 기준
- 테스트 `codex covers every dragon`, `detects codex unknown id` 통과
- `npm test`, `npm run typecheck`, `npm run lint:data` 통과

## 결과 보고 형식
바꾼 파일, 세 명령 출력 꼬리, 판단한 것.
