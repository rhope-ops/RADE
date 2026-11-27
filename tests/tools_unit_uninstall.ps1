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
$nbA = @(Get-ChildItem -LiteralPath (Join-Path $base 'Backups') -Directory).Count; Remove-Item -LiteralPath (Join-Path $base 'U01') -Recurse -Force
$u = Invoke-Uninstall $base $null $null; [System.IO.File]::WriteAllText($recPath, $recText); $nbB = @(Get-ChildItem -LiteralPath (Join-Path $base 'Backups') -Directory).Count
Assert-Case 'uninstall: a record of a newer RADE stops it before the backup and any step' ($u.State -eq 'refused' -and ($u.Lines -join ' ') -like '*a newer RADE installed*' -and
  $nbB -eq $nbA -and -not (Test-Path -LiteralPath (Join-Path $base 'U01')))
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
# ---- Back up stall (engine-v42; 90-161.Z R44 E4): the sign-in time line, the site check and the stage time limit.
Save-SiteUrl $base 'https://usaf.dps.mil/sites/fake'   # Remove RADE above took RADE\Config, so the site address goes back
$script:app.Backup = @('Sample Tasks'); $fk = Get-Content -LiteralPath $env:RADE_FAKE_PNP -Raw | ConvertFrom-Json
$env:RADE_SIGNIN_TEST = '1'; Start-Sleep -Seconds 1; $b1 = Invoke-Backup $base $null; $env:RADE_SIGNIN_TEST = $null
Assert-Case 'back up (R44 E4, engine-v44): the result gives the sign-in time; the run log has the SIGNIN line with the host' ($b1.State -eq 'done' -and
  ($b1.Lines -join '|') -match 'The sign-in took \d+ seconds\.' -and (@($script:runLog) -join '|') -match 'Back up SIGNIN seconds=\d+ host=')
$fk | Add-Member -NotePropertyName webUrl -NotePropertyValue 'https://usaf.dps.mil/sites/other' -Force; Set-Fake $fk
Start-Sleep -Seconds 1; $b3 = Invoke-Backup $base $null
Assert-Case 'back up (R44 E4): a sign-in to another site reads nothing and says so' ($b3.State -eq 'failed' -and -not $b3.Path -and
  $b3.Lines[0] -eq 'Back up saved nothing: the sign-in connected to another site than the saved site address.')
$fk.PSObject.Properties.Remove('webUrl'); $fk | Add-Member -NotePropertyName signinSleep -NotePropertyValue 20 -Force; Set-Fake $fk
$keepStage = $toolStageSeconds; $toolStageSeconds = 3; $t0 = Get-Date; Start-Sleep -Seconds 1
$b4 = Invoke-Backup $base $null; $took = ((Get-Date) - $t0).TotalSeconds; $toolStageSeconds = $keepStage
Assert-Case 'back up (R44 E4): a sign-in that runs past the stage limit is stopped and named' ($b4.State -eq 'failed' -and $took -lt 15 -and
  $b4.Lines[0] -like 'Back up saved nothing: the sign-in did not finish in * minutes, so RADE stopped it.')
$fk.PSObject.Properties.Remove('signinSleep'); Set-Fake $fk
Assert-Case 'back up (R44 E4): the stage words name the list' ((Get-StageText 'list 1' @('Sample Tasks')) -eq 'the read of the list "Sample Tasks"' -and
  (Get-StageText 'site' @()) -eq 'the site check' -and (Get-StageText 'list 9' @('A')) -eq 'the stage "list 9"')
# ---- One shortcut for each app (engine-v42; 90-161.Z R44 E1): names, the runner path, the .ico container, Remove RADE.
$appDisplay = 'Sample - Kanon'; $keepVer = $script:app.Version; $script:app.Version = '0.1.0'
Assert-Case 'shortcut (engine-v46): the name is the app word, no version; the display name is not in it' ((Get-ShortcutName) -eq [string]$script:app.Name -and
  $(& { $appProduct = 'Kanon'; (Get-ShortcutName) -eq 'Kanon' }))
$rp = Get-RunnerPath
Assert-Case 'shortcut (R44 E1): the runner copy is RADE\runners\<12 hex>.ps1, one for each app' ((Split-Path -Parent $rp) -eq (Join-Path (Join-Path $Dir 'RADE') 'runners') -and
  (Split-Path -Leaf $rp) -match '^[0-9a-f]{12}\.ps1$' -and
  (Get-ShortcutRecord) -eq ($rp -replace '\.ps1$', '.lnk.txt'))
$ico = ConvertTo-IcoByte @([byte[]](1, 2, 3), [byte[]](4, 5)) @(16, 256)
Assert-Case 'shortcut (R44 E1): the .ico file has the header, one entry for each size (256 as 0) and the images in order' ($ico.Length -eq (6 + 32 + 5) -and $ico[2] -eq 1 -and $ico[4] -eq 2 -and
  $ico[6] -eq 16 -and $ico[22] -eq 0 -and [BitConverter]::ToUInt32($ico, 18) -eq 38 -and [BitConverter]::ToUInt32($ico, 34) -eq 41 -and $ico[38] -eq 1 -and $ico[42] -eq 5)
$script:selfText = "`$buildId = '" + $buildId + "'`n`$engineRelease = " + $engineRelease + "`n"
$saved = Save-RunnerCopy; $script:selfText = "`$buildId = '" + $buildId + "'`n`$engineRelease = " + ($engineRelease - 1) + "`n"; $older = Save-RunnerCopy
Set-Content -LiteralPath $rp -Value ("`$engineRelease = " + ($engineRelease + 1))
$script:selfText = "`$buildId = '" + $buildId + "'`n`$engineRelease = " + $engineRelease + "`n"; $newerStays = -not (Save-RunnerCopy)
Assert-Case 'shortcut (R44 E1): the runner copy is saved; a higher engine release stays' ($saved -and $older -and $newerStays)
$null = Invoke-RemoveRade
Assert-Case 'remove RADE (engine-v42): the runners folder goes' (-not (Test-Path -LiteralPath (Join-Path (Join-Path $Dir 'RADE') 'runners')))
$appDisplay = ''; $script:app.Version = $keepVer
# ---- ISE start (engine-v42; 90-161.Z R44 E3): from ISE the window goes to a child powershell.exe -STA, with plain fallbacks.
$script:selfText = "`$buildId = '" + $buildId + "'"; $h1 = Get-IseHandoff 'Windows PowerShell ISE Host' 'RemoteSigned'; $h2 = Get-IseHandoff 'ConsoleHost' 'RemoteSigned'
$h3 = Get-IseHandoff 'Windows PowerShell ISE Host' 'AllSigned'; $env:RADE_ISE_CHILD = '0'; $h4 = Get-IseHandoff 'Windows PowerShell ISE Host' 'Bypass'; $env:RADE_ISE_CHILD = $null
$script:selfText = '# another script'; $h6 = Get-IseHandoff 'Windows PowerShell ISE Host' 'Unrestricted'
$script:selfText = ''; $h5 = Get-IseHandoff 'Windows PowerShell ISE Host' 'Unrestricted'
Assert-Case 'ISE start (R44 E3): ISE goes to the child; ConsoleHost stays; AllSigned, RADE_ISE_CHILD=0 and no own text stay in ISE with the reason' ($h1.Go -and -not $h2.Go -and -not $h2.Why -and
  -not $h3.Go -and $h3.Why -eq 'the execution policy is AllSigned' -and -not $h4.Go -and $h4.Why -eq 'RADE_ISE_CHILD=0' -and
  -not $h5.Go -and $h5.Why -eq 'RADE could not read its own text' -and -not $h6.Go)
# R44 E4: a site check that cannot read the site gives its own words (not "the sign-in did not finish").
Save-SiteUrl $base 'https://usaf.dps.mil/sites/fake'   # Remove RADE above took RADE\Config again
$fk | Add-Member -NotePropertyName webError -NotePropertyValue $true -Force; Set-Fake $fk
Start-Sleep -Seconds 1; $script:app.Backup = @('Sample Tasks'); $b5 = Invoke-Backup $base $null
Assert-Case 'back up (R44 E4): a site check that fails is named as the site check' ($b5.State -eq 'failed' -and
  $b5.Lines[0] -eq 'Back up saved nothing: RADE could not read which site the sign-in connected to.')
$fk.PSObject.Properties.Remove('webError'); Set-Fake $fk
# R44 E2 (the PFM's Q1 answer, 2026-11-26): opened from a runner copy (the shortcut), the title has no round; engine-v46
# (the PFM, 2026-11-26): the shortcut is the app's word, with no version; engine-v43 L1: the subtitle comes from
# application.subtitle.
$appDisplay = 'Sample - Kanon'; $keepVer = $script:app.Version; $script:app.Version = '0.1.0'; $keepStart = $script:startFile
$script:startFile = Join-Path (Join-Path (Join-Path $Dir 'RADE') 'runners') 'aaaaaaaaaaaa.ps1'; $r1 = Test-RunnerStart
$script:startFile = ''; $r2 = Test-RunnerStart; $script:startFile = Join-Path $Dir 'other.ps1'; $r3 = Test-RunnerStart
$appProduct = 'Kanon'; $dv = Get-ShortcutName; $appProduct = ''; $dn = Get-ShortcutName
$appSubtitle = 'Kanon ' + [char]0x2022 + ' Forms'; $sb = Get-AppSubtitle; $appSubtitle = ''; $s0 = Get-AppSubtitle
Assert-Case 'title and names (R44 E2, L1, engine-v46): a runner copy start is known; a paste or another file is not; the shortcut is the word; the subtitle' ($r1 -and -not $r2 -and -not $r3 -and
  $dv -eq 'Kanon' -and $dn -eq [string]$script:app.Name -and $sb -eq ('Kanon ' + [char]0x2022 + ' Forms') -and $s0 -eq '')
# Name spot L3 (engine-v46, the PFM, 2026-11-26): the word is productName, else the app name; under the line "<name>
# <bullet> <subtitle>" with a productName; no version text (Get-AppVersionText of engine-v45 is gone).
$appProduct = 'Kanon'; $appSubtitle = 'Forms'
$w1 = Get-AppWord; $u1 = Get-AppSubtitle; $appSubtitle = ''; $u2 = Get-AppSubtitle
$appProduct = ''; $appSubtitle = 'Forms'; $w0 = Get-AppWord; $u0 = Get-AppSubtitle; $appSubtitle = ''
$appProduct = 'Kanon'; $appSubtitle = 'Forms'; $appName = 'Sample'; $u3 = Get-AppSubtitle; $appName = ''; $appProduct = ''; $appSubtitle = ''   # engine-v47: the application's own name
$b = [string][char]0x2022; $gone = -not (Get-Command Get-AppVersionText -ErrorAction SilentlyContinue)
Assert-Case 'name spot L3: the word and the line under it; no version text' ($w1 -eq 'Kanon' -and $u1 -eq ([string]$script:app.Name + ' ' + $b + ' Forms') -and
  $u2 -eq [string]$script:app.Name -and $w0 -eq [string]$script:app.Name -and $u0 -eq 'Forms' -and $u3 -eq ('Sample ' + $b + ' Forms') -and $gone)
$appDisplay = ''; $script:app.Version = $keepVer; $script:startFile = $keepStart
