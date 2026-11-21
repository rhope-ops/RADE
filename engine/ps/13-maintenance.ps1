# RADE engine part 13, the Maintenance tools (the Administrator, 2026-11-20; docs/engine.md "Maintenance run types").
# Diagnose: read-only; the install record, the app's local files and the app's RADE checks again; one report file.
# Back up: reads only the lists the app's manifest names ("backup") and saves each as JSON plus a CSV copy.
# Restore (engine-v31; the Administrator, 2026-11-21): puts back the rows of a backup that are missing from their list,
# on a test site only: a dry run with counts first, then (after the user types the app name) a fresh backup, the pause
# switch, the Recycle Bin, then new rows with lookups re-pointed. A row that is on the list is never changed.
# Uses parts 01 to 08 (Get-BasePath, Read-Installed, Get-InstalledKey, Get-StartPath, Invoke-Check, Invoke-ChildScript).
# Network: Diagnose runs the app's own RADE checks (their fixed addresses only); Back up signs in to the saved site and
# reads only the lists the manifest names (AGENTS.md "No reconnaissance"); Restore reads the same lists, their fields and
# the site's Recycle Bin. Diagnose and Back up never write to the site.
# Writes: Diagnose: Diagnose\diagnose-<time>.txt; Back up: Backups\<time>\<list>.json and .csv (the app folder);
# Restore: site rows of the named lists (missing rows only) and the app's pause-switch row, after the typed confirm.
# Credentials: the interactive CAC sign-in of PnP (-UseWebLogin), for Back up and Restore only.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

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
  $rp = Join-Path (Get-RadePath) 'rade-runner.ps1'
  if (Test-Path -LiteralPath $rp -PathType Leaf) { $out += ConvertTo-ToolLine 'PASS' 'The RADE runner copy is saved' '' }
  else { $out += ConvertTo-ToolLine 'NOTE' 'The RADE runner copy is not saved, so the desktop shortcut cannot start RADE' $repair }
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
  $all = @(Get-DiagnoseInstall) + @(Get-DiagnoseCheck $Base $Tick)
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
  $null = & { Connect-PnPOnline -Url $Site -UseWebLogin -ErrorAction Stop } *>&1
  $i = 0
  foreach ($name in ($Lists -split '\|')) {
    $i++
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
  $r = Invoke-ChildScript $backupScript ('-Site "' + $site + '" -Folder "' + $dir + '" -Lists "' + ($lists -join '|') + '"') 1800 $Tick
  $got = @{}; $res = ''
  foreach ($l in $r.Lines) { if ($l -match '^LIST (\d+) (.+)$') { $got[[int]$Matches[1]] = $Matches[2] } elseif ($l -match '^RESULT (\S+)') { $res = $Matches[1] } }
  if ($res -ne 'done') { $why = $(switch ($res) { 'no-pnp' { 'the SharePoint tool is not installed' } 'not-connected' { 'the sign-in did not finish' } default { 'it stopped: ' + $r.Why } })
    $gone = Clear-BackupDir $dir
    $left = $(if ($gone) { 'Nothing on the site changed.' } else { 'Nothing on the site changed. Its unfinished folder stays: ' + (ConvertTo-Masked $dir) })
    return @{ State = 'failed'; Path = ''; Lines = @(('Back up saved nothing: ' + $why + '.'), $left, 'Select "Back up" again.') } }
  $lines = @(); $bad = 0
  for ($i = 1; $i -le $lists.Count; $i++) {
    $n = [string]$lists[$i - 1]; $v = [string]$got[$i]; $ok = $false
    if ($v -match '^\d+$') { $ok = Rename-BackupFile $dir $i (Get-BackupFileName $n) }
    if ($ok) { $lines += ('PASS: "' + $n + '": ' + $v + ' rows saved'); continue }
    $bad++; $ty = $(if ($v -match '^failed (\S+)') { ' (' + $Matches[1] + ')' } elseif ($v) { ' (its files could not be named)' } else { '' })
    $lines += ('FINDING: "' + $n + '" was not saved' + $ty + '. What to do: check that the list exists and that you can read it, then select "Back up" again')
  }
  $head = $(if ($bad) { [string]$bad + ' of ' + $lists.Count + ' lists were not saved.' } else { 'All ' + $lists.Count + ' lists were saved.' })
  return @{ State = $(if ($bad) { 'failed' } else { 'done' }); Path = $dir; Lines = @(@($head, 'Nothing on the site changed.') + $lines) }
}

# ---- Restore (engine-v31; plan docs/reviews/2026-11-21-plan-restore-v31.md). The child script runs in two modes:
# "plan" (the dry run: reads only) and "write" (after the typed confirm). It prints only list numbers, counts and error
# types: never the site, a name, an ID or a value.
$restoreScript = @'
param([string]$Site, [string]$Folder, [string]$Lists, [string]$Mode, [string]$Expect, [string]$Pause, [string]$MapFile)
# RADE Restore: missing rows only. Mode plan reads the site and writes nothing; mode write puts the missing rows back.
Remove-TypeData -TypeName System.Array -ErrorAction SilentlyContinue
# The file name of a saved list (the same rule as Get-BackupFileName in the engine). Takes the list title.
function Get-FileName([string]$N) { return ($N -replace '[^A-Za-z0-9 _()-]', '_') }
# The IDs in a saved lookup or person value "id;#text;#id;#text" (the even parts). Takes the value; gives back ints.
function Get-SavedIds($V) { $p = @(([string]$V) -split ';#'); return @(for ($k = 0; $k -lt $p.Count; $k += 2) { if ($p[$k] -match '^\d+$') { [int]$p[$k] } }) }
# Turns a saved value (Back up's plain form) into what Add-PnPListItem takes for a field of this type. Lookup IDs are
# re-pointed by $Map (old ID to new ID) of the list the lookup reads, when that list is one of the restored lists; an ID
# that is not there is dropped and counted in $script:unlinked. Takes the field, the value and the restored lists' data.
function ConvertTo-WriteValue($F, $V, $Info) {
  if ($null -eq $V -or ([string]$V) -eq '') { return $null }
  $t = [string]$F.TypeAsString
  if ($t -in 'Lookup', 'LookupMulti') {
    $j = $Info.ById[[string]$F.LookupGuid]; $out = @()
    foreach ($id in (Get-SavedIds $V)) {
      if ($null -eq $j) { $out += $id; continue }   # a list RADE does not restore: the ID stays
      $tgt = $Info.Lists[$j]
      if ($tgt.Map.ContainsKey($id)) { $out += [int]$tgt.Map[$id] } elseif ($tgt.Have.ContainsKey($id)) { $out += $id } else { $script:unlinked++ } }
    if (-not $out.Count) { return $null }
    if ($t -eq 'Lookup') { return $out[0] } else { return $out } }
  if ($t -eq 'User') { $i = @(Get-SavedIds $V); if ($i.Count) { return $i[0] } else { return $null } }
  if ($t -eq 'UserMulti') { $i = @(Get-SavedIds $V); if ($i.Count) { return $i } else { return $null } }
  if ($t -eq 'URL') { $p = ([string]$V) -split ';#', 2; if ($p.Count -gt 1 -and $p[1]) { return ($p[0] + ', ' + $p[1]) } else { return $p[0] } }
  if ($t -in 'TaxonomyFieldType', 'TaxonomyFieldTypeMulti') { $g = @(([string]$V) -split ';#' | ForEach-Object { ($_ -split '\|')[-1] } | Where-Object { $_ })
    if ($t -eq 'TaxonomyFieldType') { return $g[0] } else { return $g } }
  if ($t -eq 'MultiChoice') { return @(([string]$V) -split ';#' | Where-Object { $_ }) }
  if ($t -eq 'DateTime') { if ($V -is [datetime]) { return $V }
    return [datetime]::Parse([string]$V, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind) }
  if ($t -eq 'Geolocation') { return $null }   # not written in v1 (no plain form PnP takes)
  return $V
}
try {
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { 'RESULT no-pnp'; exit 3 }
  $pin = @($mod | Where-Object { [string]$_.Version -eq '1.12.0' }); if ($pin.Count) { $mod = $pin }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  $null = & { Connect-PnPOnline -Url $Site -UseWebLogin -ErrorAction Stop } *>&1
} catch { 'RESULT not-connected ' + $_.Exception.GetType().Name; exit 2 }
$names = @($Lists -split '\|'); $info = @{ Lists = @{}; ById = @{} }
# The rows an earlier Restore made new on this site (old ID to new ID, per list title), from any backup of this app, so
# no run makes them again: Backups\~restore-map-<site hash>.json ('~': no backup folder has it; one file per site, as
# IDs belong to a site). A row re-made twice is a chain (5 to 20, then 20 to 21): it is followed to its end.
$mapFile = $MapFile; $old = @{}
if (Test-Path -LiteralPath $mapFile -PathType Leaf) { try { $mj = [System.IO.File]::ReadAllText($mapFile) | ConvertFrom-Json
    foreach ($q in $mj.PSObject.Properties) { $h = @{}; foreach ($r in $q.Value.PSObject.Properties) { $h[[int]$r.Name] = [int]$r.Value }; $old[$q.Name] = $h } } catch { 'MAP failed'; exit 6 } }
# Reads each list: the saved rows, the IDs on the list now and the writable fields. A list with no saved file or no
# list on the site is reported and left out.
for ($i = 1; $i -le $names.Count; $i++) {
  $n = $names[$i - 1]; $f = Join-Path $Folder ((Get-FileName $n) + '.json')
  if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { 'PLAN ' + $i + ' nofile'; continue }
  try {
    $saved = @([System.IO.File]::ReadAllText($f) | ConvertFrom-Json) | Where-Object { $null -ne $_ }
    $list = $null; $null = & { $script:l = Get-PnPList -Identity $n -Includes RootFolder -ErrorAction Stop } *>&1; $list = $script:l
    if (-not $list) { 'PLAN ' + $i + ' nolist'; continue }
    $script:now = @(); $null = & { $script:now = @(Get-PnPListItem -List $n -PageSize 500 -Fields 'ID' -ErrorAction Stop) } *>&1
    $have = @{}; foreach ($it in $script:now) { $have[[int]$it.Id] = $true }
    $script:fs = @(); $null = & { $script:fs = @(Get-PnPField -List $n -ErrorAction Stop) } *>&1
    $fields = @(foreach ($x in $script:fs) {
      if ($x.ReadOnlyField -or $x.Hidden -or ([string]$x.TypeAsString) -in 'Computed', 'Calculated', 'Attachments', 'ContentTypeId', 'File', 'Counter') { continue }
      if ([string]$x.InternalName -in 'ContentType', 'Attachments') { continue }
      $g = ''; if ([string]$x.SchemaXml -match 'List="\{?([0-9a-fA-F-]{36})\}?"') { $g = $Matches[1].ToLowerInvariant() }
      [pscustomobject]@{ InternalName = [string]$x.InternalName; TypeAsString = [string]$x.TypeAsString; LookupGuid = $g } })
    # A saved row is on the list under its own ID, or under the new ID an earlier Restore gave it.
    $map = @{}
    if ($old.ContainsKey($n)) { $om = $old[$n]
      foreach ($k in @($om.Keys)) { $to = $om[$k]; $hop = 0; while ($om.ContainsKey($to) -and $hop -lt 100) { $to = $om[$to]; $hop++ }
        if ($have.ContainsKey($to)) { $map[$k] = $to } } }
    $ids = @{}; foreach ($r in $saved) { $ids[[int]$r.ID] = $true; if ($map.ContainsKey([int]$r.ID)) { $ids[$map[[int]$r.ID]] = $true } }
    $missing = @($saved | Where-Object { -not $have.ContainsKey([int]$_.ID) -and -not $map.ContainsKey([int]$_.ID) })
    $after = @($have.Keys | Where-Object { -not $ids.ContainsKey($_) }).Count
    $info.Lists[$i] = @{ Name = $n; Saved = $saved.Count; Missing = $missing; Have = $have; Fields = $fields; Map = $map; Bin = @{}; After = $after
      Url = ([string]$list.RootFolder.ServerRelativeUrl).Trim('/').ToLowerInvariant() }
    $info.ById[([string]$list.Id).Trim('{}').ToLowerInvariant()] = $i
  } catch { 'PLAN ' + $i + ' failed ' + $_.Exception.GetType().Name }
}
# The Recycle Bin (R1): a deleted row of a restored list that is missing comes back with its own ID.
$binOk = $true
try { $script:bin = @(); $null = & { $script:bin = @(Get-PnPRecycleBinItem -RowLimit 5000 -ErrorAction Stop) } *>&1
  foreach ($b in $script:bin) {
    if ([string]$b.ItemType -ne 'ListItem' -or [string]$b.LeafName -notmatch '^(\d+)_\.000$') { continue }
    $id = [int]$Matches[1]; $dir = ([string]$b.DirName).Trim('/').ToLowerInvariant()
    foreach ($k in @($info.Lists.Keys)) { $L = $info.Lists[$k]
      if ($dir -eq $L.Url -and @($L.Missing | Where-Object { [int]$_.ID -eq $id }).Count -and -not $L.Bin.ContainsKey($id)) { $L.Bin[$id] = $b } } } }
catch { $binOk = $false; 'BIN failed ' + $_.Exception.GetType().Name }
$keys = @($info.Lists.Keys | Sort-Object)
# Writes the map file: every old-to-new ID pair the Restore runs on this site made, the earlier ones kept. Takes nothing.
function Save-RestoreMap {
  $o = [ordered]@{}
  foreach ($q in @($old.Keys)) { $o[$q] = [ordered]@{}; foreach ($k in @($old[$q].Keys)) { $o[$q][[string]$k] = $old[$q][$k] } }
  foreach ($k in $keys) { $L = $info.Lists[$k]; if (-not $o.Contains($L.Name)) { $o[$L.Name] = [ordered]@{} }
    foreach ($m in @($L.Map.Keys)) { $o[$L.Name][[string]$m] = $L.Map[$m] } }
  [System.IO.File]::WriteAllText($mapFile, (ConvertTo-Json -InputObject $o -Depth 4), (New-Object System.Text.UTF8Encoding $true)) }
foreach ($k in $keys) { $L = $info.Lists[$k]
  # A short hash of the missing IDs and the bin IDs: the write checks the same rows, not only the same count (no ID is printed).
  $txt = (@($L.Missing | ForEach-Object { [int]$_.ID } | Sort-Object) -join ',') + '/' + (@($L.Bin.Keys | Sort-Object) -join ',')
  $sha = [System.Security.Cryptography.SHA256]::Create(); $L.Sig = (-join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($txt))[0..5] | ForEach-Object { $_.ToString('x2') })); $sha.Dispose()
  'PLAN ' + $k + ' saved=' + $L.Saved + ' now=' + $L.Have.Count + ' missing=' + $L.Missing.Count + ' bin=' + $L.Bin.Count +
    ' new=' + ($L.Missing.Count - $L.Bin.Count) + ' after=' + $L.After + ' sig=' + $L.Sig }
if ($Mode -ne 'write') { 'RESULT plan'; exit 0 }
# The write. First: the site must be as the dry run saw it (the same missing rows and Recycle Bin rows per list, by the
# hash), else nothing is written.
$want = @{}; foreach ($e in ($Expect -split ',')) { if ($e -match '^(\d+):([0-9a-f]+)$') { $want[[int]$Matches[1]] = $Matches[2] } }
foreach ($k in $keys) { if ($want[$k] -ne $info.Lists[$k].Sig) { 'RESULT changed'; exit 4 } }
if ($want.Count -ne $keys.Count) { 'RESULT changed'; exit 4 }
# R2: the pause switch. Its earlier value is read first and put back after; a switch that is on already stops the run.
$pz = $null; $pRow = $null; $pOld = $null
if ($Pause) { $q = $Pause -split '\|'; $pz = @{ List = $q[0]; Title = $q[1]; Field = $q[2]; On = $q[3] }
  try { $caml = '<View><Query><Where><Eq><FieldRef Name="Title"/><Value Type="Text">' + $pz.Title + '</Value></Eq></Where></Query></View>'
    $script:pr = $null; $null = & { $script:pr = @(Get-PnPListItem -List $pz.List -Query $caml -ErrorAction Stop) } *>&1; $pRow = @($script:pr)[0]
    if (-not $pRow) { 'RESULT no-pause-row'; exit 5 }
    $pOld = [string]$pRow[$pz.Field]
    if ($pOld -eq $pz.On) { 'RESULT paused-already'; exit 5 }
    $null = & { Set-PnPListItem -List $pz.List -Identity $pRow.Id -Values @{ $pz.Field = $pz.On } -ErrorAction Stop } *>&1; 'PAUSE on' }
  catch { 'RESULT pause-failed ' + $_.Exception.GetType().Name; exit 5 } }
$stopMake = $false
try {
  # R1: the Recycle Bin first, every list; a row that does not come back is made new below.
  foreach ($k in $keys) { $L = $info.Lists[$k]; $L.FromBin = 0; $L.BinFailed = 0
    foreach ($id in @($L.Bin.Keys)) {
      try { $null = & { Restore-PnPRecycleBinItem -Identity $L.Bin[$id] -Force -ErrorAction Stop } *>&1; $L.Have[$id] = $true; $L.FromBin++ }
      catch { $L.Bin.Remove($id); $L.BinFailed++ } }
    # The IDs on the list again: a Recycle Bin restore that reported an error but worked is not made a second time.
    if ($L.BinFailed) { try { $script:now = @(); $null = & { $script:now = @(Get-PnPListItem -List $L.Name -PageSize 500 -Fields 'ID' -ErrorAction Stop) } *>&1
        foreach ($it in $script:now) { $L.Have[[int]$it.Id] = $true } } catch { $stopMake = $true } } }
  # R5: lists in dependency order (a list whose lookup reads another restored list comes after it); a loop keeps the
  # manifest order for the lists left.
  $order = @(); $left = [System.Collections.Generic.List[int]]::new(); foreach ($k in $keys) { $left.Add($k) }
  while ($left.Count) { $next = $null
    foreach ($k in $left) { $deps = @($info.Lists[$k].Fields | Where-Object { $_.LookupGuid } | ForEach-Object { $info.ById[$_.LookupGuid] } |
        Where-Object { $null -ne $_ -and $_ -ne $k -and $left.Contains($_) })
      if (-not $deps.Count) { $next = $k; break } }
    if ($null -eq $next) { $next = $left[0] }
    $order += $next; $null = $left.Remove($next) }
  foreach ($k in $order) { $L = $info.Lists[$k]; $L.Made = 0; $L.Failed = 0; $script:unlinked = 0
    if ($stopMake) { continue }   # a list could not be read again after the Recycle Bin: no new row, so none is made twice
    foreach ($r in @($L.Missing | Where-Object { -not $L.Have.ContainsKey([int]$_.ID) } | Sort-Object { [int]$_.ID })) {
      $v = @{}
      foreach ($fd in $L.Fields) { $p = $r.PSObject.Properties[$fd.InternalName]; if (-not $p) { continue }
        $w = ConvertTo-WriteValue $fd $p.Value $info; if ($null -ne $w) { $v[$fd.InternalName] = $w } }
      try { $script:made = $null; $null = & { $script:made = Add-PnPListItem -List $L.Name -Values $v -ErrorAction Stop } *>&1
        $L.Map[[int]$r.ID] = [int]$script:made.Id; $L.Made++ } catch { $L.Failed++ }
      Save-RestoreMap }   # after each row: a run that stops halfway never makes a row twice
    $L.Unlinked = $script:unlinked }
  # R7 (counts only): the rows on each list after the write.
  foreach ($k in $keys) { $L = $info.Lists[$k]; $c = -1
    try { $script:now = @(); $null = & { $script:now = @(Get-PnPListItem -List $L.Name -PageSize 500 -Fields 'ID' -ErrorAction Stop) } *>&1; $c = $script:now.Count } catch { $c = -1 }
    'DONE ' + $k + ' bin=' + $L.FromBin + ' made=' + $L.Made + ' failed=' + ($L.Failed + 0) + ' binfailed=' + $L.BinFailed + ' unlinked=' + ($L.Unlinked + 0) + ' now=' + $c }
} finally {
  if ($pz) { try { $null = & { Set-PnPListItem -List $pz.List -Identity $pRow.Id -Values @{ $pz.Field = $pOld } -ErrorAction Stop } *>&1; 'RESUME ok' } catch { 'RESUME failed' } } }
if ($stopMake) { 'RESULT reread-failed'; exit 7 }
'RESULT done'; exit 0
'@

<#
.SYNOPSIS
Gives the backups on this computer that Restore can use, newest first (10 at most).
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
  foreach ($d in @(Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending)) {
    $n = @($script:app.Backup | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $d.FullName ((Get-BackupFileName $_) + '.json')) -PathType Leaf) }).Count
    if ($n) { $out += @{ Path = $d.FullName; Name = $d.Name; Lists = $n } }
    if ($out.Count -ge 10) { break } }
  return $out
}

<#
.SYNOPSIS
Says whether Restore may write on the saved site: the app names Restore ("restore") and the site is one of its test sites.
.DESCRIPTION
Restore runs only on a site the app's manifest lists as a test site (the Administrator, 2026-11-20). The site name is
the part of the saved address after the site prefix, compared without case.
.PARAMETER Base
The RADE app folder.
.OUTPUTS
@{ Ok; Site; Lines }: Ok is $true when Restore may run; Lines say why not.
#>
function Test-RestoreSite([string]$Base) {
  $rs = $script:app.Restore
  if (-not $rs) { return @{ Ok = $false; Site = ''; Lines = @(($script:app.Name + ' does not use Restore in this version.'), 'Nothing was changed.') } }
  $site = Get-SiteUrl $Base
  if (-not (Test-SiteUrl $site)) { return @{ Ok = $false; Site = ''; Lines = @('No site address is saved, so Restore did not sign in.', 'Select "Repair": its checks ask for the site address.') } }
  $name = $site.Substring($sitePrefix.Length).TrimEnd('/')
  if (@($rs.TestSites | Where-Object { [string]$_ -eq $name }).Count) { return @{ Ok = $true; Site = $site; Lines = @() } }
  return @{ Ok = $false; Site = $site; Lines = @('Restore runs only on a test site that the app names. The saved site is not one.', 'Nothing was changed.') }
}

# Reads the PLAN lines of the Restore child script: one table for each list number. Takes the output lines; gives
# back @{ <n> = @{ Saved; Now; Missing; Bin; New; After; Sig } or @{ Error } }.
function Read-RestorePlan([string[]]$Lines) {
  $p = @{}
  foreach ($l in $Lines) {
    if ($l -match '^PLAN (\d+) saved=(\d+) now=(\d+) missing=(\d+) bin=(\d+) new=(\d+) after=(\d+) sig=([0-9a-f]+)$') {
      $p[[int]$Matches[1]] = @{ Saved = [int]$Matches[2]; Now = [int]$Matches[3]; Missing = [int]$Matches[4]; Bin = [int]$Matches[5]
        New = [int]$Matches[6]; After = [int]$Matches[7]; Sig = $Matches[8] } }
    elseif ($l -match '^PLAN (\d+) (.+)$') { $p[[int]$Matches[1]] = @{ Error = $Matches[2] } } }
  return $p
}
# The -MapFile argument of the Restore child script: Backups\~restore-map-<site hash>.json in the app folder, one record
# for every backup of this app on that site (reviews of PR 151: a map per backup folder let two backups make the same row
# twice; a map for every site would mix two sites' IDs). Takes the app folder and the site address.
function Get-RestoreMapArg([string]$Base, [string]$Site) {
  $h = Get-ShortHash $Site.Trim().TrimEnd('/').ToLowerInvariant()
  return (' -MapFile "' + (Join-Path (Join-Path $Base 'Backups') ('~restore-map-' + $h + '.json')) + '"') }
# The words for a sign-in or tool stop of a child script. Takes the RESULT word and the child's Why.
function Get-ChildStopText([string]$Res, [string]$Why) {
  switch ($Res) { 'no-pnp' { return 'the SharePoint tool is not installed' } 'not-connected' { return 'the sign-in did not finish' }
    'reread-failed' { return 'a list could not be read again after the Recycle Bin, so no new row was made' }
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
  $t = Test-RestoreSite $Base
  if (-not $t.Ok) { return @{ State = 'refused'; Lines = $t.Lines; Plan = @{}; Expect = ''; Missing = 0 } }
  $lists = @($script:app.Backup | Where-Object { $_ })
  $r = Invoke-ChildScript $restoreScript ('-Site "' + $t.Site + '" -Folder "' + $Dir + '" -Lists "' + ($lists -join '|') + '" -Mode plan' + (Get-RestoreMapArg $Base $t.Site)) 1800 $Tick
  $res = ''; foreach ($l in $r.Lines) { if ($l -match '^RESULT (\S+)') { $res = $Matches[1] } elseif ($l -eq 'MAP failed') { $res = 'map' } }
  $stop = $(if ($res -eq 'map') { "the record of an earlier Restore on this site (Backups\~restore-map-*.json) could not be read" } else { Get-ChildStopText $res $r.Why })
  if ($res -ne 'plan') { return @{ State = 'failed'; Plan = @{}; Expect = ''; Missing = 0; Lines = @(('The dry run did not finish: ' + $stop + '.'), 'Nothing was changed.') } }
  $plan = Read-RestorePlan $r.Lines; $lines = @(); $exp = @(); $tot = 0; $nb = 0; $nn = 0
  for ($i = 1; $i -le $lists.Count; $i++) {
    $n = [string]$lists[$i - 1]; $p = $plan[$i]
    if (-not $p) { $lines += ('NOTE: "' + $n + '": no result'); continue }
    if ($p.Error) { $why = $(switch -regex ($p.Error) { '^nofile' { 'this backup has no file for it' } '^nolist' { 'the list is not on the site (Restore does not make lists)' }
          default { 'it could not be read (' + ($p.Error -replace '^failed ', '') + ')' } })
      $lines += ('NOTE: "' + $n + '" is left out: ' + $why); continue }
    $exp += ([string]$i + ':' + $p.Sig); $tot += $p.Missing; $nb += $p.Bin; $nn += $p.New
    $lines += ('"' + $n + '": ' + $p.Saved + ' in the backup, ' + $p.Now + ' on the list now. Would put back ' + $p.Missing +
      ' (' + $p.Bin + ' from the Recycle Bin, ' + $p.New + ' as new rows). ' + $p.After + ' made after the backup stay.') }
  $head = @(('Dry run: ' + $tot + ' rows would come back (' + $nb + ' from the Recycle Bin, ' + $nn + ' as new rows). Nothing was written.'))
  if (@($r.Lines | Where-Object { $_ -like 'BIN failed*' }).Count) { $head += 'NOTE: the Recycle Bin could not be read, so every missing row would come back as a new row (a new ID).' }
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
  $t = Test-RestoreSite $Base
  if (-not $t.Ok) { return @{ State = 'refused'; Path = ''; Lines = $t.Lines } }
  if (-not $Plan -or $Plan.State -ne 'plan' -or -not $Plan.Missing) { return @{ State = 'failed'; Path = ''; Lines = @('There are no rows to put back.', 'Nothing was changed.') } }
  $fresh = Invoke-Backup $Base $Tick   # R3: the restore itself can be undone from this backup
  if ($fresh.State -ne 'done') { return @{ State = 'failed'; Path = ''; Lines = @(@('Restore wrote nothing: the fresh backup before it did not save every list.') + @($fresh.Lines)) } }
  $lists = @($script:app.Backup | Where-Object { $_ }); $pz = $script:app.Restore.Pause
  $pa = $(if ($pz) { ' -Pause "' + $pz.List + '|' + $pz.Title + '|' + $pz.Field + '|' + $pz.On + '"' } else { '' })
  $r = Invoke-ChildScript $restoreScript ('-Site "' + $t.Site + '" -Folder "' + $Dir + '" -Lists "' + ($lists -join '|') + '" -Mode write -Expect "' + $Plan.Expect + '"' + $pa +
    (Get-RestoreMapArg $Base $t.Site)) 3600 $Tick
  $res = ''; $done = @{}; $resume = ''
  foreach ($l in $r.Lines) { if ($l -match '^RESULT (\S+)') { $res = $Matches[1] } elseif ($l -match '^DONE (\d+) (.+)$') { $done[[int]$Matches[1]] = $Matches[2] }
    elseif ($l -match '^RESUME (\S+)') { $resume = $Matches[1] } }
  $fl = 'Fresh backup before Restore: ' + (ConvertTo-Masked $fresh.Path)
  $stop = $(switch ($res) { 'changed' { 'the site changed after the dry run. Run Restore again for a new dry run' }
      'paused-already' { 'the pause switch is on already (another Restore, or it was left on). Check it, then run Restore again' }
      'no-pause-row' { "the app's pause-switch row is not on the site" } 'pause-failed' { 'the pause switch could not be set' } default { '' } })
  if ($stop) { return @{ State = $(if ($res -eq 'changed') { 'changed' } else { 'failed' }); Path = $fresh.Path; Lines = @(('Restore wrote no rows: ' + $stop + '.'), $fl) } }
  $lines = @(); $bad = 0; $back = 0
  for ($i = 1; $i -le $lists.Count; $i++) {
    $n = [string]$lists[$i - 1]; $d = [string]$done[$i]; $p = $Plan.Plan[$i]
    if (-not $p -or $p.Error) { continue }
    if ($d -notmatch '^bin=(\d+) made=(\d+) failed=(\d+) binfailed=(\d+) unlinked=(\d+) now=(-?\d+)$') {
      $bad++; $lines += ('FINDING: "' + $n + '": no result. What to do: compare the list with the backup'); continue }
    $b = [int]$Matches[1]; $m = [int]$Matches[2]; $f = [int]$Matches[3]; $u = [int]$Matches[5]; $now = [int]$Matches[6]; $back += $b + $m
    $want = $p.Now + $b + $m; $ok = ($f -eq 0 -and $now -eq $want)
    $txt = '"' + $n + '": ' + $b + ' back from the Recycle Bin, ' + $m + ' made new; ' + $now + ' rows on the list now'
    if ($u) { $txt += '; ' + $u + ' lookup value(s) left empty (the row they pointed to is not there)' }
    if ($ok) { $lines += ('PASS: ' + $txt); continue }
    $bad++; $lines += ('FINDING: ' + $txt + $(if ($f) { '; ' + $f + ' row(s) could not be written' } else { '' }) + '. What to do: compare the list with the backup') }
  if ($res -ne 'done') { $bad++
    $lines += ('FINDING: Restore stopped before the end: ' + (Get-ChildStopText $res $r.Why) + '. What to do: run Restore again (it puts back only what is still missing)') }
  if ($pz -and $resume -ne 'ok') { $bad++; $lines += "FINDING: the pause switch could not be put back. What to do: set it back by hand in the app's settings" }
  $head = @(('Restore put back ' + $back + ' of ' + $Plan.Missing + ' rows. Rows on the lists were not changed.'), $fl)
  if ($pz -and $resume -eq 'ok') { $head += "The app's pause switch is back as it was." }
  return @{ State = $(if ($bad) { 'failed' } else { 'done' }); Path = $fresh.Path; Lines = @($head + $lines) }
}
