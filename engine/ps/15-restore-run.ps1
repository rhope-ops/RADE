# RADE engine part 15, the Maintenance tool Restore, the functions the window and the text mode call (moved out of
# engine/ps/14-restore.ps1 to keep each file at 450 lines or fewer; fleet v2 DEC 6): the backups Restore can use, the
# local test-site mark, the dry run and the write. Part 14 holds the child script ($restoreScript) these functions run.
# Uses parts 01 to 08, 13, 14 and 16 (Get-SiteUrl, Test-SiteUrl, Get-SiteMark, Invoke-ChildScript, Get-BackupFileName,
# $restoreScript, $restoreWriteSeconds, $backupSetMax).
# Network: through the child script of part 14 only (the saved site; AGENTS.md "No reconnaissance").
# Writes: through the child script of part 14 (site rows, after the typed confirm); on the computer, a fresh backup,
#   Backups\~restore-map-<site hash>.json and, from the mark card, Config\<prefix>-restore-test-site.txt.
# Credentials: the interactive CAC sign-in of PnP (-UseWebLogin), in the child script.
# Joined into every bundle by engine/rade_build.py, right after part 14; Windows PowerShell 5.1.

<#
.SYNOPSIS
Gives the backups on this computer that Restore can use, newest first ($backupSetMax at most).
.DESCRIPTION
A backup is a folder in Backups that holds the JSON file of at least one list the manifest names ("backup").
.PARAMETER Base
The RADE app folder.
.OUTPUTS
A list of @{ Path; Name (the folder name, its time); Lists (how many named lists it holds) }.
#>
function Get-BackupSet([string]$Base) {
  $root = Join-Path $Base 'Backups'; if (-not (Test-Path -LiteralPath $root -PathType Container)) { return @() }
  $out = @()
  foreach ($folder in @(Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending)) {
    $count = @($script:app.Backup | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $folder.FullName ((Get-BackupFileName $_) + '.json')) -PathType Leaf) }).Count
    if ($count) { $out += @{ Path = $folder.FullName; Name = $folder.Name; Lists = $count } }
    if ($out.Count -ge $backupSetMax) { break } }
  return $out
}

# ---- The local test-site mark (engine-v32; the Administrator, 2026-11-21): an app whose manifest gives
# "restore.testSites": "local" names no site (a public repo must not hold it). The person marks the saved site as a test
# site on this computer, on the card where they type its name; the mark is Config\@@PREFIX@@-restore-test-site.txt in
# the app folder, next to the site address (Config\@@PREFIX@@-site.txt), never in a repo.
# Gives the path of the mark file. Takes the app folder.
function Get-RestoreMarkFile([string]$Base) { return (Get-ConfigFile $Base '@@PREFIX@@-restore-test-site.txt') }
# Gives the site name the mark holds, or '' (no mark, or a file that cannot be read). Takes the app folder.
function Get-RestoreMark([string]$Base) {
  $p = Get-RestoreMarkFile $Base
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return '' }
  try { return ([string](Get-Content -LiteralPath $p -TotalCount 1)).Trim() } catch { return '' } }
# Saves the mark: the site name, one line. Throws when it cannot. Takes the app folder and the site name.
function Save-RestoreMark([string]$Base, [string]$Name) {
  $p = Get-RestoreMarkFile $Base; $dir = Split-Path -Parent $p
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
  [System.IO.File]::WriteAllText($p, ($Name.Trim() + "`r`n"), (New-Object System.Text.UTF8Encoding $true)) }
# Removes the mark (engine-v33; the Administrator, 2026-11-21): Restore then asks for the site name again. Throws when
# the file is there and cannot be removed. Takes the app folder.
function Clear-RestoreMark([string]$Base) {
  $p = Get-RestoreMarkFile $Base; if (Test-Path -LiteralPath $p -PathType Leaf) { Remove-Item -LiteralPath $p -Force -ErrorAction Stop } }
<#
.SYNOPSIS
Diagnose's line about the local test-site mark (engine-v33; the Administrator, 2026-11-21: one NOTE line).
.DESCRIPTION
Only for an app with "testSites": "local". A NOTE, never a FINDING: no mark is a normal state. Names no site (the
report is saved on the computer).
.PARAMETER Base
The RADE app folder.
.OUTPUTS
A ConvertTo-ToolLine table, or $null for an app without the local mark.
#>
function Get-RestoreMarkNote([string]$Base) {
  if (-not ($script:app.Restore -and $script:app.Restore.Local)) { return $null }
  $site = Get-SiteUrl $Base; $mark = Get-RestoreMark $Base
  if (-not (Test-SiteUrl $site)) { return (ConvertTo-ToolLine 'NOTE' 'Restore test-site mark: no site address is saved' 'Select "Repair": its checks ask for the site address') }
  $name = $site.Substring($sitePrefix.Length).TrimEnd('/')
  if (-not $mark) { return (ConvertTo-ToolLine 'NOTE' 'Restore test-site mark: the saved site is not marked, so Restore asks for its name first' '') }
  $off = 'To take the mark off, select Restore, then "Remove test-site mark"'
  if ($mark -eq $name) { return (ConvertTo-ToolLine 'NOTE' 'Restore test-site mark: the saved site is marked as a test site on this computer' $off) }
  return (ConvertTo-ToolLine 'NOTE' 'Restore test-site mark: the mark on this computer is for another site, so Restore asks for the name of the saved site first' '')
}

<#
.SYNOPSIS
Says whether Restore may write on the saved site: the app names Restore ("restore") and the site is one of its test
sites, or (with "testSites": "local") the site is marked as a test site on this computer.
.DESCRIPTION
Restore runs only on a test site (the Administrator, 2026-11-20 and 2026-11-21). The site name is the part of the saved
address after the site prefix, compared without case. With a list of names, the site must be in it; with "local", the
mark (Get-RestoreMark) must hold this site's name. A mark of another site does not count.
.PARAMETER Base
The RADE app folder.
.OUTPUTS
@{ Ok; Site; Name; NeedMark; Lines }: Ok is $true when Restore may run; Name is the site name; NeedMark is $true when
only the mark is missing (the window then shows the mark card); Lines say why not.
#>
function Test-RestoreSite([string]$Base) {
  $restoreDef = $script:app.Restore
  if (-not $restoreDef) { return @{ Ok = $false; Site = ''; Name = ''; NeedMark = $false; Lines = @(($script:app.Name + ' does not use Restore in this version.'), 'Nothing was changed.') } }
  $site = Get-SiteUrl $Base
  if (-not (Test-SiteUrl $site)) { $why = @('No site address is saved, so Restore did not sign in.', 'Select "Repair": its checks ask for the site address.')
    return @{ Ok = $false; Site = ''; Name = ''; NeedMark = $false; Lines = $why } }
  $name = $site.Substring($sitePrefix.Length).TrimEnd('/')
  if ($restoreDef.Local) {
    if ((Get-RestoreMark $Base) -eq $name) { return @{ Ok = $true; Site = $site; Name = $name; NeedMark = $false; Lines = @() } }
    $why = 'Restore runs only on a site marked as a test site on this computer. The saved site is not marked.'
    return @{ Ok = $false; Site = $site; Name = $name; NeedMark = $true; Lines = @($why, 'Nothing was changed.') } }
  if (@($restoreDef.TestSites | Where-Object { [string]$_ -eq $name }).Count) { return @{ Ok = $true; Site = $site; Name = $name; NeedMark = $false; Lines = @() } }
  $why = 'Restore runs only on a test site that the app names. The saved site is not one.'
  return @{ Ok = $false; Site = $site; Name = $name; NeedMark = $false; Lines = @($why, 'Nothing was changed.') }
}

# Reads the PLAN lines of the Restore child script: one table for each list number. Takes the output lines; gives
# back @{ <n> = @{ Saved; Now; Missing; Bin; New; After; Unsure; Sig } or @{ Error } }.
function Read-RestorePlan([string[]]$Lines) {
  $plans = @{}
  foreach ($line in $Lines) {
    if ($line -match '^PLAN (\d+) saved=(\d+) now=(\d+) missing=(\d+) bin=(\d+) new=(\d+) after=(\d+) unsure=(\d+) sig=([0-9a-f]+)$') {
      $plans[[int]$Matches[1]] = @{ Saved = [int]$Matches[2]; Now = [int]$Matches[3]; Missing = [int]$Matches[4]; Bin = [int]$Matches[5]
        New = [int]$Matches[6]; After = [int]$Matches[7]; Unsure = [int]$Matches[8]; Sig = $Matches[9] } }
    elseif ($line -match '^PLAN (\d+) (.+)$') { $plans[[int]$Matches[1]] = @{ Error = $Matches[2] } } }
  return $plans
}
# The -MapFile argument of the Restore child script: Backups\~restore-map-<site hash>.json in the app folder, one record
# for every backup of this app on that site (reviews of PR 151: a map per backup folder let two backups make the same row
# twice; a map for every site would mix two sites' IDs). Takes the app folder and the site address.
function Get-RestoreMapArg([string]$Base, [string]$Site) {
  return (' -MapFile "' + (Join-Path (Join-Path $Base 'Backups') ('~restore-map-' + (Get-SiteMark $Site) + '.json')) + '"') }
# The words for a sign-in or tool stop of a child script. Takes the RESULT word and the child's Why.
function Get-ChildStopText([string]$Res, [string]$Why) {
  switch ($Res) { 'no-pnp' { return 'the SharePoint tool is not installed' } 'not-connected' { return 'the sign-in did not finish' }
    'reread-failed' { return 'a list could not be read again after the Recycle Bin, so no new row was made' }
    'map-write-failed' { return 'the record of re-made rows could not be saved, so Restore stopped making new rows' }
    default { return ('it stopped: ' + $(if ($Why) { $Why } else { 'no result' })) } } }

<#
.SYNOPSIS
Restore, the dry run (R4): reads the site and says, for each list, what Restore would put back. Writes nothing.
.PARAMETER Base
The RADE app folder.
.PARAMETER Dir
The backup folder (from Get-BackupSet).
.PARAMETER Tick
Run while the sign-in and the reads go on, or $null.
.OUTPUTS
@{ State; Lines; Plan; Expect; Missing }: State is plan, refused or failed; Lines are plain report lines (counts only);
Plan is Read-RestorePlan's table; Expect is the hash of the missing and Recycle Bin rows per list ("1:<hex>,2:<hex>")
the write checks again; Missing is the total.
#>
function Invoke-RestorePlan([string]$Base, [string]$Dir, [scriptblock]$Tick) {
  $siteCheck = Test-RestoreSite $Base
  if (-not $siteCheck.Ok) { return @{ State = 'refused'; Lines = $siteCheck.Lines; Plan = @{}; Expect = ''; Missing = 0 } }
  $lists = @($script:app.Backup | Where-Object { $_ })
  $argText = '-Site "' + $siteCheck.Site + '" -Folder "' + $Dir + '" -Lists "' + ($lists -join '|') + '" -Mode plan' + (Get-RestoreMapArg $Base $siteCheck.Site)
  $child = Invoke-ChildScript $restoreScript $argText $toolReadSeconds $Tick
  $res = ''; foreach ($line in $child.Lines) { if ($line -match '^RESULT (\S+)') { $res = $Matches[1] } elseif ($line -eq 'MAP failed') { $res = 'map' } }
  $stop = $(if ($res -eq 'map') { "the record of an earlier Restore on this site (Backups\~restore-map-*.json) could not be read" } else { Get-ChildStopText $res $child.Why })
  if ($res -ne 'plan') { return @{ State = 'failed'; Plan = @{}; Expect = ''; Missing = 0; Lines = @(('The dry run did not finish: ' + $stop + '.'), 'Nothing was changed.') } }
  $plan = Read-RestorePlan $child.Lines; $lines = @(); $exp = @(); $tot = 0; $fromBinTotal = 0; $newTotal = 0
  for ($i = 1; $i -le $lists.Count; $i++) {
    $listName = [string]$lists[$i - 1]; $item = $plan[$i]
    if (-not $item) { $lines += ('NOTE: "' + $listName + '": no result'); continue }
    if ($item.Error) { $why = $(switch -regex ($item.Error) { '^nofile' { 'this backup has no file for it' } '^nolist' { 'the list is not on the site (Restore does not make lists)' }
          default { 'it could not be read (' + ($item.Error -replace '^failed ', '') + ')' } })
      $lines += ('NOTE: "' + $listName + '" is left out: ' + $why); continue }
    $exp += ([string]$i + ':' + $item.Sig); $tot += $item.Missing; $fromBinTotal += $item.Bin; $newTotal += $item.New
    $lines += ('"' + $listName + '": ' + $item.Saved + ' in the backup, ' + $item.Now + ' on the list now. Would put back ' + $item.Missing +
      ' (' + $item.Bin + ' from the Recycle Bin, ' + $item.New + ' as new rows). ' + $item.After + ' made after the backup stay.')
    if ($item.Unsure) { $lines += ('NOTE: "' + $listName + '": ' + $item.Unsure + ' row(s) are left out: an earlier Restore wrote them but did not confirm it. Check the list by hand') } }
  $head = @(('Dry run: ' + $tot + ' rows would come back (' + $fromBinTotal + ' from the Recycle Bin, ' + $newTotal + ' as new rows). Nothing was written.'))
  if (@($child.Lines | Where-Object { $_ -like 'BIN failed*' }).Count) { $head += 'NOTE: the Recycle Bin could not be read, so every missing row would come back as a new row (a new ID).' }
  return @{ State = 'plan'; Plan = $plan; Expect = ($exp -join ','); Missing = $tot; Lines = @($head + $lines) }
}

<#
.SYNOPSIS
Restore, the write: a fresh backup (R3), the pause switch on (R2), the Recycle Bin (R1), new rows in dependency order
with lookups re-pointed (R5), the pause switch back, then the row count of each list.
.DESCRIPTION
Runs only after the user typed the app name on the dry-run card, and only on a test site. Writes missing rows only: a
row on the list is never changed, and a row made after the backup stays (the Administrator, 2026-11-21). The site must
be as the dry run saw it (the same missing and Recycle Bin rows per list), else nothing is written.
.PARAMETER Base
The RADE app folder.
.PARAMETER Dir
The backup folder the dry run used.
.PARAMETER Plan
The result of Invoke-RestorePlan.
.PARAMETER Tick
Run while the run goes on, or $null.
.OUTPUTS
@{ State; Lines; Path }: State is done, failed, changed or refused; Path is the fresh backup folder or ''.
#>
function Invoke-Restore([string]$Base, [string]$Dir, $Plan, [scriptblock]$Tick) {
  $siteCheck = Test-RestoreSite $Base
  if (-not $siteCheck.Ok) { return @{ State = 'refused'; Path = ''; Lines = $siteCheck.Lines } }
  if (-not $Plan -or $Plan.State -ne 'plan' -or -not $Plan.Missing) { return @{ State = 'failed'; Path = ''; Lines = @('There are no rows to put back.', 'Nothing was changed.') } }
  $fresh = Invoke-Backup $Base $Tick   # R3: the restore itself can be undone from this backup
  if ($fresh.State -ne 'done') { return @{ State = 'failed'; Path = ''; Lines = @(@('Restore wrote nothing: the fresh backup before it did not save every list.') + @($fresh.Lines)) } }
  $lists = @($script:app.Backup | Where-Object { $_ }); $pause = $script:app.Restore.Pause
  $pauseArg = $(if ($pause) { ' -Pause "' + $pause.List + '|' + $pause.Title + '|' + $pause.Field + '|' + $pause.On + '"' } else { '' })
  $child = Invoke-ChildScript $restoreScript ('-Site "' + $siteCheck.Site + '" -Folder "' + $Dir + '" -Lists "' + ($lists -join '|') + '" -Mode write -Expect "' + $Plan.Expect + '"' + $pauseArg +
    (Get-RestoreMapArg $Base $siteCheck.Site)) $restoreWriteSeconds $Tick
  $res = ''; $done = @{}; $resume = ''; $binErr = @{}
  foreach ($line in $child.Lines) { if ($line -match '^RESULT (\S+)') { $res = $Matches[1] } elseif ($line -match '^DONE (\d+) (.+)$') { $done[[int]$Matches[1]] = $Matches[2] }
    elseif ($line -match '^RESUME (\S+)') { $resume = $Matches[1] } elseif ($line -match '^BINERR (\d+) ([A-Za-z0-9_.]+)$') { $binErr[[int]$Matches[1]] = $Matches[2] } }
  $freshLine = 'Fresh backup before Restore: ' + (ConvertTo-Masked $fresh.Path)
  $stop = $(switch ($res) { 'changed' { 'the site changed after the dry run. Run Restore again for a new dry run' }
      'paused-already' { 'the pause switch is on already (another Restore, or it was left on). Check it, then run Restore again' }
      'no-pause-row' { "the app's pause-switch row is not on the site" } 'pause-failed' { 'the pause switch could not be set' } default { '' } })
  if ($stop) { return @{ State = $(if ($res -eq 'changed') { 'changed' } else { 'failed' }); Path = $fresh.Path; Lines = @(('Restore wrote no rows: ' + $stop + '.'), $freshLine) } }
  $lines = @(); $bad = 0; $back = 0
  for ($i = 1; $i -le $lists.Count; $i++) {
    $listName = [string]$lists[$i - 1]; $doneText = [string]$done[$i]; $item = $Plan.Plan[$i]
    if (-not $item -or $item.Error) { continue }
    if ($doneText -notmatch '^before=(\d+) bin=(\d+) made=(\d+) failed=(\d+) skipped=(\d+) binfailed=(\d+) unlinked=(\d+) now=(-?\d+)$') {
      $bad++; $lines += ('FINDING: "' + $listName + '": no result. What to do: compare the list with the backup'); continue }
    $before = [int]$Matches[1]; $fromBin = [int]$Matches[2]; $made = [int]$Matches[3]; $notConfirmed = [int]$Matches[4]; $skipped = [int]$Matches[5]
    $binFailed = [int]$Matches[6]; $unlinkedCount = [int]$Matches[7]; $now = [int]$Matches[8]
    $back += $fromBin + $made
    $want = $before + $fromBin + $made; $ok = ($notConfirmed -eq 0 -and $skipped -eq 0 -and $binFailed -eq 0 -and $now -eq $want)
    $txt = '"' + $listName + '": ' + $fromBin + ' back from the Recycle Bin, ' + $made + ' made new; ' + $now + ' rows on the list now'
    if ($unlinkedCount) { $txt += '; ' + $unlinkedCount + ' lookup value(s) left empty (the row they pointed to is not there)' }
    if ($ok) { $lines += ('PASS: ' + $txt); continue }
    $notConfirmedText = $(if ($notConfirmed) { '; ' + $notConfirmed + ' row(s) not confirmed (they may be on the list; Restore never makes them again)' } else { '' })
    if ($skipped) { $notConfirmedText += '; ' + $skipped + ' row(s) not written: a saved value could not be read (the next dry run offers them again)' }
    if ($binFailed) { $notConfirmedText += '; ' + $binFailed + ' row(s) did not come back from the Recycle Bin (' + $(if ($binErr[$i]) { $binErr[$i] } else { 'error' }) +
        '), so Restore made them as new rows with new row numbers' }   # E2 (R42): a planned Recycle Bin row made new is never a PASS
    $bad++; $lines += ('FINDING: ' + $txt + $notConfirmedText + '. What to do: compare the list with the backup') }
  if ($res -ne 'done') { $bad++
    $lines += ('FINDING: Restore stopped before the end: ' + (Get-ChildStopText $res $child.Why) + '. What to do: run Restore again (it puts back only what is still missing)') }
  if ($pause -and $resume -ne 'ok') { $bad++; $lines += "FINDING: the pause switch could not be put back. What to do: set it back by hand in the app's settings" }
  $head = @(('Restore put back ' + $back + ' of ' + $Plan.Missing + ' rows. Rows on the lists were not changed.'), $freshLine)
  if ($pause -and $resume -eq 'ok') { $head += "The app's pause switch is back as it was." }
  return @{ State = $(if ($bad) { 'failed' } else { 'done' }); Path = $fresh.Path; Lines = @($head + $lines) }
}
