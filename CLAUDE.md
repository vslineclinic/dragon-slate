# Wyrmslot (드래곤 룬 석판 로그라이트)

설계: `docs/superpowers/specs/2026-11-23-wyrmslot-design.md` · 현재 계획: `docs/superpowers/plans/2026-11-23-phase0-prototype.md`

## 명령
- `npm run dev` 브라우저 플레이(5173) · `npm test` · `npm run typecheck` · `npm run lint:data` · `npm run sim -- --runs 10000 --seed 1` · `npm run build`

## 불변 규칙
- `packages/core/**`에서는 `phaser`, `document`, `window`, `localStorage`, `Math.random`, `Date.now`, `performance.now`, `Math.sin|cos|tan|pow|exp|log|sqrt`를 쓰지 않는다. 난수는 `Rng`만 쓴다.
- core 수치는 정수, 배율은 백분율 정수, 나눗셈은 `Math.floor`.
- 수치는 `data/*.json`에서 읽는다. 코드 상수는 판 구조값(3×3, 둥지 6, 대기칸 4)뿐.
- TypeScript는 지울 수 있는 문법만(enum·namespace·생성자 매개변수 속성 금지), import 경로에 `.ts` 확장자.
- 원소 fire > ice > lightning > fire, 강 135% / 약 75%.
- 화면 문구 한국어. 금지어: 잭팟, JACKPOT, 코인, 베팅, 칩, 각인, 코어. 대신 줄 맞춤, 마력, 룬 석판, 계승 특성.
- 화면 배치: 위 전투, 아래 왼쪽 둥지·대기칸, 아래 오른쪽 석판.

## 레인 소유권 (설계 8.1)
| Claude | Codex (`C:\claude\dragon-game-codex`, 브랜치 `codex/*`) |
|---|---|
| `packages/core/src` 규칙, `packages/view`, `data/*.json` 최종 수치, 계약(`packages/core/src/contracts/`) | `tools/sim`, `tools/lint-data`, 테스트 보강, 데이터 초안, `apps/desktop`, `apps/mobile`, 저장·빌드 스크립트 |

코덱스 결과는 테스트 + diff 검토 뒤에만 main에 병합. 작업 카드: `docs/tasks/`. 개발 일지: `docs/devlog/`.
