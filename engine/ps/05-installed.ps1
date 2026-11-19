# RADE engine part 05, the install record: one record file for each app in RADE\Config\installed, the newer-
# version look-up, the runner copy and desktop shortcut, and the lines that tell a user what was made. Used by 04 and 06.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# ---- Installed versions (the Administrator, 14 Nov 26, deploy v1): RADE\Config\installed keeps, one file per app, the
# version a deploy last installed and the last deploy run. It holds no user name, path, site or DODID. A deploy run sends
# nothing: no e-mail draft, no saved address; its report stays in Rounds\<round> on this computer.
function Get-InstalledKey($A) {
  # An app that keeps an install record on the site (manifest "marker") has one record for each site: the key ends in
  # "@" and a short hash of the site address (never the address). So versions, step states and the made list of one
  # site never count on another (reviews, 14 Nov 26).
  $k = $appFolder + '/' + [string]$A.Name
  if ($A.Marker) { $h = Get-SiteMark (Get-SiteUrl (Get-BasePath)); if ($h) { $k += '@' + $h } }
  return $k
}
# Turns a saved run of a record (version, build, round, time, state) into a plain ordered table of text, fixing a date
# that PowerShell 7 reads as a date. Takes the run; gives back the table, or $null for none.
function ConvertTo-InstalledRun($V) {
  if ($null -eq $V) { return $null }
  $at = $V.at; if ($at -is [datetime]) { $at = $at.ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture) }   # PowerShell 7 reads it as a date
  $o = [ordered]@{ version = [string]$V.version; build = [string]$V.build; round = [string]$V.round; at = [string]$at }
  if ($null -ne $V.state) { $o.state = [string]$V.state }
  return $o
}
# Shared files (docs/engine.md "Shared files"; the Administrator, 2026-11-15). Many apps, each with its own engine version,
# use RADE\Config. So: one record file for each app (RADE\Config\installed\<12 hex of the record key>.json, schema
# rade-installed/2), and an engine reads and writes only its own app's file (S1). A record with a higher schema number is
# never written, and that app is not deployed (S2). Every write goes to a temporary file first (S4). Only a file with the
# exact name is read, so a conflict copy that OneDrive makes is ignored (S5).
$installedSchema = 2
function Write-FileWhole([string]$Path, [string]$Text) {
  # The file is whole or unchanged: the text goes to a temporary file in the same folder, which then takes the place of
  # the final file in one step. A stop in the middle leaves the old file as it was.
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
  $tmp = $Path + '.tmp' + $PID
  try {
    [System.IO.File]::WriteAllText($tmp, $Text, (New-Object System.Text.UTF8Encoding $false))
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
      if ((Get-Item -LiteralPath $Path -Force).IsReadOnly) { throw 'the file is read-only' }
      [System.IO.File]::Replace($tmp, $Path, [NullString]::Value)   # $null would go in as an empty string, which Replace refuses
    } else { [System.IO.File]::Move($tmp, $Path) }
  } finally { if (Test-Path -LiteralPath $tmp -PathType Leaf) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } }
}
# Gives the path of the record file of one app: RADE\Config\installed\<12 hex of the key>.json. Takes the record key;
# gives back the path.
function Get-InstalledFile([string]$Key) { return (Join-Path (Get-RadeConfigFile 'installed') ((Get-ShortHash $Key) + '.json')) }
function Read-InstalledRaw([string]$Key) {
  # State: none (no file), ok, damaged (not JSON, or no record of this schema), newer (a higher schema number: S2),
  # foreign (a whole record with another app's key: two keys gave one file name) or unreadable (the file is there but
  # cannot be read now, for example while another program holds it). Only none, ok and damaged may be written (S1).
  $p = Get-InstalledFile $Key
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return @{ State = 'none'; Path = $p } }
  $text = $null
  try { $text = [System.IO.File]::ReadAllText($p) } catch { return @{ State = 'unreadable'; Path = $p } }
  try {
    $j = $text | ConvertFrom-Json
    if ([string]$j.schema -notmatch '^rade-installed/(\d{1,6})$') { return @{ State = 'damaged'; Path = $p } }
    if ([int]$Matches[1] -gt $installedSchema) { return @{ State = 'newer'; Path = $p } }
    if ([int]$Matches[1] -lt $installedSchema) { return @{ State = 'damaged'; Path = $p } }
    if ([string]$j.key -cne $Key) { return @{ State = $(if ([string]$j.key) { 'foreign' } else { 'damaged' }); Path = $p } }
    return @{ State = 'ok'; Path = $p; Json = $j }
  } catch { return @{ State = 'damaged'; Path = $p } }
}
# Says whether the app's record was written by a newer RADE (a higher schema number). Takes the app; gives back $true or
# $false.
function Test-InstalledNewer($A) { return ((Read-InstalledRaw (Get-InstalledKey $A)).State -eq 'newer') }
$newerRadeText = 'a newer RADE installed this application: get the newest script from the RADE page'
function Get-InstalledBlock($A) {
  # '' or why this app's record must not be written, so the app is not deployed (S1, S2).
  switch ((Read-InstalledRaw (Get-InstalledKey $A)).State) {
    'newer' { return $newerRadeText }
    'foreign' { return 'the install record file of this application holds the record of another application (RADE\Config\installed). RADE did not change it: ask for help before you install' }
    'unreadable' { return 'the install record of this application could not be read (another program may be using the file). Wait a minute, then run again' }
  }
  return ''
}
function Read-Installed([string]$Key) {
  # This app's record, or $null (no file, a damaged file, or a record from a newer RADE).
  $r = Read-InstalledRaw $Key
  if ($r.State -ne 'ok') { return $null }
  try {
    $st = [ordered]@{}
    if ($r.Json.steps) { foreach ($s in @($r.Json.steps.PSObject.Properties)) {
      $at = $s.Value.at; if ($at -is [datetime]) { $at = $at.ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture) }
      $made = @(); foreach ($m in @($s.Value.made)) { if ($null -ne $m) { $made += [ordered]@{ kind = [string]$m.kind; name = [string]$m.name } } }
      $st[$s.Name] = [ordered]@{ state = [string]$s.Value.state; version = [string]$s.Value.version; at = [string]$at; made = $made }
    } }
    return [ordered]@{ installed = (ConvertTo-InstalledRun $r.Json.installed); lastRun = (ConvertTo-InstalledRun $r.Json.lastRun); steps = $st }
  } catch { return $null }   # a damaged file reads as nothing installed
}
function Get-InstalledText($A) {
  # One short text for the Choose card and the log; '' for an app that is not a deploy.
  if ([string]$A.Mode -ne 'deploy') { return '' }
  if (Test-InstalledNewer $A) { return ('version ' + $A.Version + ' (' + $newerRadeText + ')') }
  $e = (Read-Installed (Get-InstalledKey $A))
  if ($e -and $e.installed) {
    if ($e.installed.version -eq [string]$A.Version) { return ('version ' + $A.Version + ' is installed') }
    return ('version ' + $A.Version + ' (installed now: ' + $e.installed.version + ')')
  }
  return ('version ' + $A.Version + ' (not installed yet)')
}
function Save-Installed([string]$State, [bool]$Whole, $StepRecs) {
  # Every deploy run is the app's lastRun. "installed" changes only when every step of the app ran and PASSED (none off,
  # none skipped). Clean-up is not a step: it only recycles old files, so it may be off.
  # $StepRecs: name -> @{ state; made } for the steps this run reached; a step it did not reach keeps its older record.
  # A step's "made" list adds up over runs (the undo list): an item stays until an undo removes it.
  # Returns '' or the reason the record could not be saved (the caller says it: the record is the upgrade path).
  try {
    $key = Get-InstalledKey $script:app
    $raw = Read-InstalledRaw $key
    $blk = Get-InstalledBlock $script:app; if ($blk) { return $blk }   # S1, S2: never write a record of a newer RADE or of another app, or one that cannot be read
    if ($raw.State -eq 'damaged') {
      # Keep what was there before it is replaced; an older .damaged copy is kept too.
      $keep = $raw.Path + '.damaged'; if (Test-Path -LiteralPath $keep) { $keep += '-' + (Get-Date).ToString('yyyyMMdd-HHmmss', [System.Globalization.CultureInfo]::InvariantCulture) }
      Copy-Item -LiteralPath $raw.Path -Destination $keep -Force
    }
    $old = Read-Installed $key
    $run = [ordered]@{ version = [string]$script:app.Version; build = [string]$buildId; round = [string]$round; at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture) }
    $inst = $null; if ($old) { $inst = $old.installed }
    if ($State -eq 'PASSED' -and $Whole) { $inst = [ordered]@{ version = $run.version; build = $run.build; round = $run.round; at = $run.at } }
    $run.state = $State
    $st = [ordered]@{}; if ($old -and $old.steps) { $st = $old.steps }
    if ($StepRecs) { foreach ($n in @($StepRecs.Keys)) {
      $made = @(); $seen = @{}
      $om = @(); if ($st.Contains($n)) { $om = @($st[$n].made) }
      foreach ($m in ($om + @($StepRecs[$n].made))) { if ($null -eq $m) { continue }; $id = [string]$m.kind + '|' + [string]$m.name; if (-not $seen[$id]) { $seen[$id] = $true; $made += [ordered]@{ kind = [string]$m.kind; name = [string]$m.name } } }
      $st[$n] = [ordered]@{ state = [string]$StepRecs[$n].state; version = $run.version; at = $run.at; made = $made }
    } }
    $doc = [ordered]@{
      schema = 'rade-installed/' + $installedSchema
      about = 'What RADE installed for one app (key: folder/name; a key that ends in @ and letters is one site, as a short hash). "installed" is the last deploy in which every step ran and PASSED; "lastRun" is the last deploy run and its state; "steps" holds each step''s last state and what it made. No user, path or site address is kept here. Only the RADE that installs this app writes this file.'
      key = $key
      installed = $inst
      lastRun = $run
      steps = $st
    }
    Write-FileWhole $raw.Path ($doc | ConvertTo-Json -Depth 9)
    return ''
  } catch { return (ConvertTo-Masked $_.Exception.Message) }
}
function Test-SharedFile([string]$Dir) {
  # Test rounds only (it goes away with the test branch): runs the record functions on a scratch folder, so a round on a
  # work computer proves them on Windows PowerShell 5.1. Returns one line for each test: "PASS ..." or "FAIL ...".
  $out = @(); $keepApp = $script:app
  try {
    $script:configOver = $Dir
    $script:app = @{ Name = 'Self test'; Version = '0.0.1'; Mode = 'test'; Marker = $null }
    $key = Get-InstalledKey $script:app; $p = Get-InstalledFile $key
    $rec = @{ 'step one' = @{ state = 'PASSED'; made = @(@{ kind = 'file'; name = 'a' }) } }
    $w = Save-Installed 'PASSED' $true $rec; $e = Read-Installed $key
    $out += $(if (-not $w -and $e -and $e.installed -and $e.installed.version -eq '0.0.1' -and @($e.steps['step one'].made).Count -eq 1 -and [string]$e.steps['step one'].made[0].name -eq 'a') { 'PASS' } else { 'FAIL' }) + ' shared files: a record is written and read back'
    $w = Save-Installed 'NEEDS REVIEW' $false @{ 'step two' = @{ state = 'NEEDS REVIEW'; made = @() } }; $e = Read-Installed $key
    $left = @(Get-ChildItem -LiteralPath (Split-Path -Parent $p) -Force | Where-Object { $_.Name -ne (Split-Path -Leaf $p) })
    $out += $(if (-not $w -and $e -and $e.lastRun.state -eq 'NEEDS REVIEW' -and $e.installed.version -eq '0.0.1' -and $e.steps.Count -eq 2 -and -not $left.Count) { 'PASS' } else { 'FAIL' }) + ' shared files: a second write replaces the file and leaves no temporary file'
    $newer = '{ "schema": "rade-installed/' + ($installedSchema + 1) + '", "key": "' + $key + '", "later": true }'
    [System.IO.File]::WriteAllText($p, $newer)
    $w = Save-Installed 'PASSED' $true $rec
    $out += $(if ($w -eq $newerRadeText -and (Test-InstalledNewer $script:app) -and $null -eq (Read-Installed $key) -and [System.IO.File]::ReadAllText($p) -eq $newer) { 'PASS' } else { 'FAIL' }) + ' shared files: a record of a newer RADE is not read and not written'
    [System.IO.File]::WriteAllText($p, '{ "schema": "rade-installed/2", "key": "')
    $e0 = Read-Installed $key; $w = Save-Installed 'PASSED' $true $rec; $e = Read-Installed $key
    $out += $(if ($null -eq $e0 -and -not $w -and $e -and $e.installed -and (Test-Path -LiteralPath ($p + '.damaged') -PathType Leaf)) { 'PASS' } else { 'FAIL' }) + ' shared files: a cut record is kept as .damaged and replaced'
  } catch { $out += 'FAIL shared files: the self-test stopped (' + (ConvertTo-Masked $_.Exception.Message) + ')' }
  finally { $script:configOver = $null; $script:app = $keepApp; try { Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue } catch { $null = $_ } }
  return $out
}
function Get-StepPrior {
  # Deploy only: step name -> state, for the steps the record holds at the version this bundle installs.
  $res = @{}
  if (-not (Test-Deploy)) { return $res }
  $e = (Read-Installed (Get-InstalledKey $script:app))
  if ($e -and $e.steps) { foreach ($n in @($e.steps.Keys)) { if ([string]$e.steps[$n].version -eq [string]$script:app.Version) { $res[[string]$n] = [string]$e.steps[$n].state } } }
  return $res
}
function Get-StepDefault([int]$K) {
  # Safe second run (deploy v1 item 3): a step that PASSED at this version starts off, so a second run does only what is
  # left. When every step of the app has PASSED, the run is a repair: every step starts on again.
  # Optional = the manifest says "default": false. Every other step is needed: in a deploy it is on until it has PASSED
  # at this version, whatever a files-changed default says (that default is for test rounds).
  if (-not (Test-Deploy) -or [bool]$steps[$K].Optional) { return [bool]$steps[$K].Default }
  $prior = Get-StepPrior
  # Only needed steps count: an optional step that never ran must not block the repair (review).
  $all = $true; foreach ($j in $script:appSteps) { if (-not [bool]$steps[$j].Optional -and $prior[[string]$steps[$j].Name] -ne 'PASSED') { $all = $false } }
  if ($all) { return $true }
  return ($prior[[string]$steps[$K].Name] -ne 'PASSED')
}
# The RADE page (R28: the newer-version notice points here, not to the app page; the Administrator, 2026-11-17).
$radeUrl = 'https://rhope-ops.github.io/RADE'
function Get-NewerVersion {
  # Reads rade-release.json in the app repository (data, not code): { "apps": { "<app name>": "<version>" } }.
  # Returns that version when it is newer than the one this bundle installs, else ''. Short timeout; any failure is silent.
  # R28: in a test round too (the Administrator, 2026-11-17): the notice shows for every application that names a version.
  if (-not [string]$script:app.Version) { return '' }   # no version: nothing to compare, no request
  try {
    $rq = Get-WebRequest $releaseUrl 4000   # engine/ps/07-checks.ps1: no Windows sign-in for the address, only for the proxy
    $rs = $rq.GetResponse()
    try { $text = (New-Object System.IO.StreamReader($rs.GetResponseStream())).ReadToEnd() } finally { $rs.Close() }
    $v = [string](($text | ConvertFrom-Json).apps.PSObject.Properties | Where-Object { $_.Name -eq [string]$script:app.Name } | ForEach-Object { $_.Value } | Select-Object -First 1)
    if ($v -match '^\d+\.\d+(\.\d+)?$' -and ([version]$v) -gt ([version][string]$script:app.Version)) { return $v }
  } catch { $null = $_ }
  return ''
}
# Gives the line that tells the user a newer version of the app is on the RADE page, or an empty text when there is
# none. Takes nothing.
function Get-NewerVersionText {
  $v = Get-NewerVersion
  if ($v) { return ('A newer version, ' + $v + ', of ' + $script:app.Name + ' is on the RADE page (' + $radeUrl + '). Use that one instead.') }
  return ''
}
function Get-StartPath {
  # R28: the app's start script (manifest app.start), inside its local install folder; '' when the app has none, the path is
  # not inside the folder, or the file is not there. Nothing is downloaded.
  $st = [string]$script:app.Start
  if (-not $st) { return '' }
  try { $base = [System.IO.Path]::GetFullPath((Get-BasePath)).TrimEnd('\', '/')
    $full = [System.IO.Path]::GetFullPath((Join-Path $base ($st -replace '/', [string][System.IO.Path]::DirectorySeparatorChar)))
    if (-not $full.StartsWith($base + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { return '' }
    if (Test-Path -LiteralPath $full -PathType Leaf) { return $full }
  } catch { $null = $_ }
  return ''
}
# Gives the full path of Windows PowerShell (powershell.exe), or just its name when the system folder is not known.
# Takes nothing.
function Get-PowerShellExe {
  if ($env:SystemRoot) { $x = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'; if (Test-Path -LiteralPath $x -PathType Leaf) { return $x } }
  return 'powershell.exe'
}
# The installed runner (R28, the Administrator, 2026-11-17): RADE had none, so the desktop shortcut had nothing to open. The smallest
# one: after a deploy has passed, a copy of the pasted text is saved as OneDrive\RADE\rade-runner.ps1 (the newest deploy's paste
# replaces it; the file is a whole bundle, so it carries its own engine and its own applications). The shortcut runs it.
$script:selfText = ''
try { if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath -PathType Leaf)) { $script:selfText = [System.IO.File]::ReadAllText($PSCommandPath) } } catch { $null = $_ }
if (-not $script:selfText) { try { if ($psISE -and $psISE.CurrentFile) { $script:selfText = [string]$psISE.CurrentFile.Editor.Text } } catch { $null = $_ } }
if (-not $script:selfText) { try { $script:selfText = [string]$MyInvocation.MyCommand.ScriptBlock } catch { $null = $_ } }
<#
.SYNOPSIS
The bundle's own hash check: the line to show, the short form and whether the text matches its first line.
.DESCRIPTION
Script check (docs/specs/bundle-hash.md; the Administrator, 2026-11-18): the first line of a bundle holds the SHA-256 of
all the text after it (line ends as LF; engine/rade_hash.py HASH_LINE). RADE hashes its own text ($script:selfText) the
same way and shows the short form (first 12 and last 4 hex), so a person can compare it with the RADE page. It catches a
change on the way (a half copy, an old page); a changed script can print any value, so it is no security control. This
release shows the answer and stops nothing: a work-computer round must first prove that a paste keeps the text (Q5).
.OUTPUTS
A table: Line (the text to show), Short (the short form, or '' when RADE cannot read its own text) and Ok ($true only
when the hash of the text is the value on its first line).
#>
function Get-ScriptCheck {
  $res = @{ Line = 'Script check: not available (RADE could not read its own text)'; Short = ''; Ok = $false }
  try {
    $t = ([string]$script:selfText) -replace "`r`n", "`n"
    $m = [regex]::Match($t, '^\s*# @@BUNDLE-HASH ([0-9a-f]{64}) @@\n')
    if (-not $m.Success) { return $res }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $hex = -join @($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($t.Substring($m.Length))) | ForEach-Object { $_.ToString('x2') }) } finally { $sha.Dispose() }
    $own = [string]$m.Groups[1].Value
    $res.Short = $hex.Substring(0, 12) + '...' + $hex.Substring(60)
    $res.Ok = ($hex -eq $own)
    if ($res.Ok) { $res.Line = 'Script check: ' + $res.Short + ' (checked)' }
    else { $res.Line = 'Script check: ' + $res.Short + ' DOES NOT MATCH the line in the script (' + $own.Substring(0, 12) + '...' + $own.Substring(60) + ')' }
  } catch { $res.Line = 'Script check: not available (' + $_.Exception.GetType().Name + ')' }
  return $res
}
$script:scriptCheck = Get-ScriptCheck
function Save-RunnerCopy {
  # Returns $true when the runner is saved. Only the text of this bundle is saved (its build id must be in it). Never an error.
  # Only a newer RADE replaces a saved copy (the Administrator, 2026-11-17): a copy with a higher or equal engine release stays.
  try { if (-not $script:selfText -or -not $script:selfText.Contains("`$buildId = '" + $buildId + "'")) { return $false }
    $rp = Join-Path (Get-RadePath) 'rade-runner.ps1'
    if (Test-Path -LiteralPath $rp -PathType Leaf) {
      $m = [regex]::Match([IO.File]::ReadAllText($rp), '(?m)^\$engineRelease = (\d+)')
      if ($m.Success -and [int]$m.Groups[1].Value -ge [int]$engineRelease) { return $false } }
    Write-FileWhole $rp $script:selfText; return $true } catch { return $false }
}
function Get-DesktopDir {
  # The user's own Desktop folder (it follows OneDrive), or '' when Windows names none that exists.
  try { $d = [Environment]::GetFolderPath('Desktop'); if ($d -and (Test-Path -LiteralPath $d -PathType Container)) { return $d } } catch { $null = $_ }
  return ''
}
function Get-ShortcutDir {
  # R29 (the PFM, 17 Nov 26: "I should be asked where to install it, but have the desktop path prefilled"): the folder for the
  # RADE shortcut. RADE\Config\rade-shortcut.txt holds the folder the user chose; else the Desktop folder. '' when neither exists.
  try { $p = Get-RadeConfigFile 'rade-shortcut.txt'
    if (Test-Path -LiteralPath $p -PathType Leaf) { $v = ([string](Get-Content -LiteralPath $p -TotalCount 1)).Trim(); if ($v -and (Test-Path -LiteralPath $v -PathType Container)) { return $v } } } catch { $null = $_ }
  return (Get-DesktopDir)
}
# Saves the folder chosen for the RADE shortcut to RADE\Config\rade-shortcut.txt; a failure is ignored. Takes the
# folder; gives back nothing.
function Save-ShortcutDir([string]$Dir) {
  try { $p = Get-RadeConfigFile 'rade-shortcut.txt'; $d = Split-Path -Parent $p
    if (-not (Test-Path -LiteralPath $d -PathType Container)) { [void](New-Item -ItemType Directory -Path $d -Force) }
    Write-FileWhole $p ($Dir + "`r`n") } catch { $null = $_ }
}
# Says whether a shortcut named RADE.lnk is in the saved shortcut folder. Takes nothing; gives back $true or $false.
function Test-ShortcutMade { $d = Get-ShortcutDir; return [bool]($d -and (Test-Path -LiteralPath (Join-Path $d 'RADE.lnk'))) }
function Add-DesktopIcon([string]$Dir) {
  # One shortcut named RADE in the folder the user chose on the install card ($Dir; R29), else the user's own Desktop folder,
  # made once, only when missing, with no administrator rights (WScript.Shell). Returns the plain line the Done card shows,
  # or '' when there is nothing to say.
  try { $runner = Join-Path (Get-RadePath) 'rade-runner.ps1'
    if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) { return '' }
    $desk = $(if ($Dir) { $Dir } else { Get-ShortcutDir }); $isDesk = (-not $desk -or $desk -eq (Get-DesktopDir))   # no folder given: the one chosen before (review of PR 78), else the Desktop
    if (-not $desk -or -not (Test-Path -LiteralPath $desk -PathType Container)) { return $(if ($isDesk) { 'RADE could not find your Desktop folder, so it made no desktop shortcut. Open RADE from the RADE page instead.' } else { 'RADE could not find the folder you chose, so it made no shortcut. Open RADE from the RADE page instead.' }) }
    $lnk = Join-Path $desk 'RADE.lnk'
    if (Test-Path -LiteralPath $lnk) { return '' }
    $sh = New-Object -ComObject WScript.Shell; $sc = $sh.CreateShortcut($lnk)
    $sc.TargetPath = (Get-PowerShellExe); $sc.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Minimized -File "' + $runner + '"'
    $sc.WorkingDirectory = (Get-RadePath); $sc.Description = 'Open RADE'; $sc.WindowStyle = 7; $sc.Save()
    return $(if ($isDesk) { 'A shortcut named RADE is now on your desktop. It opens RADE.' } else { 'A shortcut named RADE is now in the folder "' + (Split-Path -Leaf $desk) + '". It opens RADE.' })
  } catch { return 'RADE could not make a desktop shortcut. Open RADE from the RADE page instead.' }
}
function Get-MadeLine {
  # Deploy: what the installs of the chosen app made, from the record (deploy v1 item 4: the list a user needs to remove it by hand).
  $out = @()
  $e = (Read-Installed (Get-InstalledKey $script:app))
  if ($e -and $e.steps) { foreach ($n in @($e.steps.Keys)) { foreach ($m in @($e.steps[$n].made)) { if ($null -ne $m) { $out += ('  ' + [string]$m.kind + ': ' + [string]$m.name + '  (' + [string]$n + ')') } } } }
  if ($out.Count) { return (@('Made by this app''s installs on this computer and site (to remove the app, remove these by hand):') + $out) }
  return @()
}
# Gives the help line that names the Teams channel (a name only, no link). Takes nothing; gives back the text.
function Get-HelpLine { return ('For help, ask in the Teams channel ' + $helpChannel + '.') }
