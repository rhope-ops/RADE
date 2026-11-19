# RADE window part 07, the run: the callbacks Invoke-Round uses (log line, tick, step state), the Run button,
# and the Done, Needs review and Stopped cards. Uses the card parts and Invoke-Round.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# ---- The run. Invoke-Round calls back: a log line ($ui.Say), a tick ($ui.Tick), a step that starts ($ui.OnStatus) and
# a step that ends ($ui.OnStep). A step you do by hand comes in through $script:guideUi, what a step does now through
# $script:nowUi, and the last question of a test round through $script:feedbackUi.
$ui.Say = { param($t) Add-RunLog $t; $ui.Log.Add([string]$t); if ($ui.RecOn) { try { $ui.RecText.AppendText([string]$t + "`r`n") } catch { $null = $_ } }; try { [System.Windows.Forms.Application]::DoEvents() } catch { $null = $_ } }
# L7 (the Administrator, 2026-11-19): the now-doing line under the step's bar. The engine calls this ($script:nowUi) with a
# plain sentence for each item a step script reports (Get-NowText) and for a NOW line. Each text ends with "..." (its own
# end mark goes; the Administrator, 2026-11-19) and is cut to $ui.NowLines lines; the line keeps its room. Takes the text.
$ui.ShowNow = { param([string]$Text) try { if ($ui.View -eq 'run') { $x = $Text.Trim() -replace '[\s.,;:!?\u2026]+$', ''; $ui.NowRaw = $(if ($x) { $x + '...' } else { '' }); & $ui.CutNow; $ui.Now.Visible = $true } } catch { $null = $_ } }   # a line that cannot show never stops a step
# Shows the whole now-doing text ($ui.NowRaw) cut to $ui.NowLines lines at the line's wrap width; runs again after a resize
# ($ui.BreakAll), so a narrower window cuts it again from the whole text. Takes nothing; a failure is ignored.
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
  & $ui.SetBar 'all' ([math]::Max($g.All, $ui.Bars['all'].Target)) $true; & $ui.SetBar 'step' ([math]::Max($g.StepShown, $ui.Bars['step'].Target)) $true
  if ($ui.View -ne 'run') { return }
  & $ui.ShowTime
  $fr = $(if ($script:prog.Frac -ge 0) { [string]$script:prog.FracText } else { '' }); if ($ui.StepFrac.Text -ne $fr) { $ui.StepFrac.Text = $fr }   # one size ($ui.FixW): the bar keeps its width
  # R21 W6: a time left only when earlier runs give one; never "a guess".
  $rt = [string][int]($g.All * 100) + ' %'; if ($ui.RightL.Text -ne $rt) { $ui.RightL.Text = $rt } }
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
# Shows the run card: step k of n, the step name, the bars, Cancel and the next step that needs you.
$ui.ShowRun = {
  & $ui.SetCard @{ View = 'run'; Kicker = $(if ($ui.StepI) { 'Step ' + $ui.StepI + ' of ' + $ui.StepN } else { 'Starting' }); Sentence = $(if (Test-Deploy) { 'Installing ' + $script:app.Name + '.' } else { 'Running round ' + $round + '.' })
    StepRow = $true; Buttons = @(@{ Text = 'Cancel'; Always = $true; Act = { $ui.Form.Close() } })   # asks first while a step runs (the window's X does the same)
    Range = @{ Kick = @('STARTING', 'STEP 00 OF 00'); StepName = @(@($steps | ForEach-Object { Get-StepTitle $_ }) + @('Clean-up')) }   # every step title: the step row keeps its place
    Right = '0 %'
    Foot = $(if (@($ui.Guides).Count) { 'RADE needs you next at "' + (& $ui.TitleOf $ui.Guides[0]) + '". Until then, keep this window open.' } elseif (-not (Test-Deploy) -and -not $ui.Asked) { 'RADE asks you one last question at the end. Until then, keep this window open.' } else { 'Nothing is needed from you. Keep this window open.' }) }
  $ui.StepName.Text = (& $ui.TitleOf $ui.StepNow); $null = & $ui.FitEdges; $null = & $ui.FitBar; $null = & $ui.ShowTime }   # the edge follows the ink of the new text's first letter (titles start with any letter)
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
  if ($ui.View -ne 'run') { $null = & $ui.ShowRun } else { $null = & $ui.ShowStep $i $count $name }
  $null = & $ui.SetBar 'step' 0 $true; $ui.StepFrac.Text = ''; $null = & $ui.FitBar; $null = & $ui.ShowTime
  $doing = ''; foreach ($s in @($steps)) { if ([string]$s.Name -ceq [string]$name) { $doing = [string]$s.Doing } }; $null = & $ui.ShowNow $doing; $ui.StepAt = $ui.Clock.Elapsed.TotalMilliseconds   # L7: the step's own present-tense sentence, until its first item
  $null = & $ui.Paint; [System.Windows.Forms.Application]::DoEvents() }
# Called when a step ends: keeps its state word (DONE, PASSED, SKIPPED, ...) from the result line and redraws. Takes the
# step number and its result line.
$ui.OnStep = { param($k, $line)
  $nm = [string]$steps[$k].Name + ': '; $rest = [string]$line; if ($rest.StartsWith($nm, [System.StringComparison]::Ordinal)) { $rest = $rest.Substring($nm.Length) }
  $st = 'DONE'; foreach ($w in 'NEEDS REVIEW', 'FAILED', 'SKIPPED', 'PASSED') { if ($rest.StartsWith($w, [System.StringComparison]::Ordinal)) { $st = $w; break } }
  $ui.StepState[[int]$k] = $st; $null = & $ui.Paint }
# Gives the "Window: OK" or "Window: NOT OK" line for the report, with the layout self-check when it is on. Takes
# nothing; gives back the text.
$ui.WindowLine = { $w = $(if ($ui.OkBox.Checked) { 'Window: OK' } else { 'Window: NOT OK - write here what overlapped or was cut off' }); if ($ui.LayOn -and ($env:RADE_LAYOUT -eq '1' -or -not (Test-Deploy))) { $w + "`r`n" + (& $ui.LayLine) } else { $w } }
$ui.StartApp = {
  # The installed app opens from its local copy in its own powershell.exe process; then RADE closes.
  $p = Get-StartPath; if (-not $p) { & $ui.Say1 'The start file of this application was not found. Select "Install" to put it back.'; return }
  try { $pr = Start-Process -FilePath (Get-PowerShellExe) -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -STA -File "' + $p + '"') -WorkingDirectory (Split-Path -Parent $p) -PassThru
    if ($pr) { $null = $pr.Handle }   # Windows PowerShell 5.1 keeps the exit code only when the handle is held
    # A start script that a policy blocks or that fails at once ends within a moment: say so and keep RADE open.
    if ($pr -and $pr.WaitForExit(2500) -and $pr.ExitCode -ne 0) { & $ui.Say1 ('The application stopped as soon as it started (exit code ' + $pr.ExitCode + '). Ask in the Teams channel.'); return }
    $ui.Started = $true; $ui.Form.Close() } catch { & $ui.Say1 'The application could not be started. Select "Start" again, or ask in the Teams channel.' } }
# Starts the run: saves the shortcut folder, asks for the folder some steps need, then calls Invoke-Round with the
# window callbacks and shows Done, Needs review or Stopped. Takes nothing.
$ui.Run = {
  $ui.LinkDir = ''; $ui.FieldAsked = $false
  if ($ui.View -eq 'ready' -and $ui.FieldRow.Visible -and $ui.FieldL.Text -eq 'RADE shortcut in') {   # R29 N8: the folder for the RADE shortcut
    $d = $ui.Field.Text.Trim().Trim('"')
    if ($d -and -not (Test-Path -LiteralPath $d -PathType Container)) { & $ui.Say1 'That folder was not found. Select "Browse" to choose a folder, or empty the box for no shortcut.'; return }
    $ui.LinkDir = $d; $ui.FieldAsked = $true; if ($d) { Save-ShortcutDir $d } }
  $dep = Test-Deploy; $ui.Running = $true; $ui.Asked = $false; $ui.StepAt = $null; $ui.Summary = @(); $ui.Log.Clear(); $ui.StepState = @{}; $ui.StepI = 0; $ui.StepNow = ''; $ui.Edit = $false
  $to = ''; if (-not $dep) { $to = [string](Get-MailTo (Get-BasePath)); $ui.ToBox.Text = $to }
  $sel = @(); $ui.Guides = @()
  for ($k = 0; $k -lt $steps.Count; $k++) { $on = [bool]($script:appSteps -contains $k -and $ui.Sel[[int]$k]); $sel += $on; if ($on -and $steps[$k].Kind -eq 'guide') { $ui.Guides += [string]$steps[$k].Name } }
  # A step that needs a folder asks for it now (a Windows dialog); Cancel skips that step.
  $answers = @()
  for ($k = 0; $k -lt $steps.Count; $k++) {
    $a = ''
    if ($sel[$k] -and $steps[$k].AskParam) {
      $pick = New-Object System.Windows.Forms.FolderBrowserDialog
      $pick.Description = $steps[$k].AskPrompt; $pick.ShowNewFolderButton = $false
      if ([string]$pick.ShowDialog($ui.Form) -eq 'OK') { $a = [string]$pick.SelectedPath } else { $sel[$k] = $false; $ui.Guides = @($ui.Guides | Where-Object { $_ -ne [string]$steps[$k].Name }); $ui.Log.Add($steps[$k].Name + ': skipped (no folder picked)') }
      $pick.Dispose()
    }
    $answers += $a
  }
  $ui.Bars['all'].Fill = $ui.C.Blue; & $ui.SetBar 'all' 0 $true; & $ui.SetBar 'step' 0 $true
  & $ui.ShowRun; $ui.TimeT.Start()
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
  } finally { $ui.Running = $false; try { $ui.TimeT.Stop() } catch { $null = $_ }; $sv = $ui.StepState; & $ui.InitSel; $ui.StepState = $sv } }
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
# Shows the card at the end of a run: Done when every step passed, else Needs review with the first problem. Copies the
# summary and opens the folder in a test round. Takes nothing.
$ui.VDone = {
  $sum = @($ui.Summary); $dep = Test-Deploy; $bad = ([string]$sum[0] -match 'NEEDS REVIEW'); $made = ''; if ($dep) { $made = [string](& $ui.MadeText) }
  $took = Format-Duration ((Get-Date) - $script:roundStart).TotalSeconds
  $ui.Bars['all'].Fill = $(if ($bad) { $ui.C.Blue } else { $ui.C.Green }); & $ui.SetBar 'all' $(if ($bad) { $ui.Bars['all'].Target } else { 1 }) $true
  $mail = $(if ($script:draftMade) { 'An Outlook draft is open with the summary and all result files. Review it, then select Send.' } else { 'The results folder is open and the summary is on the clipboard. Paste it into an e-mail and attach the files.' })
  $bMade = $(if ($made) { @{ Text = 'Record'; Act = { & $ui.VRecord } } } else { $null })
  $iconNote = ''; if ($dep -and -not $bad) { $null = Save-RunnerCopy; $iconNote = $(if ($ui.FieldAsked -and -not $ui.LinkDir -and (Get-DesktopDir)) { 'The shortcut folder box was empty, so RADE made no shortcut. Open RADE from the RADE page instead.' } else { [string](Add-DesktopIcon ([string]$ui.LinkDir)) }) }   # R28: the runner copy and the desktop shortcut (a deploy that passed)
  if (-not $bad) {
    $inst = ($dep -and (Get-InstalledText $script:app) -match 'is installed$')
    # Start (R28 fix: after a first install the Done card had no Start button): the checks passed before the install.
    $startB = $(if ($inst -and [string]$script:app.Start -and (Get-StartPath)) { @{ Text = 'Start ' + $script:app.Name; Kind = 'primary'; Act = { & $ui.StartApp } } } else { $null })
    & $ui.SetCard @{ View = 'done'; Tick = $true; Kicker = $(if ($dep -and -not $inst) { 'Passed' } else { 'All steps passed' }); Right = $took
      Sentence = $(if (-not $dep) { 'Round ' + $round + ' is done.' } elseif ($inst) { $script:app.Name + ' ' + $script:app.Version + ' is installed.' } else { 'The run passed, but version ' + $script:app.Version + ' is not recorded as installed.' })
      P = @($(if ($dep -and -not $inst) { 'Some steps were off or skipped. Run again with every step on.' } else { '' }), $(if ($dep) { 'Nothing was sent. The report stays on this computer.' } else { $mail }), $made, $iconNote)
      Buttons = @($startB, @{ Text = 'Close'; Kind = $(if ($startB) { '' } else { 'primary' }); Act = { $ui.Form.Close() } }, $bMade, @{ Text = 'Open results folder'; Act = { & $ui.Open } }, @{ Text = 'Copy summary'; Act = { & $ui.Copy } })
      Test = (-not $dep); Back = { & $ui.VReady } }
  } else {
    # The first step that needs review, with its help line from the manifest; the rest is in the Record.
    $one = ''; $what = ''; $more = 0
    for ($k = 0; $k -lt $sum.Count; $k++) { if ([string]$sum[$k] -match ': (NEEDS REVIEW|FAILED) ') { if ($one) { $more++ } else { $one = [string]$sum[$k]; if ($k + 1 -lt $sum.Count -and [string]$sum[$k + 1] -match '^\s+What to do: ') { $what = ([string]$sum[$k + 1]).Trim() } } } }
    if (-not $one) { $one = 'A file, the clean-up or a result file needs review. The Record shows which.' }
    & $ui.SetCard @{ View = 'review'; Light = 'bad'; Kicker = 'Needs review'; Right = 'Needs review'; Sentence = $(if ($dep) { 'The install is not complete.' } else { 'The round needs review.' })
      P = @(($one + $(if ($more) { ' (and ' + $more + ' more in the Record)' } else { '' })), $what, $(if ($dep) { 'Steps that passed stay done. If you paste the block again, RADE runs only what is left.' } else { $mail }))
      Help = $(if ($dep) { Get-HelpLine } else { '' }); Note = $(if ($dep) { '"Copy summary" puts the report on the clipboard. Paste it in the channel. Nothing was sent.' } else { '' })
      Buttons = @(@{ Text = 'Copy summary'; Kind = 'primary'; Act = { & $ui.Copy } }, @{ Text = 'Open results folder'; Act = { & $ui.Open } }, $bMade, @{ Text = 'Close'; Act = { $ui.Form.Close() } })
      Test = (-not $dep); Back = { & $ui.VReady } }
  }
  if (-not $dep) { & $ui.Copy; if (-not $script:draftMade) { & $ui.Open } }   # a test round: the summary is on the clipboard, and with no draft the folder opens
  & $ui.ToFront }
# Shows the Stopped card with why the run stopped and what to do. Takes the reason and the help text; does nothing when
# the window is closing.
$ui.VStopped = { param([string]$Why, [string]$What)
  if ($script:closing -or $ui.Form.IsDisposed) { return }
  $dep = Test-Deploy
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

