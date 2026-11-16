# The test "user" for the REAL RADE window (tests/window_real.py; the Windows job .github/workflows/window.yml).
# It is put in front of a test copy of a bundle and runs on Windows PowerShell 5.1 with the real Windows Forms types
# (tests/window_driver.ps1 is the same idea for the stand-in types on Linux). A timer answers each card: it prints one
# "WIN" line, saves one PNG of the window, prints the lines of the engine's layout self-check, then selects a button.
# Set by the harness: RADE_T_OUT (folder for the PNG files), RADE_T_APP (index of the application), RADE_T_HAND (done or
# fail), RADE_T_TOUR (1 = the application also gets the site, sign-in and Power Automate checks), RADE_T_SIZE
# ("811x469" = the window is set to this size: 1280 x 800 at 150 % scaling, in 100 % pixels; empty = as the engine sets it).
# A check that cannot pass on the test computer is set to PASSED after its card has shown (the test is of the window).
# The hand step's questions (manifest "answers"): one picture per kind (NN-answer-yesno, NN-answer-pick, NN-answer-text),
# RADE_T_PROBE (1 = on the Ready card and on the first hand step of a run, minimize and restore the window: Test-RadeRestore).
# for the owner's approval of the look (the long-text run draws a first sentence that shrinks in the smallest window);
# the driver selects the first button (a text gets a short fake note).
Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
$env:RADE_LAYOUT = '1'   # the layout self-check runs for a deploy too
function Start-Process { param($FilePath, $ArgumentList) Write-Host ('WIN start-process ' + $(if ([string]$FilePath -match '^https://') { 'browser' } else { [string]$FilePath })) }
$global:RadeT = @{ Seen = ''; N = 0; Out = [string]$env:RADE_T_OUT; App = [int]$env:RADE_T_APP; Hand = [string]$env:RADE_T_HAND; Tour = ($env:RADE_T_TOUR -eq '1'); Size = [string]$env:RADE_T_SIZE
  Forced = $false; Opened = $false; Probe = ($env:RADE_T_PROBE -eq '1'); Lay = 0; SignIn = $false; Sized = $false; T0 = (Get-Date); Env = $false }

# RADE_T_LOG (the ISE run: the ISE host has no standard output): every Write-Host line also goes to this file.
if ($env:RADE_T_LOG) { function global:Write-Host { param([Parameter(Position = 0)]$Object, $ForegroundColor, $BackgroundColor, [switch]$NoNewline) [System.IO.File]::AppendAllText([string]$env:RADE_T_LOG, ([string]$Object) + "`r`n") } }
# Minimize and restore with the messages Windows sends for the title bar and the taskbar button (WM_SYSCOMMAND with
# SC_MINIMIZE, SC_RESTORE, SC_MAXIMIZE), not with the WindowState property (R25: a click on the taskbar button did not
# bring the window back). "WIN probe" lines give the facts (numbers only); "WIN restore ... ok=" the verdict.
Add-Type -Namespace RadeT -Name Win -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
[DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint c);
[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
'@
function global:Test-RadeRestore([string]$Where) {
  $f = $ui.Form; $h = $f.Handle; $b0 = $f.Bounds
  $r = { param($b) [string]$b.Width + 'x' + $b.Height + '@' + $b.X + ',' + $b.Y }
  $pump = { param([int]$Ms) $sw = [System.Diagnostics.Stopwatch]::StartNew(); while ($sw.ElapsedMilliseconds -lt $Ms) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 15 } }
  $say = { param([string]$T) Write-Host ('WIN probe ' + $Where + ' ' + $T + ' state=' + $f.WindowState + ' iconic=' + [RadeT.Win]::IsIconic($h) + ' bounds=' + (& $r $f.Bounds) + ' restore=' + (& $r $f.RestoreBounds) + ' owned=' + ([RadeT.Win]::GetWindow($h, 4) -ne [IntPtr]::Zero) + ' enabled=' + [RadeT.Win]::IsWindowEnabled($h) + ' exstyle=0x' + ([RadeT.Win]::GetWindowLong($h, -20)).ToString('X') + ' topmost=' + $f.TopMost + ' foreground=' + [object]::ReferenceEquals([System.Windows.Forms.Form]::ActiveForm, $f) + ' card=' + $ui.Card.Width + 'x' + $ui.Card.Height) }
  $cmd = { param([int]$C, [int]$Ms) [void][RadeT.Win]::PostMessage($h, 0x112, [IntPtr]$C, [IntPtr]::Zero); & $pump $Ms }
  & $say 'start'
  & $cmd 0xF020 1500; & $say 'minimized'; $min = [RadeT.Win]::IsIconic($h)   # 1.5 s: the engine's repair leaves a window alone that the person minimized
  & $cmd 0xF120 600; & $say 'restored'; $ok1 = ($min -and [string]$f.WindowState -eq 'Normal' -and -not [RadeT.Win]::IsIconic($h) -and $f.Bounds -eq $b0)
  & $cmd 0xF030 400; & $cmd 0xF020 400; & $say 'max-minimized'
  & $cmd 0xF120 600; & $say 'max-restored'; $ok2 = ([string]$f.WindowState -eq 'Maximized' -and -not [RadeT.Win]::IsIconic($h))
  & $cmd 0xF120 600; & $say 'normal-again'; $ok3 = ([string]$f.WindowState -eq 'Normal' -and $f.Bounds -eq $b0)
  # The engine's repair (a): the minimized window is made the foreground window, as a click on its taskbar button does, but
  # with no restore (SetForegroundWindow leaves a window minimized). The engine must show it within about a second. Where
  # Windows does not give the foreground to it (no other window had it, or the session forbids it), the case cannot be made: "n/a".
  & $cmd 0xF020 700; $away = -not [object]::ReferenceEquals([System.Windows.Forms.Form]::ActiveForm, $f); [void][RadeT.Win]::SetForegroundWindow($h); & $pump 300
  $fg = ([RadeT.Win]::IsIconic($h) -and [object]::ReferenceEquals([System.Windows.Forms.Form]::ActiveForm, $f)); & $say 'selected'; & $pump 1500; & $say 'repaired'
  $rep = $(if (-not ($away -and $fg)) { 'n/a' } else { [string]([string]$f.WindowState -eq 'Normal' -and -not [RadeT.Win]::IsIconic($h) -and $f.Bounds -eq $b0) })
  if ([RadeT.Win]::IsIconic($h)) { & $cmd 0xF120 600 }
  Write-Host ('WIN ' + (& $ui.WLine))
  Write-Host ('WIN restore ' + $Where + ' ok=' + ($ok1 -and $ok2 -and $ok3 -and $rep -ne 'False') + ' normal=' + $ok1 + ' maximized=' + $ok2 + ' back=' + $ok3 + ' repair=' + $rep + ' host=' + $Host.Name + ' shown-by=' + $ui.ShownBy)
}
function global:Save-RadeCard([string]$Tag) {
  $global:RadeT.N++; $card = ('{0:00}-{1}' -f $global:RadeT.N, $Tag)
  try { $ui.Form.Refresh() } catch { $null = $_ }
  $bs = @($ui.B | Where-Object { $_.Visible } | ForEach-Object { $(if ($_.Enabled) { '[' } else { '(' }) + $_.Text + $(if ($_.Enabled) { ']' } else { ')' }) }) -join ' '
  Write-Host ('WIN card=' + $card + ' view=' + $ui.View + ' kick=' + $ui.Kick.Text + ' sent=' + $ui.Sent.Text + ' p=' + (@($ui.P | Where-Object { $_.Visible } | ForEach-Object { $_.Text }) -join ' / ') + ' btn=' + $bs + ' form=' + $ui.Form.Width + 'x' + $ui.Form.Height + ' client=' + $ui.Form.ClientSize.Width + 'x' + $ui.Form.ClientSize.Height + ' cardw=' + $ui.ContentW)
  try {
    $bmp = New-Object System.Drawing.Bitmap($ui.Form.Width, $ui.Form.Height)
    $ui.Form.DrawToBitmap($bmp, (New-Object System.Drawing.Rectangle(0, 0, $ui.Form.Width, $ui.Form.Height)))
    if ($global:RadeT.Out) { $bmp.Save((Join-Path $global:RadeT.Out ($card + '.png')), [System.Drawing.Imaging.ImageFormat]::Png) }
    # A picture that is all one color means the window was not drawn: count the colors on a grid.
    $all = @{}; for ($yy = 0; $yy -lt $bmp.Height; $yy += 9) { for ($xx = 0; $xx -lt $bmp.Width; $xx += 9) { $all[$bmp.GetPixel($xx, $yy).ToArgb()] = 1 } }
    Write-Host ('WIN png=' + $card + ' colors=' + $all.Count)
    $bmp.Dispose()
  } catch { Write-Host ('WIN PNG-FAILED ' + $card + ' ' + $_.Exception.Message) }
  # The engine's own layout self-check ($ui.Check) measures the card; this prints what it added.
  & $ui.Check
  for ($i = $global:RadeT.Lay; $i -lt $ui.LayBad.Count; $i++) { Write-Host $ui.LayBad[$i] }
  $global:RadeT.Lay = $ui.LayBad.Count
  if ($ui.Scrolls -and -not $ui.RecOn) { Write-Host ('WIN scrolls ' + $card) }
}
function global:Step-Rade {
  if (((Get-Date) - $global:RadeT.T0).TotalSeconds -gt 240) { Write-Host ('WIN TIMEOUT view=' + $ui.View + ' sent=' + $ui.Sent.Text); [Environment]::Exit(3) }
  if (-not $ui -or -not $ui.Form -or $ui.Form.IsDisposed -or -not $ui.Form.Visible -or -not $ui.View) { return }
  if (-not $global:RadeT.Env) {
    $global:RadeT.Env = $true; $sc = [System.Windows.Forms.Screen]::PrimaryScreen
    Write-Host ('WINENV ps=' + $PSVersionTable.PSVersion + ' dpi=' + $ui.Dpi + ' screen=' + $sc.Bounds.Width + 'x' + $sc.Bounds.Height + ' working=' + $sc.WorkingArea.Width + 'x' + $sc.WorkingArea.Height + ' form=' + $ui.Form.Width + 'x' + $ui.Form.Height + ' interactive=' + [Environment]::UserInteractive)
    foreach ($k in @($ui.F.Keys | Sort-Object)) { $f = $ui.F[$k]; Write-Host ('MEASURE ' + $k + ' ' + $f.Name + ' ' + $f.SizeInPoints + ' ' + $f.Style + ' = ' + [System.Windows.Forms.TextRenderer]::MeasureText('The quick brown fox jumps over the lazy dog 0123456789', $f, (New-Object System.Drawing.Size(9999, 99)), [System.Windows.Forms.TextFormatFlags]'NoPadding, NoPrefix, SingleLine').Width + ' h=' + [System.Windows.Forms.TextRenderer]::MeasureText('Ag', $f).Height) }
  }
  if ($ui.GuardMs) { $ui.GuardMs = 0 }   # the test user acts at once, as if it had waited 400 ms (tests/engine_test.sh tests the guard)
  if ($global:RadeT.Size -and -not $global:RadeT.Sized) { $global:RadeT.Sized = $true; $wh = $global:RadeT.Size -split 'x'; $ui.Form.Size = New-Object System.Drawing.Size([int]$wh[0], [int]$wh[1]); $ui.Form.Location = New-Object System.Drawing.Point(0, 0) }
  $key = [string]$ui.View + '|' + $ui.Sent.Text + '|' + $ui.Kick.Text
  if ($key -eq $global:RadeT.Seen) { return }
  $global:RadeT.Seen = $key
  $v = [string]$ui.View
  $tag = $v; if ($v -eq 'answer') { $tag = 'answer-' + $(if ($ui.FieldRow.Visible) { 'text' } elseif ($ui.B[0].Text -eq 'Yes') { 'yesno' } else { 'pick' }) }
  Save-RadeCard $tag
  if ($v -eq 'choose') {
    if ($ui.Blocked.Count -and -not $global:RadeT.Forced) {
      $global:RadeT.Forced = $true; Write-Host ('WIN blocked=' + $ui.Blocked.Count)
      foreach ($id in @($ui.BaseRes.Keys)) { if ($ui.BaseRes[$id].State -eq 'FAILED') { $ui.BaseRes[$id] = @{ State = 'PASSED'; Detail = 'Set by the test'; Fix = '' } } }
      $ui.Blocked = @{}; & $ui.VChoose; Save-RadeCard 'choose-all'
    }
    if ($global:RadeT.Tour) { $global:RadeT.Tour = $false; $apps[$global:RadeT.App].Checks = @($apps[$global:RadeT.App].Checks) + @('net-site', 'site-rights', 'flow-guide') }
    foreach ($o in @($ui.Opts.Controls)) { if (-not $o.Tag.Off -and [int]$o.Tag.Index -eq $global:RadeT.App) { $o.PerformClick(); return } }
    Write-Host 'WIN BAD no choice for the application'; [Environment]::Exit(4)
  }
  elseif ($v -eq 'maint') { $ui.B[0].PerformClick() }
  elseif ($v -eq 'site') { $ui.Field.Text = 'https://rade-test.invalid/sites/fake'; $ui.B[0].PerformClick() }
  elseif ($v -in 'fail', 'need') {
    $id = [string]@($script:appChecks)[([int]($ui.Kick.Text -replace '^CHECK (\d+) OF .*$', '$1')) - 1]
    if ($v -eq 'need' -and (Get-CheckDef $id).Kind -eq 'guide') { $ui.B[0].PerformClick(); return }
    if ($v -eq 'need' -and (Get-CheckDef $id).Kind -eq 'signin' -and -not $global:RadeT.SignIn) {
      $global:RadeT.SignIn = $true; $script:checkResults[$id] = @{ State = 'FAILED'; Detail = 'Sign-in was not finished'; Fix = 'Select "Sign in and check site rights"' }; & $ui.Next; return
    }
    $script:checkResults[$id] = @{ State = 'PASSED'; Detail = 'Set by the test'; Fix = '' }
    & $ui.Next
  }
  elseif ($v -eq 'ready') {
    if (-not $global:RadeT.Opened) { $global:RadeT.Opened = $true; & $ui.VRecord; Save-RadeCard 'record'; & $ui.CloseRecord }
    if ($global:RadeT.Probe -and -not $global:RadeT.Probed1) { $global:RadeT.Probed1 = $true; Test-RadeRestore 'ready' }   # the window waits in its own message loop
    $ui.B[0].PerformClick()
  }
  elseif ($v -eq 'hand') {
    if ($global:RadeT.Probe -and -not $global:RadeT.Probed2 -and $ui.Running) { $global:RadeT.Probed2 = $true; Test-RadeRestore 'hand' }   # the window waits for an answer inside a run (the R25 case)
    if ($ui.B[1].Text -ne 'It failed') { $ui.B[0].PerformClick() }
    elseif ($global:RadeT.Hand -eq 'fail') { $ui.B[1].PerformClick() } else { $ui.B[0].PerformClick() }
  }
  elseif ($v -eq 'answer') {
    if ($ui.FieldRow.Visible) { $ui.Field.Text = 'Sample note' }
    $ui.B[0].PerformClick() }
  elseif ($v -eq 'handfail') { $ui.ErrBox.Text = 'Import failed: flow https://usaf.dps.mil/sites/fake/x not found'; $ui.B[0].PerformClick() }
  elseif ($v -in 'done', 'review', 'stopped') {
    foreach ($l in @($ui.Log)) { if ([string]$l -match 'failed|FAILED|STOPPED|could not') { Write-Host ('WIN log ' + ([string]$l).Trim()) } }
    & $ui.VRecord; Save-RadeCard ($v + '-record'); & $ui.CloseRecord
    $ll = @((& $ui.LayLine) -split "`r`n"); Write-Host ('WIN line ' + $ll[0]); foreach ($l in $ll) { if ($l -like 'SCALE *') { Write-Host ('WIN ' + $l) } }   # the scaling facts (numbers only)
    Write-Host 'WIN closed=True'; $ui.Form.Close()
  }
}
$global:RadeTimer = New-Object System.Windows.Forms.Timer
$global:RadeTimer.Interval = 150
# A tick can run inside another tick's click (the engine pumps messages while a step runs): the card key stops a repeat.
$global:RadeTimer.Add_Tick({ try { Step-Rade } catch { Write-Host ('WIN DRIVER-ERROR ' + $_.Exception.Message + ' line ' + $_.InvocationInfo.ScriptLineNumber) } })
$global:RadeTimer.Start()
