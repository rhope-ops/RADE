# RADE engine part 14, the Maintenance tool Restore (engine-v31; the local test-site mark, engine-v32; the Administrator,
# 2026-11-20 and 2026-11-21; plan docs/reviews/2026-11-21-plan-restore-v31.md; docs/engine.md "Maintenance run types").
# Puts back the rows of a backup that are missing from their list, on a test site only: a dry run with counts first,
# then (after the user types the app name) a fresh backup, the pause switch, the Recycle Bin, then new rows with lookups
# re-pointed. A row that is on the list is never changed, and no row is made twice.
# Uses parts 01 to 08, 13 and 16 (Get-SiteUrl, Test-SiteUrl, Get-SiteMark, Invoke-ChildScript, Invoke-Backup,
# Get-BackupFileName, ConvertTo-Masked).
# Network: signs in to the saved site and reads only the lists the manifest names ("backup"), their fields and the
# site's Recycle Bin (AGENTS.md "No reconnaissance").
# Writes: site rows of the named lists (missing rows only) and the app's pause-switch row, after the typed confirm; on
# the computer, a fresh backup, Backups\~restore-map-<site hash>.json and, from the mark card,
# Config\<prefix>-restore-test-site.txt.
# Credentials: the interactive CAC sign-in of PnP (-UseWebLogin).
# The functions the window and the text mode call (Get-BackupSet to Invoke-Restore) are in part 15,
# engine/ps/15-restore-run.ps1.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

$restoreWriteSeconds = 3600   # time limit of the Restore write, in seconds: a sign-in and every row it puts back
$backupSetMax = 10            # backups the Restore card lists, newest first (one card of rows)

# ---- Restore (engine-v31; plan docs/reviews/2026-11-21-plan-restore-v31.md). The child script runs in two modes:
# "plan" (the dry run: reads only) and "write" (after the typed confirm). It prints only list numbers, counts and error
# types: never the site, a name, an ID or a value.
$restoreScript = @'
param([string]$Site, [string]$Folder, [string]$Lists, [string]$Mode, [string]$Expect, [string]$Pause, [string]$MapFile)
# <RADE sign-in window size>
# RADE Restore: missing rows only. Mode plan reads the site and writes nothing; mode write puts the missing rows back.
# Output: PLAN, BIN, PAUSE, DONE, RESUME and RESULT lines with numbers, error types and a short hash only.
Remove-TypeData -TypeName System.Array -ErrorAction SilentlyContinue   # Windows PowerShell 5.1 writes an array as {value, Count} while it is loaded; absent elsewhere
$PageSize = 500         # rows a read asks for at once: under the SharePoint list view threshold of 5,000
$BinRowLimit = 5000     # Recycle Bin items read at most (docs/engine.md "Maintenance run types", limits)
$SigBytes = 6           # bytes of the SHA-256 kept as the dry-run hash of a list (12 hex characters)
$SkipTypes = @('Computed', 'Calculated', 'Attachments', 'ContentTypeId', 'File', 'Counter')   # field types SharePoint sets itself
$SkipNames = @('ContentType', 'Attachments')                                                   # fields SharePoint sets itself

# ---- Small helpers.
# The file name of a saved list (the same rule as Get-BackupFileName in the engine). Takes the list title.
function Get-FileName([string]$Name) { return ($Name -replace '[^A-Za-z0-9 _()-]', '_') }
# The IDs in a saved lookup or person value "id;#text;#id;#text" (the even parts). Takes the value; gives back ints.
function Get-SavedIds($Value) { $parts = @(([string]$Value) -split ';#')
  return @(for ($k = 0; $k -lt $parts.Count; $k += 2) { if ($parts[$k] -match '^\d+$') { [int]$parts[$k] } }) }
# Reads the IDs on a list now. Takes the list title; gives back a table ID -> $true; throws when the list cannot be read.
function Read-ListIds([string]$Name) { $script:rows = @()
  $null = & { $script:rows = @(Get-PnPListItem -List $Name -PageSize $PageSize -Fields 'ID' -ErrorAction Stop) } *>&1
  $ids = @{}; foreach ($item in $script:rows) { $ids[[int]$item.Id] = $true }; return $ids }

# ---- The same-row groups (reviews 3 and 4 of PR 151): each Restore that makes a row new links its old ID and the new
# one; all IDs linked, step by step, are one row. A groups table holds P (each ID's parent) and M (each root's IDs), so
# a group is found at once, not by a scan.
# Gives the root ID of a group (and shortens the path). Takes the groups and an ID.
function Get-Root($Groups, [int]$Id) { if (-not $Groups.P.ContainsKey($Id)) { return $Id }
  $root = $Id; while ($Groups.P[$root] -ne $root) { $root = $Groups.P[$root] }
  while ($Groups.P[$Id] -ne $root) { $next = $Groups.P[$Id]; $Groups.P[$Id] = $root; $Id = $next }; return $root }
# Links two IDs as one row. Takes the groups and the two IDs.
function Join-Ids($Groups, [int]$First, [int]$Second) {
  foreach ($id in $First, $Second) { if (-not $Groups.P.ContainsKey($id)) { $Groups.P[$id] = $id
      $Groups.M[$id] = New-Object 'System.Collections.Generic.List[int]'; $Groups.M[$id].Add($id) } }
  $rootA = Get-Root $Groups $First; $rootB = Get-Root $Groups $Second
  if ($rootA -ne $rootB) { $Groups.P[$rootB] = $rootA; $Groups.M[$rootA].AddRange($Groups.M[$rootB]); $Groups.M.Remove($rootB) } }
# The IDs of the row that an ID is one of. Takes the groups and the ID; gives back ints.
function Get-Group($Groups, [int]$Id) { if (-not $Groups.P.ContainsKey($Id)) { return @($Id) }; return @($Groups.M[(Get-Root $Groups $Id)]) }
# The ID under which a row is on the list now (any ID of its group), or $null. Takes the list's state and the ID.
function Get-OnList($State, [int]$Id) { foreach ($member in (Get-Group $State.Groups $Id)) { if ($State.Have.ContainsKey($member)) { return $member } }; return $null }
# Says whether an ID of a row has a pending mark ("p<ID>": a new row was being written and not confirmed). Takes the
# list's state and the ID.
function Test-Pending($State, [int]$Id) { foreach ($member in (Get-Group $State.Groups $Id)) { if ($State.Pend.ContainsKey($member)) { return $true } }; return $false }

<#
.SYNOPSIS
Turns a saved value (Back up's plain form) into what Add-PnPListItem takes for a field of this type.
.DESCRIPTION
Lookup IDs go to the ID the row has on that list now (Get-OnList) when the list is one of the restored lists; an ID
that is not there is dropped and counted in $script:unlinked. A person goes back by its site user ID, a link as
"url, description", managed metadata by its term ID, several choices as a list, a date as a date; a place is not written.
.PARAMETER Field
The field (InternalName, TypeAsString, LookupGuid).
.PARAMETER Value
The saved value.
.PARAMETER Info
The restored lists' states (Lists, ById).
.OUTPUTS
The value to write, or $null for no value.
#>
function ConvertTo-WriteValue($Field, $Value, $Info) {
  if ($null -eq $Value -or ([string]$Value) -eq '') { return $null }
  $type = [string]$Field.TypeAsString
  if ($type -in 'Lookup', 'LookupMulti') {
    $target = $Info.ById[[string]$Field.LookupGuid]; $out = @()
    foreach ($id in (Get-SavedIds $Value)) {
      if ($null -eq $target) { $out += $id; continue }   # a list RADE does not restore: the ID stays
      $on = Get-OnList $Info.Lists[$target] $id; if ($null -ne $on) { $out += [int]$on } else { $script:unlinked++ } }
    if (-not $out.Count) { return $null }
    if ($type -eq 'Lookup') { return $out[0] } else { return $out } }
  if ($type -in 'User', 'UserMulti') { $ids = @(Get-SavedIds $Value); if (-not $ids.Count) { return $null }
    if ($type -eq 'User') { return $ids[0] } else { return $ids } }
  if ($type -eq 'URL') { $parts = ([string]$Value) -split ';#', 2; if ($parts.Count -gt 1 -and $parts[1]) { return ($parts[0] + ', ' + $parts[1]) }; return $parts[0] }
  if ($type -in 'TaxonomyFieldType', 'TaxonomyFieldTypeMulti') { $terms = @(([string]$Value) -split ';#' | ForEach-Object { ($_ -split '\|')[-1] } | Where-Object { $_ })
    if ($type -eq 'TaxonomyFieldType') { return $terms[0] } else { return $terms } }
  if ($type -eq 'MultiChoice') { return @(([string]$Value) -split ';#' | Where-Object { $_ }) }
  if ($type -eq 'DateTime') { if ($Value -is [datetime]) { return $Value }
    return [datetime]::Parse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind) }
  if ($type -eq 'Geolocation') { return $null }   # not written in v1 (no plain form PnP takes)
  return $Value
}

# ---- The record of re-made rows: Backups\~restore-map-<site hash>.json, one file per site (IDs belong to a site), from
# any backup of this app: links "old-new" and pending marks "p<ID>" per list title. A pending mark is saved before a new
# row is written and replaced by the link after: a row with a mark is never made again (the write may have worked).
# Reads the record. Takes nothing; gives back a table list title -> entries; stops the run with "MAP failed" when the
# file is there but cannot be read (an empty file too: it is never read as "no record").
function Read-RestoreRecord {
  $record = @{}; if (-not (Test-Path -LiteralPath $MapFile -PathType Leaf)) { return $record }
  try { $json = [System.IO.File]::ReadAllText($MapFile) | ConvertFrom-Json
    if ($null -eq $json) { throw 'empty record' }
    foreach ($prop in $json.PSObject.Properties) { $record[$prop.Name] = @(@($prop.Value) | Where-Object { [string]$_ -match '^(\d+-\d+|p\d+)$' } | ForEach-Object { [string]$_ }) } }
  catch { 'MAP failed'; exit 6 }
  return $record }
# Writes the record: every link and pending mark, the lists of this run and the others as read. Writes a new file, then
# puts it in place, so a stop halfway never leaves a cut file. Throws when it cannot. Takes nothing.
function Save-RestoreRecord {
  $out = [ordered]@{}; foreach ($title in @($record.Keys)) { $out[$title] = @($record[$title]) }
  foreach ($k in $keys) { $state = $info.Lists[$k]; $out[$state.Name] = @($state.Links) }
  $tmp = $MapFile + '.new'
  [System.IO.File]::WriteAllText($tmp, (ConvertTo-Json -InputObject $out -Depth 4), (New-Object System.Text.UTF8Encoding $true))
  if (Test-Path -LiteralPath $MapFile) { [System.IO.File]::Replace($tmp, $MapFile, [NullString]::Value) } else { [System.IO.File]::Move($tmp, $MapFile) } }

<#
.SYNOPSIS
Reads one list for Restore: its saved rows, the IDs on it now, its writable fields and its same-row groups.
.PARAMETER Number
The list's number (its place in the manifest's "backup").
.PARAMETER Name
The list title.
.OUTPUTS
The list's state (Name, Saved, Have, Fields, Groups, Links, Pend, Missing, Unsure, After, Bin, Url), or $null after a
PLAN line that says why it is left out (nofile, nolist or failed and the error type).
#>
function Read-RestoreList([int]$Number, [string]$Name) {
  $file = Join-Path $Folder ((Get-FileName $Name) + '.json')
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { 'PLAN ' + $Number + ' nofile'; return $null }
  try {
    $saved = @([System.IO.File]::ReadAllText($file) | ConvertFrom-Json) | Where-Object { $null -ne $_ }
    $script:found = $null; $null = & { $script:found = Get-PnPList -Identity $Name -Includes RootFolder -ErrorAction Stop } *>&1
    if (-not $script:found) { 'PLAN ' + $Number + ' nolist'; return $null }
    $have = Read-ListIds $Name
    $script:defs = @(); $null = & { $script:defs = @(Get-PnPField -List $Name -ErrorAction Stop) } *>&1
    $fields = @(foreach ($def in $script:defs) {
      if ($def.ReadOnlyField -or $def.Hidden -or ([string]$def.TypeAsString) -in $SkipTypes -or [string]$def.InternalName -in $SkipNames) { continue }
      $guid = ''; if ([string]$def.SchemaXml -match 'List="\{?([0-9a-fA-F-]{36})\}?"') { $guid = $Matches[1].ToLowerInvariant() }
      [pscustomobject]@{ InternalName = [string]$def.InternalName; TypeAsString = [string]$def.TypeAsString; LookupGuid = $guid } })
    $state = @{ Name = $Name; Saved = $saved.Count; Have = $have; Fields = $fields; Groups = @{ P = @{}; M = @{} }; Links = @(); Pend = @{}; Bin = @{}
      Url = ([string]$script:found.RootFolder.ServerRelativeUrl).Trim('/').ToLowerInvariant(); Id = ([string]$script:found.Id).Trim('{}').ToLowerInvariant() }
    if ($record.ContainsKey($Name)) { $state.Links = @($record[$Name])
      foreach ($entry in $state.Links) { if ($entry -match '^p(\d+)$') { $state.Pend[[int]$Matches[1]] = $true }
        else { $pair = $entry -split '-'; Join-Ids $state.Groups ([int]$pair[0]) ([int]$pair[1]) } } }
    # A saved row is on the list when any ID of its group is (its own, or one an earlier Restore gave it).
    $known = @{}; foreach ($row in $saved) { foreach ($member in (Get-Group $state.Groups ([int]$row.ID))) { $known[$member] = $true } }
    $gone = @($saved | Where-Object { $null -eq (Get-OnList $state ([int]$_.ID)) })
    $state.Unsure = @($gone | Where-Object { Test-Pending $state ([int]$_.ID) }).Count   # not put back: a hand check
    $state.Missing = @($gone | Where-Object { -not (Test-Pending $state ([int]$_.ID)) })
    $state.After = @($have.Keys | Where-Object { -not $known.ContainsKey($_) }).Count
    $state.Before = $have.Count   # the rows on the list when this run read it: the base of the count check after the write
    return $state
  } catch { 'PLAN ' + $Number + ' failed ' + $_.Exception.GetType().Name; return $null }
}

# Finds, for each missing row, an ID of its group in the site's Recycle Bin (its own first), each bin item once (R1).
# Fills each list's Bin (saved ID -> @{ Item; Id }). Takes nothing; a bin that cannot be read gives a BIN line.
function Find-BinRows {
  try { $script:bin = @(); $null = & { $script:bin = @(Get-PnPRecycleBinItem -RowLimit $BinRowLimit -ErrorAction Stop) } *>&1 }
  catch { 'BIN failed ' + $_.Exception.GetType().Name; return }
  $inBin = @{}
  foreach ($item in $script:bin) { if ([string]$item.ItemType -ne 'ListItem' -or [string]$item.LeafName -notmatch '^(\d+)_\.000$') { continue }
    $inBin[([string]$item.DirName).Trim('/').ToLowerInvariant() + '|' + $Matches[1]] = $item }
  foreach ($k in $keys) { $state = $info.Lists[$k]; $used = @{}
    foreach ($row in $state.Missing) { foreach ($member in (Get-Group $state.Groups ([int]$row.ID))) { $key = $state.Url + '|' + $member
        if ($inBin.ContainsKey($key) -and -not $used.ContainsKey($member)) { $state.Bin[[int]$row.ID] = @{ Item = $inBin[$key]; Id = $member }; $used[$member] = $true; break } } } } }

# Prints the PLAN line of each list, with a short hash of its missing IDs and bin choices (the write checks the same
# rows, not only the same count; no ID is printed). Takes nothing.
function Write-PlanLines {
  foreach ($k in $keys) { $state = $info.Lists[$k]
    $text = (@($state.Missing | ForEach-Object { [int]$_.ID } | Sort-Object) -join ',') + '/' + (@($state.Bin.Keys | Sort-Object | ForEach-Object { [string]$_ + ':' + $state.Bin[$_].Id }) -join ',')
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $state.Sig = -join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text))[0..($SigBytes - 1)] | ForEach-Object { $_.ToString('x2') }); $sha.Dispose()
    'PLAN ' + $k + ' saved=' + $state.Saved + ' now=' + $state.Have.Count + ' missing=' + $state.Missing.Count + ' bin=' + $state.Bin.Count +
      ' new=' + ($state.Missing.Count - $state.Bin.Count) + ' after=' + $state.After + ' unsure=' + $state.Unsure + ' sig=' + $state.Sig } }

# Says whether the site is as the dry run saw it: the same hash for each list, and no list more or less. Takes nothing.
function Test-SameAsPlan {
  $want = @{}; foreach ($entry in ($Expect -split ',')) { if ($entry -match '^(\d+):([0-9a-f]+)$') { $want[[int]$Matches[1]] = $Matches[2] } }
  if ($want.Count -ne $keys.Count) { return $false }
  foreach ($k in $keys) { if ($want[$k] -ne $info.Lists[$k].Sig) { return $false } }
  return $true }

# R2: reads the pause-switch row, then sets it to its on value. Takes nothing; gives back the switch (List, Title,
# Field, On, Row, Old) and prints nothing, or $null with no switch; stops the run (no row written) when the row is not there, is on already or cannot be set.
function Set-PauseOn {
  if (-not $Pause) { return $null }
  $part = $Pause -split '\|'; $switch = @{ List = $part[0]; Title = $part[1]; Field = $part[2]; On = $part[3] }
  try { $caml = '<View><Query><Where><Eq><FieldRef Name="Title"/><Value Type="Text">' + $switch.Title + '</Value></Eq></Where></Query></View>'
    $script:found = $null; $null = & { $script:found = @(Get-PnPListItem -List $switch.List -Query $caml -ErrorAction Stop) } *>&1; $row = @($script:found)[0]
    if (-not $row) { 'RESULT no-pause-row'; exit 5 }
    $old = [string]$row[$switch.Field]
    if ($old -eq $switch.On) { 'RESULT paused-already'; exit 5 }
    $null = & { Set-PnPListItem -List $switch.List -Identity $row.Id -Values @{ $switch.Field = $switch.On } -ErrorAction Stop } *>&1 }
  catch { 'RESULT pause-failed ' + $_.Exception.GetType().Name; exit 5 }
  return ($switch + @{ Row = $row; Old = $old }) }

# R1: puts back each chosen Recycle Bin item; after an error the list is read again (a restore that reported an error
# but worked is not made a second time). A row that did not come back is made new later (Add-MissingRows): the BINERR
# line gives its list and the first error type, so the result card says so (E2, R42; the Administrator, 2026-11-21).
# Takes nothing; sets $script:stopMake when a list cannot be read again.
function Restore-BinRows {
  foreach ($k in $keys) { $state = $info.Lists[$k]; $state.FromBin = 0; $state.BinFailed = 0; $binErr = ''; $failed = @()
    foreach ($id in @($state.Bin.Keys)) { $choice = $state.Bin[$id]
      try { $null = & { Restore-PnPRecycleBinItem -Identity $choice.Item -Force -ErrorAction Stop } *>&1; $state.Have[[int]$choice.Id] = $true; $state.FromBin++ }
      catch { $state.Bin.Remove($id); $failed += @{ Id = $choice.Id; Err = $_.Exception.GetType().Name } } }
    if ($failed.Count) { try { foreach ($id in @((Read-ListIds $state.Name).Keys)) { $state.Have[$id] = $true } } catch { $script:stopMake = $true } }
    # A restore that reported an error but put the row back (it is on the list now, with its own ID) counts as back.
    # BINERR gives the error type of the first row that really did not come back.
    foreach ($miss in $failed) { if ($state.Have.ContainsKey([int]$miss.Id)) { $state.FromBin++ } else { $state.BinFailed++; if (-not $binErr) { $binErr = [string]$miss.Err } } }
    if ($state.BinFailed) { 'BINERR ' + $k + ' ' + $binErr } } }   # an error type only: no site, name, ID or value

# R5: the lists in dependency order: a list whose lookup reads another restored list comes after it; a loop keeps the
# manifest order for the lists left. Takes nothing; gives back the list numbers.
function Get-ListOrder {
  $order = @(); $left = New-Object 'System.Collections.Generic.List[int]'; foreach ($k in $keys) { $left.Add($k) }
  while ($left.Count) { $next = $null
    foreach ($k in $left) { $deps = @($info.Lists[$k].Fields | Where-Object { $_.LookupGuid } | ForEach-Object { $info.ById[$_.LookupGuid] } |
        Where-Object { $null -ne $_ -and $_ -ne $k -and $left.Contains($_) })
      if (-not $deps.Count) { $next = $k; break } }
    if ($null -eq $next) { $next = $left[0] }
    $order += $next; $null = $left.Remove($next) }
  return $order }

<#
.SYNOPSIS
Makes the missing rows of one list that did not come back from the Recycle Bin, each with a pending mark saved first.
.DESCRIPTION
A write that works but reports an error keeps its mark, so no later run makes it again (a hand check). A record that
cannot be saved stops new rows ($script:mapStop). A row whose group is on the list already is not made.
.PARAMETER State
The list's state.
.OUTPUTS
None; sets Made, Failed, Skipped and Unlinked on the state.
#>
function Add-MissingRows($State) {
  $State.Made = 0; $State.Failed = 0; $State.Skipped = 0; $script:unlinked = 0
  foreach ($row in @($State.Missing | Sort-Object { [int]$_.ID })) {
    if ($null -ne (Get-OnList $State ([int]$row.ID))) { continue }   # back from the Recycle Bin, or another saved ID of the same row was made
    $values = @{}
    $unlinkedBefore = $script:unlinked   # a row that is not written does not add to the empty-lookup count
    try { foreach ($field in $State.Fields) { $prop = $row.PSObject.Properties[$field.InternalName]; if (-not $prop) { continue }
        $value = ConvertTo-WriteValue $field $prop.Value $info; if ($null -ne $value) { $values[$field.InternalName] = $value } } }
    catch { $State.Skipped++; $script:unlinked = $unlinkedBefore; continue }   # a saved value that cannot be read (a bad date): not written, no mark; the next rows go on
    $mark = 'p' + [int]$row.ID
    try { $State.Links += $mark; Save-RestoreRecord } catch { $script:mapStop = $true; break }
    try { $script:made = $null; $null = & { $script:made = Add-PnPListItem -List $State.Name -Values $values -ErrorAction Stop } *>&1; $newId = [int]$script:made.Id
      if ($newId -le 0) { throw 'no ID' } }   # no ID back: the write is not confirmed, so the mark stays
    catch { $State.Failed++; continue }   # the mark stays: the row may be on the list; the next runs leave it for a hand check
    $State.Have[$newId] = $true; Join-Ids $State.Groups ([int]$row.ID) $newId; $State.Made++
    $State.Links = @(@($State.Links | Where-Object { $_ -ne $mark }) + @([string]$row.ID + '-' + $newId))
    try { Save-RestoreRecord } catch { $script:mapStop = $true; break } }   # the mark is on file: the row is not made again
  $State.Unlinked = $script:unlinked }

# ---- The run.
try {
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { 'RESULT no-pnp'; exit 3 }
  $pin = @($mod | Where-Object { [string]$_.Version -eq '1.12.0' }); if ($pin.Count) { $mod = $pin }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Start-SignInSize   # E3: the CAC sign-in window opens at about 480 x 360, centered (the block above)
  $null = & { Connect-PnPOnline -Url $Site -UseWebLogin -ErrorAction Stop } *>&1
} catch { 'RESULT not-connected ' + $_.Exception.GetType().Name; exit 2 }
$record = Read-RestoreRecord
$info = @{ Lists = @{}; ById = @{} }; $names = @($Lists -split '\|')
for ($i = 1; $i -le $names.Count; $i++) { $state = Read-RestoreList $i $names[$i - 1]
  if ($state -is [hashtable]) { $info.Lists[$i] = $state; $info.ById[$state.Id] = $i } elseif ($state) { $state } }   # a PLAN line comes back as text
$keys = @($info.Lists.Keys | Sort-Object)
Find-BinRows
Write-PlanLines
if ($Mode -ne 'write') { 'RESULT plan'; exit 0 }
if (-not (Test-SameAsPlan)) { 'RESULT changed'; exit 4 }
$pauseSwitch = Set-PauseOn; if ($pauseSwitch) { 'PAUSE on' }   # the function gives back only the switch: its line is printed here
$script:stopMake = $false; $script:mapStop = $false
try {
  Restore-BinRows
  foreach ($k in (Get-ListOrder)) { $state = $info.Lists[$k]; $state.Made = 0; $state.Failed = 0; $state.Skipped = 0; $state.Unlinked = 0
    if (-not ($script:stopMake -or $script:mapStop)) { Add-MissingRows $state } }   # a list not read again, or a record not saved: no new row
  # R7 (counts only): the rows on each list after the write.
  foreach ($k in $keys) { $state = $info.Lists[$k]; $count = -1; try { $count = (Read-ListIds $state.Name).Count } catch { $count = -1 }   # -1: not read
    'DONE ' + $k + ' before=' + $state.Before + ' bin=' + $state.FromBin + ' made=' + $state.Made +
      ' failed=' + $state.Failed + ' skipped=' + $state.Skipped + ' binfailed=' + $state.BinFailed + ' unlinked=' + $state.Unlinked + ' now=' + $count }
} finally {
  if ($pauseSwitch) { $back = @{ $pauseSwitch.Field = $pauseSwitch.Old }
    try { $null = & { Set-PnPListItem -List $pauseSwitch.List -Identity $pauseSwitch.Row.Id -Values $back -ErrorAction Stop } *>&1; 'RESUME ok' }
    catch { 'RESUME failed' } } }
if ($script:mapStop) { 'RESULT map-write-failed'; exit 8 }
if ($script:stopMake) { 'RESULT reread-failed'; exit 7 }
'RESULT done'; exit 0
'@
$restoreScript = Add-SignInSize $restoreScript   # E3: the sign-in window size block (16-site-scripts.ps1)
