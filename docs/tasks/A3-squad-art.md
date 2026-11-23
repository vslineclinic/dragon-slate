# A3 부대 전투용 그림 (코덱스, image_gen)

설계: `docs/superpowers/specs/2026-11-23-squad-battlefield-design.md` 5.3, 6장.

## 할 일
image_gen(이미지 생성 도구) 사용을 허락해요. 이 작업에서 image_gen은 금지된 네트워크 사용이 아니에요. 아래 그림을 만들어 저장하세요.

### 1. 졸병 6종 (원소별 1종)
화풍은 `assets/dragons/*.png`(예: `assets/dragons/ember_drake.png`, `frost_drake.png`)와 맞춰요. 굵은 외곽선이 있는 귀여운 판타지 일러스트예요. 몸 전체가 보이게, **왼쪽을 바라보게**, 배경은 투명하게 그려요. 무기를 든 작은 코볼트(도마뱀 얼굴의 작은 병사)이고, 원소 색과 소품으로 구분해요.

| id | 이름 | 원소 | 느낌 |
|---|---|---|---|
| ember_kobold | 불씨 코볼트 | fire | 주황·빨강, 불붙은 창 |
| frost_kobold | 서리 코볼트 | ice | 하늘색·흰색, 얼음 방패 |
| spark_kobold | 번개 코볼트 | lightning | 노랑, 번개 지팡이 |
| bog_kobold | 늪 코볼트 | poison | 연두·보라, 독 단검 |
| iron_kobold | 강철 코볼트 | steel | 회색 갑옷, 망치 |
| shade_kobold | 그림자 코볼트 | abyss | 짙은 보라, 두건, 낫 |

- 원본은 `art/minions-src/<id>.png`, 게임용은 `assets/minions/<id>.png`(256×256, 투명 배경, 가운데 정렬, 발이 아래쪽 10% 안)에 저장해요.

### 2. 전장 배경 4장
옆에서 본 가로로 긴 전장이에요. 왼쪽(아군)과 오른쪽(적)이 맞붙는 땅이고, **가운데와 아래 2/3는 비교적 단순하게** 그려서 유닛이 잘 보이게 해요. 하늘·먼 풍경은 위쪽 1/3에 둬요. 글자, 사람, 유닛은 넣지 않아요. 화풍은 드래곤 그림과 어울리는 부드러운 판타지 일러스트이고, 너무 밝지 않게(UI 글자가 올라가요) 그려요.

| 파일 | 웨이브 | 장소 |
|---|---|---|
| plains_ruins | 1~5 | 풀밭과 무너진 돌기둥 유적, 저녁빛 |
| ice_canyon | 6~10 | 눈 덮인 협곡, 푸른 얼음 |
| volcano | 11~15 | 검은 바위와 용암 줄기, 붉은 하늘 |
| abyss | 16~20 | 보랏빛 균열과 떠 있는 돌, 별빛 |

- 원본은 `art/backgrounds-src/<파일>.png`, 게임용은 `assets/backgrounds/<파일>.png`(1600×446)에 저장해요. 원본 비율이 다르면 위아래를 잘라서 맞춰요(늘리지 말 것).

## 고쳐도 되는 파일
`art/minions-src/**`, `art/backgrounds-src/**`, `assets/minions/**`, `assets/backgrounds/**`, `docs/tasks/A3-squad-art.md`(결과 메모 추가)

## 건드리면 안 되는 파일
그 밖의 모든 파일. 특히 `godot/**`, `data/**`, `project.godot`, `package.json`, `.godot/` 등은 손대지 마세요. `.import` 파일도 만들지 마세요. git commit·reset·push는 하지 마세요.

## 완료 조건
- 졸병 PNG 6개와 배경 PNG 4개가 위 경로와 크기로 있어요. 크기는 `python -c`나 아무 방법으로 확인해서 결과 메모에 적어요.
- 이 카드 맨 아래에 "결과" 절을 만들고, 만든 파일 목록과 쓴 프롬프트 요약을 적어요.

## 결과

내장 image_gen으로 졸병 6종과 전장 배경 4종을 생성했습니다. 화풍은 저장소의 `assets/dragons/fire_drake.png`와 `assets/dragons/ice_drake.png`를 참조했습니다.

- 졸병 프롬프트는 굵은 외곽선과 각진 명암, 왼쪽을 보는 코볼트 전신, 투명 배경을 공통으로 지정했습니다. 게임용 PNG에서 알파 채널, 가로 가운데 정렬, 아래쪽 10% 안의 발 위치를 확인했습니다.
- 배경 프롬프트는 부드러운 판타지 화풍, 가로로 긴 측면 구도, 상단의 하늘과 먼 풍경, 가운데와 아래의 단순한 지면을 공통으로 지정했습니다. 글자와 인물, 유닛을 빼고 그렸습니다. 게임용 PNG는 원본의 위아래를 잘라 가로세로 비율을 유지한 채 축소했습니다.

| 원본 PNG | 해상도 · 용량 | 게임용 PNG | 해상도 · 용량 | 개별 프롬프트 요약 |
|---|---|---|---|---|
| `art/minions-src/ember_kobold.png` | 1254×1254 · 827,093 B | `assets/minions/ember_kobold.png` | 256×256 · 60,351 B | 주황·빨강 비늘과 불붙은 창 |
| `art/minions-src/frost_kobold.png` | 1254×1254 · 973,312 B | `assets/minions/frost_kobold.png` | 256×256 · 77,447 B | 하늘색·흰색 비늘과 각진 얼음 방패 |
| `art/minions-src/spark_kobold.png` | 1254×1254 · 948,776 B | `assets/minions/spark_kobold.png` | 256×256 · 76,416 B | 노란 비늘과 번개 모양 지팡이 |
| `art/minions-src/bog_kobold.png` | 1254×1254 · 901,447 B | `assets/minions/bog_kobold.png` | 256×256 · 72,588 B | 연두색 비늘, 보라색 장비와 독 단검 |
| `art/minions-src/iron_kobold.png` | 1254×1254 · 949,609 B | `assets/minions/iron_kobold.png` | 256×256 · 77,732 B | 회색 판금 갑옷과 쇠망치 |
| `art/minions-src/shade_kobold.png` | 1254×1254 · 916,729 B | `assets/minions/shade_kobold.png` | 256×256 · 75,602 B | 짙은 보라색 비늘, 두건과 낫 |
| `art/backgrounds-src/plains_ruins.png` | 2243×701 · 1,624,001 B | `assets/backgrounds/plains_ruins.png` | 1600×446 · 678,574 B | 저녁빛이 드는 풀밭과 무너진 돌기둥 |
| `art/backgrounds-src/ice_canyon.png` | 2172×724 · 1,478,458 B | `assets/backgrounds/ice_canyon.png` | 1600×446 · 564,275 B | 푸른 얼음 절벽과 눈밭. 글자가 잘 보이도록 채도를 낮춘 푸른 저녁빛으로 조정 |
| `art/backgrounds-src/volcano.png` | 2243×701 · 1,507,209 B | `assets/backgrounds/volcano.png` | 1600×446 · 574,709 B | 붉은 하늘, 검은 화산암과 멀리 흐르는 용암 |
| `art/backgrounds-src/abyss.png` | 2241×702 · 1,505,713 B | `assets/backgrounds/abyss.png` | 1600×446 · 598,520 B | 별빛 아래 보랏빛 균열과 공중에 떠 있는 바위 |

### 검증

- PNG 20개를 열어 해상도와 용량을 확인했습니다.
- `npm test -- --no-cache` 통과. 테스트 파일 17개, 테스트 131개.
- `npm run typecheck` 통과.
- `npm run godot:test` 종료 코드 1. `godot/tests/run_tests.gd`에서 `TestCase` 형식을 찾지 못해 테스트가 시작되지 않았습니다.
