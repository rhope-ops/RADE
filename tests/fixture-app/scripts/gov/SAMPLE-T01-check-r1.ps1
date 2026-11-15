# Fake step for the RADE engine tests (tests/engine_test.sh). Reads this computer only.
param([string]$Id, [switch]$NoPause)
$null = $Id; $null = $NoPause
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'SAMPLE-T01-result-r1.txt'), 'sample result')
Write-Output ('PASS sample check: PowerShell ' + $PSVersionTable.PSVersion.Major)
