# uni-skills 自检脚本
# 用法（本机执行策略禁止直接运行 .ps1，用 scriptblock 调用）：
#   # 检查某个技能仓库：
#   & ([scriptblock]::Create((Get-Content "<技能目录>\_verify.ps1" -Raw -Encoding UTF8))) -Root "<技能目录>"
#   # 检查父目录下的全部技能（父目录需同时含各技能目录）：
#   & ([scriptblock]::Create((Get-Content "<父目录>\_verify.ps1" -Raw -Encoding UTF8))) -Root "<父目录>"
# 通过 -Root 定位，不依赖绝对路径，所以可随仓库分发到任何机器。
# 注意：脚本内的占位符扫描会查运行时出现的那条命令，这是运行痕迹，不是文件里的占位符。

param([string]$Root)

$ErrorActionPreference = "Stop"

# -Root 优先；其次 PS 给出的脚本路径；最后当前工作目录
if (-not $Root) {
  if ($PSScriptRoot) { $Root = $PSScriptRoot }
  elseif ($MyInvocation.MyCommand.Path) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
  else { $Root = (Get-Location).Path }
}

if (Test-Path (Join-Path $Root "SKILL.md")) {
  $dirs = @(Get-Item $Root)
} else {
  $dirs = @(Get-ChildItem $Root -Directory | Where-Object { Test-Path (Join-Path $_.FullName "SKILL.md") })
}

$fail = 0
function Check($cond, $msg) {
  if ($cond) { Write-Output "  OK   $msg" }
  else {
    Write-Output "  FAIL $msg"
    # 用 $global: 而不是 $script:：以 [scriptblock]::Create() 方式调用时
    # $script: 不会指向调用方的脚本作用域，计数会静默失效（曾导致坏技能也报 PASSED）。
    $global:verifyFailCount = [int]$global:verifyFailCount + 1
  }
}
$global:verifyFailCount = 0

if ($dirs.Count -eq 0) {
  Write-Output "no skill directory found under: $Root"
  Write-Output "hint: pass -Root pointing at a directory that contains SKILL.md, or at a parent of skill directories."
  exit 1
}

foreach ($dirItem in $dirs) {
  $dir = $dirItem.FullName
  $skill = $dirItem.Name
  Write-Output "=== $skill ==="
  $skillMd = Join-Path $dir "SKILL.md"
  Check (Test-Path $skillMd) "SKILL.md exists"
  $text = Get-Content $skillMd -Raw -Encoding UTF8

  # frontmatter block
  $hasFm = $text -match '(?s)^---\r?\n(.*?)\r?\n---'
  Check $hasFm "frontmatter delimited by ---"
  $fm = ""
  if ($hasFm) { $fm = $Matches[1] }
  Check ($fm -match '(?m)^name:\s*\S+') "frontmatter has name"
  Check ($fm -match '(?m)^description:\s*\S+') "frontmatter has description"
  Check ($fm -match '(?m)^compatibility:\s*\S+') "frontmatter has compatibility"
  Check (-not ($fm -match '(?m)^allowed-tools:')) "no allowed-tools field"

  $name = ([regex]::Match($fm, '(?m)^name:\s*(\S+)')).Groups[1].Value
  Check ($name -eq $skill) "name '$name' == dir name"
  Check ($name -match '^[a-z0-9]+(?:-[a-z0-9]+)*$') "name is kebab-case"
  Check ($name.Length -le 64) "name length $($name.Length) <= 64"

  $desc = ([regex]::Match($fm, '(?m)^description:\s*(.+)$')).Groups[1].Value
  $descLen = $desc.Trim().Length
  Check ($descLen -gt 10 -and $descLen -le 1024) "description length $descLen (10..1024)"
  Check (-not ($name -match '[\s\u4e00-\u9fff]')) "name has no spaces/CJK"

  # body budget (whole file chars and lines)
  $lines = (Get-Content $skillMd).Count
  Write-Output "  INFO SKILL.md: $($text.Length) chars, $lines lines"

  # referenced files exist
  $files = Get-ChildItem $dir -Recurse -File
  Write-Output "  INFO files: $($files.Count)"
  $refs = [regex]::Matches($text, 'references/[a-z0-9\-]+\.md') | ForEach-Object { $_.Value } | Sort-Object -Unique
  foreach ($r in $refs) {
    $p = Join-Path $dir ($r -replace '/', '\')
    Check (Test-Path $p) "reference exists: $r"
  }
  $trefs = [regex]::Matches($text, 'templates/[a-z0-9\-]+\.md') | ForEach-Object { $_.Value } | Sort-Object -Unique
  foreach ($r in $trefs) {
    $p = Join-Path $dir ($r -replace '/', '\')
    Check (Test-Path $p) "template exists: $r"
  }

  # required policy strings present in SKILL.md body
  $required = @{
    "math-exam-coach" = @("答案释放门控", "无法判定", "可复现性", "退役", "00-learner.md", "questions.md", "降级", "不得改动", "错题本.md")
    "time-planner"    = @("80%", "缓冲", "顺延", "完成率", "不发送离线通知", "默认只读", "不写", "00-learner.md", "睡眠时间不排任务", "降级")
  }
  foreach ($k in $required[$skill]) {
    Check ($text -match [regex]::Escape($k)) "body mentions '$k'"
  }

  # no TODO / placeholder — 全目录递归扫，不只顶层
  $bad = @(Get-ChildItem $dir -Recurse -File -Filter *.md | ForEach-Object {
    Select-String -Path $_.FullName -Pattern 'TODO|FIXME|占位|待填'
  })
  Check ($bad.Count -eq 0) "no TODO/placeholder markers anywhere in $skill ($($bad.Count) found)"
  foreach ($b in $bad) { Write-Output "       $($b.Path):$($b.LineNumber): $($b.Line.Trim())" }
}

# ---- 跨文件一致性：题型家族集合必须等于分册标题集合 ----
# 只在能找到 math-exam-coach 的 references 时检查；单独装 time-planner 时跳过。
$refDir = $null
$probe = $Root
for ($i = 0; $i -lt 4 -and -not $refDir; $i++) {
  foreach ($rel in @("math-exam-coach\references", "references")) {
    $cand = Join-Path $probe $rel
    if (Test-Path (Join-Path $cand "error-tracking.md")) { $refDir = $cand; break }
  }
  $parent = Split-Path -Parent $probe
  if (-not $parent -or $parent -eq $probe) { break }
  $probe = $parent
}

if (-not $refDir) {
  Write-Output "=== family table vs problem-map headings ==="
  Write-Output "  SKIP math-exam-coach not found near $Root (family check only applies when it is present)"
} else {
Write-Output "=== family table vs problem-map headings ==="
$src = @()
Get-ChildItem (Join-Path $refDir "problem-map-*.md") | ForEach-Object {
  Select-String -Path $_.FullName -Pattern '^## (.+)$' | ForEach-Object {
    $src += $_.Matches[0].Groups[1].Value.Trim()
  }
}
$src = $src | Sort-Object -Unique

$etText = Get-Content (Join-Path $refDir "error-tracking.md") -Raw -Encoding UTF8
$famBlock = [regex]::Match($etText, '(?s)## 题型家族命名.*?```\r?\n(.*?)```').Groups[1].Value
$listed = @($famBlock -split "\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }) | Sort-Object -Unique

# 已声明的例外：跳转条目（不是独立家族）
$redirectHeadings = @("空间-三重积分（柱坐标/球坐标）")

$missing = @($src | Where-Object { $listed -notcontains $_ -and $redirectHeadings -notcontains $_ })
Check ($missing.Count -eq 0) "every problem-map heading is listed in the family table ($($missing.Count) missing)"
foreach ($m in $missing) { Write-Output "       missing from table: $m" }

$extra = @($listed | Where-Object { $src -notcontains $_ -and $redirectHeadings -notcontains $_ })
Check ($extra.Count -eq 0) "family table has no stale names ($($extra.Count) stale)"
foreach ($e in $extra) { Write-Output "       stale in table: $e" }

Check ($etText -match '空间-三重积分（柱坐标/球坐标）') "cross-reference heading documented as exception"
Write-Output "  INFO families=$($listed.Count) headings=$($src.Count) redirects=$($redirectHeadings.Count)"
}

Write-Output ""
if ([int]$global:verifyFailCount -eq 0) { Write-Output "ALL CHECKS PASSED" }
else { Write-Output "$($global:verifyFailCount) CHECK(S) FAILED" }

