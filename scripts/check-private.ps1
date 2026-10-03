<#
.SYNOPSIS
Fails if the skill's publishable files (or a commit message) contain private data.
Checks every line of local/private-strings.txt and a set of generic patterns (path with a
user name, e-mail address, Steam ID, IPv4 address, access token).
Run before every commit of the skill (references/learning.md, section 7).
.PARAMETER Message
Optional commit message text to check as well.
#>
param([string]$Message = '')
$root = Split-Path $PSScriptRoot
$list = Join-Path $root 'local\private-strings.txt'
$files = Get-ChildItem $root -Recurse -File -Force |
    Where-Object { $_.FullName -notlike (Join-Path $root 'local\*') -and $_.FullName -notlike (Join-Path $root '.git\*') -and $_.FullName -ne $PSCommandPath }

$hits = @()
if (Test-Path $list) {
    $needles = Get-Content $list | Where-Object { $_.Trim() }
    foreach ($n in $needles) {
        $hits += $files | Select-String -SimpleMatch -Pattern $n | ForEach-Object { "{0}:{1}: your private string" -f $_.Path.Substring($root.Length + 1), $_.LineNumber }
        if ($Message -and $Message.Contains($n)) { $hits += "commit message: your private string" }
    }
} else {
    Write-Warning "No ${list}: only the generic patterns are checked. Create it with your own private strings (references/learning.md, section 7)."
}

$generic = [ordered]@{
    'path with a user name' = '(?i)(C:\\Users\\(?!Public\b|Default\b|All Users\b)[^\\\s<>%`"'']+|/home/[^/\s<>]+|/Users/[^/\s<>]+)'
    'e-mail address'        = '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}'
    'Steam ID'              = '\b7656119\d{10}\b'
    'IPv4 address'          = '(?<![\w.])(?!127\.0\.0\.1\b|0\.0\.0\.0\b)(25[0-5]|2[0-4]\d|1?\d?\d)(\.(25[0-5]|2[0-4]\d|1?\d?\d)){3}(?!\.\w|\w)'
    'access token'          = '\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})\b'
}
foreach ($name in $generic.Keys) {
    $re = $generic[$name]
    $hits += $files | Select-String -Pattern $re | ForEach-Object { "{0}:{1}: {2}" -f $_.Path.Substring($root.Length + 1), $_.LineNumber, $name }
    if ($Message -and $Message -match $re) { $hits += "commit message: $name" }
}

if ($hits) { $hits; Write-Host "Private data found, do not commit or push"; exit 1 }
Write-Host 'Clean'
