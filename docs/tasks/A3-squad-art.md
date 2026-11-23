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
