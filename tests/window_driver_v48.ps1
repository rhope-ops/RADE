# RADE test: part 2 of the stand-in window driver (tests/window_driver.ps1), the checks of the review of engine-v48
# (MINOR 6) on the first Ready card. tests/engine_window.sh joins it after window_driver.ps1, in front of a test copy of a
# bundle; it does not run alone.
# Network: none.
# Writes: nothing (it prints one WIN line).
# Credentials: none.
# Runs on PowerShell 7 with the stand-in Windows Forms types (tests/window_stub.cs).

# Stands in for $ui.BandLH: a band label that needs 200 px, more than the band's 56. Takes the label.
$global:tallBandLine = { param($L) $null = $L; 200 }
# Stands in for $ui.SetCard: keeps the card's line in capitals (its raw text) and draws nothing. Takes the card.
$global:catchCard = { param($c) $global:RadeT.Kick48 = [string]$c.Kicker }
<#
.SYNOPSIS
Review of engine-v48 (MINOR 6), once on the first Ready card: prints "WIN v48-fact" with three facts.
.DESCRIPTION
band: the band height while its text needs more room ($ui.BandLH gives 200 px), then after it needs less again (back to
56 px scaled); fact: Get-AppFact of an app with one check ("1 check"); kick: the Ready card's line in capitals with one
check ("The check passed"), caught at $ui.SetCard, so the card on the screen does not change.
.OUTPUTS
Nothing; one WIN line.
#>
function global:Test-RadeV48Fact {
  if ($env:RADE_T_V48 -ne "1" -or $global:RadeT.V48Fact) { return }; $global:RadeT.V48Fact = $true; $keepLH = $ui.BandLH   # window 1 only (RADE_T_V48)
  $ui.BandLH = $global:tallBandLine
  & $ui.BandFit; $hi = $ui.Band.Height; $ui.BandLH = $keepLH; & $ui.BandFit; $lo = $ui.Band.Height; $want = & $ui.Sc $ui.Z.BandH
  $fact = [string](Get-AppFact @{ Steps = @(); Checks = @('one'); Mode = 'test' } $ui.Hist).Steps
  $keepC = $script:appChecks; $keepSet = $ui.SetCard; $ui.SetCard = $global:catchCard
  try { $script:appChecks = @(@($keepC)[0]); & $ui.VReady } finally { $ui.SetCard = $keepSet; $script:appChecks = $keepC }; $kick = [string]$global:RadeT.Kick48
  Write-Host ('WIN v48-fact band-high=' + [bool]($hi -gt $want) + ' band-back=' + [bool]($lo -eq $want) + ' fact-end=' + (($fact -split [regex]::Escape($dot))[-1]) + ' kick=' + $kick)
}
