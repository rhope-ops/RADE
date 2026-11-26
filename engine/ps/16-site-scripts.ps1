# RADE engine part 16, the site scripts of the checks (moved out of engine/ps/07-checks.ps1 to keep each file at 450
# lines or fewer; fleet v2 DEC 6): the sign-in window size block ($signInSize, Add-SignInSize), the rights check script
# ($rightsScript), Invoke-ChildScript (moved from part 07 in engine-v42), and the install record on the site
# (Get-MarkerArg, Get-SiteMark, Test-InstalledHere, Test-FirstInstall, $markerScript). Part 07 runs them (Invoke-Check,
# Write-SiteMarker); parts 13 and 14 use Add-SignInSize when they load, so this part comes right after part 07.
# Network: none when it loads; the child scripts it holds sign in to the saved site on the DAF SharePoint host (PnP).
# Writes: none when it loads; Invoke-ChildScript writes each child script to the temp folder and deletes it at the end;
# $markerScript writes the install record (one row of the app's own list on the site).
# Credentials: the interactive CAC sign-in of PnP (-UseWebLogin), in the child scripts.
# Joined into every bundle by engine/rade_build.py, right after part 07; Windows PowerShell 5.1.

<#
.SYNOPSIS
Runs an embedded child script as a child powershell.exe, the way steps run, and gives back its exit code and output lines.
.DESCRIPTION
No -ExecutionPolicy setting (fleet v2, DEC 3: Group Policy governs). The script is written to the Windows temp folder and
deleted at the end. With StageSeconds (R44 E4), RADE reads the output while the child runs: a line "STAGE <name>" starts a
stage, a stage that runs longer than StageSeconds stops the child (Stage then names it), and "STAGE none" ends the timed
stage. Without it, the output is read at the end (the test child of the policy check).
.PARAMETER Text
The script text.
.PARAMETER ArgText
The arguments after the script path.
.PARAMETER Seconds
The time limit of the whole child.
.PARAMETER Tick
A script block called about every 30 ms while the child runs (the window stays live), or $null.
.PARAMETER StageSeconds
The time limit of one stage, or 0 for no stage limit.
.OUTPUTS
@{ Exit; Lines; Why; Stage }: Stage is the stage that was stopped, or ''.
#>
function Invoke-ChildScript([string]$Text, [string]$ArgText, [int]$Seconds, [scriptblock]$Tick, [int]$StageSeconds = 0) {
  $exe = 'powershell.exe'
  if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { $exe = 'pwsh' }
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('@@PREFIX@@-check-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.ps1')
  $res = @{ Exit = -1; Lines = @(); Why = ''; Stage = '' }
  try {
    [System.IO.File]::WriteAllText($tmp, $Text, (New-Object System.Text.UTF8Encoding $true))
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = '-NoProfile -File "' + $tmp + '"' + $(if ($ArgText) { ' ' + $ArgText } else { '' })
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    # A PowerShell started with -ExecutionPolicy hands that setting to its child processes in this variable (an old RADE
    # shortcut sets "Bypass"): take only that value out, as Get-StepStartInfo does, else a check would say "ran" where a
    # step cannot. Any other value a person set stays.
    if ($psi.EnvironmentVariables['PSExecutionPolicyPreference'] -ceq 'Bypass') { $psi.EnvironmentVariables.Remove('PSExecutionPolicyPreference') }
    $p = [System.Diagnostics.Process]::Start($psi)
    $script:child = $p   # Exit stops a check too (review R17)
    $errTask = $p.StandardError.ReadToEndAsync(); $got = New-Object System.Collections.Generic.List[string]
    $outTask = $null; $rd = $null
    if ($StageSeconds -gt 0) { $rd = $p.StandardOutput.ReadLineAsync() } else { $outTask = $p.StandardOutput.ReadToEndAsync() }
    $deadline = (Get-Date).AddSeconds($Seconds); $stage = ''; $stageEnd = [datetime]::MaxValue
    while ($true) {
      while ($rd -and $rd.IsCompleted) {   # the lines that are there now; a STAGE line starts a stage and its time limit
        $l = $rd.Result; if ($null -eq $l) { $rd = $null; break }
        $got.Add($l); if ($l -match '^STAGE (.+)$') { $stage = $Matches[1].Trim(); $stageEnd = (Get-Date).AddSeconds($StageSeconds)
          if ($stage -eq 'none') { $stage = '' } }   # "STAGE none": no stage runs (engine-v43)
        $rd = $p.StandardOutput.ReadLineAsync() }
      if ($p.WaitForExit(30)) { break }
      if ($Tick) { & $Tick }
      if ((Get-Date) -gt $deadline) { try { $p.Kill() } catch { $null = $_ }; $res.Why = 'it ran longer than ' + $Seconds + ' seconds'; break }
      if ($stage -and (Get-Date) -gt $stageEnd) { try { $p.Kill() } catch { $null = $_ }   # it ended already
        $res.Stage = $stage; $res.Why = 'its stage "' + $stage + '" ran longer than ' + $StageSeconds + ' seconds'; break }
    }
    $p.WaitForExit()
    while ($rd) { $l = $rd.Result; if ($null -eq $l) { break }; $got.Add($l); $rd = $p.StandardOutput.ReadLineAsync() }   # the last lines after the end
    $res.Exit = $p.ExitCode
    $all = $(if ($outTask) { @(([string]$outTask.Result) -split "`r?`n") } else { @($got) })
    $res.Lines = @($all | Where-Object { $_ })
    if (-not $res.Why -and ([string]$errTask.Result).Trim()) { $res.Why = 'it wrote error output' }
  } catch { $res.Why = $_.Exception.GetType().Name }
  finally { $script:child = $null; try { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force } } catch { $null = $_ } }
  return $res
}
# engine-v43 S1 (the PFM, 2026-11-26): the time limit of the sign-in stage of the rights, install record and Restore children
# (Back up keeps its own stage limit, $toolStageSeconds). A frozen sign-in then ends with its stage named: no force close.
$signInStageSeconds = 180
<#
.SYNOPSIS
Puts the sign-in lines of a child (SIGNIN, SIGNIN-WIN) into the run log with RADE's host, and gives the short note.
.DESCRIPTION
engine-v43 S2, S3: each line goes to the run log as "<name> <line> host=<host>" ($env:RADE_HOST: ise, child, shortcut or
console; set by part 09). The note is the SIGNIN line with the host, else (a sign-in that did not finish) the last
SIGNIN-WIN line with the host, else ''.
.PARAMETER Name
The child's name in the log (for example "Rights check").
.PARAMETER Lines
The child's output lines.
.OUTPUTS
The note, or ''.
#>
function Get-SignInNote([string]$Name, [object[]]$Lines) {
  $hostTag = ' host=' + $(if ($env:RADE_HOST) { $env:RADE_HOST } else { 'unknown' })
  $s = @($Lines | Where-Object { [string]$_ -match '^SIGNIN(-WIN)? ' })
  foreach ($l in $s) { Add-RunLog ($Name + ' ' + $l + $hostTag) }
  $done = @($s | Where-Object { [string]$_ -match '^SIGNIN seconds=' } | Select-Object -First 1)
  if ($done.Count) { return ([string]$done[0] + $hostTag) }
  if ($s.Count) { return ([string]$s[-1] + $hostTag) }
  return ''
}
# Gives the words for a stage of the Back up child ("signin", "site", "list <n>"). Takes the stage and the list titles.
function Get-StageText([string]$Stage, [object[]]$Lists) {
  if ($Stage -eq 'signin') { return 'the sign-in' }
  if ($Stage -eq 'site') { return 'the site check' }
  if ($Stage -match '^list (\d+)$' -and [int]$Matches[1] -ge 1 -and [int]$Matches[1] -le @($Lists).Count) { return ('the read of the list "' + [string]$Lists[[int]$Matches[1] - 1] + '"') }
  return ('the stage "' + $Stage + '"')
}
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
# Such a script also calls Stop-SignInSize when Connect-PnPOnline returns (in a finally block): a sign-in that showed no
# window then leaves no watch behind that could size the script's own next window.
# Windows PowerShell 5.1, no module. When the helper cannot be compiled (Constrained Language Mode) or the calls fail,
# nothing changes and the sign-in goes on as before.
$SignInW = 480; $SignInH = 360; $SignInWatchMs = 120000; $SignInTickMs = 100
function Start-SignInSize {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
  param([switch]$SignInOnly)
  $script:signInWatchOn = $false   # R43 E4: $true only when the watch really started (the SIGNIN line reports it)
  if (-not $PSCmdlet.ShouldProcess('the sign-in window of this process', 'Set its size')) { return }   # -WhatIf: no timer
  if ($env:RADE_SIGNIN_WATCH -eq '0') { return }   # R43 E4 (the PFM, 2026-11-25): the timed pair; RADE_SIGNIN_WATCH=0 turns the watch off
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
  Stop();   // a watch that still runs from an earlier call ends first
  lock (gate) { w = width; h = height; one = signInOnly; left = System.Math.Max(1, watchMs / System.Math.Max(1, tickMs));
    if (one) { using (System.Diagnostics.Process me = System.Diagnostics.Process.GetCurrentProcess()) {
      foreach (System.Diagnostics.ProcessThread t in me.Threads) { EnumThreadWindows((uint)t.Id, mark, System.IntPtr.Zero); } } }
    timer = new System.Threading.Timer(Tick, null, tickMs, tickMs); } }
// Ends the watch now (no more ticks). Safe to call when no watch runs.
public static void Stop() { lock (gate) { left = 0; if (timer != null) { timer.Dispose(); timer = null; } } }
// Marks one window that exists at the start (signInOnly): it is never sized.
static bool Mark(System.IntPtr hw, System.IntPtr l) { seen.Add(hw.ToInt64()); return true; }
// One tick: a tick that starts while the last one still runs is skipped (the timer can overlap), so seen has one writer.
static void Tick(object state) {
  if (!System.Threading.Monitor.TryEnter(gate)) { return; }
  try { if (--left < 0) { if (timer != null) { timer.Dispose(); timer = null; } return; }
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
    [RadeSignIn.Size2]::Start($SignInW, $SignInH, $SignInWatchMs, $SignInTickMs, [bool]$SignInOnly); $script:signInWatchOn = $true
  } catch { $null = $_ }   # no helper: the sign-in window keeps its own size
}
function Stop-SignInSize {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
  param()
  if (-not $PSCmdlet.ShouldProcess('the sign-in window watch of this process', 'Stop')) { return }
  try { if ('RadeSignIn.Size2' -as [type]) { [RadeSignIn.Size2]::Stop() } } catch { $null = $_ }   # no watch: nothing to stop
}
# engine-v43 S2 (the PFM, 2026-11-26: R44 r1 froze at the sign-in with no data): while Connect-PnPOnline runs, a
# background timer reads the windows of THIS process only, about every second, and prints one line at each change:
# "SIGNIN-WIN t=<seconds> windows=<visible> owned=<visible with an owner> min=<minimized> size=<largest WxH>
# hung=<not responding> front=<1 when the foreground window is one of them>". No title, no text, no other process.
# The parent reads the lines while the child runs (Invoke-ChildScript -StageSeconds), so a frozen sign-in still reports.
function Start-SignInReport {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
  param()
  if (-not $PSCmdlet.ShouldProcess('the windows of this process', 'Report their state')) { return }   # -WhatIf: no timer
  if ($env:OS -ne 'Windows_NT' -and $env:RADE_SIGNIN_TEST -ne '1') { return }   # Windows only (the cloud test compiles it)
  try {
    if (-not ('RadeSignIn.Report1' -as [type])) {
      Add-Type -Namespace RadeSignIn -Name Report1 -ErrorAction Stop -MemberDefinition @"
public delegate bool WinProc(System.IntPtr h, System.IntPtr l);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool EnumThreadWindows(uint tid, WinProc f, System.IntPtr l);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool IsWindowVisible(System.IntPtr h);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool IsIconic(System.IntPtr h);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool IsHungAppWindow(System.IntPtr h);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern System.IntPtr GetWindow(System.IntPtr h, uint cmd);
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern System.IntPtr GetForegroundWindow();
[System.Runtime.InteropServices.DllImport("user32.dll")] static extern bool GetWindowRect(System.IntPtr h, out Rect r);
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct Rect { public int L, T, R, B; }
static System.Threading.Timer timer; static object gate = new object(); static System.DateTime t0; static string last = "";
static int n, owned, mins, hung, front, bw, bh; static long fg; static WinProc each = Each;
// Starts the report: one look now, then one every tickMs, until End. The timer starts outside the lock, so the first look runs.
public static void Begin(int tickMs) { End(false); lock (gate) { t0 = System.DateTime.Now; last = ""; }
  System.Threading.Timer tm = new System.Threading.Timer(Tick, null, System.Threading.Timeout.Infinite, System.Threading.Timeout.Infinite);
  lock (gate) { timer = tm; } tm.Change(0, tickMs); }
// Ends the report: waits until no tick runs, then, with final, prints one last line (the state at the end).
public static void End(bool final) {
  System.Threading.Timer tm; lock (gate) { tm = timer; timer = null; }
  // The event is closed only when the last tick has ended: a tick that runs past 2 s signals it later, and a closed event
  // would then end this process (review of PR 201). In that rare case the event stays open until the process ends.
  if (tm != null) { System.Threading.ManualResetEvent done = new System.Threading.ManualResetEvent(false); if (!tm.Dispose(done) || done.WaitOne(2000)) { done.Dispose(); } }
  if (final) { lock (gate) { Look(true); } } }
// One timer tick: a tick that starts while another look runs is skipped; a tick after End prints nothing.
static void Tick(object state) {
  if (!System.Threading.Monitor.TryEnter(gate)) { return; }
  try { if (timer != null) { Look(false); } } finally { System.Threading.Monitor.Exit(gate); } }
// Reads the windows of this process and prints a line when the state changed since the last line, or when force is set.
// The caller holds gate.
static void Look(bool force) {
  try { n = 0; owned = 0; mins = 0; hung = 0; front = 0; bw = 0; bh = 0; fg = GetForegroundWindow().ToInt64();
    using (System.Diagnostics.Process me = System.Diagnostics.Process.GetCurrentProcess()) {
      foreach (System.Diagnostics.ProcessThread t in me.Threads) { EnumThreadWindows((uint)t.Id, each, System.IntPtr.Zero); } }
    string s = "windows=" + n + " owned=" + owned + " min=" + mins + " size=" + bw + "x" + bh + " hung=" + hung + " front=" + front;
    if (s != last || force) { last = s; System.Console.Out.WriteLine("SIGNIN-WIN t=" + (int)(System.DateTime.Now - t0).TotalSeconds + " " + s); System.Console.Out.Flush(); } }
  catch { } }
static bool Each(System.IntPtr hw, System.IntPtr l) {
  if (!IsWindowVisible(hw)) { return true; }
  n++; if (GetWindow(hw, 4) != System.IntPtr.Zero) { owned++; } if (IsIconic(hw)) { mins++; } if (IsHungAppWindow(hw)) { hung++; } if (hw.ToInt64() == fg) { front = 1; }
  Rect r; if (GetWindowRect(hw, out r) && (r.R - r.L) * (r.B - r.T) > bw * bh) { bw = r.R - r.L; bh = r.B - r.T; }
  return true; }
"@
    }
    [RadeSignIn.Report1]::Begin(1000)
  } catch { $null = $_ }   # no helper: the sign-in goes on without the report
}
function Stop-SignInReport {
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'None')]
  param()
  if (-not $PSCmdlet.ShouldProcess('the window report of this process', 'Stop')) { return }
  try { if ('RadeSignIn.Report1' -as [type]) { [RadeSignIn.Report1]::End($true) } } catch { $null = $_ }   # no report: nothing to stop
}
# engine-v43 S1: the one sign-in of a child script. Prints "STAGE signin" (the parent stops a stage that runs too long),
# signs in with the CAC (PnP web login), prints "SIGNIN seconds=<n> watch=<on|off>" and "STAGE none" (no stage runs).
# Throws when the sign-in fails, as Connect-PnPOnline does. Takes the site address.
function Connect-RadeSite([string]$Site) {
  'STAGE signin'
  $t0 = Get-Date; Start-SignInReport; Start-SignInSize   # E3: the CAC sign-in window opens at about 480 x 360, centered
  try { $null = & { Connect-PnPOnline -Url $Site -UseWebLogin -ErrorAction Stop } *>&1 }
  finally { Stop-SignInSize; Stop-SignInReport }   # R44 E4: no watch after the sign-in
  'SIGNIN seconds=' + [int]((Get-Date) - $t0).TotalSeconds + ' watch=' + $(if ($script:signInWatchOn) { 'on' } else { 'off' })   # what happened, not what was asked
  'STAGE none'
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
  Connect-RadeSite $Site   # engine-v43 S1: STAGE, SIGNIN and SIGNIN-WIN lines (the block above)
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
  Connect-RadeSite $Site   # engine-v43 S1: STAGE, SIGNIN and SIGNIN-WIN lines (the block above)
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
