# 작업 카드 A2: 새 드래곤 그림 30장 (image_gen)

코드는 고치지 않아요. image_gen은 이 환경에 내장된 이미지 도구라 써도 돼요(이전에 같은 방식으로 `assets/dragons/` 22장을 만들었어요). 네트워크 금지는 패키지 설치·웹 접근에 대한 규칙이에요.

## 저장
`art/dragons-src/<id>.png` (정사각형, 1024 이상, 배경 투명). 기존 파일은 건드리지 않아요. 이번 호출에서 만들 id는 질문 끝 "이번 목록"만.

## 화풍 (기존 `art/dragons-src/*.png`과 똑같이)
Original 2D game sprite. Bold black outlines, flat colors, exactly two levels of hard-edged cel shadow. Slightly oversized head, cute but strong proportions. Left-facing three-quarter side view, whole body visible with margin, centered. Transparent background. No ground, shadow, scenery, text, border or watermark. Original design, must not resemble any existing game or animation character. No flame on the tail tip.

원소 색: 독 = 연두·보라 독기, 강철 = 은회색 금속 판갑·리벳, 심연 = 짙은 남보라·검정, 별빛 같은 점. 티어가 높을수록 장식과 위엄↑.

## 30종
| id | 이름 | 설명 |
|---|---|---|
| poison_drake | 늪지 드레이크 | 기본, 독. 통통한 네 발 드레이크, 등에 이끼와 독 혹 |
| poison_wyvern | 맹독 와이번 | 기본, 독. 꼬리 끝 독침, 연두 날개막 |
| hydra | 히드라 | 2티어, 독. 머리 세 개의 늪 용(머리 셋까지만), 묵직한 몸 |
| basilisk | 바실리스크 | 2티어, 독. 왕관 같은 볏의 뱀 용, 노려보는 눈 |
| cockatrice | 코카트리스 | 2티어, 독. 닭 같은 볏·날개와 뱀 꼬리를 가진 독 비행 용 |
| jormungandr | 요르문간드 | 1티어, 독. 몸을 둥글게 감은 거대한 바다뱀, 독 거품, 위엄 |
| steel_drake | 강철 드레이크 | 기본, 강철. 판갑을 두른 네 발 드레이크 |
| steel_wyvern | 강철 와이번 | 기본, 강철. 금속 깃 날개의 와이번 |
| tarasque | 타라스크 | 2티어, 강철. 거북 등딱지 같은 가시 갑각의 육중한 용 |
| west_white_dragon | 서해백룡 오윤 | 2티어, 강철. 흰 은빛 동양 용, 금속 비늘, 수염 |
| zilant | 질란트 | 2티어, 강철. 날개 달린 은빛 뱀 용, 날렵 |
| ladon | 라돈 | 1티어, 강철. 황금 사과 나무를 지키는 수호룡, 갑옷 같은 비늘, 위엄 (머리 하나) |
| abyss_drake | 심연 드레이크 | 기본, 심연. 그림자 같은 네 발 드레이크, 빛나는 눈 |
| abyss_wyvern | 그림자 와이번 | 기본, 심연. 찢어진 어둠 날개의 와이번 |
| apophis | 아포피스 | 2티어, 심연. 거대한 혼돈의 뱀, 짙은 남보라 |
| vritra | 브리트라 | 2티어, 심연. 물을 가두는 가뭄의 뱀 용, 몸을 꼬아 웅크림 |
| leviathan | 레비아탄 | 2티어, 심연. 심해의 거대 바다 괴룡, 지느러미 |
| nidhogg | 니드호그 | 1티어, 심연. 세계수 뿌리를 갉는 어둠의 용, 위엄 |
| salamander | 살라만더 | 이중(불+독). 불꽃 무늬와 독 반점의 도롱뇽 용 |
| forge_dragon | 용광로룡 | 이중(불+강철). 몸 안이 용광로처럼 빛나는 금속 용 |
| azi_dahaka | 아지 다하카 | 이중(불+심연). 불타는 어둠의 용(머리 셋까지만) |
| frostvenom_dragon | 빙독룡 | 이중(얼음+독). 얼음 결정 속에 독이 흐르는 용 |
| crystal_dragon | 결정갑룡 | 이중(얼음+강철). 수정 결정과 금속 판갑의 용 |
| deep_serpent | 심해 서펜트 | 이중(얼음+심연). 차가운 심해의 긴 뱀 용 |
| shockvenom_dragon | 뇌독룡 | 이중(번개+독). 전기가 흐르는 독 가시 용 |
| typhon | 티폰 | 이중(번개+강철). 폭풍을 부르는 금속 날개 용 |
| dark_thunder_dragon | 칠흑뇌룡 | 이중(번개+심연). 검은 몸에 보라 번개 |
| corrosion_dragon | 부식철룡 | 이중(독+강철). 녹슨 금속과 독 거품 |
| plague_dragon | 역병룡 | 이중(독+심연). 어둠과 독기를 두른 용 |
| blackiron_dragon | 흑철룡 | 이중(강철+심연). 검은 금속 갑옷의 용 |

## 결과 보고
만든 파일, 크기, 투명 여부, 실패와 이유.
