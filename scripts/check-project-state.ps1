<#
.SYNOPSIS
Checks a project's state document against references/project-hygiene.md. Prints every problem and then "Clean" or "N problem(s)".
- The file is at most -BudgetKB (default 100).
- Every open item (a line matching -OpenPattern, default an unchecked task "- [ ] ") has a line containing "Passes when:" within the
  next -Window lines (default 8).
.PARAMETER StateFile
The state document (UTF-8).
#>
param([Parameter(Mandatory)][string]$StateFile, [int]$BudgetKB = 100, [string]$OpenPattern = '^\s*[-*] \[ \] ', [int]$Window = 8)
$p = @()
$f = Get-Item $StateFile
if ($f.Length -gt $BudgetKB * 1KB) { $p += "$($f.Name): $([int]($f.Length / 1KB)) KB (budget $BudgetKB KB): archive closed sessions' entries" }
$lines = Get-Content $StateFile -Encoding UTF8
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $OpenPattern) {
        $end = [Math]::Min($lines.Count - 1, $i + $Window)
        if (-not ($lines[$i..$end] | Where-Object { $_ -like '*Passes when:*' })) { $p += "$($f.Name):$($i + 1): open item without 'Passes when:'" }
    }
}
if ($p.Count) { $p; "$($p.Count) problem(s)" } else { 'Clean' }
