# RADE engine part 06, the round: Invoke-Round runs clean-up, downloads and every selected step, writes the report
# and makes the draft or the install record, through the phase functions below (one run table, $run). Uses parts 01
# to 05 and the progress state of 09; called by the window and text mode.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# Starts the record of one run: the folder, the history, the summary lines (line 1 = the e-mail subject), the mode
# line, whether the install can be whole, and the overall progress weights. Takes the Invoke-Round inputs; returns the
# run table that the other Round functions read and change ($run).
function Initialize-RoundRun([bool]$Clean, [bool[]]$Selected, [scriptblock]$Say, [string[]]$CheckLines) {
  $script:ranSteps = @()
  $script:roundBad = $false
  $script:runLog = New-Object System.Collections.Generic.List[string]
  $script:helped = @{}
  $run = @{ SayRaw = $Say; Base = (Resolve-Base); Started = (Get-Date); Deploy = (Test-Deploy); Prior = (Get-StepPrior) }   # Prior is empty in a test round
  $run.Hist = Read-RoundHistory $run.Base
  # Line 1 is the e-mail subject (PFM 13 Nov); PASSED or NEEDS REVIEW is added at the end (R06; words R13).
  $run.Summary = @(('@@PREFIX@@ ' + $round), ('Round ' + $round + ', build ' + $buildId + ', started ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')))
  $run.Summary += ('Application: ' + $script:app.Name)
  # A step that is off still counts when the record says it PASSED at this version (safe second run).
  $run.Whole = $true; foreach ($k in $script:appSteps) { if (-not [bool]$steps[$k].Optional -and -not $Selected[$k] -and $run.Prior[[string]$steps[$k].Name] -ne 'PASSED') { $run.Whole = $false } }   # an optional step ("default": false) is not needed for "installed"
  $run.StepRecs = @{}; $run.RunState = @{}   # RunState: every step this run reached (the "after" check); StepRecs: what goes to the record
  $run.Done = @(); $run.Sel = $Selected; $run.Resumed = $false; $run.Kept = @{}   # Done: each finished step, for the round state (12-resume.ps1)
  $run.ModeLine = ''; if ($run.Deploy) { $run.ModeLine = 'Mode: deploy, ' + (Get-InstalledText $script:app); $run.Summary += $run.ModeLine }
  if ($CheckLines) { $run.Summary += $CheckLines }
  $run.Units = 0
  # Overall bar: each unit weighs its expected seconds (Get-StepWeight); files and clean-up weigh little.
  $script:prog = @{ Total = 5.0; Done = 0.0; Cur = 0.0; CurKnown = $false; Known = $true; Start = $null; Frac = -1.0; FracText = ''; Index = 0; Count = 0 }
  if ($Clean -and $cleanup.Count) { $run.Units++; $script:prog.Total += 10 }
  $run.Total = 0
  for ($k = 0; $k -lt $steps.Count; $k++) {
    if (-not $Selected[$k]) { continue }
    $run.Units++; $run.Total++
    $w = Get-StepWeight $run.Hist $steps[$k]; $script:prog.Total += $w.Seconds; if (-not $w.Known) { $script:prog.Known = $false }
  }
  $script:prog.Count = $run.Units
  $run.N = 0; $run.K1 = 0
  return $run
}

# Gets the computer ready before the first step: the RADE folder, the notes (mode, newer version, text mode, Word), the
# bundle's files, the downloads, the saved e-mail address and the clean-up. Throws when a deploy must not go on.
# Takes the run table, the Clean switch and the To address; changes $run.Base and $run.Summary.
function Invoke-RoundSetup($run, [bool]$Clean, [string]$To, [scriptblock]$OnStatus) {
  $speak = $run.Speak
  & $speak ('RADE, round ' + $round + ' (build ' + $buildId + '), started ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  & $speak $script:scriptCheck.Line   # in the log and the report, so a round's results show it (docs/specs/bundle-hash.md)
  $run.Base = Move-ToRade $speak
  $base = $run.Base
  & $speak ('Working folder: ' + (ConvertTo-Masked $base))
  if ($run.ModeLine) { & $speak $run.ModeLine; $nv = Get-NewerVersionText; if ($nv) { & $speak $nv; $run.Summary += $nv } }
  if ($run.Deploy) { $blk = Get-InstalledBlock $script:app; if ($blk) { throw ($blk + '. No step ran') } }   # S1, S2: before any step
  if ($script:noWindowWhy) { & $speak ('Note: no window could open, so the round runs in text mode. Reason: ' + (ConvertTo-Masked $script:noWindowWhy)) }
  if (Test-WordOpen) { & $speak 'Note: Word is open. Renders use Word: save your documents and close Word if a step stops.' }
  & $speak ''
  Write-BundleFile $base $speak
  if ($script:closing) { throw 'the window was closed (Exit) while the round ran; no step ran' }
  $fl = Save-RoundDownload $base $speak
  if ($fl) { $run.Summary += $fl }
  # A deploy needs every file: with a failed download no step runs (deploy v1 item 5).
  if ($run.Deploy -and $script:roundBad) { throw 'a file this install needs could not be downloaded, so no step ran. Check the network connection, then run again' }
  # An empty box clears the saved address (review R06 #5).
  if (-not $run.Deploy) { try { if ($To -or (Get-MailTo $base)) { Save-MailTo $base $To } } catch { & $speak ('NOTE: could not save the e-mail address: ' + (ConvertTo-Masked $_.Exception.Message)) } }
  if ($cleanup.Count) {
    if ($Clean) {
      $run.N++; $script:prog.Index = $run.N; $script:prog.Cur = 10; $script:prog.CurKnown = $false; $script:prog.Frac = -1; $script:prog.Start = Get-Date
      & $OnStatus $run.N $run.Units 'Clean-up' 0; & $speak ''; $run.Summary += (Invoke-Cleanup $base $speak)
      $script:prog.Done += 10; $script:prog.Cur = 0
    }
    elseif ($run.Resumed) { $run.Summary += 'Clean-up: not run again (the round resumed)' }   # it could recycle what the kept steps made
    else { $run.Summary += 'Clean-up: SKIPPED by you' }
  }
}

# Returns the name of the first step that step $K needs ("after" in the manifest) and that has not PASSED, in this run
# or (deploy) at this version before; '' when every needed step passed.
function Get-StepNeed($run, [int]$K) {
  foreach ($a in @($steps[$K].After)) {
    if (-not $a) { continue }
    $okA = $(if ($run.RunState.ContainsKey([string]$a)) { $run.RunState[[string]$a] -eq 'PASSED' } else { $run.Prior[[string]$a] -eq 'PASSED' })
    if (-not $okA) { return [string]$a }
  }
  return ''
}

# Runs selected step $K: its heading in the log, the step itself (a script, or a hand step of kind "guide"), its result
# line, its record (state and made list), the bars and the history. Takes the run table, the step index, the person's
# answer and the window callbacks; changes $run (Summary, Whole, RunState, StepRecs, N, K1).
function Invoke-RoundStepAt($run, [int]$K, [string]$Ans, [scriptblock]$Tick, [scriptblock]$OnStep, [scriptblock]$OnStatus) {
  $speak = $run.Speak; $step = $steps[$K]
  $est = Get-StepEstimate $run.Hist $step.Name
  $w = Get-StepWeight $run.Hist $step
  $run.N++; $run.K1++
  $script:prog.Index = $run.N; $script:prog.Cur = $w.Seconds; $script:prog.CurKnown = $w.Known; $script:prog.Frac = -1; $script:prog.FracText = ''; $script:prog.Start = Get-Date
  & $OnStatus $run.N $run.Units $step.Name $est
  & $speak ''
  & $speak ('Step ' + $run.K1 + ' of ' + $run.Total + ': ' + $step.Name)
  if ($step.Note) { & $speak ('  ' + $step.Note) }
  & $speak ('  Started ' + (Get-Date -Format 'HH:mm') + $(if ($est) { '. Last successful run took ' + (Format-Duration $est) + '.' } else { '.' }))
  $t0 = Get-Date
  # "after" (manifest): a step runs only when each step it needs PASSED, in this run or (deploy) at this version before.
  $need = Get-StepNeed $run $K
  if ($need) { $r = @{ Pass = 0; Fail = 0; Exit = 0; Skipped = $true; Why = 'it needs "' + $need + '" to pass first' }; & $speak ('    Skipped: ' + $r.Why + '.') }
  elseif ($step.Kind -eq 'guide') { $r = Invoke-GuideStep $run.Base $step $speak }
  else { $r = Invoke-RoundStep $run.Base $step $speak $Tick $Ans }
  if ((Get-StepState $r) -ne 'SKIPPED') { $script:ranSteps += $step.Name }   # a step you skip, or one that only printed SKIP, expects no result files
  $secs = ((Get-Date) - $t0).TotalSeconds
  $state = Get-StepState $r
  if ($state -eq 'NEEDS REVIEW') { $script:roundBad = $true }
  if ($state -ne 'PASSED' -and -not [bool]$step.Optional) { $run.Whole = $false }   # a skipped step is not installed (review, deploy v1); an optional step that fails makes the run NEEDS REVIEW
  $made = @($r.Made | Where-Object { $_ }); if ($state -eq 'PASSED') { foreach ($m in @($step.Makes)) { $made += @{ kind = [string]$m.kind; name = [string]$m.name } } }
  $run.RunState[[string]$step.Name] = $state
  if (-not $need) { $run.StepRecs[[string]$step.Name] = @{ state = $state; made = $made } }   # a step skipped for a missing dependency keeps its older record
  $line = Get-StepLine $step $r $secs
  $lines = @($line) + @($r.Answers | Where-Object { $_ } | ForEach-Object { [string]$_ })   # a hand step's answers, under its line
  & $speak ('  Result: ' + ($line.Substring($step.Name.Length + 2)))
  if ($state -eq 'NEEDS REVIEW' -and $step.Help) { $hl = '  What to do: ' + $step.Help; & $speak $hl; $lines += $hl }   # the step's own help text (manifest "help")
  $run.Summary += $lines
  $run.Done += @{ Name = [string]$step.Name; State = $state; Lines = $lines; Made = $made }
  $script:prog.Done += $script:prog.Cur; $script:prog.Cur = 0; $script:prog.Frac = -1
  & $OnStep $K $line
  Add-RoundHistory $run.Base $step.Name $(if ($state -eq 'PASSED') { 'OK' } else { 'CHECK' }) ([int]$secs)
  Save-RoundState $run $run.Sel   # pause and resume: the state after each step that ends (12-resume.ps1)
  if ($state -eq 'INTERRUPTED') {   # the CAC is out: stop here; the state above lets Resume run this step again
    throw ('INTERRUPTED: the sign-in failed in step "' + (Get-StepTitle $step) + '". Insert your CAC, then select Resume') }
}

# L4 (the Administrator, 2026-11-19), test rounds only: asks the last question "Anything else about this round or the app?"
# in the window ($script:feedbackUi) and gives back its report line. The text is masked as a text answer is and kept
# whole; empty is allowed. Text mode asks nothing. Takes the log callback; gives back the line "Other feedback: ...".
function Get-RoundFeedback([scriptblock]$Say) {
  if ($script:textMode -or -not $script:feedbackUi) { $v = 'not asked (text mode)' }
  else { $v = ConvertTo-UserText ([string](@(& $script:feedbackUi))[-1]); if (-not $v) { $v = '(none)' } }
  & $Say ('Other feedback: ' + $v)
  return ('Other feedback: ' + $v)
}

# Test rounds only: runs the shared-file self-test (docs/engine.md "Shared files") on a scratch folder that is removed
# again, logs its lines and adds one summary line. Changes $run.Summary and, on a failure, the round state.
function Test-RoundSharedFile($run) {
  $speak = $run.Speak
  $sf = @(Test-SharedFile (Join-Path (Join-Path (Join-Path $run.Base 'Rounds') $round) ('selftest' + $PID)))
  foreach ($l in $sf) { & $speak ('  ' + $l) }
  $sfBad = @($sf | Where-Object { $_ -notmatch '^PASS ' }).Count
  $run.Summary += ('Shared-file self-test: ' + ($sf.Count - $sfBad) + ' passed, ' + $sfBad + ' failed')
  if ($sfBad) { $script:roundBad = $true }
  & $speak ''
}

# A run that stops midway still leaves a report to send (the summary so far and the log up to the stop); a deploy also
# records the part install, here and (when the app keeps one) on the site. Takes the run table and the error record.
function Save-StoppedRound($run, $Err) {
  $run.Summary[0] = '@@PREFIX@@ ' + $round + ' STOPPED'
  $run.Summary += ('STOPPED: ' + (ConvertTo-Masked ([string]$Err)))
  if ($run.Deploy) { $run.Summary += (Get-HelpLine); & $run.SayRaw (Get-HelpLine); $sv = Save-Installed 'STOPPED' $run.Whole $run.StepRecs; if ($sv) { $run.Summary += ('NOTE: the installed-version record could not be saved: ' + $sv) }
    # A stopped run that reached a step is a part install too: record it on the site (never when the own record failed).
    if ($script:app.Marker -and $run.StepRecs.Count -and -not $sv) { try { $mw = Write-SiteMarker $run.Base $false; $run.Summary += $mw; & $run.SayRaw $mw } catch { $null = $_ } } }
  [void](Export-RoundResult $run.Base $run.Summary)
  Add-RoundHistory $run.Base 'ROUND' 'STOPPED' ([int]((Get-Date) - $run.Started).TotalSeconds)
}

# Deploy v1: nothing leaves this computer. The report stays in Rounds\<round>; the version record (and, when the app
# keeps one, the row on the site) is updated, and the made list is logged. Takes the run table, the final state and
# whether a step needs review.
function Complete-DeployRun($run, [string]$State, [bool]$Bad) {
  $speak = $run.Speak
  $script:draftMade = $false
  $sv = Save-Installed $State $run.Whole $run.StepRecs
  if ($sv) { & $speak ('NOTE: the installed-version record (RADE\Config\installed) could not be saved: ' + $sv) }
  if ($Bad) { & $speak ('Note: one or more items need review (see above). The report in Rounds\' + $round + ' shows what went wrong. Nothing was sent.'); & $speak (Get-HelpLine) }
  elseif (-not $run.Whole) { & $speak ('Note: some steps were off or skipped, so version ' + $script:app.Version + ' is not recorded as installed. Run again with every step on.') }
  else {
    & $speak ('Version ' + $script:app.Version + ' of ' + $script:app.Name + ' is recorded as installed.')
  }
  # Never when the own record could not be saved: the row would then stop this account's next run.
  if ($script:app.Marker -and $run.StepRecs.Count -and -not $sv) { $mw = Write-SiteMarker $run.Base ([bool]($run.Whole -and -not $Bad)); & $speak $mw; $run.Summary += $mw }
  $ml = @(Get-MadeLine); if ($ml.Count) { foreach ($l in $ml) { & $speak $l }; $run.Summary += $ml }
  [void](Export-RoundResult $run.Base $run.Summary)   # the report also holds the deploy notes and the made list
  & $speak ('DONE in ' + (Format-Duration ((Get-Date) - $run.Started).TotalSeconds) + '. The report is in Rounds\' + $round + ' on this computer. Nothing was sent.')
}

# Test rounds (R05): an Outlook draft with the summary and every result file; if Outlook cannot make one, the results
# folder opens and the summary is on the clipboard, with the steps to make the e-mail by hand. Takes the run table, the
# results (Export-RoundResult), the To address, the window's line callback and whether a step needs review.
function Complete-TestRun($run, $Z, [string]$To, [scriptblock]$WindowLine, [bool]$Bad) {
  $speak = $run.Speak; $summary = $run.Summary
  if ($Bad) { & $speak 'Note: one or more items need review (see above). Send the results anyway; they show what went wrong.' }
  $why = Save-RoundDraft $Z.Dir $summary $To (& $WindowLine)
  $script:draftMade = (-not $why)
  if ($script:draftMade) {
    & $speak ('DONE in ' + (Format-Duration ((Get-Date) - $run.Started).TotalSeconds) + '. An Outlook draft is open with the subject "' + $summary[0] + '", the summary and all result files (' + $Z.Count + ').')
    & $speak $(if ($To) { 'Review the draft, then select Send.' } else { 'Enter the To address in the draft (or in the box here for next time), then select Send.' })
  } else {
    & $speak ('The Outlook draft could not be created (' + $why + ').')
    & $speak ('DONE. The results folder Rounds\' + $round + ' is open and the summary is on the clipboard.')
    & $speak ('Create a new e-mail: paste the summary into the body, move the first line ("' + $summary[0] + '") into the subject, and attach all files from the folder (' + $Z.Count + ').')
  }
}

# Runs one round from start to end: the preparation, each selected step in order, the shared-file self-test (test
# rounds), the results folder and then the deploy record or the e-mail draft. Every line goes to $Say (with a "what to
# do" line after a known problem). Takes the window's choices and callbacks; returns the summary lines (line 1 = the
# subject). A run that stops writes its report first, then throws again.
function Invoke-Round([bool]$Clean, [bool[]]$Selected, [string]$To, [scriptblock]$Say, [scriptblock]$Tick, [scriptblock]$OnStep, [scriptblock]$OnStatus, [scriptblock]$WindowLine, [string[]]$Answers, [string[]]$CheckLines) {
  $resume = $script:resume; $script:resume = $null   # the round state to resume from (window or text mode), once
  if ($resume) { $Clean = $false; $Selected = Get-ResumeSelection $resume }
  $run = Initialize-RoundRun $Clean $Selected $Say $CheckLines
  if ($resume) { Initialize-RoundResume $run $resume }
  $sayRaw = $Say
  # Logs a line, then a "what to do" line when the line names a known problem. Not a closure (GetNewClosure would hide
  # the bundle's own functions): the Round functions are called from here, so they find $sayRaw in this scope.
  $run.Speak = { param($t) & $sayRaw $t; $w = Get-WhatToDo $t; if ($w) { & $sayRaw $w } }
  $speak = $run.Speak
  try {
    Invoke-RoundSetup $run $Clean $To $OnStatus
    for ($k = 0; $k -lt $steps.Count; $k++) {
      if ($script:closing) { throw 'the window was closed (Exit) while the round ran; the steps after it did not run' }
      if (-not $Selected[$k]) { if ($script:appSteps -contains $k) { $run.Summary += ($steps[$k].Name + $(if ($run.Prior[[string]$steps[$k].Name] -eq 'PASSED') { ': already done for version ' + $script:app.Version + ', not run again' } else { ': not selected' })) }; continue }
      if ($run.Kept.ContainsKey([string]$steps[$k].Name)) { Restore-RoundStep $run $k $OnStep; continue }   # resume: a passed step stays done
      $ans = ''; if ($Answers -and $Answers.Count -gt $k) { $ans = [string]$Answers[$k] }
      Invoke-RoundStepAt $run $k $ans $Tick $OnStep $OnStatus
    }
    & $speak ''
    if (-not $run.Deploy) { $run.Summary += (Get-RoundFeedback $speak); Test-RoundSharedFile $run }
    if ($script:closing) { throw 'the window was closed (Exit) while the round ran' }
    $run.Summary += (Get-FolderInventory $run.Base)
  } catch {
    Save-StoppedRound $run $_
    throw
  }
  $z = Export-RoundResult $run.Base $run.Summary
  $run.Summary += ('Results folder: Rounds\' + $round + ', files: ' + $z.Count + $(if (@($z.Missing).Count) { '; ' + @($z.Missing).Count + ' expected files missing: ' + ($z.Missing -join ', ') } else { '; no expected file missing' }) + '.')
  & $speak $run.Summary[-1]
  $bad = $script:roundBad   # a step that needs review, a failed clean-up or download, or a missing result file
  $state = $(if ($bad) { 'NEEDS REVIEW' } else { 'PASSED' })
  $run.Summary[0] = '@@PREFIX@@ ' + $round + ' ' + $state
  [void](Export-RoundResult $run.Base $run.Summary)   # rewrite so the report holds the RESULTS line and the subject
  Add-RoundHistory $run.Base 'ROUND' $(if ($bad) { 'CHECK' } else { 'OK' }) ([int]((Get-Date) - $run.Started).TotalSeconds)
  $script:resultsDir = $z.Dir
  # The round ended: nothing to resume, so its state file goes.
  try { $sp = Get-RoundStatePath $run.Base; if (Test-Path -LiteralPath $sp -PathType Leaf) { Remove-Item -LiteralPath $sp -Force -ErrorAction Stop } }
  catch { & $speak ('NOTE: the round state could not be removed: ' + (ConvertTo-Masked $_.Exception.Message)) }
  & $speak ''
  if ($run.Deploy) { Complete-DeployRun $run $state $bad; return ,$run.Summary }
  Complete-TestRun $run $z $To $WindowLine $bad
  return ,$run.Summary
}
