# The test "user" for the RADE window (tests/engine_test.sh, section "window"). It is put in front of a test copy of a
# bundle. It loads the stand-in types (tests/window_stub.cs), then answers each card the window shows: it prints one
# "WIN" line per card, runs every Paint handler, checks that each control has a name and a focus ring, and selects a button.
# Set by the test: RADE_T_STUB (path of the stub), RADE_T_APP (index of the application), RADE_T_HAND (done, fail or
# skip), RADE_T_RECORD (1 = open "Steps and files" and clear the Clean-up box before the run), RADE_T_TOUR (1 = the
# application also gets the site, sign-in and Power Automate checks, and a base check of the test application is FAILED),
# RADE_T_LOOP (1 = Application.Run fails as when a message loop already runs: the window must open with ShowDialog),
# RADE_T_SCALE (150 = the form scales to 144 dpi while the screen dpi says 96, as on the R24 device). It prints "WIN measure"
# lines: sizes RADE sets after the form has scaled (a choice on Choose, the Record's step boxes and labels, made then).
# A button that showed a longer text on an earlier card must be able to shrink (AutoSize GrowAndShrink): else WIN BAD.
# Alignment (no layout here): "WIN mid" lines give the vertical midpoints of an aligned row from its margins and sizes
# (top margin + height / 2); "WIN sent-pt" the headline size of a question card; "WIN rule" the self-check's alignment rules
# on a fixture that is aligned and one that is not.
# On the hand step's questions (manifest "answers") it answers No, the second choice, and a text with a fake e-mail address.
# A check that cannot pass on the test computer is set to PASSED after its card has shown (the test is of the window).
Add-Type -TypeDefinition ([System.IO.File]::ReadAllText($env:RADE_T_STUB)) -ReferencedAssemblies @('System.Drawing.Primitives', 'System.Collections', 'System.Linq.Expressions', 'System.Management.Automation', 'System.Runtime', 'netstandard') -WarningAction SilentlyContinue
function Start-Process { param($FilePath, $ArgumentList) Write-Host ('WIN start-process ' + $(if ($FilePath -match '^https://') { 'browser' } else { [string]$FilePath })) }
[RadeStub.Driver]::RunThrows = ($env:RADE_T_LOOP -eq '1'); if ($env:RADE_T_SCALE -eq '150') { [RadeStub.Driver]::FormDpi = 144 }
$global:RadeT = @{ Long = @{}; Min = $false; Seen = ''; App = [int]$env:RADE_T_APP; Hand = [string]$env:RADE_T_HAND; Record = ($env:RADE_T_RECORD -eq '1'); Forced = $false; Opened = $false; Tour = ($env:RADE_T_TOUR -eq '1'); Esc = $false; Again = $false; SignIn = $false }
function global:Show-RadeCard {
  $ps = @($ui.P | Where-Object { $_.Shown } | ForEach-Object { $_.Text }) -join ' / '
  $bs = @($ui.B | Where-Object { $_.Shown } | ForEach-Object { $(if ($_.Enabled) { '[' } else { '(' }) + $_.Text + $(if ($_.Enabled) { ']' } else { ')' }) }) -join ' '
  $os = @($ui.Opts.Controls | ForEach-Object { $(if ($_.Tag.Off) { 'OFF ' } else { [string]$_.Tag.Key + ' ' }) + $_.Tag.Name + $_.Tag.Ver + $(if ($_.Tag.Note) { ' NOTE ' + $_.Tag.Note } else { '' }) }) -join '; '
  Write-Host ('WIN view=' + $ui.View + ' light=' + ([string]$ui.Light.AccessibleName).Substring(14) + ' kick=' + $(if ($ui.Kick.Shown) { $ui.Kick.Text } else { '' }) + ' sent=' + $ui.Sent.Text + ' p=' + $ps + $(if ($ui.Opts.Shown) { ' opts=' + $os } else { '' }) +
    $(if ($ui.Lines.Shown) { ' lines=' + ($ui.Lines.Text -replace '\r\n', ' ~ ') } else { '' }) + $(if ($ui.Note.Shown) { ' note=' + $ui.Note.Text } else { '' }) + $(if ($ui.Help.Shown) { ' help=' + $ui.Help.Text } else { '' }) + ' btn=' + $bs + $(if ($ui.Foot.Shown) { ' foot=' + $ui.Foot.Text } else { '' }) +
    $(if ($ui.TestRow.Shown) { ' test=shown' } else { '' }) + ' back=' + [bool]$ui.BackB.Shown + ' right=' + $ui.RightL.Text + ' app=' + $ui.AppL.Text)
  # The stand-ins have no layout: a button keeps the width of its longest text unless it can shrink (Windows Forms GrowOnly).
  for ($k = 0; $k -lt @($ui.B).Count; $k++) { $b = $ui.B[$k]; if (-not $b.Shown) { continue }; $was = [int]$global:RadeT.Long[$k]
    if ($was -gt $b.Text.Length -and [string]$b.Values['AutoSizeMode'] -ne 'GrowAndShrink') { Write-Host ('WIN BAD button ' + $k + ' "' + $b.Text + '" keeps the width of a ' + $was + '-character text in view ' + $ui.View) }
    if ($b.Text.Length -gt $was) { $global:RadeT.Long[$k] = $b.Text.Length } }
  $ui.Form.Repaint()
  $all = New-Object 'System.Collections.Generic.List[System.Windows.Forms.Control]'; $ui.Form.Walk($all)
  foreach ($c in $all) {
    if (-not $c.Shown) { continue }
    $t = $c.GetType().Name; $drawn = $c.Events.ContainsKey('Paint') -and $t -eq 'Panel'
    if ($t -in 'Button', 'TextBox', 'CheckBox', 'PictureBox' -or $drawn) { if (-not $c.Text -and -not $c.Has('AccessibleName')) { Write-Host ('WIN NONAME ' + $t + ' in view ' + $ui.View) } }
    # Focus is always visible: the parent draws the ring ($ui.Ring), or the control is a choice, which draws its own.
    if ($t -in 'Button', 'TextBox', 'CheckBox' -and -not ($c.Parent -and $c.Parent.Events.ContainsKey('Paint')) -and -not ($c.Tag -is [hashtable])) { Write-Host ('WIN NOFOCUS ' + $t + ' "' + $c.Text + '" in view ' + $ui.View) }
  }
}
function global:Push-RadeButton([string]$Text) {
  foreach ($b in $ui.B) { if ($b.Shown -and $b.Text -eq $Text) { $b.PerformClick(); return } }
  throw ('the test user found no button "' + $Text + '" in view ' + $ui.View)
}
[RadeStub.Driver]::Pump = {
  if (-not $ui -or -not $ui.Form -or $ui.Form.Closed -or -not $ui.View) { return }
  $key = [string]$ui.View + '|' + $ui.Sent.Text + '|' + $ui.Kick.Text
  if ($key -eq $global:RadeT.Seen) { return }
  $global:RadeT.Seen = $key
  Show-RadeCard
  $v = [string]$ui.View
  if ($v -eq 'choose') {
    if ($ui.Blocked.Count -and -not $global:RadeT.Forced) {
      $global:RadeT.Forced = $true; Write-Host ('WIN blocked=' + $ui.Blocked.Count)
      foreach ($id in @($ui.BaseRes.Keys)) { if ($ui.BaseRes[$id].State -eq 'FAILED') { $ui.BaseRes[$id] = @{ State = 'PASSED'; Detail = 'Set by the test'; Fix = '' } } }
      $ui.Blocked = @{}; & $ui.VChoose; Show-RadeCard
    }
    if ($global:RadeT.Tour) {
      $global:RadeT.Tour = $false; $apps[$global:RadeT.App].Checks = @($apps[$global:RadeT.App].Checks) + @('net-site', 'site-rights', 'flow-guide')
      $ui.BaseRes['outlook'] = @{ State = 'FAILED'; Detail = 'Not found'; Fix = 'Install Outlook, then paste the block again' }   # a base check only the test application has: that one is blocked
      & $ui.VChoose; Show-RadeCard
    }
    foreach ($o in @($ui.Opts.Controls)) { if (-not $o.Tag.Off -and [int]$o.Tag.Index -eq $global:RadeT.App) { Write-Host ('WIN measure choice h=' + $o.Height + ' gap=' + $o.Margin.Bottom + ' plan-x=' + (& $ui.OptPlan $o.Tag $o.Width).X); $ui.Form.Key('D' + $o.Tag.Key); return } }
    throw 'the test user found no choice for the application'
  }
  elseif ($v -eq 'maint') {
    if (-not $global:RadeT.Esc) { $global:RadeT.Esc = $true; Write-Host 'WIN esc'; $ui.Form.Key('Escape'); return }   # Esc = Back: Choose again; the user chooses the same application
    $ui.B[0].PerformClick()
  }
  elseif ($v -eq 'site') { $ui.Field.Text = 'not an address'; $ui.B[0].PerformClick(); Write-Host ('WIN site-note=' + $ui.Note.Text); $ui.Field.Text = 'https://rade-test.invalid/sites/fake'; $ui.B[0].PerformClick() }   # .invalid never resolves: the site check fails on every computer
  elseif ($v -in 'fail', 'need') {
    # The check on the card: the look-and-answer check is answered through its own card; any other is set to PASSED.
    $id = [string]@($script:appChecks)[([int]($ui.Kick.Text -replace '^CHECK (\d+) OF .*$', '$1')) - 1]
    if ($v -eq 'need' -and (Get-CheckDef $id).Kind -eq 'guide') { $ui.B[0].PerformClick(); return }
    if ($v -eq 'need' -and (Get-CheckDef $id).Kind -eq 'signin' -and -not $global:RadeT.SignIn) {   # a sign-in that failed: its card must offer the sign-in again
      $global:RadeT.SignIn = $true; $script:checkResults[$id] = @{ State = 'FAILED'; Detail = 'Sign-in was not finished'; Fix = 'Select "Sign in and check site rights"' }; & $ui.Next; return
    }
    if ($v -eq 'fail' -and $ui.B[0].Text -eq 'Run checks again' -and -not $global:RadeT.Again) {   # the check runs again and fails again
      $global:RadeT.Again = $true; Write-Host 'WIN again'; $ui.B[0].PerformClick(); return   # the cards that follow are answered by the calls inside this click
    }
    $script:checkResults[$id] = @{ State = 'PASSED'; Detail = 'Set by the test'; Fix = '' }
    & $ui.Next
  }
  elseif ($v -eq 'ready') {
    if (-not $global:RadeT.Min) {   # a minimized window: RADE brings it back when it needs the person; it has its own taskbar button
      $global:RadeT.Min = $true; $ui.Form.WindowState = 'Minimized'; & $ui.ToFront
      Write-Host ('WIN restored=' + $ui.Form.WindowState + ' taskbar=' + $ui.Form.Values['ShowInTaskbar'] + ' minbox=' + $ui.Form.Values['MinimizeBox'] + ' shown-by=' + [RadeStub.Driver]::ShownBy)
    }
    if ($global:RadeT.Record -and -not $global:RadeT.Opened) {
      $global:RadeT.Opened = $true
      $script:checkResults['ps'] = @{ State = 'PASSED'; Detail = 'Last check: 14-11-26'; Fix = 'Version [5.1]'; Saved = $true }   # a reused check, as Get-SavedCheck gives it
      Push-RadeButton 'Steps and files'
      $ui.Form.Repaint()
      $all = New-Object 'System.Collections.Generic.List[System.Windows.Forms.Control]'; $ui.Rec.Walk($all)   # the Record's controls: each one that takes the focus has a ring
      foreach ($c in $all) { $t = $c.GetType().Name; if ($t -in 'Button', 'TextBox', 'CheckBox' -and -not ($c.Parent -and $c.Parent.Events.ContainsKey('Paint'))) { Write-Host ('WIN NOFOCUS ' + $t + ' "' + $c.Text + '" in the Record') } }
      $boxes = @($ui.RecSteps.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] })
      $lab = @($ui.RecSteps.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] })[0]
      Write-Host ('WIN measure record box=' + $boxes[0].Margin.Left + ',' + $boxes[0].Margin.Top + ' label=' + $lab.Margin.Left + ',' + $lab.Margin.Bottom + ' rows=' + (& $ui.RecPlan 400).Tall)
      Write-Host ('WIN record on=' + $ui.RecOn + ' rows=' + @($ui.RecData).Count + ' boxes=' + $boxes.Count + ' enabled=' + $boxes[0].Enabled + ' text=' + [bool]($ui.RecText.Text -match 'Files this round saves') + ' name=' + [bool]($ui.RecChecks.Values['AccessibleName'] -match 'PASSED') + ' reused=' + (@($ui.RecData | Where-Object { $_.Name -match '^PowerShell is version' })[0].More -join ' / ') + ' tall=' + ($ui.RecChecks.Height -gt 100))
      $ui.Form.Key('Next'); Write-Host ('WIN paged=' + $ui.RecScroll.Values['AutoScrollPosition'].Y); $ui.Form.Key('Prior')   # the names Windows gives Page Down and Page Up
      foreach ($b in $boxes) { if ([int]$b.Tag -lt 0) { $b.Checked = $false } }
      $ui.Form.Key('Escape'); Write-Host ('WIN record on=' + $ui.RecOn + ' clean=' + $ui.Clean)
    }
    $ui.B[0].PerformClick()
  }
  elseif ($v -eq 'hand') {
    $m = { param($C) $(if ($C.AutoSize) { $C.Margin.Top + $C.PreferredSize.Height / 2.0 } else { $C.Margin.Top + $C.Height / 2.0 }) }
    Write-Host ('WIN mid hand label=' + (& $m $ui.FieldL) + ' box=' + (& $m $ui.FieldBox) + ' button=' + (& $m $ui.FieldB) + ' box-h=' + $ui.FieldBox.Height + ' button-h=' + $ui.FieldB.PreferredSize.Height + ' gaps=' + ($ui.FieldL.Margin.Right + $ui.FieldBox.Margin.Left) + ',' + ($ui.FieldBox.Margin.Right + $ui.FieldB.Margin.Left) + ' inner=' + $ui.Field.Width + '/' + $ui.FieldBox.Width + ' tick=' + $ui.TickP.Margin.Left)
    Write-Host ('WIN mid header logo=' + ($ui.Logo.Margin.Top + $ui.Logo.Height / 2.0) + ' word=' + (& $m $ui.WordL) + ' app=' + (& $m $ui.AppL))
    if (-not $ui.Field.Shown -or $ui.Form.Values['AcceptButton']) { Write-Host 'WIN BAD hand card: no address box, or Enter answers' }
    $ui.FieldB.PerformClick(); if ($ui.CopyPathB.Shown) { $ui.CopyPathB.PerformClick() }; Write-Host ('WIN hand-note=' + $ui.Note.Text + ' clip=' + [bool][RadeStub.Driver]::Clip)
    if ($ui.B[1].Text -ne 'It failed') { $ui.B[0].PerformClick() }   # a look-and-answer check: Yes
    elseif ($global:RadeT.Hand -eq 'fail') { Push-RadeButton 'It failed' } elseif ($global:RadeT.Hand -eq 'skip') { $ui.B[2].PerformClick() } else { $ui.B[0].PerformClick() }
  }
  elseif ($v -eq 'answer') {
    Write-Host ('WIN sent-pt=' + $ui.Sent.Font.SizeInPoints + ' for "' + $ui.Sent.Text + '"')
    if ($ui.FieldRow.Shown) { $m = { param($C) $(if ($C.AutoSize) { $C.Margin.Top + $C.PreferredSize.Height / 2.0 } else { $C.Margin.Top + $C.Height / 2.0 }) }; Write-Host ('WIN mid answer label=' + (& $m $ui.FieldL) + ' box=' + (& $m $ui.FieldBox) + ' h=' + $ui.FieldBox.Height) }
    if ($ui.FieldRow.Shown) { Write-Host ('WIN answer-box max=' + $ui.Field.Values['MaxLength'] + ' enter=' + $ui.Form.Values['AcceptButton'].Text + ' focus=' + $ui.Field.Focused); $ui.Field.Text = '  Mail someone@example.com about it  '; $ui.Form.Values['AcceptButton'].PerformClick() }
    elseif ($ui.B[0].Text -eq 'Yes') { Push-RadeButton 'No' } else { $ui.B[1].PerformClick() }
  }
  elseif ($v -eq 'handfail') { $ui.ErrBox.Text = 'Import failed: flow https://usaf.dps.mil/sites/fake/x not found'; $ui.B[0].PerformClick() }
  elseif ($v -in 'done', 'review', 'stopped') {
    [RadeStub.Driver]::Clip = ''
    foreach ($b in $ui.B) { if ($b.Shown -and $b.Text -eq 'What it made') { $b.PerformClick(); Write-Host ('WIN made=' + [bool]($ui.RecText.Text -match "Made by this app's installs") + ' log=' + [bool]($ui.RecText.Text -match '(?m)^LOG') + ' locked=' + (-not @($ui.RecSteps.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] })[0].Enabled)); $ui.RecClose.PerformClick() } }
    $ui.Form.Key('F2'); $ui.Form.Repaint(); $ui.Form.Key('F2')
    Write-Host ('WIN layline=' + ((& $ui.LayLine) -replace "`r`n", ' ~ '))
    $ok = @(& $ui.RowBad 'fixture' 'FieldRow' @(@{ N = 'FieldL'; Top = 10; H = 18; Kind = 'other' }, @{ N = 'FieldBox'; Top = 4; H = 30; Kind = 'box' }, @{ N = 'FieldB'; Top = 4; H = 30; Kind = 'button' })) + @(& $ui.EdgeBad 'fixture' @(@{ N = 'Kick'; X = 125 }, @{ N = 'Sent'; X = 126 }, @{ N = 'P0'; X = 125 }, @{ N = 'B0'; X = 125 }))
    $no = @(& $ui.RowBad 'fixture' 'FieldRow' @(@{ N = 'FieldL'; Top = 13; H = 18; Kind = 'other' }, @{ N = 'FieldBox'; Top = 4; H = 23; Kind = 'box' }, @{ N = 'FieldB'; Top = 4; H = 30; Kind = 'button' })) + @(& $ui.EdgeBad 'fixture' @(@{ N = 'Kick'; X = 123 }, @{ N = 'Sent'; X = 126 }, @{ N = 'P0'; X = 123 }, @{ N = 'B0'; X = 124 }))
    Write-Host ('WIN rule aligned=' + $ok.Count + ' misaligned=' + $no.Count + ' ~ ' + ($no -join ' ~ '))
    # A row that wraps: the check box alone on the second line is aligned on its own line; on the first line it is not.
    $wrap = @(& $ui.RowBad 'fixture' 'TestRow' @(@{ N = 'TestL'; Top = 10; H = 18; Line = 0; Kind = 'other' }, @{ N = 'ToBoxF'; Top = 4; H = 30; Line = 0; Kind = 'box' }, @{ N = 'OkBox'; Top = 48; H = 20; Line = 38; Kind = 'other' }))
    $wbad = @(& $ui.RowBad 'fixture' 'TestRow' @(@{ N = 'TestL'; Top = 10; H = 18; Line = 0; Kind = 'other' }, @{ N = 'ToBoxF'; Top = 4; H = 30; Line = 0; Kind = 'box' }, @{ N = 'OkBox'; Top = 48; H = 20; Line = 0; Kind = 'other' }))
    Write-Host ('WIN rule wrapped=' + $wrap.Count + ' one-line=' + $wbad.Count + ' ~ ' + ($wbad -join ' ~ '))
    foreach ($b in $ui.B) { if ($b.Shown -and $b.Text -in 'Copy summary', 'Copy the log') { $b.PerformClick() } }
    Write-Host ('WIN copied=' + [bool]([RadeStub.Driver]::Clip -match 'Application: ') + ' note=' + $ui.Note.Text)
    if ($ui.TestRow.Shown) { $ui.DraftB.PerformClick(); Write-Host ('WIN draft-note=' + $ui.Note.Text) }
    Push-RadeButton 'Close'; Write-Host ('WIN closed=' + $ui.Form.Closed)
  }
}
