// Godot 내보내기. 인수 없음: Windows 정식판·데모판 / "android": 테스트용 APK(디버그 서명) / "web": 웹판(스레드 없음, 특별한 서버 설정 없이 돌아감).
const { execFileSync } = require('node:child_process');
const { mkdirSync, writeFileSync } = require('node:fs');
const GODOT = 'C:/claude/tools/godot/Godot_v4.7.2-stable_win64_console.exe';
const jobs = process.argv[2] === 'android'
  ? [['Android', 'release-godot-android', 'Wyrmslot-debug.apk', '--export-debug']]
  : process.argv[2] === 'web'
  ? [['Web', 'release-godot-web', 'index.html', '--export-release']]
  : [
      ['Windows', 'release-godot', 'Wyrmslot.exe', '--export-release'],
      ['Windows Demo', 'release-godot-demo', 'Wyrmslot Demo.exe', '--export-release'],
    ];
for (const [preset, dir, file, mode] of jobs) {
  mkdirSync(dir, { recursive: true });
  writeFileSync(dir + '/.gdignore', '');
  execFileSync(GODOT, ['--headless', '--path', '.', mode, preset, dir + '/' + file], { stdio: 'ignore' });
  console.log('exported', dir + '/' + file);
}
