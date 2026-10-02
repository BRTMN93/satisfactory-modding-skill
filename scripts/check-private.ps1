<#
.SYNOPSIS
Fails if any line of local/private-strings.txt appears in the skill's publishable files.
Run before every commit of the skill (references/learning.md, section 6).
#>
$root = Split-Path $PSScriptRoot
$list = Join-Path $root 'local\private-strings.txt'
if (-not (Test-Path $list)) { Write-Host "No $list, nothing to check"; exit 0 }
$needles = Get-Content $list | Where-Object { $_.Trim() }
$files = Get-ChildItem $root -Recurse -File -Force |
    Where-Object { $_.FullName -notlike (Join-Path $root 'local\*') -and $_.FullName -notlike (Join-Path $root '.git\*') }
$hits = foreach ($n in $needles) { $files | Select-String -SimpleMatch -Pattern $n | ForEach-Object { "{0}:{1}: {2}" -f $_.Path.Substring($root.Length + 1), $_.LineNumber, $n } }
if ($hits) { $hits; Write-Host "Private strings found, do not commit"; exit 1 }
Write-Host 'Clean'
