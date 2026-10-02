<#
.SYNOPSIS
Prints new lines of the Satisfactory game log that match a pattern, until the game exits.
Handles the log being renamed to FactoryGame-backup-<UTC>.log when the game starts.

.EXAMPLE
.\watch-log.ps1 -Pattern 'LogMyMod|LogSatisfactoryModLoader|Fatal error'
#>
param(
    [string] $Pattern = 'LogSatisfactoryModLoader|LogNativeHookManager|Fatal error|World Serialization',
    [string] $Process = 'FactoryGame*-Win64-Shipping'
)

$log = "$env:LOCALAPPDATA\FactoryGame\Saved\Logs\FactoryGame.log"
while (-not (Get-Process $Process -ErrorAction SilentlyContinue)) { Start-Sleep -Seconds 2 }
'{0:HH:mm:ss} game running' -f (Get-Date)

# Lines already in the log belong to the previous run (or were written before watching began)
$seen = @(Select-String -Path $log -Pattern $Pattern -CaseSensitive -ErrorAction SilentlyContinue).Count
while ($true) {
    $running = Get-Process $Process -ErrorAction SilentlyContinue
    $lines = @(Select-String -Path $log -Pattern $Pattern -CaseSensitive -ErrorAction SilentlyContinue)
    if ($lines.Count -lt $seen) { $seen = 0 }  # the game started a new log
    $lines | Select-Object -Skip $seen | ForEach-Object { $_.Line }
    $seen = $lines.Count
    if (-not $running) { '{0:HH:mm:ss} game exited' -f (Get-Date); break }
    Start-Sleep -Seconds 2
}
