# 부대 전투 · 큰 전장 · 굴림 석판 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Godot판 전투를 위치 기반 부대 전투로 바꾸고, 화면을 큰 전장 중심으로 다시 배치하고, 석판 굴림 애니메이션과 배경을 넣는다.

**Architecture:** core(`godot/core/*.gd`)는 결정적 정수 시뮬레이션으로 유닛 위치·줄·표적을 계산하고 events(spawn/attack/death/hazard/pos)를 낸다. UI는 그 events를 보간 재생한다. 화면 배치는 뷰포트 폭(1280~1600)에 맞춰 다시 계산한다.

**Tech Stack:** Godot 4.7.2, GDScript(정적 타입), 자체 테스트 러너 `godot/tests/run_tests.gd`.

**Spec:** `docs/superpowers/specs/2026-11-23-squad-battlefield-design.md`

## Global Constraints
- core 규칙: Node·randi·randf·Time·OS 금지, 난수는 `Rng`만, 정수 계산, 나눗셈은 `Rng.fdiv`, 배율은 백분율 정수.
- 수치는 `data/*.json`에서 읽는다. 코드 상수는 판 구조값(3×3, 둥지 6, 대기칸 4, 줄 3)뿐.
- 화면 문구는 한국어. 금지어: 잭팟, JACKPOT, 코인, 베팅, 칩, 각인, 코어.
- 원소 상성: battle.json beats, 강 135 / 약 75.
- 웹판(packages/*, apps/*, tools/sim, tools/parity)은 수정하지 않는다.
- 테스트: `npm run godot:test` 전부 통과.

## Review Focus
1. 둥지에 드래곤 1마리만 있을 때 1웨이브: 끝까지 진행되고(시간 초과 아님) 승률 90% 이상.
2. 아군 드래곤이 전부 후열에만 있을 때: 적이 닿지 못해 끝나지 않는 일이 없음(드래곤 사거리 무제한, 줄 이동).
3. 유닛 30개 이상(14웨이브 이후)에서 events 크기와 재생 속도: 4x 배속에서 끊기지 않음, pos 기록은 움직인 유닛만.
4. 화면 폭 1600(20:9)과 1280(16:9) 모두에서 아래 띠 요소가 겹치지 않음.
5. 굴림 애니메이션 도중 탭·다시 돌리기·밀기(▲▼) 입력: 결과가 core 상태와 어긋나지 않음.

---

### Task 1: 부대 전투 core
**Files:**
- Modify: `godot/core/battle.gd` (simulate_battle 교체, to_unit 유지), `godot/core/waves.gd` (generate_enemies 교체), `godot/core/run.gd` (_do_battle: 아군에 slot 번호 전달), `godot/core/data.gd` (minions 읽기)
- Create: `data/minions.json`
- Modify: `data/battle.json` (escort, field 값 추가), `data/waves.json` (squad 값 추가)
- Test: `godot/tests/test_battle.gd` (다시 씀), `godot/tests/test_waves.gd` (부대 구성 테스트로 바꿈)
- Delete from runner: `godot/tests/test_parity_runs.gd` (run 일치 검사 은퇴, rng·slot 일치 검사는 유지)

**Interfaces:**
- Produces: `Battle.simulate_battle(cfg: Dictionary, allies: Array, enemies: Array, rules: Dictionary = {}) -> Dictionary`
  - allies: 길이 6 배열(빈칸 null), 각 원소 = to_unit 결과
  - enemies: `Waves.generate_enemies` 결과 = `{"kind": "dragon"|"minion", "id": String, "elements": Array, "hp", "atk", "cooldownTicks", "speed", "lane", "x"}` 배열
  - 반환 `{"winner": "ally"|"enemy", "ticks": int, "events": Array, "units": Array}`
  - units: spawn 정보 `{id, side, kind, ref("species/minion id"), slot(아군 드래곤·호위만, 아니면 -1), owner(호위만, 아니면 -1), lane, x, hp}`
  - events: `{"tick","kind":"attack","src","dst","dmg","mult","heal"}`, `{"tick","kind":"death","id","cause":"hit"|"owner"|"hazard"}`, `{"tick","kind":"hazard","name","id","dmg"}`, `{"tick","kind":"enrage"}`, `{"tick","kind":"pos","xs":{id: x},"lanes":{id: lane}}`(4틱마다, 바뀐 유닛만)
- battle.json에 추가: `"field": {"frontX":260,"backX":140,"laneGap":120,"meleeRange":40,"laneChangeRange":80,"laneChangeTicks":8,"posEveryTicks":4}`, `"escort": {"count":{"base":2,"t2":3,"t1":4,"dual":4,"secret":4},"hpPct":22,"atkPct":18,"cooldownTicks":12,"speed":6,"offsetX":50,"spacingX":12}`
- waves.json에 추가: `"squad": {"leaderSharePct":55,"minionBase":4,"minionMax":14,"leaderX":860,"extraLeaderX":900,"minionX":700,"minionSpacingX":30,"secondLeaderWave":8,"thirdLeaderWave":14}`
- minions.json: `{ "ember_kobold": {"id","nameKo","element":"fire","hp","atk","cooldownTicks","speed"}, ... }` 6종 (A3 카드의 id)

- [ ] **Step 1: 실패하는 테스트 작성** (`test_battle.gd`, `test_waves.gd`)
  - `test_back_row_only_dragon_still_finishes_battle`: 후열 3번 칸에 드래곤 1, 적 우두머리 1(x 900), 졸병 0 → winner가 정해지고 ticks < maxTicks
  - `test_melee_requires_same_lane_within_range`: 줄 0 호위와 줄 1 졸병, x 차이 30 → 첫 공격 전에 lane 변경 pos 기록이 있음
  - `test_escorts_die_with_owner`: 주인 드래곤 death 직후 같은 tick에 그 호위들 death(cause "owner")
  - `test_escort_count_by_tier`: base 드래곤 → 호위 2, t1 → 4 (units에서 owner로 셈)
  - `test_dragon_targets_nearest_enemy`: 적 졸병(x 700)과 우두머리(x 860) → 아군 드래곤 첫 공격 dst = 졸병
  - `test_identical_input_produces_identical_events` (유지, 새 형식)
  - `test_hazard_burn_hits_lowest_hp_dragon_only`, `test_row_blast_hits_row_dragons_and_their_escorts`
  - 원소 배율·흡혈·haste·to_unit·beats 표 테스트는 유지
  - waves: `test_squad_minion_count_grows_and_caps_at_14`, `test_leader_count_by_wave`(1 / 8웨이브 2 / 14웨이브 3), `test_boss_first_leader_is_t1_of_boss_element`, `test_squad_total_power_within_ten_percent_of_target`
- [ ] **Step 2: 실행해서 실패 확인** — `npm run godot:test` → 새 테스트 실패
- [ ] **Step 3: 구현** — 스펙 4장 그대로. 매 틱 순서: 보스 규칙 → 이동(걷는 유닛, id 순) → 공격(아군 id 순, 그다음 적 id 순, 지금처럼 같은 틱 안 순차) → 죽음 처리(주인 죽음 시 호위 제거) → 승패 판정 → posEveryTicks마다 pos 기록. 표적: 거리 = |dx| + |dlane| × laneGap, 동률은 lane 작은 쪽 → id 작은 쪽.
- [ ] **Step 4: 통과 확인** — `npm run godot:test` 전부 통과 (run 테스트의 전투 기대값이 바뀌면 새 규칙 기준으로 갱신)
- [ ] **Step 5: 커밋** — `feat(godot): squad battle core (positions, escorts, minion squads)`

### Task 2: Godot 밸런스 시뮬레이터 + 수치 조정
**Files:**
- Create: `godot/tools/sim.gd` (SceneTree 스크립트, 인수 `--runs N --seed S [--demo] [--calamity C] [--first-wave]`)
- Modify: `package.json` 스크립트 `"sim"` → Godot 실행
- Modify: `data/battle.json`, `data/waves.json`, `data/minions.json` 수치

**Interfaces:**
- Consumes: `RunRules.start/dispatch`, Task 1 battle
- Produces: 출력 한 줄 요약 `runs=N clear=X% avgWave=Y wave1Win=Z%`

- [ ] **Step 1:** `tools/sim/bot.ts`의 판단 규칙(밀기 선택, 고르기, 합체, 배치 front/back)을 GDScript로 옮긴다. 배치: 근접형 구분이 없으므로 체력이 큰 드래곤을 전열에.
- [ ] **Step 2:** `npm run sim -- --runs 2000 --seed 1` 실행, 결과 확인
- [ ] **Step 3:** 수치 조정으로 목표 맞춤: 정식 클리어 40~50%, `--first-wave` 1웨이브 승률 ≥ 90%, `--demo` 재앙 0 클리어 65~75%
- [ ] **Step 4:** `npm run godot:test` 통과 후 커밋 — `feat(godot): headless balance sim; squad balance`

### Task 3: 창 크기 · 화면 폭 대응
**Files:**
- Modify: `project.godot` (aspect expand), `godot/ui/theme.gd` (AREA를 폭 함수로: `static func areas(width: float) -> Dictionary`), `godot/ui/game.gd` (뷰포트 크기 변경 시 다시 배치, F11 전체 화면), `godot/ui/title.gd` (가운데 정렬)
- Create: `godot/ui/window.gd` (PC 첫 실행 창 크기: 작업 영역 85%, 16:9, 가운데)

- [ ] **Step 1:** `test_build.gd`에 `test_areas_fit_width_1280_and_1600`: areas(1280)·areas(1600)에서 hud/field/bench/slab/offers 사각형이 화면 안이고 서로 겹치지 않음
- [ ] **Step 2:** 실패 확인 → 구현 → 통과
- [ ] **Step 3:** 캡처 도구로 1280×720·1600×720 화면 저장해 눈으로 확인 (`capture.gd`에 크기 인수 추가)
- [ ] **Step 4:** 커밋 — `feat(godot): resizable window, expand aspect, width-aware layout`

### Task 4: 전장 화면 (배치 + 전투 재생 + 배경)
**Files:**
- Create: `godot/ui/field_panel.gd` (nest_panel.gd의 끌어다 놓기·미리보기 로직 + battle_panel.gd의 재생을 합침)
- Modify: `godot/ui/game.gd` (nest_panel·battle_panel 대신 field_panel + bench_panel)
- Create: `godot/ui/bench_panel.gd` (대기칸 2×2, 아래 띠 왼쪽)
- Delete: `godot/ui/nest_panel.gd`, `godot/ui/battle_panel.gd` (옮긴 뒤)
- Test: `godot/tests/test_controller.gd`에 끌어다 놓기 명령 테스트 유지/갱신

**Interfaces:**
- Consumes: Task 1 events/units, Task 3 areas, A3 그림(`assets/backgrounds/*.png`, `assets/minions/<id>.png`; 없으면 원소 색 원으로 대체)
- field_panel 신호: `finished` (전투 재생 끝)

- [ ] **Step 1:** 발판 6개(전열 x 260 / 후열 x 140을 화면 좌표로 변환), 놓아주기 칸(왼쪽 아래), 전투 시작 버튼(오른쪽 아래). 대기칸 ↔ 발판 끌기, 합체·흡수 미리보기.
- [ ] **Step 2:** 재생: units로 스프라이트 생성(드래곤 96px, 호위 52px, 졸병 48px), pos 보간 이동, 숨결 투사체·근접 찌르기, 맞을 때 체력바, 죽음 페이드, 배속·건너뛰기.
- [ ] **Step 3:** 웨이브 구간별 배경.
- [ ] **Step 4:** 캡처로 정리 단계·전투 중·전투 끝 화면 확인. 테스트 통과 후 커밋 — `feat(godot): battlefield placement and squad playback`

### Task 5: 아래 띠 석판 + 굴림 애니메이션
**Files:**
- Modify: `godot/ui/slot_panel.gd` (아래 띠 가운데 석판, 오른쪽 알 카드 3장 가로 + 안내 + 돌리기)
- Create: `godot/ui/reel.gd` (열 하나의 굴림: 잘린 영역 안 그림 띠 스크롤, 감속, 튕김)

- [ ] **Step 1:** 스펙 5.4: 0.6초 뒤 1열 정지, 0.18초 간격, 튕김·확대, 맞은 줄 순서대로 빛남, 탭하면 즉시 결과.
- [ ] **Step 2:** 굴림 중 돌리기·밀기·고르기 버튼 막기(애니메이션 끝 또는 건너뛰기 뒤 활성).
- [ ] **Step 3:** 캡처 도구에 "spin-mid" 모드(굴림 중간 프레임) 추가해 확인. 커밋 — `feat(godot): reel spin animation and bottom strip`

### Task 6: 튜토리얼 · 문구 · 규칙 문서
**Files:**
- Modify: `godot/ui/tutorial.gd` (새 위치), 화면 문구 윤문(humanize-korean)
- Modify: `CLAUDE.md`, `AGENTS.md` (Godot만 기준, parity 은퇴, sim 명령)
- [ ] 캡처로 튜토리얼 5단계 확인, 커밋 — `docs+ui: tutorial for battlefield layout; Godot-only rules`

### Task 7: 마무리 검증
- [ ] 코덱스 독립 검토(읽기 전용, `git diff <시작>..HEAD`), 지적 확인·수정
- [ ] `npm run godot:export`, `npm run godot:apk`, 에뮬레이터에서 1판 진행 캡처
- [ ] 개발 일지 `docs/devlog/` 한 편
