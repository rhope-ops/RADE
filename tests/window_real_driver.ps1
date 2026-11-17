# The test "user" for the REAL RADE window (tests/window_real.py; the Windows job .github/workflows/window.yml).
# It is put in front of a test copy of a bundle and runs on Windows PowerShell 5.1 with the real Windows Forms types
# (tests/window_driver.ps1 is the same idea for the stand-in types on Linux). A timer answers each card: it prints one
# "WIN" line, saves one PNG of the window, prints the lines of the engine's layout self-check, then selects a button.
# Set by the harness: RADE_T_OUT (folder for the PNG files), RADE_T_APP (index of the application), RADE_T_HAND (done or
# fail), RADE_T_TOUR (1 = the application also gets the site, sign-in and Power Automate checks), RADE_T_SIZE
# ("811x469" = the window is set to this size: 1280 x 800 at 150 % scaling, in 100 % pixels; empty = as the engine sets it).
# A check that cannot pass on the test computer is set to PASSED after its card has shown (the test is of the window).
# The hand step's questions (manifest "answers"): one picture per kind (NN-answer-yesno, NN-answer-pick, NN-answer-text),
# for the owner's approval of the look (the long-text run draws a first sentence that shrinks in the smallest window);
# the driver selects the first button (a text gets a short fake note).
Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
$env:RADE_LAYOUT = '1'   # the layout self-check runs for a deploy too
function Start-Process { param($FilePath, $ArgumentList) Write-Host ('WIN start-process ' + $(if ([string]$FilePath -match '^https://') { 'browser' } else { [string]$FilePath })) }
$global:RadeT = @{ Seen = ''; N = 0; Out = [string]$env:RADE_T_OUT; App = [int]$env:RADE_T_APP; Hand = [string]$env:RADE_T_HAND; Tour = ($env:RADE_T_TOUR -eq '1'); Size = [string]$env:RADE_T_SIZE
  Forced = $false; Opened = $false; Lay = 0; SignIn = $false; Sized = $false; T0 = (Get-Date); Env = $false }

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
  if ($global:RadeT.Size -and -not $global:RadeT.Sized) { $global:RadeT.Sized = $true; $wh = $global:RadeT.Size -split 'x'; $ui.Form.WindowState = 'Normal'; $ui.Form.MinimumSize = New-Object System.Drawing.Size(0, 0); $ui.Form.Size = New-Object System.Drawing.Size([int]$wh[0], [int]$wh[1]); $ui.Form.Location = New-Object System.Drawing.Point(0, 0) }
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
    $ui.B[0].PerformClick()
  }
  elseif ($v -eq 'hand') {
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
