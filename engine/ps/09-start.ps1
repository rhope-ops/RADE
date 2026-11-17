# RADE engine part 09, the start: step weights and progress, the shared state variables, Select-App and Get-AppFact, the
# NIPR guard that stops an unsupported computer before anything is written, and the load of Windows Forms for the window.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.
# ---- Progress (PFM 14 Nov 26: two bars, overall and this step, so the finish time can be estimated). Weights are seconds:
# the last successful run on this computer, else the step's estimate from the round, else 2 minutes. Inside a step the bar
# follows "PROGRESS n/m" lines from the step script; without them it follows elapsed time against the weight (at most 95 %).
function Get-StepWeight($Hist, $Step) {
  $e = Get-StepEstimate $Hist $Step.Name
  if ($e) { return @{ Seconds = [double]$e; Known = $true } }
  if ($Step.Estimate) { return @{ Seconds = [double]$Step.Estimate; Known = $false } }
  return @{ Seconds = 120.0; Known = $false }
}
function Get-Progress {
  # Returns the step fraction (-1 = unknown), the overall fraction and the seconds left, from $script:prog.
  $p = $script:prog
  if (-not $p) { return @{ Step = -1; StepShown = 0.0; All = 0; Left = 0; Known = $false } }
  $el = 0; if ($p.Start) { $el = ((Get-Date) - $p.Start).TotalSeconds }
  $f = -1.0
  if ($p.Frac -ge 0) { $f = [double]$p.Frac }
  elseif ($p.Cur -gt 0 -and $p.CurKnown) { $f = [math]::Min(0.95, $el / $p.Cur) }
  $fa = $f; if ($fa -lt 0 -and $p.Cur -gt 0) { $fa = [math]::Min(0.9, $el / $p.Cur) }; if ($fa -lt 0) { $fa = 0.0 }
  $all = 0.0; if ($p.Total -gt 0) { $all = [math]::Min(1.0, ($p.Done + $p.Cur * $fa) / $p.Total) }
  # Time left in this step: from the script's own fraction when it reports one, else the weight minus the time so far.
  $curLeft = [math]::Max(0.0, $p.Cur - $el)
  if ($p.Frac -gt 0) { $curLeft = $el * (1 - $p.Frac) / $p.Frac }
  $left = [math]::Max(0.0, $p.Total - $p.Done - $p.Cur) + $curLeft
  return @{ Step = $f; StepShown = $fa; All = $all; Left = $left; Known = $p.Known; Elapsed = $el }
}
$script:secret = @(); $script:dodid = ''; $script:child = $null; $script:runLog = $null; $script:resultsDir = ''; $script:draftMade = $false; $script:textMode = $false; $script:helped = @{}; $stepMinutes = 30
$script:statusBase = ''; $script:stepStart = $null; $script:stepEst = 0; $script:noWindowWhy = ''; $script:ranSteps = @(); $script:prog = $null; $script:roundStart = Get-Date
$helpChannel = 'RHOPE-OPS'   # a placeholder name (the Administrator, 14 Nov 26); a name only, never a link or an address
$script:checkResults = @{}; $script:closing = $false; $script:guideUi = $null; $checkGate = $true   # tests turn the gate off to run steps
$script:checkHost = $null; $script:savedWhy = @{}
function Select-App([int]$I) {
  # The chosen application: its steps and the checks they need (the embedded catalog; PFM 14 Nov 26: no fetch, 3A).
  $script:app = $apps[$I]; $script:appSteps = @($script:app.Steps); $script:appChecks = @($script:app.Checks); $script:checkResults = @{}
}
Select-App 0
function Get-AppFact($A, $Hist) {
  # Choose: the facts of one application (steps, time, checks; for a deploy the version and what is installed).
  $est = 0; $you = 0
  foreach ($k in $A.Steps) { $est += (Get-StepWeight $Hist $steps[$k]).Seconds; if ($steps[$k].Kind -eq 'guide') { $you++ } }
  $n = @($A.Steps).Count
  $t = [string]$n + $(if ($n -eq 1) { ' step' } else { ' steps' }) + $(if ($you) { ', ' + $you + $(if ($you -eq 1) { ' needs you' } else { ' need you' }) } else { '' })
  $t += $dot + 'about ' + [math]::Max(1, [int][math]::Round($est / 60)) + ' min' + $dot + @($A.Checks).Count + ' checks'
  $i = Get-InstalledText $A; if ($i) { $i = $i.Substring(0, 1).ToUpperInvariant() + $i.Substring(1) }
  return @{ Steps = $t; Installed = $i }
}
if (-not (Test-NiprDevice)) {
  # Before anything is written: no folder, no file, no saved check, no e-mail, no window.
  Write-Host 'This application cannot be installed in your environment.'
  return
}
$gui = $true
try { Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing } catch { $gui = $false; $script:noWindowWhy = 'Windows Forms not available: ' + $_.Exception.Message }
