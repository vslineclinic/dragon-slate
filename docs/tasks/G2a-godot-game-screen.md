# 작업 카드 G2a: Godot 게임 화면 (HUD·석판·둥지·전투)

먼저 `AGENTS.md`, `docs/superpowers/plans/2026-11-23-godot-transition.md`를 읽어요. G1에서 만든 `godot/core/*.gd`를 써요.

## 목표
웹판 게임 화면(`packages/view/src/scenes/GameScene.ts`, `panels/*.ts`)을 Godot로 옮겨요. 배치·문구·동작은 웹판과 같게. 화면은 **코드로 만든 Control 노드**로 구성해요(.tscn은 최소).

## 고칠 파일 (새로 만듦)
- `godot/ui/controller.gd` (`class_name GameController extends RefCounted`): `data`, `state`, `busy`, `signal changed(events: Array, state: Dictionary)`, `dispatch(cmd: Dictionary) -> Array`, `restart(seed: int, calamity := -1)`. 웹판 `controller.ts`와 같은 동작.
- `godot/ui/theme.gd`: 웹판 `layout.ts`의 영역(AREA)·색(COLOR, 6원소+gold+wild)·라벨(SYMBOL_LABEL, ELEMENT_KO, TIER_KO)·UI 색. 글꼴은 `SystemFont`(font_names: "Malgun Gothic", "Noto Sans KR", "Apple SD Gothic Neo")로 한글 표시.
- `godot/ui/marks.gd`: 웹판 `fx/icons.ts`의 원소 문양(불·얼음·번개·독·강철·심연·금·여의주)과 알 모양을 `_draw()`로 그리는 Control.
- `godot/ui/hud.gd`, `godot/ui/slot_panel.gd`, `godot/ui/nest_panel.gd`, `godot/ui/battle_panel.gd`: 웹판 Hud·SlotPanel·NestPanel·BattlePanel과 같은 기능(석판 알·밀기 버튼·줄 연결 표시·보라 띠·추천·보상 미리보기 문구 / 둥지·대기칸 끌어 놓기·합치기 미리보기·놓아주기·합체 가능 표시 / 전투 재생·배속·건너뛰기·히트 연출·기믹 자막). 드래곤 그림은 `res://assets/dragons/<id>.png`, 없으면 문양.
- `godot/ui/game.gd` + `godot/scenes/game.tscn`: 위 패널을 붙이고 이벤트를 연결(보너스 알림, 새로 발견 배너, 보상 상자, 보스 예보, 결과는 G2b).
- 발견 기록·설정 저장: `user://wyrmslot.cfg`(ConfigFile) — `godot/ui/store.gd`.

## 건드리면 안 되는 파일
`packages/**`, `data/**`, `godot/core/**`(버그 수정만, 결과에 적기), `godot/tests/fixtures/**`, `package.json`

## 완료 기준
- Godot 테스트 "실패 0개" 유지, `--headless --quit` 로 프로젝트를 열었을 때 스크립트 오류 0.
- `godot/tests/test_controller.gd`: 컨트롤러로 spin→pick→move→startBattle 흐름이 웹판 규칙대로(거절 이유 포함) 동작.
- 화면 확인은 지휘자가 해요(샌드박스에서 창을 못 띄움).

## 결과 보고
바꾼 파일, 테스트 출력, 웹판과 다르게 한 곳과 이유.
