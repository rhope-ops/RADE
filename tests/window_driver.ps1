# The test "user" for the RADE window (tests/engine_window.sh, sourced by tests/engine_test.sh). It is put in front of a test copy of a
# bundle. It loads the stand-in types (tests/window_stub.cs), then answers each card the window shows: it prints one
# "WIN" line per card, runs every Paint handler, checks that each control has a name and a focus ring, and selects a button.
# Set by the test: RADE_T_STUB (path of the stub: its C# source or a DLL made from it), RADE_T_APP (index of the application), RADE_T_HAND (done, fail or
# skip), RADE_T_RECORD (1 = open "Record" and clear the Clean-up box before the run), RADE_T_TOUR (1 = the
# application also gets the site, sign-in and Power Automate checks, and a base check of the test application is FAILED),
# RADE_T_LOOP (1 = Application.Run fails as when a message loop already runs: the window must open with ShowDialog),
# RADE_T_FAULT (boot = the boot checks throw; noapps = the paste lists no application), RADE_T_CANCEL (1 = select Cancel on the first checking card), RADE_T_START (1 = select the Start button when the Ready card has it; maint = select Start on the Maintenance card), RADE_T_LINK (a folder: the Ready card's shortcut box first gets a folder that does not exist, then this one), RADE_T_SCALE (150 = the form scales to 144 dpi while the screen dpi says 96, as on the R24 device). It prints "WIN measure"
# lines: sizes RADE sets after the form has scaled (a choice on Choose, the Record's step boxes and labels, made then).
# A button that showed a longer text on an earlier card must be able to shrink (AutoSize GrowAndShrink): else WIN BAD.
# Alignment (no layout here): "WIN mid" lines give the vertical midpoints of an aligned row from its margins and sizes
# (top margin + height / 2); "WIN sent-pt" the headline size of a question card; "WIN rule" the self-check's alignment rules
# on a fixture that is aligned and one that is not.
# On the hand step's questions (manifest "answers") it answers No, the second choice, and a text with a fake e-mail address.
# A check that cannot pass on the test computer is set to PASSED after its card has shown (the test is of the window).
# The stand-in types: RADE_T_STUB is the C# source (compiled here, about 0.8 s of CPU) or a DLL made from it once. With
# RADE_T_STUB_OUT set, this script only compiles the source to that DLL and stops (tests/engine_window.sh; speed audit 2026-11-17).
$stubRefs = @('System.Drawing.Primitives', 'System.Collections', 'System.Linq.Expressions', 'System.Management.Automation', 'System.Runtime', 'netstandard')
if ($env:RADE_T_STUB -like '*.dll') { Add-Type -Path $env:RADE_T_STUB }
elseif ($env:RADE_T_STUB_OUT) { Add-Type -TypeDefinition ([System.IO.File]::ReadAllText($env:RADE_T_STUB)) -ReferencedAssemblies $stubRefs -OutputAssembly $env:RADE_T_STUB_OUT -OutputType Library -WarningAction SilentlyContinue; return }
else { Add-Type -TypeDefinition ([System.IO.File]::ReadAllText($env:RADE_T_STUB)) -ReferencedAssemblies $stubRefs -WarningAction SilentlyContinue }
function Start-Process { param($FilePath, $ArgumentList, $WorkingDirectory) Write-Host ('WIN start-process ' + $(if ($FilePath -match '^https://') { 'browser' } else { [string]$FilePath })) }
[RadeStub.Driver]::RunThrows = ($env:RADE_T_LOOP -eq '1'); if ($env:RADE_T_SCALE -eq '150') { [RadeStub.Driver]::FormDpi = 144 }
$global:RadeT = @{ Long = @{}; Min = $false; Seen = ''; App = [int]$env:RADE_T_APP; Hand = [string]$env:RADE_T_HAND; Record = ($env:RADE_T_RECORD -eq '1'); Forced = $false; Opened = $false; Tour = ($env:RADE_T_TOUR -eq '1'); Esc = $false; Again = $false; SignIn = $false }
# R34: a pasted block goes into the one-line answer box as one line ($ui.PasteLine), cut to the room that is left
# ($ui.OneLine); R7: the note of what did not fit. Takes nothing; prints the lines "WIN paste" and "WIN paste-cut".
function global:Test-RadePaste {
  $ui.Field.Multiline = $false; $ui.Field.ReadOnly = $false; [RadeStub.Driver]::Clip = "line one`r`n  line two`n"; $pl = & $ui.PasteLine $ui.Field
  Write-Host ('WIN paste ok=' + $pl + ' text=' + $ui.Field.SelectedText + ' cut=' + (& $ui.OneLine ('x' * 20) 5) + ' joined=' + (& $ui.OneLine "a`tb`r`n`r`nc" 100) + ' note=' + $ui.Note.Text)
  # R7: a paste over the room is cut and the gray line under the box says how many characters did not fit.
  $ui.Field.Text = ('a' * ($ui.Field.MaxLength - 3)); [RadeStub.Driver]::Clip = ('x' * 1237); $pc = & $ui.PasteLine $ui.Field
  Write-Host ('WIN paste-cut ok=' + $pc + ' inserted=' + $ui.Field.Inserted.Length + ' note=' + $ui.Note.Text + ' shown=' + $ui.Note.Visible)
  $ui.Field.Text = ('a' * ($ui.Field.MaxLength - 1)); [RadeStub.Driver]::Clip = 'xy'; $null = & $ui.PasteLine $ui.Field; Write-Host ('WIN paste-cut one=' + $ui.Note.Text)
  $ui.Field.Text = ''; [RadeStub.Driver]::Clip = 'fits'; $null = & $ui.PasteLine $ui.Field; Write-Host ('WIN paste-cut none=[' + $ui.Note.Text + ']') }
# R33: a check result that comes while the Record is open shows, with its detail also when it passed; Copy all gives the
# whole Record. Takes nothing; prints the line "WIN record-copy" and puts the check's result back.
function global:Test-RadeRecordCopy {
  $cid = [string]@($script:appChecks)[0]; $was = $script:checkResults[$cid]; $script:checkResults[$cid] = @{ State = 'PASSED'; Detail = 'R33 detail probe'; Fix = '' }; & $ui.RecRefresh
  $ui.RecCopy.PerformClick(); $cl = [string][RadeStub.Driver]::Clip; $nm = [string]$ui.RecChecks.Values['AccessibleName']
  Write-Host ('WIN record-copy btn=' + $ui.RecCopy.Text + ' checks=' + ($cl -match '(?m)^CHECKS') + ' detail=' + ($cl -match '(?m)^      R33 detail probe') + ' steps=' + ($cl -match '(?m)^  \[[x ]\] ') + ' text=' + ($cl -match 'Files this round saves') + ' name=' + ($nm -match 'R33 detail probe'))
  $script:checkResults[$cid] = $was; & $ui.RecRefresh }
<#
.SYNOPSIS
The red line of a script whose hash does not match (the Administrator, 2026-11-19): prints the "WIN script-warn" lines.
.DESCRIPTION
On the real Choose card: a mismatch, a match and a hash that is not available. Then on cards that have a last line of
their own (Choose of a test-only paste, Ready with a site, boot): the warning takes that line on a mismatch and the own
text is back on a match. The real state is restored and Choose is shown again.
.OUTPUTS
Nothing; 9 WIN lines.
#>
function global:Test-RadeScriptWarn {
  if ($global:RadeT.WarnDone) { return }; $global:RadeT.WarnDone = $true
  $was = $script:scriptCheck
  foreach ($k in @(@('mismatch', 'abc...def', $false), @('match', 'abc...def', $true), @('unavailable', '', $false))) {
    $script:scriptCheck = @{ Line = 'x'; Short = $k[1]; Ok = $k[2] }; & $ui.VChoose
    Write-Host ('WIN script-warn ' + $k[0] + ' view=' + $ui.View + ' text=[' + $(if ($ui.Foot.Visible) { $ui.Foot.Text } else { '' }) + '] red=' + [object]::Equals($ui.Foot.ForeColor, $ui.C.Red)) }
  # Cards that have a last line of their own (Choose of a test-only paste, Ready with a site, boot with none): the warning takes it on a mismatch; the own text is back on a match.
  foreach ($k in @(@('mismatch', $false), @('match', $true))) {
    $script:scriptCheck = @{ Line = 'x'; Short = 'abc...def'; Ok = $k[1] }
    foreach ($v in @(@('choose', 'Last round on this computer: none recorded yet.'), @('ready', 'Site: example'), @('boot', ''))) {
      & $ui.Show $ui.Foot ([string]$v[1]); & $ui.ScriptWarn @{ View = $v[0]; Foot = $v[1] }   # what SetCard does with the card's own last line
      Write-Host ('WIN script-warn own ' + $k[0] + ' ' + $v[0] + ' text=[' + $(if ($ui.Foot.Visible) { $ui.Foot.Text } else { '' }) + '] red=' + [object]::Equals($ui.Foot.ForeColor, $ui.C.Red)) } }
  $script:scriptCheck = $was; & $ui.VChoose }
<#
.SYNOPSIS
The Administrator, 2026-11-19 ("values cause fluttering"): prints "WIN steady", proof that no control moves or resizes
while the values of a card change through their range.
.DESCRIPTION
The stand-ins have no layout, so a control's place is its margins and its size is what RADE sets (an AutoSize label: the
size it asks for). On the Run card: every step title with its number, the time in the step from 0 s to 9 h 58 m 20 s, the
count from none to "999 of 999", the percent from 0 to 100 and the now-doing line short, long and empty. On the checking
card: every check name and "Check i of n". Then a probe: a title that is not in the card's range must show as a change
(the test can see one). The values of the card are put back after.
.PARAMETER V
The view of the card that shows; only the first Run card with a step and the first checking card are measured.
.OUTPUTS
Nothing; one WIN line for each of the two cards.
#>
function global:Test-RadeSteady([string]$V) {
  $run = ($V -eq 'run' -and $ui.Kick.Text -match '^STEP ' -and $script:prog -and $script:stepStart -and -not $global:RadeT.SteadyRun)
  $chk = ($V -eq 'checking' -and $ui.Sent.Text -eq 'Checking this computer and your access.' -and -not $global:RadeT.SteadyChk)
  if (-not ($run -or $chk)) { return }
  # One text per shown control: its place (margins, left, top) and its size; the same card, so the same controls in order.
  $snap = { $all = New-Object 'System.Collections.Generic.List[System.Windows.Forms.Control]'; $ui.Form.Walk($all); $k = 0
    foreach ($c in $all) { $k++; if (-not $c.Shown) { continue }; $m = $c.Margin; $z = $(if ($c.Values['AutoSize'] -eq $true -and $c -is [System.Windows.Forms.Label]) { $c.PreferredSize } else { $c.Size })
      [string]$k + ' ' + (& $ui.NameOf $c) + ' ' + $z.Width + 'x' + $z.Height + ' m=' + $m.Left + ',' + $m.Top + ',' + $m.Right + ',' + $m.Bottom + ' at=' + $c.Left + ',' + $c.Top } }
  $keep = @{ Kick = $ui.Kick.Text; Name = $ui.StepName.Text; Time = $ui.StepTime.Text; Frac = $ui.StepFrac.Text; Right = $ui.RightL.Text; P0 = $ui.P[0].Text; Start = $script:stepStart; NowRaw = $ui.NowRaw; Now = $ui.Now.Text }
  foreach ($b in @($ui.Wrap.Keys)) { & $ui.Reflow $b }; foreach ($l in @($ui.Most.Keys)) { & $ui.FixW $l }
  $s0 = @(& $snap); $n = 0; $moved = @(); $sn = $(if ($global:RadeT.ShowNow) { $global:RadeT.ShowNow } else { $ui.ShowNow })
  # The stand-ins fire no TextChanged: each box and label is sized here as its TextChanged handler sizes it on Windows.
  $look = { foreach ($b in @($ui.Wrap.Keys)) { & $ui.Reflow $b }; foreach ($l in @($ui.Most.Keys)) { & $ui.FixW $l }; $s1 = @(& $snap); for ($i = 0; $i -lt [math]::Max($s0.Count, $s1.Count); $i++) { if ($s0[$i] -ne $s1[$i]) { $script:steadyMoved += ($s0[$i] + ' -> ' + $s1[$i]) } } }
  $script:steadyMoved = @()
  if ($run) { $global:RadeT.SteadyRun = $true; $fr = @($script:prog.Frac, $script:prog.FracText); $sc = @($steps).Count
    for ($i = 0; $i -lt $sc; $i++) { & $ui.ShowStep ($i + 1) $sc ([string]$steps[$i].Name); $n++; & $look }
    & $ui.ShowStep 1 $sc 'Clean-up'; $n++; & $look
    foreach ($sec in 0, 5, 65, 754, 3599, 3725, 35900) { $script:stepStart = (Get-Date).AddSeconds(-$sec); & $ui.ShowTime; $n++; & $look }
    foreach ($f in '1 of 2', '12 of 40', '999 of 999', '') { $script:prog.Frac = $(if ($f) { 0.5 } else { -1 }); $script:prog.FracText = $f; & $ui.Paint; $n++; & $look }
    foreach ($r in '0 %', '7 %', '62 %', '100 %') { $ui.RightL.Text = $r; $n++; & $look }
    foreach ($w in 'Copying the list files.', ('word ' * 100), '') { & $sn $w; $n++; & $look }
    $script:prog.Frac = $fr[0]; $script:prog.FracText = $fr[1]; $script:stepStart = $keep.Start }
  else { $global:RadeT.SteadyChk = $true; $ids = @($script:appChecks)
    for ($i = 0; $i -lt $ids.Count; $i++) { $ui.P[0].Text = [string](Get-CheckDef $ids[$i]).Name; $ui.RightL.Text = 'Check ' + ($i + 1) + ' of ' + $ids.Count; $n++; & $look } }
  $pb = $(if ($run) { $ui.StepName } else { $ui.P[0] }); $pb.Text = ('Probe ' * 60); & $ui.Reflow $pb; & $ui.FitEdges; & $ui.FitBar; $probe = [bool](@(& $snap) -join '|').CompareTo((@($s0) -join '|'))
  $ui.Kick.Text = $keep.Kick; $ui.StepName.Text = $keep.Name; $ui.StepTime.Text = $keep.Time; $ui.StepFrac.Text = $keep.Frac; $ui.RightL.Text = $keep.Right; $ui.P[0].Text = $keep.P0
  $ui.NowRaw = $keep.NowRaw; $ui.Now.Text = $keep.Now; foreach ($b in @($ui.Wrap.Keys)) { & $ui.Reflow $b }; & $ui.FitEdges; & $ui.FitBar
  Write-Host ('WIN steady ' + $V + ' values=' + $n + ' moved=' + @($script:steadyMoved).Count + ' probe=' + $probe + ' ~ ' + (@($script:steadyMoved | Select-Object -First 4) -join ' ~ '))
}
function global:Show-RadeCard {
  # The top bar and the logo block at the first frame (the Administrator, 2026-11-19): one WIN line, once, with the window
  # title, the name spot (tagline until an application is chosen), whether it and the rule under RADE are shown, and the style.
  if (-not $global:RadeT.TopBar) { $global:RadeT.TopBar = $true
    Write-Host ('WIN topbar title=' + $ui.Form.Text + ' spot=' + $ui.AppL.Text + ' shown=' + ($ui.AppL.Visible -and ($ui.AppRow.Visible -or $ui.HeadRule.Visible)) + ' same-font=' + [object]::ReferenceEquals($ui.AppL.Font, $ui.F.Small) + ' right=[' + $ui.RightL.Text + ']')
    # "Your turn" (the Administrator, 2026-11-19): bold, blue, in the header row under the line in capitals; its line is as tall empty as shown.
    $tw = $ui.Turn.Text; $ui.Turn.Text = 'Your turn'; & $ui.Reflow $ui.Turn; $h1 = $ui.Turn.Height; $ui.Turn.Text = ''; & $ui.Reflow $ui.Turn; $h2 = $ui.Turn.Height; $ui.Turn.Text = $tw; & $ui.Reflow $ui.Turn
    Write-Host ('WIN turn font=' + $ui.Turn.Font.Name + ' ' + $ui.Turn.Font.SizeInPoints + ' ' + $ui.Turn.Font.Style + ' blue=' + [object]::Equals($ui.Turn.ForeColor, $ui.C.Blue) + ' head=' + ((@($ui.Head.Controls) | ForEach-Object { & $ui.NameOf $_ }) -join ',') + ' down=' + $ui.Head.Values['FlowDirection'] + ' same-h=' + ($h1 -eq $h2 -and $h1 -gt 0) + ' shown=' + $ui.Turn.Shown) }
  $ps = @($ui.P | Where-Object { $_.Shown } | ForEach-Object { $_.Text }) -join ' / '
  $bs = @($ui.B | Where-Object { $_.Shown } | ForEach-Object { $(if ($_.Enabled) { '[' } else { '(' }) + $_.Text + $(if ($_.Enabled) { ']' } else { ')' }) }) -join ' '
  $os = @($ui.Opts.Controls | ForEach-Object { $(if ($_.Tag.Off) { 'OFF ' } else { [string]$_.Tag.Key + ' ' }) + $_.Tag.Name + $_.Tag.Ver + $(if ($_.Tag.Note) { ' NOTE ' + $_.Tag.Note } else { '' }) }) -join '; '
  Write-Host ('WIN view=' + $ui.View + ' light=' + ([string]$ui.Light.AccessibleName).Substring(14) + ' kick=' + $(if ($ui.Kick.Shown) { $ui.Kick.Text } else { '' }) + ' sent=' + $ui.Sent.Text + ' p=' + $ps + $(if ($ui.Opts.Shown) { ' opts=' + $os } else { '' }) +
    $(if ($ui.Guide.Shown -and @($ui.GuideNums).Count) { ' steps=' + ((@(for ($i = 0; $i -lt @($ui.GuideNums).Count; $i++) { $ui.GuideNums[$i] + ' ' + $ui.GuideTexts[$i] })) -join ' ~ ') } else { '' }) + $(if ($ui.Guide.Shown -and @($ui.GuideRest).Count) { ' rest=' + (@($ui.GuideRest) -join ' ~ ') } else { '' }) + $(if ($ui.Close.Shown) { ' close=' + $ui.Close.Text } else { '' }) + $(if ($ui.Note.Shown) { ' note=' + $ui.Note.Text } else { '' }) + $(if ($ui.Help.Shown) { ' help=' + $ui.Help.Text } else { '' }) + ' btn=' + $bs + $(if ($ui.Foot.Shown) { ' foot=' + $ui.Foot.Text } else { '' }) + $(if ($ui.StepRow.Shown) { ' step=' + $ui.StepName.Text + ' now-font=' + $ui.Now.Font.Name + $ui.Now.Font.SizeInPoints } else { '' }) +
    $(if ($ui.TestRow.Shown) { ' test=shown' } else { '' }) + ' back=' + [bool]$ui.BackB.Shown + ' right=' + $ui.RightL.Text + ' app=' + $ui.AppL.Text +
    $(if ($ui.FieldRow.Shown) { ' field=' + $ui.FieldL.Text + ':' + $ui.Field.Text } else { '' }) + $(if ($ui.PathT.Shown) { ' path=' + ($ui.PathT.Text -replace "`n", '') } else { '' }) + $(if ($ui.StepRow.Shown) { ' time=' + $ui.StepTime.Text } else { '' }) + ' help=' + [bool]$ui.TourB.Shown + ' turn=' + $(if ($ui.Turn.Shown) { $ui.Turn.Text } else { 'hidden' }))
  # UI standard v1 (B1, B3, B4, B5): every button has a size of the fixed set and no AutoSize, at most one primary button,
  # which is the last one, and at most 3 others ("Back (Esc)" is not counted: it is the Back pattern, B6).
  $kz = $ui.Dpi / 96.0; $ws = @(96, 160, 240 | ForEach-Object { [int][math]::Round($_ * $kz) }); $hs = @(30, 40 | ForEach-Object { [int][math]::Round($_ * $kz) })
  foreach ($b in @(@($ui.B) + @($ui.BackB, $ui.FieldB, $ui.RecClose, $ui.RecCopy) | Where-Object { $_ -and $_.Shown })) {
    if ($b.Values['AutoSize'] -or $ws -notcontains $b.Width -or $hs -notcontains $b.Height) { Write-Host ('WIN BAD button "' + $b.Text + '" is ' + $b.Width + 'x' + $b.Height + ' (autosize ' + [bool]$b.Values['AutoSize'] + ') in view ' + $ui.View) } }
  $shown = @($ui.B | Where-Object { $_.Shown }); $main = @(for ($k = 0; $k -lt $shown.Count; $k++) { if ([string]$ui.Kinds[$shown[$k]] -eq 'primary') { $k } })
  if ($main.Count -gt 1 -or ($main.Count -eq 1 -and $main[0] -ne $shown.Count - 1) -or ($shown.Count - $main.Count) -gt 3) { Write-Host ('WIN BAD buttons in view ' + $ui.View + ': ' + $shown.Count + ' shown, primary at ' + ($main -join ',')) }
  $ui.Form.Repaint()
  $all = New-Object 'System.Collections.Generic.List[System.Windows.Forms.Control]'; $ui.Form.Walk($all)
  foreach ($c in $all) {
    if (-not $c.Shown) { continue }
    $t = $c.GetType().Name; $drawn = $c.Events.ContainsKey('Paint') -and $t -eq 'Panel'
    # One typeface and four styles (docs/window-design.md "Fixed parts"): every button has the semibold small font (a link: the underlined one), and every label and card text box a font of $ui.F (or a headline size of the shrink rule).
    if ($t -eq 'Button' -and -not ($c.Tag -is [hashtable]) -and -not [object]::ReferenceEquals($c.Font, $ui.F.SmallB) -and -not [object]::ReferenceEquals($c.Font, $ui.F.Link)) { Write-Host ('WIN BAD font of button "' + $c.Text + '" in view ' + $ui.View) }
    if (($t -eq 'Label' -or (& $ui.IsCardText $c)) -and -not (@($ui.F.Values) + @($ui.SentFonts.Values) | Where-Object { [object]::ReferenceEquals($_, $c.Font) })) { Write-Host ('WIN BAD font of label "' + $c.Text + '" in view ' + $ui.View) }
    if ($t -in 'Button', 'TextBox', 'CheckBox', 'PictureBox' -or $drawn) { if (-not $c.Text -and -not $c.Has('AccessibleName')) { Write-Host ('WIN NONAME ' + $t + ' in view ' + $ui.View) } }
    # Focus is always visible: the parent draws the ring ($ui.Ring), or the control is a choice, which draws its own.
    if ($t -in 'Button', 'TextBox', 'CheckBox' -and -not ($c.Parent -and $c.Parent.Events.ContainsKey('Paint')) -and -not ($c.Tag -is [hashtable]) -and -not ($c.Values.ContainsKey('TabStop') -and $c.Values['TabStop'] -eq $false)) { Write-Host ('WIN NOFOCUS ' + $t + ' "' + $c.Text + '" in view ' + $ui.View) }
  }
  Test-RadeSteady ([string]$ui.View)
}
<#
.SYNOPSIS
R29b N3: prints "WIN mid tick", the step's time and count against the bar's midpoint, from margins and sizes (no layout here).
.DESCRIPTION
At 100, 150 and 200 %: the bar's coded margin and height scaled, the small font scaled (the stand-ins' text height is 1.7 x
the points). Then a text taller than the bar's place, fitted twice. The bar, its base margin and the fonts are restored after.
.OUTPUTS
Nothing; one WIN line.
#>
function global:Show-RadeTick {
  $tk = @('base=' + (& $ui.BarTop)); $keep = @{ Bar = $ui.StepBar.Margin; H = $ui.StepBar.Height; F = $ui.StepTime.Font; BT = $ui.BarTop }
  foreach ($k in 1.0, 1.5, 2.0) { $ui.StepBar.Margin = (& $ui.Pad 14 ([int](11 * $k)) 14 0); $ui.BarTop = [scriptblock]::Create('' + [int](11 * $k)); $ui.StepBar.Height = [int](4 * $k); $f = New-Object RadeDraw.Font([string]$ui.F.Small.Name, [single](10 * $k))
    $ui.StepTime.Font = $f; $ui.StepFrac.Font = $f; & $ui.AlignTick; $mb = $ui.StepBar.Margin.Top + $ui.StepBar.Height / 2.0
    $tk += ([string]([int]($k * 100)) + '%:' + [math]::Abs(($ui.StepTime.Margin.Top + $ui.StepTime.PreferredSize.Height / 2.0) - $mb) + '/' + [math]::Abs(($ui.StepFrac.Margin.Top + $ui.StepFrac.PreferredSize.Height / 2.0) - $mb)) }
  $ui.StepBar.Margin = $keep.Bar; $ui.BarTop = $keep.BT; $ui.StepBar.Height = $keep.H; $ui.StepTime.Font = $keep.F; $ui.StepFrac.Font = $keep.F; & $ui.AlignTick
  # A text taller than the bar's place (30 pt: 51 high) lifts the bar; a second fit keeps the same margin (the lift never adds up).
  $f = New-Object RadeDraw.Font([string]$ui.F.Small.Name, [single]30); $ui.StepTime.Font = $f; $ui.StepFrac.Font = $f; & $ui.AlignTick; $b1 = $ui.StepBar.Margin.Top; & $ui.AlignTick
  $tk += ('lift=' + ($b1 - 11) + ' again=' + ($ui.StepBar.Margin.Top - $b1) + ' off=' + [math]::Abs(($ui.StepTime.Margin.Top + $ui.StepTime.PreferredSize.Height / 2.0) - ($ui.StepBar.Margin.Top + $ui.StepBar.Height / 2.0)))
  $ui.StepTime.Font = $keep.F; $ui.StepFrac.Font = $keep.F; & $ui.AlignTick
  Write-Host ('WIN mid tick ' + ($tk -join ' '))
}
<#
.SYNOPSIS
Prints "WIN rule head" (R29b) and "WIN rule r31" (R31): the self-check's rules on fixtures that are right and that are not.
.DESCRIPTION
R29b: the header rule fails on any edge difference; the ticker rule allows 1 px at 100, 150 and 200 % (bar 4, 6, 8 high;
text 17, 26, 34 high) and fails beyond it. R31: the rules of the header line (L2), a label above its box (L3) and the
card frame (L1).
.OUTPUTS
Nothing; two WIN lines.
#>
function global:Show-RadeR29bRules {
  $hd = @(& $ui.HeadBad 'fixture' @{ N = 'WordL'; X = 80 } @{ N = 'AppL'; X = 80 }) + @(& $ui.HeadBad 'fixture' @{ N = 'WordL'; X = 86 } @{ N = 'AppL'; X = 80 })
  $tg = @(& $ui.TickBad 'fixture' @{ Top = 11; H = 4 } @{ N = 'StepTime'; Top = 5; H = 17 }) + @(& $ui.TickBad 'fixture' @{ Top = 16; H = 6 } @{ N = 'StepTime'; Top = 7; H = 26 }) + @(& $ui.TickBad 'fixture' @{ Top = 22; H = 8 } @{ N = 'StepTime'; Top = 9; H = 34 })
  $tb = @(& $ui.TickBad 'fixture' @{ Top = 11; H = 4 } @{ N = 'StepTime'; Top = 6; H = 17 }) + @(& $ui.TickBad 'fixture' @{ Top = 16; H = 6 } @{ N = 'StepTime'; Top = 9; H = 26 }) + @(& $ui.TickBad 'fixture' @{ Top = 22; H = 8 } @{ N = 'StepTime'; Top = 7; H = 34 })
  # R31 L2 (at 100 %: gap 4, tolerance 1): the word's ink ends at 20, the line is 24 to 25 and as wide as the word, the name's capitals start
  # at 29: no defect, also 1 px off; a gap of 7, a name 3 px low, a line 5 px short and a line 3 px right give one line each.
  $okM = @{ WordBottom = 20; WordLeft = 80; WordW = 52; RuleTop = 24; RuleBottom = 25; RuleLeft = 80; RuleW = 52; AppTop = 29 }; $ok1 = $okM.Clone(); $ok1.RuleTop = 25; $ok1.RuleBottom = 26; $ok1.AppTop = 31; $ok1.RuleW = 51; $ok1.AppTop = 31
  $no1 = $okM.Clone(); $no1.RuleTop = 27; $no1.RuleBottom = 28; $no1.AppTop = 35; $no1.RuleW = 47; $no1.RuleLeft = 83; $low = $okM.Clone(); $low.AppTop = $null
  $l2 = @(& $ui.HeadRuleBad 'fixture' $okM 4) + @(& $ui.HeadRuleBad 'fixture' $ok1 4) + @(& $ui.HeadRuleBad 'fixture' $low 4); $l2no = @(& $ui.HeadRuleBad 'fixture' $no1 4)
  # R31 L3: a label above its box (label bottom 40, box top 44, on the edge, as wide as the text): no defect; a box beside its label, 12 px right and 200 px short: 3 lines.
  $l3 = @(& $ui.AboveBad 'fixture' @{ LabelBottom = 40; BoxTop = 44; BoxLeft = 125; BoxW = 590; Edge = 125; TextW = 590 }); $l3no = @(& $ui.AboveBad 'fixture' @{ LabelBottom = 40; BoxTop = 22; BoxLeft = 137; BoxW = 390; Edge = 125; TextW = 590 })
  # R31 L1: the header row at the fixed top and a frame of its minimum height: no defect (also a card that had to move up); a header 30 px low and a frame 40 px short: 2 lines.
  $l1 = @(& $ui.FrameBad 'fixture' @{ Top = 96; WantTop = 96; H = 360; MinH = 360; Moved = $false }) + @(& $ui.FrameBad 'fixture' @{ Top = 0; WantTop = 96; H = 500; MinH = 360; Moved = $true }); $l1no = @(& $ui.FrameBad 'fixture' @{ Top = 126; WantTop = 96; H = 320; MinH = 360; Moved = $false })
  Write-Host ('WIN rule r31 head-ok=' + $l2.Count + ' head-off=' + $l2no.Count + ' above-ok=' + $l3.Count + ' above-off=' + $l3no.Count + ' frame-ok=' + $l1.Count + ' frame-off=' + $l1no.Count + ' ~ ' + (@($l2no) + @($l3no) + @($l1no) -join ' ~ '))
  Write-Host ('WIN rule head=' + $hd.Count + ' tick-ok=' + $tg.Count + ' tick-off=' + $tb.Count + ' ~ ' + (@($hd) + @($tb) -join ' ~ '))
}
<#
.SYNOPSIS
R31: one time, before the test user's first card: measures the minimum step time (L8), prints what Get-NowText gives (L7),
and makes each now-doing line print a "WIN now=" line.
.OUTPUTS
Nothing; WIN lines. Sets $ui.Layout.StepMs to 0 (the test user does not wait) and wraps $ui.ShowNow.
#>
function global:Start-RadeR31 {
  $ms0 = [int]$ui.Layout.StepMs; $ui.Layout.StepMs = 120; $v0 = $ui.View; $ui.View = 'run'; $ui.StepAt = $ui.Clock.Elapsed.TotalMilliseconds; $t0 = $ui.StepAt; & $ui.HoldStep
  Write-Host ('WIN hold ms=120 held=' + (($ui.Clock.Elapsed.TotalMilliseconds - $t0) -ge 115) + ' json=' + $ms0); $ui.View = $v0; $ui.StepAt = $null; $ui.Layout.StepMs = 0
  Write-Host ('WIN now-text pass=' + (Get-NowText 'ITEM m2-list PASS list there') + '|skip=' + (Get-NowText '  SKIP: no flow') + '|fail=' + (Get-NowText 'x FAIL list missing') + '|plain=' + (Get-NowText 'a line that passes nothing') + '|none=' + (Get-NowText 'PASS'))
  # The Administrator, 2026-11-19: the line keeps one height (Cancel under it does not move), each text ends with "...", a long
  # text is cut to $ui.NowLines lines. Measured once on a 300 px wrap, then the line is as it was.
  $v0 = $ui.View; $ui.View = 'run'; $w0 = [int]$ui.Wrap[$ui.Now]; & $ui.SetWrap $ui.Now 300
  & $ui.ShowNow 'Copying the list files.'; $s1 = $ui.Now.Text; $h1 = $ui.Now.Height
  & $ui.ShowNow ('word ' * 200); $s2 = [string]$ui.Now.Text; $h2 = $ui.Now.Height
  & $ui.ShowNow ('word ' * 200); & $ui.SetWrap $ui.Now 150; & $ui.BreakAll; $s4 = [string]$ui.Now.Text   # a narrower window: cut again
  $fit4 = ((& $ui.Meas $s4 $ui.Now.Font 150).Height -le $ui.NowLines * (& $ui.Meas 'Ag' $ui.Now.Font 100000).Height) -and $s4.EndsWith('...')
  & $ui.SetWrap $ui.Now 300; & $ui.ShowNow ('Done. ' + [string][char]0x2026); $s5 = [string]$ui.Now.Text
  & $ui.ShowNow ''; $h3 = $ui.Now.Height; $e3 = $ui.Now.Visible
  $fits = ((& $ui.Meas $s2 $ui.Now.Font 300).Height -le $ui.NowLines * (& $ui.Meas 'Ag' $ui.Now.Font 100000).Height)
  Write-Host ('WIN now-fit short=' + $s1 + '|long-end=' + $s2.EndsWith('...') + '|long-fits=' + $fits + '|same-h=' + ($h1 -eq $h2 -and $h2 -eq $h3 -and $h1 -gt 0) + '|empty-shown=' + $e3 + '|narrower-fits=' + $fit4 + '|ellipsis=' + $s5)
  & $ui.SetWrap $ui.Now $w0; $ui.Now.Text = ''; $ui.View = $v0
  $global:RadeT.ShowNow = $ui.ShowNow
  # The window's now-doing line, with one WIN line for each text (the text given, then the text shown). Takes the text.
  $ui.ShowNow = { param([string]$Text) & $global:RadeT.ShowNow $Text; if ($Text) { Write-Host ('WIN now=' + $Text + ' shown=' + $ui.Now.Text) } }
}
<#
.SYNOPSIS
R31: answers the cards of the R31 brief: the tour (L6), Help from the Ready card (L6), the error text after an answer that
means a failure (E2) and the last card of a test round (L4).
.PARAMETER V
The view of the card that shows.
.OUTPUTS
$true when the card was answered here; $false when the caller must answer it.
#>
function global:Step-RadeR31([string]$V) {
  if ($V -eq 'choose') { Test-RadeScriptWarn }
  if ($V -eq 'tour') {   # RADE_T_WALK=1: every card, with Back one time; else the test user skips it. From Help: skipped.
    if ($env:RADE_T_WALK -eq '1' -and -not $global:RadeT.Helped) {
      if ($ui.Kick.Text -match ' 2 OF 5$' -and -not $global:RadeT.TourBack) { $global:RadeT.TourBack = $true; Push-RadeButton 'Back'; return $true }
      $ui.Form.Values['AcceptButton'].PerformClick() }
    else { Push-RadeButton 'Skip the tour' }
    return $true }
  if ($V -eq 'answerfail') { $ui.ErrBox.Text = 'The page said: error 42 at https://usaf.dps.mil/sites/fake/x'; Push-RadeButton 'Continue'; return $true }
  if ($V -eq 'feedback') {   # L3: its label is above its box
    Write-Host ('WIN feedback max=' + $ui.Field.Values['MaxLength'] + ' enter=' + $ui.Form.Values['AcceptButton'].Text + ' focus=' + $ui.Field.Focused)
    Test-RadePaste; $ui.Field.Text = $(if ($env:RADE_T_FEEDBACK) { [string]$env:RADE_T_FEEDBACK } else { '' }); Push-RadeButton 'Continue'; return $true }
  if ($V -eq 'ready' -and $env:RADE_T_WALK -eq '1') {
    # Help (F1) opens the tour from a card; its end shows that card again (the calls nest here, so the second visit of this card prints the result).
    if ($global:RadeT.Helped -and -not $global:RadeT.HelpBack) { $global:RadeT.HelpBack = $true; Write-Host ('WIN help link=' + $global:RadeT.HelpLink + ' name=' + $ui.TourB.Text + ' back-on=' + $ui.View + ' same=' + ($ui.Sent.Text -eq $global:RadeT.HelpSent) + ' seen=' + (Test-TourSeen)) }
    if (-not $global:RadeT.Helped) { $global:RadeT.Helped = $true; $global:RadeT.HelpSent = $ui.Sent.Text; $global:RadeT.HelpLink = [bool]$ui.TourB.Shown; $ui.Form.Key('F1'); return $true } }
  return $false
}
# The primary button of the card on screen (UI standard v1: the last one), or the first shown button when it has none.
function global:Get-RadeMain { $m = @($ui.B | Where-Object { $_.Shown -and [string]$ui.Kinds[$_] -eq 'primary' }); if ($m.Count) { return $m[0] }; return @($ui.B | Where-Object { $_.Shown })[0] }
function global:Push-RadeButton([string]$Text) {
  if ($Text -eq 'Record' -and $ui.RecB.Shown) { $ui.RecB.PerformClick(); return }   # B7: the Record is the link "Record (F2)"
  if ($Text -in 'Back', 'Back (Esc)' -and $ui.BackB.Shown) { $ui.BackB.PerformClick(); return }   # B6: the one Back pattern
  foreach ($b in $ui.B) { if ($b.Shown -and $b.Text -eq $Text) { $b.PerformClick(); return } }
  throw ('the test user found no button "' + $Text + '" in view ' + $ui.View)
}
[RadeStub.Driver]::Pump = {
  if (-not $ui -or -not $ui.Form -or $ui.Form.Closed -or -not $ui.View) { return }
  if (-not $global:RadeT.Quick) { $global:RadeT.Quick = $true; $ui.GuardMs = 0; Start-RadeR31 }   # the test user acts at once, as if it had waited (the guard is tested on the first question)
  $key = [string]$ui.View + '|' + $ui.Sent.Text + '|' + $ui.Kick.Text
  if ($key -eq $global:RadeT.Seen) { return }
  $global:RadeT.Seen = $key
  Show-RadeCard
  $v = [string]$ui.View; if (Step-RadeR31 $v) { return }
  if ($v -eq 'choose') {
    if ($env:RADE_T_FAULT -eq 'noapps' -and -not $global:RadeT.FaultDone) { $global:RadeT.FaultDone = $true; $global:RadeT.Apps = $script:apps; $script:apps = @(); & $ui.VChoose; return }
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
  elseif ($v -eq 'boot' -and $env:RADE_T_FAULT -eq 'boot' -and -not $global:RadeT.FaultDone) { $global:RadeT.FaultDone = $true; $global:RadeT.RunBase = $ui.RunBase; $ui.RunBase = { throw 'The test made the boot checks fail' } }   # R28: a boot error has a card
  elseif ($v -eq 'booterr') { $ui.RunBase = $global:RadeT.RunBase; Push-RadeButton 'Try again' }
  elseif ($v -eq 'noapps') { $script:apps = $global:RadeT.Apps; & $ui.VChoose }   # R28: a paste with no application has a card
  elseif ($v -eq 'checking' -and $env:RADE_T_CANCEL -eq '1' -and -not $global:RadeT.Cancelled) { $global:RadeT.Cancelled = $true; Write-Host ('WIN cancel busy=' + $ui.Busy + ' always=' + $ui.Always[0]); Push-RadeButton 'Cancel' }   # R28: Cancel on the checking card goes back to Choose
  elseif ($v -eq 'maint') {
    if (-not $global:RadeT.Esc) { $global:RadeT.Esc = $true; Write-Host 'WIN esc'; $ui.Form.Key('Escape'); return }   # Esc = Back: Choose again; the user chooses the same application
    if ($env:RADE_T_START -eq 'maint') { Push-RadeButton ('Start ' + $script:app.Name); Write-Host ('WIN maint-start started=' + $ui.Started + ' closed=' + $ui.Form.Closed); Write-Host ('WIN closed=' + $ui.Form.Closed); return }   # R28: Start runs the checks, then starts the application
    @($ui.B | Where-Object { $_.Shown -and $_.Enabled -and $_.Text -notlike 'Start *' })[0].PerformClick()   # Repair (or Update)
  }
  elseif ($v -eq 'site') { $ui.Field.Text = 'not an address'; $ui.B[0].PerformClick(); Write-Host ('WIN site-note=' + $ui.Note.Text); $ui.Field.Text = 'https://rade-test.invalid/sites/fake'; $ui.B[0].PerformClick() }   # .invalid never resolves: the site check fails on every computer
  elseif ($v -in 'fail', 'need') {
    # The check on the card: the look-and-answer check is answered through its own card; any other is set to PASSED.
    $id = [string]@($script:appChecks)[([int]($ui.Kick.Text -replace '^CHECK (\d+) OF .*$', '$1')) - 1]
    if ($v -eq 'need' -and (Get-CheckDef $id).Kind -eq 'guide') { $ui.B[0].PerformClick(); return }
    if ($v -eq 'need' -and (Get-CheckDef $id).Kind -eq 'signin' -and -not $global:RadeT.SignIn) {   # a sign-in that failed: its card must offer the sign-in again
      $global:RadeT.SignIn = $true; $script:checkResults[$id] = @{ State = 'FAILED'; Detail = 'Sign-in was not finished'; Fix = 'Select "Sign in and check site rights"' }; & $ui.Next; return
    }
    if ($v -eq 'fail' -and (Get-RadeMain).Text -eq 'Run checks again' -and -not $global:RadeT.Again) {   # the check runs again and fails again
      $global:RadeT.Again = $true; Write-Host 'WIN again'; (Get-RadeMain).PerformClick(); return   # the cards that follow are answered by the calls inside this click
    }
    $script:checkResults[$id] = @{ State = 'PASSED'; Detail = 'Set by the test'; Fix = '' }
    & $ui.Next
  }
  elseif ($v -eq 'ready') {
    if ($env:RADE_T_START -eq 'maint') { return }   # Start on Maintenance: the window starts the application when the checks have passed
    if ($env:RADE_T_LINK -and $ui.FieldRow.Shown -and -not $global:RadeT.Linked) {   # R29 N8: a folder that does not exist is refused; then the folder of the test
      $global:RadeT.Linked = $true; $ui.Field.Text = (Join-Path $env:RADE_T_LINK 'no-such-folder'); Push-RadeButton 'Install'; Write-Host ('WIN link-bad view=' + $ui.View + ' note=' + $ui.Note.Text) }
    if (-not $global:RadeT.Min) {   # a minimized window: RADE brings it back when it needs the person; it has its own taskbar button
      $global:RadeT.Min = $true; $ui.Form.WindowState = 'Minimized'; & $ui.ToFront
      Write-Host ('WIN restored=' + $ui.Form.WindowState + ' taskbar=' + $ui.Form.Values['ShowInTaskbar'] + ' minbox=' + $ui.Form.Values['MinimizeBox'] + ' shown-by=' + [RadeStub.Driver]::ShownBy)
    }
    if ($global:RadeT.Record -and -not $global:RadeT.Opened) {
      $global:RadeT.Opened = $true
      $script:checkResults['ps'] = @{ State = 'PASSED'; Detail = 'Last check: 14 Nov 26'; Fix = 'Version [5.1]'; Saved = $true }   # a reused check, as Get-SavedCheck gives it
      Push-RadeButton 'Record'
      $ui.Form.Repaint()
      $all = New-Object 'System.Collections.Generic.List[System.Windows.Forms.Control]'; $ui.Rec.Walk($all)   # the Record's controls: each one that takes the focus has a ring
      foreach ($c in $all) { $t = $c.GetType().Name; if ($t -in 'Button', 'TextBox', 'CheckBox' -and -not ($c.Parent -and $c.Parent.Events.ContainsKey('Paint'))) { Write-Host ('WIN NOFOCUS ' + $t + ' "' + $c.Text + '" in the Record') } }
      $boxes = @($ui.RecSteps.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] })
      $lab = @($ui.RecSteps.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] })[0]
      Write-Host ('WIN measure record box=' + $boxes[0].Margin.Left + ',' + $boxes[0].Margin.Top + ' label=' + $lab.Margin.Left + ',' + $lab.Margin.Bottom + ' rows=' + (& $ui.RecPlan 400).Tall + ' one-line=' + (-not $boxes[0].AutoSize -and -not $boxes[0].Values.ContainsKey('AutoEllipsis')))
      Write-Host ('WIN record on=' + $ui.RecOn + ' rows=' + @($ui.RecData).Count + ' boxes=' + $boxes.Count + ' enabled=' + $boxes[0].Enabled + ' text=' + [bool]($ui.RecText.Text -match 'Files this round saves') + ' name=' + [bool]($ui.RecChecks.Values['AccessibleName'] -match 'PASSED') + ' reused=' + (@($ui.RecData | Where-Object { $_.Name -match '^PowerShell is version' })[0].More -join ' / ') + ' tall=' + ($ui.RecChecks.Height -gt 100) + ' box-text=' + (($boxes | ForEach-Object { $ui.Full[$_] }) -join '|') + ' box-name=' + ($boxes[1].Values['AccessibleName'] -replace '\. .*$', ''))
      Test-RadeRecordCopy; $ui.Form.Key('Next'); Write-Host ('WIN paged=' + $ui.RecScroll.Values['AutoScrollPosition'].Y); $ui.Form.Key('Prior')   # the names Windows gives Page Down and Page Up
      foreach ($b in $boxes) { if ([int]$b.Tag -lt 0) { $b.Checked = $false } }
      $ui.Form.Key('Escape'); Write-Host ('WIN record on=' + $ui.RecOn + ' clean=' + $ui.Clean)
    }
    # R28: an installed application with a start script has a Start button; it is the main one when the installed version is this paste's.
    $sb = @($ui.B | Where-Object { $_.Shown -and $_.Text -like 'Start *' })[0]
    if ($sb) {
      Write-Host ('WIN start-button=' + $sb.Text + ' main=' + $ui.Form.Values['AcceptButton'].Text)
      if ($env:RADE_T_START -eq '1') { $sb.PerformClick(); Write-Host ('WIN started=' + $ui.Started + ' closed=' + $ui.Form.Closed + ' note=' + $ui.Note.Text); Write-Host ('WIN closed=' + $ui.Form.Closed); return }
    }
    if ($env:RADE_T_LINK -and $ui.FieldRow.Shown) { $ui.Field.Text = $env:RADE_T_LINK }   # the folder is set last: the Record redraws the card
    $ib = @($ui.B | Where-Object { $_.Shown -and $_.Text -in 'Install', 'Run' })[0]; $ib.PerformClick()
  }
  elseif ($v -eq 'hand') {
    $m = { param($C) $(if ($C.AutoSize) { $C.Margin.Top + $C.PreferredSize.Height / 2.0 } else { $C.Margin.Top + $C.Height / 2.0 }) }
    Write-Host ('WIN mid hand label=' + (& $m $ui.FieldL) + ' box=' + (& $m $ui.FieldBox) + ' button=' + (& $m $ui.FieldB) + ' box-h=' + $ui.FieldBox.Height + ' button-h=' + $ui.FieldB.Height + ' gaps=' + ($ui.FieldL.Margin.Right + $ui.FieldBox.Margin.Left) + ',' + ($ui.FieldBox.Margin.Right + $ui.FieldB.Margin.Left) + ' inner=' + $ui.Field.Width + '/' + $ui.FieldBox.Width + ' tick=' + $ui.TickP.Margin.Left)
    Write-Host ('WIN mid header logo=' + ($ui.Logo.Margin.Top + $ui.Logo.Height / 2.0) + ' title=' + (& $m $ui.TitleCol) + ' word-in-title=' + [object]::ReferenceEquals($ui.WordL.Parent, $ui.TitleCol) + ' ink-left=' + ($ui.WordL.Margin.Left + (& $ui.Ink $ui.WordL)) + ',' + ($ui.AppL.Margin.Left + (& $ui.Ink $ui.AppL)) + "`n" + 'WIN mid approw shown=' + $ui.AppRow.Shown + ' link=' + $ui.LinkLine.Shown + ' applogo=' + $(if ($ui.AppLogo) { $ui.AppLogo.Margin.Top + $ui.AppLogo.Height / 2.0 } else { 'none' }) + ' app=' + (& $m $ui.AppL) + ' name=' + $ui.AppL.Text + ' logoname=' + $(if ($ui.AppLogo) { $ui.AppLogo.AccessibleName } else { 'none' })); Show-RadeTick
    $bc = @($ui.Body.Controls); $tc = @($ui.Tail.Controls)
    Write-Host ('WIN hand-order address-above-lines=' + ($bc.IndexOf($ui.FieldRow) -lt $bc.IndexOf($ui.Guide)) + ' lines-above-path=' + ($bc.IndexOf($ui.Guide) -lt $bc.IndexOf($ui.PathL) -and $bc.IndexOf($ui.PathL) + 1 -eq $bc.IndexOf($ui.PathT)) + ' path-above-links=' + ($bc.IndexOf($ui.PathT) -lt $bc.IndexOf($ui.LinkRow)) + ' closing-above-buttons=' + ($tc.IndexOf($ui.Close) + 1 -eq $tc.IndexOf($ui.BtnRow)) + ' closing-gap=' + $ui.BtnRow.Margin.Top)
    Write-Host ('WIN F tokens=' + ((@($ui.F.Keys) | Sort-Object) -join ',') + ' mono-only-in-record=' + [bool]([object]::ReferenceEquals($ui.RecText.Font, $ui.F.Mono) -and -not @($ui.F.Keys | Where-Object { $_ -ne 'Mono' -and $ui.F[$_].Name -eq 'Consolas' }).Count) + ' sent=' + $ui.F.Sent.Name + $ui.F.Sent.SizeInPoints + ' body=' + $ui.F.Body.Name + $ui.F.Body.SizeInPoints + ' small=' + $ui.F.Small.SizeInPoints + ' smallb=' + $ui.F.SmallB.Name + $ui.F.SmallB.SizeInPoints + ' help=' + $ui.Help.Font.SizeInPoints + ' kick=' + $ui.Kick.Font.Name + ' label=' + $ui.FieldL.Font.Name + ' plainbtn=' + $ui.B[1].Font.Name + ' link=' + $ui.CopyPathB.Font.Name + ' now=' + $ui.Now.Font.Name)
    if (-not $ui.Field.Shown -or $ui.Form.Values['AcceptButton']) { Write-Host 'WIN BAD hand card: no address box, or Enter answers' }
    $ui.FieldB.PerformClick(); if ($ui.CopyPathB.Shown) { $ui.CopyPathB.PerformClick() }; Write-Host ('WIN hand-note=' + $ui.Note.Text + ' clip=' + [bool][RadeStub.Driver]::Clip)
    if (-not $global:RadeT.NoAddr) {   # R28: one text for the lines (copy across lines gives the lines as written); a broken path copies whole; no address row without an address
      $global:RadeT.NoAddr = $true
      Write-Host ('WIN guide one-box=' + ($ui.Guide -is [System.Windows.Forms.RichTextBox]) + ' rtf=' + [bool]([string]$ui.Guide.Values['Rtf'] -match '\\li(\d+)\\fi-\1\\tx\1.* 1\.\\tab Open the import page\.') + ' selectable=' + ($ui.Guide.ReadOnly -and $ui.Guide.Values['ContextMenuStrip'] -eq $ui.Menu))
      $ui.Guide.SelectedText = "1.`tOpen the import page.`n" + [char]0x2007 + "2.`tChoose"; $ui.Guide.SelectionLength = 30; $null = & $ui.CopyText $ui.Guide; $c1 = [RadeStub.Driver]::Clip -replace "`r`n", '|'
      $ui.PathT.SelectedText = "C:\a`nb.zip"; $ui.PathT.SelectionLength = 9; $null = & $ui.CopyText $ui.PathT; Write-Host ('WIN guide-copy=' + $c1 + ' path-copy=' + [RadeStub.Driver]::Clip)
      Write-Host ('WIN elapsed=' + (& $ui.Elapsed 252) + '|' + (& $ui.Elapsed 5) + '|' + (& $ui.Elapsed 3725))
      $g0 = $ui.GUrl; $s0 = $ui.G.Step; $ui.GUrl = ''; $ui.G.Step = $s0.Clone(); $ui.G.Step.UrlConfig = ''; & $ui.VHand
      Write-Host ('WIN no-address field=' + $ui.FieldRow.Shown + ' close=' + $ui.Close.Text + ' focus-text=' + $ui.Guide.Focused + ' accept=' + [bool]$ui.Form.Values['AcceptButton'])
      $ui.GUrl = $g0; $ui.G.Step = $s0; & $ui.VHand
    }
    $hb = @($ui.B | Where-Object { $_.Shown }); $hm = (Get-RadeMain); if (-not @($hb | Where-Object { $_.Text -eq 'It failed' }).Count) { $hm.PerformClick() }   # B3: Done last; a look-and-answer check: Yes
    elseif ($global:RadeT.Hand -eq 'fail') { Push-RadeButton 'It failed' } elseif ($global:RadeT.Hand -eq 'skip') { @($hb | Where-Object { $_.Text -ne 'It failed' -and -not [object]::ReferenceEquals($_, $hm) })[0].PerformClick() } else { $hm.PerformClick() }
  }
  elseif ($v -eq 'answer') {
    Write-Host ('WIN sent-pt=' + $ui.Sent.Font.SizeInPoints + ' for "' + $ui.Sent.Text + '"')
    if (-not $global:RadeT.Guard) {   # a click at once after the card changed (the second click of a double-click on Done) is not an answer
      $global:RadeT.Guard = $true; $ui.GuardMs = 400; $ui.CardAt = $ui.Clock.Elapsed.TotalMilliseconds; $ui.B[0].PerformClick(); $held = ($null -eq $ui.Reply)
      Write-Host ('WIN guard held=' + $held + ' then=' + $ui.B[0].Text)
      $now = $ui.Clock.Elapsed.TotalMilliseconds; $ui.CardAt = $now + 1000000; $fut = [bool](& $ui.Settled); $ui.CardAt = $now - 401; $aft = [bool](& $ui.Settled); $ui.CardAt = $ui.Clock.Elapsed.TotalMilliseconds - 100; $win = [bool](& $ui.Settled); $ui.GuardMs = 0
      Write-Host ('WIN clock future=' + $fut + ' after400=' + $aft + ' within=' + $win)
      $sp = 'ab' + [char]::ConvertFromUtf32(0x1F600) + 'cd'; $pcs = @((& $ui.BreakLong $sp $ui.F.Body 21) -split "`n")
      Write-Host ('WIN surrogate pieces=' + $pcs.Count + ' whole=' + (-not @($pcs | Where-Object { $_ -match '[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]' }).Count -and ($pcs -join '') -eq $sp))
      $pl = New-Object System.Windows.Forms.Label; & $ui.Shorten $pl 'abcdefghij' 50
      & $ui.SetWrap $ui.P[1] 50; $ui.P[1].Text = 'see abcdefghijkl'; & $ui.BreakAll; $bb = ($ui.P[1].Text -eq "see abcdefg`nhijkl"); $ui.P[1].Text = ''
      Write-Host ('WIN shorten=' + $pl.Text + ' body-break=' + $bb)
      Write-Host ('WIN break=' + ((& $ui.BreakLong 'abcdefghij' $ui.F.Body 21) -replace "`n", '|') + ' word-bad=' + (& $ui.WordBad 'fixture' 'P0' 'abcdefghij' $ui.F.Body 50) + ' word-ok=' + ($null -eq (& $ui.WordBad 'fixture' 'P0' 'abc def ghi' $ui.F.Body 50)))
    }
    if ($ui.FieldRow.Shown) { Write-Host ('WIN mid answer above=' + $ui.FieldAbove + ' box-top=' + $ui.FieldBox.Margin.Top + ' box-left=' + $ui.FieldBox.Margin.Left + ' box-w=' + ($ui.FieldBox.Width - $ui.ContentW) + ' h=' + $ui.FieldBox.Height) }   # R31 L3: the box under its label, on the card's edge, as wide as the text
    if ($ui.FieldRow.Shown) { Write-Host ('WIN answer-box max=' + $ui.Field.Values['MaxLength'] + ' enter=' + $ui.Form.Values['AcceptButton'].Text + ' focus=' + $ui.Field.Focused); $ui.Field.Text = '  Mail someone@example.com about it  '; $ui.Form.Values['AcceptButton'].PerformClick() }
    elseif ($ui.B[0].Text -eq 'Yes') { Push-RadeButton 'No' } else { $ui.B[1].PerformClick() }
  }
  elseif ($v -eq 'handfail') { $ui.ErrBox.Text = 'Import failed: flow https://usaf.dps.mil/sites/fake/x not found'; $ui.B[0].PerformClick() }
  elseif ($v -in 'done', 'review', 'stopped') {
    [RadeStub.Driver]::Clip = ''
    foreach ($b in @($ui.RecB)) { if ($b.Shown -and (Test-Deploy)) { $b.PerformClick(); Write-Host ('WIN made=' + [bool]($ui.RecText.Text -match "Made by this app's installs") + ' log=' + [bool]($ui.RecText.Text -match '(?m)^LOG') + ' locked=' + (-not @($ui.RecSteps.Controls | Where-Object { $_ -is [System.Windows.Forms.CheckBox] })[0].Enabled)); $ui.RecClose.PerformClick() } }
    $ui.Form.Key('F2'); $ui.Form.Repaint(); $ui.Form.Key('F2')
    Write-Host ('WIN layline=' + ((& $ui.LayLine) -replace "`r`n", ' ~ '))
    $ok = @(& $ui.RowBad 'fixture' 'FieldRow' @(@{ N = 'FieldL'; Top = 10; H = 18; Kind = 'other' }, @{ N = 'FieldBox'; Top = 4; H = 30; Kind = 'box' }, @{ N = 'FieldB'; Top = 4; H = 30; Kind = 'button' })) + @(& $ui.EdgeBad 'fixture' @(@{ N = 'Kick'; X = 125 }, @{ N = 'Sent'; X = 126 }, @{ N = 'P0'; X = 125 }, @{ N = 'B0'; X = 125 }))
    $no = @(& $ui.RowBad 'fixture' 'FieldRow' @(@{ N = 'FieldL'; Top = 13; H = 18; Kind = 'other' }, @{ N = 'FieldBox'; Top = 4; H = 23; Kind = 'box' }, @{ N = 'FieldB'; Top = 4; H = 30; Kind = 'button' })) + @(& $ui.EdgeBad 'fixture' @(@{ N = 'Kick'; X = 123 }, @{ N = 'Sent'; X = 126 }, @{ N = 'P0'; X = 123 }, @{ N = 'B0'; X = 124 }))
    Write-Host ('WIN rule aligned=' + $ok.Count + ' misaligned=' + $no.Count + ' ~ ' + ($no -join ' ~ '))
    # A row that wraps: the check box alone on the second line is aligned on its own line; on the first line it is not.
    $wrap = @(& $ui.RowBad 'fixture' 'TestRow' @(@{ N = 'TestL'; Top = 10; H = 18; Line = 0; Kind = 'other' }, @{ N = 'ToBoxF'; Top = 4; H = 30; Line = 0; Kind = 'box' }, @{ N = 'OkBox'; Top = 48; H = 20; Line = 38; Kind = 'other' }))
    $wbad = @(& $ui.RowBad 'fixture' 'TestRow' @(@{ N = 'TestL'; Top = 10; H = 18; Line = 0; Kind = 'other' }, @{ N = 'ToBoxF'; Top = 4; H = 30; Line = 0; Kind = 'box' }, @{ N = 'OkBox'; Top = 48; H = 20; Line = 0; Kind = 'other' }))
    Write-Host ('WIN rule wrapped=' + $wrap.Count + ' one-line=' + $wbad.Count + ' ~ ' + ($wbad -join ' ~ ')); Show-RadeR29bRules
    foreach ($b in $ui.B) { if ($b.Shown -and $b.Text -in 'Copy summary', 'Copy the log') { $b.PerformClick() } }
    Write-Host ('WIN copied=' + [bool]([RadeStub.Driver]::Clip -match 'Application: ') + ' note=' + $ui.Note.Text)
    if ($ui.TestRow.Shown) { $ui.DraftB.PerformClick(); Write-Host ('WIN draft-note=' + $ui.Note.Text) }
    Push-RadeButton 'Close'; Write-Host ('WIN closed=' + $ui.Form.Closed)
  }
}
