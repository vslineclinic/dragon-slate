# 0단계 재미 검증 프로토타입 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 회색 네모로 된 브라우저 프로토타입을 만들어요. 석판 돌리기 → 알 고르기 → 합치기·배치 → 자동 전투를 10웨이브까지 플레이할 수 있어야 해요. 그리고 "5명 중 3명이 한 판 더"라는 0단계 통과 기준을 판정할 수 있는 상태까지 가요.

**Architecture:** `packages/core`는 순수 TypeScript 규칙 엔진이에요. 명령(command)을 받아 새 상태와 이벤트를 돌려주고, 시드 난수와 정수 계산만 써요. `packages/view`는 Phaser 4 화면이고, core의 이벤트를 받아 그리기만 해요. 밸런스 봇과 데이터 검사기는 Node에서 core를 그대로 불러 써요. 작업은 Claude 줄(C)과 Codex 줄(X)로 나눠 동시에 진행해요.

**Tech Stack:** Node 26(타입 제거로 `.ts` 직접 실행), TypeScript 7, Vite 8, Vitest 5, Phaser 4.2.x, npm(단일 package.json)

**Spec:** `docs/superpowers/specs/2026-11-23-wyrmslot-design.md` (특히 6장 게임 설계, 7장 기술, 8.1절 병렬 개발)

## Global Constraints

- `packages/core/**`에서는 `phaser`, `document`, `window`, `localStorage`, `Math.random`, `Date.now`, `performance.now`, `Math.sin|cos|tan|pow|exp|log|sqrt`를 쓰지 않는다. 난수는 `Rng`만 쓴다.
- core의 모든 수치는 정수다. 배율은 백분율 정수로 쓴다(예: 135). 나눗셈은 `Math.floor`.
- 수치는 `data/*.json`에서 읽는다. 코드에 상수로 박는 값은 판의 구조값(3×3, 칸 수 6, 대기칸 4)뿐이다.
- TypeScript는 지울 수 있는 문법만 쓴다(`erasableSyntaxOnly: true`: enum·namespace·생성자 매개변수 속성 금지). import 경로에 `.ts` 확장자를 붙인다.
- 원소는 `fire`, `ice`, `lightning` 3개다. 상성은 fire > ice > lightning > fire, 강하면 135%, 약하면 75%, 나머지는 100%다.
- 생명 5개. 일반 웨이브에서 지면 -1, 보스 웨이브에서 지면 -2, 0이면 게임오버다. 진 웨이브도 다음 웨이브로 넘어간다.
- 둥지 6칸(0~2 전열, 3~5 후열). 처음 3칸이 열려 있고 5·10·15웨이브가 끝나면 1칸씩 열린다. 대기칸은 4칸이다.
- 화면 기준 해상도는 1280×720 가로이고, 비율을 유지한 채 맞춘다(Phaser `Scale.FIT`). 누르는 요소는 최소 48×48px이다.
- 화면 문구는 한국어다. 금지어: "잭팟", "JACKPOT", "코인", "베팅", "칩", "각인", "코어". 대신 "줄 맞춤", "마력", "룬 석판", "계승 특성"을 쓴다.
- 화면 배치는 위쪽이 전투, 아래 왼쪽이 둥지·대기칸, 아래 오른쪽이 석판이다(Slotbound의 "왼쪽 슬롯·오른쪽 전투" 배치를 피한다).
- Codex 줄: `C:\claude\dragon-game-codex` 작업본에서만 쓴다. 의존성을 추가하지 않는다(작업본은 네트워크가 막혀 있다). 계약 파일(`packages/core/src/contracts/**`)은 고치지 않는다.

## Review Focus

1. **대기칸이 꽉 찬 상태에서 줄 맞춤 보너스 알이 생기는 경우**: 알을 잃지 않고 1개당 마력 +1로 바꾸고 이벤트로 알린다. → Task 8 테스트 `bonus eggs convert to mana when bench is full`
2. **둥지가 빈 채로 전투를 시작하는 경우**: `nestEmpty` 오류로 거절한다. → Task 8 테스트 `startBattle rejected when nest empty`
3. **애니메이션 중 연타(스핀·합치기 두 번 누르기)**: core는 단계가 맞지 않으면 거절하고, view는 재생 중 입력을 잠근다. → Task 8 테스트 `spin rejected during battle phase`, Task 9 수동 확인
4. **창 크기·비율 변경(19.5:9 폰, 16:10 스팀 덱)**: 잘리지 않고 여백(레터박스)으로 맞춘다. → Task 9 확인 단계
5. **마력이 모자란데 다시 돌리기**: `notEnoughMana`로 거절하고, 버튼에 비용과 비활성 상태를 보여 준다. → Task 8 테스트 `reroll rejected without mana`, Task 9 확인

---

## 줄(레인)과 순서

```
C1 뼈대 ─ C2 계약·난수 ─┬─ C4 석판 ─ C5 조합 ─ C6 전투 ─ C7 웨이브 ─ C8 판 진행 ─┬─ C9 화면·석판 ─ C10 둥지 ─ C11 전투 재생 ─ C12 타격감 ─ C13 시험 빌드
                        │                                                     │
                        └─ X1 데이터 초안·검사기·순수성 감사 (C4~C8과 동시)     └─ X2 밸런스 봇 (C9~C12와 동시)
C3 = 코덱스 작업 통로 준비 (C2 직후)
```

## 파일 구조

```
package.json, tsconfig.json, vite.config.ts, vitest.config.ts, .gitignore
CLAUDE.md, AGENTS.md
docs/tasks/_TEMPLATE.md, docs/tasks/X1-*.md, docs/tasks/X2-*.md
docs/devlog/YYYY-MM-DD.md, docs/playtest/phase0.md
data/dragons.json, recipes.json, traits.json, slot.json, waves.json, battle.json
data/fixtures/mini.json                # 테스트용 작은 데이터 (C2)
packages/core/src/contracts/types.ts   # 데이터·상태 타입 (C2, Claude만 수정)
packages/core/src/contracts/commands.ts
packages/core/src/contracts/events.ts
packages/core/src/rng.ts               # mulberry32 (C2)
packages/core/src/data.ts              # loadGameData (C2)
packages/core/src/slot.ts              # C4
packages/core/src/fusion.ts            # C5
packages/core/src/battle.ts            # C6
packages/core/src/waves.ts             # C7
packages/core/src/run.ts               # C8
packages/core/src/index.ts             # 공개 API 재수출
packages/core/test/*.test.ts
packages/core/test/purity.test.ts      # X1
tools/lint-data/lint.ts (+ test)       # X1
tools/sim/run.ts, tools/sim/bot.ts (+ test)  # X2
packages/view/src/main.ts, controller.ts, layout.ts
packages/view/src/scenes/GameScene.ts
packages/view/src/panels/SlotPanel.ts, NestPanel.ts, BattlePanel.ts, Hud.ts
packages/view/src/fx/juice.ts
packages/view/src/codex-store.ts       # 발견 기록(localStorage)
apps/web/index.html
```

---

### Task C1: 저장소와 도구 뼈대 (Claude)

**Files:**
- Create: `package.json`, `tsconfig.json`, `vite.config.ts`, `vitest.config.ts`, `.gitignore`, `CLAUDE.md`, `AGENTS.md`, `docs/tasks/_TEMPLATE.md`, `docs/devlog/2026-11-23.md`, `apps/web/index.html`, `packages/view/src/main.ts`, `packages/core/src/index.ts`, `packages/core/test/sanity.test.ts`

**Interfaces:**
- Produces: npm 스크립트 `dev`, `build`, `test`, `typecheck`, `lint:data`(→ `node tools/lint-data/lint.ts`), `sim`(→ `node tools/sim/run.ts`)

- [ ] **Step 1:** `git init -b main` 한다. `.gitignore`에는 `node_modules/`, `dist/`, `.vite/`, `*.log`를 넣는다.
- [ ] **Step 2:** `npm init -y` 후 `"type": "module"`, `"private": true`를 넣고 `npm i -D typescript@^7 vite@^8 vitest@^5 @types/node`, `npm i phaser@^4.2.1`를 설치한다.
- [ ] **Step 3:** `tsconfig.json`: `target ES2022`, `module ESNext`, `moduleResolution bundler`, `strict`, `noUncheckedIndexedAccess`, `erasableSyntaxOnly`, `allowImportingTsExtensions`, `noEmit`, `resolveJsonModule`, `include`에 `packages`, `tools`, `apps`.
- [ ] **Step 4:** `vite.config.ts`의 root는 `apps/web`, `vitest.config.ts`의 include는 `packages/**/test/**/*.test.ts`와 `tools/**/*.test.ts`.
- [ ] **Step 5:** `sanity.test.ts`에 `expect(1 + 1).toBe(2)`를 쓰고 `npm test`가 PASS인지 확인한다. `npm run dev`로 빈 Phaser 화면(배경색 `#1b1f2a`, 1280×720 FIT)이 뜨는지 브라우저 창에서 확인한다.
- [ ] **Step 6:** `CLAUDE.md`와 `AGENTS.md`에 Global Constraints 전문, 레인 소유권 표(설계 문서 8.1), 명령어 목록을 넣는다. AGENTS.md에는 "계약 변경이 필요하면 결과 끝에 `## 계약 변경 요청`으로 적고 직접 고치지 않는다", "의존성 추가 금지", "끝나면 `npm test`와 `npm run typecheck` 결과를 붙여 커밋한다"를 추가한다.
- [ ] **Step 7:** `docs/tasks/_TEMPLATE.md`를 만든다. 칸: 목표 / 고칠 파일 / 건드리면 안 되는 파일 / 참고할 계약 / 완료 기준(테스트 이름) / 실행할 명령 / 결과 보고 형식.
- [ ] **Step 8:** 커밋한다: `chore: scaffold wyrmslot prototype toolchain`

### Task C2: 계약·난수·데이터 로더 (Claude)

**Files:**
- Create: `packages/core/src/contracts/types.ts`, `commands.ts`, `events.ts`, `packages/core/src/rng.ts`, `packages/core/src/data.ts`, `data/fixtures/mini.json`
- Test: `packages/core/test/rng.test.ts`, `packages/core/test/data.test.ts`

**Interfaces (Produces — 모든 뒤 작업이 이 이름을 쓴다):**
```ts
// types.ts
export type Element = 'fire' | 'ice' | 'lightning';
export type SymbolId = Element | 'gold' | 'wild';
export type Tier = 'base' | 't2' | 't1' | 'dual' | 'secret';
export type Role = 'front' | 'back' | 'support';
export type TraitKind = 'atkPct' | 'hpPct' | 'hastePct' | 'lifestealPct';
export interface Stats { hp: number; atk: number; cooldownTicks: number }
export interface DragonSpec { id: string; nameKo: string; tier: Tier; elements: Element[]; role: Role; stats: Stats; traitId: string }
export interface TraitSpec { id: string; nameKo: string; kind: TraitKind; value: number }
export interface Recipe { a: string; b: string; result: string }
export interface SlotConfig { weights: Record<SymbolId, number>; pityThreshold: number; nudgesPerWave: number; rerollCosts: number[]; lineMana: number; goldMana: number; goldLineMana: number; wildLineMana: number; goldOfferMana: number }
export interface WaveConfig { maxWave: number; basePower: number; growthPct: number; bossPct: Record<string, number>; startLives: number; lossLife: number; bossLossLife: number; nestUnlockAfter: number[]; winMana: number; lossMana: number; startMana: number; releaseMana: Record<Tier, number> }
export interface BattleConfig { ticksPerSecond: number; maxTicks: number; strongPct: number; weakPct: number; absorbBonusPct: Record<Tier, number>; maxTraits: number }
export interface GameData { dragons: Record<string, DragonSpec>; traits: Record<string, TraitSpec>; recipes: Recipe[]; slot: SlotConfig; waves: WaveConfig; battle: BattleConfig }
export interface DragonInst { uid: number; speciesId: string; traits: string[]; bonusPct: number }
export type Zone = 'nest' | 'bench';
export interface SlotRef { zone: Zone; index: number }
export interface Cell { symbol: SymbolId; speciesId: string | null } // 원소·여의주 칸은 스핀 때 종이 정해짐, 황금은 null
export interface Grid { reels: Cell[][]; offsets: number[] }          // reels[col][0..4], 보이는 행 = 1+offset .. 3+offset
export type Offer = { kind: 'egg'; speciesId: string } | { kind: 'mana'; amount: number }
export type Phase = 'spin' | 'pick' | 'manage' | 'battle' | 'gameOver' | 'victory';
export interface RunState { seed: number; rngState: number; wave: number; phase: Phase; lives: number; mana: number; nest: (DragonInst | null)[]; nestOpen: number; bench: (DragonInst | null)[]; grid: Grid | null; spinsThisWave: number; nudgesLeft: number; pity: number; nextUid: number; discovered: string[]; log: Command[] }
```
```ts
// commands.ts
export type Command =
  | { type: 'spin' } | { type: 'nudge'; col: 0 | 1 | 2; dir: -1 | 1 } | { type: 'pick'; index: 0 | 1 | 2 }
  | { type: 'merge'; main: SlotRef; material: SlotRef } | { type: 'move'; from: SlotRef; to: SlotRef }
  | { type: 'release'; from: SlotRef } | { type: 'startBattle' };
export type RejectReason = 'wrongPhase' | 'notEnoughMana' | 'noNudgeLeft' | 'benchFull' | 'emptySlot' | 'slotLocked' | 'nestEmpty' | 'sameSlot';
```
```ts
// events.ts
export type GameEvent =
  | { t: 'spun'; grid: Grid; cost: number } | { t: 'nudged'; grid: Grid }
  | { t: 'lineHit'; lines: number[]; element: SymbolId }
  | { t: 'gained'; inst: DragonInst; to: SlotRef; via: 'pick' | 'bonus' }
  | { t: 'mana'; delta: number; reason: string }
  | { t: 'evolved'; inst: DragonInst; at: SlotRef; firstTime: boolean }
  | { t: 'absorbed'; inst: DragonInst; at: SlotRef; trait: string | null }
  | { t: 'battle'; result: BattleResult } | { t: 'lives'; lives: number }
  | { t: 'nestUnlocked'; open: number } | { t: 'waveStart'; wave: number; bossPreview: Element | null }
  | { t: 'gameOver' } | { t: 'victory' } | { t: 'rejected'; reason: RejectReason };
export type BattleEvent =
  | { tick: number; kind: 'attack'; side: 'ally' | 'enemy'; src: number; dst: number; dmg: number; mult: number; heal: number }
  | { tick: number; kind: 'death'; side: 'ally' | 'enemy'; idx: number };
export interface Unit { speciesId: string; elements: Element[]; hp: number; atk: number; cooldownTicks: number; lifestealPct: number }
export interface BattleResult { winner: 'ally' | 'enemy'; ticks: number; allies: (Unit | null)[]; enemies: (Unit | null)[]; events: BattleEvent[] }
```
```ts
// rng.ts
export interface Rng { nextU32(): number; nextInt(maxExclusive: number): number; pickWeighted<T>(items: readonly T[], weight: (t: T) => number): T; state(): number }
export function createRng(seed: number, state?: number): Rng
// data.ts
export function loadGameData(raw: { dragons: DragonSpec[]; traits: TraitSpec[]; recipes: Recipe[]; slot: SlotConfig; waves: WaveConfig; battle: BattleConfig }): GameData  // 배열을 id 맵으로 바꾸고, 참조가 없는 id가 있으면 throw
```

- [ ] **Step 1: 실패하는 테스트를 쓴다** (`rng.test.ts`)
  - `same seed gives same sequence`: `createRng(42)`를 두 번 만들어 `nextU32()` 1000번이 같다.
  - `state restore continues sequence`: 100번 뽑은 뒤 `createRng(42, r.state())`의 다음 값이 원래 Rng의 다음 값과 같다.
  - `nextInt stays in range`: 10,000번 `nextInt(6)`이 모두 0~5이고 6개 값이 다 나온다.
  - `pickWeighted follows weights`: 가중치 `[1, 3]`으로 40,000번 뽑으면 두 번째 비율이 0.72~0.78이다.
- [ ] **Step 2:** `npx vitest run packages/core/test/rng.test.ts` → FAIL(모듈 없음)을 확인한다.
- [ ] **Step 3:** `createRng`를 mulberry32(`Math.imul`, `>>> 0`)로 구현한다. `nextInt`는 `nextU32() % max`. 상태는 32비트 정수 하나다.
- [ ] **Step 4:** `data.test.ts`: `loads mini fixture`(용 수, 레시피 수 일치), `throws on unknown recipe id`, `throws on unknown traitId`. `data/fixtures/mini.json`에는 불 원소 base 2, t2 1, 특성 1, 레시피 1과 설정 객체들(아래 시작값)을 넣는다.
- [ ] **Step 5:** `loadGameData`를 구현하고 두 테스트 파일 PASS, `npm run typecheck` 통과를 확인한다.
- [ ] **Step 6:** 커밋한다: `feat(core): contracts, seeded rng, data loader`

**시작값(설정 객체, 픽스처와 X1 실데이터 공통):**
- slot: weights `{fire:26, ice:26, lightning:26, gold:13, wild:9}`, pityThreshold 4, nudgesPerWave 1, rerollCosts `[0,2,3,4,5,6]`(마지막 값 반복), lineMana 2, goldMana 1, goldLineMana 5, wildLineMana 3, goldOfferMana 3
- waves: maxWave 10, basePower 100, growthPct 118, bossPct `{"5":165,"10":180,"15":195,"20":230}`, startLives 5, lossLife 1, bossLossLife 2, nestUnlockAfter `[5,10,15]`, winMana 5, lossMana 3, startMana 3, releaseMana `{base:1,t2:2,t1:4,dual:4,secret:6}`
- battle: ticksPerSecond 20, maxTicks 1200, strongPct 135, weakPct 75, absorbBonusPct `{base:12,t2:25,t1:40,dual:40,secret:60}`, maxTraits 2

### Task C3: 코덱스 작업 통로 준비 (Claude)

**Files:**
- Create: `docs/tasks/X1-data-lint-purity.md`, `docs/tasks/X2-balance-bot.md` (X2는 C8 뒤에 내용 확정)

- [ ] **Step 1:** 작업본을 만든다: `git worktree add ..\dragon-game-codex -b codex/X1 main`, 그다음 작업본에서 `npm ci`(의존성은 Claude가 설치).
- [ ] **Step 2:** X1 카드를 템플릿으로 쓴다(내용은 Task X1). main에 커밋한 뒤 작업본에서 `git merge main`을 실행한다.
- [ ] **Step 3: 맡기기.** 코덱스 플러그인 경로를 `ls ~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs`로 찾는다(업데이트되면 버전 폴더가 바뀜). Bash `run_in_background`로 실행한다:
  `node "<경로>/codex-companion.mjs" task --write --cwd "C:\claude\dragon-game-codex" --prompt-file docs/tasks/X1-data-lint-purity.md`
  끝나면 알림이 온다. 기다리는 동안 C4를 진행한다.
- [ ] **Step 4: 받기.** 작업본에서 `npm test`, `npm run typecheck`, `npm run lint:data`를 돌린다. `git diff main...codex/X1`을 읽고, 금지 파일 변경과 의존성 추가가 없는지 확인한다. 통과하면 main에서 `git merge --no-ff codex/X1`을 실행하고 devlog에 한 줄 적는다. 실패하면 이유를 카드 끝에 덧붙여 최대 2회 다시 맡긴다.

### Task X1: 실데이터 22종·데이터 검사기·core 순수성 감사 (Codex 카드)

**Files:**
- Create: `data/dragons.json`, `data/recipes.json`, `data/traits.json`, `data/slot.json`, `data/waves.json`, `data/battle.json`, `tools/lint-data/lint.ts`, `tools/lint-data/lint.test.ts`, `tools/lint-data/fixtures/bad-*.json`, `packages/core/test/purity.test.ts`
- 금지: `packages/core/src/**`, `packages/view/**`, `package.json`

**Interfaces:**
- Consumes: C2의 `types.ts`, `loadGameData`
- Produces: `export function lintData(raw): string[]`(문제 목록, 비면 통과), `npm run lint:data`(문제가 있으면 exit 1)

**데이터 규칙 (카드에 그대로 옮김):**
- 22종 id와 레시피:
  - 화염: base `fire_drake`(A, front), `fire_wyvern`(B, back) / t2 `beowulf_firedrake`(A+A, front), `fafnir`(A+B, support), `xiuhcoatl`(B+B, back) / t1 `zhulong` = `fafnir`+`xiuhcoatl`
  - 빙결: `ice_drake`, `ice_wyvern` / `palraiyuk`(A+A), `north_black_dragon`(A+B), `azi_raoidita`(B+B) / `kuraokami` = `north_black_dragon`+`azi_raoidita`
  - 번개: `storm_drake`, `storm_wyvern` / `beisir`(A+A), `east_blue_dragon`(A+B), `quetzalcoatl`(B+B) / `yinglong` = `east_blue_dragon`+`quetzalcoatl`
  - dual(서로 다른 원소의 t2 아무거나 둘): `thermal_dragon` = fire t2 × ice t2(9쌍), `thunderbird` = fire t2 × lightning t2(9쌍), `jiaolong` = ice t2 × lightning t2(9쌍). elements는 두 원소, 앞 원소가 상성 판정용
  - secret `tiamat`: `thermal_dragon`+`yinglong`, `thunderbird`+`kuraokami`, `jiaolong`+`zhulong`
  - 레시피 합계 42개
- 능력치 시작값: base hp 100 / atk 10 / cooldownTicks 20, t2 220/22/20, t1 480/48/18, dual 400/40/18, secret 900/90/16. role 보정: front는 hp×130%·atk×80%, back은 hp×80%·atk×125%, support는 그대로(정수 내림)
- 특성: 종마다 하나씩(22개). kind는 4종을 고르게 쓰고 value는 base 10, t2 15, t1 25, dual 20, secret 30이다. nameKo는 짧은 한국어로 쓴다.
- nameKo: 설계 문서 6.4의 한국어 이름을 쓴다.

**검사 항목:** id 중복, 참조 없는 id, 순서 무관 중복 레시피, base에서 레시피로 닿지 않는 종, base·t2·t1 레시피의 원소 불일치, 0 이하 가중치·능력치, `rerollCosts`가 비었는지.

- [ ] **Step 1:** `lint.test.ts`: `real data passes`(문제 0개), `detects duplicate pair`, `detects unknown id`, `detects unreachable species`, `detects cross-element t2 recipe`. 각각 `fixtures/bad-*.json`을 쓴다.
- [ ] **Step 2:** `purity.test.ts`: `packages/core/src` 아래 `.ts` 파일을 전부 읽어 Global Constraints의 금지 토큰이 하나도 없는지 확인한다(주석 포함, 정규식은 단어 경계).
- [ ] **Step 3:** 데이터 6개 파일과 `lint.ts`를 구현한다. `npm test`, `npm run typecheck`, `npm run lint:data`가 모두 통과해야 한다.
- [ ] **Step 4:** `codex/X1` 브랜치에 커밋하고 보고한다: `feat(data): 22 species roster, data lint, core purity audit`

### Task C4: 룬 석판 (Claude)

**Files:** Create `packages/core/src/slot.ts` · Test `packages/core/test/slot.test.ts`

**Interfaces:**
- Consumes: `Rng`, `GameData`, `Grid`, `Cell`, `Offer`
- Produces:
```ts
export const LINES: readonly (readonly [number, number][])[]  // 8줄: [col,row] (row는 보이는 0~2), 순서: 가로0,가로1,가로2,세로0,세로1,세로2,대각(0,0)-(2,2),대각(0,2)-(2,0)
export function spinGrid(data: GameData, rng: Rng, forceLine: boolean): Grid
export function visible(grid: Grid, col: number, row: 0 | 1 | 2): Cell
export function evaluateLines(grid: Grid): { lines: number[]; element: SymbolId }[]  // 같은 결과 묶음별
export function nudge(grid: Grid, col: 0 | 1 | 2, dir: -1 | 1): Grid                 // offsets[col] = clamp(offsets[col]+dir, -1, 1)
export function offersFrom(data: GameData, grid: Grid): Offer[]                      // 가운데 보이는 행의 3칸
```
- 규칙: 릴 하나에 칸 5개를 뽑고 보이는 것은 `1+offset`부터 3칸이다. 원소 칸은 그 원소의 base 2종 중 하나, 여의주 칸은 아무 원소의 base 중 하나를 스핀 때 정한다. 줄 판정에서 여의주는 어느 원소든 대신한다. 여의주만 있는 줄은 `wild`, 황금 3개 줄은 `gold`, 황금이 섞이면 줄이 아니다. `forceLine`이면 가운데 행 보이는 3칸을 rng로 고른 한 원소로 덮는다. 제안: 원소·여의주 칸은 `{kind:'egg', speciesId}`, 황금 칸은 `{kind:'mana', amount: goldOfferMana}`.

- [ ] **Step 1: 실패하는 테스트**
  - `detects horizontal line with wild substitute`: 가운데 행 `[fire, wild, fire]` → `[{lines:[1], element:'fire'}]`
  - `detects two lines sharing a cell`: 가로0 3개 ice, 세로0 3개 ice → lines `[0,3]`
  - `gold breaks element line`, `three gold is gold line`, `three wild is wild line`
  - `nudge shifts visible window and clamps`: offset -1에서 다시 -1이면 그대로
  - `forceLine guarantees a line`: 1000개 시드에서 `evaluateLines(spinGrid(d, rng, true)).length >= 1`
  - `offers come from visible center row after nudge`
  - `hit rate is sane`: 기본 가중치로 10,000번 돌린 줄 맞춤 비율이 0.25~0.75 (값은 X2 봇으로 정밀하게 잰다)
- [ ] **Step 2:** FAIL 확인 → **Step 3:** 구현 → **Step 4:** PASS 확인
- [ ] **Step 5:** 커밋한다: `feat(core): rune slab spin, lines, nudge, offers`

### Task C5: 합치기 (Claude)

**Files:** Create `packages/core/src/fusion.ts` · Test `packages/core/test/fusion.test.ts`

**Interfaces:**
```ts
export function findRecipe(data: GameData, a: string, b: string): string | undefined  // 순서 무관
export function mergePreview(data: GameData, main: DragonInst, material: DragonInst): { kind: 'evolve'; result: string } | { kind: 'absorb'; trait: string | null }
export function merge(data: GameData, main: DragonInst, material: DragonInst, newUid: number): { inst: DragonInst; kind: 'evolve' | 'absorb'; trait: string | null }
```
- 진화: 새 uid, 결과 종, 주인의 `traits` 유지, `bonusPct`는 0부터 다시 시작한다.
- 흡수: 주인 uid와 종을 유지한다. 재료 종의 `traitId`가 없고 칸이 `maxTraits` 미만이면 추가한다. `bonusPct += absorbBonusPct[재료 tier]`.

- [ ] **Step 1:** 테스트를 쓴다: `A+A evolves to t2`, `order does not matter`, `t2 pair evolves to t1`, `cross element t2 gives dual`, `no recipe absorbs trait and bonus`, `absorb skips duplicate trait`, `absorb respects maxTraits but still adds bonus`, `evolve keeps main traits and resets bonus`. 실데이터 대신 테스트 안에서 만든 최소 GameData를 쓴다.
- [ ] **Step 2~4:** FAIL → 구현 → PASS
- [ ] **Step 5:** 커밋한다: `feat(core): fusion evolve and bloodline absorb`

### Task C6: 자동 전투 (Claude)

**Files:** Create `packages/core/src/battle.ts` · Test `packages/core/test/battle.test.ts`

**Interfaces:**
```ts
export function toUnit(data: GameData, inst: DragonInst): Unit  // stats × (100 + bonusPct + hpPct/atkPct 특성)/100, cooldown × (100 - hastePct)/100 (최소 5)
export function elementMult(cfg: BattleConfig, atk: Element, def: Element): number  // 135 | 75 | 100
export function simulateBattle(cfg: BattleConfig, allies: (Unit | null)[], enemies: (Unit | null)[]): BattleResult
```
- 틱마다 아군 0→5, 적 0→5 순으로 쿨타임이 다 찬 유닛이 공격한다. 대상은 상대의 살아 있는 칸 중 번호가 가장 작은 칸이다(전열 0~2가 먼저). 피해는 `floor(atk × mult / 100)`이고 최소 1이다. 흡혈 회복은 `floor(dmg × lifestealPct / 100)`, 최대 체력을 넘지 않는다.
- 첫 공격은 `cooldownTicks` 틱 뒤에 한다. 한쪽이 전멸하면 끝난다. `maxTicks`에 닿으면 적 승리다.
- 난수를 쓰지 않는다(같은 입력이면 같은 결과).

- [ ] **Step 1:** 테스트를 쓴다: `fire beats ice 135`, `ice vs fire 75`, `targets front row first`, `timeout is enemy win`, `lifesteal heals but not over max`, `haste shortens cooldown with floor 5`, `identical input identical events`(JSON 문자열 비교), `death event emitted once`.
- [ ] **Step 2~4:** FAIL → 구현 → PASS
- [ ] **Step 5:** 커밋한다: `feat(core): fixed-tick auto battle`

### Task C7: 웨이브와 적 생성 (Claude)

**Files:** Create `packages/core/src/waves.ts` · Test `packages/core/test/waves.test.ts`

**Interfaces:**
```ts
export function enemyPower(cfg: WaveConfig, wave: number): number  // p=basePower; 2..wave까지 p=floor(p*growthPct/100); 보스면 floor(p*bossPct/100)
export function isBoss(cfg: WaveConfig, wave: number): boolean
export function bossElement(seed: number, wave: number): Element    // createRng(seed ^ (wave * 7919))로 결정
export function unitPower(u: Unit): number                          // floor(hp/4) + floor(atk*20/cooldownTicks)
export function generateEnemies(data: GameData, wave: number, rng: Rng, seed: number): Unit[]
```
- 적 수는 `min(1 + floor(wave/2), 6)`이다. 종은 wave ≤ 5이면 base, 그 뒤로는 base와 t2에서 고른다. 보스 웨이브에서는 0번 칸이 `bossElement`의 t1이고 나머지는 하수인이다. 전체 `unitPower` 합이 `enemyPower`에 가깝도록 hp와 atk를 같은 백분율 k로 늘린다(k = floor(목표×100/합), 최소 50).

- [ ] **Step 1:** 테스트를 쓴다: `power wave1=100 wave2=118 wave3=139`, `boss wave5 applies 165`, `isBoss 5 and 10 only within maxWave 10`, `bossElement stable per seed`, `enemy total power within 10% of target`, `boss slot 0 is t1 of boss element`.
- [ ] **Step 2~4:** FAIL → 구현 → PASS
- [ ] **Step 5:** 커밋한다: `feat(core): wave power curve and enemy generation`

### Task C8: 판 진행 상태기계 (Claude)

**Files:** Create `packages/core/src/run.ts`, Modify `packages/core/src/index.ts` · Test `packages/core/test/run.test.ts`

**Interfaces:**
```ts
export function createRun(data: GameData, seed: number): { state: RunState; events: GameEvent[] }  // wave 1, phase 'spin', lives/mana 시작값, nestOpen 3, waveStart 이벤트(보스 예보는 1·6웨이브에 다음 보스 원소)
export function applyCommand(data: GameData, state: RunState, cmd: Command): { state: RunState; events: GameEvent[] }  // 불변: 입력 state를 바꾸지 않음. 거절이면 state 그대로 + rejected 이벤트. 받아들인 명령은 state.log에 추가
export function stateHash(state: RunState): string  // log를 뺀 상태의 안정적인 JSON 문자열
```
- `spin`: phase는 'spin' 또는 'pick'이어야 한다. 비용은 `rerollCosts[spinsThisWave]`(넘치면 마지막 값)이다. `pity >= pityThreshold`이면 `forceLine`. 줄이 없으면 pity+1, 있으면 0 → phase 'pick'.
- `nudge`: phase 'pick', `nudgesLeft > 0`.
- `pick`: phase 'pick'. 제안을 받는다(알은 대기칸 첫 빈칸, 대기칸이 차 있으면 `benchFull`로 거절). 줄 보상을 정산한다: 원소 줄 묶음마다 그 원소의 base 보너스 알 1개(rng로 A/B)와 `lineMana`. 원소 줄이 2줄 이상이면 base 대신 그 원소 t2 중 하나다. gold 줄은 `goldLineMana`, wild 줄은 `wildLineMana`. 보이는 황금 칸마다 `goldMana`. 보너스 알이 들어갈 대기칸이 없으면 1개당 마력 +1로 바꾼다. 그 뒤 grid=null, phase 'manage'.
- `merge`/`move`/`release`: phase 'manage'. 잠긴 둥지 칸(`index >= nestOpen`)이면 `slotLocked`. 진화가 처음이면 `discovered`에 추가하고 `firstTime: true`.
- `startBattle`: phase 'manage', 둥지에 1마리 이상. 전투 → 승패에 따라 마력·생명. `nestUnlockAfter`에 해당하면 칸을 연다. 생명 0이면 'gameOver', `wave === maxWave`에서 이기면 'victory', 그 밖에는 wave+1, spinsThisWave 0, nudgesLeft 리셋, phase 'spin', waveStart 이벤트.

- [ ] **Step 1: 실패하는 테스트** (실데이터 `data/*.json` 사용. X1 병합 전이면 C2 픽스처로 시작하고 X1 병합 뒤 바꾼다)
  - `pick before spin rejected wrongPhase`
  - `first spin free, second costs 2`, `reroll rejected without mana`
  - `nudge only once per wave`
  - `bonus eggs convert to mana when bench is full`
  - `pick rejected when bench full`
  - `startBattle rejected when nest empty`
  - `spin rejected during battle phase` (phase를 'battle'로 만든 상태)
  - `merge into locked nest slot rejected`
  - `first evolution marks discovered once`
  - `boss loss costs 2 lives`, `lives zero ends run`, `nest unlocks after wave 5`
  - `victory after winning maxWave`
  - `replay determinism`: 같은 시드로 명령 30개를 두 번 적용하면 `stateHash`가 같다. 같은 log를 새 판에 다시 적용해도 같다.
- [ ] **Step 2~4:** FAIL → 구현 → PASS. 이어서 `npm test` 전체와 `npm run typecheck`
- [ ] **Step 5:** 코덱스 독립 검수(읽기 전용)를 맡긴다. 코덱스 플러그인의 `review`(읽기 전용 샌드박스)를 main 작업 폴더에서 C4~C8 커밋 범위로 실행해, 결정론 위반과 설계 문서 6장 규칙 위반을 찾게 한다. 지적 사항은 받아들일지 판단한 뒤 반영한다.
- [ ] **Step 6:** 커밋한다: `feat(core): run state machine with lives, mana, nest unlock`

### Task X2: 밸런스 봇 (Codex 카드, C8 병합 뒤 맡김)

**Files:**
- Create: `tools/sim/bot.ts`, `tools/sim/run.ts`, `tools/sim/report.ts`, `tools/sim/sim.test.ts`
- 금지: `packages/**`, `data/**`, `package.json`

**Interfaces:**
- Consumes: `createRun`, `applyCommand`, `mergePreview`, `offersFrom`, `evaluateLines`, `nudge`
- Produces: `export function chooseCommand(data, state): Command`(봇 한 수), `export function simulate(data, runs: number, seed: number): SimStats`, `npm run sim -- --runs 10000 --seed 1` → 마크다운 표를 stdout과 `docs/balance/latest.md`에 쓴다

**봇 규칙:** 줄이 새로 생기는 밀기가 있으면 한다 → 레시피를 완성하는 알 > 둥지 원소와 같은 알 > 첫 알 순으로 고른다 → 진화 레시피가 있으면 합친다 → 대기칸이 차면 가장 약한 것을 흡수 재료로 쓴다 → 강한 순서로 둥지를 채운다(front 역할은 전열로) → 전투. 다시 돌리기는 마력이 8 이상일 때 웨이브당 1회.

**SimStats 표 항목:** 클리어율, 평균 도달 웨이브, 평균 남은 생명, 5웨이브 안에 t2 보유 비율, 1티어 첫 등장 웨이브 분포(없음 포함), 합치기 중 흡수 비율, 스핀당 줄 맞춤 비율(밀기 전·후), 종별 최종 둥지 등장률 상위·하위 5.

- [ ] **Step 1:** `sim.test.ts`: `same seed same stats`(runs 200 두 번 비교), `bot never issues rejected command`(runs 50, 거절 이벤트 0), `report has all rows`.
- [ ] **Step 2:** 구현한 뒤 `npm test`, `npm run typecheck`, `npm run sim -- --runs 2000 --seed 1`이 1분 안에 끝나는지 확인한다.
- [ ] **Step 3:** `codex/X2`에 커밋하고 보고한다: `feat(tools): heuristic balance bot and report`

### Task C9: 화면 뼈대와 석판 패널 (Claude)

**Files:** Create `packages/view/src/controller.ts`, `layout.ts`, `scenes/GameScene.ts`, `panels/SlotPanel.ts`, `panels/Hud.ts`, Modify `packages/view/src/main.ts`

**Interfaces:**
```ts
// controller.ts
export class GameController {
  constructor(data: GameData, seed: number)
  readonly state: RunState
  dispatch(cmd: Command): GameEvent[]          // applyCommand 래핑, 상태 교체, 구독자에게 이벤트 전달
  on(fn: (events: GameEvent[], state: RunState) => void): () => void
  busy: boolean                                // 애니메이션 재생 중 true → dispatch가 [] 반환
}
// layout.ts — 영역(px, 1280×720 기준)
export const AREA = { battle: {x:0,y:0,w:1280,h:330}, nest: {x:0,y:330,w:640,h:390}, slab: {x:640,y:330,w:640,h:390}, hud: {x:0,y:0,w:1280,h:44} }
```
- 데이터는 `data/*.json`을 Vite JSON import로 불러 `loadGameData`에 넘긴다. 시드는 URL `?seed=` 또는 시간을 쓴다(시간은 view에서만 쓴다).
- SlotPanel: 3×3 칸(칸마다 원소 색 사각형 + 글자 "불/얼/번/금/여"), 세로 줄마다 ▲▼(밀기, 남은 횟수 표시), "돌리기 (마력 n)" 버튼(모자라면 비활성), 가운데 행 아래에 제안 카드 3장(종 이름, 원소색). 맞은 줄은 테두리를 강조한다.
- 원소 색: fire `#E8590C`, ice `#4DABF7`, lightning `#FAB005`, gold `#D4AF37`, wild `#9775FA`.
- Hud: 웨이브 n/10, 생명 ♥×n, 마력, 보스 예보("5웨이브 보스: 얼음").

- [ ] **Step 1:** 구현 후 `npm run dev`로 앱 브라우저 창에서 돌리기 → 밀기 → 카드 고르기 흐름을 확인한다(스크린샷).
- [ ] **Step 2:** 빠르게 두 번 누를 때, 돌리는 연출 중 입력이 잠기는지 확인한다(Review Focus 3).
- [ ] **Step 3:** 창 크기를 모바일(375×812, 가로로 돌린 비율)과 1280×800으로 바꿔 잘림 없이 맞춰지는지 확인한다(Review Focus 4). 마력이 모자랄 때 버튼이 비활성인지 확인한다(Review Focus 5).
- [ ] **Step 4:** 커밋한다: `feat(view): layout, controller, rune slab panel, hud`

### Task C10: 둥지·대기칸 패널 (Claude)

**Files:** Create `packages/view/src/panels/NestPanel.ts`, `packages/view/src/codex-store.ts`

**Interfaces:**
```ts
// codex-store.ts — 발견 기록은 브라우저에만 저장(판과 무관한 도감)
export function loadDiscovered(): Set<string>
export function markDiscovered(id: string): boolean  // 처음이면 true
```
- 둥지 2행×3칸(위 후열 3~5, 아래 전열 0~2), 잠긴 칸은 자물쇠 표시, 그 아래 대기칸 4칸. 카드에는 이름, 티어 글자(기본/2티어/1티어/이중/???), 계승 특성 점 2개, bonusPct를 보여 준다.
- 끌어 놓기(터치·마우스 공통): 빈칸에 놓으면 `move`, 다른 용 위에 놓으면 손을 떼기 전에 `mergePreview` 결과를 띄운다("진화 → 파프니르" / "흡수: 특성 +1"). 놓으면 `merge`(놓은 자리 = 주인, 끌고 온 것 = 재료). "놓아주기" 칸에 놓으면 `release`.
- 처음 보는 진화이면 화면 가운데에 "새로 발견! ○○"를 1.5초 띄운다(`markDiscovered`).
- "전투 시작" 버튼(둥지가 비면 비활성).

- [ ] **Step 1:** 구현 후 브라우저에서 A+A 진화, 흡수, 이동, 놓아주기, 잠긴 칸 거절을 각각 확인한다(스크린샷).
- [ ] **Step 2:** 커밋한다: `feat(view): nest and bench with drag merge preview`

### Task C11: 전투 재생과 배속 (Claude)

**Files:** Create `packages/view/src/panels/BattlePanel.ts`

**Interfaces:**
- Consumes: `GameEvent` `{t:'battle', result}`의 `BattleResult.events`
- Produces: `play(result: BattleResult, speed: 1 | 2 | 4): Promise<void>`, `skip(): void`
- 위쪽 영역 왼쪽에 아군 6칸, 오른쪽에 적 6칸을 그린다. 틱 1개는 50ms/speed로 재생한다. 공격할 때는 공격자를 대상 쪽으로 짧게 이동시키고, HP 막대를 줄이고, 죽으면 흐리게 만든다.
- 배속 버튼 1x/2x/4x(설정 유지), "건너뛰기"는 마지막 상태로 바로 간다. 끝나면 "승리 / 패배 (생명 -n)" 띄우기 → controller.busy 해제.

- [ ] **Step 1:** 구현 후 브라우저에서 1~5웨이브를 실제로 플레이하며 배속, 건너뛰기, 보스 웨이브, 생명 감소를 확인한다.
- [ ] **Step 2:** 커밋한다: `feat(view): battle playback with speed and skip`

### Task C12: 타격감 (Claude)

**Files:** Create `packages/view/src/fx/juice.ts`, Modify `BattlePanel.ts`, `SlotPanel.ts`, `NestPanel.ts`

**Interfaces:**
```ts
export function hitFlash(target: Phaser.GameObjects.Components.Tint & Phaser.GameObjects.GameObject, ms?: number): void   // 흰색 80ms
export function damageNumber(scene: Phaser.Scene, x: number, y: number, dmg: number, strong: boolean): void  // 위로 튀어 오르며 사라짐, strong이면 크게
export function hitstop(scene: Phaser.Scene, ms: number): Promise<void>  // 처치 때 60ms
export function shake(scene: Phaser.Scene, intensity: number, ms: number): void  // 보스 피격·보스 처치
export function pulse(target: Phaser.GameObjects.GameObject): void  // 줄 맞춤 칸, 새로 발견
```
- [ ] **Step 1:** 적용한 뒤 브라우저에서 줄 맞춤, 공격, 처치, 보스, 새로 발견 장면을 확인한다. 4x 배속에서도 숫자가 겹쳐 읽기 어렵지 않은지 본다(4x에서는 숫자를 생략해도 됨).
- [ ] **Step 2:** 커밋한다: `feat(view): juice pass (flash, numbers, hitstop, shake)`

### Task C13: 시험 빌드와 0단계 판정 준비 (Claude)

**Files:** Create `docs/playtest/phase0.md`, Modify `docs/devlog/*`

- [ ] **Step 1:** `npm run build`가 성공하고 `dist/`를 `npx vite preview`로 열어 한 판(10웨이브)을 끝까지 할 수 있는지 확인한다.
- [ ] **Step 2:** `npm run sim -- --runs 10000 --seed 1`을 돌려 결과를 `docs/balance/latest.md`에 남긴다. 설계 목표와 비교한다: "5웨이브 안 t2 보유 90% 이상", 흡수 비율, 클리어율(목표 30~60%). 벗어나면 `data/*.json`의 가중치·배율만 고치고 다시 돌린다(최대 3회. 그래도 안 맞으면 사용자에게 보고).
- [ ] **Step 3:** `docs/playtest/phase0.md`에 시험 안내를 쓴다. 할 일(한 판 이상), 질문 5개(가장 재밌던 순간 / 지루한 순간 / 한 판 더 하고 싶었나 / 이해 안 된 규칙 / 다음 판에 해 보고 싶은 조합), 결과 기록표(5명), 통과 기준("시키지 않아도 한 판 더 3명 이상")을 넣는다.
- [ ] **Step 4:** 빌드물을 어디에 올려 시험자에게 보낼지(itch.io 비공개 페이지 등)는 공개 행위라 사용자에게 묻는다.
- [ ] **Step 5:** 커밋한다: `chore: phase0 playtest build and balance report`

---

## 완료 정의

- `npm test`, `npm run typecheck`, `npm run lint:data`가 main에서 모두 통과한다.
- 브라우저에서 10웨이브 한 판을 끝까지 할 수 있고, 같은 `?seed=`이면 같은 석판 결과가 나온다.
- 밸런스 리포트가 `docs/balance/latest.md`에 있다.
- 시험 안내서가 준비되어 사용자가 5명 시험을 진행할 수 있다.
- 1단계 계획은 0단계 판정 결과를 보고 새로 쓴다.
