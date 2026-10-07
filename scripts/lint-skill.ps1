<#
.SYNOPSIS
Checks the skill's own structure. Prints every problem and then "Clean" or "N problem(s)".
- SKILL.md: at most 150 lines, description at most 1024 characters.
- Every file in references/ and domains/ is at most 30 KB, unless it has a line `<!-- size-exception: <reason> -->`.
- Every domain folder has a row in the domain table of SKILL.md, an index (domains/<name>/README.md) and an inbox (learned/<name>.md);
  every file of a domain is named in its index, every core file in SKILL.md.
- Every path in backticks (references/…, domains/…, learned/…, scripts/…, evals/…) exists; every `file.md`, "Heading" names a real heading;
  every `file.md`, section N has a heading "## N." there; numbered headings of a file run 1, 2, 3 without gaps.
- Every inbox entry (a top-level "- " line in learned/*.md) has a marker or "Evidence:" and ends with "(date, versions)".
.PARAMETER Baseline
Optional git ref (e.g. a tag taken before a restructure). Lists every line of that ref's SKILL.md, references/ and domains/
that no longer exists verbatim anywhere in them, and compares the number of [source] and [?] markers. Moved text passes;
rewritten or deleted text is listed, so each listed line can be checked by hand.
#>
param([string]$Baseline = '')
$root = Split-Path $PSScriptRoot
$p = @()
function Rel($f) { $f.FullName.Substring($root.Length + 1).Replace('\', '/') }
$skill = Get-Content (Join-Path $root 'SKILL.md') -Encoding UTF8
$kb = Get-ChildItem (Join-Path $root 'references'), (Join-Path $root 'domains') -Recurse -File -Filter *.md -ErrorAction SilentlyContinue
$md = @(Get-Item (Join-Path $root 'SKILL.md'), (Join-Path $root 'README.md')) + $kb + @(Get-ChildItem (Join-Path $root 'learned') -File -Filter *.md -ErrorAction SilentlyContinue)

# budgets
if ($skill.Count -gt 150) { $p += "SKILL.md: $($skill.Count) lines (budget 150)" }
$desc = ($skill | Where-Object { $_ -like 'description:*' } | Select-Object -First 1)
if ($desc -and ($desc.Length - 13) -gt 1024) { $p += "SKILL.md: description $($desc.Length - 13) characters (limit 1024)" }
foreach ($f in $kb) {
    if ($f.Length -gt 30KB -and -not (Select-String -Path $f.FullName -SimpleMatch '<!-- size-exception:' -Quiet)) { $p += "$(Rel $f): $([int]($f.Length / 1KB)) KB (budget 30 KB, no size-exception line)" }
}

# domains and core files are reachable
$skillText = $skill -join "`n"
foreach ($d in Get-ChildItem (Join-Path $root 'domains') -Directory -ErrorAction SilentlyContinue) {
    $n = $d.Name
    if ($skillText -notmatch "\|\s*$n\s*\|\s*``domains/$n/") { $p += "SKILL.md: no row for domain '$n' in the domain table" }
    $index = Join-Path $d.FullName 'README.md'
    if (-not (Test-Path $index)) { $p += "domains/${n}: no README.md index"; continue }
    if (-not (Test-Path (Join-Path $root "learned/$n.md"))) { $p += "domains/${n}: no inbox learned/$n.md" }
    $it = Get-Content $index -Raw -Encoding UTF8
    foreach ($f in Get-ChildItem $d.FullName -File -Filter *.md | Where-Object Name -ne 'README.md') {
        if ($it -notmatch [regex]::Escape($f.Name)) { $p += "domains/$n/README.md: does not name $($f.Name)" }
    }
}
foreach ($f in Get-ChildItem (Join-Path $root 'references') -File -Filter *.md) {
    if ($skillText -notmatch [regex]::Escape("references/$($f.Name)")) { $p += "SKILL.md: does not name references/$($f.Name)" }
}

# links, headings, section numbers
foreach ($f in $md) {
    $lines = Get-Content $f.FullName -Encoding UTF8
    $nums = @($lines | Where-Object { $_ -match '^## (\d+)\. ' } | ForEach-Object { [int]$Matches[1] })
    for ($i = 0; $i -lt $nums.Count; $i++) { if ($nums[$i] -ne $i + 1) { $p += "$(Rel $f): numbered headings run $($nums -join ','), expected 1..$($nums.Count)"; break } }
    for ($ln = 0; $ln -lt $lines.Count; $ln++) {
        $l = $lines[$ln]
        foreach ($m in [regex]::Matches($l, '`((?:references|domains|learned|scripts|evals)/[^`*<>\s]+)`')) {
            $t = $m.Groups[1].Value.TrimEnd('/', '.', ',')
            if (-not (Test-Path (Join-Path $root $t))) { $p += "$(Rel $f):$($ln + 1): missing path $t" }
        }
        foreach ($m in [regex]::Matches($l, '`([\w/.-]+\.md)`,? "([^"]+)"')) {
            $t = $m.Groups[1].Value; $h = $m.Groups[2].Value
            $c = @(Get-ChildItem $root -Recurse -File -Filter (Split-Path $t -Leaf) | Where-Object { $_.FullName.Replace('\', '/') -like "*$t" })
            if ($c -and -not (Select-String -Path $c[0].FullName -SimpleMatch $h -Quiet)) { $p += "$(Rel $f):$($ln + 1): '$h' not found in $t" }
        }
        foreach ($m in [regex]::Matches($l, '`([\w/.-]+\.md)`,? section (\d+)')) {
            $t = $m.Groups[1].Value; $s = $m.Groups[2].Value
            $c = @(Get-ChildItem $root -Recurse -File -Filter (Split-Path $t -Leaf) | Where-Object { $_.FullName.Replace('\', '/') -like "*$t" })
            if ($c -and -not (Select-String -Path $c[0].FullName -Pattern "^## $s\. " -Quiet)) { $p += "$(Rel $f):$($ln + 1): no section $s in $t" }
        }
    }
}

# inbox entries
foreach ($f in Get-ChildItem (Join-Path $root 'learned') -File -Filter *.md -ErrorAction SilentlyContinue) {
    $ln = 0
    foreach ($l in Get-Content $f.FullName -Encoding UTF8) {
        $ln++
        if ($l -notmatch '^- ') { continue }
        if ($l -notmatch '\*\*\[(source|\?)\]\*\*' -and $l -notmatch 'Evidence:') { $p += "$(Rel $f):${ln}: entry without a marker or evidence" }
        if ($l -notmatch '\((\d{4}-\d\d-\d\d|versions unknown)[^)]*\)\s*$') { $p += "$(Rel $f):${ln}: entry without (date, versions) at the end" }
    }
}

# nothing lost against a baseline
if ($Baseline) {
    $now = ($kb + @(Get-Item (Join-Path $root 'SKILL.md')) | ForEach-Object { Get-Content $_.FullName -Encoding UTF8 } | Where-Object { $_ -notlike 'Part of the*' }) -join "`n"
    $old = (& git -C $root ls-tree -r --name-only $Baseline -- SKILL.md references domains) | Where-Object { $_ -like '*.md' }
    $oldText = ''
    foreach ($o in $old) {
        $body = & git -C $root show "${Baseline}:$o"
        $oldText += (($body | Where-Object { $_ -notlike 'Part of the*' }) -join "`n") + "`n"
        $ln = 0
        foreach ($l in $body) {
            $ln++; $t = $l.Trim()
            if ($t.Length -lt 12 -or $t -match '^(#|\||```|Part of the)') { continue }
            if ($now.IndexOf($t, [StringComparison]::Ordinal) -lt 0) { $p += "lost or rewritten since ${Baseline}: ${o}:${ln}: $($t.Substring(0, [Math]::Min(110, $t.Length)))" }
        }
    }
    foreach ($mk in '[source]', '[?]') {
        $a = ([regex]::Matches($oldText, [regex]::Escape("**$mk**"))).Count; $b = ([regex]::Matches($now, [regex]::Escape("**$mk**"))).Count
        Write-Host "markers $mk : $a at $Baseline, $b now"
    }
}

$p
if ($p) { Write-Host "$($p.Count) problem(s)" } else { Write-Host 'Clean' }
