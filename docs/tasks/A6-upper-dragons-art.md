# 작업 카드 A6: 윗계급 용 그림 72장 (image_gen)

코드는 고치지 않아요. image_gen은 이 환경에 내장된 이미지 도구라 써도 돼요(A1~A5에서 같은 방식으로 만들었어요). 네트워크 금지는 패키지 설치·웹 접근에 대한 규칙이에요.

## 저장
`art/dragons-src/<id>.png` (정사각형, 1024 이상, 배경 투명). 기존 파일은 건드리지 않아요. 이번 호출에서 만들 id는 질문 끝 "이번 목록"만. git commit·reset·push는 하지 않아요. 테스트·typecheck는 돌리지 않아요.

## 화풍 (기존 `art/dragons-src/*.png`과 똑같이. 먼저 같은 계급의 기존 그림을 열어 보고 맞춰요)
- 2티어 기준: `fafnir`, `tarasque`, `azi_raoidita`
- 1티어 기준: `zhulong`, `zmey_gorynych`, `ryujin`
- 정점 기준: `fire_sovereign`, `ice_sovereign`

Original 2D game sprite. Bold black outlines, flat colors, exactly two levels of hard-edged cel shadow. Slightly oversized head, cute but strong proportions. Left-facing three-quarter side view, whole body visible with margin, centered. Transparent background. No ground, shadow, scenery, text, border or watermark. Original design, must not resemble any existing game or animation character. No flame on the tail tip.

계급이 높을수록 몸이 크고 장식과 위엄이 늘어요: 2티어 = 다 자란 용, 1티어 = 전설의 용(화려한 뿔·갈기·문양), 정점 = 용의 신·왕(가장 화려함, 후광이나 왕관).

## id 규칙: `<원소>_<형태>`
원소 접두와 색:
| 접두 | 원소 | 색 |
|---|---|---|
| fire | 불 | 주황·빨강, 불꽃 무늬 |
| ice | 얼음 | 하늘색·흰색, 얼음 결정 |
| storm | 번개 | 노랑·남색, 번개 줄무늬 |
| poison | 독 | 연두·보라, 독 반점·독기 |
| steel | 강철 | 은회색 금속 판갑·리벳 |
| abyss | 심연 | 짙은 남보라·검정, 별빛 점 |

형태 12가지(서로 한눈에 구별되게):
| 형태 | 계급 | 이름 | 모습 |
|---|---|---|---|
| armored | 2티어 | 갑주룡 | 온몸에 두꺼운 판 비늘 갑옷을 두른 육중한 네 발 용, 날개 없음 |
| brawler | 2티어 | 투사룡 | 굵은 앞발과 넓은 어깨로 두 발로 선 싸움꾼 용, 날개 없음 |
| lancer | 2티어 | 창날 와이번 | 창처럼 길고 뾰족한 주둥이와 날렵한 날개의 와이번 |
| twinhead | 2티어 | 쌍두 와이번 | 머리가 둘인 와이번(머리 둘까지만) |
| sage | 2티어 | 현자룡 | 긴 수염과 눈썹을 늘어뜨린 늙고 차분한 동양풍 용 |
| dancer | 2티어 | 무희 서펜트 | 리본 같은 긴 지느러미를 휘날리는 우아한 뱀 용, 다리 없음 |
| guardian | 1티어 | 수호룡 | 방패 같은 머리 갑각과 성벽 같은 몸의 거대한 네 발 용 |
| skylord | 1티어 | 천공룡 | 아주 큰 날개를 활짝 편 하늘의 용, 구름 장식 |
| meteor | 1티어 | 유성룡 | 유성 꼬리처럼 빛줄기를 끌며 내리꽂는 날렵한 용 |
| elder | 1티어 | 고룡 | 이끼·수정이 자란 뿔과 깊은 주름의 아주 오래된 용 |
| god | 정점 | 룡신 | 후광을 두른 신성한 거대 용, 여러 겹 날개(네 장까지), 가장 웅장 |
| king | 정점 | 룡왕 | 왕관과 망토 같은 날개를 두른 용의 임금, 위엄 있는 자세 |

예: `fire_armored`, `ice_twinhead`, `storm_skylord`, `abyss_god`.

## 결과 보고
만든 파일, 크기, 투명 여부, 실패와 이유.
