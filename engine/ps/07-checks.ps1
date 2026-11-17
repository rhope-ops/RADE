# RADE engine part 07, the checks: the NIPR guard, the site address, the web and sign-in checks, the install
# record on the site, and Invoke-Check, which runs one check. Its results are saved by 08-saved-checks.ps1.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.
# ---- Checks (PFM 14 Nov 26: RADE checks, from its window, that this computer can install the chosen app and
# that the PFM has the rights to see it done end to end). Read-only except: one test file in the OneDrive folder and one
# temporary script in the Windows temp folder, each deleted at once, and the site address in Config when the PFM enters it.
# Kind: auto = runs on its own when the Check screen opens; signin = needs a CAC sign-in (button); guide = the PFM looks
# in another program and answers (button). Advisory: a problem is a WARNING, never a FAILED.
$checkDefs = @(
  @{ Id = 'nipr'; Group = 'Local'; Name = 'This computer is on NIPR (area52 domain)'; Kind = 'auto' },
  @{ Id = 'ps'; Group = 'Local'; Name = 'PowerShell is version 5.1 or newer'; Kind = 'auto' },
  @{ Id = 'lang'; Group = 'Local'; Name = 'PowerShell is not restricted'; Kind = 'auto' },
  @{ Id = 'onedrive'; Group = 'Local'; Name = 'Your OneDrive folder is set up'; Kind = 'auto' },
  @{ Id = 'disk'; Group = 'Local'; Name = 'There is enough free disk space'; Kind = 'auto' },
  @{ Id = 'write'; Group = 'Local'; Name = 'Files can be saved in OneDrive'; Kind = 'auto' },
  @{ Id = 'child'; Group = 'Local'; Name = 'RADE can run its scripts'; Kind = 'auto' },
  @{ Id = 'outlook'; Group = 'Local'; Name = 'Outlook can make the results e-mail'; Kind = 'auto'; Advisory = $true },
  @{ Id = 'word'; Group = 'Local'; Name = 'Word is installed'; Kind = 'auto' },
  @{ Id = 'pnp'; Group = 'Local'; Name = 'The SharePoint tool (PnP.PowerShell 1.12.0) is installed'; Short = 'The SharePoint tool (PnP 1.12.0) is installed'; Kind = 'auto' },
  @{ Id = 'net-bookmark'; Group = 'Network'; Name = 'The repository can be reached'; Kind = 'auto'; Advisory = $true },
  @{ Id = 'net-site'; Group = 'Network'; Name = 'Your SharePoint site can be reached'; Kind = 'auto' },
  @{ Id = 'net-flow'; Group = 'Network'; Name = 'Power Automate can be reached'; Kind = 'auto' },
  @{ Id = 'site-rights'; Group = 'Access'; Name = 'You can change the site (sign in with your CAC)'; Short = 'You can change the site (CAC sign-in)'; Kind = 'signin' },
  @{ Id = 'flow-guide'; Group = 'Access'; Name = 'You can import flows in Power Automate (you look)'; Short = 'You can import flows (you look)'; Kind = 'guide' }
)
# Short: the name in the window's narrow check column (the Administrator, 2026-11-14); the log and the e-mail keep Name.
$dot = ' ' + [char]0x00B7 + ' '   # a middle dot between facts, made at run time so the bundle stays ASCII
# ---- Environment guard (the Administrator, 15 Nov 26): RADE runs on NIPR computers only. It reads this computer's own
# full name (host name and its domain: two local values; nothing is sent and no host is contacted) and goes on only when
# that name contains the NIPR domain label below. It cannot prove NIPR; it stops an honest mistake. The name is never shown or saved.
$niprLabel = '.area52.'
# Reads this computer's own host name and domain name (two local values; no host is contacted). Takes nothing; gives
# back "host.domain", or an empty text on an error.
function Get-OwnFqdn { try { $g = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties(); return [string]$g.HostName + '.' + [string]$g.DomainName } catch { return '' } }
# Says whether this computer's full name has the NIPR domain label. Takes nothing; gives back $true or $false.
function Test-NiprDevice { return ([string](Get-OwnFqdn)).Trim().ToLowerInvariant().Contains($niprLabel) }
# Finds the definition of a check by its id. Takes the id; gives back the definition, or $null.
function Get-CheckDef([string]$Id) { foreach ($d in $checkDefs) { if ($d.Id -eq $Id) { return $d } }; return $null }
function Get-SiteUrl([string]$Base) {
  # Config\@@PREFIX@@-site.txt: the same file T16 site setup keeps (one place for the site address; never in the repo).
  $p = Get-ConfigFile $Base '@@PREFIX@@-site.txt'
  if (Test-Path -LiteralPath $p -PathType Leaf) { try { return ([string](Get-Content -LiteralPath $p -TotalCount 1)).Trim() } catch { return '' } }
  return ''
}
$sitePrefix = 'https://usaf.dps.mil/sites/'   # the DAF SharePoint address every site starts with; the box starts with it
# Guardrail (the Administrator, 14 Nov 26): only a site on the DAF SharePoint host is accepted, so RADE never signs in to
# or writes to another host.
function Test-SiteUrl([string]$Url) { return ($Url -match ('^' + [regex]::Escape($sitePrefix) + '[^/\\\s"]+/?$')) }
# Writes the site address to Config\<prefix>-site.txt, creating the folder if needed. Takes the base folder and the
# address; gives back nothing.
function Save-SiteUrl([string]$Base, [string]$Url) {
  $p = Get-ConfigFile $Base '@@PREFIX@@-site.txt'
  $dir = Split-Path -Parent $p
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
  [System.IO.File]::WriteAllText($p, ($Url.Trim() + "`r`n"), (New-Object System.Text.UTF8Encoding $true))
}
function Get-FlowPortal([string]$Base) {
  # The address the guide steps open (editable there, remembered in Config); the first app step that names one wins.
  foreach ($k in $script:appSteps) {
    $s = $steps[$k]
    if ($s.Url) {
      if ($s.UrlConfig) { $p = Get-ConfigFile $Base $s.UrlConfig; if (Test-Path -LiteralPath $p -PathType Leaf) { try { $v = ([string](Get-Content -LiteralPath $p -TotalCount 1)).Trim(); if ($v -match '^https://') { return @{ Url = $v; Config = $p } } } catch { $null = $_ } } }
      return @{ Url = $s.Url; Config = $(if ($s.UrlConfig) { Get-ConfigFile $Base $s.UrlConfig } else { '' }) }
    }
  }
  return @{ Url = ''; Config = '' }
}
function Test-WebReach([string]$Url) {
  # TLS 1.2 first (found in R19, fixed for R20: Windows PowerShell 5.1 starts with TLS 1.0, which GitHub closes: [ReceiveFailure]; Edge uses 1.2).
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch { $null = $_ }
  # Does the host answer? Any HTTP answer counts (401 or 403 = it answers but wants a sign-in). Windows sign-in for the proxy.
  # Returns no address and no message text (they can hold the site or tenant name): only the code or the error kind.
  try {
    $rq = [System.Net.WebRequest]::Create($Url)
    $rq.Timeout = 6000
    # R20: [ReceiveFailure] stayed with TLS 1.2 set. A request with no User-Agent can be closed by a filtering proxy (agent
    # finding, Confidence low); send the one Edge's family sends.
    try { $rq.UserAgent = $webAgent } catch { $null = $_ }
    try { $rq.UseDefaultCredentials = $true } catch { $null = $_ }
    try { $rq.AllowAutoRedirect = $false } catch { $null = $_ }
    try { if ($rq.Proxy) { $rq.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials } } catch { $null = $_ }
    $rs = $rq.GetResponse()
    $code = 0; try { $code = [int]$rs.StatusCode } catch { $null = $_ }
    $rs.Close()
    return @{ Ok = $true; Code = $code }
  } catch {
    $e = $_.Exception
    while ($e -and -not ($e -is [System.Net.WebException]) -and $e.InnerException) { $e = $e.InnerException }
    if ($e -is [System.Net.WebException] -and $e.Response) {
      $code = 0; try { $code = [int]$e.Response.StatusCode } catch { $null = $_ }
      if ($code -eq 407) { return @{ Ok = $false; Why = 'Network sign-in required, code [407]' } }
      return @{ Ok = $true; Code = $code }
    }
    if ($e -is [System.Net.WebException]) {
      $why = @{ Timeout = 'no reply in time'; NameResolutionFailure = 'address not found'; ConnectFailure = 'could not connect'; ProxyNameResolutionFailure = 'network proxy not found'; TrustFailure = 'the security certificate was not trusted'; SecureChannelFailure = 'secure connection failed' }[[string]$e.Status]
      if (-not $why) { $why = 'network error' }
      $why += ' [' + [string]$e.Status + ']'
      # R21 diagnostics: the inner error kinds, a socket error code and the TLS setting (names and numbers only, no address).
      $kinds = @(); $x = $e.InnerException
      while ($x) { $k = $x.GetType().Name; if ($x -is [System.Net.Sockets.SocketException]) { $k += ' ' + [int]$x.ErrorCode } elseif ($x.HResult) { $k += ' 0x' + ('{0:X8}' -f $x.HResult) }; $kinds += $k; $x = $x.InnerException }
      $tls = ''; try { $tls = [string][Net.ServicePointManager]::SecurityProtocol } catch { $null = $_ }
      if ($kinds.Count -or $tls) { $why += ' (' + (@($kinds) + @('TLS ' + $tls) -join '; ') + ')' }
      return @{ Ok = $false; Why = $why }
    }
    return @{ Ok = $false; Why = 'network error [' + $e.GetType().Name + ']' }
  }
}
function Invoke-ChildScript([string]$Text, [string]$ArgText, [int]$Seconds, [scriptblock]$Tick) {
  # Runs a short embedded check script as a child powershell.exe, the way steps run. The script is written to the Windows
  # temp folder and deleted at once. Returns the exit code and the output lines.
  $exe = 'powershell.exe'
  if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { $exe = 'pwsh' }
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('@@PREFIX@@-check-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.ps1')
  $res = @{ Exit = -1; Lines = @(); Why = '' }
  try {
    [System.IO.File]::WriteAllText($tmp, $Text, (New-Object System.Text.UTF8Encoding $true))
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $tmp + '"' + $(if ($ArgText) { ' ' + $ArgText } else { '' })
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $script:child = $p   # Exit stops a check too (review R17)
    $outTask = $p.StandardOutput.ReadToEndAsync(); $errTask = $p.StandardError.ReadToEndAsync()
    $deadline = (Get-Date).AddSeconds($Seconds)
    while (-not $p.WaitForExit(30)) {
      if ($Tick) { & $Tick }
      if ((Get-Date) -gt $deadline) { try { $p.Kill() } catch { $null = $_ }; $res.Why = 'it ran longer than ' + $Seconds + ' seconds'; break }
    }
    $p.WaitForExit()
    $res.Exit = $p.ExitCode
    $res.Lines = @(([string]$outTask.Result) -split "`r?`n" | Where-Object { $_ })
    if (-not $res.Why -and ([string]$errTask.Result).Trim()) { $res.Why = 'it wrote error output' }
  } catch { $res.Why = $_.Exception.GetType().Name }
  finally { $script:child = $null; try { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force } } catch { $null = $_ } }
  return $res
}
$rightsScript = @'
param([string]$Site, [string]$MarkerList = '', [string]$MarkerKey = '', [string]$MarkerField = '')
# RADE check (read-only): signs in with the CAC (web login, as T16 does) and prints your rights on the site, whether your
# own account is a site collection administrator (one flag; no list of administrators) and, when the app keeps an install
# record on the site, the version in that one row. Prints only right names, True/False and a version, never the site,
# your name or an error message.
try {
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { 'RESULT no-pnp'; exit 3 }
  $pin = @($mod | Where-Object { [string]$_.Version -eq '1.12.0' }); if ($pin.Count) { $mod = $pin }   # the tested version first (2.x needs PowerShell 7)
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  $null = & { Connect-PnPOnline -Url $Site -UseWebLogin -ErrorAction Stop } *>&1
  $script:web = $null
  $null = & { $script:web = Get-PnPWeb -Includes EffectiveBasePermissions -ErrorAction Stop } *>&1
  $p = $script:web.EffectiveBasePermissions
  $k = [Microsoft.SharePoint.Client.PermissionKind]
  foreach ($n in 'ViewListItems', 'AddListItems', 'EditListItems', 'ManageLists', 'ManageWeb', 'ManagePermissions') { 'RIGHT ' + $n + ' ' + $p.Has($k::$n) }
  try {
    $script:adm = $null
    $null = & { $script:adm = (Get-PnPWeb -Includes CurrentUser -ErrorAction Stop).CurrentUser.IsSiteAdmin } *>&1
    if ($script:adm -is [bool]) { 'ADMIN ' + $script:adm } else { 'ADMIN unknown' }
  } catch { 'ADMIN unknown' }
  if ($MarkerList) {
    try {
      $script:mk = 'none'
      $null = & {
        $l = Get-PnPList -Identity $MarkerList -ErrorAction Stop   # a list that does not exist gives nothing, not an error
        if ($l) {
          $q = "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>" + $MarkerKey + "</Value></Eq></Where></Query><RowLimit>1</RowLimit></View>"
          $it = @(Get-PnPListItem -List $l -Query $q -ErrorAction Stop)
          if ($it.Count) {
            $v = ([string]$it[0][$MarkerField]).Trim()
            if ($v -match '^([0-9][0-9.]*)') { $script:mk = 'found ' + $Matches[1] } elseif ($v) { $script:mk = 'found 0' }   # any value is an install
          }
        }
      } *>&1
      'MARKER ' + $script:mk
    } catch { 'MARKER unknown' }
  }
  exit 0
} catch { 'RESULT not-connected ' + $_.Exception.GetType().Name; exit 2 }
'@
$rightWords = @{ ViewListItems = 'read items'; AddListItems = 'add items'; EditListItems = 'edit items'; ManageLists = 'manage lists'; ManageWeb = 'manage the site'; ManagePermissions = 'manage permissions' }
$rightsNeeded = @('ManageLists', 'ManageWeb', 'ManagePermissions')   # what T16 site setup and list set-up use
# ---- Install record on the site (the Administrator, 14 Nov 26: one install per site). An app with "marker" in the
# manifest keeps one row (Title = Key) in its own list: the installed version and the date, no name. The record in
# RADE\Config is per account; this row is what another account's RADE sees. A site that has the row and an account
# that did not install it: the deploy is blocked (a second import would run every flow twice).
function Get-MarkerArg {
  $m = $script:app.Marker
  if (-not $m) { return '' }
  return (' -MarkerList "' + $m.List + '" -MarkerKey "' + $m.Key + '" -MarkerField "' + $m.Field + '"')
}
# Gives a short hash that stands for a site address (so the record never holds the address). Takes the site address;
# gives back the hash, or an empty text when the address is not valid.
function Get-SiteMark([string]$Site) {
  if (-not (Test-SiteUrl $Site)) { return '' }
  return (Get-ShortHash $Site.Trim().TrimEnd('/').ToLowerInvariant())
}
function Test-InstalledHere {
  # True when this account's record for this site (Get-InstalledKey) holds a step: a deploy from this account reached
  # a step here. A run that reached no step does not count.
  if (-not (Get-SiteMark (Get-SiteUrl (Get-BasePath)))) { return $false }
  $e = (Read-Installed (Get-InstalledKey $script:app))
  return [bool]($e -and $e.steps -and $e.steps.Count)
}
# Says whether this is a deploy of an app that keeps a row on the site and this account has not installed it on that
# site yet. Takes nothing; gives back $true or $false.
function Test-FirstInstall { return ((Test-Deploy) -and [bool]$script:app.Marker -and -not (Test-InstalledHere)) }
$markerScript = @'
param([string]$Site, [string]$MarkerList, [string]$MarkerKey, [string]$MarkerField, [string]$Value)
# RADE (one write): signs in with the CAC and sets one row of the app's own list to the installed version and the date.
# Adds the row when it is missing; changes nothing else. Prints one RESULT word, never the site, a name or an error message.
try {
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { 'RESULT no-pnp'; exit 3 }
  $pin = @($mod | Where-Object { [string]$_.Version -eq '1.12.0' }); if ($pin.Count) { $mod = $pin }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  $null = & { Connect-PnPOnline -Url $Site -UseWebLogin -ErrorAction Stop } *>&1
  $script:res = 'no-list'
  $null = & {
    $l = Get-PnPList -Identity $MarkerList -ErrorAction Stop
    if ($l) {
      $q = "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>" + $MarkerKey + "</Value></Eq></Where></Query><RowLimit>1</RowLimit></View>"
      $it = @(Get-PnPListItem -List $l -Query $q -ErrorAction Stop)
      if ($it.Count) { $null = Set-PnPListItem -List $l -Identity $it[0].Id -Values @{ $MarkerField = $Value } -ErrorAction Stop; $script:res = 'updated' }
      else { $null = Add-PnPListItem -List $l -Values @{ Title = $MarkerKey; $MarkerField = $Value } -ErrorAction Stop; $script:res = 'added' }
    }
  } *>&1
  'RESULT ' + $script:res
  exit 0
} catch { 'RESULT failed ' + $_.Exception.GetType().Name; exit 2 }
'@
function Write-SiteMarker([string]$Base, [bool]$Whole) {
  # After a deploy that ran a step: a part install is recorded too (its flows may be imported already), with the word
  # "partial". Returns the one line for the log and the report.
  $m = $script:app.Marker; $site = Get-SiteUrl $Base
  $where = '"' + $m.List + '", row "' + $m.Key + '"'
  $again = ' Until it is written, another account is not stopped from a second install on this site: run this deploy again'
  if (-not (Test-SiteUrl $site)) { return ('NOTE: the install record on the site (' + $where + ') was not written: no site address.' + $again) }
  $val = [string]$script:app.Version + ' ' + (Get-Date).ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture) + $(if ($Whole) { '' } else { ' partial' })
  $r = Invoke-ChildScript $markerScript ('-Site "' + $site + '"' + (Get-MarkerArg) + ' -Value "' + $val + '"') 300 $null
  $w = ''; foreach ($l in $r.Lines) { if ($l -match '^RESULT (\S+)') { $w = $Matches[1] } }
  if ($w -in 'added', 'updated') { return ('Install record on the site: ' + $where + ' now holds version ' + $script:app.Version + ' and the date' + $(if ($Whole) { '' } else { ', marked partial' }) + ' (' + $w + ').') }
  $why = $(switch ($w) { 'no-list' { 'the list was not found' } 'no-pnp' { 'the SharePoint tool is not installed' } default { 'the sign-in or the write did not finish' } })
  return ('NOTE: the install record on the site (' + $where + ') was not written: ' + $why + '.' + $again)
}
function Split-Sentence([string]$Text) {
  # One sentence per line on screen (PFM 14 Nov 26): a break after . ! or ? when a capital, a quote or a bracket follows.
  return ($Text -replace '(?<=[.!?])\s+(?=[A-Z"\[])', "`r`n")
}
function Format-CheckResult([string]$State, [string]$Detail, [string]$Fix) {
  # Text rule (the Administrator, 2026-11-14, replaces the full-stop rule): each Details line starts with a capital and ends
  # with no full stop; one fact per line, never joined with ";". Names on the screen (buttons, menus) are in "double quotes";
  # literal values the computer reports (versions, codes, error names) are in [brackets].
  if ($Detail) { $Detail = $Detail.Substring(0, 1).ToUpper() + $Detail.Substring(1); $Detail = $Detail -replace '\.$', '' }
  if ($Fix) { $Fix = $Fix -replace '\.$', '' }
  return @{ State = $State; Detail = $Detail; Fix = $Fix }
}
# Checks of this computer itself: NIPR name, PowerShell version and language mode, OneDrive, free space, a test file,
# and a child script. Takes the check id and the tick callback (for the child script); returns a check result
# (Format-CheckResult), or $null for an id it does not handle.
function Get-ComputerCheck([string]$Id, [scriptblock]$Tick) {
  $one = $null
  switch ($Id) {
  'nipr' {
    # Reads only this computer's own full name (Test-NiprDevice); the name itself is never shown or saved.
    if (Test-NiprDevice) { $one = Format-CheckResult 'PASSED' 'Read this computer''s own full name: it is in the area52 domain' '' }
    else { $one = Format-CheckResult 'FAILED' 'This application cannot be installed in your environment.' '' }
  }
  'ps' {
    $v = $PSVersionTable.PSVersion
    if ($v -ge [version]'5.1') { $one = Format-CheckResult 'PASSED' ('version [' + $v + ']') '' }
    else { $one = Format-CheckResult 'FAILED' ('version [' + $v + ']') 'Open Windows PowerShell ISE from the Start menu, then paste the round again' }
  }
  'lang' {
    $m = [string]$ExecutionContext.SessionState.LanguageMode
    if ($m -eq 'FullLanguage') { $one = Format-CheckResult 'PASSED' 'Not restricted' '' }
    else { $one = Format-CheckResult 'FAILED' ('Restricted [' + $m + ']') 'PowerShell is restricted on this computer. Contact your ISSM and send the results e-mail as is' }
  }
  'onedrive' {
    $od = Get-OneDrivePath
    if (Test-Path -LiteralPath $od -PathType Container) { $one = Format-CheckResult 'PASSED' 'found' '' }
    else { $one = Format-CheckResult 'FAILED' 'not found' 'Sign in to OneDrive, wait until it is up to date, then select "Run checks again"' }
  }
  'disk' {
    $od = Get-OneDrivePath
    $root = [System.IO.Path]::GetPathRoot($od); if (-not $root) { $root = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetTempPath()) }
    $free = (New-Object System.IO.DriveInfo($root)).AvailableFreeSpace
    $need = 200MB; foreach ($f in $files) { $need += 2 * $f.Data.Length }
    $mb = [math]::Floor($free / 1MB)
    if ($free -lt $need) { $one = Format-CheckResult 'FAILED' ('{0:N0} MB free, {1:N0} MB needed' -f $mb, [math]::Ceiling($need / 1MB)) 'Free up space (for example, empty the Recycle Bin), then select "Run checks again"' }
    elseif ($free -lt 1GB) { $one = Format-CheckResult 'WARNING' ('{0:N0} MB free' -f $mb) 'Enough for this deployment. Free up space soon' }
    else { $one = Format-CheckResult 'PASSED' ('{0:N0} MB free' -f $mb) '' }
  }
  'write' {
    $od = Get-OneDrivePath
    if (-not (Test-Path -LiteralPath $od -PathType Container)) { $one = Format-CheckResult 'NOT RUN' 'No OneDrive folder' 'Resolve the OneDrive check first' }
    else {
      $t = Join-Path $od ('@@PREFIX@@-write-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.tmp')
      [System.IO.File]::WriteAllText($t, 'test'); Remove-Item -LiteralPath $t -Force
      $one = Format-CheckResult 'PASSED' 'Test file saved and deleted' ''
    }
  }
  'child' {
    # Steps run as child scripts with -ExecutionPolicy Bypass; a Group Policy can still block them.
    $r = Invoke-ChildScript "'child ok'`r`nexit 7`r`n" '' 60 $Tick
    $pol = ''
    try { $pol = (@(Get-ExecutionPolicy -List | Where-Object { $_.Scope -match 'Policy$' -and [string]$_.ExecutionPolicy -ne 'Undefined' } | ForEach-Object { [string]$_.Scope + '=' + [string]$_.ExecutionPolicy }) -join ', ') } catch { $null = $_ }
    if ($r.Exit -eq 7) { $one = Format-CheckResult 'PASSED' ('Test script ran' + $(if ($pol) { ', policy [' + $pol + ']' } else { '' })) '' }
    else { $one = Format-CheckResult 'FAILED' ('Test script did not run, exit code [' + $r.Exit + ']' + $(if ($r.Why) { ', ' + $r.Why } else { '' }) + $(if ($pol) { ', policy [' + $pol + ']' } else { '' })) 'This computer blocks RADE scripts. Contact your ISSM and send the results e-mail as is' }
  }
  }
  return $one
}

# Checks of installed programs: classic Outlook (drafts), Word (renders; it must also be closed) and PnP.PowerShell.
# Takes the check id; returns a check result, or $null for an id it does not handle.
function Get-ProgramCheck([string]$Id) {
  $one = $null
  switch ($Id) {
  'outlook' {
    if ($env:OS -ne 'Windows_NT') { $one = Format-CheckResult 'WARNING' 'Not Windows' 'RADE opens the results folder and copies the summary for your e-mail' }
    elseif ([type]::GetTypeFromProgID('Outlook.Application')) { $one = Format-CheckResult 'PASSED' 'Installed' '' }
    else { $one = Format-CheckResult 'WARNING' 'Classic Outlook not found (new Outlook cannot make drafts)' 'RADE opens the results folder and copies the summary for your e-mail' }
  }
  'word' {
    if ($env:OS -eq 'Windows_NT' -and [type]::GetTypeFromProgID('Word.Application')) {
      if (Test-WordOpen) { $one = Format-CheckResult 'FAILED' 'Installed, but open now' 'Save your work, close Word, then select "Run checks again"' }   # PFM 14 Nov 26: blocks (1B)
      else { $one = Format-CheckResult 'PASSED' 'Installed' '' }
    } else { $one = Format-CheckResult 'FAILED' 'Not found' 'This application requires Microsoft Word' }
  }
  'pnp' {
    $m = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
    if (-not $m.Count) { $one = Format-CheckResult 'FAILED' 'Not installed' 'Site steps require it. Use the manual steps in the repository' }
    elseif ([string]$m[0].Version -eq '1.12.0') { $one = Format-CheckResult 'PASSED' 'version [1.12.0]' '' }
    else { $one = Format-CheckResult 'WARNING' ('Version [' + $m[0].Version + '], tested with [1.12.0]') 'Likely compatible. If a site step fails, send the results as is' }
  }
  }
  return $one
}

# Checks that a fixed address answers (the repository's go file, the site, Power Automate). Only these addresses: no
# host finding (AGENTS.md "No reconnaissance"). Takes the check id, the RADE app folder and the site address; returns
# a check result, or $null for an id it does not handle.
function Get-NetworkCheck([string]$Id, [string]$Base, [string]$Site) {
  $one = $null
  switch ($Id) {
  'net-bookmark' {
    $w = Test-WebReach $goUrl   # the file the "newer round" notice reads
    if ($w.Ok) { $one = Format-CheckResult 'PASSED' ('reached' + $(if ($w.Code) { ', code [' + $w.Code + ']' } else { '' })) '' }
    else { $one = Format-CheckResult 'WARNING' ('Not reached: ' + $w.Why) 'Optional: only the new-round notice uses it' }
  }
  'net-site' {
    if (-not (Test-SiteUrl $Site)) { $one = Format-CheckResult 'NOT RUN' 'No site address' ('Complete the "Site address" box (it starts with ' + $sitePrefix + '), then select "Run checks again"') }
    else {
      $w = Test-WebReach $Site
      if ($w.Ok) { $one = Format-CheckResult 'PASSED' ('Reached' + $(if ($w.Code -in 401, 403) { ', code [' + $w.Code + '] (sign-in required, as expected)' } elseif ($w.Code) { ', code [' + $w.Code + ']' } else { '' })) '' }
      else { $one = Format-CheckResult 'FAILED' ('Not reached: ' + $w.Why) 'Verify the address opens in Edge, then select "Run checks again"' }
    }
  }
  'net-flow' {
    $fp = Get-FlowPortal $Base
    if (-not $fp.Url) { $one = Format-CheckResult 'NOT RUN' 'No Power Automate address' '' }
    else {
      $w = Test-WebReach $fp.Url
      if ($w.Ok) { $one = Format-CheckResult 'PASSED' ('reached' + $(if ($w.Code) { ', code [' + $w.Code + ']' } else { '' })) '' }
      else { $one = Format-CheckResult 'FAILED' ('Not reached: ' + $w.Why) 'If Power Automate opens in Edge, select "Check Power Automate"' }
    }
  }
  }
  return $one
}

# The site rights check: a child script signs in with the CAC and prints only right names, True/False, the admin flag
# and the install record's version ($rightsScript). Fails on a missing right or on another account's install record.
# Takes the RADE app folder, the site address and the tick callback; returns a check result.
function Get-SiteRightsCheck([string]$Base, [string]$Site, [scriptblock]$Tick) {
  if (-not (Test-SiteUrl $Site)) { $one = Format-CheckResult 'NOT RUN' 'No site address' ('Complete the "Site address" box first (it starts with ' + $sitePrefix + ')') }
  else {
    $r = Invoke-ChildScript $rightsScript ('-Site "' + $Site + '"' + (Get-MarkerArg)) 300 $Tick
    $have = @{}; $adm = 'unknown'; $mk = ''
    foreach ($l in $r.Lines) {
      if ($l -match '^RIGHT (\w+) (True|False)$') { $have[$Matches[1]] = ($Matches[2] -eq 'True') }
      if ($l -match '^ADMIN (True|False|unknown)$') { $adm = $Matches[1] }
      if ($l -match '^MARKER (none|unknown|found [0-9.]+)$') { $mk = $Matches[1] }
    }
    $admText = 'Site collection administrator: ' + $(switch ($adm) { 'True' { 'yes' } 'False' { 'no' } default { 'not read' } }) + ' (shown only, not required)'
    if (-not $have.Count) {
      $why = 'Sign-in did not finish'; foreach ($l in $r.Lines) { if ($l -match '^RESULT (\S+)') { $why = $Matches[1] } }
      if ($why -eq 'not-connected') { $why = 'Sign-in did not finish' }
      if ($why -eq 'no-pnp') { $one = Format-CheckResult 'FAILED' 'SharePoint tool not installed' 'See the SharePoint tool check' }
      else { $one = Format-CheckResult 'FAILED' ($why + $(if ($r.Why) { ', ' + $r.Why } else { '' })) 'Select "Sign in and check site rights" and complete the CAC sign-in' }
    } else {
      $miss = @($rightsNeeded | Where-Object { -not $have[$_] } | ForEach-Object { $rightWords[$_] })
      $got = @($have.Keys | Sort-Object | Where-Object { $have[$_] } | ForEach-Object { $rightWords[$_] })
      if ($miss.Count) { $one = Format-CheckResult 'FAILED' ('Missing: ' + ($miss -join ', ')) 'Ask a site owner to add you to the site Owners group' }
      elseif ((Test-FirstInstall) -and $mk -like 'found *') { $one = Format-CheckResult 'FAILED' ('This site already has an install of this application [version ' + $(if ($mk -eq 'found 0') { 'not readable' } else { $mk.Substring(6) }) + '], made from another account or for another site') 'Do not install again: every flow would run twice. Ask the person who installed it to run RADE' }
      elseif ((Test-FirstInstall) -and $mk -ne 'none') { $one = Format-CheckResult 'FAILED' 'The install record on the site could not be read' 'Select "Sign in and check site rights" again' }
      else { $one = Format-CheckResult 'PASSED' ('Rights: ' + ($got -join ', ') + '. ' + $admText) '' }
    }
  }
  return $one
}

# The Power Automate check that a person answers by looking: in text mode at the prompt, in the window on a hand card
# ($script:guideUi). Takes the RADE app folder; returns a check result (NOT RUN when it is not answered).
function Get-FlowGuideCheck([string]$Base) {
  if ($script:textMode) {
    $fp = Get-FlowPortal $Base
    Write-Host ('  Open Power Automate (' + $fp.Url + '). Look at the left menu for "Solutions" (it may be under "More"), then select "My flows" and look for "Import".')
    $a = ([string](Read-Host 'Did you see both "Solutions" and "Import"? Type Y or N and press Enter')).Trim()
    if ($a -match '^[Yy]') { $one = Format-CheckResult 'PASSED' 'Confirmed by you' '' }
    else { $one = Format-CheckResult 'FAILED' '"Solutions" or "Import" not shown' 'Ask your Power Automate administrator for maker access' }
  }
  else {
    $fp = Get-FlowPortal $Base
    $g = @{ Name = 'Check Power Automate'; File = ''; Url = $fp.Url; DoneText = 'Yes: I see both'; NoText = 'No: one is missing'; SkipText = 'Not now'
      Guide = @('You look in Power Automate and answer (about 2 minutes, an estimate). Nothing is changed.',
        '1. Select Open in browser. Power Automate opens; sign in with your CAC if asked.',
        '2. Look at the left menu: it must show Solutions (it may be under More).',
        '3. Select My flows: Import must show at the top of the page.',
        '4. Come back here. Select Yes if you saw both, No if one is missing.') }
    $a = 'Cancel'; if ($script:guideUi) { $a = [string](@(& $script:guideUi $g '' $fp.Url $fp.Config))[-1] }
    if ($a -eq 'OK') { $one = Format-CheckResult 'PASSED' 'Confirmed by you' '' }
    elseif ($a -eq 'No') { $one = Format-CheckResult 'FAILED' '"Solutions" or "Import" not shown' 'Ask your Power Automate administrator for maker access' }
    else { $one = Format-CheckResult 'NOT RUN' 'Not answered' 'Select "Check Power Automate" when ready' }
  }
  return $one
}

# Runs one check (the ids of $checkDefs) and gives its result. States: PASSED, WARNING, FAILED, NOT RUN. Detail and Fix
# never hold the site address or the DODID. An error in a check is a FAILED result, and an advisory check never
# FAILS (WARNING instead). Takes the check definition, the RADE app folder, the site address and the tick callback.
function Invoke-Check($Def, [string]$Base, [string]$Site, [scriptblock]$Tick) {
  $one = $null
  try {
    switch ($Def.Id) {
      { $_ -in 'nipr', 'ps', 'lang', 'onedrive', 'disk', 'write', 'child' } { $one = Get-ComputerCheck $Def.Id $Tick; break }
      { $_ -in 'outlook', 'word', 'pnp' } { $one = Get-ProgramCheck $Def.Id; break }
      { $_ -in 'net-bookmark', 'net-site', 'net-flow' } { $one = Get-NetworkCheck $Def.Id $Base $Site; break }
      'site-rights' { $one = Get-SiteRightsCheck $Base $Site $Tick; break }
      'flow-guide' { $one = Get-FlowGuideCheck $Base; break }
      default { $one = Format-CheckResult 'NOT RUN' 'unknown check' '' }
    }
  } catch { $one = Format-CheckResult 'FAILED' ('Check stopped with an error [' + $_.Exception.GetType().Name + ']') 'Select "Run checks again". If it repeats, send the results as is' }
  if ($Def.Advisory -and $one.State -eq 'FAILED') { $one.State = 'WARNING' }
  return $one
}
function Get-CheckSummary($Results) {
  # For the summary and the e-mail: one count line, then one line for each check that did not pass.
  $c = @{ PASSED = 0; WARNING = 0; FAILED = 0; 'NOT RUN' = 0 }
  $rest = @(); $saved = 0
  foreach ($id in $script:appChecks) {
    $r = $Results[$id]; $d = Get-CheckDef $id
    if (-not $r) { $r = Format-CheckResult 'NOT RUN' 'not run' '' }
    $c[$r.State]++
    if ($r.Saved) { $saved++ }
    if ($r.State -ne 'PASSED') { $rest += ('  ' + $r.State + ': ' + $d.Name + '. ' + $r.Detail) }
  }
  $savedText = $(if ($saved) { ' (' + $saved + ' from saved results)' } else { '' })
  return @(@(('Checks. Passed: ' + $c.PASSED + $savedText + '. Warnings: ' + $c.WARNING + '. Failed: ' + $c.FAILED + '. Not run: ' + $c['NOT RUN'] + '.')) + $rest) | ForEach-Object { ConvertTo-Masked $_ }
}
function Get-CheckBlock($Results) {
  # PFM 14 Nov 26: no deploy unless every check passes (a half-done deploy is hard to undo). FAILED or NOT RUN blocks;
  # a WARNING (an advisory check, or a problem the deploy can live with) does not. No "deploy anyway".
  foreach ($id in $script:appChecks) { $r = $Results[$id]; if (-not $r -or $r.State -in 'FAILED', 'NOT RUN', 'RUNNING') { return $true } }
  return $false
}
