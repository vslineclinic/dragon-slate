# 작업 카드 A5: 새 기본 용 그림 48장 (image_gen)

코드는 고치지 않아요. image_gen은 이 환경에 내장된 이미지 도구라 써도 돼요(A1~A4에서 같은 방식으로 만들었어요). 네트워크 금지는 패키지 설치·웹 접근에 대한 규칙이에요.

## 저장
`art/dragons-src/<id>.png` (정사각형, 1024 이상, 배경 투명). 기존 파일은 건드리지 않아요. 이번 호출에서 만들 id는 질문 끝 "이번 목록"만. git commit·reset·push는 하지 않아요. 테스트·typecheck는 돌리지 않아요.

## 화풍 (기존 `art/dragons-src/*.png`과 똑같이. 먼저 `fire_whelp`, `fire_serpent`, `ice_whelp`, `steel_serpent`를 열어 보고 맞춰요)
Original 2D game sprite. Bold black outlines, flat colors, exactly two levels of hard-edged cel shadow. Slightly oversized head, cute but strong proportions. Left-facing three-quarter side view, whole body visible with margin, centered. Transparent background. No ground, shadow, scenery, text, border or watermark. Original design, must not resemble any existing game or animation character. No flame on the tail tip.

전부 **기본 계급(새끼·작은 용)** 이라 작고 단순하게, 장식은 적게 그려요.

## id 규칙: `<원소>_<형태>`
원소 접두와 색:
| 접두 | 원소 | 색 |
|---|---|---|
| fire | 불 | 주황·빨강, 불씨 무늬 |
| ice | 얼음 | 하늘색·흰색, 서리 결정 |
| storm | 번개 | 노랑·남색, 번개 줄무늬 |
| poison | 독 | 연두·보라, 독 반점 |
| steel | 강철 | 은회색 금속 판갑·리벳 |
| abyss | 심연 | 짙은 남보라·검정, 별빛 점 |

형태 8가지(서로 한눈에 구별되게):
| 형태 | 이름 | 모습 |
|---|---|---|
| lindworm | 린드부름 | 뒷다리가 없고 앞발 둘만 있는 긴 몸의 용, 날개 없음 |
| amphiptere | 암피프테르 | 다리가 없고 날개만 있는 뱀 용, 깃털 같은 날개 |
| wyrm | 웜 | 다리도 날개도 없는 굵고 통통한 땅굴 용, 큰 입 |
| tortoise | 거북룡 | 등에 단단한 등딱지를 진 네 발 용, 짧은 목 |
| fairy | 요정룡 | 나비 날개를 단 아주 작은 용, 큰 눈, 가는 몸 |
| raptor | 랩터룡 | 두 뒷다리로 서서 달리는 날렵한 용, 작은 앞발, 날개 없음 |
| gecko | 도마뱀룡 | 넓적한 발가락과 굵은 꼬리의 도마뱀 같은 용, 날개 없음 |
| horned | 뿔룡 | 머리에 큰 뿔과 목 프릴이 있는 네 발 용 |

예: `fire_lindworm`, `ice_fairy`, `storm_raptor`, `steel_tortoise`.

## 결과 보고
만든 파일, 크기, 투명 여부, 실패와 이유.
