# Dragon Slate(예전 이름 Wyrmslot) — Codex 작업 규칙

설계: `docs/superpowers/specs/2026-11-23-wyrmslot-design.md` · 계획: `docs/superpowers/plans/2026-11-23-phase0-prototype.md` · 작업 카드: `docs/tasks/`

## 반드시
- 작업 카드의 "고칠 파일"만 만든다/고친다. "건드리면 안 되는 파일"은 읽기만 한다.
- 계약 파일(`packages/core/src/contracts/**`)은 고치지 않는다. 바꿔야 하면 결과 끝에 `## 계약 변경 요청`으로 적는다.
- 의존성을 추가하지 않는다(네트워크 없음). `package.json`을 고치지 않는다. 필요한 패키지는 결과에 적는다.
- git commit·reset·push를 하지 않는다. 커밋은 지휘자가 한다.
- 끝나면 `npm test`와 `npm run typecheck` 출력 꼬리를 결과에 붙인다.

## 코드 규칙
- `packages/core/**`: `phaser`, `document`, `window`, `localStorage`, `Math.random`, `Date.now`, `performance.now`, `Math.sin|cos|tan|pow|exp|log|sqrt` 금지. 정수 계산, 백분율 정수, `Math.floor`.
- TypeScript는 지울 수 있는 문법만(enum·namespace·생성자 매개변수 속성 금지). import 경로에 `.ts` 확장자. 도구는 `node tools/.../x.ts`로 바로 실행된다(Node 26 타입 제거).
- 테스트는 Vitest(`*.test.ts`).

## Godot 작업 규칙 (2026-11-23)
- GDScript는 Godot 4.7 문법, 정적 타입 표기(`var x: int`)를 써요. 규칙 코드(`godot/core/`)는 Node·장면·`randi()`·`Time`을 쓰지 않아요(RefCounted 클래스만). 난수는 `godot/core/rng.gd`만.
- 정수 나눗셈은 TypeScript의 `Math.floor(a / b)`와 같아야 해요. 음수가 나올 수 있으면 `Rng.fdiv(a, b)`를 써요. 32비트 곱셈은 `Rng.imul(a, b)`.
- 테스트는 `godot/tests/test_*.gd`(함수 이름 `test_`로 시작), 실행은 `C:\claude\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://godot/tests/run_tests.gd`. 실패가 하나라도 있으면 종료 코드 1.
- 일치 검사 기준 자료(`godot/tests/fixtures/*.json`)는 고치지 않아요. 다르면 GDScript 쪽을 고쳐요.
