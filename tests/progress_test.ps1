# Two bars and the check gate (moved from rhope-ops/90-161.Z tests, 2026-11-15): progress math, the PROGRESS line rule and
# the gate, taken from a built bundle's own functions. Prints one line; tests/engine_test.sh compares it.
param([string]$Bundle)
$src = Get-Content -LiteralPath $Bundle -Raw
foreach ($n in 'Format-Duration', 'Get-Progress', 'Get-CheckBlock') { Invoke-Expression ([regex]::Match($src, "(?s)function $n\b.*?\n}\n").Value) }
$re = [regex]::Match($src, "if \(\`$line -match '([^']+)'\) \{\s+if \(\`$script:prog").Groups[1].Value
$now = Get-Date
# One clock for the whole test: the bundle's Get-Progress reads Get-Date, and a function wins over the cmdlet in this
# scope. Without it a busy CPU moved "now" between the set-up and the read (0.376 for 0.375; DECISIONS 2026-11-16).
function Get-Date { $now }
# Done 100 of 400 s; this step weighs 100 s, ran 90 s and reports 1 of 10: 10 %, about 810 s left in it, 200 s after it.
$script:prog = @{ Total = 400.0; Done = 100.0; Cur = 100.0; CurKnown = $true; Known = $true; Start = $now.AddSeconds(-90); Frac = 0.1; FracText = '1 of 10' }
$g = Get-Progress
$a = '{0:N2} {1:N2} {2}' -f $g.Step, $g.All, [int][math]::Round($g.Left / 10)
# No report and no earlier run: the step fraction is unknown (-1); the overall bar still moves with time.
$script:prog = @{ Total = 400.0; Done = 100.0; Cur = 100.0; CurKnown = $false; Known = $false; Start = $now.AddSeconds(-50); Frac = -1.0 }
$h = Get-Progress
# The step bar fills left to right with time when the fraction is unknown (StepShown 50/100 s = 0.50).
'{0} | {1:N0} {2:N3} {6:N2} | {3} {4} {5}' -f $a, $h.Step, $h.All, ('  PROGRESS 3/10' -match $re), ('PROGRESS 3 of 10' -match $re), ('PROGRESS done' -match $re), $h.StepShown
# The gate: WARNING passes; FAILED, NOT RUN or a missing result blocks.
$script:appChecks = @('a', 'b')
$ok = @{ a = @{ State = 'PASSED' }; b = @{ State = 'WARNING' } }
$f = @{ a = @{ State = 'PASSED' }; b = @{ State = 'FAILED' } }
$n = @{ a = @{ State = 'NOT RUN' }; b = @{ State = 'PASSED' } }
$m = @{ a = @{ State = 'PASSED' } }
'gate {0} {1} {2} {3}' -f (Get-CheckBlock $ok), (Get-CheckBlock $f), (Get-CheckBlock $n), (Get-CheckBlock $m)
