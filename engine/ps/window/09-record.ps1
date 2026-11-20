# RADE window part 09, the Record (F2): lists the checks, the steps and the log, and closes it again.
# Builds on the Record parts in 04-record-parts.ps1.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# ---- The Record
# Returns the text color of a state in the Record (green PASSED, red FAILED or NEEDS REVIEW, ...). Takes the state.
$ui.StateInk = { param([string]$St) $(if ($St -eq 'PASSED') { $ui.C.GreenInk } elseif ($St -in 'FAILED', 'NEEDS REVIEW') { $ui.C.Red } elseif ($St -in 'WARNING', 'RUNNING') { $ui.C.Navy } else { $ui.C.Gray }) }   # the word is always shown: never color alone
$ui.RecRows = {
  # The checks to list: the chosen application's, or (before a choice) the base checks. Group, name, state, and the rows under it.
  $ids = $(if ($ui.Picked) { @($script:appChecks) } else { @($ui.BaseIds) }); $rows = @(); $g0 = ''
  foreach ($id in $ids) {
    $d = Get-CheckDef $id; $r = $(if ($ui.Picked) { $script:checkResults[$id] } else { $ui.BaseRes[$id] }); if (-not $r) { $r = @{ State = 'NOT RUN'; Detail = ''; Fix = '' } }
    if ([string]$d.Group -ne $g0) { $g0 = [string]$d.Group; $rows += @{ Head = $g0.ToUpperInvariant() } }
    $nm = [string]$d.Short; if (-not $nm) { $nm = [string]$d.Name }
    $rows += @{ Name = $nm; State = [string]$r.State; More = $(if ($r.State -ne 'PASSED' -or $r.Saved) { @(@($r.Detail, $r.Fix) | Where-Object { $_ }) } else { @(@($r.Detail) | Where-Object { $_ }) }) }   # not passed: what was found, then what to do; reused (Get-SavedCheck): "Last check: 17 Nov 26", then what it found; passed (R33): what it found
  }
  return $rows }
$ui.RecPlan = { param([int]$w)
  # Where each row of the check list goes. The result word has its own column (as wide as the widest plain result
  # word): no name and no detail enters it. A qualifier ("fallback") goes under the word in gray. A name and each
  # detail wrap to 2 lines at most.
  $h0 = [System.Windows.Forms.TextRenderer]::MeasureText('Ag', $ui.F.Small).Height; $hc = [System.Windows.Forms.TextRenderer]::MeasureText('Ag', $ui.F.SmallB).Height; $v = & $ui.Sc 3
  $sw = 0; foreach ($t in 'NOT RUN', 'WARNING', 'RUNNING', 'PASSED', 'FAILED', 'fallback') { $sw = [math]::Max($sw, [System.Windows.Forms.TextRenderer]::MeasureText($t, $ui.F.SmallB).Width) }
  $sw += & $ui.Sc 4; $lw = [math]::Max((& $ui.Sc 60), ($w - $sw - (& $ui.Sc 8))); $in = & $ui.Sc 12; $y = 0; $rows = @()
  foreach ($r in @($ui.RecData)) {
    if ($r.Head) { $y += & $ui.Sc 8; $rows += @{ R = $r; Y = $y; H = ($h0 + $v) }; $y += $h0 + $v; continue }
    $word = [string]$r.State; $qual = ''; if ($word -match '^(.+?) \((.+)\)$') { $word = $Matches[1]; $qual = $Matches[2] }
    $nh = (& $ui.Rows ([string]$r.Name) $ui.F.Small $lw $h0 2) * $h0 + $v; if ($qual) { $nh = [math]::Max($nh, (2 * $hc + $v)) }
    $more = @(); $my = $y + $nh
    foreach ($m in @($r.More)) { $mh = (& $ui.Rows ([string]$m) $ui.F.Small ($lw - $in) $h0 2) * $h0 + $v; $more += @{ T = [string]$m; Y = $my; H = $mh }; $my += $mh }
    $rows += @{ R = $r; Y = $y; H = $nh; Word = $word; Qual = $qual; More = $more }; $y = $my
  }
  return @{ Rows = $rows; Tall = $y; Sw = $sw; Lw = $lw; In = $in; H0 = $h0; Hc = $hc } }
$ui.RecChecks.Add_Paint({
  try {
    $g = $_.Graphics; $g.Clear($ui.C.White); $w = $this.ClientSize.Width; $pl = & $ui.RecPlan $w; $sw = $pl.Sw; $lw = $pl.Lw
    $wrap = 'Left, Top, NoPrefix, WordBreak, EndEllipsis, TextBoxControl'
    foreach ($q in @($pl.Rows)) {
      $r = $q.R
      if ($r.Head) { & $ui.Word $g ([string]$r.Head) $ui.F.SmallB $ui.C.Gray 0 $q.Y $w $q.H 'Left, VerticalCenter, NoPrefix, SingleLine'; continue }
      & $ui.Word $g ([string]$r.Name) $ui.F.Small $ui.C.Navy 0 ($q.Y + (& $ui.Sc 1)) $lw ($q.H - (& $ui.Sc 1)) $wrap
      & $ui.Word $g ([string]$q.Word) $ui.F.SmallB (& $ui.StateInk ([string]$q.Word)) ($w - $sw) ($q.Y + (& $ui.Sc 2)) $sw $pl.Hc 'Right, Top, NoPrefix, SingleLine'
      if ($q.Qual) { & $ui.Word $g ([string]$q.Qual) $ui.F.Small $ui.C.Gray ($w - $sw) ($q.Y + (& $ui.Sc 2) + $pl.Hc) $sw $pl.Hc 'Right, Top, NoPrefix, SingleLine' }
      foreach ($m in @($q.More)) { & $ui.Word $g $m.T $ui.F.Small $ui.C.Gray $pl.In ($m.Y + (& $ui.Sc 1)) ($lw - $pl.In) ($m.H - (& $ui.Sc 1)) $wrap }   # what was found, then what to do
    }
  } catch { $null = $_ } })
# Reads the check results again while the Record is open (R33: a check that ended after F2 still showed NOT RUN). Takes
# nothing; does nothing when the Record is closed. Called after each check result of the window's check runs.
$ui.RecRefresh = { if (-not $ui.RecOn) { return }
  try { $ui.RecData = @(& $ui.RecRows); & $ui.RecTall; & $ui.RecName; $ui.RecChecks.Invalidate() } catch { $null = $_ } }   # a form being closed: nothing to redraw
# Sets the screen-reader text of the check list from $ui.RecData. Takes nothing.
$ui.RecName = { $ui.RecChecks.AccessibleName = 'Checks. ' + ((@($ui.RecData) | ForEach-Object { if ($_.Head) { $_.Head + ':' } else { $_.Name + ' ' + $_.State + $(if (@($_.More).Count) { ', ' + (@($_.More) -join ', ') } else { '' }) } }) -join '. ') }
# The whole Record as plain text, for Copy all (R33): the title, each check with its result and its detail lines, each step
# box with its state, then the text box (files, made list, log). Takes nothing; gives back the text with Windows line ends.
$ui.RecAll = {
  $t = @([string]$ui.RecTitle.Text, '', 'CHECKS')
  foreach ($r in @($ui.RecData)) { if ($r.Head) { $t += ('  ' + $r.Head) } else { $t += ('    ' + $r.State + ': ' + $r.Name); foreach ($m in @($r.More)) { $t += ('      ' + [string]$m) } } }
  $t += @('', 'STEPS')
  foreach ($c in @($ui.RecSteps.Controls)) {
    if ($c -is [System.Windows.Forms.CheckBox]) { $fu = $ui.Full[$c]; $t += ('  [' + $(if ($c.Checked) { 'x' } else { ' ' }) + '] ' + $(if ($null -ne $fu) { [string]$fu } else { [string]$c.Text })) }
    elseif ([string]$c.Text -and [string]$c.Text -ne 'STEPS') { $t += ('      ' + [string]$c.Text) } }
  $t += ''; $t += @(([string]$ui.RecText.Text) -split "`r?`n")
  return ((@($t) -join "`r`n").TrimEnd() + "`r`n") }
# Copy all: puts $ui.RecAll on the clipboard and says so on the button until the Record opens again. Takes nothing.
$ui.RecCopyAll = { try { [System.Windows.Forms.Clipboard]::SetText((& $ui.RecAll)); $ui.RecCopy.Text = 'Copied' } catch { $ui.RecCopy.Text = 'Not copied' } }
# Sets the height of the check list to the height of its rows. Takes nothing; does nothing before the window has its
# scale.
$ui.RecTall = { if (-not $ui.Scaled) { return }; try { $t = (& $ui.RecPlan $ui.RecChecks.ClientSize.Width).Tall + (& $ui.Sc 4); if ($ui.RecChecks.Height -ne $t) { $ui.RecChecks.Height = $t } } catch { $null = $_ } }
$ui.RecChecks.Add_Resize({ if ($ui.RecOn -and [int]$ui.RecW -ne [int]$this.ClientSize.Width) { $ui.RecW = [int]$this.ClientSize.Width; & $ui.RecTall }; $this.Invalidate() })
# The step list: a label or a long step name wraps at the column's width, also after the window changes its size.
$ui.RecFit = { if (-not $ui.Scaled) { return }; try { $mw = [math]::Max((& $ui.Sc 120), ($ui.RecSteps.ClientSize.Width - (& $ui.Sc 28))); foreach ($l in @($ui.RecSteps.Controls)) { if ($l -is [System.Windows.Forms.CheckBox]) { $fu = $ui.Full[$l]; if ($null -ne $fu) { & $ui.Shorten $l ([string]$fu) $mw }; $l.Size = New-Object System.Drawing.Size($mw, $l.PreferredSize.Height) } else { $l.MaximumSize = New-Object System.Drawing.Size($mw, 0) } } } catch { $null = $_ } }   # a step box is one line, as wide as the column, and ends with "..." when its text is longer
$ui.RecSteps.Add_SizeChanged({ & $ui.RecFit })
& $ui.Ring $ui.RecSteps; & $ui.Ring $ui.Rec; & $ui.Cue $ui.RecText   # focus is always visible: the step boxes and the text box too
# Opens the Record (F2): every check, the step boxes, the files, the made list and the log, sized to its rows.
$ui.VRecord = {
  & $ui.Check
  if ($ui.View -eq 'ready' -and -not $ui.Running) { $ui.Edit = $true }   # B7 (UI standard v1): the Record is a link only; opened from Ready, its boxes can change
  $ui.RecOn = $true; $ui.RecData = @(& $ui.RecRows)
  $ui.RecW = 0; & $ui.RecTall   # as tall as its rows (the same plan as the Paint handler)
  & $ui.RecName; $ui.RecCopy.Text = 'Copy all'
  $old = @($ui.RecSteps.Controls); $ui.RecSteps.Controls.Clear(); foreach ($o in $old) { $o.Dispose() }; $ui.Full = @{}
  # Adds one label to the Steps part of the Record. Takes the text, the font and the color; gives back nothing.
  $mk = { param([string]$Text, $Font, $Color) $l = New-Object System.Windows.Forms.Label; $l.AutoSize = $true; $l.UseMnemonic = $false; $l.MaximumSize = New-Object System.Drawing.Size(([math]::Max((& $ui.Sc 120), $ui.RecSteps.ClientSize.Width - (& $ui.Sc 24))), 0); $l.Text = $Text; $l.Font = $Font; $l.ForeColor = $Color; $l.Margin = (& $ui.Pad (& $ui.Sc 5) 0 0 (& $ui.Sc 6)); [void]$ui.RecSteps.Controls.Add($l) }
  & $mk 'STEPS' $ui.F.SmallB $ui.C.Gray
  if (-not $ui.Picked) { & $mk 'Choose an application first.' $ui.F.Small $ui.C.Gray }
  else {
    if (-not $ui.Edit) { & $mk $(if ($ui.Running) { 'The run has started: the boxes are locked.' } else { 'To change the boxes, go to "Ready" and select "Record (F2)".' }) $ui.F.Small $ui.C.Gray }
    $list = @(); if ($cleanup.Count) { $list += -1 }; $list += @($script:appSteps); $n = 0
    foreach ($k in $list) {
      $cb = New-Object System.Windows.Forms.CheckBox
      $cb.AutoSize = $false; $cb.UseMnemonic = $false; $cb.Margin = (& $ui.Pad (& $ui.Sc 5) (& $ui.Sc 4) (& $ui.Sc 4) (& $ui.Sc 4)); & $ui.Cue $cb; $cb.Enabled = [bool]$ui.Edit; $cb.Tag = [int]$k; $cb.Font = $ui.F.SmallB; $cb.ForeColor = $ui.C.Navy
      if ($k -lt 0) { $cb.Text = 'Clean-up'; $cb.Checked = [bool]$ui.Clean; $more = 'Moves finished files to the Recycle Bin' }
      else {
        $n++; $s1 = $steps[$k]; $cb.Checked = [bool]$ui.Sel[[int]$k]
        $cb.Text = [string]$n + '  ' + (Get-StepTitle $s1) + $(if ($s1.AskParam) { '  (asks for a folder)' } elseif ($s1.Kind -eq 'guide') { '  (needs you)' } else { '' })
        $more = $(if ($ui.StepState[[int]$k]) { [string]$ui.StepState[[int]$k] } elseif ((Test-Deploy) -and -not [bool]$s1.Optional -and -not (Get-StepDefault $k)) { 'Already done for version ' + $script:app.Version + '. Tick the box to run it again' } else { [string]$s1.Note })
      }
      $cb.AccessibleName = $cb.Text + $(if ($more) { '. ' + $more } else { '' }); $ui.Full[$cb] = [string]$cb.Text   # the full name; the box may show it shortened ($ui.RecFit)
      $cb.Add_CheckedChanged({ if ([int]$this.Tag -lt 0) { $ui.Clean = [bool]$this.Checked } else { $ui.Sel[[int]$this.Tag] = [bool]$this.Checked } })
      [void]$ui.RecSteps.Controls.Add($cb)
      if ($more) { & $mk $more $ui.F.Small (& $ui.StateInk $more) }
    }
  }
  $t = @()
  if ($ui.Picked) {
    if (-not $ui.Plan) { $ui.Plan = Get-RoundPlan }
    $t += $ui.Plan.Lines
    if (Test-Deploy) { $ml = @(Get-MadeLine); if ($ml.Count) { $t += ''; $t += $ml } else { $t += @('', 'The installs of this application have made nothing yet.') } }
  }
  if ($ui.Log.Count -or $ui.Running) { $t += @('', 'LOG'); $t += @($ui.Log) }
  $ui.RecText.Text = ($t -join "`r`n") + "`r`n"   # ends with a line break: a live log line is added below
  $ui.RecTitle.Text = 'Record' + $(if ($ui.Picked) { $dot + $script:app.Name } else { '' })
  & $ui.RecFit
  $ui.Card.Visible = $false; $ui.Rec.Visible = $true; & $ui.RecTall; $ui.RecChecks.Invalidate(); $ui.RecB.Visible = $false; $ui.TourB.Visible = $false; $ui.BackB.Visible = $false; $ui.FeedB.Visible = $false
  try { [void]$ui.RecClose.Focus() } catch { $null = $_ } }
# Closes the Record and shows the card again; redraws the ready card when a step box was changed. Takes nothing.
$ui.CloseRecord = {
  & $ui.Check
  $ui.RecOn = $false; $ui.Rec.Visible = $false; $ui.Card.Visible = $true; $ui.RecB.Visible = $true; $ui.TourB.Visible = ($ui.HelpViews -contains [string]$ui.View); $ui.BackB.Visible = [bool]$ui.Back; $ui.FeedB.Visible = [bool]((& $ui.NoteOn) -and [string]$ui.View -notin $ui.NoNoteViews)
  if ($ui.Edit) { $ui.Edit = $false; if ($ui.View -eq 'ready') { & $ui.VReady } }   # the plan line follows the boxes
  try { [void]$ui.RecB.Focus() } catch { $null = $_ } }
$ui.RecB.Add_Click({ & $ui.VRecord })
$ui.FeedB.Add_Click({ if (& $ui.Settled) { & $ui.VNote } })   # B13: the feedback card for the card on screen
$ui.RecClose.Add_Click({ & $ui.CloseRecord })
$ui.RecCopy.Add_Click({ & $ui.RecCopyAll })
$ui.BackB.Add_Click({ if ((& $ui.Settled) -and $ui.Back -and -not $ui.RecOn -and -not $ui.Busy -and -not $ui.Running) { & $ui.Back } })

