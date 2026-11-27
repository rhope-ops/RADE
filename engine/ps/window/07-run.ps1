# RADE window part 07, the run: the callbacks Invoke-Round uses (log line, tick, step state), the Run button,
# and the Done, Needs review and Stopped cards. Uses the card parts and Invoke-Round.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# ---- The run. Invoke-Round calls back: a log line ($ui.Say), a tick ($ui.Tick), a step that starts ($ui.OnStatus) and
# a step that ends ($ui.OnStep). A step you do by hand comes in through $script:guideUi, what a step does now through
# $script:nowUi, and the last question of a test round through $script:feedbackUi.
$ui.Say = { param($t) Add-RunLog $t; $ui.Log.Add([string]$t); if ($ui.RecOn) { try { $ui.RecText.AppendText([string]$t + "`r`n") } catch { $null = $_ } }; try { [System.Windows.Forms.Application]::DoEvents() } catch { $null = $_ } }
# L7 (the Administrator, 2026-11-19): the now-doing line under the step's bar. The engine calls this ($script:nowUi) with a
# plain sentence for each item a step script reports (Get-NowText) and for a NOW line. Cards v2 (plan engine-v48 step 5):
# the text as written, with no "..." added; it wraps to $ui.NowLines lines and the line keeps its room. Takes the text.
$ui.ShowNow = { param([string]$Text) try { if ($ui.View -eq 'run') { $ui.NowRaw = $Text.Trim(); & $ui.CutNow; $ui.Now.Visible = $true } } catch { $null = $_ } }   # a line that cannot show never stops a step
# Shows the whole now-doing text ($ui.NowRaw) in $ui.NowLines lines at the line's wrap width (a text longer than that, over
# the manifest's 80 characters, is cut at the end of the last line); runs again after a resize ($ui.BreakAll). Takes nothing.
$ui.CutNow = { try { $w = [int](& $ui.GetWrap $ui.Now); $x = [string]$ui.NowRaw; if ($x) { $x = & $ui.FitLines (& $ui.BreakLong $x $ui.Now.Font $w) $ui.Now.Font $w $ui.NowLines }; if ([string]$ui.Now.Text -cne $x) { $ui.Now.Text = $x } } catch { $null = $_ } }   # a line that cannot show never stops a step
# The engine's callback for the now-doing line (Add-StepLine): shows the text and emits nothing. Takes the text.
$script:nowUi = { param($t) $null = & $ui.ShowNow ([string]$t) }
# L8 (the Administrator, 2026-11-19): a step stays on the Run card for $ui.Layout.StepMs (engine/window.json) at least, so a
# run of fast steps does not flicker. Waits out the rest of that time since the step showed. Takes nothing.
$ui.HoldStep = {
  while ($ui.View -eq 'run' -and $null -ne $ui.StepAt -and -not $script:closing -and -not $ui.Form.IsDisposed -and ($ui.Clock.Elapsed.TotalMilliseconds - [double]$ui.StepAt) -lt [double]$ui.Layout.StepMs) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 15 } }
# Draws the progress: both bars, the time in the step, the step fraction and the overall percent (the Administrator, 2026-11-19:
# the percent only). Takes nothing; does nothing when no step runs.
$ui.Paint = {
  if (-not $script:prog -or -not $script:stepStart) { return }
  $g = Get-Progress
  $all = [math]::Max($g.All, $ui.Bars['all'].Target); & $ui.SetBar 'all' $all $true; & $ui.SetBar 'run' $all $true; & $ui.SetBar 'step' ([math]::Max($g.StepShown, $ui.Bars['step'].Target)) $true
  if ($ui.View -ne 'run') { return }
  & $ui.ShowTime
  $fr = $(if ($script:prog.Frac -ge 0) { [string]$script:prog.FracText } else { '' }); if ($ui.StepFrac.Text -ne $fr) { $ui.StepFrac.Text = $fr }   # one size ($ui.FixW): the bar keeps its width
  # Cards v2: one percent for the whole run, on the card beside its bar (the bottom line has none).
  $rt = [string][int]($g.All * 100) + ' %'; if ($ui.PctL.Text -ne $rt) { $ui.PctL.Text = $rt } }
# The time in this step (R28 N10): "4m 12s"; with hours "1h 04m 12s".
$ui.Elapsed = { param([double]$Sec) $q = [int][math]::Floor([math]::Max(0, $Sec)); $h = [int][math]::Floor($q / 3600); $m = [int][math]::Floor(($q % 3600) / 60); $x = $q % 60
  if ($h) { return ('{0}h {1:00}m {2:00}s' -f $h, $m, $x) }; return ('{0}m {1:00}s' -f $m, $x) }
# Shows the time in this step on the step line, once for each second. The time keeps one size from its widest value
# ($ui.FixW), so the bar beside it never changes its width. Takes nothing; a failure is ignored.
$ui.ShowTime = { try { if ($ui.View -eq 'run' -and $script:stepStart) { $t = & $ui.Elapsed ((Get-Date) - $script:stepStart).TotalSeconds; if ($ui.StepTime.Text -ne $t) { $ui.StepTime.Text = $t } } } catch { $null = $_ } }
$ui.TimeT = New-Object System.Windows.Forms.Timer; $ui.TimeT.Interval = 1000; $ui.TimeT.Add_Tick({ & $ui.ShowTime })
# The tick callback of a running step: repaints the bars and lets the window handle its events. Emits nothing.
$ui.Tick = { $null = & $ui.Paint; [System.Windows.Forms.Application]::DoEvents() }   # a callback must emit nothing: its output would join the engine function's return value
# Returns the title the window shows for a step (its manifest title, else its name). Takes the step name.
$ui.TitleOf = { param([string]$Name) foreach ($s in @($steps)) { if ([string]$s.Name -ceq $Name) { return (Get-StepTitle $s) } }; return $Name }   # the title of the step with this name
# ---- The step list of the Run card (plan engine-v48 step 3, Cards v2). $ui.RunList has one row for each step of this
# run (Clean-up first when it runs): @{ Key (the step name, or 'Clean-up'); Title; Sub (the second line); State }. The
# running row is the tinted $ui.RunRow; the row before it and the rows after it are drawn in $ui.RunA and $ui.RunB.
$ui.RunList = @()
# The status of a row: its word and the token of its color. Takes the state word; gives back @(word, token).
$ui.RunMark = { param([string]$S) switch ($S) { 'PASSED' { @('PASSED', 'GreenInk') } 'DONE' { @('DONE', 'GreenInk') } 'SKIPPED' { @('SKIPPED', 'Gray') }
    'FAILED' { @('FAILED', 'Red') } 'NEEDS REVIEW' { @('NEEDS REVIEW', 'Red') } 'INTERRUPTED' { @('STOPPED', 'Red') } default { @('WAITING', 'Gray') } } }
# Makes the rows of this run from the steps that are on. Takes the selection (one flag for each step); sets $ui.RunList.
$ui.MakeRunList = { param($Sel)
  $ui.RunList = @(); if ($cleanup.Count -and $ui.Clean -and -not $script:resume) {   # a resume runs no clean-up (Invoke-Round)
  $ui.RunList += @{ Key = 'Clean-up'; Title = 'Clean-up'; Sub = ''; State = '' } }
  for ($k = 0; $k -lt $steps.Count; $k++) { if ($Sel[$k]) { $ui.RunList += @{ Key = [string]$steps[$k].Name; Title = (Get-StepTitle $steps[$k]); Sub = [string]$steps[$k].Doing; State = '' } } } }
# The room the Run card has for drawn rows: the card's height less its header, its body without the lists and its
# buttons (each as tall as its parts ask for), so the card never scrolls for its lists (the Windows job of PR 211: fixed
# thresholds made the Run card scroll at 1004 x 577 with long texts). Takes nothing; gives back pixels (0 at least).
$ui.RunRoom = { $ph = { param($C) $h = 0; try { $h = [int]$C.GetPreferredSize((New-Object System.Drawing.Size(0, 0))).Height } catch { $null = $_ }; [math]::Max($h, [int]$C.Height) }   # no measure: its height
  return [int][math]::Max(0, [int]$ui.Card.ClientSize.Height - (& $ph $ui.Head) - (& $ph $ui.Body) - (& $ph $ui.Tail) - (& $ui.Sc $ui.Z.G2)) }
$ui.RunMost = 4   # at most 4 drawn rows beside the running one (the Cards v2 mock: 5 rows in all)
# The width of a drawn row's texts (the row less the status column and the side room). Takes the row width.
$ui.RunTextW = { param([int]$W) [int][math]::Max(1, $W - (& $ui.Sc 120) - 2 * (& $ui.Sc $ui.Z.G2)) }
# The height of one drawn row slot (R35, the Administrator, 2026-11-19: values do not move anything): the tallest row this
# run can have, from the longest name of all its steps (2 lines at most) and a second line of 2 lines, 44 px at least.
# Takes the width; gives back pixels.
$ui.RunSlotOf = { param([int]$W)
  $h1 = & $ui.LineH $ui.F.SmallB; $h2 = & $ui.LineH $ui.F.Small; $tw = & $ui.RunTextW $W; $n1 = 1
  foreach ($x in @($ui.RunList)) { $n1 = [math]::Max($n1, (& $ui.Rows ([string]$x.Title) $ui.F.SmallB $tw $h1 2)) }
  return [int][math]::Max((& $ui.Sc 44), $n1 * $h1 + 2 * $h2 + (& $ui.Sc $ui.Z.G3)) }
$ui.RunCap = @{}; $ui.RunSlotH = 0; $ui.RunN = 0; $ui.RunKey = ''   # the slots of each list, the slot height, the slots in all, the size they are for
# Sizes one drawn list to its slots (not to its rows: a list keeps its height from step to step). Takes the panel.
$ui.SizeRuns = { param($P) $P.Height = [math]::Max(1, [int]$ui.RunCap[$P] * [int]$ui.RunSlotH)
  $P.AccessibleDescription = (@($P.Tag) | ForEach-Object { [string]$_.Title + ': ' + (& $ui.RunMark ([string]$_.State))[0] }) -join '; ' }
# The number of row slots the Run card has room for at this window size (R35: once for a size, again only after a
# resize, so the parts never move from step to step). Takes nothing; sets $ui.RunN, $ui.RunSlotH and $ui.RunKey.
$ui.RunFit = { $key = [string]$ui.Card.ClientSize.Width + 'x' + $ui.Card.ClientSize.Height; if ($ui.RunKey -eq $key) { return }
  foreach ($p in @($ui.RunA, $ui.RunB)) { $ui.RunCap[$p] = 0; $p.Visible = $false }   # first the card with no list: its room ($ui.RunRoom)
  try { $ui.Card.PerformLayout() } catch { $null = $_ }; $ui.RunSlotH = & $ui.RunSlotOf ([int]$ui.RunA.Width)
  $ui.RunN = [int][math]::Min($ui.RunMost, [math]::Floor((& $ui.RunRoom) / [math]::Max(1, $ui.RunSlotH))); $ui.RunKey = $key }
# Puts the rows around the running step into the lists: one slot for the step before it (empty on the first step), the
# other slots for the steps after it. The slots keep their heights from step to step. Takes nothing.
$ui.PlaceRuns = {
  $all = @($ui.RunList); $r = -1; for ($i = 0; $i -lt $all.Count; $i++) { if ($all[$i].State -eq 'RUNNING') { $r = $i } }
  $ui.StepSum.Text = $(if ($r -ge 0) { [string]$all[$r].Sub } else { '' }); $ui.StepSum.Visible = $true   # its room is the longest summary ($ui.Range)
  & $ui.RunFit; $na = [int][bool]$ui.RunN; $a = @(); if ($na -and $r -gt 0) { $a = @($all[$r - 1]) }
  $b = @(); for ($i = $r + 1; $i -lt $all.Count -and $b.Count -lt ($ui.RunN - $na); $i++) { $b += $all[$i] }
  $ui.RunA.Tag = $a; $ui.RunB.Tag = $b; $ui.RunCap[$ui.RunA] = $na; $ui.RunCap[$ui.RunB] = $ui.RunN - $na
  foreach ($p in @($ui.RunA, $ui.RunB)) { & $ui.SizeRuns $p; $p.Visible = [bool]$ui.RunCap[$p] }   # only the Run card shows them ($ui.Dress hides them)
  $ui.RunA.Invalidate(); $ui.RunB.Invalidate(); & $ui.Squeeze }
# Marks the step that starts as running, and a row that was running and has no result as done. Takes the step name.
$ui.RunStart = { param([string]$Name) foreach ($x in @($ui.RunList)) { if ($x.State -eq 'RUNNING') { $x.State = 'DONE' } }
  foreach ($x in @($ui.RunList)) { if ([string]$x.Key -ceq $Name) { $x.State = 'RUNNING'; break } } }
# Keeps the result of a step that ended in its row: the state word and the rest of its result line as its second line.
# Takes the step name, the state word and the rest of the line.
$ui.RunEnd = { param([string]$Name, [string]$State, [string]$Rest)
  foreach ($x in @($ui.RunList)) { if ([string]$x.Key -ceq $Name) { $x.State = $State; $t = ($Rest.Substring([math]::Min($Rest.Length, $State.Length)) -replace '^[\s:(]+', '' -replace '\)$', '').Trim(); if ($t) { $x.Sub = $t } } } }
$ui.PaintRuns = {
  <#
  .SYNOPSIS
  Draws the rows of one step list: a thin line under each row, the name and the second line (2 lines each at most), and at the
  right the status as an icon and a word (PASSED with a tick, WAITING with a ring, FAILED with a cross).
  .PARAMETER P
  The list panel (its Tag holds the rows).
  .PARAMETER G
  Its graphics.
  .OUTPUTS
  Nothing; a failure draws nothing more.
  #>
  param($P, $G)
  try { $G.Clear($ui.C.White); $G.SmoothingMode = 'AntiAlias'; $w = $P.ClientSize.Width; $y = 0; $pad = & $ui.Sc $ui.Z.G2; $mw = & $ui.Sc 120; $h1 = & $ui.LineH $ui.F.SmallB; $h2 = & $ui.LineH $ui.F.Small
    $wrap = 'Left, Top, NoPrefix, WordBreak, EndEllipsis, TextBoxControl'; $ln = New-Object System.Drawing.Pen($ui.C.Hair)
    foreach ($r in @($P.Tag)) { $h = [int]$ui.RunSlotH; $m = & $ui.RunMark ([string]$r.State); $col = $ui.C[[string]$m[1]]
      $tw = & $ui.RunTextW $w; $n1 = & $ui.Rows ([string]$r.Title) $ui.F.SmallB $tw $h1 2   # the name and the second line wrap to 2 lines each (Cards v2)
      & $ui.Word $G ([string]$r.Title) $ui.F.SmallB $ui.C.Navy $pad ($y + (& $ui.Sc 6)) $tw ($n1 * $h1) $wrap
      & $ui.Word $G ([string]$r.Sub) $ui.F.Small $ui.C.Gray $pad ($y + (& $ui.Sc 6) + $n1 * $h1) $tw (2 * $h2) $wrap
      & $ui.Word $G ([string]$m[0]) $ui.F.SmallB $col ($w - $mw) $y ($mw - $pad) $h 'Right, VerticalCenter, NoPrefix, SingleLine'
      $ww = [int](& $ui.Meas ([string]$m[0]) $ui.F.SmallB 100000).Width; & $ui.RunIcon $G ([string]$m[0]) $col ($w - $pad - $ww - (& $ui.Sc 16)) ($y + [int]($h / 2))
      $y += $h; $G.DrawLine($ln, 0, ($y - 1), $w, ($y - 1)) }
    $ln.Dispose() } catch { $null = $_ } }   # a list that cannot be drawn: the running row and the percent still show
# Draws the icon of a status, 10 px, centered on a point: a tick, a cross, a ring (WAITING) or a dash. Takes the graphics,
# the word, the color and the point.
$ui.RunIcon = { param($G, [string]$Word, $Color, [int]$X, [int]$Y) $d = & $ui.Sc 10; $t = $Y - [int]($d / 2); $pn = New-Object System.Drawing.Pen($Color, [single](& $ui.Sc 2))
  if ($Word -in 'PASSED', 'DONE') { $G.DrawLines($pn, [System.Drawing.Point[]]@((New-Object System.Drawing.Point($X, ($t + [int]($d / 2)))), (New-Object System.Drawing.Point(($X + [int]($d / 3)), ($t + $d))), (New-Object System.Drawing.Point(($X + $d), $t)))) }
  elseif ($Word -in 'FAILED', 'NEEDS REVIEW', 'STOPPED') { $G.DrawLine($pn, $X, $t, ($X + $d), ($t + $d)); $G.DrawLine($pn, ($X + $d), $t, $X, ($t + $d)) }
  elseif ($Word -eq 'WAITING') { $G.DrawEllipse($pn, $X, $t, $d, $d) } else { $G.DrawLine($pn, $X, $Y, ($X + $d), $Y) }
  $pn.Dispose() }
# The installed part of this app's install record, or $null (the row the person sees next on Maintenance: $ui.RowVerb).
$ui.InstNow = { $e = $null; try { $e = Read-Installed (Get-InstalledKey $script:app) } catch { $null = $_ }; if ($e -and $e.installed) { return $e.installed }; return $null }   # no record: not installed
# A count with its noun, singular for 1 ("1 step", "3 checks"). Takes the number and the noun.
$ui.Counted = { param([int]$N, [string]$One) [string]$N + ' ' + $One + $(if ($N -ne 1) { 's' } else { '' }) }
# The Cancel question (Cards v2; critique change 10): Cancel or Esc on the Run card asks first. "Stop the install" lets the
# step that runs now finish and then stops the run ($script:stopAfter, engine/ps/06-round.ps1); "Keep installing" shows the
# Run card again. The run goes on while the question shows; during the setup, before the first step, it says so. Takes nothing.
$ui.VCancelQ = {
  if (-not $ui.Running -or $ui.View -ne 'run') { return }
  $t = & $ui.TitleOf $ui.StepNow; $dep = Test-Deploy; $verb = $(if ($dep) { 'install' } else { 'round' })
  & $ui.SetCard @{ View = 'cancelq'; Light = 'you'; Kicker = $ui.Kick.Text; Sentence = ('Stop the ' + $verb + '?')
    P = @($(if ($ui.StepI -and $t) { 'RADE stops after "' + $t + '". The steps that passed stay done.' } else { 'RADE stops before the first step.' }), $(if ($dep) { 'To finish the install later, select "' + (& $ui.RowVerb (& $ui.InstNow)) + '" again.' } else { '' }))
    Buttons = @(@{ Text = ('Stop the ' + $verb); Kind = 'dangerline'; Always = $true; Act = { $script:stopAfter = $true; & $ui.ShowRun; & $ui.Say1 'RADE stops after the step that runs now.' } },
      @{ Text = $(if ($dep) { 'Keep installing' } else { 'Keep running' }); Kind = 'primary'; Always = $true; Act = { & $ui.ShowRun } }) } }
# Shows the run card: step k of n, the step name, the bars, Cancel and the next step that needs you.
$ui.ShowRun = {
  & $ui.SetCard @{ View = 'run'; Kicker = $(if ($ui.StepI) { 'Step ' + $ui.StepI + ' of ' + $ui.StepN } else { 'Starting' }); Sentence = $(if (Test-Deploy) { 'Installing ' + (Get-AppWord) + ' ' + $script:app.Version + '.' } else { 'Running round ' + $round + '.' })
    StepRow = $true; Buttons = @(@{ Text = 'Cancel (Esc)'; Always = $true; Act = { & $ui.VCancelQ } })   # Cards v2: the Cancel question first (the window's X still asks with a message)
    Range = @{ Kick = @('STARTING', 'STEP 00 OF 00'); StepName = @(@($steps | ForEach-Object { Get-StepTitle $_ }) + @('Clean-up')) }   # every step title: the step row keeps its place
    Foot = $(if (@($ui.Guides).Count) { 'RADE needs you next at "' + (& $ui.TitleOf $ui.Guides[0]) + '". Until then, keep this window open.' } elseif (-not (Test-Deploy) -and -not $ui.Asked) { 'RADE asks you one last question at the end. Until then, keep this window open.' } else { 'Nothing is needed from you. Keep this window open.' }) }
  $ui.Range[$ui.StepSum] = @($ui.RunList | ForEach-Object { [string]$_.Sub } | Where-Object { $_ }); & $ui.Reflow $ui.StepSum   # one height for every summary (R35)
  $ui.StepName.Text = (& $ui.TitleOf $ui.StepNow); $ui.PctL.Text = [string][int]($ui.Bars['all'].Target * 100) + ' %'; $null = & $ui.PlaceRuns; $null = & $ui.FitEdges; $null = & $ui.FitBar; $null = & $ui.ShowTime }   # the edge follows the ink of the new text's first letter (titles start with any letter)
# Shows a new step on the Run card that is shown: its number in the line in capitals and its title. Both keep their size
# ($ui.Range of the card), and the edges are fitted for the title's first letter. Takes the step number, the count and the name.
$ui.ShowStep = { param([int]$I, [int]$N, [string]$Name) $ui.Kick.Text = ('Step ' + $I + ' of ' + $N).ToUpperInvariant(); $ui.StepName.Text = (& $ui.TitleOf $Name); $null = & $ui.FitEdges; $null = & $ui.FitBar }
# Invoke-Round calls this when a step starts: keeps its name, start and estimate, and moves the run card on.
# Takes the step index, the step count, the name and the estimate.
$ui.OnStatus = { param($i, $count, $name, $estimate)
  $null = & $ui.HoldStep
  $script:statusBase = $name; $script:stepStart = Get-Date; $script:stepEst = $estimate
  if ($i -le 1) { $null = & $ui.SetBar 'all' 0 $true }
  $ui.StepI = [int]$i; $ui.StepN = [int]$count; $ui.StepNow = [string]$name
  $null = & $ui.RunStart ([string]$name)
  if ($ui.View -eq 'cancelq') { $ui.Kick.Text = ('Step ' + $i + ' of ' + $count).ToUpperInvariant() } elseif ($ui.View -ne 'run') { $null = & $ui.ShowRun } else { $null = & $ui.ShowStep $i $count $name; $null = & $ui.PlaceRuns }   # the Cancel question stays
  $null = & $ui.SetBar 'step' 0 $true; $ui.StepFrac.Text = ''; $null = & $ui.FitBar; $null = & $ui.ShowTime
  $null = & $ui.ShowNow ''; $ui.StepAt = $ui.Clock.Elapsed.TotalMilliseconds   # Cards v2: the step's doing text is its summary line ($ui.PlaceRuns); the now-doing line waits for its first item
  $null = & $ui.Paint; [System.Windows.Forms.Application]::DoEvents() }
# Called when a step ends: keeps its state word (DONE, PASSED, SKIPPED, ...) from the result line and redraws. Takes the
# step number and its result line.
$ui.OnStep = { param($k, $line)
  $nm = [string]$steps[$k].Name + ': '; $rest = [string]$line; if ($rest.StartsWith($nm, [System.StringComparison]::Ordinal)) { $rest = $rest.Substring($nm.Length) }
  $st = 'DONE'; foreach ($w in 'NEEDS REVIEW', 'INTERRUPTED', 'FAILED', 'SKIPPED', 'PASSED') { if ($rest.StartsWith($w, [System.StringComparison]::Ordinal)) { $st = $w; break } }
  $ui.StepState[[int]$k] = $st; $null = & $ui.RunEnd ([string]$steps[$k].Name) $st $rest; $null = & $ui.Paint }
# Gives the "Window: OK" or "Window: NOT OK" line for the report, with the layout self-check when it is on. Takes
# nothing; gives back the text.
$ui.WindowLine = { $w = $(if ($ui.OkBox.Checked) { 'Window: OK' } else { 'Window: NOT OK - write here what overlapped or was cut off' }); if ($ui.LayOn -and ($env:RADE_LAYOUT -eq '1' -or -not (Test-Deploy))) { $w += "`r`n" + (& $ui.LayLine) }
  @(@($w) + @(& $ui.ScaleLines)) -join "`r`n" }   # E4: the SCALE line of each RADE window shown since this one opened
$ui.StartApp = {
  # The installed app opens from its local copy in its own powershell.exe process; then RADE closes.
  $p = Get-StartPath; if (-not $p) { & $ui.Say1 'The start file of this application was not found. Select "Install" to put it back.'; return }
  # No -ExecutionPolicy setting (DEC 3): drop only a "Bypass" handed down by an old RADE shortcut (RADE closes after this)
  if ($env:PSExecutionPolicyPreference -ceq 'Bypass') { Remove-Item -LiteralPath 'Env:PSExecutionPolicyPreference' -ErrorAction SilentlyContinue }
  try { $pr = Start-Process -FilePath (Get-PowerShellExe) -ArgumentList ('-NoProfile -STA -File "' + $p + '"') -WorkingDirectory (Split-Path -Parent $p) -PassThru
    if ($pr) { $null = $pr.Handle }   # Windows PowerShell 5.1 keeps the exit code only when the handle is held
    # A start script that a policy blocks or that fails at once ends within a moment: say so and keep RADE open.
    if ($pr -and $pr.WaitForExit(2500) -and $pr.ExitCode -ne 0) { & $ui.Say1 ('The application stopped as soon as it started (exit code ' + $pr.ExitCode + '). Ask in the Teams channel.'); return }
    $ui.Started = $true; $ui.Form.Close() } catch { & $ui.Say1 'The application could not be started. Select "Start" again, or ask in the Teams channel.' } }
# Starts the run: saves the shortcut folder, asks for the folder some steps need, then calls Invoke-Round with the
# window callbacks and shows Done, Needs review or Stopped. Takes nothing.
$ui.Run = {
  $ui.LinkDir = ''; $ui.FieldAsked = $false
  if ($ui.View -eq 'ready' -and $ui.FieldRow.Visible -and $ui.FieldL.Text -eq 'Shortcut in') {   # R29 N8: the folder for the app's shortcut (the label is the key: 06-open.ps1)
    $d = $ui.Field.Text.Trim().Trim('"')
    if ($d -and -not (Test-Path -LiteralPath $d -PathType Container)) { & $ui.Say1 'That folder was not found. Select "Browse" to choose a folder, or empty the box for no shortcut.'; $script:resume = $null; return }
    $ui.LinkDir = $d; $ui.FieldAsked = $true; if ($d) { Save-ShortcutDir $d } }
  $dep = Test-Deploy; $ui.Running = $true; $ui.Asked = $false; $ui.StepAt = $null; $ui.Summary = @(); $ui.Log.Clear(); $ui.StepState = @{}; $ui.StepI = 0; $ui.StepNow = ''; $ui.Edit = $false
  $to = ''; if (-not $dep) { $to = [string](Get-MailTo (Get-BasePath)); $ui.ToBox.Text = $to }
  $sel = @(); $ui.Guides = @()
  for ($k = 0; $k -lt $steps.Count; $k++) { $on = [bool]($script:appSteps -contains $k -and $ui.Sel[[int]$k]); $sel += $on; if ($on -and $steps[$k].Kind -eq 'guide') { $ui.Guides += [string]$steps[$k].Name } }
  # A step that needs a folder asks for it now (a Windows dialog); Cancel skips that step. A resume does not ask again
  # for a step it keeps.
  $kept = $(if ($script:resume) { Get-ResumeKept $script:resume } else { @{} })
  $answers = @()
  for ($k = 0; $k -lt $steps.Count; $k++) {
    $a = ''
    if ($sel[$k] -and $steps[$k].AskParam -and -not $kept.ContainsKey([string]$steps[$k].Name)) {
      $pick = New-Object System.Windows.Forms.FolderBrowserDialog
      $pick.Description = $steps[$k].AskPrompt; $pick.ShowNewFolderButton = $false
      if ([string]$pick.ShowDialog($ui.Form) -eq 'OK') { $a = [string]$pick.SelectedPath } else { $sel[$k] = $false; $ui.Guides = @($ui.Guides | Where-Object { $_ -ne [string]$steps[$k].Name }); $ui.Log.Add($steps[$k].Name + ': skipped (no folder picked)') }
      $pick.Dispose()
    }
    $answers += $a
  }
  $ui.Bars['all'].Fill = $ui.C.Info; $ui.Bars['run'].Fill = $ui.C.Info; $ui.Bars['step'].Fill = $ui.C.Info; & $ui.SetBar 'all' 0 $true; & $ui.SetBar 'run' 0 $true; & $ui.SetBar 'step' 0 $true
  $script:stopAfter = $false; & $ui.MakeRunList $sel; $ui.RunKey = ''; & $ui.ShowRun; $ui.TimeT.Start()
  $checkLines = Get-CheckSummary $script:checkResults
  $script:roundStart = Get-Date
  try {
    $ui.Summary = Invoke-Round ([bool]($cleanup.Count -and $ui.Clean)) $sel $to $ui.Say $ui.Tick $ui.OnStep $ui.OnStatus $ui.WindowLine $answers $checkLines
    & $ui.HoldStep; $script:stepStart = $null; $ui.Running = $false
    if (-not ($script:closing -or $ui.Form.IsDisposed)) { & $ui.VDone }   # closed in the last moments of the run: no clipboard, no folder
  } catch {
    $script:stepStart = $null; $ui.Running = $false
    if ($script:closing -or $ui.Form.IsDisposed) { return }   # Exit during a step: the report on disk says STOPPED
    $msg = 'STOPPED: ' + (ConvertTo-Masked ([string]$_)); & $ui.Say $msg
    $what = [string](Get-WhatToDo $msg); if ($what) { & $ui.Say $what }
    & $ui.VStopped $msg.Substring(9) $what
  } finally { $script:resume = $null; $ui.Running = $false; try { $ui.TimeT.Stop() } catch { $null = $_ }; $sv = $ui.StepState; & $ui.InitSel; $ui.StepState = $sv } }
# Pause and resume (the PFM, 2026-11-20; docs/engine.md "Pause and resume"): runs the round again from its saved state.
# The steps that passed stay done; the step that was running and the steps after it run. Takes nothing.
$ui.ResumeRun = {
  $st = Read-RoundState (Get-BasePath)
  if ($st.State -ne 'ok') { $null = Clear-RoundState (Get-BasePath); & $ui.VReady; & $ui.Say1 'The saved progress could not be read, so the round starts over. Select the main button to start.'; return }
  $sel = Get-ResumeSelection $st.Doc; for ($k = 0; $k -lt $steps.Count; $k++) { if ($script:appSteps -contains $k) { $ui.Sel[[int]$k] = [bool]$sel[$k] } }
  $script:resume = $st.Doc; & $ui.Run }
# Start over: the saved state goes to the Recycle Bin, then the round runs from its first step. Takes nothing.
$ui.StartOver = { $why = Clear-RoundState (Get-BasePath); if ($why) { & $ui.Say1 ('The saved progress could not be moved to the Recycle Bin (' + $why + ').'); return }; $script:resume = $null; & $ui.Run }
$ui.MadeText = {
  # Deploy: how many things the installs of this application made, by kind (the list is in the Record).
  $c = [ordered]@{}; $e = (Read-Installed (Get-InstalledKey $script:app))
  if ($e -and $e.steps) { foreach ($n in @($e.steps.Keys)) { foreach ($m in @($e.steps[$n].made)) { if ($null -ne $m) { $k = [string]$m.kind; if ($c.Contains($k)) { $c[$k] = [int]$c[$k] + 1 } else { $c[$k] = 1 } } } } }
  if (-not $c.Count) { return '' }
  $parts = @(); foreach ($k in @($c.Keys)) { $parts += ([string]$c[$k] + ' ' + $k + $(if ($c[$k] -ne 1) { 's' } else { '' })) }
  return ('The installs of this application made: ' + ($parts -join ', ') + '.') }
# Copies the summary (else the log) to the clipboard and says "Copied.". Takes nothing.
$ui.Copy = {
  $t = $(if (@($ui.Summary).Count) { @($ui.Summary) } else { @($ui.Log) }) -join "`r`n"
  try { [System.Windows.Forms.Clipboard]::SetText($t); & $ui.Say1 'Copied.' } catch { & $ui.Say1 'The clipboard is busy. Select the button again.' } }
# Opens the results folder in Explorer, when there is one. Takes nothing.
$ui.Open = { if ($script:resultsDir) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $script:resultsDir + '"') } }
# engine-v46 (the PFM, 2026-11-26: "I got no notification that a script was blocked"): the end card names each step
# whose script Windows blocked 2 times (Invoke-RoundStep), also when it is not the first problem. Takes nothing; gives
# back the paragraph, or '' when no step was blocked.
$ui.BlockedText = { $b = @($script:blockedSteps | Where-Object { $_ })
  if (-not $b.Count) { return '' }
  return ('Windows blocked the script of ' + $(if ($b.Count -eq 1) { 'the step "' + $b[0] + '"' } else { [string]$b.Count + ' steps: "' + ($b -join '", "') + '"' }) + ' 2 times. Details shows the policy line.') }
# Shows the card at the end of a run: Done when every step passed ($ui.VPassed), else the step-failed card for the first
# step that failed ($ui.VStepFail), or Needs review. Copies the summary and opens the folder in a test round. Takes nothing.
$ui.VDone = {
  $sum = @($ui.Summary); $dep = Test-Deploy; $bad = ([string]$sum[0] -match 'NEEDS REVIEW')
  $ui.Took = Format-Duration ((Get-Date) - $script:roundStart).TotalSeconds
  $ui.Bars['all'].Fill = $(if ($bad) { $ui.C.Red } else { $ui.C.Green }); & $ui.SetBar 'all' $(if ($bad) { $ui.Bars['all'].Target } else { 1 }) $true
  $ui.Mail = $(if ($script:draftMade) { 'An Outlook draft is open with the summary and all result files. Review it, then select Send.' } else { 'The results folder is open and the summary is on the clipboard. Paste it into an e-mail and attach the files.' })
  if (-not $bad) { & $ui.VPassed } else {
    # The first step that failed or needs review, with its help line from the manifest; the rest is in Details.
    $one = ''; $what = ''; $more = 0
    for ($k = 0; $k -lt $sum.Count; $k++) { if ([string]$sum[$k] -match ': (NEEDS REVIEW|FAILED) ') { if ($one) { $more++ } else { $one = [string]$sum[$k]; if ($k + 1 -lt $sum.Count -and [string]$sum[$k + 1] -match '^\s+What to do: ') { $what = ([string]$sum[$k + 1]).Trim() } } } }
    $row = $null; $ri = 0; for ($i = 0; $i -lt @($ui.RunList).Count; $i++) { if ($one.StartsWith([string]$ui.RunList[$i].Key + ': ', [System.StringComparison]::Ordinal)) { $row = $ui.RunList[$i]; $ri = $i + 1; break } }
    if ($row) { & $ui.VStepFail $row $ri $one $what $more } else {
      if (-not $one) { $one = 'A file, the clean-up or a result file needs review. Details shows which.' }
      & $ui.SetCard @{ View = 'review'; Light = 'bad'; Kicker = 'Needs review'; Right = 'Needs review'; Sentence = $(if ($dep) { 'The install is not complete.' } else { 'The round needs review.' })
        P = @(($one + $(if ($more) { ' (and ' + $more + ' more in Details)' } else { '' })), $what, (& $ui.BlockedText), $(if ($dep) { 'Steps that passed stay done. If you paste the block again, RADE runs only what is left.' } else { $ui.Mail }))
        Help = $(if ($dep) { Get-HelpLine } else { '' }); Note = $(if ($dep) { '"Copy summary" puts the report on the clipboard. Paste it in the channel. Nothing was sent.' } else { '' })
        Buttons = @(@{ Text = 'Copy summary'; Kind = 'primary'; Act = { & $ui.Copy } }, @{ Text = 'Open results folder'; Act = { & $ui.Open } }, @{ Text = 'Close'; Act = { $ui.Form.Close() } })
        Test = (-not $dep); Back = { & $ui.VReady } } } }
  if (-not $dep) { & $ui.Copy; if (-not $script:draftMade) { & $ui.Open } }   # a test round: the summary is on the clipboard, and with no draft the folder opens
  & $ui.ToFront }
$ui.VPassed = {
  <#
  .SYNOPSIS
  Shows the Done card of a run that passed (Cards v2): the green light line, the kicker "ALL n STEPS PASSED" in the
  PASSED color, the tick and the headline, the strong summary line "<n> steps and <m> checks passed in <time>.", what
  was sent (nothing), the main button "Start <word> (Enter)" when it can start, and no Back.
  .OUTPUTS
  Nothing.
  #>
  $dep = Test-Deploy; $made = ''; if ($dep) { $made = [string](& $ui.MadeText) }
  $all = @($ui.RunList).Count; $n = @($ui.RunList | Where-Object { [string]$_.State -in 'PASSED', 'DONE' }).Count   # counted from the states: a skipped step did not pass
  $m = @($script:appChecks | Where-Object { $script:checkResults[$_] -and [string]$script:checkResults[$_].State -like 'PASSED*' }).Count   # a warning did not pass
  $iconNote = ''; if ($dep) { $saved = Save-RunnerCopy   # a copy that stays (a higher engine) keeps its shortcut (review of PR 199)
    $noBox = 'The shortcut folder box was empty, so RADE made no shortcut. Open RADE from the RADE page instead.'   # R28: the runner copy and the shortcut (a deploy that passed)
    $iconNote = $(if (-not $saved) { '' } elseif ($ui.FieldAsked -and -not $ui.LinkDir -and (Get-DesktopDir)) { $noBox } else { [string](Add-DesktopIcon ([string]$ui.LinkDir)) }) }
  $inst = ($dep -and (Get-InstalledText $script:app) -match 'is installed$'); $w = Get-AppWord
  # Start (R28 fix: after a first install the Done card had no Start button): the checks passed before the install.
  $startB = $(if ($inst -and [string]$script:app.Start -and (Get-StartPath)) { @{ Text = 'Start ' + $w; Kind = 'primary'; Act = { & $ui.StartApp } } } else { $null })
  & $ui.SetCard @{ View = 'done'; Light = 'pass'; Tick = $true; KickColor = 'GreenInk'; Strong = $true
    Kicker = $(if (($dep -and -not $inst) -or $n -ne $all) { 'Passed' } else { $(if ($n -eq 1) { 'The step passed' } else { 'All ' + $n + ' steps passed' }) })
    Sentence = $(if (-not $dep) { 'Round ' + $round + ' is done.' } elseif ($inst) { $w + ' ' + $script:app.Version + ' is installed.' } else { 'The run passed, but version ' + $script:app.Version + ' is not recorded as installed.' })
    P = @(((& $ui.Counted $n 'step') + ' and ' + (& $ui.Counted $m 'check') + ' passed in ' + $ui.Took + '.'), $(if ($dep -and -not $inst) { 'Some steps were off or skipped. Run again with every step on.' } else { '' }), $(if ($dep) { 'Nothing was sent. The report stays on this computer.' } else { $ui.Mail }), $made, $iconNote)
    Buttons = @(@{ Text = 'Open results folder'; Act = { & $ui.Open } }, @{ Text = 'Copy summary'; Act = { & $ui.Copy } }, @{ Text = 'Close'; Kind = $(if ($startB) { '' } else { 'primary' }); Act = { $ui.Form.Close() } }, $startB)
    Test = (-not $dep) } }
$ui.VStepFail = {
  <#
  .SYNOPSIS
  Shows the step-failed card (Cards v2): the kicker "STEP k OF n FAILED" with a cross, both in the error color; the
  headline "A step failed: <step title>."; what happened; the boxed WHAT TO DO line; the help line; "Try again (Enter)"
  (the Ready card, which offers Resume), "Copy summary" and "Close".
  .PARAMETER Row
  The row of the step in $ui.RunList.
  .PARAMETER K
  Its number in the run.
  .PARAMETER Line
  Its result line from the summary.
  .PARAMETER What
  Its "What to do:" line ('' when it has none).
  .PARAMETER More
  How many more steps failed or need review.
  .OUTPUTS
  Nothing.
  #>
  param($Row, [int]$K, [string]$Line, [string]$What, [int]$More)
  $dep = Test-Deploy; $said = $Line.Substring([math]::Min($Line.Length, ([string]$Row.Key).Length + 2))
  $what = ($said -replace '^(FAILED|NEEDS REVIEW)[^:]*:\s*', '').Trim(); if ($what) { $said = $what }   # what happened, without the state word and the time (Cards v2)
  & $ui.SetCard @{ View = 'stepfail'; Light = 'bad'; KickColor = 'Red'; Kicker = ([string][char]0x00D7 + ' Step ' + $K + ' of ' + @($ui.RunList).Count + ' failed')
    Sentence = ('A step failed: ' + [string]$Row.Title + '.'); Todo = ($What -replace '^What to do:\s*', '')
    P = @(($said + $(if ($More) { ' (and ' + $More + ' more in Details)' } else { '' })), (& $ui.BlockedText), $(if ($dep) { '' } else { $ui.Mail })); Help = (Get-HelpLine)
    Buttons = @(@{ Text = 'Copy summary'; Act = { & $ui.Copy } }, @{ Text = 'Close'; Act = { $ui.Form.Close() } }, @{ Text = 'Try again'; Kind = 'primary'; Act = { & $ui.VReady } })
    Test = (-not $dep) } }
# Shows the Paused card (the PFM, 2026-11-20): the sign-in failed in a step (the CAC is out), so the round paused at that
# step; Resume runs it again. Takes the reason ("INTERRUPTED: ..."); does nothing when the window is closing.
$ui.VPaused = { param([string]$Why)
  if ($script:closing -or $ui.Form.IsDisposed) { return }
  $p1 = (($Why.Substring(13) -replace '\. Insert your CAC, then select Resume$', '') -replace '^t', 'T') + '.'
  & $ui.SetCard @{ View = 'stopped'; Kicker = 'Paused'; Right = 'Paused'; Sentence = 'Insert your CAC, then select Resume.'
    P = @($p1, 'The steps that passed stay done. Resume runs this step again.'); Back = { & $ui.VReady }
    Buttons = @(@{ Text = 'Resume'; Kind = 'primary'; Act = { & $ui.ResumeRun } }, @{ Text = 'Copy the log'; Act = { & $ui.Copy } }, @{ Text = 'Close'; Act = { $ui.Form.Close() } }) }
  & $ui.ToFront }
# Shows the Stopped card with why the run stopped and what to do. Takes the reason and the help text; does nothing when
# the window is closing.
$ui.VStopped = { param([string]$Why, [string]$What)
  if ($script:closing -or $ui.Form.IsDisposed) { return }
  $dep = Test-Deploy
  if ($Why -match '^INTERRUPTED: ') { & $ui.VPaused $Why; return }   # the sign-in failed (CAC out): Paused, not Stopped
  & $ui.SetCard @{ View = 'stopped'; Light = 'bad'; Kicker = 'Stopped'; Right = 'Stopped'; Sentence = $(if ($dep) { 'The install stopped.' } else { 'The round stopped.' })
    P = @(($Why.Substring(0, 1).ToUpperInvariant() + $Why.Substring(1)), $What, 'The report in the results folder says STOPPED.'); Help = $(if ($dep) { Get-HelpLine } else { '' })
    Buttons = @(@{ Text = 'Copy the log'; Kind = 'primary'; Act = { & $ui.Copy } }, @{ Text = 'Try again'; Act = { & $ui.VReady } }, @{ Text = 'Close'; Act = { $ui.Form.Close() } }); Back = { & $ui.VReady } }
  & $ui.ToFront }
$ui.OkBox.Add_CheckedChanged({ if (-not $ui.OkBox.Checked) { & $ui.Say1 'Select "Make e-mail draft" to make a draft that says "Window: NOT OK".' } elseif ($ui.Note.Text -match '^Select "Make e-mail draft"') { & $ui.Say1 '' } })   # ticking again removes only this note
$ui.DraftB.Add_Click({
  $to = $ui.ToBox.Text.Trim()
  if ($to -and -not (Test-MailTo $to)) { & $ui.Say1 'The e-mail address does not look right.'; return }
  try { $null = Save-MailTo (Get-BasePath) $to } catch { $null = $_ }
  $why = Save-RoundDraft $script:resultsDir $ui.Summary $to (& $ui.WindowLine)
  & $ui.Say1 $(if ($why) { 'The Outlook draft could not be created (' + $why + ').' } else { 'The Outlook draft is open.' }) })

