<#
.SYNOPSIS
Dedicated VRAM used by the running Satisfactory process, in GB.
Task Manager's GPU memory graph sums every process, this counts only the game.

.EXAMPLE
.\vram.ps1    # run ~10 s after each save load; a leak shows as growth across loads
#>
param([string] $Process = 'FactoryGame*-Win64-Shipping')

$p = Get-Process $Process -ErrorAction Stop | Select-Object -First 1
$samples = (Get-Counter "\GPU Process Memory(pid_$($p.Id)*)\Dedicated Usage").CounterSamples
'{0:HH:mm:ss}  {1:N2} GB' -f (Get-Date), (($samples | Measure-Object CookedValue -Sum).Sum / 1GB)
