# RADE engine part 02, settings and history: time text, step titles, the saved window place, the results
# e-mail address, the round history file, the newer-round look-up and the "What to do" help lines. Uses 01-base.ps1.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# Turns seconds into text like "3m 05s". Takes the seconds (a number); gives back the text.
function Format-Duration([double]$Seconds) {
  $s = [int][math]::Round($Seconds)
  return ('{0}m {1:00}s' -f [math]::Floor($s / 60), ($s % 60))
}
# What the window calls a step to a person: its manifest "title", else its name. The log, the report, the summary, the results
# files and every key keep the name.
function Get-StepTitle($Step) { if ($Step -and [string]$Step.Title) { return [string]$Step.Title }; return [string]$Step.Name }
# Says whether Word is running. Takes nothing; gives back $true or $false.
function Test-WordOpen { return (@(Get-Process -Name WINWORD -ErrorAction SilentlyContinue).Count -gt 0) }
# Says whether the text is one or more e-mail addresses separated by ";". Takes the text; gives back $true or $false.
# Sends nothing.
function Test-MailTo([string]$To) {
  $one = '[^@\s;,]+@[^@\s;,]+\.[^@\s;,]+'
  return ($To -match ('^\s*' + $one + '(\s*;\s*' + $one + ')*\s*;?\s*$'))
}
# Returns the path of a file in the app's Config folder. Takes the app folder and the file name.
function Get-ConfigFile([string]$Base, [string]$Name) { return (Join-Path (Join-Path $Base 'Config') $Name) }
# Returns the path of a file in RADE's own Config folder (a test can set $script:configOver). Takes the file name.
function Get-RadeConfigFile([string]$Name) { if ($script:configOver) { return (Join-Path $script:configOver $Name) }; return (Join-Path (Join-Path (Get-RadePath) 'Config') $Name) }   # the engine's own settings (R17)
# engine-v48: $true after the last app's Uninstall moved RADE\Config to the Recycle Bin (Clear-UninstallRecord, part 17).
# Then the window place and the tour mark are not written again, so the closing window does not make RADE\Config again.
$script:radeConfigGone = $false
function Read-WindowState {
  # R28 (the Administrator, 2026-11-17): where the user last closed the window. RADE\Config\rade-window.json (a cache: when it
  # is lost or does not read, the window opens maximized on the screen with the mouse). { x, y, w, h, state, dpi, closed: { w, h, state } }
  try { $p = Get-RadeConfigFile 'rade-window.json'
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $null }
    $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
    foreach ($k in 'x', 'y', 'w', 'h') { if ($null -eq $j.$k -or -not ([string]$j.$k -match '^-?\d{1,5}$')) { return $null } }
    if ([int]$j.w -lt 100 -or [int]$j.h -lt 100) { return $null }
    $st = $(if ([string]$j.state -eq 'Maximized') { 'Maximized' } else { 'Normal' })
    $cl = ''; if ($j.closed -and [string]$j.closed.w -match '^\d{1,5}$' -and [string]$j.closed.h -match '^\d{1,5}$') { $cl = [string]$j.closed.w + 'x' + [string]$j.closed.h + '/' + [string]$j.closed.state -replace '[^A-Za-z0-9/x]', '' }
    return @{ X = [int]$j.x; Y = [int]$j.y; W = [int]$j.w; H = [int]$j.h; State = $st; Dpi = $(if ([string]$j.dpi -match '^\d{2,3}$') { [int]$j.dpi } else { 0 }); Closed = $cl }
  } catch { return $null }
}
function Save-WindowState([int]$X, [int]$Y, [int]$W, [int]$H, [string]$State, [int]$Dpi, [int]$ClientW, [int]$ClientH, [string]$CloseState) {
  # Numbers and two words only: no name, path or text. A write that fails is ignored (the window is closing).
  if ($script:radeConfigGone) { return }   # engine-v48: the last Uninstall took RADE\Config
  try { $o = [ordered]@{ about = 'RADE window place (a cache; delete it to open maximized again)'; x = $X; y = $Y; w = $W; h = $H; state = $State; dpi = $Dpi; closed = [ordered]@{ w = $ClientW; h = $ClientH; state = $CloseState } }
    Write-FileWhole (Get-RadeConfigFile 'rade-window.json') (($o | ConvertTo-Json -Depth 4) + "`r`n") } catch { $null = $_ }
}
# L6 (the Administrator, 2026-11-19): says whether the RADE tour was shown for this Windows profile before
# (RADE\Config\rade-tour.txt is there). Takes nothing; gives back $true or $false ($true when the file cannot be looked
# for, so a problem never shows the tour each time).
function Test-TourSeen { try { return [bool](Test-Path -LiteralPath (Get-RadeConfigFile 'rade-tour.txt') -PathType Leaf) } catch { return $true } }
# Remembers that the RADE tour was shown: writes the date to RADE\Config\rade-tour.txt; a failure is ignored. Takes
# nothing; gives back nothing.
function Save-TourSeen {
  if ($script:radeConfigGone) { return }   # engine-v48: the last Uninstall took RADE\Config
  try { $p = Get-RadeConfigFile 'rade-tour.txt'; $d = Split-Path -Parent $p
    if (-not (Test-Path -LiteralPath $d -PathType Container)) { [void](New-Item -ItemType Directory -Path $d -Force) }
    Write-FileWhole $p ((Get-Date -Format 'yyyy-MM-dd') + "`r`n") } catch { $null = $_ }   # not saved: the tour shows one more time
}
function Get-MailTo([string]$Base) {
  # RADE\Config\rade-mail-to.txt: the address the results e-mail goes to (PFM 13 Nov; RADE R17). The window box saves it.
  # Until it exists, the app's old Config\@@PREFIX@@-mail-to.txt is read.
  foreach ($p in @((Get-RadeConfigFile 'rade-mail-to.txt'), (Get-ConfigFile $Base '@@PREFIX@@-mail-to.txt'))) {
    if (Test-Path -LiteralPath $p -PathType Leaf) { try { return ([string](Get-Content -LiteralPath $p -TotalCount 1)).Trim() } catch { return '' } }
  }
  return ''
}
# Writes the results e-mail address to RADE\Config\rade-mail-to.txt, creating the folder if needed. Takes the base
# folder (not used) and the address; gives back nothing.
function Save-MailTo([string]$Base, [string]$To) {
  $null = $Base
  $p = Get-RadeConfigFile 'rade-mail-to.txt'
  $dir = Split-Path -Parent $p
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
  [System.IO.File]::WriteAllText($p, ($To.Trim() + "`r`n"), (New-Object System.Text.UTF8Encoding $true))
}
function Read-RoundHistory([string]$Base) {
  # Config\@@PREFIX@@-history.csv: round, step, finish time, status, seconds (no DODID). Feeds the banner and the estimates.
  $p = Get-ConfigFile $Base '@@PREFIX@@-history.csv'
  if (Test-Path -LiteralPath $p -PathType Leaf) { try { return @(Import-Csv -LiteralPath $p) } catch { return @() } }
  return @()
}
# Adds one row (round, step, time, status, seconds) to the history file; a failure is ignored. Takes the base folder,
# step name, status and seconds; gives back nothing.
function Add-RoundHistory([string]$Base, [string]$Step, [string]$Status, [int]$Seconds) {
  try {
    $p = Get-ConfigFile $Base '@@PREFIX@@-history.csv'
    $dir = Split-Path -Parent $p
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    [pscustomobject]@{ Round = $round; Step = $Step; Finished = (Get-Date -Format 'yyyy-MM-dd HH:mm'); Status = $Status; Seconds = $Seconds } |
      Export-Csv -LiteralPath $p -Append -NoTypeInformation
  } catch { $null = $_ }   # history is a convenience: never stop a round for it
}
function Get-NewerRound {
  # Reads go.md in the repository (the bookmark page's source; data, not code) and returns the highest round number listed in an open task
  # heading when it is newer than this one, else ''. Short timeout; any failure is silent, so it never blocks a run.
  try {
    $rq = Get-WebRequest $goUrl 4000   # engine/ps/07-checks.ps1: no Windows sign-in for the address, only for the proxy
    $rs = $rq.GetResponse()
    try { $text = (New-Object System.IO.StreamReader($rs.GetResponseStream())).ReadToEnd() } finally { $rs.Close() }
    $mine = [int]($round -replace '\D', '')
    $max = 0
    foreach ($m in [regex]::Matches($text, '(?m)^## [^\r\n]*Round R(\d{2})[^\r\n]*\(open')) { $n = [int]$m.Groups[1].Value; if ($n -gt $max) { $max = $n } }
    if ($max -gt $mine) { return ('R{0:00}' -f $max) }
  } catch { $null = $_ }
  return ''
}
# Gives the one line about the last round on this computer, or says none is recorded. Takes the history rows; gives back
# the text.
function Get-LastRoundText($Hist) {
  $r = @($Hist | Where-Object { $_.Step -eq 'ROUND' })
  if (-not $r.Count) { return 'Last round on this computer: none recorded yet.' }
  $l = $r[-1]
  $word = @{ OK = 'passed'; CHECK = 'needed review'; STOPPED = 'stopped' }[[string]$l.Status]; if (-not $word) { $word = [string]$l.Status }
  return ('Last round on this computer: ' + $l.Round + ' ' + $word + ' on ' + $l.Finished + ' (took ' + (Format-Duration ([double]$l.Seconds)) + ').')
}
# Returns the seconds of the last successful run of a step on this computer, or 0. Takes the history and the step name.
function Get-StepEstimate($Hist, [string]$Name) {
  $r = @($Hist | Where-Object { $_.Step -eq $Name -and $_.Status -eq 'OK' -and $_.Seconds })   # last good run only
  if ($r.Count) { return [int]$r[-1].Seconds }
  return 0
}
$helpRules = @(
  @{ Re = 'FOLDER not found|PROFILE folder'; Text = 'OneDrive is not set up in this Windows profile. Open OneDrive from the Start menu, sign in, wait until it says it is up to date, then run again.' },
  @{ Re = 'being used by another process|cannot access the file'; Text = 'A file is open in another program. Close Word and any file or Explorer window from the RADE folder, then press Run again.' },
  @{ Re = 'RPC_E_CALL_REJECTED|0x80010001|0x8001010A|server busy'; Text = 'Word was busy. Close every Word window, wait 10 seconds, then press Run again.' },
  @{ Re = 'ran longer than'; Text = 'A step ran too long. Close Word (check the taskbar), then press Run again. If it happens twice, send the results as they are.' },
  @{ Re = 'LABEL (FAIL|not set)'; Text = 'The sensitivity label was not set. Keep the Config folder; see "Sensitivity label" in the repository (go.md).' },
  # engine-v46 (90-161.Z R45 finding 1): a script policy block, before the general rule below (its text was wrong for it).
  @{ Re = 'running scripts is disabled|is not digitally signed'; Covers = 'denied|UnauthorizedAccess'
    Text = 'Windows did not let a step script run (its script policy). RADE runs it once more. If the step still fails, send the results as they are.' },
  @{ Re = 'denied|UnauthorizedAccess'; Text = 'Windows blocked a file. Check that the RADE folder is in your own OneDrive and not read-only, then run again.' },
  @{ Re = 'Outlook draft could not be created'; Text = 'Open Outlook (classic), then press Make e-mail draft. Or send by hand: the results folder is open and the summary is on the clipboard.' },
  @{ Re = 'FORMAT-FAIL'; Text = 'The renderer found a format problem. Send the results as they are; Claude fixes it.' },
  @{ Re = 'NO IMAGES'; Text = 'The seal images are not on this computer yet. Send the results; Claude checks how the seal e-mails were delivered.' },
  @{ Re = 'Clean-up could not'; Text = 'A file could not go to the Recycle Bin (it may be open). Close it; the next round tries again.' },
  @{ Re = 'e-mail address does not look right'; Text = 'Type one address like name@example.com (several: separate with ;), or leave the box empty.' }
)
# Gives a "What to do: ..." help line for a log line that matches a known problem, once for each problem in a round;
# else an empty text. Takes the log line; marks the problem as helped.
function Get-WhatToDo([string]$Line) {
  foreach ($h in $helpRules) {
    if ($Line -match $h.Re -and -not $script:helped.ContainsKey($h.Re)) { $script:helped[$h.Re] = $true
      if ($h.Covers) { $script:helped[[string]$h.Covers] = $true }   # engine-v46: a more exact rule keeps the general one quiet
      return ('What to do: ' + $h.Text) }
  }
  return ''
}
