# 작업 카드 A1: 드래곤 그림 21종 (image_gen)

코드는 고치지 않아요. 이미지 생성 도구(image_gen)로 그림만 만들어 저장해요.

## 저장 규칙
- 위치: `assets/dragons/<id>.png` (이미 있는 `fire_drake.png`는 건드리지 않아요)
- 정사각형, 1024×1024 이상, **배경 투명(알파 채널)**
- 이번 호출에서 만들 id는 질문 끝의 "이번 목록"만이에요.

## 공통 화풍 (기존 `assets/dragons/fire_drake.png`과 똑같이)
Original 2D game sprite. Bold black outlines, flat colors, exactly two levels of hard-edged cel shadow. Slightly oversized head, cute but strong proportions. Left-facing three-quarter side view, whole body visible with clear margin, centered. Transparent background. No ground, cast shadow, scenery, text, border or watermark. Must be an original design and must not resemble any existing game or animation character (특히 꼬리 끝에 불꽃을 달지 말 것).

원소 색: 불 = 주홍·용암, 얼음 = 하늘색·흰 서리, 번개 = 노랑·남색 먹구름. 티어가 높을수록 장식과 위엄이 늘어나요(기본 < 2티어 < 1티어 < 숨은 종).

## 21종 설명
| id | 이름 | 설명 |
|---|---|---|
| fire_wyvern | 화염 와이번 | 기본, 불. 두 다리와 날개가 있는 날렵한 와이번. 주황 날개막에 불씨 무늬, 꼬리 끝은 붉게 달아오른 뾰족한 바위 조각 |
| beowulf_firedrake | 베오울프 화룡 | 2티어, 불. 오래된 보물을 지키는 육중한 네 발 화룡. 진홍 비늘, 왕관처럼 솟은 뿔, 등에 금빛 장신구 |
| fafnir | 파프니르 | 2티어, 불. 탐욕스러운 뱀 같은 용. 짙은 적갈색, 뿔에 걸린 금반지, 가늘고 긴 몸을 휘감은 자세 |
| xiuhcoatl | 시우코아틀 | 2티어, 불. 청록과 불꽃색이 섞인 불뱀. 몸에 독창적인 기하학 문양, 입에서 작은 불길 |
| zhulong | 촉룡 | 1티어, 불. 거대한 붉은 뱀 용, 이마에 해처럼 빛나는 눈, 몸에서 빛이 퍼짐. 위엄 있음 |
| ice_drake | 빙하 드레이크 | 기본, 얼음. 통통한 네 발 드레이크, 등에 얼음 결정 판, 서리 낀 발톱 |
| ice_wyvern | 서리 와이번 | 기본, 얼음. 반투명한 얼음 날개의 와이번, 하늘색, 꼬리 끝 고드름 |
| palraiyuk | 팔라이유크 | 2티어, 얼음. 다리가 여섯인 얼음 늪 용, 넓적한 몸, 등에 눈 덮인 돌기 |
| north_black_dragon | 북해흑룡 오순 | 2티어, 얼음. 북쪽 바다의 검은 동양 용, 긴 몸, 수염, 몸에 서리와 파도 무늬 |
| azi_raoidita | 아지 라오이디타 | 2티어, 얼음. 겨울을 부르는 붉은 비늘의 뱀, 몸에 눈이 쌓이고 입에서 냉기 |
| kuraokami | 쿠라오카미 | 1티어, 얼음. 흰색과 하늘색의 비·눈의 신룡, 구름과 눈송이에 둘러싸인 긴 몸, 위엄 있음 |
| storm_drake | 뇌운 드레이크 | 기본, 번개. 먹구름 색 네 발 드레이크, 몸에 노란 번개 줄무늬 |
| storm_wyvern | 폭풍 와이번 | 기본, 번개. 노랑·흰 날개에서 전기가 튀는 와이번 |
| beisir | 베이시르 | 2티어, 번개. 커다란 뿔로 돌진하는 번개 드레이크, 몸에서 전기 |
| east_blue_dragon | 동해청룡 오광 | 2티어, 번개. 동쪽 바다의 푸른 동양 용, 발에 빛나는 여의주, 번개 |
| quetzalcoatl | 케찰코아틀 | 2티어, 번개. 에메랄드·금색 깃털을 두른 깃털 뱀, 깃털 끝에 불꽃 대신 전기 |
| yinglong | 응룡 | 1티어, 번개. 날개가 있는 황금빛 동양 용, 폭풍을 거느린 위엄 있는 자세 |
| thermal_dragon | 열충격룡 | 이중(불+얼음). 몸 반은 용암, 반은 얼음, 경계에서 김이 오름 |
| thunderbird | 선더버드 | 이중(불+번개). 불꽃 깃털 날개에 번개가 감긴 새 같은 용 |
| jiaolong | 교룡 | 이중(얼음+번개). 물과 얼음의 뱀 용, 파란 몸, 전기가 흐르는 수염 |
| tiamat | 원초룡 티아마트 | 숨은 종(불+얼음+번개). 머리 하나의 태초 용, 몸이 주홍·하늘·노랑으로 물듦, 우주 같은 무늬, 가장 위엄 있음 (머리 여러 개 금지) |

## 결과 보고
만든 파일 경로 목록, 각 크기와 배경 투명 여부, 실패한 것과 이유.
