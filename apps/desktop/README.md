# Wyrmslot 데스크톱

저장소 루트에서 `npm run desktop`으로 웹 빌드를 만들고 Electron으로 실행합니다.
`npm run desktop:pack`으로 Windows x64 포터블 실행 파일을 `release/`에 만듭니다.
두 명령을 실행하기 전에 Vite의 `base`를 `'./'`로 설정해야 `file://`에서 번들 경로가 맞습니다.
