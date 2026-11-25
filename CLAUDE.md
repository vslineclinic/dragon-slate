# Dragon Slate (드래곤 룬 석판 로그라이트, 예전 이름 Wyrmslot)

게임 이름은 2026-11-25부터 **Dragon Slate**(사용자 결정). 저장 파일 이름(`user://wyrmslot*.cfg`)과 안드로이드 패키지 id(`com.wyrmslot.game`)는 옛 이름 그대로 둔다(바꾸면 저장 · 설치가 끊긴다). 옛 저장 폴더는 `Store.carry_over_old_saves`가 한 번 복사해 온다.

설계: `docs/superpowers/specs/2026-11-23-wyrmslot-design.md` · 현재 계획: `docs/superpowers/plans/2026-11-23-phase0-prototype.md`

## 명령
- Godot(기준): `npm run godot:test` · `npm run sim -- --runs 300 --seed 1000 [--demo] [--calamity 1] [--waves] [--margin] [--set waves.basePower=190] [--standard] [--start | --start-index N] [--each]`(40웨이브 한 판에 약 20초라 여러 묶음을 동시에 돌린다) · `npm run godot:export` (Windows 정식·데모) · `npm run godot:apk` (Android 테스트 APK)
- 화면 확인: `godot --audio-driver Dummy --path . --position -4000,-4000 --script res://godot/tests/capture.gd -- <장면> <png> [spin|spinmid|manage|battle|battle-late] [폭]`
- 배경음악: `python tools/music/make_tracks.py`(A 모음) · `python tools/music/codex_tracks.py`(B 모음) → ffmpeg로 `assets/music/a|b/*.ogg`. 재생·전환은 `godot/ui/music.gd`.
- 배경·UI 그림: `python tools/art/gen_backgrounds.py [이름...]` → `assets/backgrounds/*.png`, `assets/ui/*.png` (코드로 그림, 그림 생성 AI 안 씀). 바꾼 뒤 `godot --headless --path . --import`.
- 웹판(멈춤, 참고용): `npm run dev` · `npm test` · `npm run typecheck`

## 불변 규칙
- `packages/core/**`에서는 `phaser`, `document`, `window`, `localStorage`, `Math.random`, `Date.now`, `performance.now`, `Math.sin|cos|tan|pow|exp|log|sqrt`를 쓰지 않는다. 난수는 `Rng`만 쓴다.
- core 수치는 정수, 배율은 백분율 정수, 나눗셈은 `Math.floor`.
- 수치는 `data/*.json`에서 읽는다. 코드 상수는 판 구조값(3×3, 둥지 6, 대기칸 4)뿐.
- TypeScript는 지울 수 있는 문법만(enum·namespace·생성자 매개변수 속성 금지), import 경로에 `.ts` 확장자.
- 원소 fire > ice > lightning > fire, 강 135% / 약 75%.
- 화면 문구 한국어. 금지어: 잭팟, JACKPOT, 코인, 베팅, 칩, 각인, 코어. 대신 줄 맞춤, 마력, 룬 석판, 계승 특성.
- 화면에서는 "용"이라 쓰지 않고 "드래곤"이라 쓴다(2026-11-25, 사용자 요청). 용암 · 용사 같은 다른 낱말과 종 이름의 "~룡"은 그대로.
- 성장 구조(2026-11-23 2차): 40웨이브, 원소별 계급 피라미드(기본 4 · 2티어 3 · 1티어 2 · 정점 1), 용 레벨(전투·흡수로 경험치, 레벨 업마다 스킬 점수 1), 진화는 레벨 5/10/15부터, 보스마다 유물 3택 1. 수치는 `data/battle.json`의 level, `data/relics.json`, `data/waves.json`의 growthBands·bossPct.
- 3차(2026-11-24): 갈림길(waves.fork), 중간 보스(waves.elitePct), 기본 용 원소별 12종(`node tools/gen-upper-dragons.cjs`가 조합표까지 다시 만듦), 궁극기(battle.ultimate). 설계 문서 13·14장.
- 화풍 "용 신전"(2026-11-24, 설계 문서 16장): 흑요석 판 · 금박 선 · 양피지색 글자. 색·판·단추·제목은 `godot/ui/theme.gd`의 도우미(panel · frame · well · heading · cta · divider · glow)로만 만든다. 화면 파일에 색 코드를 새로 박지 않는다. 제목은 명조(Noto Serif KR), 본문은 고딕(Noto Sans KR).
- 스킬은 별자리 3개 × 별 4개(`data/skills.json` 12개). 도감은 원소별 세계수(가지 = 같은 용 둘을 합친 결과).
- 화면 배치(2026-11-24 개정, 사용자 요청): 왼쪽 316px 조작 패널(안내 → 내 룬 장수 → 석판 → 알 카드 3장 → 돌리기/전투 시작), 나머지는 전장. 대기칸 4칸과 놓아주기 칸은 전장 맨 아래 띠. 위치 값은 `godot/ui/theme.gd`의 `LEFT_W` · `SLAB_TOP` · `OFFER_TOP` · `SPIN_TOP` · `BENCH_Y` · `LANE_Y`와 `areas()`에만 둔다.
- 방향 B(2026-11-24, 사용자 결정): 석판 짜기 + 용 계보 + 줄 전투. 설계와 남은 순서는 `docs/superpowers/specs/2026-11-24-direction-b-design.md`. 기준은 "플레이어가 정한 것이 결과를 바꾼다". 수치만 올리는 유물·새 종·비밀 조합 추가는 얼려 둔다.
- 줄 전투(2026-11-24): 드래곤은 제 줄을 지키며 사거리까지 걸어가 쏜다. 제 줄 100% · 옆줄 75% · 건너편 50%(`battle.field.crossLanePct`, 궁극기는 감쇠 없음). 적이 몰리는 줄은 `waves.squad.lanePatterns`와 판 씨앗으로 정해지고 전투 전에 미리 보여 준다(`Waves.lane_preview`는 실제 편성과 같아야 한다 — 시험으로 고정).
- 전환의 룬(2026-11-24): 같은 등급·같은 형태의 다른 원소 용으로 바꾼다. 실패해도 용은 그대로이고 다음 시도는 반드시 성공한다(`waves.transmute`). 원소별 용 목록은 자료 순서가 형태 순서와 같아야 한다(`dragons.json`에 종을 넣을 때 여섯 원소를 같은 순서로).
- 내 석판(2026-11-24): 석판의 칸은 내 룬 묶음(`state.slab`, 시작은 `slot.slab.start`)에서 고르게 뽑는다. 보상 "룬 한 장"으로 묶음의 룬 하나를 바꾼다(차례 `slab`, 명령 `replaceRune`·`skipRune`). `slot.weights`는 묶음이 없는 옛 저장과 기준 자료 시험에만 쓴다. 새 판은 시작 묶음(원소 셋 중 하나 + 그 원소 용 한 마리, `Run.start_options`)을 고르고 시작한다. 화면을 자동으로 조작하는 도구는 시작 화면을 닫아야 한다(`_start_open`, capture.gd 참고).
- 역할(2026-11-24): 화면에서는 front · back · support를 **수호 · 사수 · 지원**이라 부른다(`GameTheme.ROLE_KO`, 전열·후열은 놓는 자리 이름). 사수는 줄 감쇠가 100 · 90 · 75이고 사거리 +80(`battle.field.roleLanePct` · `roleRangeAdd`).
- 계보 선택(2026-11-24): 진화 후보가 둘이면 고른다. 첫째는 조합표의 결과, 둘째는 받는 쪽 드래곤의 역할을 잇는 종(`Fusion.merge_options`, `merge` 명령의 `choice`). 조합표의 첫째 결과는 바꾸지 않는다.
- 형태별 능력(2026-11-24): 꿰뚫기 · 연속 공격 · 돌봄 · 방패막 · 맞대결 · 선봉 · 저격 · 함성, 그리고 신화 이름 용 30종의 신화의 숨결(`species` 목록으로 붙음). `battle.abilities`의 `forms`(종 id에서 원소 머리말을 뗀 형태 이름)로 붙고 보통 공격에만 든다. 새 능력은 `Battle.simulate_battle`의 strikes · `_warded` · `_most_hurt` 옆에 넣고 `test_ability.gd`에 시험을 쓴다.
- 지역(2026-11-25): 지역 넷 × 20웨이브(`data/stages.json`, `Build.for_stage`). 지역을 깨면 용 한 마리를 다음 지역으로 데려간다(종 · 계승 특성만, 레벨 1). 봇 클리어율 목표는 지역마다 약 15%(사용자 결정). 측정: `npm run sim -- --stage N --start [--carry 종id]`.
- 호위병(2026-11-25): 기본 0마리. 스킬 "무리 부름"으로 1마리, 모든 출처를 합쳐 용 한 마리당 최대 2마리(`battle.escort.max`).
- 마력을 쓸 곳(2026-11-25, 사용자 결정): 보스 뒤 상점(`waves.shop.stock`, 차례 `shop`, 명령 `buy` · `leaveShop`), 밀기 추가 구매(`slot.nudgeBuy`), 보상 다시 뽑기(`waves.rewardReroll`, 명령 `rerollRewards`). 갈림길의 떠돌이 상인은 상점을 한 번 더 여는 길이다. 상점 진열은 판 난수와 따로 뽑는다(판 씨앗 · 웨이브 · 들른 횟수). 이자와 경험치 사기는 만들지 않는다. 설계 문서 2.19절, 시험 `test_shop.gd`.
- 전투는 `Battle.begin_battle` → `step_battle` → `battle_result`로 한 틱씩 돈다(`simulate_battle`은 이것을 끝까지 돌린 것). 수동 궁극기 전투는 화면이 직접 돌리고 쏜 틱을 `startBattle`의 `ults`로 보낸다. 전투 규칙을 고치면 `test_stepper.gd`의 "한 번에 = 한 틱씩"과 "기록으로 다시 계산" 시험이 통과해야 한다.
- 원정 길이(2026-11-24): 기본 원정 20웨이브(`waves.standard`로 덮어씀, `Build.for_length`)와 긴 원정 40웨이브. 봇 측정은 `--standard`를 붙여 잰다. 수치를 고칠 때 두 길이를 따로 본다.
- 자동 저장(2026-11-24): 하던 판은 `user://run.json`. 규칙·자료가 바뀌어 옛 저장을 이을 수 없으면 `Store.RUN_VERSION`을 올린다. 게임 장면을 띄우는 도구는 반드시 `Store.autosave_off`를 켠다(사용자의 저장을 덮어쓰지 않게).
- 용의 공격 동작은 그림 한 장을 셰이더로 휘어 만든다(`godot/ui/dragon_pose.gdshader`, `dragon_sprite.gd`). 용 그림은 왼쪽을 보고 머리가 왼쪽 위에 오게 그린다. 숨결 모양은 `godot/ui/breath_fx.gd`.

## 레인 소유권 (설계 8.1)
| Claude | Codex (`C:\claude\dragon-game-codex`, 브랜치 `codex/*`) |
|---|---|
| `packages/core/src` 규칙, `packages/view`, `data/*.json` 최종 수치, 계약(`packages/core/src/contracts/`) | `tools/sim`, `tools/lint-data`, 테스트 보강, 데이터 초안, `apps/desktop`, `apps/mobile`, 저장·빌드 스크립트 |

코덱스 결과는 테스트 + diff 검토 뒤에만 main에 병합. 작업 카드: `docs/tasks/`. 개발 일지: `docs/devlog/`.

## 업무 분담 개정 (2026-11-23, 설계 문서 8장)
- Claude = 지휘자: 계약·작업 카드·검토(테스트 재실행, diff 읽기, 실행 확인)·병합·밸런스 결정·문서. 직접 구현은 작은 연결 작업과 눈으로 봐야 하는 화면 다듬기만.
- Codex = 주 구현자: 카드 단위 구현(규칙 이식, 도구, 데이터, 그림, 문구, 포장, 화면 초안)과 독립 검수.
- 코덱스 호출: `C:\claude\ai-team\Invoke-Worker.ps1 -Worker codex -Mode build -WorkDir C:\claude\dragon-game-codex` (맡기기 전 작업본 커밋, 묶음 사이 커밋).

## Godot 전환 (2026-11-23, 설계 문서 8.2)
- 렌더러는 PC·모바일 모두 Compatibility(OpenGL)(2026-11-24): Intel 내장 그래픽에서 Vulkan·D3D12는 드라이버가 약 570MB를 더 잡았다. 메모리 측정은 `godot --audio-driver Dummy --path . --position -4000,-4000 --script res://godot/tests/memprobe.gd -- <웨이브 수>`.
- Godot 4.7.2 + GDScript, 실행 파일 `C:\claude\tools\godot\Godot_v4.7.2-stable_win64_console.exe`.
- `project.godot`는 저장소 맨 위. 규칙 이식은 `godot/core/`, 테스트는 `godot/tests/` (실행: `godot --headless --path . --script res://godot/tests/run_tests.gd`).
- **2026-11-23부터 Godot판만 개발**(사용자 결정). 웹판(packages/*, apps/web, tools/sim, tools/parity)은 고치지 않음. run 일치 검사는 은퇴, rng·slot 일치 기준 자료(`godot/tests/fixtures/`)는 유지.
- 부대 전투 설계: `docs/superpowers/specs/2026-11-23-squad-battlefield-design.md` · 계획: `docs/superpowers/plans/2026-11-23-squad-battlefield.md`
