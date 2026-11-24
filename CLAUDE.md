# Wyrmslot (드래곤 룬 석판 로그라이트)

설계: `docs/superpowers/specs/2026-11-23-wyrmslot-design.md` · 현재 계획: `docs/superpowers/plans/2026-11-23-phase0-prototype.md`

## 명령
- Godot(기준): `npm run godot:test` · `npm run sim -- --runs 300 --seed 1000 [--demo] [--calamity 1] [--waves] [--margin]` · `npm run godot:export` (Windows 정식·데모) · `npm run godot:apk` (Android 테스트 APK)
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
- 성장 구조(2026-11-23 2차): 40웨이브, 원소별 계급 피라미드(기본 4 · 2티어 3 · 1티어 2 · 정점 1), 용 레벨(전투·흡수로 경험치, 레벨 업마다 스킬 점수 1), 진화는 레벨 5/10/15부터, 보스마다 유물 3택 1. 수치는 `data/battle.json`의 level, `data/relics.json`, `data/waves.json`의 growthBands·bossPct.
- 3차(2026-11-24): 갈림길(waves.fork), 중간 보스(waves.elitePct), 기본 용 원소별 12종(`node tools/gen-upper-dragons.cjs`가 조합표까지 다시 만듦), 궁극기(battle.ultimate). 설계 문서 13·14장.
- 화풍 "용 신전"(2026-11-24, 설계 문서 16장): 흑요석 판 · 금박 선 · 양피지색 글자. 색·판·단추·제목은 `godot/ui/theme.gd`의 도우미(panel · frame · well · heading · cta · divider · glow)로만 만든다. 화면 파일에 색 코드를 새로 박지 않는다. 제목은 명조(Noto Serif KR), 본문은 고딕(Noto Sans KR).
- 스킬은 별자리 3개 × 별 4개(`data/skills.json` 12개). 도감은 원소별 세계수(가지 = 같은 용 둘을 합친 결과).
- 화면 배치(2026-11-23 개정): 왼쪽 약 34% 조작 패널(석판·알 카드·대기칸), 오른쪽 전장(둥지 발판 포함).

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
