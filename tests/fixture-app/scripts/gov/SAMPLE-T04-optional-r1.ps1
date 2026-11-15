# Fake optional step for the RADE engine tests (default off).
param([string]$Id, [switch]$NoPause)
$null = $Id; $null = $NoPause
Write-Output 'PASS sample optional'
