// Godot Windows 내보내기: 정식판(release-godot/)과 데모판(release-godot-demo/).
const { execFileSync } = require('node:child_process');
const { mkdirSync, writeFileSync } = require('node:fs');
const GODOT = 'C:/claude/tools/godot/Godot_v4.7.2-stable_win64_console.exe';
for (const [preset, dir, file] of [
  ['Windows', 'release-godot', 'Wyrmslot.exe'],
  ['Windows Demo', 'release-godot-demo', 'Wyrmslot Demo.exe'],
]) {
  mkdirSync(dir, { recursive: true });
  writeFileSync(dir + '/.gdignore', '');
  execFileSync(GODOT, ['--headless', '--path', '.', '--export-release', preset, dir + '/' + file], { stdio: 'ignore' });
  console.log('exported', dir + '/' + file);
}
