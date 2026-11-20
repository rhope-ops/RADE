# RADE test: pause and resume (docs/engine.md "Pause and resume") and no scripts in results, on the engine parts
# themselves (no bundle, no window). Run by tests/resume_test.sh: pwsh -NoProfile -File tests/resume_unit.ps1 <scratch folder>.
# Prints one PASS or FAIL line for each case, then "RESUME-UNIT pass=N fail=M".
# Network: none.
# Writes: only inside the scratch folder it is given.
# Credentials: none.
# Runs on PowerShell 7 (the cloud tests).
param([Parameter(Mandatory = $true)][string]$Dir)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
foreach ($p in '01-base', '02-config', '03-files', '04-steps', '05-installed', '12-resume') { . (Join-Path $root ('engine/ps/' + $p + '.ps1')) }
# What a bundle sets before the engine: fake data only.
$round = 'R01'; $buildId = 'abcd1234'; $script:app = @{ Name = 'Sample app' }; $script:appSteps = @(0, 1, 2)
$steps = @(@{ Name = 'T01 One' }, @{ Name = 'T02 Two' }, @{ Name = 'T03 Three' })
$scriptExts = @('.ps1', '.psm1', '.psd1', '.bat', '.cmd', '.vbs', '.js', '.wsf', '.hta', '.py', '.sh', '.exe', '.dll', '.msi', '.lnk', '.scr')
$script:runLog = New-Object System.Collections.Generic.List[string]
$script:pass = 0; $script:fail = 0
# Records one case. Takes the case name and whether it held.
function Assert-Case([string]$Name, [bool]$Ok) { if ($Ok) { $script:pass++; Write-Host ('PASS ' + $Name) } else { $script:fail++; Write-Host ('FAIL ' + $Name) } }

$base = Join-Path $Dir 'RADE\SampleApp'
$run = @{ Base = $base; Done = @(@{ Name = 'T01 One'; State = 'PASSED'; Lines = @('T01 One: PASSED (1 passed, 0 failed, exit code 0) in 1s'); Made = @(@{ kind = 'list'; name = 'Fake list' }) },
    @{ Name = 'T02 Two'; State = 'INTERRUPTED'; Lines = @('T02 Two: INTERRUPTED (0 passed, 1 failed, exit code 1) in 2s'); Made = @() }) }
$script:runLog.Add('Step 1 of 3: T01 One')
# write: the state file is whole JSON in Rounds\<round>, and no temporary file stays.
Save-RoundState $run @($true, $true, $true)
$sp = Get-RoundStatePath $base
Assert-Case 'write: the state file is in Rounds\R01' ((Test-Path -LiteralPath $sp) -and $sp.EndsWith((Join-Path (Join-Path 'Rounds' 'R01') 'rade-state.json')))
Assert-Case 'write: no temporary file stays' (@(Get-ChildItem -LiteralPath (Split-Path -Parent $sp) -Filter '*.tmp*').Count -eq 0)
$j = Get-Content -LiteralPath $sp -Raw | ConvertFrom-Json
Assert-Case 'write: round, build, steps and log' ($j.round -eq 'R01' -and $j.build -eq 'abcd1234' -and @($j.steps).Count -eq 2 -and @($j.log)[0] -eq 'Step 1 of 3: T01 One')
# read: the same round and build resume at the first step that has not passed (T02, which was interrupted).
$st = Read-RoundState $base
Assert-Case 'read: same build reads ok' ($st.State -eq 'ok')
Assert-Case 'read: resume at step 2 of 3' ($st.Next -eq 2 -and $st.Total -eq 3)
# resume: only the passed step is kept, with its made list; the selection comes back.
$kept = Get-ResumeKept $st.Doc
Assert-Case 'resume: keeps the passed step only' ($kept.Count -eq 1 -and $kept.ContainsKey('T01 One'))
$sel = Get-ResumeSelection $st.Doc
Assert-Case 'resume: the selection comes back' ($sel.Count -eq 3 -and $sel[0] -and $sel[1] -and $sel[2])
$r2 = @{ Summary = @(); Kept = @{} }; Initialize-RoundResume $r2 $st.Doc
$marks = @($script:runLog | Where-Object { $_ -like '---- resumed *' }).Count
Assert-Case 'resume: the earlier log comes back under a marker' ($script:runLog -contains 'Step 1 of 3: T01 One' -and $marks -eq 1 -and $r2.Summary[0] -like 'Resumed: 1 finished steps kept*')
# build mismatch: another build of the same round never resumes.
$buildId = 'ffff0000'; $st = Read-RoundState $base; $buildId = 'abcd1234'
Assert-Case 'build mismatch: another build is not resumed' ($st.State -eq 'other')
# start over: the state file goes (Recycle Bin on Windows; a plain delete here).
Assert-Case 'start over: the state file is moved away' ((Clear-RoundState $base) -eq '' -and -not (Test-Path -LiteralPath $sp))
Assert-Case 'start over: no file reads as none' ((Read-RoundState $base).State -eq 'none')
# corrupt state file: read as bad, with a plain reason (the window and text mode then start over).
[System.IO.File]::WriteAllText($sp, '{ "schema": "rade-state/1", "round": ')
$st = Read-RoundState $base
Assert-Case 'corrupt: a cut file reads as bad' ($st.State -eq 'bad' -and $st.Why -eq 'the file is not valid JSON')
[System.IO.File]::WriteAllText($sp, '{ "note": "something else" }')
Assert-Case 'corrupt: another JSON reads as bad' ((Read-RoundState $base).State -eq 'bad')
# CAC removed: a failed sign-in line makes the step INTERRUPTED, not NEEDS REVIEW; another failure stays NEEDS REVIEW.
$r = @{ Pass = 0; Fail = 0; Skip = 0; Exit = 1; Made = @(); Fallback = ''; SignIn = $false }
Add-StepLine 'FAIL Connect: the smart card was removed' @{ ScreenOnly = '' } $r '' { param($t) $null = $t }
Assert-Case 'CAC out: the step is INTERRUPTED' ((Get-StepState $r) -eq 'INTERRUPTED')
$r = @{ Pass = 0; Fail = 0; Skip = 0; Exit = 1; Made = @(); Fallback = ''; SignIn = $false }
Add-StepLine 'FAIL the list has no column' @{ ScreenOnly = '' } $r '' { param($t) $null = $t }
Assert-Case 'other failure: the step NEEDS REVIEW' ((Get-StepState $r) -eq 'NEEDS REVIEW')
# No scripts in results: the collect step copies no script file, and logs one line for it.
$src = Join-Path $base 'T22'; [void](New-Item -ItemType Directory -Path $src -Force)
foreach ($n in 'SAMPLE-T22-feedback-r1.ps1', 'SAMPLE-T22-feedback-r1.pdf', 'SAMPLE-T22-feedback-r1.cmd') { Set-Content -LiteralPath (Join-Path $src $n) -Value 'fake' }
$collect = @(@{ Dir = 'T22'; Name = 'SAMPLE-T22-feedback-*'; Step = '' }); $script:ranSteps = @()
$z = Export-RoundResult $base @('subject', 'line')
$got = @(Get-ChildItem -LiteralPath $z.Dir -File | ForEach-Object { $_.Name })
Assert-Case 'collect: the PDF is copied' ($got -contains 'T22-SAMPLE-T22-feedback-r1.pdf')
Assert-Case 'collect: no script file is copied' (-not @($got | Where-Object { $_ -match '\.(ps1|cmd)$' }).Count)
$one = @($script:runLog | Where-Object { $_ -eq 'SKIPPED script file SAMPLE-T22-feedback-r1.ps1 (scripts never go in results)' }).Count
Assert-Case 'collect: one SKIPPED line for each script file' ($one -eq 1 -and @($script:runLog | Where-Object { $_ -like 'SKIPPED script file *' }).Count -eq 2)
Write-Host ('RESUME-UNIT pass=' + $script:pass + ' fail=' + $script:fail)
