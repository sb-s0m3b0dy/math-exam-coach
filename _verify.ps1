# uni-skills 自检脚本
# 用法（本机执行策略禁止直接运行 .ps1，用 scriptblock 调用）：
#   # 检查某个技能仓库：
#   & ([scriptblock]::Create((Get-Content "<技能目录>\_verify.ps1" -Raw -Encoding UTF8))) -Root "<技能目录>"
#   # 检查父目录下的全部技能（父目录需同时含各技能目录）：
#   & ([scriptblock]::Create((Get-Content "<父目录>\_verify.ps1" -Raw -Encoding UTF8))) -Root "<父目录>"
# 通过 -Root 定位，不依赖绝对路径，所以可随仓库分发到任何机器。
# 注意：脚本内的占位符扫描会查运行时出现的那条命令，这是运行痕迹，不是文件里的占位符。
#
# 新增技能时：必须在下面的 $canonicalSources 里登记该技能的"状态源文件"（含表头定义的那个），
# 否则自检会报 FAIL。登记后，其它文件里的表头会被拿来和状态源逐列比对，防止再次出现
# "视图表头少一列、数据只能扔掉"的问题。

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
  $singleSkillRoot = $true
} else {
  $dirs = @(Get-ChildItem $Root -Directory | Where-Object { Test-Path (Join-Path $_.FullName "SKILL.md") })
  $singleSkillRoot = $false
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

# ---- schema 列一致性：视图表头必须与状态源 schema 完全一致 ----
# 起因：error-tracking.md 把某列声明为"必填"，SKILL.md 的表头却没有那列 → 会真丢数据（曾发生）。
# 规则来源是状态源文件里的表头本身，不硬编码列名，所以改 schema 时这条检查自动跟着变。
Write-Output "=== schema: view header vs canonical schema ==="
$mdFiles = @(Get-ChildItem $Root -Recurse -File -Filter *.md |
  Where-Object { $_.FullName -notmatch '[\\/](\.git|node_modules|bin|obj|archive|导出)[\\/]' } |
  Select-Object -ExpandProperty FullName)

function Get-HeaderCells([string[]]$arr, [int]$start) {
  # 找 $start 之后的第一条表格行（跳过代码围栏标记与 |---|---| 分隔行）
  for ($i = $start; $i -lt $arr.Count; $i++) {
    $line = $arr[$i].Trim()
    if ($line -notmatch '^\|') { continue }
    $cells = @($line.Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
    $isSep = $true
    foreach ($c in $cells) { if ($c -ne '' -and $c -notmatch '^:?-{2,}:?$') { $isSep = $false; break } }
    if ($isSep) { continue }
    if ($cells.Count -gt 1) { return $cells }
  }
  return $null
}

# ① 每个技能的规范 schema 来源文件（状态源所在文件）。新增技能时必须在此登记。
$canonicalSources = @{
  'math-exam-coach' = 'references\error-tracking.md'
  'time-planner'    = 'references\task-pool.md'
}

$viewCount = 0
foreach ($skillDir in $dirs) {
  $skillName = $skillDir.Name
  if (-not $canonicalSources.ContainsKey($skillName)) {
    Check $false "$skillName has no canonical schema source registered in _verify.ps1"
    continue
  }
  $canonPath = Join-Path $skillDir.FullName $canonicalSources[$skillName]
  Check (Test-Path $canonPath) "$skillName canonical schema file exists: $($canonicalSources[$skillName])"
  if (-not (Test-Path $canonPath)) { continue }

  # 规范列 = 状态源文件里每个「表头（列名固定…）」锚点后的表头
  $canonLines = @((Get-Content $canonPath -Raw -Encoding UTF8) -split "\r?\n")
  $canonSet = New-Object System.Collections.ArrayList
  for ($j = 0; $j -lt $canonLines.Count; $j++) {
    if ($canonLines[$j] -match '表头（列名固定') {
      $hc = Get-HeaderCells $canonLines $j
      if ($hc) { [void]$canonSet.Add($hc) }
    }
  }
  Check ($canonSet.Count -gt 0) "$skillName canonical schema parsed from $(Split-Path $canonPath -Leaf) ($($canonSet.Count) schema(s))"
  if ($canonSet.Count -eq 0) { continue }
  Write-Output "  INFO $skillName canonical: $(($canonSet | ForEach-Object { $_.Count }) -join ',') columns"

  # ② 该技能内**其它**文件的声明视图，必须与某套规范 schema 完全一致（列名与列数都要对）
  $skillFiles = @(Get-ChildItem $skillDir.FullName -Recurse -File -Filter *.md |
    Where-Object { $_.FullName -notmatch '[\\/](\.git|node_modules|archive|导出)[\\/]' })
  foreach ($vf in $skillFiles) {
    if ($vf.FullName -eq $canonPath) { continue }   # 规范自身的表头不作为视图比对
    $va = @((Get-Content $vf.FullName -Raw -Encoding UTF8) -split "\r?\n")
    $vh = -1
    for ($j = 0; $j -lt $va.Count; $j++) { if ($va[$j] -match '表头（列名固定') { $vh = $j; break } }
    if ($vh -lt 0) { continue }
    $vcells = Get-HeaderCells $va $vh
    if (-not $vcells) { continue }
    $viewCount++
    $matched = $false
    foreach ($c in $canonSet) {
      if ($vcells.Count -eq $c.Count -and @($c | Where-Object { $vcells -notcontains $_ }).Count -eq 0) { $matched = $true; break }
    }
    Check $matched "$skillName/$($vf.Name) view header matches a canonical schema ($($vcells.Count) cols)"
    if (-not $matched) { Write-Output "       view: $($vcells -join ' / ')" }
  }

  # ③ 状态源自己的字段定义表：每个规范列都必须有一行定义
  # 定义行形如 | `列名` | ... |，且允许一格合并多个列名（| `开始` / `结束` | ... |）
  $defCols = @()
  foreach ($dl in $canonLines) {
    $first = [regex]::Match($dl, '^\|([^|]*)\|')
    if (-not $first.Success) { continue }
    foreach ($bm in [regex]::Matches($first.Groups[1].Value, '`([^`]+)`')) {
      $defCols += $bm.Groups[1].Value.Trim()
    }
  }
  foreach ($c in $canonSet) {
    $undef = @($c | Where-Object { $defCols -notcontains $_ })
    Check ($undef.Count -eq 0) "${skillName}: every canonical column has a definition row ($($undef.Count) undefined)"
    foreach ($u in $undef) { Write-Output "       no definition row: $u" }
  }
}
if (-not $singleSkillRoot) {
  Check ($viewCount -ge 1) "at least one view header found to compare ($viewCount)"
}
Write-Output "  INFO view headers compared: $viewCount"

Write-Output ""
if ([int]$global:verifyFailCount -eq 0) { Write-Output "ALL CHECKS PASSED" }
else { Write-Output "$($global:verifyFailCount) CHECK(S) FAILED" }

