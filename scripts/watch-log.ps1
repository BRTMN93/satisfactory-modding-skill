<#
.SYNOPSIS
Prints new lines of the Satisfactory game log that match a pattern, until the game exits.
Handles the log being renamed to FactoryGame-backup-<UTC>.log when the game starts.
It remembers a byte position in the file, so each poll reads only what was added since the last one.

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

# Read what was added since $pos. The game keeps the file open, so open it shared.
function Read-NewLog($pos) {
    $fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
    try {
        if ($fs.Length -lt $pos) { $pos = 0 }  # the game started a new log
        $fs.Seek($pos, 'Begin') | Out-Null
        $text = (New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)).ReadToEnd()
        $end = $text.LastIndexOf("`n")
        if ($end -lt 0) { return @{ Pos = $pos; Lines = @() } }  # no complete line yet
        $done = $text.Substring(0, $end)
        return @{ Pos = $pos + [System.Text.Encoding]::UTF8.GetByteCount($text.Substring(0, $end + 1)); Lines = $done -split "`r?`n" }
    } finally { $fs.Dispose() }
}

# Lines already in the log belong to the previous run (or were written before watching began)
$pos = if (Test-Path $log) { (Get-Item $log).Length } else { 0 }
while ($true) {
    $running = Get-Process $Process -ErrorAction SilentlyContinue
    if (Test-Path $log) {
        $r = Read-NewLog $pos
        $pos = $r.Pos
        $r.Lines | Where-Object { $_ -cmatch $Pattern }
    }
    if (-not $running) { '{0:HH:mm:ss} game exited' -f (Get-Date); break }
    Start-Sleep -Seconds 2
}
