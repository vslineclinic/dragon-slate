# 작업 카드 A4: 계급 피라미드용 새 드래곤 그림 24장 (image_gen)

코드는 고치지 않아요. image_gen은 이 환경에 내장된 이미지 도구라 써도 돼요(A1·A2·A3에서 같은 방식으로 만들었어요). 네트워크 금지는 패키지 설치·웹 접근에 대한 규칙이에요.

## 저장
`art/dragons-src/<id>.png` (정사각형, 1024 이상, 배경 투명). 기존 파일은 건드리지 않아요. 이번 호출에서 만들 id는 질문 끝 "이번 목록"만. git commit·reset·push는 하지 않아요.

## 화풍 (기존 `art/dragons-src/*.png`과 똑같이. 먼저 몇 장을 열어 보고 맞춰요)
Original 2D game sprite. Bold black outlines, flat colors, exactly two levels of hard-edged cel shadow. Slightly oversized head, cute but strong proportions. Left-facing three-quarter side view, whole body visible with margin, centered. Transparent background. No ground, shadow, scenery, text, border or watermark. Original design, must not resemble any existing game or animation character. No flame on the tail tip.

원소 색: 불 = 주황·빨강, 얼음 = 하늘색·흰색, 번개 = 노랑·남색, 독 = 연두·보라 독기, 강철 = 은회색 금속 판갑·리벳, 심연 = 짙은 남보라·검정에 별빛 같은 점.
계급이 높을수록 장식과 위엄↑. 기본(새끼)은 작고 단순하게, 정점(룡황)은 왕관 같은 뿔·큰 날개·가장 화려하게.

## 24종
| id | 이름 | 설명 |
|---|---|---|
| fire_serpent | 불씨 서펜트 | 기본, 불. 다리 없는 작은 뱀 용, 몸에 불씨 무늬 |
| fire_whelp | 잿불 새끼용 | 기본, 불. 알에서 갓 나온 통통한 새끼 용, 작은 날개 |
| zmey_gorynych | 즈메이 고리니치 | 1티어, 불. 슬라브 전설의 머리 셋 화룡(머리 셋까지만), 위엄 |
| fire_sovereign | 화염룡황 | 정점, 불. 불꽃 왕관 뿔과 큰 날개의 용의 황제 |
| ice_serpent | 눈꽃 서펜트 | 기본, 얼음. 다리 없는 작은 뱀 용, 눈꽃 결정 비늘 |
| ice_whelp | 얼음 새끼용 | 기본, 얼음. 통통한 새끼 용, 고드름 뿔 |
| imugi | 이무기 | 1티어, 얼음. 한국 전설의 뿔 없는 거대한 물뱀 용, 차가운 물안개 |
| ice_sovereign | 빙설룡황 | 정점, 얼음. 얼음 왕관과 수정 날개의 용의 황제 |
| storm_serpent | 번개 서펜트 | 기본, 번개. 다리 없는 작은 뱀 용, 몸에 번개 줄무늬 |
| storm_whelp | 천둥 새끼용 | 기본, 번개. 통통한 새끼 용, 정전기로 선 갈기 |
| ryujin | 류진 | 1티어, 번개. 폭풍과 바다를 다스리는 동양 용왕, 수염, 여의주 |
| storm_sovereign | 뇌전룡황 | 정점, 번개. 번개 왕관 뿔과 구름 갈기의 용의 황제 |
| poison_serpent | 독니 서펜트 | 기본, 독. 다리 없는 작은 뱀 용, 큰 송곳니 |
| poison_whelp | 이끼 새끼용 | 기본, 독. 통통한 새끼 용, 등에 이끼와 버섯 |
| vasuki | 바수키 | 1티어, 독. 인도 전설의 뱀의 왕, 머리에 보석, 독기 |
| poison_sovereign | 맹독룡황 | 정점, 독. 가시 왕관과 독 날개의 용의 황제 |
| steel_serpent | 사슬 서펜트 | 기본, 강철. 다리 없는 작은 뱀 용, 사슬 같은 마디 비늘 |
| steel_whelp | 무쇠 새끼용 | 기본, 강철. 통통한 새끼 용, 투구 같은 머리 |
| colchian_dragon | 콜키스의 용 | 1티어, 강철. 황금 양털을 지키는 잠들지 않는 수호룡, 금속 비늘 |
| steel_sovereign | 강철룡황 | 정점, 강철. 왕관 투구와 칼날 날개의 갑옷 용의 황제 |
| abyss_serpent | 밤안개 서펜트 | 기본, 심연. 다리 없는 작은 뱀 용, 안개처럼 흐린 꼬리 |
| abyss_whelp | 어스름 새끼용 | 기본, 심연. 통통한 새끼 용, 빛나는 큰 눈 |
| bakunawa | 바쿠나와 | 1티어, 심연. 달을 삼키는 필리핀 전설의 바다 용, 입가에 초승달 빛 |
| abyss_sovereign | 심연룡황 | 정점, 심연. 별빛 왕관과 밤하늘 날개의 용의 황제 |

## 결과 보고
만든 파일, 크기, 투명 여부, 실패와 이유.
