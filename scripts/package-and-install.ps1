<#
.SYNOPSIS
Packages a Satisfactory mod with RunUAT PackagePlugin (the command Alpakit runs) and, with -GameDir, installs it into the game.

.EXAMPLE
.\package-and-install.ps1 -EngineDir D:\UE\UE_5.6-CSS -Project D:\UE\MyProject\FactoryGame.uproject -Mod MyMod -GameDir D:\SteamLibrary\steamapps\common\Satisfactory
#>
param(
    [Parameter(Mandatory)] [string] $EngineDir,
    [Parameter(Mandatory)] [string] $Project,
    [Parameter(Mandatory)] [string] $Mod,
    [string] $GameDir,                          # install into this game folder when given
    [string] $Target = 'FactoryGameSteam',      # '' builds FactoryGameEGS and FactoryGameSteam
    [string] $LogFile = (Join-Path $env:TEMP "package-$Mod.log")
)

$uat = Join-Path $EngineDir 'Engine\Build\BatchFiles\RunUAT.bat'
$uatArgs = @("-ScriptsForProject=$Project", 'PackagePlugin', "-project=$Project",
    '-clientconfig=Shipping', '-serverconfig=Shipping', '-utf8output', "-DLCName=$Mod",
    '-build', '-platform=Win64', '-nocompileeditor', '-installed', '-merge')
if ($Target) { $uatArgs += "-Target=$Target" }

Write-Host "Packaging $Mod, log: $LogFile"
& $uat @uatArgs *> $LogFile
if ($LASTEXITCODE -ne 0) {
    Select-String -Path $LogFile -Pattern 'error C\d+|error LNK|fatal error|BUILD FAILED' |
        Select-Object -Last 20 | ForEach-Object { $_.Line }
    throw "Packaging failed (exit code $LASTEXITCODE), see $LogFile"
}
$zip = Join-Path (Split-Path $Project) "Saved\ArchivedPlugins\$Mod\$Mod.zip"
Write-Host "Built: $zip"
if (-not $GameDir) { return }

# The running game locks the mod's DLL
if (Get-Process -Name 'FactoryGame*' -ErrorAction SilentlyContinue) { throw 'Close the game first' }

# The install path mirrors the project: game feature mods live in Mods\GameFeatures\<Mod>, others in Mods\<Mod>.
# In the wrong folder the C++ still runs but the paks don't mount.
$relative = if (Test-Path (Join-Path (Split-Path $Project) "Mods\GameFeatures\$Mod")) { "Mods\GameFeatures\$Mod" } else { "Mods\$Mod" }
$dest = Join-Path $GameDir "FactoryGame\$relative"
$unzipped = Join-Path $env:TEMP "package-$Mod-unzipped"
if (Test-Path $unzipped) { Remove-Item -Recurse -Force $unzipped }
Expand-Archive -Path $zip -DestinationPath $unzipped
New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item -Recurse -Force (Join-Path $unzipped 'Windows\*') $dest
Remove-Item -Recurse -Force $unzipped

Write-Host "Installed to $dest"
Get-ChildItem $dest -Recurse -Filter *.dll | ForEach-Object { '{0:yyyy-MM-dd HH:mm}  {1}' -f $_.LastWriteTime, $_.Name }
