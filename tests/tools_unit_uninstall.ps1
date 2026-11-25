# RADE test: the Maintenance tools Uninstall and Remove RADE (engine-v40; 90-161.Z R43 E3), part 2 of tests/tools_unit.ps1.
# Dot-sourced by tests/tools_unit.ps1 at its end: it uses that file's scope (the engine parts, the fake PnP site, Assert-Case,
# $base, $Dir); it does not run alone.
# Network: none (the fake PnP refuses every address but the fake site's).
# Writes: only inside the scratch folder tools_unit.ps1 is given.
# Credentials: none.
# Runs on PowerShell 7 (the cloud tests).
# ---- Uninstall (engine-v40; 90-161.Z R43 E3): the gate, the backup first, the steps with RADE_MODE=uninstall and
# RADE_MADE, the stop at the first step that is not done, and the record (answer 2A: whole = not installed, history kept).
$stepMinutes = 5; $script:dodid = 'fake'; $signInLost = 'smart ?card'; $uScript = @'
param([string]$Id, [switch]$NoPause)
Write-Output ('PASS mode ' + $env:RADE_MODE)
$got = $env:RADE_MADE -and (Test-Path -LiteralPath $env:RADE_MADE) -and ((Get-Content -LiteralPath $env:RADE_MADE -Raw) -match 'Sample Tasks')
if ($got) { Write-Output 'PASS made list' } else { Write-Output 'FAIL no made list' }
if ($env:RADE_FAKE_UFAIL -eq '1') { Write-Output 'FAIL could not remove' }
'@
$steps = @(@{ Name = 'T01-make'; Title = ''; Dir = 'T01'; File = 'make.ps1'; Kind = 'script'; Args = ''; AskParam = ''; Minutes = 0 },
  @{ Name = 'U01-remove'; Title = 'Remove the lists'; Dir = 'U01'; File = 'remove.ps1'; Kind = 'script'; Args = ''; AskParam = ''; Minutes = 0 },
  @{ Name = 'U02-again'; Title = ''; Dir = 'U01'; File = 'remove.ps1'; Kind = 'script'; Args = ''; AskParam = ''; Minutes = 0 })
$files = @(@{ Dir = 'U01'; Name = 'remove.ps1'; Kind = 'text'; Sha = 'x'; Data = $uScript })
$script:app = @{ Name = 'Sample app'; Version = '1.0.0'; Mode = 'deploy'; Marker = $null; Steps = @(0); Uninstall = @(1, 2); Backup = @('Sample Tasks')
  Restore = @{ TestSites = @('other'); Local = $false; Pause = $null } }
Set-Fake @{ admin = $true; rights = $true; list = $true; rows = @{}; items = @{ 'Sample Tasks' = @(@{ Title = 'One' }) } }   # a fresh fake site
$null = Save-Installed 'PASSED' $true @{ 'T01-make' = @{ state = 'PASSED'; made = @(@{ kind = 'list'; name = 'Sample Tasks' }) } }
$key = Get-InstalledKey $script:app
# A site that is not a test site: nothing runs, nothing is backed up.
$nb = @(Get-ChildItem -LiteralPath (Join-Path $base 'Backups') -Directory -ErrorAction SilentlyContinue).Count
$u = Invoke-Uninstall $base $null $null
$nb2 = @(Get-ChildItem -LiteralPath (Join-Path $base 'Backups') -Directory -ErrorAction SilentlyContinue).Count
Assert-Case 'uninstall: refuses a site that is not a test site, and backs up nothing' ($u.State -eq 'refused' -and $nb2 -eq $nb -and ($u.Lines -join ' ') -like '*Uninstall runs only on a test site*')
# A test site, a backup that misses a list: no step runs, the record stays.
$script:app.Restore.TestSites = @('fake'); $script:app.Backup = @('Sample Tasks', 'Sample Missing')
$u = Invoke-Uninstall $base $null $null
Assert-Case 'uninstall: a backup that misses a list stops it before any step' ($u.State -eq 'no-backup' -and -not (Test-Path -LiteralPath (Join-Path $base 'U01')) -and (Read-Installed $key).installed)
# A step that fails: the run stops there, the next step does not run, the record stays installed with NEEDS REVIEW.
$script:app.Backup = @('Sample Tasks'); $env:RADE_FAKE_UFAIL = '1'
$u = Invoke-Uninstall $base $null $null; $e = Read-Installed $key; $env:RADE_FAKE_UFAIL = $null
Assert-Case 'uninstall: a step that is not done stops it; the record stays installed, NEEDS REVIEW' ($u.State -eq 'review' -and $e.installed -and $e.lastRun.state -eq 'NEEDS REVIEW' -and
  @($u.Lines | Where-Object { $_ -like 'Not run: 1 step(s) after "Remove the lists".' }).Count -eq 1 -and $e.steps.Contains('T01-make'))
# Every step done: the steps see RADE_MODE=uninstall and the made list; the record is not installed, keeps the history.
$sp = Get-RoundStatePath $base; $null = New-Item -ItemType Directory -Path (Split-Path -Parent $sp) -Force; Set-Content -LiteralPath $sp -Value '{}'   # saved progress of an install round
$u = Invoke-Uninstall $base $null $null
$e = Read-Installed $key; $raw = (Read-InstalledRaw $key).Json; $rep = $(if ($u.Path) { Get-Content -LiteralPath $u.Path -Raw } else { '' })
Assert-Case 'uninstall: every step done clears installed and the steps, lastRun UNINSTALLED' ($u.State -eq 'done' -and -not $e.installed -and $e.steps.Count -eq 0 -and
  $e.lastRun.state -eq 'UNINSTALLED')
Assert-Case 'uninstall: the record keeps the version and the made list under "uninstalled"' ([string]$raw.uninstalled.version -eq '1.0.0' -and @($raw.uninstalled.made).Count -eq 1)
Assert-Case 'uninstall: the steps got RADE_MODE=uninstall and RADE_MADE (the report says so)' ($rep -match 'mode uninstall' -and $rep -match 'made list' -and $rep -notmatch 'no made list')
$nBk = @(Get-ChildItem -LiteralPath (Join-Path $base 'Backups') -Directory).Count
Assert-Case 'uninstall: the step file came from the paste; the backups stay' ((Test-Path -LiteralPath (Join-Path $base 'U01\remove.ps1')) -and $nBk -ge 3)
Assert-Case 'uninstall: the step env holds RADE_MODE=uninstall only during the run' ($null -eq $script:stepEnvExtra -and (Get-StepEnv $base $steps[1]).RADE_MODE -eq 'deploy')
Assert-Case 'uninstall: a whole Uninstall removes the saved progress of the round (review of PR 194)' (-not (Test-Path -LiteralPath $sp))
# A record of a newer RADE: Uninstall runs no step and says why (review of PR 194).
$recPath = (Read-InstalledRaw $key).Path; $recText = [System.IO.File]::ReadAllText($recPath); [System.IO.File]::WriteAllText($recPath, $recText.Replace('rade-installed/2', 'rade-installed/9'))
$u = Invoke-Uninstall $base $null $null; [System.IO.File]::WriteAllText($recPath, $recText)
Assert-Case 'uninstall: a record of a newer RADE stops it before the backup and any step' ($u.State -eq 'refused' -and ($u.Lines -join ' ') -like '*may not change `[newer`]*')
# ---- Remove RADE (engine-v40, E3 b, option A): off while an app is installed; then RADE's own files go, Backups stay.
$keepRec = [System.IO.File]::ReadAllText((Read-InstalledRaw $key).Path)
$script:app.Uninstall = @(); $null = Save-Installed 'PASSED' $true @{ 'T01-make' = @{ state = 'PASSED'; made = @() } }
$rr = Invoke-RemoveRade
$cfgThere = Test-Path -LiteralPath (Join-Path $Dir 'RADE\Config')
Assert-Case 'remove RADE: blocked while an app is installed; the card names it' ($rr.State -eq 'blocked' -and ($rr.Lines -join ' ') -like '*Sample app*' -and $cfgThere)
[System.IO.File]::WriteAllText((Read-InstalledRaw $key).Path, $keepRec)   # back to the uninstalled record
Set-Content -LiteralPath (Join-Path $Dir 'RADE\rade-runner.ps1') -Value '# runner'; $null = New-Item -ItemType Directory -Path (Join-Path $Dir 'RADE\Other') -Force
$rr = Invoke-RemoveRade; $left = @(Get-ChildItem -LiteralPath $base -Force | ForEach-Object { $_.Name })
Assert-Case 'remove RADE: Config, the runner and the app files go; Backups stays' ($rr.State -eq 'done' -and -not (Test-Path -LiteralPath (Join-Path $Dir 'RADE\Config')) -and
  -not (Test-Path -LiteralPath (Join-Path $Dir 'RADE\rade-runner.ps1')) -and ($left -join ',') -eq 'Backups')
Assert-Case 'remove RADE: a folder that no record names stays' (Test-Path -LiteralPath (Join-Path $Dir 'RADE\Other'))
# A record whose key names a folder outside RADE ("..") or an odd name: no folder outside RADE is touched.
$null = New-Item -ItemType Directory -Path (Join-Path $Dir 'RADE\Config\installed') -Force; Set-Content -LiteralPath (Join-Path $Dir 'keep.txt') -Value 'x'
'{"schema":"rade-installed/2","key":"../x","installed":null}' | Set-Content -LiteralPath (Join-Path $Dir 'RADE\Config\installed\aaaaaaaaaaaa.json')
'{"schema":"rade-installed/2","key":"Config./z","installed":null}' | Set-Content -LiteralPath (Join-Path $Dir 'RADE\Config\installed\cccccccccccc.json')
'{"schema":"rade-installed/2","key":"Other/y","installed":null}' | Set-Content -LiteralPath (Join-Path $Dir 'RADE\Config\installed\bbbbbbbbbbbb.json')
$odd = @(Get-RadeAppDir | ForEach-Object { Split-Path -Leaf $_ })
Assert-Case 'remove RADE: a key with ".." or "Config." names no folder; a plain one names its folder' (-not ($odd -contains '..') -and -not ($odd -like 'Config*') -and ($odd -contains 'Other') -and
  @($odd | Where-Object { -not (Test-Path -LiteralPath (Join-Path (Join-Path $Dir 'RADE') $_)) }).Count -eq 0)
$okNames = @('SampleApp', '90-161.Z', 'App_1', 'A b') | Where-Object { Test-RadeAppName $_ }
$noNames = @('..', '.', './x', 'Config', 'config', 'Config.', 'x.', 'x ', ' x', '.git', 'Backups', 'C:', '') | Where-Object { Test-RadeAppName $_ }
Assert-Case 'remove RADE: the app folder name test takes plain names only (no trim to another name, not Config or Backups)' (@($okNames).Count -eq 4 -and @($noNames).Count -eq 0)
$null = Invoke-RemoveRade
Assert-Case 'remove RADE: nothing outside the RADE folder is touched' (Test-Path -LiteralPath (Join-Path $Dir 'keep.txt'))
