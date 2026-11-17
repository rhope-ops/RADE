function Invoke-Round([bool]$Clean, [bool[]]$Selected, [string]$To, [scriptblock]$Say, [scriptblock]$Tick, [scriptblock]$OnStep, [scriptblock]$OnStatus, [scriptblock]$WindowLine, [string[]]$Answers, [string[]]$CheckLines) {
  $script:ranSteps = @()
  $script:roundBad = $false
  $script:runLog = New-Object System.Collections.Generic.List[string]
  $script:helped = @{}
  $sayRaw = $Say
  $speak = { param($t) & $sayRaw $t; $w = Get-WhatToDo $t; if ($w) { & $sayRaw $w } }
  $base = Resolve-Base
  $hist = Read-RoundHistory $base
  $started = Get-Date
  # Line 1 is the e-mail subject (PFM 13 Nov); PASSED or NEEDS REVIEW is added at the end (R06; words R13).
  $summary = @(('@@PREFIX@@ ' + $round), ('Round ' + $round + ', build ' + $buildId + ', started ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')))
  $summary += ('Application: ' + $script:app.Name)
  $deploy = Test-Deploy
  $prior = Get-StepPrior   # empty in a test round
  # A step that is off still counts when the record says it PASSED at this version (safe second run).
  $whole = $true; foreach ($k in $script:appSteps) { if (-not [bool]$steps[$k].Optional -and -not $Selected[$k] -and $prior[[string]$steps[$k].Name] -ne 'PASSED') { $whole = $false } }   # an optional step ("default": false) is not needed for "installed"
  $stepRecs = @{}; $runState = @{}   # runState: every step this run reached (the "after" check); stepRecs: what goes to the record
  $modeLine = ''; if ($deploy) { $modeLine = 'Mode: deploy, ' + (Get-InstalledText $script:app); $summary += $modeLine }
  if ($CheckLines) { $summary += $CheckLines }
  $units = 0
  # Overall bar: each unit weighs its expected seconds (Get-StepWeight); files and clean-up weigh little.
  $script:prog = @{ Total = 5.0; Done = 0.0; Cur = 0.0; CurKnown = $false; Known = $true; Start = $null; Frac = -1.0; FracText = ''; Index = 0; Count = 0 }
  if ($Clean -and $cleanup.Count) { $units++; $script:prog.Total += 10 }
  $total = 0
  for ($k = 0; $k -lt $steps.Count; $k++) {
    if (-not $Selected[$k]) { continue }
    $units++; $total++
    $w = Get-StepWeight $hist $steps[$k]; $script:prog.Total += $w.Seconds; if (-not $w.Known) { $script:prog.Known = $false }
  }
  $script:prog.Count = $units
  $n = 0; $k1 = 0
  try {
  & $speak ('RADE, round ' + $round + ' (build ' + $buildId + '), started ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  $base = Move-ToRade $speak
  & $speak ('Working folder: ' + (ConvertTo-Masked $base))
  if ($modeLine) { & $speak $modeLine; $nv = Get-NewerVersionText; if ($nv) { & $speak $nv; $summary += $nv } }
  if ($deploy) { $blk = Get-InstalledBlock $script:app; if ($blk) { throw ($blk + '. No step ran') } }   # S1, S2: before any step
  if ($script:noWindowWhy) { & $speak ('Note: no window could open, so the round runs in text mode. Reason: ' + (ConvertTo-Masked $script:noWindowWhy)) }
  if (Test-WordOpen) { & $speak 'Note: Word is open. Renders use Word: save your documents and close Word if a step stops.' }
  & $speak ''
  Write-BundleFile $base $speak
  if ($script:closing) { throw 'the window was closed (Exit) while the round ran; no step ran' }
  $fl = Save-RoundDownload $base $speak
  if ($fl) { $summary += $fl }
  # A deploy needs every file: with a failed download no step runs (deploy v1 item 5).
  if ($deploy -and $script:roundBad) { throw 'a file this install needs could not be downloaded, so no step ran. Check the network connection, then run again' }
  # An empty box clears the saved address (review R06 #5).
  if (-not $deploy) { try { if ($To -or (Get-MailTo $base)) { Save-MailTo $base $To } } catch { & $speak ('NOTE: could not save the e-mail address: ' + (ConvertTo-Masked $_.Exception.Message)) } }
  if ($cleanup.Count) {
    if ($Clean) {
      $n++; $script:prog.Index = $n; $script:prog.Cur = 10; $script:prog.CurKnown = $false; $script:prog.Frac = -1; $script:prog.Start = Get-Date
      & $OnStatus $n $units 'Clean-up' 0; & $speak ''; $summary += (Invoke-Cleanup $base $speak)
      $script:prog.Done += 10; $script:prog.Cur = 0
    }
    else { $summary += 'Clean-up: SKIPPED by you' }
  }
  for ($k = 0; $k -lt $steps.Count; $k++) {
    if ($script:closing) { throw 'the window was closed (Exit) while the round ran; the steps after it did not run' }
    if (-not $Selected[$k]) { if ($script:appSteps -contains $k) { $summary += ($steps[$k].Name + $(if ($prior[[string]$steps[$k].Name] -eq 'PASSED') { ': already done for version ' + $script:app.Version + ', not run again' } else { ': not selected' })) }; continue }
    $est = Get-StepEstimate $hist $steps[$k].Name
    $w = Get-StepWeight $hist $steps[$k]
    $n++; $k1++
    $script:prog.Index = $n; $script:prog.Cur = $w.Seconds; $script:prog.CurKnown = $w.Known; $script:prog.Frac = -1; $script:prog.FracText = ''; $script:prog.Start = Get-Date
    & $OnStatus $n $units $steps[$k].Name $est
    & $speak ''
    & $speak ('Step ' + $k1 + ' of ' + $total + ': ' + $steps[$k].Name)
    if ($steps[$k].Note) { & $speak ('  ' + $steps[$k].Note) }
    & $speak ('  Started ' + (Get-Date -Format 'HH:mm') + $(if ($est) { '. Last successful run took ' + (Format-Duration $est) + '.' } else { '.' }))
    $t0 = Get-Date
    $ans = ''; if ($Answers -and $Answers.Count -gt $k) { $ans = [string]$Answers[$k] }
    # "after" (manifest): a step runs only when each step it needs PASSED, in this run or (deploy) at this version before.
    $need = ''
    foreach ($a in @($steps[$k].After)) {
      if (-not $a) { continue }
      $okA = $(if ($runState.ContainsKey([string]$a)) { $runState[[string]$a] -eq 'PASSED' } else { $prior[[string]$a] -eq 'PASSED' })
      if (-not $okA) { $need = [string]$a; break }
    }
    if ($need) { $r = @{ Pass = 0; Fail = 0; Exit = 0; Skipped = $true; Why = 'it needs "' + $need + '" to pass first' }; & $speak ('    Skipped: ' + $r.Why + '.') }
    elseif ($steps[$k].Kind -eq 'guide') { $r = Invoke-GuideStep $base $steps[$k] $speak }
    else { $r = Invoke-RoundStep $base $steps[$k] $speak $Tick $ans }
    if ((Get-StepState $r) -ne 'SKIPPED') { $script:ranSteps += $steps[$k].Name }   # a step you skip, or one that only printed SKIP, expects no result files
    $secs = ((Get-Date) - $t0).TotalSeconds
    $state = Get-StepState $r
    if ($state -eq 'NEEDS REVIEW') { $script:roundBad = $true }
    if ($state -ne 'PASSED' -and -not [bool]$steps[$k].Optional) { $whole = $false }   # a skipped step is not installed (review, deploy v1); an optional step that fails makes the run NEEDS REVIEW
    $made = @($r.Made | Where-Object { $_ }); if ($state -eq 'PASSED') { foreach ($m in @($steps[$k].Makes)) { $made += @{ kind = [string]$m.kind; name = [string]$m.name } } }
    $runState[[string]$steps[$k].Name] = $state
    if (-not $need) { $stepRecs[[string]$steps[$k].Name] = @{ state = $state; made = $made } }   # a step skipped for a missing dependency keeps its older record
    $line = Get-StepLine $steps[$k] $r $secs
    $summary += $line
    foreach ($al in @($r.Answers | Where-Object { $_ })) { $summary += [string]$al }   # a hand step's answers, under its line
    & $speak ('  Result: ' + ($line.Substring($steps[$k].Name.Length + 2)))
    if ($state -eq 'NEEDS REVIEW' -and $steps[$k].Help) { $hl = '  What to do: ' + $steps[$k].Help; & $speak $hl; $summary += $hl }   # the step's own help text (manifest "help")
    $script:prog.Done += $script:prog.Cur; $script:prog.Cur = 0; $script:prog.Frac = -1
    & $OnStep $k $line
    Add-RoundHistory $base $steps[$k].Name $(if ($state -eq 'PASSED') { 'OK' } else { 'CHECK' }) ([int]$secs)
  }
  & $speak ''
  if (-not $deploy) {
    # Test rounds: the shared-file self-test (docs/engine.md "Shared files"), on a scratch folder that is removed again.
    $sf = @(Test-SharedFile (Join-Path (Join-Path (Join-Path $base 'Rounds') $round) ('selftest' + $PID)))
    foreach ($l in $sf) { & $speak ('  ' + $l) }
    $sfBad = @($sf | Where-Object { $_ -notmatch '^PASS ' }).Count
    $summary += ('Shared-file self-test: ' + ($sf.Count - $sfBad) + ' passed, ' + $sfBad + ' failed')
    if ($sfBad) { $script:roundBad = $true }
    & $speak ''
  }
  if ($script:closing) { throw 'the window was closed (Exit) while the round ran' }
  $summary += (Get-FolderInventory $base)
  } catch {
    # A run that stops midway still leaves a report to send (summary so far + the log up to the stop).
    $summary[0] = '@@PREFIX@@ ' + $round + ' STOPPED'
    $summary += ('STOPPED: ' + (ConvertTo-Masked ([string]$_)))
    if ($deploy) { $summary += (Get-HelpLine); & $sayRaw (Get-HelpLine); $sv = Save-Installed 'STOPPED' $whole $stepRecs; if ($sv) { $summary += ('NOTE: the installed-version record could not be saved: ' + $sv) }
      # A stopped run that reached a step is a part install too: record it on the site (never when the own record failed).
      if ($script:app.Marker -and $stepRecs.Count -and -not $sv) { try { $mw = Write-SiteMarker $base $false; $summary += $mw; & $sayRaw $mw } catch { $null = $_ } } }
    [void](Export-RoundResult $base $summary)
    Add-RoundHistory $base 'ROUND' 'STOPPED' ([int]((Get-Date) - $started).TotalSeconds)
    throw
  }
  $z = Export-RoundResult $base $summary
  $summary += ('Results folder: Rounds\' + $round + ', files: ' + $z.Count + $(if (@($z.Missing).Count) { '; ' + @($z.Missing).Count + ' expected files missing: ' + ($z.Missing -join ', ') } else { '; no expected file missing' }) + '.')
  & $speak $summary[-1]
  $bad = $script:roundBad   # a step that needs review, a failed clean-up or download, or a missing result file
  $state = $(if ($bad) { 'NEEDS REVIEW' } else { 'PASSED' })
  $summary[0] = '@@PREFIX@@ ' + $round + ' ' + $state
  [void](Export-RoundResult $base $summary)   # rewrite so the report holds the RESULTS line and the subject
  Add-RoundHistory $base 'ROUND' $(if ($bad) { 'CHECK' } else { 'OK' }) ([int]((Get-Date) - $started).TotalSeconds)
  $script:resultsDir = $z.Dir
  & $speak ''
  if ($deploy) {
    # Deploy v1: nothing leaves this computer. The report stays in Rounds\<round>; the version record is updated.
    $script:draftMade = $false
    $sv = Save-Installed $state $whole $stepRecs
    if ($sv) { & $speak ('NOTE: the installed-version record (RADE\Config\installed) could not be saved: ' + $sv) }
    if ($bad) { & $speak ('Note: one or more items need review (see above). The report in Rounds\' + $round + ' shows what went wrong. Nothing was sent.'); & $speak (Get-HelpLine) }
    elseif (-not $whole) { & $speak ('Note: some steps were off or skipped, so version ' + $script:app.Version + ' is not recorded as installed. Run again with every step on.') }
    else {
      & $speak ('Version ' + $script:app.Version + ' of ' + $script:app.Name + ' is recorded as installed.')
    }
    # Never when the own record could not be saved: the row would then stop this account's next run.
    if ($script:app.Marker -and $stepRecs.Count -and -not $sv) { $mw = Write-SiteMarker $base ([bool]($whole -and -not $bad)); & $speak $mw; $summary += $mw }
    $ml = @(Get-MadeLine); if ($ml.Count) { foreach ($l in $ml) { & $speak $l }; $summary += $ml }
    [void](Export-RoundResult $base $summary)   # the report also holds the deploy notes and the made list
    & $speak ('DONE in ' + (Format-Duration ((Get-Date) - $started).TotalSeconds) + '. The report is in Rounds\' + $round + ' on this computer. Nothing was sent.')
    return ,$summary
  }
  if ($bad) { & $speak 'Note: one or more items need review (see above). Send the results anyway; they show what went wrong.' }
  # R05: an Outlook draft with everything in it; if Outlook cannot make one, the folder opens and the summary is on the clipboard.
  $why = Save-RoundDraft $z.Dir $summary $To (& $WindowLine)
  $script:draftMade = (-not $why)
  if ($script:draftMade) {
    & $speak ('DONE in ' + (Format-Duration ((Get-Date) - $started).TotalSeconds) + '. An Outlook draft is open with the subject "' + $summary[0] + '", the summary and all result files (' + $z.Count + ').')
    & $speak $(if ($To) { 'Review the draft, then select Send.' } else { 'Enter the To address in the draft (or in the box here for next time), then select Send.' })
  } else {
    & $speak ('The Outlook draft could not be created (' + $why + ').')
    & $speak ('DONE. The results folder Rounds\' + $round + ' is open and the summary is on the clipboard.')
    & $speak ('Create a new e-mail: paste the summary into the body, move the first line ("' + $summary[0] + '") into the subject, and attach all files from the folder (' + $z.Count + ').')
  }
  return ,$summary
}

