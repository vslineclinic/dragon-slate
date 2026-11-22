# 작업 카드 G1b: 규칙 이식 2 + 판 전체 일치 검사 (GDScript)

먼저 `AGENTS.md`와 `docs/superpowers/plans/2026-11-23-godot-transition.md`를 읽어요. G1a에서 만든 `godot/core/*.gd`를 써요.

## 고칠 파일 (새로 만듦)
- `godot/core/hints.gd` (`class_name Hints`): `best_nudge`, `recommend_offer`, `evolvable_pairs`, `line_rewards` — `packages/core/src/hints.ts`.
- `godot/core/run.gd` (`class_name Run`): `create_run(data, seed, calamity := 0) -> Dictionary{state, events}`, `apply_command(data, state, cmd) -> Dictionary{state, events}`, `spin_cost(data, state)`, `state_hash(state)` — `packages/core/src/run.ts`. 입력 state를 바꾸지 않아요(`duplicate(true)`). 거절이면 같은 state와 `[{ "t": "rejected", "reason": ... }]`.
- `godot/tests/test_hints.gd`, `godot/tests/test_run.gd` — TypeScript 테스트를 옮겨서.
- `godot/tests/test_parity_runs.gd`: `res://godot/tests/fixtures/runs.json`의 각 판(seed)마다 `create_run(data, seed)`의 상태(log 제외)·이벤트가 `start`·`startEvents`와 같고, `steps`의 `cmd`를 차례로 적용했을 때 매 단계 `events`와 `state`(log 제외)가 같아야 해요. 처음 다른 단계에서 무엇이 다른지(키 경로) 메시지로 보여 줘요.

## 건드리면 안 되는 파일
`packages/**`, `data/**`, `godot/tests/fixtures/**`, `godot/core/rng.gd`, `godot/tests/run_tests.gd`, `godot/tests/test_case.gd`, `package.json`, `project.godot`. G1a 파일은 버그 수정만(이유를 결과에 적기).

## 완료 기준
Godot 테스트 "실패 0개"(일치 검사 3판 포함), `npm test` 유지.

## 결과 보고
바꾼 파일, 테스트 출력 꼬리, 일치 검사에서 처음 어긋났던 곳과 고친 방법.
