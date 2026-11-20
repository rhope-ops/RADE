# RADE engine part 12, pause and resume (the PFM, 2026-11-20: every app needs a pause and resume for when the user
# closes the window, removes the CAC or is stopped in any other way). After each step ends, the round state goes to
# Rounds\<round>\rade-state.json; the same round of the same build can resume from it (docs/engine.md "Pause and resume").
# Uses parts 01 to 06 (Write-FileWhole, Move-ToRecycleBin, the run table); called by 06-round.ps1, the window and text mode.
# Network: none.
# Writes: Rounds\<round>\rade-state.json only (a temporary file, then one replace); Start over moves it to the Recycle Bin.
# Credentials: none.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

$stateName = 'rade-state.json'   # the state file in the round's results folder; never attached to the e-mail draft
$stateSchema = 'rade-state/1'
# A step line that says the sign-in failed: the CAC may be out. Such a step is INTERRUPTED, not FAILED (the PFM, 2026-11-20).
$signInLost = '(?i)smart ?card|sign-?in (failed|was cancel+ed|timed out)|authentication (failed|was cancel+ed)|user cancel+ed authentication'

# Gives the path of the round state file. Takes the RADE app folder; gives back Rounds\<round>\rade-state.json.
function Get-RoundStatePath([string]$Base) { return (Join-Path (Join-Path (Join-Path $Base 'Rounds') $round) $stateName) }

# Writes the round state after a step ends: round, build, application, time, the selected steps, each finished step
# (state, its summary lines, its record) and the log so far. A failed write never stops the round: it is one log line.
# Takes the run table and the selection; gives back nothing.
function Save-RoundState($run, [bool[]]$Selected) {
  try {
    $sel = @(); for ($k = 0; $k -lt $steps.Count; $k++) { if ($Selected[$k]) { $sel += [string]$steps[$k].Name } }
    $done = @(foreach ($d in @($run.Done)) { @{ name = [string]$d.Name; state = [string]$d.State; lines = @($d.Lines); made = @($d.Made) } })
    $doc = [ordered]@{ schema = $stateSchema; round = [string]$round; build = [string]$buildId; app = [string]$script:app.Name
      saved = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'); selected = $sel; steps = $done; log = @($script:runLog) }
    Write-FileWhole (Get-RoundStatePath $run.Base) (ConvertTo-Json -InputObject $doc -Depth 6)
  } catch { Add-RunLog ('NOTE: the round state could not be saved: ' + (ConvertTo-Masked $_.Exception.Message)) }
}

<#
.SYNOPSIS
Reads the round state file Rounds\<round>\rade-state.json.
.DESCRIPTION
Only a file of this round, this build and this application can resume; another build never resumes (the PFM,
2026-11-20). Next and Total give "Resume at step Next of Total": Next is the first selected step that a resume runs.
The state of another application of the same paste reads as 'none' and stays in place.
.PARAMETER Base
The RADE app folder.
.OUTPUTS
@{ State; Why; Doc; Next; Total }. State: 'none' (no file), 'ok', 'other' (another round, build or application) or
'bad' (the file cannot be read); Why says why in plain words.
#>
function Read-RoundState([string]$Base) {
  $res = @{ State = 'none'; Why = ''; Doc = $null; Next = 0; Total = 0 }
  $p = Get-RoundStatePath $Base
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $res }
  try { $j = [System.IO.File]::ReadAllText($p) | ConvertFrom-Json -ErrorAction Stop } catch { $res.State = 'bad'; $res.Why = 'the file is not valid JSON'; return $res }
  if (-not $j -or [string]$j.schema -ne $stateSchema -or $null -eq $j.selected -or $null -eq $j.steps) {
    $res.State = 'bad'; $res.Why = 'the file is not a RADE round state'; return $res }
  if ([string]$j.app -ne [string]$script:app.Name) { return $res }   # another application of this paste: its state stays for it
  if ([string]$j.round -ne [string]$round -or [string]$j.build -ne [string]$buildId) {
    $res.State = 'other'; $res.Why = 'it was saved by build ' + [string]$j.build; return $res }
  $sel = @($j.selected | ForEach-Object { [string]$_ }); $kept = Get-ResumeKept $j
  $res.Total = $sel.Count; $res.Next = $sel.Count
  for ($i = 0; $i -lt $sel.Count; $i++) { if (-not $kept.ContainsKey($sel[$i])) { $res.Next = $i + 1; break } }
  if (-not $sel.Count) { $res.State = 'bad'; $res.Why = 'the file names no step'; return $res }
  $res.State = 'ok'; $res.Doc = $j
  return $res
}

# Gives the finished steps a resume keeps: every step that ended (passed, failed, skipped, answered), not the one that
# was INTERRUPTED (CAC out, or the window closed while it ran). Takes the state document; gives back name to saved step.
function Get-ResumeKept($Doc) {
  $kept = @{}
  foreach ($s in @($Doc.steps)) { if ($s -and [string]$s.state -and [string]$s.state -ne 'INTERRUPTED') { $kept[[string]$s.name] = $s } }
  return $kept
}

# Start over (and a state file that cannot be read, or of another build): moves the state file to the Recycle Bin.
# Takes the RADE app folder; gives back '' or why it could not be moved.
function Clear-RoundState([string]$Base) {
  $p = Get-RoundStatePath $Base
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return '' }
  try { Move-ToRecycleBin $p; return '' } catch { return (ConvertTo-Masked $_.Exception.Message) }
}

# Gives the selection a resume runs: the steps the state names. Takes the state document; gives back one bool for each step.
function Get-ResumeSelection($Doc) {
  $names = @($Doc.selected | ForEach-Object { [string]$_ })
  $sel = @(); for ($k = 0; $k -lt $steps.Count; $k++) { $sel += [bool]($script:appSteps -contains $k -and $names -contains [string]$steps[$k].Name) }
  return ,$sel
}

# Starts a resumed run: the earlier log goes back into the run log under a marker line, and the summary says where the
# run resumes. Takes the run table and the state document; changes $run.Summary and the run log.
function Initialize-RoundResume($run, $Doc) {
  $run.Resumed = $true; $run.Kept = Get-ResumeKept $Doc
  foreach ($l in @($Doc.log)) { Add-RunLog ([string]$l) }
  Add-RunLog ('---- resumed ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + ' (the lines above are from the run that stopped) ----')
  $run.Summary += ('Resumed: ' + $run.Kept.Count + ' finished steps kept from the run saved at ' + ([string]$Doc.saved -replace 'T', ' ') + '.')
}

<#
.SYNOPSIS
Puts a kept step back into a resumed run, as if it ran; it does not run again.
.DESCRIPTION
Adds its summary lines, its saved state (for "after"), its record and made list, the step counters and its weight on
the overall bar, logs one "kept from the earlier run" line and tells the window that the step ended.
.PARAMETER run
The run table (Invoke-Round); its Kept table holds the saved step.
.PARAMETER K
The step index.
.PARAMETER OnStep
The window's step-ended callback.
.OUTPUTS
Nothing; changes $run.
#>
function Restore-RoundStep($run, [int]$K, [scriptblock]$OnStep) {
  $step = $steps[$K]; $s = $run.Kept[[string]$step.Name]; $lines = @($s.lines | ForEach-Object { [string]$_ }); $st = [string]$s.state
  $run.N++; $run.K1++
  $made = @(foreach ($m in @($s.made)) { if ($m) { @{ kind = [string]$m.kind; name = [string]$m.name } } })
  $run.RunState[[string]$step.Name] = $st; $run.StepRecs[[string]$step.Name] = @{ state = $st; made = $made }
  if ($st -ne 'SKIPPED') { $script:ranSteps += $step.Name }; $run.Summary += $lines
  if ($st -eq 'NEEDS REVIEW') { $script:roundBad = $true }; if ($st -ne 'PASSED' -and -not [bool]$step.Optional) { $run.Whole = $false }
  $run.Done += @{ Name = [string]$step.Name; State = $st; Lines = $lines; Made = $made }
  $script:prog.Done += (Get-StepWeight $run.Hist $step).Seconds
  & $run.Speak ('Step ' + $run.K1 + ' of ' + $run.Total + ': ' + $step.Name + ': kept from the earlier run (' + $st + '), not run again.')
  & $OnStep $K $lines[0]
}
