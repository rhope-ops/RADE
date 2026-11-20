# RADE engine part 13, the Maintenance tools (the Administrator, 2026-11-20; docs/engine.md "Maintenance run types").
# Diagnose: read-only; the install record, the app's local files and the app's RADE checks again; one report file.
# Back up: reads only the lists the app's manifest names ("backup") and saves each as JSON plus a CSV copy.
# Restore is not built yet (engine-v31 at the earliest; test sites only).
# Uses parts 01 to 08 (Get-BasePath, Read-Installed, Get-InstalledKey, Get-StartPath, Invoke-Check, Invoke-ChildScript).
# Network: Diagnose runs the app's own RADE checks (their fixed addresses only); Back up signs in to the saved site and
# reads only the lists the manifest names (AGENTS.md "No reconnaissance"). Neither one writes to the site.
# Writes: Diagnose: Rounds\<round>\diagnose-<time>.txt; Back up: Backups\<time>\<list>.json and .csv (the app folder).
# Credentials: the interactive CAC sign-in of PnP (-UseWebLogin), for Back up only.
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
Runs Diagnose and saves its report in the round's results folder.
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
  try { $dir = Join-Path (Join-Path $Base 'Rounds') $round
    if (-not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
    $p = Join-Path $dir ('diagnose-' + (Get-ToolStamp) + '.txt'); Write-FileWhole $p (($lines -join "`r`n") + "`r`n") } catch { $p = '' }
  return @{ Lines = $lines; Path = $p; Findings = $n }
}

# ---- Back up. The child script reads each named list and writes <n>.json and <n>.csv into the folder it is given.
# It prints only a list number, a row count or an error type: never the site, a name, a value or an error message.
$backupScript = @'
param([string]$Site, [string]$Folder, [string]$Lists)
# RADE Back up (reads the site, writes this computer only): signs in with the CAC and saves each named list.
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
        foreach ($k in @($it.FieldValues.Keys)) { $v = $it.FieldValues[$k]
          if ($null -ne $v -and $v.PSObject.Properties['LookupId']) { $v = [string]$v.LookupId + ';#' + [string]$v.LookupValue }
          elseif ($v -is [System.Array]) {
            $v = (@($v | ForEach-Object { if ($null -ne $_ -and $_.PSObject.Properties['LookupId']) { [string]$_.LookupId + ';#' + [string]$_.LookupValue } else { [string]$_ } }) -join ';#') }
          elseif ($v -is [datetime]) { $v = $v.ToUniversalTime().ToString('o') }
          elseif ($null -ne $v -and -not ($v -is [string] -or $v -is [ValueType])) { $v = [string]$v }
          $o[$k] = $v }
        [pscustomobject]$o })
      $j = Join-Path $Folder ([string]$i + '.json'); $c = Join-Path $Folder ([string]$i + '.csv')
      [System.IO.File]::WriteAllText($j, (ConvertTo-Json -InputObject @($rows) -Depth 4), (New-Object System.Text.UTF8Encoding $true))
      if ($rows.Count) { $rows | Export-Csv -LiteralPath $c -NoTypeInformation -Encoding UTF8 } else { [System.IO.File]::WriteAllText($c, '') }
      'LIST ' + $i + ' ' + $rows.Count
    } catch { 'LIST ' + $i + ' failed ' + $_.Exception.GetType().Name }
  }
  'RESULT done'; exit 0
} catch { 'RESULT not-connected ' + $_.Exception.GetType().Name; exit 2 }
'@

# Gives the folder of a backup, Backups\<time> in the app folder. Takes the RADE app folder and the time stamp.
function Get-BackupDir([string]$Base, [string]$Stamp) { return (Join-Path (Join-Path $Base 'Backups') $Stamp) }

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
  $dir = Get-BackupDir $Base (Get-ToolStamp)
  try { $null = New-Item -ItemType Directory -Path $dir -Force } catch { return @{ State = 'failed'; Path = ''; Lines = @('Back up could not make its folder on this computer.') } }
  $r = Invoke-ChildScript $backupScript ('-Site "' + $site + '" -Folder "' + $dir + '" -Lists "' + ($lists -join '|') + '"') 1800 $Tick
  $got = @{}; $res = ''
  foreach ($l in $r.Lines) { if ($l -match '^LIST (\d+) (.+)$') { $got[[int]$Matches[1]] = $Matches[2] } elseif ($l -match '^RESULT (\S+)') { $res = $Matches[1] } }
  if ($res -ne 'done') { $why = $(switch ($res) { 'no-pnp' { 'the SharePoint tool is not installed' } 'not-connected' { 'the sign-in did not finish' } default { 'it stopped: ' + $r.Why } })
    return @{ State = 'failed'; Path = $dir; Lines = @(('Back up saved nothing: ' + $why + '.'), 'Nothing on the site changed. Select "Back up" again.') } }
  $lines = @(); $bad = 0
  for ($i = 1; $i -le $lists.Count; $i++) {
    $n = [string]$lists[$i - 1]; $v = [string]$got[$i]; $f = Join-Path $dir ([string]$i + '.json')
    if ($v -match '^\d+$' -and (Test-Path -LiteralPath $f -PathType Leaf)) {
      $safe = ($n -replace '[^A-Za-z0-9 _-]', '_'); Move-Item -LiteralPath $f -Destination (Join-Path $dir ($safe + '.json')) -Force
      Move-Item -LiteralPath (Join-Path $dir ([string]$i + '.csv')) -Destination (Join-Path $dir ($safe + '.csv')) -Force
      $lines += ('PASS: "' + $n + '": ' + $v + ' rows saved') }
    else { $bad++; $ty = $(if ($v -match '^failed (\S+)') { ' (' + $Matches[1] + ')' } else { '' })
      $lines += ('FINDING: "' + $n + '" was not saved' + $ty + '. What to do: check that the list exists and that you can read it') }
  }
  $head = $(if ($bad) { [string]$bad + ' of ' + $lists.Count + ' lists were not saved.' } else { 'All ' + $lists.Count + ' lists were saved.' })
  return @{ State = $(if ($bad) { 'failed' } else { 'done' }); Path = $dir; Lines = @(@($head, 'Nothing on the site changed.') + $lines) }
}
