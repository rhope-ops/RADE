# Fake step for the RADE engine tests: it needs the hand step T02 (manifest "after").
param([string]$Id, [switch]$NoPause)
$null = $Id; $null = $NoPause
Write-Output 'PASS sample verify'
