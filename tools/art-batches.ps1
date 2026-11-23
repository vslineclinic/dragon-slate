# 작업 카드 A5: 코덱스에게 새 기본 용 그림을 형태 두 가지씩(12장) 네 묶음으로 차례로 맡긴다.
# 묶음이 끝날 때마다 작업본(dragon-game-codex)에 그림만 커밋한다(코덱스는 커밋하지 않는다).
$ErrorActionPreference = 'Continue'
$work = 'C:\claude\dragon-game-codex'
$elements = 'fire', 'ice', 'storm', 'poison', 'steel', 'abyss'
$batches = @(@('lindworm', 'amphiptere'), @('wyrm', 'tortoise'), @('fairy', 'raptor'), @('gecko', 'horned'))
foreach ($forms in $batches) {
    $ids = foreach ($form in $forms) { foreach ($element in $elements) { "${element}_$form" } }
    $list = $ids -join ', '
    $prompt = "docs/tasks/A5-base-dragons-art.md 작업 카드를 읽고 그대로 해 주세요. image_gen 도구를 써도 됩니다. 이번 목록(12장): $list. 파일은 art/dragons-src/<id>.png 로만 저장하고 다른 파일은 고치지 마세요. 테스트나 typecheck는 돌리지 않아도 됩니다. git commit은 하지 마세요."
    $result = & 'C:\claude\ai-team\Invoke-Worker.ps1' -Worker codex -Mode build -WorkDir $work -Effort medium -TimeoutSec 1800 -Prompt $prompt
    "BATCH $($forms -join '+') status=$($result.Status) changed=$($result.ChangedFiles.Count) protected=$($result.ProtectedChanges.Count)"
    git -C $work add art/dragons-src
    git -C $work commit -q -m "art: A5 base dragons ($($forms -join ', ')) (Codex image_gen)"
    git -C $work status --short
}
'ALL DONE'
