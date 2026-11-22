# 작업 카드 X5: 데스크톱(Electron) 포장

먼저 `AGENTS.md`를 읽어요.

## 목표
웹 빌드(`dist/`)를 Windows 데스크톱 앱으로 띄우는 Electron 메인 파일과 포장 설정을 만들어요. electron, electron-builder는 이미 설치돼 있어요(`package.json`의 `main`은 `apps/desktop/main.cjs`, 스크립트 `desktop`, `desktop:pack` 준비됨).

## 고칠 파일 (새로 만듦)
- `apps/desktop/main.cjs` — CommonJS(.cjs). 
- `apps/desktop/electron-builder.yml`
- `apps/desktop/README.md` — 실행·포장 방법 3~5줄

## 건드리면 안 되는 파일
`packages/**`, `data/**`, `package.json`, `package-lock.json`, `vite.config.ts`

## 요구 사항 (main.cjs)
- `dist/index.html`을 `BrowserWindow.loadFile`로 띄워요(경로는 `path.join(__dirname, '../../dist/index.html')`, 포장 후에도 맞게 `app.getAppPath()` 기준으로 처리).
- 창: 1280×720, 최소 960×540, 배경 `#0e1016`, 제목 "Wyrmslot", 메뉴 없음(`Menu.setApplicationMenu(null)`), 크기 조절 가능.
- F11: 전체화면 전환. Esc: 전체화면이면 해제.
- 보안: `contextIsolation: true`, `nodeIntegration: false`, `sandbox: true`. 새 창·외부 링크는 앱 안에서 열지 말고 `shell.openExternal`(http/https만).
- 단일 인스턴스(`requestSingleInstanceLock`).
- 웹 빌드의 이미지 경로(`dragons/<id>.png`)와 스크립트 경로가 `file://`에서도 열리는지 확인하고, 안 되면 결과에 "vite base 설정 필요"라고 적어요(vite.config.ts는 고치지 말 것).

## electron-builder.yml
- appId `com.wyrmslot.game`, productName `Wyrmslot`, 출력 `release/`, Windows 대상 `portable`(x64), 포함 파일: `dist/**`, `apps/desktop/main.cjs`, `package.json`. 아이콘은 아직 없으니 생략.

## 완료 기준
- `npm test`, `npm run typecheck` 통과(기존 테스트 유지)
- `node --check apps/desktop/main.cjs` 통과
- GUI 실행·포장은 지휘자가 확인해요(샌드박스에서 못 함).

## 결과 보고 형식
바꾼 파일, 명령 출력 꼬리, 판단한 것, file:// 경로 관련 주의점.
