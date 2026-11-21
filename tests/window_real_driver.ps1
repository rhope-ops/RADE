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
# the driver selects the first button (a text gets a short fake note). R31: the tour cards (each one), the step that shows only
# questions (the driver selects its answer that means a failure, then gives a fake error text) and the last card of a test round.
Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
$env:RADE_LAYOUT = '1'   # the layout self-check runs for a deploy too
function Start-Process { param($FilePath, $ArgumentList, $WorkingDirectory) Write-Host ('WIN start-process ' + $(if ([string]$FilePath -match '^https://') { 'browser' } else { [string]$FilePath })) }
$global:RadeT = @{ Seen = ''; N = 0; Out = [string]$env:RADE_T_OUT; App = [int]$env:RADE_T_APP; Hand = [string]$env:RADE_T_HAND; Tour = ($env:RADE_T_TOUR -eq '1'); Size = [string]$env:RADE_T_SIZE
  Forced = $false; Opened = $false; Lay = 0; SignIn = $false; Sized = $false; T0 = (Get-Date); Env = $false }

function global:Save-RadeRestore {
  <#
  .SYNOPSIS
  Draws the Restore cards once (engine-v31), from the Maintenance screen: the mark card (engine-v32) with a wrong and
  then the right site name, the backup list, the dry-run card, a wrong typed name and the result card.
  .DESCRIPTION
  Fake data: two backup folders of one list; the dry run and the result are set by the test (no SharePoint on the
  runner). The app's own Backup and Restore, its site file, the mark file and the backup folders are put back as they
  were after.
  Takes no parameter.
  #>
  if ($global:RadeT.Restored) { return }; $global:RadeT.Restored = $true
  $bp = Get-BasePath; $keep = @{ B = $script:app.Backup; R = $script:app.Restore }
  $cfg = Join-Path $bp 'Config'; $had = @(Get-ChildItem -LiteralPath $cfg -Filter '*-site.txt' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
  if (-not (Test-SiteUrl (Get-SiteUrl $bp))) { Save-SiteUrl $bp ($sitePrefix + 'fake') }   # taken out again below: the run goes on as before
  $nm = (Get-SiteUrl $bp).Substring($sitePrefix.Length).TrimEnd('/')
  $script:app.Backup = @('Sample Tasks', 'Sample Recs (Form 1)')
  $script:app.Restore = @{ TestSites = @(); Local = $true; Pause = @{ List = 'Sample Settings'; Title = 'RestorePause'; Field = 'SettingValue'; On = 'On' } }
  foreach ($d in '20261120-140000', '20261121-090000') { $f = Join-Path $bp ('Backups\' + $d); $null = New-Item -ItemType Directory -Path $f -Force
    Set-Content -LiteralPath (Join-Path $f 'Sample Tasks.json') -Value '[]' }
  $mk = Get-RestoreMarkFile $bp; $keepMark = $(if (Test-Path -LiteralPath $mk) { [System.IO.File]::ReadAllBytes($mk) } else { $null })
  if ($keepMark) { Remove-Item -LiteralPath $mk -Force }   # no mark, so the mark card shows; put back below
  & $ui.VRestorePick; Save-RadeCard 'restmark'
  $ui.Field.Text = 'not-the-site'; & $ui.RestoreMarkGo; Save-RadeCard 'restmark-wrongname'
  $ui.Field.Text = $nm.ToUpperInvariant(); & $ui.RestoreMarkGo
  Write-Host ('WIN restore-mark saved=' + ((Get-RestoreMark $bp) -eq $nm) + ' view=' + $ui.View)
  Save-RadeCard 'restpick'
  $ui.RestoreDir = Join-Path $bp 'Backups\20261121-090000'
  $ui.RestoreDry = @{ State = 'plan'; Missing = 3; Expect = '1:3'; Plan = @{}; Lines = @('Dry run: 3 rows would come back (1 from the Recycle Bin, 2 as new rows). Nothing was written.',
      '"Sample Tasks": 12 in the backup, 9 on the list now. Would put back 3 (1 from the Recycle Bin, 2 as new rows). 1 made after the backup stay.',
      'NOTE: "Sample Recs (Form 1)" is left out: this backup has no file for it') }
  & $ui.VRestoreConfirm; Save-RadeCard 'restconfirm'
  # The count lines are in the rich text box, which a picture cannot show (DrawToBitmap): log how many it holds.
  Write-Host ('WIN restore-lines ' + @(([string]$ui.Guide.Text) -split "`n" | Where-Object { $_.Trim() }).Count + ' visible=' + $ui.Guide.Visible)
  $ui.Field.Text = 'wrong name'; & $ui.RestoreGo; Save-RadeCard 'restconfirm-wrongname'
  & $ui.ToolResult 'Restore' @{ State = 'done'; Path = (Join-Path $bp 'Backups\20261121-091500'); Lines = @('Restore put back 3 of 3 rows. Rows on the lists were not changed.',
      'Fresh backup before Restore: Backups\20261121-091500', "The app's pause switch is back as it was.", 'PASS: "Sample Tasks": 1 back from the Recycle Bin, 2 made new; 12 rows on the list now') }
  Save-RadeCard 'toolres-restore'
  Get-ChildItem -LiteralPath $cfg -Filter '*-site.txt' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notin $had } | Remove-Item -Force
  if ($keepMark) { [System.IO.File]::WriteAllBytes($mk, $keepMark) } else { Remove-Item -LiteralPath $mk -Force -ErrorAction SilentlyContinue }
  Remove-Item -LiteralPath (Join-Path $bp 'Backups') -Recurse -Force; $script:app.Backup = $keep.B; $script:app.Restore = $keep.R
  & $ui.VTools $ui.MaintVerb }

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
  # R32: the wheel moves the text of a card that scrolls, from a control that has no scroll bar of its own (the headline).
  if ($ui.Scrolls -and -not $ui.RecOn) { try { $y0 = $ui.Scroll.AutoScrollPosition.Y; $ev = New-Object System.Windows.Forms.HandledMouseEventArgs('None', 0, 0, 0, -120)
      [System.Windows.Forms.Control].GetMethod('OnMouseWheel', [System.Reflection.BindingFlags]'NonPublic, Instance').Invoke($ui.Sent, [object[]]@($ev.PSObject.BaseObject))   # as Windows raises it on the headline: only the hook of $ui.WheelOn hands it on
      Write-Host ('WIN wheel ' + $card + ' moved=' + ($ui.Scroll.AutoScrollPosition.Y -ne $y0)); $ui.Scroll.AutoScrollPosition = New-Object System.Drawing.Point(0, 0) } catch { Write-Host ('WIN wheel ' + $card + ' error=' + $_.Exception.Message) } }
  # R32 measures (screen pixels, top/height): the bottom line's two texts, the header's widths, and on the Run card the step row.
  try { $sr = { param($C) $q = $C.RectangleToScreen($C.ClientRectangle); [string]$q.Top + '/' + $q.Height }
    $m = 'WIN r32 ' + $card + ' rec=' + (& $sr $ui.RecB) + ' right=' + (& $sr $ui.RightL) + ' word=' + $ui.WordL.Width + ' rule=' + $ui.HeadRule.Width + ' app=' + $ui.AppL.Width
    if ($ui.View -eq 'run') { $m += ' name=' + (& $sr $ui.StepName) + ' bar=' + (& $sr $ui.StepBar) + '/m' + $ui.StepBar.Margin.Top + ' time=' + (& $sr $ui.StepTime) + '/m' + $ui.StepTime.Margin.Top + '/pref' + $ui.StepTime.PreferredSize.Height + ' [' + $ui.StepTime.Text + '] now=' + (& $sr $ui.Now) + '/m' + $ui.Now.Margin.Top + '/' + $ui.Now.Visible + ' row=' + $ui.StepRow.Height + ' frac=' + (& $sr $ui.StepFrac) }
    Write-Host $m } catch { Write-Host ('WIN r32 ' + $card + ' error=' + $_.Exception.Message) }
}
# R31: answers the cards of the R31 brief. tour: each card (Next, then "Close the tour"); answer: the answer that means a
# failure when the card has one (so its error card is drawn), else the first button; answerfail: a fake error text;
# feedback: a fake note. Takes the view of the card.
function global:Step-RadeR31([string]$V) {
  if ($V -eq 'answerfail') { $ui.ErrBox.Text = 'The page said: error 42' } elseif ($V -eq 'feedback') { $ui.Field.Text = 'Sample feedback' }
  $fb = @($ui.B | Where-Object { $_.Visible -and $_.Text -like 'An error*' })[0]
  if ($V -eq 'answer' -and $fb) { $fb.PerformClick() } else { (Get-RadeMain).PerformClick() }
}
# The primary button of the card on screen (UI standard v1: the last one), or the first shown button when it has none.
function global:Get-RadeMain { $m = @($ui.B | Where-Object { $_.Visible -and [string]$ui.Kinds[$_] -eq 'primary' }); if ($m.Count) { return $m[0] }; return @($ui.B | Where-Object { $_.Visible })[0] }
# Prints the action row of the card on screen: its wrap width, the text column, and each button's place and left margin.
function global:Write-RadeRow { Write-Host ('WIN row max=' + $ui.BtnRow.MaximumSize.Width + ' cw=' + $ui.ContentW + ' w=' + $ui.BtnRow.Width + ' ' + ((@(@($ui.BackB) + @($ui.B)) | Where-Object { $_.Visible } |
    ForEach-Object { $_.Text + ':' + $_.Left + '/' + $_.Top + '/' + $_.Width + '/m' + $_.Margin.Left }) -join ' ')) }
function global:Step-Rade {
  if (((Get-Date) - $global:RadeT.T0).TotalSeconds -gt 240) { Write-Host ('WIN TIMEOUT view=' + $ui.View + ' sent=' + $ui.Sent.Text); [Environment]::Exit(3) }
  if (-not $ui -or -not $ui.Form -or $ui.Form.IsDisposed -or -not $ui.Form.Visible -or -not $ui.View) { return }
  if (-not $global:RadeT.Env) {
    $global:RadeT.Env = $true; $sc = [System.Windows.Forms.Screen]::PrimaryScreen; Write-Host ('WIN high=' + [bool]$ui.High + ' fonts=' + $ui.FontNote + ' standard=' + $ui.Standard)
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
  elseif ($v -eq 'maint') { Write-RadeRow; @($ui.B | Where-Object { $_.Visible -and $_.Text -eq 'Maintenance' })[0].PerformClick() } elseif ($v -eq 'tools') { Save-RadeRestore; (Get-RadeMain).PerformClick() }   # the Maintenance screen (and the Restore cards once), then Repair or Update (Start would start the application)
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
    $ib = @($ui.B | Where-Object { $_.Visible -and $_.Text -in 'Install', 'Run' })[0]; $ib.PerformClick()
  }
  elseif ($v -eq 'hand') {
    if (-not $global:RadeT.NoAddr -and $ui.FieldRow.Visible) {   # R28 N1: the same step with no address: no address row (its own picture and self-check)
      $global:RadeT.NoAddr = $true; $g0 = $ui.GUrl; $s0 = $ui.G.Step; $ui.GUrl = ''; $ui.G.Step = $s0.Clone(); $ui.G.Step.UrlConfig = ''
      & $ui.VHand; Save-RadeCard 'noaddress-hand'; Write-Host ('WIN no-address field=' + $ui.FieldRow.Visible + ' guide=' + $ui.Guide.Visible + ' path=' + $ui.PathT.Visible)
      $ui.GUrl = $g0; $ui.G.Step = $s0; & $ui.VHand }
    $hf = @($ui.B | Where-Object { $_.Visible -and $_.Text -eq 'It failed' })[0]   # B3: Done (primary) is the last button
    if (-not $hf) { (Get-RadeMain).PerformClick() } elseif ($global:RadeT.Hand -eq 'fail') { $hf.PerformClick() } else { (Get-RadeMain).PerformClick() }
  }
  elseif ($v -eq 'answer') {
    if ($ui.FieldRow.Visible) { $ui.Field.Text = 'Sample note' }; Step-RadeR31 $v }
  elseif ($v -in 'tour', 'answerfail', 'feedback') { Step-RadeR31 $v }
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
