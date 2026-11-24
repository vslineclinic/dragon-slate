# 웹판으로 다른 사람에게 시험받기

## 만들기

```
npm run godot:web
```

`release-godot-web/`에 웹판이 생겨요(약 88MB). 스레드를 쓰지 않는 판이라 서버에 특별한 설정(SharedArrayBuffer, COOP/COEP 헤더)이 없어도 돌아가요.
올릴 묶음은 이 폴더 안의 파일을 zip으로 묶은 것이에요(`release-godot/Wyrmslot-web.zip`, 약 55MB, `index.html`이 zip 맨 위에 있어야 해요).

내 컴퓨터에서 확인: 미리보기 설정 `wyrmslot-web`(`.claude/launch.json`) 또는
`python -m http.server 8765 --directory release-godot-web` → http://localhost:8765
(`index.html`을 파일로 바로 열면 돌아가지 않아요. 서버가 있어야 해요.)

## itch.io에 비공개로 올리기 (계정은 직접)

1. itch.io에 로그인 → 오른쪽 위 메뉴 → **Upload new project**
2. **Kind of project**: HTML
3. **Uploads**: `Wyrmslot-web.zip`을 올리고 **This file will be played in the browser**에 체크
4. **Embed options**: Viewport 1280 × 720, **Fullscreen button** 체크. SharedArrayBuffer 항목은 켜지 않아도 돼요.
5. **Visibility & access**: **Restricted** → 비밀번호를 정해요. 시험해 줄 사람에게 주소와 비밀번호를 함께 보내요.
6. 저장 → **View page**로 열어 첫 화면까지 뜨는지 확인

## 시험하는 사람에게 알려 줄 것

- PC의 크롬 · 엣지에서 하는 것을 권해요. 처음 불러올 때 약 90MB를 받아서 시간이 조금 걸려요.
- 휴대폰 브라우저는 무겁고 화면 배치가 PC 기준이라 권하지 않아요.
- 하던 판과 진행은 그 브라우저에만 저장돼요(사이트 데이터를 지우면 사라져요).
- 소리는 화면을 한 번 누른 뒤에 나와요(브라우저 규칙).
