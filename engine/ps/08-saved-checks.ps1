# ---- Saved checks (PFM 14 Nov 26, R17): RADE\Config\rade-checks.json keeps each check that PASSED, so a later run (of
# any app on this computer) can skip it. A saved result is used only when it is at most $checkMaxDays days old, the
# PowerShell and PnP versions and the computer are the same, and its scope (the site or the Power Automate address, as a
# hash) matches. A check that did not pass is never saved. No DODID, name or address is in the file (details are masked).
$checkMaxDays = 7
# Checks whose answer can change between two runs on the same day always run (review R17 MAJOR 2: "Word is open" blocks a
# deploy, PFM 14 Nov 26 1B; free space; a test file in OneDrive).
$checkNoSave = @('nipr', 'word', 'disk', 'write')
function Get-ShortHash([string]$Text) {
  if (-not $Text) { return '' }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return (-join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text.ToLowerInvariant().TrimEnd('/'))) | Select-Object -First 6 | ForEach-Object { $_.ToString('x2') })) } finally { $sha.Dispose() }
}
function Get-CheckHost {
  # What makes a saved result stale when it changes: PowerShell, the PnP module, the computer (hashed).
  if ($script:checkHost) { return $script:checkHost }
  $pnp = ''; try { $m = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending); if ($m.Count) { $pnp = [string]$m[0].Version } } catch { $null = $_ }
  $script:checkHost = @{ powershell = [string]$PSVersionTable.PSVersion; pnp = $pnp; computer = (Get-ShortHash ([string]$env:COMPUTERNAME)) }
  return $script:checkHost
}
function Get-CheckScope([string]$Id, [string]$Base, [string]$Site) {
  # A result about one site or one address is good only for that site or address.
  if ($Id -in 'net-site', 'site-rights') { return ('site:' + (Get-ShortHash $Site)) }
  if ($Id -in 'net-flow', 'flow-guide') { return ('flow:' + (Get-ShortHash (Get-FlowPortal $Base).Url)) }
  return ''
}
function Read-CheckCache {
  $p = Get-RadeConfigFile 'rade-checks.json'
  $res = @{}
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $res }
  try {
    $j = [System.IO.File]::ReadAllText($p) | ConvertFrom-Json
    $h = Get-CheckHost
    if ([string]$j.host.powershell -ne $h.powershell -or [string]$j.host.pnp -ne $h.pnp -or [string]$j.host.computer -ne $h.computer) { return $res }
    foreach ($c in @($j.checks.PSObject.Properties)) {
      $v = $c.Value
      $at = $v.at; if ($at -is [datetime]) { $at = $at.ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture) }   # PowerShell 7 reads it as a date
      $res[$c.Name] = @{ State = [string]$v.state; Detail = [string]$v.detail; Fix = ''; At = [string]$at; Scope = [string]$v.scope }
    }
  } catch { $null = $_ }   # a damaged file is ignored: every check runs
  return $res
}
function Get-CheckAge([string]$At) {
  # Days since a saved result (fractional); -1 when the date cannot be read.
  $d = [datetime]::MinValue
  if ([datetime]::TryParseExact($At, 'yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture, 'None', [ref]$d)) { return ((Get-Date) - $d).TotalDays }
  return 99999   # unreadable: too old
}
function Get-SavedCheck($Cache, [string]$Id, [string]$Scope) {
  # The saved result to use, or $null (with the reason in $script:savedWhy[$Id] when one was found but is too old).
  if ($checkNoSave -contains $Id) { return $null }
  $c = $Cache[$Id]
  if (-not $c -or $c.State -ne 'PASSED' -or $c.Scope -ne $Scope) { return $null }
  $age = Get-CheckAge $c.At
  if ($age -lt -0.01) { $script:savedWhy[$Id] = 'Last check date is in the future (clock changed)'; return $null }
  if ($age -gt $checkMaxDays) { $script:savedWhy[$Id] = ('Last check ' + [int][math]::Floor([math]::Max(0, $age)) + ' days ago, older than ' + $checkMaxDays + ' days'); return $null }
  # Two lines (the Administrator, 2026-11-14): "Last check: 17 Nov 26", then what that check found; no full stops.
  $d0 = [datetime]::ParseExact($c.At, 'yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
  $found = ([string]$c.Detail) -replace '\.$', ''; if ($found) { $found = $found.Substring(0, 1).ToUpperInvariant() + $found.Substring(1) }
  return @{ State = 'PASSED'; Detail = ('Last check: ' + $d0.ToString('d MMM yy', [System.Globalization.CultureInfo]::InvariantCulture)); Fix = $found; Saved = $true; Found = $found }
}
function Save-CheckCache($Results, [string]$Base, [string]$Site) {
  # Keeps the old file's other entries (other apps' checks), replaces this run's: PASSED is saved, anything else removed.
  try {
    $p = Get-RadeConfigFile 'rade-checks.json'
    $keep = @{}
    if (Test-Path -LiteralPath $p -PathType Leaf) {
      try { $j = [System.IO.File]::ReadAllText($p) | ConvertFrom-Json; foreach ($c in @($j.checks.PSObject.Properties)) { $keep[$c.Name] = $c.Value } } catch { $null = $_ }
      try { $h0 = Get-CheckHost; if ([string]$j.host.powershell -ne $h0.powershell -or [string]$j.host.pnp -ne $h0.pnp -or [string]$j.host.computer -ne $h0.computer) { $keep = @{} } } catch { $null = $_ }
    }
    foreach ($id in @($Results.Keys)) {
      $r = $Results[$id]
      if ($r.Saved) { continue }   # a saved result keeps its first date
      if ($checkNoSave -contains $id) { if ($keep.ContainsKey($id)) { $keep.Remove($id) }; continue }
      if ($r.State -eq 'PASSED') {
        $keep[$id] = [ordered]@{ state = 'PASSED'; detail = (ConvertTo-Masked ([string]$r.Detail)); at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture); scope = (Get-CheckScope $id $Base $Site) }
      } elseif ($keep.ContainsKey($id) -and $r.State -ne 'RUNNING') { $keep.Remove($id) }
    }
    $sorted = [ordered]@{}; foreach ($k in @($keep.Keys | Sort-Object)) { $sorted[$k] = $keep[$k] }
    $doc = [ordered]@{
      schema = 'rade-checks/1'
      about = ('Saved RADE checks. Any app may read this file: use an entry only when its state is PASSED, its "at" is at most ' + $checkMaxDays + ' days old, "host" equals this computer (PowerShell, PnP and the hashed computer name), and "scope" matches (site: or flow: plus the first 12 hex of the SHA-256 of the lower-case address). Write only PASSED results; remove an entry when the check does not pass.')
      maxAgeDays = $checkMaxDays
      host = (Get-CheckHost)
      checks = $sorted
    }
    Write-FileWhole $p ($doc | ConvertTo-Json -Depth 5)
  } catch { $null = $_ }   # saving is a convenience: never stop for it
}
function Get-CheckToRun($Def, $Cache, [string]$Base, [string]$Site, [bool]$Force) {
  # $null = run it now; else the saved result to show.
  if ($Force) { return $null }
  if ($Def.Id -eq 'site-rights' -and (Test-FirstInstall)) { return $null }   # a first install always reads the site's install record fresh
  return (Get-SavedCheck $Cache $Def.Id (Get-CheckScope $Def.Id $Base $Site))
}
