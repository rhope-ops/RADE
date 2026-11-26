# RADE engine part 13, the Maintenance tools (the Administrator, 2026-11-20; docs/engine.md "Maintenance run types").
# Diagnose: read-only; the install record, the app's local files and the app's RADE checks again; one report file.
# Back up: reads only the lists the app's manifest names ("backup") and saves each as JSON plus a CSV copy.
# Restore (engine-v31) is parts 14 and 15, engine/ps/14-restore.ps1 and 15-restore-run.ps1; it uses Invoke-Backup and Get-BackupFileName from here.
# Uses parts 01 to 08 (Get-BasePath, Read-Installed, Get-InstalledKey, Get-StartPath, Invoke-Check, Invoke-ChildScript).
# Network: Diagnose runs the app's own RADE checks (their fixed addresses only); Back up signs in to the saved site and
# reads only the lists the manifest names (AGENTS.md "No reconnaissance"). Neither one writes to the site.
# Writes: Diagnose: Diagnose\diagnose-<time>.txt; Back up: Backups\<time>\<list>.json and .csv (the app folder).
# Credentials: the interactive CAC sign-in of PnP (-UseWebLogin), for Back up only.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# Time limit of a child script that signs in and reads every named list, in seconds (Back up and the Restore dry run;
# the Administrator's lists are small, so it is generous).
$toolReadSeconds = 1800
# R44 E4 (R43: Back up stopped after a sign-in window): the time limit of one stage (sign-in, site check, one list), in seconds.
$toolStageSeconds = 300

# Gives the time stamp of a report or a backup folder (sortable, no colons). Takes nothing.
function Get-ToolStamp { return (Get-Date).ToString('yyyyMMdd-HHmmss', [System.Globalization.CultureInfo]::InvariantCulture) }
# Makes one finding of a Maintenance tool. Takes PASS, FINDING or NOTE, the fact and what to do (or '').
function ConvertTo-ToolLine([string]$State, [string]$Text, [string]$Fix) { return @{ State = $State; Text = $Text; Fix = $Fix } }

<#
.SYNOPSIS
Diagnose, part D1: the install record and the app's local files against this paste.
.DESCRIPTION
Reads RADE's own files only: the install record (RADE\Config\installed), the start script of the app (manifest
"start") and the RADE runner copy. Each finding names its fix. Changes nothing.
.OUTPUTS
A list of ConvertTo-ToolLine tables.
#>
function Get-DiagnoseInstall {
  $e = Read-Installed (Get-InstalledKey $script:app); $out = @(); $pv = [string]$script:app.Version
  $repair = 'Select "Repair" on the Maintenance screen'
  if (-not ($e -and $e.installed)) { return @(ConvertTo-ToolLine 'FINDING' ('This computer has no install record of ' + $script:app.Name + ' that ended PASSED') $repair) }
  $iv = [string]$e.installed.version; $c = 0
  try { $c = ([version]$pv).CompareTo([version]$iv) } catch { $c = [string]::CompareOrdinal($pv, $iv) }
  if ($c -eq 0) { $out += ConvertTo-ToolLine 'PASS' ('The installed version, ' + $iv + ', is the version in this paste') '' }
  elseif ($c -gt 0) { $out += ConvertTo-ToolLine 'FINDING' ('The installed version is ' + $iv + '; this paste has ' + $pv) ('Select "Update to ' + $pv + '" on the Maintenance screen') }
  else { $out += ConvertTo-ToolLine 'FINDING' ('The installed version, ' + $iv + ', is newer than this paste (' + $pv + ')') ('Use the newest paste of ' + $script:app.Name) }
  $ls = $(if ($e.lastRun) { [string]$e.lastRun.state } else { '' })
  if ($ls -and $ls -ne 'PASSED') { $out += ConvertTo-ToolLine 'FINDING' ('The last install run ended ' + $ls) $repair }
  if ($e.steps) { foreach ($n in @($e.steps.Keys)) { $s = [string]$e.steps[$n].state
    if ($s -and $s -ne 'PASSED') { $out += ConvertTo-ToolLine 'FINDING' ('Step "' + $n + '" ended ' + $s + ' in its last run') $repair } } }
  $st = [string]$script:app.Start
  if ($st) { if (Get-StartPath) { $out += ConvertTo-ToolLine 'PASS' ('The start script ' + $st + ' is in the app folder') '' }
    else { $out += ConvertTo-ToolLine 'FINDING' ('The start script ' + $st + ' is missing from the app folder') ($repair + ': it puts the file back') } }
  $rp = Get-RunnerPath   # engine-v42: the app's own runner copy, RADE\runners\<key>.ps1
  if (Test-Path -LiteralPath $rp -PathType Leaf) { $out += ConvertTo-ToolLine 'PASS' 'The RADE runner copy of this app is saved' '' }
  else { $out += ConvertTo-ToolLine 'NOTE' 'The RADE runner copy of this app is not saved, so its shortcut cannot start RADE' $repair }
  return $out
}

<#
.SYNOPSIS
Diagnose, part D0: the app's RADE checks again, as the Ready card runs them, with no saved result reused.
.DESCRIPTION
A check that runs on its own runs again now. A sign-in or look-and-answer check needs the user, so Diagnose shows its
saved result, or says it was not run. The checks are read-only (docs/engine.md "Checks").
.PARAMETER Base
The RADE app folder.
.PARAMETER Tick
Run while a check waits (keeps the window alive), or $null.
.OUTPUTS
A list of ConvertTo-ToolLine tables, one for each check.
#>
function Get-DiagnoseCheck([string]$Base, [scriptblock]$Tick) {
  $site = Get-SiteUrl $Base; $cache = Read-CheckCache; $out = @()
  foreach ($id in @($script:appChecks)) {
    $d = Get-CheckDef $id; $r = $null
    if ($d.Kind -eq 'auto') { $r = Invoke-Check $d $Base $site $Tick } else { $r = Get-CheckToRun $d $cache $Base $site $false }
    if (-not $r) { $out += ConvertTo-ToolLine 'NOTE' ([string]$d.Name + ': not run (it needs you)') 'Select "Repair": its checks ask for it'; continue }
    $w = $(if ($r.State -in 'PASSED', 'WARNING') { 'PASS' } else { 'FINDING' })
    $out += ConvertTo-ToolLine $w ([string]$d.Name + ': ' + $r.State + $(if ($r.Detail) { '. ' + $r.Detail } else { '' })) ([string]$r.Fix)
  }
  return $out
}

<#
.SYNOPSIS
Runs Diagnose and saves its report in the app folder's Diagnose folder (never attached to the e-mail draft).
.PARAMETER Base
The RADE app folder.
.PARAMETER Tick
Run while a check waits, or $null.
.OUTPUTS
@{ Lines; Path; Findings }: the report lines (masked), the report file ('' when it could not be written) and the count
of findings.
#>
function Invoke-Diagnose([string]$Base, [scriptblock]$Tick) {
  $all = @(Get-DiagnoseInstall) + @(Get-DiagnoseCheck $Base $Tick) + @(Get-RestoreMarkNote $Base | Where-Object { $_ })   # the mark line: part 14 (engine-v33)
  $n = @($all | Where-Object { $_.State -eq 'FINDING' }).Count
  $lines = @(('Diagnose of ' + $script:app.Name + ' ' + $script:app.Version + ', ' + (Get-NowText) + '. Read-only: nothing was changed.'),
    $(if ($n) { [string]$n + ' finding(s). Each one says what to do.' } else { 'No findings.' }))
  foreach ($f in $all) { $lines += ($f.State + ': ' + $f.Text + $(if ($f.Fix) { '. What to do: ' + $f.Fix } else { '' })) }
  $lines = @($lines | ForEach-Object { ConvertTo-Masked $_ })
  $p = ''
  try { $dir = Join-Path $Base 'Diagnose'   # not Rounds\<round>: the e-mail draft attaches every file there (review of PR 143)
    if (-not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
    $p = Join-Path $dir ('diagnose-' + (Get-ToolStamp) + '.txt'); Write-FileWhole $p (($lines -join "`r`n") + "`r`n") } catch { $p = '' }
  return @{ Lines = $lines; Path = $p; Findings = $n }
}

# ---- Back up. The child script reads each named list and writes ~<n>.json and ~<n>.csv into the folder it is given.
# It prints only a list number, a row count or an error type: never the site, a name, a value or an error message.
$backupScript = @'
param([string]$Site, [string]$Folder, [string]$Lists)
# <RADE sign-in window size>
# RADE Back up (reads the site, writes this computer only): signs in with the CAC and saves each named list.
# Windows PowerShell 5.1 writes an array as {value, Count} while this type data is loaded: take it out first.
Remove-TypeData -TypeName System.Array -ErrorAction SilentlyContinue
# Turns one SharePoint field value into plain text or a number: lookup and person "id;#text", link "url;#text", managed
# metadata "label|guid", place "POINT(lon lat)", several values joined with ";#", a date in ISO form (UTC). Takes the value.
function ConvertTo-PlainValue($V) {
  if ($V -is [datetime]) { return $V.ToUniversalTime().ToString('o') }
  if (($null -eq $V) -or ($V -is [string]) -or ($V -is [ValueType])) { return $V }
  $p = $V.PSObject.Properties
  if ($p['LookupId']) { return ([string]$V.LookupId + ';#' + [string]$V.LookupValue) }
  if ($p['Url']) { return ([string]$V.Url + ';#' + [string]$V.Description) }
  if ($p['TermGuid']) { return ([string]$V.Label + '|' + [string]$V.TermGuid) }
  if ($p['Latitude']) { return ('POINT(' + [string]$V.Longitude + ' ' + [string]$V.Latitude + ')') }
  if ($V -is [System.Collections.IEnumerable]) { return ((@(foreach ($x in $V) { ConvertTo-PlainValue $x }) | ForEach-Object { [string]$_ }) -join ';#') }
  return [string]$V
}
try {
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { 'RESULT no-pnp'; exit 3 }
  $pin = @($mod | Where-Object { [string]$_.Version -eq '1.12.0' }); if ($pin.Count) { $mod = $pin }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  # R44 E4: STAGE lines let RADE stop a stage that takes too long and name it (Invoke-ChildScript -StageSeconds).
  Connect-RadeSite $Site   # engine-v43 S1: STAGE signin, SIGNIN and SIGNIN-WIN lines (the block above)
  # R44 E4: the site check. The connection must be to the given site, else nothing is read (prints no address).
  'STAGE site'
  $script:web = $null
  try { $null = & { $script:web = Get-PnPWeb -ErrorAction Stop } *>&1; $u = [string]$script:web.Url } catch { 'RESULT site-unknown ' + $_.Exception.GetType().Name; exit 5 }
  if ($u.TrimEnd('/').ToLowerInvariant() -ne $Site.Trim().TrimEnd('/').ToLowerInvariant()) { 'RESULT wrong-site'; exit 4 }
  $i = 0
  foreach ($name in ($Lists -split '\|')) {
    $i++
    'STAGE list ' + $i
    try {
      $script:items = @()
      $null = & { $script:items = @(Get-PnPListItem -List $name -PageSize 500 -ErrorAction Stop) } *>&1
      $rows = @(foreach ($it in $script:items) { $o = [ordered]@{}
        foreach ($k in @($it.FieldValues.Keys)) { $o[$k] = ConvertTo-PlainValue $it.FieldValues[$k] }
        [pscustomobject]$o })
      $j = Join-Path $Folder ('~' + $i + '.json'); $c = Join-Path $Folder ('~' + $i + '.csv')   # '~': no list title has it, so no name clash
      [System.IO.File]::WriteAllText($j, (ConvertTo-Json -InputObject @($rows) -Depth 4), (New-Object System.Text.UTF8Encoding $true))
      if ($rows.Count) { $rows | Export-Csv -LiteralPath $c -NoTypeInformation -Encoding UTF8 } else { [System.IO.File]::WriteAllText($c, '') }
      'LIST ' + $i + ' ' + $rows.Count
    } catch { 'LIST ' + $i + ' failed ' + $_.Exception.GetType().Name }
  }
  'RESULT done'; exit 0
} catch { 'RESULT not-connected ' + $_.Exception.GetType().Name; exit 2 }
'@
$backupScript = Add-SignInSize $backupScript   # E3: the sign-in window size block (16-site-scripts.ps1)

# Gives the file name (no extension) of a saved list: its title with any sign a file name cannot hold made "_" (the
# build allows letters, digits, space, "_", "-", "(" and ")", so this changes nothing today). Takes the list title.
function Get-BackupFileName([string]$Name) { return ($Name -replace '[^A-Za-z0-9 _()-]', '_') }
# Makes the new folder of a backup, Backups\<time> in the app folder; a folder of that name that is there already (the
# same second, or the hour that repeats when daylight saving ends) is never reused: -2, -3 and so on follow. Takes the
# RADE app folder and the time stamp; gives back the new folder, or '' when none could be made.
function Get-NewBackupDir([string]$Base, [string]$Stamp) {
  $root = Join-Path $Base 'Backups'
  for ($k = 1; $k -le 50; $k++) { $d = Join-Path $root ($Stamp + $(if ($k -gt 1) { '-' + $k } else { '' }))
    if (Test-Path -LiteralPath $d) { continue }
    try { $null = New-Item -ItemType Directory -Path $d -ErrorAction Stop; return $d } catch { if (-not (Test-Path -LiteralPath $d)) { return '' } } }
  return '' }
# Removes the folder of a backup that saved nothing (only the new folder this run made). Takes the folder; gives back
# $true when it is gone.
function Clear-BackupDir([string]$Dir) {
  try { Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction Stop; return $true } catch { return (-not (Test-Path -LiteralPath $Dir)) } }
# Gives a saved list its name: ~<n>.json and ~<n>.csv become <list>.json and <list>.csv; both must be there. Takes the
# folder, the list number and the file name; gives back $true when both files have their name.
function Rename-BackupFile([string]$Dir, [int]$I, [string]$Name) {
  try { foreach ($x in '.json', '.csv') { $to = Join-Path $Dir ($Name + $x); if (Test-Path -LiteralPath $to) { return $false }   # never over another list's file
      Move-Item -LiteralPath (Join-Path $Dir ('~' + $I + $x)) -Destination $to -ErrorAction Stop }
    return ((Test-Path -LiteralPath (Join-Path $Dir ($Name + '.json')) -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $Dir ($Name + '.csv')) -PathType Leaf)) } catch { return $false } }

<#
.SYNOPSIS
Runs Back up: saves each list the manifest names ("backup") as JSON plus a CSV copy in a new Backups\<time> folder.
.DESCRIPTION
An app that names no lists: Back up says so and writes nothing (the Administrator, 2026-11-20). With no valid site
address it stops before the sign-in. A list that cannot be read is reported by name, never skipped without a word. The
files are named after the list; a list file is checked after the run (it must be there). Nothing on the site changes.
.PARAMETER Base
The RADE app folder.
.PARAMETER Tick
Run while the sign-in and the reads go on (keeps the window alive), or $null.
.OUTPUTS
@{ State; Lines; Path }: State is none, no-site, done or failed; Lines are plain report lines; Path is the folder or ''.
#>
function Invoke-Backup([string]$Base, [scriptblock]$Tick) {
  $lists = @($script:app.Backup | Where-Object { $_ })
  if (-not $lists.Count) { $why = $script:app.Name + ' names no lists to back up, so Back up saved nothing.'
    return @{ State = 'none'; Path = ''; Lines = @($why, 'The app adds them in its manifest ("backup").') } }
  $site = Get-SiteUrl $Base
  if (-not (Test-SiteUrl $site)) {
    return @{ State = 'no-site'; Path = ''; Lines = @('No site address is saved, so Back up did not sign in.', 'Select "Repair": its checks ask for the site address.') } }
  $dir = Get-NewBackupDir $Base (Get-ToolStamp)   # always a new folder: a failed run removes only this one
  if (-not $dir) { return @{ State = 'failed'; Path = ''; Lines = @('Back up could not make its folder on this computer.') } }
  $r = Invoke-ChildScript $backupScript ('-Site "' + $site + '" -Folder "' + $dir + '" -Lists "' + ($lists -join '|') + '"') $toolReadSeconds $Tick $toolStageSeconds
  $got = @{}; $res = ''
  foreach ($l in $r.Lines) { if ($l -match '^LIST (\d+) (.+)$') { $got[[int]$Matches[1]] = $Matches[2] } elseif ($l -match '^RESULT (\S+)') { $res = $Matches[1] } }
  $note = Get-SignInNote 'Back up' $r.Lines   # R44 E4, engine-v43 S2, S3: the sign-in lines in the run log, with the host
  $signLine = ''; if ($note -match '^SIGNIN seconds=(\d+) watch=(on|off)') { $signLine = 'The sign-in took ' + $Matches[1] + ' seconds (sign-in window size: ' + $Matches[2] + ').' }
  if ($res -ne 'done') { $why = $(switch ($res) { 'no-pnp' { 'the SharePoint tool is not installed' } 'not-connected' { 'the sign-in did not finish' }
        'wrong-site' { 'the sign-in connected to another site than the saved site address' }
        'site-unknown' { 'RADE could not read which site the sign-in connected to' }
        default { $(if ($r.Stage) { (Get-StageText $r.Stage $lists) + ' did not finish in ' + [int]($toolStageSeconds / 60) + ' minutes, so RADE stopped it' } else { 'it stopped: ' + $r.Why }) } })
    $gone = Clear-BackupDir $dir
    $left = $(if ($gone) { 'Nothing on the site changed.' } else { 'Nothing on the site changed. Its unfinished folder stays: ' + (ConvertTo-Masked $dir) })
    return @{ State = 'failed'; Path = ''; Lines = @(@(('Back up saved nothing: ' + $why + '.'), $left, 'Select "Back up" again.') + @($signLine | Where-Object { $_ })) } }
  $lines = @(); $bad = 0
  for ($i = 1; $i -le $lists.Count; $i++) {
    $n = [string]$lists[$i - 1]; $v = [string]$got[$i]; $ok = $false
    if ($v -match '^\d+$') { $ok = Rename-BackupFile $dir $i (Get-BackupFileName $n) }
    if ($ok) { $lines += ('PASS: "' + $n + '": ' + $v + ' rows saved'); continue }
    $bad++; $ty = $(if ($v -match '^failed (\S+)') { ' (' + $Matches[1] + ')' } elseif ($v) { ' (its files could not be named)' } else { '' })
    $lines += ('FINDING: "' + $n + '" was not saved' + $ty + '. What to do: check that the list exists and that you can read it, then select "Back up" again')
  }
  $head = $(if ($bad) { [string]$bad + ' of ' + $lists.Count + ' lists were not saved.' } else { 'All ' + $lists.Count + ' lists were saved.' })
  return @{ State = $(if ($bad) { 'failed' } else { 'done' }); Path = $dir; Lines = @(@($head, 'Nothing on the site changed.') + $lines + @($signLine | Where-Object { $_ })) }
}

# ---- Uninstall (engine-v40; 90-161.Z R43 E3, the PFM, 2026-11-25; docs/engine.md "Maintenance run types"). RADE gives
# the mode, the card and the record; the app gives the steps (manifest "uninstall": its own steps, never the install
# steps). Test sites only (the Restore gate, Test-RestoreSite). Back up first: a backup that misses a list stops it
# before any step. The steps run with RADE_MODE=uninstall and RADE_MADE (the made list as a JSON file). Local files and
# the Backups folder stay. Answers 1A, 2A, 4A of the PFM (2026-11-25).

# Says whether Uninstall may run on the saved site: the Restore test-site gate, with Uninstall's own words. Takes the
# app folder; gives back the Test-RestoreSite table (Ok, Site, Name, NeedMark, Lines).
function Test-UninstallSite([string]$Base) {
  $c = Test-RestoreSite $Base
  $c.Lines = @($c.Lines | ForEach-Object { ([string]$_) -replace 'does not use Restore in this version', 'names no test sites, so Uninstall cannot run' -replace '\bRestore\b', 'Uninstall' })
  return $c
}

<#
.SYNOPSIS
Writes the files of the Uninstall steps (their script or hand-step file) into the app folder.
.DESCRIPTION
A step that came with this paste can then run when the installed version is older. Only those files are written: the
rest of the app's local copy stays as it is.
.PARAMETER Base
The RADE app folder.
.OUTPUTS
The number of files written.
#>
function Write-UninstallFile([string]$Base) {
  $n = 0; $utf8Bom = New-Object System.Text.UTF8Encoding $true
  foreach ($k in @($script:app.Uninstall)) { $s = $steps[[int]$k]; if (-not $s.File) { continue }
    foreach ($f in @($files | Where-Object { $_.Dir -eq $s.Dir -and $_.Name -eq $s.File })) {
      $dir = Join-Path $Base $f.Dir; if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
      $path = Join-Path $dir $f.Name
      if ($f.Kind -eq 'text') { [System.IO.File]::WriteAllText($path, (((Expand-SharedBlock $f.Data) -replace "`r?`n", "`r`n") + "`r`n"), $utf8Bom) }
      else { [System.IO.File]::WriteAllBytes($path, [System.Convert]::FromBase64String(($f.Data -replace '\s', ''))) }
      $n++ } }
  return $n
}

# Writes the made list of the install record (every step's "made" items: kind and name, no address) to
# Uninstall\made-<time>.json in the app folder, for the steps (RADE_MADE). Takes the app folder and the time stamp;
# gives back the file path.
function Save-UninstallMade([string]$Base, [string]$Stamp) {
  $e = Read-Installed (Get-InstalledKey $script:app); $made = @()
  if ($e -and $e.steps) { foreach ($n in @($e.steps.Keys)) { foreach ($m in @($e.steps[$n].made)) {
        if ($m) { $made += [ordered]@{ step = [string]$n; kind = [string]$m.kind; name = [string]$m.name } } } } }
  $p = Join-Path (Join-Path $Base 'Uninstall') ('made-' + $Stamp + '.json')
  Write-FileWhole $p (ConvertTo-Json -InputObject @{ schema = 'rade-made/1'; app = [string]$script:app.Name; made = @($made) } -Depth 5)
  return $p
}

<#
.SYNOPSIS
Writes the result of an Uninstall run to the app's install record (answer 2A of the PFM, 2026-11-25).
.DESCRIPTION
Every Uninstall step done: "installed" is cleared (the app shows as not installed), "uninstalled" keeps the version,
the time and the made list that the steps removed, "steps" is cleared (a new install runs every step again) and
"lastRun" reads UNINSTALLED. Not every step done: "installed" and "steps" stay, and "lastRun" reads NEEDS REVIEW, so
Maintenance offers Uninstall again. Never writes a record of a newer RADE or of another app (S1, S2).
.PARAMETER Whole
$true when every Uninstall step is done.
.OUTPUTS
'' or the reason the record could not be saved.
#>
function Save-Uninstalled([bool]$Whole) {
  try {
    $key = Get-InstalledKey $script:app; $raw = Read-InstalledRaw $key
    $blk = Get-InstalledBlock $script:app; if ($blk) { return $blk }
    if ($raw.State -ne 'ok') { return 'there is no install record to change' }
    $old = Read-Installed $key; if (-not $old) { return 'the install record could not be read' }
    $at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
    $ver = $(if ($old.installed) { [string]$old.installed.version } else { [string]$script:app.Version })
    $run = [ordered]@{ version = $ver; build = [string]$buildId; round = [string]$round; at = $at; state = $(if ($Whole) { 'UNINSTALLED' } else { 'NEEDS REVIEW' }) }
    $doc = [ordered]@{ schema = 'rade-installed/' + $installedSchema; about = [string]$raw.Json.about; key = $key; installed = $old.installed; lastRun = $run; steps = $old.steps }
    if ($Whole) { $made = @(); foreach ($n in @($old.steps.Keys)) { foreach ($m in @($old.steps[$n].made)) { if ($m) { $made += $m } } }
      $doc.installed = $null; $doc.steps = [ordered]@{}; $doc.uninstalled = [ordered]@{ version = $ver; at = $at; made = @($made) } }
    Write-FileWhole $raw.Path ($doc | ConvertTo-Json -Depth 9)
    return ''
  } catch { return (ConvertTo-Masked $_.Exception.Message) }
}

<#
.SYNOPSIS
Uninstall: the gate, a fresh backup, then the app's Uninstall steps in order, the record and one report file.
.DESCRIPTION
Stops before any step when the site is not a test site or the backup missed a list. A script step runs as a child
process with the step contract and RADE_MODE=uninstall, RADE_MADE (Invoke-RoundStep); a script step that only prints
SKIP found nothing to remove and counts as done. A hand step shows its card (Invoke-GuideStep); Skip there is not done.
The first step that is not done stops the run: the steps after it do not run (they can need it).
.PARAMETER Base
The RADE app folder.
.PARAMETER Tick
Run while a child script runs (keeps the window alive), or $null.
.PARAMETER OnStep
Called before each step with the step and its number, or $null.
.OUTPUTS
@{ State; Lines; Path }: State is refused, no-backup, done or review; Path is the report file or ''.
#>
function Invoke-Uninstall([string]$Base, [scriptblock]$Tick, [scriptblock]$OnStep) {
  $site = Test-UninstallSite $Base
  if (-not $site.Ok) { return @{ State = 'refused'; Path = ''; Lines = @($site.Lines) } }
  $blk = Get-InstalledBlock $script:app   # a record RADE must not write (newer, another app's, unreadable): no step runs
  if ($blk) { return @{ State = 'refused'; Path = ''; Lines = @(('Uninstall cannot run: ' + $blk + '.'), 'Nothing was changed.') } }   # the record's own reason and what to do
  $bk = Invoke-Backup $Base $Tick
  $noBk = @('Uninstall removed nothing: the backup did not save every list.', 'Nothing on the site changed. Select "Uninstall" again.')
  if ($bk.State -ne 'done') { return @{ State = 'no-backup'; Path = ''; Lines = @($noBk + @($bk.Lines)) } }
  $stamp = Get-ToolStamp; $log = New-Object System.Collections.Generic.List[string]
  # The log callback of the steps: each line masked, kept for the report. Takes the line.
  $say = { param($t) $log.Add((ConvertTo-Masked ([string]$t))) }
  $lines = @(('Test site: ' + $site.Name), ('Backup: ' + (Split-Path -Leaf $bk.Path) + ' (' + @($script:app.Backup).Count + ' lists)'))
  $extra = @{ RADE_MODE = 'uninstall'; RADE_MADE = '' }
  try { $null = Write-UninstallFile $Base; $extra.RADE_MADE = Save-UninstallMade $Base $stamp } catch { & $say ('NOTE: the made list or a step file could not be saved: ' + $_.Exception.Message) }
  $all = @($script:app.Uninstall); $done = 0; $stop = ''
  $script:stepEnvExtra = $extra
  try { for ($i = 0; $i -lt $all.Count; $i++) { $st = $steps[[int]$all[$i]]
      if ($OnStep) { & $OnStep $st ($i + 1) $all.Count }
      & $say ''; & $say ('Uninstall step ' + ($i + 1) + ' of ' + $all.Count + ': ' + $st.Name)
      $t0 = Get-Date
      $r = $(if ($st.Kind -eq 'guide') { Invoke-GuideStep $Base $st $say } else { Invoke-RoundStep $Base $st $say $(if ($Tick) { $Tick } else { {} }) '' })
      $state = Get-StepState $r; $ok = ($state -eq 'PASSED' -or ($state -eq 'SKIPPED' -and $st.Kind -ne 'guide' -and -not $r.Skipped))
      $lines += Get-StepLine $st $r ((Get-Date) - $t0).TotalSeconds
      if ($ok) { $done++; continue }
      $stop = Get-StepTitle $st; break } }
  finally { $script:stepEnvExtra = $null }
  $whole = ($done -eq $all.Count)
  $left = $all.Count - $done - 1; if (-not $whole -and $left -gt 0) { $lines += ('Not run: ' + $left + ' step(s) after "' + $stop + '".') }
  $sv = Save-Uninstalled $whole; $noRec = [bool]($sv -and $whole)
  if ($sv) { $lines += ('NOTE: the install record could not be saved: ' + $sv); $whole = $false }   # the record still says installed
  # A whole Uninstall ends saved progress of this round too: a later install must not resume and keep steps whose items are gone.
  if ($whole) { $cs = Clear-RoundState $Base; if ($cs) { $lines += ('NOTE: the saved progress of this round could not be removed: ' + $cs) } }
  $head = $(if ($whole) { $script:app.Name + ' is uninstalled from the test site. ' + $done + ' of ' + $all.Count + ' steps done.' }
    elseif ($noRec) { 'Every Uninstall step is done, but RADE could not save the install record.' }
    else { 'Uninstall stopped at "' + $stop + '". ' + $done + ' of ' + $all.Count + ' steps done.' })
  $tail = $(if ($whole) { 'Your local files and the backups stay on this computer.' }
    elseif ($noRec) { 'Select "Uninstall" again: RADE saves a backup, runs the steps again and tries to save the record.' }
    else { 'Read the report, fix the cause, then select "Uninstall" again. The backups stay on this computer.' })
  $p = ''
  try { $p = Join-Path (Join-Path $Base 'Uninstall') ('uninstall-' + $stamp + '.txt'); Write-FileWhole $p ((@($head, '') + $lines + @('', 'Log:') + @($log) -join "`r`n") + "`r`n") } catch { $p = '' }
  return @{ State = $(if ($whole) { 'done' } else { 'review' }); Path = $p; Lines = @(@($head, $tail) + $lines) }
}

# ---- Remove RADE from this computer (engine-v40; 90-161.Z R43 E3 b, the PFM, 2026-11-25: option A, "block"). Off while
# any app is installed: the card names those apps. Then RADE's own local files go to the Recycle Bin: RADE\Config,
# RADE\rade-runner.ps1, the RADE shortcut that starts that runner, and in each app folder everything but Backups.
# engine-v42: also each app's shortcut that RADE recorded (RADE\runners\<key>.lnk.txt) and the runners folder.

# Gives the names of the apps that this computer's records show as installed (any paste, any engine). A record that
# cannot be read counts too: RADE cannot tell, so it blocks. Takes nothing; gives back the names (sorted, unique).
function Get-InstalledAppName {
  $recDir = Get-RadeConfigFile 'installed'; $out = @()
  if (-not (Test-Path -LiteralPath $recDir -PathType Container)) { return @() }
  foreach ($f in @(Get-ChildItem -LiteralPath $recDir -File -Filter '*.json' -ErrorAction SilentlyContinue)) {
    $j = $null; try { $j = [System.IO.File]::ReadAllText($f.FullName) | ConvertFrom-Json } catch { $j = $null }
    if (-not $j -or -not [string]$j.key) { $out += 'an app whose record RADE cannot read'; continue }
    if ($null -ne $j.installed -or [string]$j.schema -ne ('rade-installed/' + $installedSchema)) { $out += ((([string]$j.key) -split '/', 2)[-1] -replace '@[^@]*$', '') } }
  return @($out | Sort-Object -Unique)
}

# Says whether a record key's folder part is a plain app folder name: letters, digits, space, ".", "_", "-", starting
# and ending with a letter, digit, "_" or "-" (so Windows cannot trim it to another name), and not Config or Backups.
# Takes the name; gives back $true or $false.
function Test-RadeAppName([string]$Name) { return ($Name -cmatch '^[A-Za-z0-9]([A-Za-z0-9 ._-]*[A-Za-z0-9_-])?$' -and $Name -notin 'Config', 'Backups') }

<#
.SYNOPSIS
Gives the app folders RADE made in the RADE folder: the folder part of each record's key, and this paste's folder.
.DESCRIPTION
Only a plain name (letters, digits, space, ".", "_", "-"; it starts and ends with a letter, digit, "_" or "-", so
Windows cannot trim it to another name), never Config, and only a folder that is there, right under the RADE folder
(review of PR 194: a key "../x" named the OneDrive folder). A folder that no record names is never given.
.OUTPUTS
The full paths of the app folders.
#>
function Get-RadeAppDir {
  $names = @($appFolder); $recDir = Get-RadeConfigFile 'installed'
  foreach ($f in @(Get-ChildItem -LiteralPath $recDir -File -Filter '*.json' -ErrorAction SilentlyContinue)) {
    try { $k = [string](([System.IO.File]::ReadAllText($f.FullName) | ConvertFrom-Json).key) } catch { $k = '' }   # a record it cannot read names no folder
    if ($k -match '^([^/]+)/') { $names += $Matches[1] } }
  # Only a plain folder name (letters, digits, space, ".", "_", "-"; not "." or ".."), and only a folder right under RADE.
  $root = [System.IO.Path]::GetFullPath((Get-RadePath)).TrimEnd('\', '/')
  $plain = @($names | Where-Object { Test-RadeAppName $_ } | Sort-Object -Unique)
  return @($plain | ForEach-Object { [System.IO.Path]::GetFullPath((Join-Path $root $_)) } |
    Where-Object { (Split-Path -Parent $_).TrimEnd('\', '/') -eq $root -and (Split-Path -Leaf $_) -ne 'Config' -and (Test-Path -LiteralPath $_ -PathType Container) })
}

<#
.SYNOPSIS
Remove RADE from this computer: moves RADE's own local files to the Recycle Bin, when no app is installed.
.DESCRIPTION
Order: the RADE shortcut (only one that starts RADE's own runner; its folder is read from Config first), each app's
shortcut (engine-v42), each app folder's items except Backups, the runner, RADE\runners, then RADE\Config. Writes nothing on a site. A file that cannot move is named;
the rest still goes.
.OUTPUTS
@{ State; Lines; Path }: State is blocked, done or review; Path is ''.
#>
function Invoke-RemoveRade {
  $apps = @(Get-InstalledAppName)
  if ($apps.Count) { return @{ State = 'blocked'; Path = ''; Lines = @(@('Uninstall these apps first:') + @($apps | ForEach-Object { '- ' + $_ })) } }
  $root = Get-RadePath; $runner = Join-Path $root 'rade-runner.ps1'; $items = @(); $bad = @()
  $sd = Get-ShortcutDir; $lnk = $(if ($sd) { Join-Path $sd 'RADE.lnk' } else { '' })
  if ($lnk -and (Test-Path -LiteralPath $lnk -PathType Leaf)) {   # only RADE's own shortcut: it starts the runner
    try { $arg = [string](New-Object -ComObject WScript.Shell).CreateShortcut($lnk).Arguments
      if ($arg.Contains('"' + $runner + '"')) { $items += @{ P = $lnk; F = $false; N = 'the RADE shortcut' } } } catch { $null = $_ } }   # a shortcut it cannot read is not RADE's: it stays
  $rd = Join-Path $root 'runners'   # engine-v42: each app's shortcut, only one that starts a runner in this folder
  foreach ($r in @(Get-ChildItem -LiteralPath $rd -File -Filter '*.lnk.txt' -ErrorAction SilentlyContinue)) {
    try { $l = ([string](Get-Content -LiteralPath $r.FullName -TotalCount 1)).Trim()
      if ($l -and (Test-Path -LiteralPath $l -PathType Leaf) -and ([string](New-Object -ComObject WScript.Shell).CreateShortcut($l).Arguments).Contains('"' + $rd + '\')) {
        $items += @{ P = $l; F = $false; N = ('the shortcut ' + (Split-Path -Leaf $l)) } } } catch { $null = $_ } }   # a shortcut it cannot read is not RADE's: it stays
  foreach ($d in @(Get-RadeAppDir)) { foreach ($c in @(Get-ChildItem -LiteralPath $d -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'Backups' })) {
      $items += @{ P = $c.FullName; F = [bool]$c.PSIsContainer; N = ((Split-Path -Leaf $d) + '\' + $c.Name) } } }
  if (Test-Path -LiteralPath $runner -PathType Leaf) { $items += @{ P = $runner; F = $false; N = 'the RADE runner' } }
  if (Test-Path -LiteralPath $rd -PathType Container) { $items += @{ P = $rd; F = $true; N = 'RADE\runners' } }
  $cfg = Join-Path $root 'Config'; if (Test-Path -LiteralPath $cfg -PathType Container) { $items += @{ P = $cfg; F = $true; N = 'RADE\Config' } }
  foreach ($i in $items) { try { Move-ToRecycleBin $i.P -Folder:$i.F } catch { $bad += ('Not moved: ' + $i.N + ' [' + $_.Exception.GetType().Name + ']') } }
  $head = $(if ($bad.Count) { [string]$bad.Count + ' of ' + $items.Count + ' items did not move to the Recycle Bin.' } else { [string]$items.Count + ' items are in the Recycle Bin.' })
  return @{ State = $(if ($bad.Count) { 'review' } else { 'done' }); Path = ''; Lines = @(@($head, 'The Backups folders stay. To get an item back, open the Recycle Bin.') + $bad) }
}
