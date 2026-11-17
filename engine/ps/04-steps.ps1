function Invoke-RoundStep([string]$Base, $Step, [scriptblock]$Say, [scriptblock]$Tick, [string]$Answer) {
  $exe = 'powershell.exe'
  if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { $exe = 'pwsh' }
  $dir = Join-Path $Base $Step.Dir
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $exe
  $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $dir $Step.File) + '" -Id "' + $script:dodid + '" -NoPause'
  if ($Step.Args) { $psi.Arguments += ' ' + $Step.Args }   # fixed arguments from the round (for example -Set T12)
  if ($Step.AskParam -and $Answer) {
    # A trailing \ before the closing quote would escape it (command-line rules): trim it, but a drive root keeps its \,
    # doubled so "D:\\" reads back as D:\ (review R08).
    $a = $Answer; if ($a.Length -gt 3) { $a = $a.TrimEnd('\') }
    if ($a.EndsWith('\')) { $a += '\' }
    $psi.Arguments += ' -' + $Step.AskParam + ' "' + $a + '"'
  }
  $psi.WorkingDirectory = $dir
  $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
  $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
  try { $envs = Get-StepEnv $Base $Step; foreach ($k in @($envs.Keys)) { $psi.EnvironmentVariables[[string]$k] = [string]$envs[$k] } } catch { & $Say ('    NOTE: the step inputs could not be set: ' + (ConvertTo-Masked $_.Exception.Message)) }
  $r = @{ Pass = 0; Fail = 0; Skip = 0; Exit = $null; Made = @(); Fallback = '' }
  $siteNow = [string](Get-SiteUrl $Base)
  $p = [System.Diagnostics.Process]::Start($psi)
  $script:child = $p
  $limit = $stepMinutes; if ($Step.Minutes) { $limit = [int]$Step.Minutes }   # a step that waits for a person sets its own limit
  $deadline = (Get-Date).AddMinutes($limit)
  $errTask = $p.StandardError.ReadToEndAsync()
  $lineTask = $p.StandardOutput.ReadLineAsync()
  while ($true) {
    while (-not $lineTask.Wait(30)) {   # 30 ms: the window's bars move smoothly (R17)
      & $Tick
      if ((Get-Date) -gt $deadline) { try { $p.Kill() } catch { $null = $_ }; $r.Fail++; & $Say ('    STOPPED: the step ran longer than ' + $limit + ' minutes and was ended.'); break }
    }
    if (-not $lineTask.IsCompleted) { break }
    $line = $lineTask.Result
    if ($null -eq $line) { break }
    $line = ConvertTo-Masked $line
    # "PROGRESS n/m" (or "n of m") from a step script moves the step bar and stays out of the log (PFM 14 Nov 26).
    if ($line -match '^\s*PROGRESS\s+(\d+)\s*(?:/|of)\s*(\d+)\s*$') {
      if ($script:prog -and [int]$Matches[2] -gt 0) { $script:prog.Frac = [math]::Min(1.0, [double]$Matches[1] / [double]$Matches[2]); $script:prog.FracText = $Matches[1] + ' of ' + $Matches[2] }
      $lineTask = $p.StandardOutput.ReadLineAsync(); continue
    }
    # "MADE <kind>: <name>": something the step created (a list, a flow, a file); kept for the undo list (step contract).
    # A MADE line is never a result: it is logged with the cleaned name and not counted as PASS, FAIL or SKIP (review).
    if ($line -cmatch '^\s*MADE\s+([a-z][a-z-]{0,30}):\s+(\S.*)$') {
      $mk = $Matches[1]; $mn = ConvertTo-MadeName $Matches[2] $siteNow; $r.Made += @{ kind = $mk; name = $mn }
      & $Say ('    MADE ' + $mk + ': ' + $mn); $lineTask = $p.StandardOutput.ReadLineAsync(); continue
    }
    # "FALLBACK: <route>": the step used its documented fallback route (for a user with fewer rights). Not a result line;
    # a step that passes this way reads PASSED (fallback) and counts as passed (docs/engine.md "Results").
    if ($line -cmatch '^\s*FALLBACK:\s+(\S.*)$') {
      $r.Fallback = ConvertTo-MadeName $Matches[1] $siteNow
      & $Say ('    FALLBACK: ' + $r.Fallback); $lineTask = $p.StandardOutput.ReadLineAsync(); continue
    }
    # Lines that may name a unit or a file (for example seal details) never reach the report (data boundary).
    if ($Step.ScreenOnly -and $line -match $Step.ScreenOnly) { $line = ($line -replace '^(\S+).*$', '$1') + ' (detail hidden: it may hold a name; run the step script by hand to see it)' }
    if ($line -match '(^|\s)PASS(\s|$)') { $r.Pass++ }
    if ($line -cmatch '(^|\s)SKIP(\s|$)') { $r.Skip++ }   # upper case only: prose such as "skip this" is not a result
    if ($line -match '(^|\s)(FAIL|FORMAT-FAIL|RENDER-ERROR|MEASURE-ERROR|STOPPED:)(\s|$)') { $r.Fail++ }
    if ($line.Trim()) { & $Say ('    ' + $line) }   # step output, indented under its step heading
    $lineTask = $p.StandardOutput.ReadLineAsync()
  }
  $p.WaitForExit()
  $script:child = $null
  foreach ($e in @(([string]$errTask.Result) -split "`r?`n" | Where-Object { $_ })) { $r.Fail++; & $Say ('    Error output: ' + (ConvertTo-Masked $e)) }
  $r.Exit = $p.ExitCode
  return $r
}
function Get-StepState($R) {
  if ($R.Skipped) { return 'SKIPPED' }
  if ($R.Fail -gt 0 -or $R.Exit -ne 0) { return 'NEEDS REVIEW' }
  if ($R.Pass -eq 0 -and $R.Skip -gt 0) { return 'SKIPPED' }   # the step found nothing to do (R18: was PASSED with 0 passed)
  return 'PASSED'
}
function Get-StepLine($Step, $R, [double]$Seconds) {
  # One line per step in the summary and the e-mail: name, result, check counts, time.
  $state = Get-StepState $R
  if ($R.Skipped) { return ($Step.Name + ': SKIPPED' + $(if ($R.Why) { ' (' + $R.Why + ')' } else { ' by you' })) }
  if ($Step.Kind -eq 'guide' -and $R.FailText) { return ($Step.Name + ': FAILED (reported by you) in ' + (Format-Duration $Seconds) + ': ' + $R.FailText) }
  if ($Step.Kind -eq 'guide') { return ($Step.Name + ': ' + $state + ' (confirmed by you) in ' + (Format-Duration $Seconds)) }
  if ($state -eq 'PASSED' -and $R.Fallback) { $state = 'PASSED (fallback: ' + $R.Fallback + ')' }
  return ($Step.Name + ': ' + $state + ' (' + $R.Pass + ' passed, ' + $R.Fail + ' failed' + $(if ($R.Skip) { ', ' + $R.Skip + ' skipped' } else { '' }) + ', exit code ' + $R.Exit + ') in ' + (Format-Duration $Seconds))
}
function Copy-TextToClipboard([string]$Text) {
  try { [System.Windows.Forms.Clipboard]::SetText($Text); return $true } catch { $null = $_ }
  try { if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) { Set-Clipboard -Value $Text; return $true } } catch { $null = $_ }
  return $false
}
function ConvertTo-UserText([string]$Text) {
  # Text a person typed (the "It failed" text, a text answer): one line, the DODID masked, no e-mail or site address.
  $t = ((ConvertTo-Masked $Text) -replace '\s+', ' ').Trim()
  $t = $t -replace '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '<EMAIL>'   # e-mail first: the site rule would leave the name before @
  return ($t -replace 'https?://\S+', '<SITE>' -replace '[A-Za-z0-9.-]+\.(sharepoint|sharepoint-mil|onmicrosoft)\.[A-Za-z.]+\S*', '<SITE>')   # no address reaches the e-mail
}
function Invoke-GuideStep([string]$Base, $Step, [scriptblock]$Say) {
  $r = @{ Pass = 0; Fail = 0; Exit = 0; Skipped = $false; FailText = ''; Answers = @() }
  $script:guideAnswers = @{}
  $dir = Join-Path $Base $Step.Dir
  $file = $(if ($Step.File) { Join-Path $dir $Step.File } else { '' })   # R18: a guide step may need no file
  $url = $Step.Url
  $urlFile = ''
  if ($Step.UrlConfig) {
    $urlFile = Get-ConfigFile $Base $Step.UrlConfig
    if (Test-Path -LiteralPath $urlFile -PathType Leaf) { try { $v = ([string](Get-Content -LiteralPath $urlFile -TotalCount 1)).Trim(); if ($v -match '^https://') { $url = $v } } catch { $null = $_ } }
  }
  # An old marker from an earlier run would make site setup wait for a result that is not coming (review R13 #2).
  if ($Step.Marker) { $old = Join-Path $dir $Step.Marker; if (Test-Path -LiteralPath $old -PathType Leaf) { try { Remove-Item -LiteralPath $old -Force } catch { $null = $_ } } }
  if ($Step.File) { & $Say ('    File ready: ' + $Step.Dir + '\' + $Step.File) }
  if ($script:textMode) {
    foreach ($l in @($Step.Guide)) { & $Say ('    ' + $l) }
    if ($url) { & $Say ('    Address: ' + $url) }   # R28 N1: a step with no address shows none
    if ($file -and (Copy-TextToClipboard $file)) { & $Say '    The full file path is on the clipboard.' }
    if ($url -and $env:OS -eq 'Windows_NT') { try { Start-Process -FilePath $url } catch { $null = $_ } }
    $a = [string](Read-Host 'Press Enter when the flow run has started, type F and Enter if it failed, or S and Enter to skip this step'); $a = $(if ($a) { $a.Trim() } else { '' })   # no input (closed stdin) gives no value, not ''
    $res = $(if ($a -match '^[Ss]') { 'Cancel' } elseif ($a -match '^[Ff]') { 'Abort' } else { 'OK' })
    if ($res -eq 'Abort') { $script:guideError = [string](Read-Host 'Paste the error message (no names or site address), then press Enter') }
  } elseif ($script:guideUi) { $res = [string](@(& $script:guideUi $Step $file $url $urlFile))[-1] }   # the window shows the step as a card and waits for the answer
  else { $res = 'Cancel' }
  $ok = ($res -eq 'OK')
  if ($res -eq 'Abort') {
    $t = ConvertTo-UserText ([string]$script:guideError)
    if ($t.Length -gt 600) { $t = $t.Substring(0, 600) + ' ...' }
    if (-not $t) { $t = 'no error text given' }
    $r.Fail = 1; $r.FailText = $t
    & $Say ('    Failed (reported by you): ' + $t)
  } elseif ($ok) {
    if ($Step.Marker) { try { Set-Content -LiteralPath (Join-Path $dir $Step.Marker) -Value (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -Encoding UTF8 } catch { $null = $_ } }
    $r.Pass = 1
    & $Say ('    ' + $(if ($Step.DoneLog) { $Step.DoneLog } else { 'Confirmed by you: the flow is imported and its run has started.' }))
    # The step's questions (manifest "answers"), asked after Done: one line each for the summary, under the step's line.
    foreach ($q in @($Step.Answers | Where-Object { $_ })) {
      $k = [string]$q.Key
      if ($script:textMode) { $v = 'not asked (text mode)' }
      elseif (-not $script:guideAnswers.ContainsKey($k)) { $v = 'not answered (the window closed)' }
      elseif ($q.Kind -eq 'text') { $v = ConvertTo-UserText ([string]$script:guideAnswers[$k]); if (-not $v) { $v = '(no text)' } }   # the full answer (R28: it was cut at 120 characters)
      else { $v = [string]$script:guideAnswers[$k] }   # yes/no and pick: the fixed words of the buttons
      $r.Answers += ('  Answer ' + $k + ': ' + $v)
    }
  } else { $r.Skipped = $true; & $Say '    Skipped by you.' }
  return $r
}
function Add-RunLog([string]$T) { if ($null -ne $script:runLog) { $script:runLog.Add($T) } }
function Export-RoundResult([string]$Base, [string[]]$Summary) {
  # One folder of plain files to attach to one e-mail (zips do not cross the boundary, PFM 13 Nov).
  $out = Join-Path (Join-Path $Base 'Rounds') $round
  if (-not (Test-Path -LiteralPath $out -PathType Container)) { [void](New-Item -ItemType Directory -Path $out -Force) }
  $count = 1; $missing = @()
  foreach ($c in $collect) {
    if ($c.Step -and -not ($script:ranSteps -contains $c.Step)) { continue }   # a skipped step has nothing to send
    $src = Join-Path $Base $c.Dir
    if ($c.Name -match '[*?]') {
      # A pattern (R10: any saved page counts, whatever its name); top level only, so a browser's "_files" folders stay out.
      # Several patterns may be joined with ';' ("*.mhtml;*.pdf"): missing only when none of them finds a file.
      # Windows -Filter '*.htm' also matches '.html': keep each file once. Copies carry the task prefix (T09-..., T12-...) so
      # two tasks never overwrite each other, and older copies of that task are removed first (review R10).
      $hits = @(); if (Test-Path -LiteralPath $src -PathType Container) { foreach ($pat in ($c.Name -split ';')) { $hits += @(Get-ChildItem -LiteralPath $src -File -Filter $pat -ErrorAction SilentlyContinue) } }
      $hits = @($hits | Sort-Object FullName -Unique)
      Get-ChildItem -LiteralPath $out -File -Filter ($c.Dir + '-*') -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
      foreach ($h in $hits) { Copy-Item -LiteralPath $h.FullName -Destination (Join-Path $out ($c.Dir + '-' + $h.Name)) -Force; $count++ }
      if (-not $hits.Count) { $missing += ($c.Dir + '\' + $c.Name) }
      continue
    }
    $old = Join-Path $out $c.Name
    if (Test-Path -LiteralPath $old -PathType Leaf) { Remove-Item -LiteralPath $old -Force }   # an older copy of the same name must not be sent again
    $p = Join-Path $src $c.Name
    if (Test-Path -LiteralPath $p -PathType Leaf) { Copy-Item -LiteralPath $p -Destination (Join-Path $out $c.Name) -Force; $count++ } else { $missing += ($c.Dir + '\' + $c.Name) }
  }
  if ($missing.Count) { $script:roundBad = $true }
  $report = Join-Path $out ('@@PREFIX@@-' + $round + '-report-r1.txt')
  $body = @($Summary) + @('', '---------------- full log ----------------') + @($script:runLog)
  [System.IO.File]::WriteAllText($report, (($body -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding $true))
  return @{ Dir = $out; Count = $count; Missing = $missing }
}
function Get-RoundPlan {
  # What this round writes and recycles, before it runs (PFM 13 Nov: show the impact; show the real path).
  $base = Get-BasePath
  $found = Test-Path -LiteralPath (Get-OneDrivePath) -PathType Container
  $mv = Get-RadeMove
  $shown = $(if ($mv.Needed) { $mv.To } else { $base })
  $lines = @(('Working folder: ' + $shown + $(if ($found) { '' } else { '   (NOT found: OneDrive is not set up in this Windows profile)' })), '')
  if ($mv.Needed) { $lines += @(('Folder move (runs first): OneDrive\' + $appFolder + '  ->  OneDrive\RADE\' + $appFolder), '  One move inside your OneDrive; every file keeps its place. If it cannot run, this round uses the old folder.', '') }
  $lines += 'Files this round saves:'
  foreach ($f in $files) {
    $p = Join-Path (Join-Path $base $f.Dir) $f.Name
    $lines += ($(if (Test-Path -LiteralPath $p -PathType Leaf) { '  Replace   ' } else { '  New       ' }) + $f.Dir + '\' + $f.Name)
  }
  foreach ($f in $fetch) {
    $p = Join-Path (Join-Path $base $f.Dir) $f.Name
    $lines += ($(if (Test-Path -LiteralPath $p -PathType Leaf) { '  Replace   ' } else { '  New       ' }) + $f.Dir + '\' + $f.Name + '  (downloaded from ' + ([uri]$f.Url).Host + $(if ($f.Sha) { ', checked' } else { '' }) + ')')
  }
  $lines += ('  Results   Rounds\' + $round + '\  (one report file and copies of the result files)')
  if ($cleanup.Count) {
    $cp = @{ Lines = @(); Kept = 0 }
    if (Test-Path -LiteralPath $base -PathType Container) { $cp = Get-CleanupPlan $base }
    if ($cp.Lines.Count) { $lines += ''; $lines += 'Clean-up (runs first; moves files to the Recycle Bin; clear its check box to skip):'; $lines += $cp.Lines }
    else { $lines += ''; $lines += 'Clean-up: nothing to recycle.' }
  }
  $lines += ''
  $lines += ('Settings   RADE\Config (' + $(if (Test-Deploy) { 'the installed versions' } else { 'the e-mail address' }) + ' and the saved checks) and Config\@@PREFIX@@-site.txt (the site address).')
  if ((Test-Deploy) -and $script:app.Marker) {
    $lines += ''
    $lines += ('On the site   after the steps, one row in the list "' + $script:app.Marker.List + '" (row "' + $script:app.Marker.Key + '": the installed version and the date, no name).')
    if (Test-FirstInstall) { $lines += ('First install from this account. Install ' + $script:app.Name + ' once for each wing, on one site: RADE stops a second install on this site, but it cannot see an install on another site.') }
  }
  $lines += ''
  $lines += 'Missing folders are created and files of the same name are replaced. Nothing else is changed, moved or deleted.'
  return @{ Shown = $shown; Found = $found; Lines = $lines }
}
function Save-RoundDraft([string]$Dir, [string[]]$Summary, [string]$To, [string]$WindowLine) {
  # One Outlook draft with subject, body and every results file (R05, PFM 13 Nov); To from the window box (R06).
  # Never sent: this code has no Send call (tests/run.sh checks). Classic Outlook only (new Outlook has no COM): else fall back.
  if ($env:OS -ne 'Windows_NT') { return 'not Windows' }
  try {
    $ol = New-Object -ComObject Outlook.Application
    $m = $ol.CreateItem(0)
    $m.Subject = $Summary[0]
    if ($To) { $m.To = $To }
    $m.Body = ((@($Summary | Select-Object -Skip 1) + @('', $WindowLine)) -join "`r`n")
    foreach ($f in @(Get-ChildItem -LiteralPath $Dir -File)) { [void]$m.Attachments.Add($f.FullName) }
    $m.Display()   # first: if it fails, nothing is left in Drafts
    $m.Save()
    return ''
  } catch { return (ConvertTo-Masked $_.Exception.Message) }
}
function Test-Deploy { return ([string]$script:app.Mode -eq 'deploy') }
