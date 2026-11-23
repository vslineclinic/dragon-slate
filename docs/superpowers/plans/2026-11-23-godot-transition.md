# Godot 전환 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 웹판(TypeScript+Phaser)과 같은 게임을 Godot 4.7.2 + GDScript로 옮긴다. 규칙은 비트 단위로 같아야 한다.

**Architecture:** 저장소 맨 위 `project.godot`. 규칙 `godot/core/*.gd`(RefCounted, 상태·이벤트는 TypeScript JSON과 같은 키의 Dictionary/Array), 화면 `godot/scenes/`·`godot/ui/`. 일치 검사는 TypeScript가 만든 `godot/tests/fixtures/runs.json`(시드 3개 × 명령 80개의 이벤트·상태)을 GDScript가 그대로 재현하는지로 판정.

**Spec:** `docs/superpowers/specs/2026-11-23-wyrmslot-design.md` 8.1·8.2

## 결정 사항
- 상태·이벤트 모양: TypeScript `RunState`(log 제외)·`GameEvent`와 **같은 키, 같은 값**. 숫자는 int. 없는 값은 null.
- 모듈 대응: `rng.ts→rng.gd`(완료), `data.ts→data.gd`, `slot.ts→slot.gd`, `fusion.ts→fusion.gd`, `battle.ts→battle.gd`, `waves.ts→waves.gd`, `calamity.ts→calamity.gd`, `hints.ts→hints.gd`, `run.ts→run.gd`. 함수 이름은 snake_case(`apply_command`, `create_run`, `spin_cost` …), 반환은 `{ "state": ..., "events": [...] }`.
- 데이터 로드: `res://data/*.json`을 `GameData.load_all()`이 읽어 Dictionary로(dragons/traits는 id 맵).
- 정렬·순회 순서가 결과를 바꾸는 곳(종 목록 정렬, 가중치 뽑기 순서)은 TypeScript와 똑같이.
- 문자열 비교 정렬은 TypeScript의 `<` 비교(코드 단위)와 같게: GDScript `String` 비교(`<`)는 유니코드 코드포인트 순이라 id(영문 소문자·밑줄)에서는 같다.

## 작업
- [x] **G0 (Claude):** 프로젝트 뼈대, `.gdignore`, 테스트 실행기, `rng.gd` + 일치 테스트, 기준 자료 생성기(`npm run parity`).
- [ ] **G1a (Codex):** `data.gd`, `slot.gd`, `fusion.gd`, `battle.gd`, `waves.gd`, `calamity.gd` + 단위 테스트(TypeScript 테스트를 옮겨서).
- [ ] **G1b (Codex):** `hints.gd`, `run.gd` + `test_parity_runs.gd`(runs.json 3판 전부 이벤트·상태 일치).
- [ ] **G2 (Codex 초안 → Claude 다듬기):** 화면 — 메인(시작 화면), 게임 화면(HUD·석판·둥지·전투 재생), 도감, 결과, 안내. 웹판 배치·문구를 그대로 따름.
- [ ] **G3:** Windows 내보내기(내보내기 템플릿 1.3GB는 그때 사용자 확인 후 받기), 스팀용 폴더.
- [ ] **G4:** 안드로이드·iOS 내보내기.

## 주의
- 6원소 데이터(X7) 병합 후 `npm run parity`로 기준 자료를 다시 만들어야 한다.
- 웹판은 Godot판이 G2를 마칠 때까지 기준판으로 유지.

## 진행 상황 (2026-11-23)
- G3 완료: `export_presets.cfg`(Windows / Windows Demo), `npm run godot:export` → `release-godot/Wyrmslot.exe`, `release-godot-demo/Wyrmslot Demo.exe`(각 약 120MB, pck 내장). 내보낸 실행 파일로 타이틀 화면이 뜨고 데이터·그림·글꼴을 읽는 것을 확인함.
- 글꼴: Noto Sans KR(OFL, `godot/fonts/`)을 넣었고 굵기 500. 한글은 띄어쓰기에서만 줄을 바꿈(`GameTheme.keep_words`).
- 내보내기 템플릿 4.7.2(공식 SHA512 확인)은 `%APPDATA%/Godot/export_templates/4.7.2.stable/`에 Windows x86_64·Android만 설치함.
- G4(모바일) 전에 필요한 것: Android SDK·JDK 설치, 릴리스 서명 키(사용자 보관).
- G4 1차(Android 테스트 APK): JDK 17(Temurin 17.0.21.1, `C:/claude/tools/jdk`), Android SDK(`C:/claude/tools/android-sdk`: platform-tools, build-tools 35.0.1, android-35, 사용자가 SDK 약관 동의, 사용 기록 수집 끔)를 설치함. Gradle 빌드를 안 쓰니 NDK·CMake는 받지 않음.
  - `npm run godot:apk` → `release-godot-android/Wyrmslot-debug.apk`(약 39MB, arm64, 가로, targetSdk 36, 디버그 키 서명). 프로젝트 설정에 ETC2/ASTC 텍스처를 켜고 임시 아이콘(yinglong)을 넣음.
  - 아직 안 한 것: 실제 휴대폰·에뮬레이터 실행 확인, 세로로 긴 화면의 좌우 여백(지금은 1280×720 비율 고정), 스토어용 릴리스 서명 키(사용자가 만들어 보관), Play용 AAB(Gradle 빌드 필요).
