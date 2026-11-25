# RADE engine part 16, the site scripts of the checks (moved out of engine/ps/07-checks.ps1 to keep each file at 450
# lines or fewer; fleet v2 DEC 6): the sign-in window size block ($signInSize, Add-SignInSize), the rights check script
# ($rightsScript), and the install record on the site (Get-MarkerArg, Get-SiteMark, Test-InstalledHere,
# Test-FirstInstall, $markerScript). Part 07 runs them (Invoke-Check, Write-SiteMarker); parts 13 and 14 use
# Add-SignInSize when they load, so this part comes right after part 07.
# Network: none when it loads; the child scripts it holds sign in to the saved site on the DAF SharePoint host (PnP).
# Writes: none when it loads; $markerScript writes the install record (one row of the app's own list on the site).
# Credentials: the interactive CAC sign-in of PnP (-UseWebLogin), in the child scripts.
# Joined into every bundle by engine/rade_build.py, right after part 07; Windows PowerShell 5.1.

# E3 (R42 plan; the Owner, 2026-11-21): the one copy of the sign-in window size block. Each child script that signs in
# holds the line "# <RADE sign-in window size>" in its place; Add-SignInSize puts the block there. An app copies the block
# (from its start line to its end line) into its own task scripts, so both use the same code.
$signInSize = @'
# ---- RADE sign-in window size (start; engine/ps/07-checks.ps1 $signInSize; E3, the Owner, 2026-11-21)
# The CAC sign-in window of Connect-PnPOnline -UseWebLogin (PnP.PowerShell 1.12.0) opens very large. Start-SignInSize,
# called just before Connect-PnPOnline, starts a background timer that, for up to 2 minutes, finds each new visible window
# of THIS process only (the windows of its own threads: no other process and no other host is read) and makes it about
# 480 x 360 logical pixels, in the center of the work area of its screen. The window stays visible, so it can still take
# input. Copy this block unchanged between its start and end lines (an app's task scripts may hold the same copy).
# An app script that opens its own window calls Start-SignInSize -SignInOnly (follow-ups 2 item 10, the Maintainer,
# 2026-11-25): the windows that already exist are left as they are, and only the first new window (the sign-in window)
# is sized; then the watch stops. With no switch, each new window in the 2 minutes is sized (the engine's child scripts).
# Windows PowerShell 5.1, no module. When the helper cannot be compiled (Constrained Language Mode) or the calls fail,
# nothing changes and the sign-in goes on as before.
$SignInW = 480; $SignInH = 360; $SignInWatchMs = 120000; $SignInTickMs = 100
function Start-SignInSize {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
  param([switch]$SignInOnly)
  if (-not $PSCmdlet.ShouldProcess('the sign-in window of this process', 'Set its size')) { return }   # -WhatIf: no timer
  if ($env:OS -ne 'Windows_NT' -and $env:RADE_SIGNIN_TEST -ne '1') { return }   # Windows only (the cloud test sets RADE_SIGNIN_TEST to compile it)
  try {
    if (-not ('RadeSignIn.Size2' -as [type])) {   # Size2: Start takes signInOnly (a process that holds the old Size keeps it)
      Add-Type -Namespace RadeSignIn -Name Size2 -ErrorAction Stop -MemberDefinition @"
public delegate bool WinProc(System.IntPtr h, System.IntPtr l);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool EnumThreadWindows(uint tid, WinProc f, System.IntPtr l);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool IsWindowVisible(System.IntPtr h);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern System.IntPtr GetWindow(System.IntPtr h, uint cmd);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern System.IntPtr MonitorFromWindow(System.IntPtr h, uint flags);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool GetMonitorInfo(System.IntPtr m, ref MonInfo i);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern uint GetDpiForWindow(System.IntPtr h);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool SetWindowPos(System.IntPtr h, System.IntPtr after, int x, int y, int cx, int cy, uint flags);
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct MonInfo { public int Size; public int ML, MT, MR, MB; public int WL, WT, WR, WB; public uint Flags; }
static System.Threading.Timer timer; static WinProc each = Each, mark = Mark; static int w, h, left; static bool one;
static System.Collections.Generic.HashSet<long> seen = new System.Collections.Generic.HashSet<long>(); static object gate = new object();
// Starts the watch: every tickMs, for watchMs, each new visible top-level window of this process gets the size w x h (logical).
// signInOnly: every window of this process that exists now (shown or not) is marked as seen, and the watch stops after it
// has sized one new window, so an app's own window is never sized.
public static void Start(int width, int height, int watchMs, int tickMs, bool signInOnly) {
  lock (gate) { w = width; h = height; one = signInOnly; left = System.Math.Max(1, watchMs / System.Math.Max(1, tickMs));
    if (one) { using (System.Diagnostics.Process me = System.Diagnostics.Process.GetCurrentProcess()) {
      foreach (System.Diagnostics.ProcessThread t in me.Threads) { EnumThreadWindows((uint)t.Id, mark, System.IntPtr.Zero); } } } }
  timer = new System.Threading.Timer(Tick, null, tickMs, tickMs); }
// Marks one window that exists at the start (signInOnly): it is never sized.
static bool Mark(System.IntPtr hw, System.IntPtr l) { seen.Add(hw.ToInt64()); return true; }
// One tick: a tick that starts while the last one still runs is skipped (the timer can overlap), so seen has one writer.
static void Tick(object state) {
  if (!System.Threading.Monitor.TryEnter(gate)) { return; }
  try { if (--left < 0) { timer.Dispose(); return; }
    using (System.Diagnostics.Process me = System.Diagnostics.Process.GetCurrentProcess()) {
      foreach (System.Diagnostics.ProcessThread t in me.Threads) { EnumThreadWindows((uint)t.Id, each, System.IntPtr.Zero); } } }
  catch { }
  finally { System.Threading.Monitor.Exit(gate); } }
// One window of this process: a visible top-level window (no owner) not seen before is sized and centered once.
static bool Each(System.IntPtr hw, System.IntPtr l) {
  if (one && left <= 0) { return false; }   // signInOnly: a window is sized already (also on the other threads of this tick)
  long k = hw.ToInt64(); if (seen.Contains(k) || !IsWindowVisible(hw) || GetWindow(hw, 4) != System.IntPtr.Zero) { return true; }
  seen.Add(k);
  int dpi = 96; try { dpi = (int)GetDpiForWindow(hw); } catch { } if (dpi <= 0) { dpi = 96; }
  int cw = w * dpi / 96, ch = h * dpi / 96;
  MonInfo mi = new MonInfo(); mi.Size = System.Runtime.InteropServices.Marshal.SizeOf(typeof(MonInfo));
  if (!GetMonitorInfo(MonitorFromWindow(hw, 2), ref mi)) { return true; }
  int x = mi.WL + System.Math.Max(0, (mi.WR - mi.WL - cw) / 2), y = mi.WT + System.Math.Max(0, (mi.WB - mi.WT - ch) / 2);
  SetWindowPos(hw, System.IntPtr.Zero, x, y, cw, ch, 0x0004 | 0x0010 | 0x4000);   // no Z order change, no activate, async
  if (one) { left = 0; return false; }   // signInOnly: one window only; the next tick ends the watch
  return true; }
"@
    }
    [RadeSignIn.Size2]::Start($SignInW, $SignInH, $SignInWatchMs, $SignInTickMs, [bool]$SignInOnly)
  } catch { $null = $_ }   # no helper: the sign-in window keeps its own size
}
# ---- RADE sign-in window size (end)
'@
# Gives a child script's text with the sign-in window size block in place of its marker line. Takes the text; gives back the text.
function Add-SignInSize([string]$Text) { return $Text.Replace('# <RADE sign-in window size>', $signInSize.TrimEnd()) }
$rightsScript = @'
param([string]$Site, [string]$MarkerList = '', [string]$MarkerKey = '', [string]$MarkerField = '')
# <RADE sign-in window size>
# RADE check (read-only): signs in with the CAC (web login, as T16 does) and prints your rights on the site, whether your
# own account is a site collection administrator (one flag; no list of administrators) and, when the app keeps an install
# record on the site, the version in that one row. Prints only right names, True/False and a version, never the site,
# your name or an error message.
try {
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { 'RESULT no-pnp'; exit 3 }
  $pin = @($mod | Where-Object { [string]$_.Version -eq '1.12.0' }); if ($pin.Count) { $mod = $pin }   # the tested version first (2.x needs PowerShell 7)
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Start-SignInSize   # E3: the CAC sign-in window opens at about 480 x 360, centered (the block above)
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
$rightsScript = Add-SignInSize $rightsScript
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
# <RADE sign-in window size>
# RADE (one write): signs in with the CAC and sets one row of the app's own list to the installed version and the date.
# Adds the row when it is missing; changes nothing else. Prints one RESULT word, never the site, a name or an error message.
try {
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { 'RESULT no-pnp'; exit 3 }
  $pin = @($mod | Where-Object { [string]$_.Version -eq '1.12.0' }); if ($pin.Count) { $mod = $pin }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  Start-SignInSize   # E3: the CAC sign-in window opens at about 480 x 360, centered (the block above)
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
$markerScript = Add-SignInSize $markerScript
