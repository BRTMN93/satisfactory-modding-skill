<#
.SYNOPSIS
Finds the modding environment and its versions, compares them with the "Verified on" line of SKILL.md and saves the result in local/env.md.
Detects <Game> (Steam library with app 526870), <UE-CSS> (engine builds registered by the CSS installer) and their versions,
the SML version installed in the game, and with -Project the starter project's header changelist. Read-only except local/env.md.
.PARAMETER Project
Folder with FactoryGame.uproject. Remembered in local/env.md, so it is needed only once.
.PARAMETER Game
Game folder, when it is not a Steam install (EGS) or detection picks the wrong one.
.PARAMETER Engine
CSS engine folder, when detection picks the wrong one.
#>
param([string]$Project = '', [string]$Game = '', [string]$Engine = '')
$root = Split-Path $PSScriptRoot
$envFile = Join-Path $root 'local\env.md'
$old = @{}
if (Test-Path $envFile) { Get-Content $envFile | ForEach-Object { if ($_ -match '^- (\w+): `(.*)`$') { $old[$Matches[1]] = $Matches[2] } } }
if (-not $Project) { $Project = $old['Project'] }
if (-not $Game) { $Game = $old['Game'] }
if (-not $Engine) { $Engine = $old['Engine'] }

if (-not $Game) {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    $vdf = if ($steam) { Join-Path $steam 'steamapps\libraryfolders.vdf' }
    if ($vdf -and (Test-Path $vdf)) {
        $lib = $null
        foreach ($l in Get-Content $vdf) {
            if ($l -match '"path"\s+"(.+)"') { $lib = $Matches[1].Replace('\\', '\') }
            if ($l -match '"526870"' -and $lib) { $Game = Join-Path $lib 'steamapps\common\Satisfactory'; break }
        }
    }
}
if (-not $Engine) {
    $builds = Get-ItemProperty 'HKCU:\Software\Epic Games\Unreal Engine\Builds' -ErrorAction SilentlyContinue
    if ($builds) { $Engine = ($builds.PSObject.Properties | Where-Object { $_.Name -like '*CSS*' } | Select-Object -First 1).Value }
}

function Json($f) { if ($f -and (Test-Path $f)) { Get-Content $f -Raw | ConvertFrom-Json } }
$gv = Json (Get-ChildItem (Join-Path "$Game" 'Engine\Binaries\Win64') -Filter *.version -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
$sml = Json (Join-Path "$Game" 'FactoryGame\Mods\SML\SML.uplugin')
$ev = Json (Join-Path "$Engine" 'Engine\Build\Build.version')
$hdr = if ($Project -and (Test-Path (Join-Path $Project 'Source\FactoryGame\currentVersion.txt'))) { (Get-Content (Join-Path $Project 'Source\FactoryGame\currentVersion.txt') -Raw).Trim() }

$tag = if ($ev) { '{0}.{1}.{2}-css-{3}' -f $ev.MajorVersion, $ev.MinorVersion, $ev.PatchVersion, $ev.Changelist }
$found = [ordered]@{
    Game = $Game; GameChangelist = $gv.Changelist; GameVersion = $gv.GameVersion; GameBranch = $gv.BranchName
    SML = $sml.VersionName
    Engine = $Engine; EngineTag = $tag
    Project = $Project; HeaderChangelist = $hdr
}

$warn = @()
$verified = (Get-Content (Join-Path $root 'SKILL.md') | Where-Object { $_ -like 'Verified on:*' } | Select-Object -First 1)
if ($verified -match 'changelist (\d+)' -and $gv -and "$($gv.Changelist)" -ne $Matches[1]) { $warn += "game changelist $($gv.Changelist), the skill is verified on $($Matches[1]): re-check statements a task depends on (references/learning.md, section 2)" }
if ($verified -match 'SML (\d+\.\d+\.\d+)' -and $sml -and $sml.VersionName -ne $Matches[1]) { $warn += "SML $($sml.VersionName), the skill is verified on $($Matches[1])" }
if ($verified -match '(\d+\.\d+\.\d+-css-\d+)' -and $found.EngineTag -and $found.EngineTag -ne $Matches[1]) { $warn += "engine $($found.EngineTag), the skill is verified on $($Matches[1])" }
if ($hdr -and $gv -and $hdr -ne "$($gv.Changelist)") { $warn += "starter project headers are for changelist $hdr, the game is $($gv.Changelist) (references/patterns-and-pitfalls.md, pitfall 16)" }
foreach ($k in 'Game', 'Engine') { if (-not $found[$k] -or -not (Test-Path $found[$k])) { $warn += "$k not found: pass -$k <folder>" } }
if (-not $Project) { $warn += 'project unknown: pass -Project <folder with FactoryGame.uproject> once' }

$out = @('# Modding environment (written by scripts/doctor.ps1)', '', "Checked: $(Get-Date -Format 'yyyy-MM-dd HH:mm')", '')
$out += $found.Keys | ForEach-Object { "- ${_}: ``$($found[$_])``" }
$out += ''; $out += $warn | ForEach-Object { "- WARNING: $_" }
New-Item -ItemType Directory -Force (Split-Path $envFile) | Out-Null
$out | Set-Content $envFile -Encoding UTF8
$found.Keys | ForEach-Object { '{0,-17} {1}' -f $_, $found[$_] }
$warn | ForEach-Object { "WARNING: $_" }
if (-not $warn) { 'Versions match the skill.' }
