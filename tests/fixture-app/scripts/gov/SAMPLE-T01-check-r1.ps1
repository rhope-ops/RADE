# Fake step for the RADE engine tests (tests/engine_test.sh). Reads this computer only.
param([string]$Id, [switch]$NoPause)
$null = $Id; $null = $NoPause
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'SAMPLE-T01-result-r1.txt'), 'sample result')
Write-Output ('contract=' + $env:RADE_CONTRACT + ' mode=' + $env:RADE_MODE + ' version=' + $env:RADE_APP_VERSION + ' installed=' + $env:RADE_INSTALLED_VERSION + ' last=' + $env:RADE_STEP_LAST + ' site=' + [bool]$env:RADE_SITE)
Write-Output 'MADE file: SAMPLE-T01-result-r1.txt'
Write-Output ('MADE list: Sample FAIL list at https://fake.example/sites/x and usaf.dps.mil/sites/fake and /sites/fake for ' + $Id)
Write-Output 'MADE backup of nothing (prose, not a record)'
Write-Output ('PASS sample check: PowerShell ' + $PSVersionTable.PSVersion.Major)
