# 6원소 확장 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 출시 원소를 3개에서 6개(불·얼음·번개·독·강철·심연)로 늘리고, 드래곤을 22종에서 52종으로 늘린다(사용자 결정 2026-11-23: "너무 빨리 끝난다, 6원소로").

**Architecture:** 원소 상성은 코드 상수 대신 `data/battle.json`의 `beats` 표로 옮긴다. 원소당 구조는 그대로(기본 2, 2티어 3, 1티어 1). 이중원소룡은 원소 쌍마다 1종(15종), 숨은 종은 티아마트 1종(레시피 6개). 그림 30장은 코덱스 image_gen. 도감은 탭(원소별 / 이중·숨은)으로 나눈다.

**Spec:** `docs/superpowers/specs/2026-11-23-wyrmslot-design.md` (6.8 시즌 계획을 이 계획이 대신함)

## 결정 사항
- 상성(각 원소가 둘을 이기고 둘에게 지고 하나와 대등):
  - 불 > 얼음·강철 / 얼음 > 번개·독 / 번개 > 불·심연 / 독 > 번개·심연 / 강철 > 독·얼음 / 심연 > 불·강철
  - 대등: 불–독, 얼음–심연, 번개–강철
- 색: 독 `#82C91E`, 강철 `#ADB5BD`, 심연 `#5F3DC4`. 여의주(만능)는 보라에서 분홍 `#F783AC`로(심연과 구분).
- 새 종 id와 레시피(A=드레이크, B=와이번):
  - 독: `poison_drake`, `poison_wyvern` / `hydra`(A+A, front), `basilisk`(A+B, support), `cockatrice`(B+B, back) / 1티어 `jormungandr` = basilisk+cockatrice
  - 강철: `steel_drake`, `steel_wyvern` / `tarasque`(A+A), `west_white_dragon`(서해백룡 오윤, A+B), `zilant`(B+B) / 1티어 `ladon` = west_white_dragon+zilant
  - 심연: `abyss_drake`, `abyss_wyvern` / `apophis`(A+A), `vritra`(A+B), `leviathan`(B+B) / 1티어 `nidhogg` = vritra+leviathan
  - 이중 15종(쌍마다 1종, 서로 다른 원소의 2티어 아무거나 둘): 기존 `thermal_dragon`(불+얼음), `thunderbird`(불+번개), `jiaolong`(얼음+번개) + 새 12종 `salamander`(불+독), `forge_dragon`(불+강철, 용광로룡), `azi_dahaka`(불+심연), `frostvenom_dragon`(얼음+독, 빙독룡), `crystal_dragon`(얼음+강철, 결정갑룡), `deep_serpent`(얼음+심연, 심해 서펜트), `shockvenom_dragon`(번개+독, 뇌독룡), `typhon`(번개+강철), `dark_thunder_dragon`(번개+심연, 칠흑뇌룡), `corrosion_dragon`(독+강철, 부식철룡), `plague_dragon`(독+심연, 역병룡), `blackiron_dragon`(강철+심연, 흑철룡)
  - 숨은 `tiamat`: 기존 3개 + `corrosion_dragon`+`nidhogg`, `plague_dragon`+`ladon`, `blackiron_dragon`+`jormungandr`
  - 합계 52종, 레시피 18(기본) + 6(1티어) + 135(이중 15쌍×9) + 6(숨은) = 165개
- 석판 심볼: 원소 6개 + 황금 + 여의주. 가중치는 시뮬레이터로 맞춤(줄 맞춤이 너무 드물어지지 않게 여의주 비중↑).
- 보스 원소는 6개 중 하나.

## Review Focus
1. 기존 3원소 사이 상성(불>얼음>번개>불)은 그대로 → 테스트 `original triangle preserved`
2. 상성표가 대칭 모순(서로 이김)이 없고 각 원소 2승 2패 1무 → 테스트 `beats table is balanced`
3. 도감 52칸이 화면 밖으로 넘치지 않음 → 탭 확인
4. 석판 줄 맞춤 비율이 0단계 대비 크게 줄지 않음(밀기 후 70% 이상 목표) → 시뮬레이터
5. 기존 저장 데이터(발견 기록·해금)가 있어도 깨지지 않음 → 브라우저 확인

## 작업
- [ ] **E1 (Claude):** `Element` 6개, `BattleConfig.beats`, `elementMult`가 표를 사용. 테스트 먼저(`beats table is balanced`, `original triangle preserved`, 기존 상성 테스트 유지). `slot.ts`/`waves.ts`의 ELEMENTS 상수를 데이터(dragons의 원소)나 계약 상수 하나로 통일.
- [ ] **X7 (Codex):** 52종 dragons/traits/recipes, slot 가중치(원소 6개, 임시 12씩, 황금 12, 여의주 16), codex.json 30종 추가, 검사기 숫자·원소 검사 갱신.
- [ ] **A2 (Codex):** 새 그림 30장(10장씩 3묶음, 묶음 사이 커밋), 화풍은 기존과 동일.
- [ ] **E2 (Claude):** 화면: 색·문양(독 물방울, 강철 방패, 심연 소용돌이), 여의주 분홍, 도감 탭, ELEMENT_KO, 그림 256px 축소.
- [ ] **E3 (Claude):** 시뮬레이터로 석판 가중치·난이도 재조정(20웨이브 클리어 25~50%, 데모 재앙0 55~75%), 설계 문서 갱신, 검토, 개발 일지.
