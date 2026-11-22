# 작업 카드 G1a: 규칙 이식 1 (GDScript)

먼저 `AGENTS.md`(특히 "Godot 작업 규칙")와 `docs/superpowers/plans/2026-11-23-godot-transition.md`를 읽어요. 이미 있는 `godot/core/rng.gd`, `godot/tests/test_case.gd`, `godot/tests/test_rng.gd`가 패턴이에요.

## 목표
TypeScript 규칙을 GDScript로 그대로 옮겨요. 결과는 TypeScript와 비트 단위로 같아야 해요.

## 고칠 파일 (새로 만듦)
- `godot/core/data.gd` (`class_name GameData`): `static func load_all() -> Dictionary` — `res://data/` 의 dragons, traits, recipes, slot, waves, battle, rewards, bosses, calamity를 읽어 TS `loadGameData`와 같은 모양으로(dragons/traits는 id→항목 Dictionary, 나머지 그대로, 없는 파일은 빈 배열). 참조 검사(`unknown traitId`, `unknown dragon id`)도 같은 문구로 `push_error` + 빈 Dictionary 반환. `static func active_elements(data) -> Array` (TS `activeElements`).
- `godot/core/slot.gd` (`class_name Slot`): `LINES`, `spin_grid(data, rng, force_line) -> Dictionary`, `visible(grid, col, row)`, `evaluate_lines(grid) -> Array`, `nudge(grid, col, dir)`, `offers_from(data, grid)`.
- `godot/core/fusion.gd` (`class_name Fusion`): `find_recipe`, `merge_preview`, `merge`.
- `godot/core/battle.gd` (`class_name Battle`): `element_mult`, `to_unit`, `simulate_battle(cfg, allies, enemies, rules := {})`.
- `godot/core/waves.gd` (`class_name Waves`): `is_boss`, `enemy_power(cfg, wave, mods := Calamity.NONE)`, `boss_element(seed, wave, elements)`, `unit_power`, `generate_enemies(data, wave, rng, seed, mods := Calamity.NONE)`.
- `godot/core/calamity.gd` (`class_name Calamity`): `NONE`, `mods(data, level)`.
- 테스트: `godot/tests/test_slot.gd`, `test_fusion.gd`, `test_battle.gd`, `test_waves.gd`, `test_calamity.gd` — `packages/core/test/`의 같은 이름 테스트를 옮겨요(값·기대 결과 동일). 테스트용 작은 데이터는 `data/fixtures/mini.json`을 읽어서 만들어요.

## 건드리면 안 되는 파일
`packages/**`, `data/**`(읽기만), `godot/tests/fixtures/**`, `godot/core/rng.gd`, `godot/tests/run_tests.gd`, `godot/tests/test_case.gd`, `package.json`, `project.godot`

## 원본(명세)
`packages/core/src/{data,slot,fusion,battle,waves,calamity}.ts`와 `packages/core/src/contracts/*.ts`가 명세예요. 키 이름은 TypeScript와 같게(camelCase 그대로: `speciesId`, `cooldownTicks` 등) — 이벤트·상태 Dictionary를 TypeScript JSON과 직접 비교하기 때문이에요. 함수 이름만 snake_case.

## 주의
- 모든 나눗셈은 `Math.floor`와 같게(양수면 `/`, 음수 가능하면 `Rng.fdiv`).
- `Object.values(...)`·정렬 순서를 TypeScript와 같게(종 id 정렬 등). GDScript Dictionary는 넣은 순서를 지키니 JSON 순서와 같아요.
- 난수 호출 횟수·순서가 하나라도 다르면 이후 결과가 전부 달라져요.

## 완료 기준
`C:\claude\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://godot/tests/run_tests.gd` 가 "실패 0개", 그리고 `npm test` 유지.

## 결과 보고
바꾼 파일, 테스트 출력 꼬리, TypeScript와 다르게 판단한 곳(있으면).
