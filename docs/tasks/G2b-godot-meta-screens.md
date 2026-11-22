# 작업 카드 G2b: Godot 시작·도감·결과·안내 화면

먼저 `AGENTS.md`와 G2a 결과물(`godot/ui/*`)을 읽어요.

## 목표
웹판 `TitleScene.ts`, `panels/DexOverlay.ts`, `panels/ResultOverlay.ts`, `panels/Tutorial.ts`, `scenes/GameScene.ts`의 보상 상자를 Godot로 옮겨요.

## 고칠 파일
- 새로: `godot/ui/title.gd`(+ `godot/scenes/main.tscn`를 시작 화면으로 교체), `godot/ui/dex_overlay.gd`(원소별/이중·숨은 탭, 실루엣·힌트·설명, 숨은 종 "?"), `godot/ui/result_overlay.gd`(데모 문구 포함), `godot/ui/tutorial.gd`(첫 판 말풍선 5단계, 건너뛰기), `godot/ui/build.gd`(데모 설정: `OS.has_feature("demo")`이면 10웨이브·재앙 최대 1·마지막 보스 ×465 — 웹판 `build.ts`와 같은 값).
- 고침: `godot/ui/game.gd`(결과·안내·보상 연결), `godot/ui/store.gd`(재앙 해금 `next_unlocked` — 웹판 `calamity-store.ts`와 같은 규칙).
- 테스트: `godot/tests/test_unlock.gd`(웹판 unlock 테스트와 같은 3개), `godot/tests/test_build.gd`(데모 덮어쓰기 값).

## 건드리면 안 되는 파일
`packages/**`, `data/**`, `godot/core/**`, `godot/tests/fixtures/**`, `package.json`

## 완료 기준
Godot 테스트 "실패 0개", `--headless --quit`로 열 때 오류 0. 화면 확인은 지휘자가 해요.
