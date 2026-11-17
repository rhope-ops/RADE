# Fake optional step for the RADE engine tests (default off): it prints one PASS line and changes nothing.
# Parameters (used by RADE): -Id, -NoPause. Run target: Windows PowerShell 5.1 and pwsh 7.
param([string]$Id, [switch]$NoPause)
$null = $Id; $null = $NoPause
Write-Output 'PASS sample optional'
