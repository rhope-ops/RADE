#!/usr/bin/env python3
"""RADE engine: build an application's round bundles from its RADE manifest (schemas/rade-manifest.schema.json).

Moved from rhope-ops/90-161.Z scripts/build_paste_bundles.py (the Administrator, 2026-11-14: start using this repo).
App facts (name, folder, file prefix, home page, own file patterns, repo) come from the manifest "application" block;
RADE's own logo comes from this repo (assets/logo/logo-K-128.png). The history notes below name 90-161.Z, the first app.

A bundle is one PowerShell text (RADE, the Redacted Application Deployment Engine, PFM 14 Nov 26; formerly the
"90-161.Z Deployer" and the "runner") (Windows PowerShell 5.1) that the PFM copies from its raw page, pastes into
Windows PowerShell ISE and runs with F5. It is a
bootstrapper for fast test rounds (PFM 1A, 6A: function over form):
  1. uses the Windows profile folder as the DODID (no question: PFM 13 Nov, the empty-box default worked) and shows
     the real path on screen (reports and e-mails still mask it);
  1b. recycles finished files (cleanup list in the JSON; only files 90-161.Z made; to the Recycle Bin) and reports
     what it recycled and what is left (folder counts, no file names) in the summary (R06, PFM 13 Nov);
  1c. RADE folder (PFM 14 Nov 26, R17): the app folder is OneDrive\\RADE\\90-161.Z; RADE\\Config holds the engine's own
     settings (rade-mail-to.txt, rade-checks.json); the app's Config stays in 90-161.Z\\Config. On Run, an old
     OneDrive\\90-161.Z folder is moved into RADE as one folder move (if the move fails, the round uses the old folder);
  1d. saved checks (PFM 14 Nov 26): a PASSED check is kept in RADE\\Config\\rade-checks.json for 7 days and is not run
     again (other apps can read the file; its "about" field says how); a new PowerShell or PnP version, another site,
     an older result or "Run checks again" runs it again; a check that did not pass always runs again;
  2. makes each task folder under C:\\Users\\<DODID>\\OneDrive - United States Air Force\\RADE\\90-161.Z if missing and
     writes every file (text: same content as UTF-8 with BOM and CRLF; binary: byte-exact from base64);
  3. runs the steps one by one (each a runner file, as a child powershell.exe with -Id and -NoPause), with a live
     log, DODID masked, and PASS/FAIL counts per step. A step of kind "guide" (R13, PFM 14 Nov 26: RADE
     delivers every file, no separate downloads) is work the PFM does in another program, such as a flow import:
     RADE writes its file, opens the address, puts the file path on the clipboard and waits for Done or Skip.
     Log text (R13, PFM 14 Nov 26): one heading per step ("Step k of n: name"), the step's output indented under it,
     one result line (PASSED, NEEDS REVIEW or SKIPPED); the e-mail subject ends in PASSED or NEEDS REVIEW;
  4. writes a results folder Rounds\\<round> with one report file (summary + full masked log) and copies of the
     collect files (PDFs), ready to attach to one e-mail (no zip: zips do not cross the boundary, PFM 13 Nov);
  5. makes an Outlook draft (classic Outlook, COM): subject = summary line 1, body = the rest, every results file
     attached, never sent (R05); To from the window box, saved in RADE\\Config\\rade-mail-to.txt (R06, R17). If no draft can be made, it opens the results folder and puts
     the summary on the clipboard instead (R04 behavior).
The window (the Administrator, 2026-11-14, "One thing"; docs/window-design.md) shows one statement or one question at a
time: the application, a check that failed or needs you, the plan, the run, a step you do by hand, the result. All
checks, the step boxes, the files, the made list and the log are in the Record (F2). The Local checks run when the window
opens, so an application that cannot run on this computer cannot be chosen. All text the PFM sees is plain, simple
English (PFM 14 Nov 26). The bars are drawn by RADE (still when Windows animations are off). There is no Exit button:
the window's X asks first only while a step runs.
A catalog app of mode deploy (deploy v1, docs/engine.md; the Administrator 14 Nov 26) sends nothing: no draft, no saved
address; it updates the app's own record file in RADE\\Config\\installed (the version installed and the last deploy run).
It runs only the steps embedded in it and never fetches code (PFM 3A). If no window can open (no Windows Forms),
it runs the same steps as text.
Text files are embedded as readable single-quoted here-strings, so anyone can read the code.
The build id (first 8 hex of the sha256 of the bundle body) shows in the window title and the summary.
Usage: python3 engine/rade_build.py --app-root DIR [--manifest scripts/paste_bundles.json] [--check] [--sha]
  --check: exit 1 if a bundle is out of date. --sha: print this file's sha256 (apps pin it).
"""
import base64, hashlib, json, re, sys, textwrap
from pathlib import Path

ENGINE_ROOT = Path(__file__).resolve().parent.parent
LOGO = ENGINE_ROOT / 'assets/logo/logo-K-128.png'   # RADE's own logo (top left of the window)
UI_FILE = ENGINE_ROOT / 'engine/rade_ui.ps1'   # the shared UI file: theme tokens, builders and the layout self-check (R28; docs/engine.md "How an app gets the engine")
ROOT = None   # the application repo root (--app-root)
TEXT = {'.ps1', '.json', '.txt', '.md', '.csv'}



def step_default(s):
    """A step's default tick. "default" may be true/false, or {"passed": <hash>, "paths": [...]}: then the step is on
    only when those files changed since the round that last passed it (PFM 14 Nov 26: no repeat render test)."""
    d = s.get('default', True)
    if isinstance(d, dict):
        return files_hash(d['paths']) != d['passed']
    return bool(d)


def files_hash(paths):
    h = hashlib.sha256()
    for rel in sorted(paths):
        h.update(rel.encode() + b'\0' + (ROOT / rel).read_bytes() + b'\0')
    return h.hexdigest()[:16]

def here(text):
    text = text.replace('\r\n', '\n')
    if text.endswith('\n'):
        text = text[:-1]
    for line in text.split('\n'):
        if line.startswith("'@"):
            raise SystemExit("cannot embed: a line starts with '@")
    if any(ord(c) > 127 for c in text):
        raise SystemExit('cannot embed: non-ASCII text (keep sources ASCII)')
    return "@'\n" + text + "\n'@"


def q(s):
    return "'" + s.replace("'", "''") + "'"


ENGINE = r'''
# ---------------- RADE, the Redacted Application Deployment Engine (generated; same engine in every round bundle) ----------------
function Get-Secret([string]$Id, [string]$Leaf) {
  @($Id, $Leaf, $env:USERNAME) | Where-Object { $_ -and $_.Length -ge 4 } | Sort-Object -Unique | Sort-Object Length -Descending
}
function ConvertTo-Masked([string]$Text) {
  foreach ($x in $script:secret) { $Text = $Text -replace [regex]::Escape($x), '<DODID>' }
  return $Text
}
function Get-ProfileLeaf { if ($env:USERPROFILE) { return (Split-Path -Leaf $env:USERPROFILE) }; return '' }
function Get-OneDrivePath {
  $leaf = Get-ProfileLeaf
  if (-not $leaf) { $leaf = 'no-profile-folder' }
  return (Join-Path (Join-Path $usersRoot $leaf) 'OneDrive - United States Air Force')
}
function Get-RadePath { return (Join-Path (Get-OneDrivePath) 'RADE') }
function Get-OldBasePath { return (Join-Path (Get-OneDrivePath) $appFolder) }
function Get-BasePath {
  # The real path (shown on screen, PFM 13 Nov: no placeholder). Reports and e-mails show <DODID> instead.
  # PFM 14 Nov 26: OneDrive\RADE\<app>. Until RADE has moved it (on Run), an old OneDrive\<app> folder is used.
  $new = Join-Path (Get-RadePath) $appFolder
  if (-not (Test-Path -LiteralPath $new -PathType Container) -and (Test-Path -LiteralPath (Get-OldBasePath) -PathType Container)) { return (Get-OldBasePath) }
  return $new
}
function Get-RadeMove {
  # The one-time move of OneDrive\<app> into OneDrive\RADE (PFM 14 Nov 26). Both there: nothing moves, the RADE copy is used.
  $old = Get-OldBasePath; $new = Join-Path (Get-RadePath) $appFolder
  $o = Test-Path -LiteralPath $old -PathType Container; $n = Test-Path -LiteralPath $new -PathType Container
  return @{ Needed = ($o -and -not $n); Both = ($o -and $n); From = $old; To = $new }
}
function Move-ToRade([scriptblock]$Say) {
  # One folder move inside OneDrive (every file keeps its place). On failure the round keeps the old folder and says why.
  $m = Get-RadeMove
  if ($m.Both) { & $Say ('Note: both ' + $appFolder + ' and RADE\' + $appFolder + ' are in your OneDrive. RADE uses RADE\' + $appFolder + '; move anything you still need from the old ' + $appFolder + ' folder by hand.') }
  if (-not $m.Needed) { return (Get-BasePath) }
  try {
    $rade = Get-RadePath
    if (-not (Test-Path -LiteralPath $rade -PathType Container)) { [void](New-Item -ItemType Directory -Path $rade -Force) }
    [System.IO.Directory]::Move($m.From, $m.To)
    & $Say ('Moved the folder ' + $appFolder + ' into RADE (RADE\' + $appFolder + '). Every file kept its place.')
  } catch {
    & $Say ('Folder move could not run: ' + (ConvertTo-Masked $_.Exception.Message) + ' This round uses the old ' + $appFolder + ' folder; the next round tries again.')
  }
  return (Get-BasePath)
}
function Resolve-Base {
  # No DODID question (PFM 13 Nov): the Windows profile folder name is the DODID.
  $leaf = Get-ProfileLeaf
  $script:secret = Get-Secret $leaf $leaf
  if ($leaf -notmatch '^[A-Za-z0-9._-]{4,}$') { throw 'PROFILE folder name not usable (Windows profile not found). Sign in to Windows with your own account, then run again.' }
  $base = Get-BasePath
  $oneDrive = Get-OneDrivePath
  if (-not (Test-Path -LiteralPath $oneDrive -PathType Container)) { throw ('FOLDER not found: ' + $oneDrive + '. OneDrive is not set up in this Windows profile.') }
  $script:dodid = $leaf
  return $base
}
function Format-Duration([double]$Seconds) {
  $s = [int][math]::Round($Seconds)
  return ('{0}m {1:00}s' -f [math]::Floor($s / 60), ($s % 60))
}
# What the window calls a step to a person: its manifest "title", else its name. The log, the report, the summary, the results
# files and every key keep the name.
function Get-StepTitle($Step) { if ($Step -and [string]$Step.Title) { return [string]$Step.Title }; return [string]$Step.Name }
function Test-WordOpen { return (@(Get-Process -Name WINWORD -ErrorAction SilentlyContinue).Count -gt 0) }
function Test-MailTo([string]$To) {
  $one = '[^@\s;,]+@[^@\s;,]+\.[^@\s;,]+'
  return ($To -match ('^\s*' + $one + '(\s*;\s*' + $one + ')*\s*;?\s*$'))
}
function Get-ConfigFile([string]$Base, [string]$Name) { return (Join-Path (Join-Path $Base 'Config') $Name) }
function Get-RadeConfigFile([string]$Name) { if ($script:configOver) { return (Join-Path $script:configOver $Name) }; return (Join-Path (Join-Path (Get-RadePath) 'Config') $Name) }   # the engine's own settings (R17)
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
  try { $o = [ordered]@{ about = 'RADE window place (a cache; delete it to open maximized again)'; x = $X; y = $Y; w = $W; h = $H; state = $State; dpi = $Dpi; closed = [ordered]@{ w = $ClientW; h = $ClientH; state = $CloseState } }
    Write-FileWhole (Get-RadeConfigFile 'rade-window.json') (($o | ConvertTo-Json -Depth 4) + "`r`n") } catch { $null = $_ }
}
function Get-MailTo([string]$Base) {
  # RADE\Config\rade-mail-to.txt: the address the results e-mail goes to (PFM 13 Nov; RADE R17). The window box saves it.
  # Until it exists, the app's old Config\@@PREFIX@@-mail-to.txt is read.
  foreach ($p in @((Get-RadeConfigFile 'rade-mail-to.txt'), (Get-ConfigFile $Base '@@PREFIX@@-mail-to.txt'))) {
    if (Test-Path -LiteralPath $p -PathType Leaf) { try { return ([string](Get-Content -LiteralPath $p -TotalCount 1)).Trim() } catch { return '' } }
  }
  return ''
}
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
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch { $null = $_ }   # TLS 1.2 (R19)
    $rq = [System.Net.WebRequest]::Create($goUrl)
    $rq.Timeout = 4000
    try { $rq.UserAgent = $webAgent } catch { $null = $_ }   # R21: as in Test-WebReach
    try { $rq.UseDefaultCredentials = $true } catch { $null = $_ }   # https: Windows sign-in for the proxy (a file URL in tests has none)
    if ($rq.Proxy) { $rq.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials }
    $rs = $rq.GetResponse()
    try { $text = (New-Object System.IO.StreamReader($rs.GetResponseStream())).ReadToEnd() } finally { $rs.Close() }
    $mine = [int]($round -replace '\D', '')
    $max = 0
    foreach ($m in [regex]::Matches($text, '(?m)^## [^\r\n]*Round R(\d{2})[^\r\n]*\(open')) { $n = [int]$m.Groups[1].Value; if ($n -gt $max) { $max = $n } }
    if ($max -gt $mine) { return ('R{0:00}' -f $max) }
  } catch { $null = $_ }
  return ''
}
function Get-LastRoundText($Hist) {
  $r = @($Hist | Where-Object { $_.Step -eq 'ROUND' })
  if (-not $r.Count) { return 'Last round on this computer: none recorded yet.' }
  $l = $r[-1]
  $word = @{ OK = 'passed'; CHECK = 'needed review'; STOPPED = 'stopped' }[[string]$l.Status]; if (-not $word) { $word = [string]$l.Status }
  return ('Last round on this computer: ' + $l.Round + ' ' + $word + ' on ' + $l.Finished + ' (took ' + (Format-Duration ([double]$l.Seconds)) + ').')
}
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
  @{ Re = 'denied|UnauthorizedAccess'; Text = 'Windows blocked a file. Check that the RADE folder is in your own OneDrive and not read-only, then run again.' },
  @{ Re = 'Outlook draft could not be created'; Text = 'Open Outlook (classic), then press Make e-mail draft. Or send by hand: the results folder is open and the summary is on the clipboard.' },
  @{ Re = 'FORMAT-FAIL'; Text = 'The renderer found a format problem. Send the results as they are; Claude fixes it.' },
  @{ Re = 'NO IMAGES'; Text = 'The seal images are not on this computer yet. Send the results; Claude checks how the seal e-mails were delivered.' },
  @{ Re = 'Clean-up could not'; Text = 'A file could not go to the Recycle Bin (it may be open). Close it; the next round tries again.' },
  @{ Re = 'e-mail address does not look right'; Text = 'Type one address like name@example.com (several: separate with ;), or leave the box empty.' }
)
function Get-WhatToDo([string]$Line) {
  foreach ($h in $helpRules) {
    if ($Line -match $h.Re -and -not $script:helped.ContainsKey($h.Re)) { $script:helped[$h.Re] = $true; return ('What to do: ' + $h.Text) }
  }
  return ''
}
function Test-OurFile([string]$Name) {
  # Files @@APP@@ made: @@PREFIX@@-* names, sample renders, and the support scripts that keep their names.
  foreach ($pat in $ownPatterns) { if ($Name -like $pat) { return $true } }   # the app's own file names (manifest application.own)
  return ($known -contains $Name)
}
function Get-CleanupPlan([string]$Base) {
  # Finished items only (PFM 13 Nov). A file not made by @@APP@@ is never touched; its folder stays.
  $res = @{ Files = @(); Dirs = @(); Kept = 0; Lines = @() }
  foreach ($c in $cleanup) {
    if ($c.Kind -eq 'dir') {
      $p = Join-Path $Base $c.Path
      if (-not (Test-Path -LiteralPath $p -PathType Container)) { continue }
      $all = @(Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue)
      $ours = @($all | Where-Object { Test-OurFile $_.Name })
      $other = $all.Count - $ours.Count
      $res.Files += @($ours | ForEach-Object { $_.FullName }); $res.Dirs += $p; $res.Kept += $other
      $res.Lines += ('  Recycle   ' + $c.Path + '\  (' + $ours.Count + ' files' + $(if ($other) { '; keeps ' + $other + ' file(s) not made by @@APP@@, and the folder' } else { '' }) + ')')
    } else {
      $dir = Join-Path $Base (Split-Path -Parent $c.Path)
      if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
      foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter (Split-Path -Leaf $c.Path) -File -Force -ErrorAction SilentlyContinue)) {
        if (Test-OurFile $f.Name) { $res.Files += $f.FullName; $res.Lines += ('  Recycle   ' + (Split-Path -Parent $c.Path) + '\' + $f.Name) }
      }
    }
  }
  return $res
}
function Move-ToRecycleBin([string]$Path, [switch]$Folder) {
  # Windows: to the Recycle Bin (restore from there). Elsewhere (tests only): plain delete.
  if ($env:OS -eq 'Windows_NT') {
    Add-Type -AssemblyName Microsoft.VisualBasic
    if ($Folder) { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($Path, 'OnlyErrorDialogs', 'SendToRecycleBin') }
    else { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($Path, 'OnlyErrorDialogs', 'SendToRecycleBin') }
  } else { Remove-Item -LiteralPath $Path -Force -Recurse:$Folder }
}
function Invoke-Cleanup([string]$Base, [scriptblock]$Say) {
  $plan = Get-CleanupPlan $Base
  $done = 0; $gone = 0; $failed = 0
  foreach ($f in @($plan.Files | Select-Object -Unique)) {   # a folder item and a file pattern can name the same file (R18: failed 1)
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }   # already gone: nothing to do
    try { Move-ToRecycleBin $f; $done++ } catch { $failed++; & $Say ('Clean-up could not recycle ' + (ConvertTo-Masked $f) + ': ' + (ConvertTo-Masked $_.Exception.Message)) }
  }
  foreach ($d in @($plan.Dirs | Sort-Object Length -Descending)) {
    # The folder goes only when nothing is left in it.
    if ((Test-Path -LiteralPath $d -PathType Container) -and @(Get-ChildItem -LiteralPath $d -Recurse -File -Force -ErrorAction SilentlyContinue).Count -eq 0) {
      try { Move-ToRecycleBin $d -Folder; $gone++ } catch { $failed++; & $Say ('Clean-up could not recycle ' + (ConvertTo-Masked $d) + ': ' + (ConvertTo-Masked $_.Exception.Message)) }
    }
  }
  $line = 'Clean-up: moved to the Recycle Bin: ' + $done + ' files, ' + $gone + ' folders; kept (not made by @@APP@@): ' + $plan.Kept + ' files; failed: ' + $failed + '.'
  if ($failed) { $script:roundBad = $true }
  & $Say $line
  return $line
}
function Get-FolderInventory([string]$Base) {
  # What is left, for Claude to update the next round's steps: task folders by name, counts only (no file names).
  $parts = @(); $odd = 0
  foreach ($d in @(Get-ChildItem -LiteralPath $Base -Directory -Force -ErrorAction SilentlyContinue | Sort-Object Name)) {
    if ($d.Name -notmatch '^(T\d\d|Rounds|Config)$') { $odd++; continue }
    $all = @(Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Force -ErrorAction SilentlyContinue)
    $other = @($all | Where-Object { -not (Test-OurFile $_.Name) }).Count
    $parts += ($d.Name + ' ' + $all.Count + $(if ($other) { ' (' + $other + ' other)' } else { '' }))
  }
  return ('Files left by folder: ' + ($parts -join ', ') + $(if ($odd) { '; other folders: ' + $odd } else { '' }) + '.')
}
function Write-BundleFile([string]$Base, [scriptblock]$Say) {
  $utf8Bom = New-Object System.Text.UTF8Encoding $true
  & $Say 'Preparing files'
  foreach ($f in $files) {
    $dir = Join-Path $Base $f.Dir
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    $path = Join-Path $dir $f.Name
    if ($f.Kind -eq 'text') { [System.IO.File]::WriteAllText($path, (($f.Data -replace "`r?`n", "`r`n") + "`r`n"), $utf8Bom) }
    else { [System.IO.File]::WriteAllBytes($path, [System.Convert]::FromBase64String(($f.Data -replace '\s', ''))) }
    & $Say ('  Saved   ' + $f.Dir + '\' + $f.Name + '  (SHA-256 ' + $f.Sha + ')')
  }
  & $Say ('  ' + $files.Count + ' files saved.')
}
function Save-RoundDownload([string]$Base, [scriptblock]$Say) {
  # Data files only (briefs, public color documents), never code (PFM 3A). WebClient uses the Windows proxy and sign-in.
  # A repo file must match its SHA-256; a failed download leaves the link on the bookmark page as the fallback.
  $ok = 0; $bad = 0
  if (-not $fetch.Count) { return '' }
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch { $null = $_ }   # TLS 1.2 on PS 5.1
  foreach ($f in $fetch) {
    $dir = Join-Path $Base $f.Dir
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    $path = Join-Path $dir $f.Name
    $wc = New-Object System.Net.WebClient
    try {
      $wc.UseDefaultCredentials = $true
      try { $wc.Headers['User-Agent'] = $webAgent } catch { $null = $_ }   # R21: as in Test-WebReach
      if ($wc.Proxy) { $wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials }
      $wc.DownloadFile($f.Url, $path)
      if ($f.Sha) {
        $sha = [System.Security.Cryptography.SHA256]::Create(); $fs = [System.IO.File]::OpenRead($path)
        try { $got = ([System.BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-', '').ToLowerInvariant() } finally { $fs.Dispose(); $sha.Dispose() }   # no Get-FileHash: it is a script function of a module and was not found on Windows PowerShell 5.1 in the Windows job
        if ($got -ne $f.Sha) { Remove-Item -LiteralPath $path -Force; throw 'the file changed since this round was built' }
      }
      $ok++; & $Say ('  Downloaded   ' + $f.Dir + '\' + $f.Name + '  (' + ('{0:N0}' -f (Get-Item -LiteralPath $path).Length) + ' bytes)')
    } catch {
      $bad++
      if (Test-Path -LiteralPath $path -PathType Leaf) { try { Remove-Item -LiteralPath $path -Force } catch { $null = $_ } }   # no partial file left behind
      & $Say ('  Download failed   ' + $f.Dir + '\' + $f.Name + ': ' + (ConvertTo-Masked $_.Exception.Message) + $(if (Test-Deploy) { '' } else { ' (save it from the repository instead)' }))
    } finally { $wc.Dispose() }
  }
  $line = 'Downloads: ' + $ok + ' saved, ' + $bad + ' failed.'
  if ($bad) { $script:roundBad = $true }
  & $Say $line
  return $line
}
function Get-StepEnv([string]$Base, $Step) {
  # Step contract (docs/engine.md "Step contract"): what RADE tells a step, as environment variables of the child process.
  # Variables, not parameters: a script that does not know them still runs.
  $inst = ''; $last = ''
  if (Test-Deploy) {
    $e = (Read-Installed (Get-InstalledKey $script:app))
    if ($e) {
      if ($e.installed) { $inst = [string]$e.installed.version }
      $s = $e.steps[[string]$Step.Name]; if ($s -and [string]$s.version -eq [string]$script:app.Version) { $last = [string]$s.state }
    }
  }
  return [ordered]@{ RADE_CONTRACT = '1'; RADE_MODE = [string]$script:app.Mode; RADE_APP = [string]$script:app.Name; RADE_APP_VERSION = [string]$script:app.Version
    RADE_INSTALLED_VERSION = $inst; RADE_STEP_LAST = $last; RADE_SITE = $(if (Test-SiteUrl (Get-SiteUrl $Base)) { [string](Get-SiteUrl $Base) } else { '' }) }
}
function ConvertTo-MadeName([string]$Name, [string]$Site) {
  # A made item's name goes into the record: no address, no ID, one line, 200 characters at most.
  # Out: any https address, the saved site address in any form (with or without https://, or only its /sites/ path),
  # and any other host/sites/ path.
  $t = (ConvertTo-Masked $Name) -replace 'https?://\S+', '<SITE>'
  if ($Site -match '^https://([^/]+)(/sites/[^/]+)') { $t = $t -replace [regex]::Escape($Matches[1] + $Matches[2]), '<SITE>' -replace [regex]::Escape($Matches[2]), '<SITE>' }
  $t = $t -replace '[A-Za-z0-9.-]+\.[A-Za-z]{2,}/sites/\S*', '<SITE>' -replace '\s+', ' '
  $t = $t.Trim(); if ($t.Length -gt 200) { $t = $t.Substring(0, 200) }
  return $t
}
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
    & $Say ('    Address: ' + $url)
    if ($file -and (Copy-TextToClipboard $file)) { & $Say '    The full file path is on the clipboard.' }
    if ($env:OS -eq 'Windows_NT') { try { Start-Process -FilePath $url } catch { $null = $_ } }
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
      elseif ($q.Kind -eq 'text') { $v = ConvertTo-UserText ([string]$script:guideAnswers[$k]); if ($v.Length -gt 120) { $v = $v.Substring(0, 120) }; if (-not $v) { $v = '(no text)' } }
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
# ---- Installed versions (the Administrator, 14 Nov 26, deploy v1): RADE\Config\installed keeps, one file per app, the
# version a deploy last installed and the last deploy run. It holds no user name, path, site or DODID. A deploy run sends
# nothing: no e-mail draft, no saved address; its report stays in Rounds\<round> on this computer.
function Get-InstalledKey($A) {
  # An app that keeps an install record on the site (manifest "marker") has one record for each site: the key ends in
  # "@" and a short hash of the site address (never the address). So versions, step states and the made list of one
  # site never count on another (reviews, 14 Nov 26).
  $k = $appFolder + '/' + [string]$A.Name
  if ($A.Marker) { $h = Get-SiteMark (Get-SiteUrl (Get-BasePath)); if ($h) { $k += '@' + $h } }
  return $k
}
function ConvertTo-InstalledRun($V) {
  if ($null -eq $V) { return $null }
  $at = $V.at; if ($at -is [datetime]) { $at = $at.ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture) }   # PowerShell 7 reads it as a date
  $o = [ordered]@{ version = [string]$V.version; build = [string]$V.build; round = [string]$V.round; at = [string]$at }
  if ($null -ne $V.state) { $o.state = [string]$V.state }
  return $o
}
# Shared files (docs/engine.md "Shared files"; the Administrator, 2026-11-15). Many apps, each with its own engine version,
# use RADE\Config. So: one record file for each app (RADE\Config\installed\<12 hex of the record key>.json, schema
# rade-installed/2), and an engine reads and writes only its own app's file (S1). A record with a higher schema number is
# never written, and that app is not deployed (S2). Every write goes to a temporary file first (S4). Only a file with the
# exact name is read, so a conflict copy that OneDrive makes is ignored (S5).
$installedSchema = 2
function Write-FileWhole([string]$Path, [string]$Text) {
  # The file is whole or unchanged: the text goes to a temporary file in the same folder, which then takes the place of
  # the final file in one step. A stop in the middle leaves the old file as it was.
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
  $tmp = $Path + '.tmp' + $PID
  try {
    [System.IO.File]::WriteAllText($tmp, $Text, (New-Object System.Text.UTF8Encoding $false))
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
      if ((Get-Item -LiteralPath $Path -Force).IsReadOnly) { throw 'the file is read-only' }
      [System.IO.File]::Replace($tmp, $Path, [NullString]::Value)   # $null would go in as an empty string, which Replace refuses
    } else { [System.IO.File]::Move($tmp, $Path) }
  } finally { if (Test-Path -LiteralPath $tmp -PathType Leaf) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue } }
}
function Get-InstalledFile([string]$Key) { return (Join-Path (Get-RadeConfigFile 'installed') ((Get-ShortHash $Key) + '.json')) }
function Read-InstalledRaw([string]$Key) {
  # State: none (no file), ok, damaged (not JSON, or no record of this schema), newer (a higher schema number: S2),
  # foreign (a whole record with another app's key: two keys gave one file name) or unreadable (the file is there but
  # cannot be read now, for example while another program holds it). Only none, ok and damaged may be written (S1).
  $p = Get-InstalledFile $Key
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return @{ State = 'none'; Path = $p } }
  $text = $null
  try { $text = [System.IO.File]::ReadAllText($p) } catch { return @{ State = 'unreadable'; Path = $p } }
  try {
    $j = $text | ConvertFrom-Json
    if ([string]$j.schema -notmatch '^rade-installed/(\d{1,6})$') { return @{ State = 'damaged'; Path = $p } }
    if ([int]$Matches[1] -gt $installedSchema) { return @{ State = 'newer'; Path = $p } }
    if ([int]$Matches[1] -lt $installedSchema) { return @{ State = 'damaged'; Path = $p } }
    if ([string]$j.key -cne $Key) { return @{ State = $(if ([string]$j.key) { 'foreign' } else { 'damaged' }); Path = $p } }
    return @{ State = 'ok'; Path = $p; Json = $j }
  } catch { return @{ State = 'damaged'; Path = $p } }
}
function Test-InstalledNewer($A) { return ((Read-InstalledRaw (Get-InstalledKey $A)).State -eq 'newer') }
$newerRadeText = 'a newer RADE installed this application: get the newest script from the RADE page'
function Get-InstalledBlock($A) {
  # '' or why this app's record must not be written, so the app is not deployed (S1, S2).
  switch ((Read-InstalledRaw (Get-InstalledKey $A)).State) {
    'newer' { return $newerRadeText }
    'foreign' { return 'the install record file of this application holds the record of another application (RADE\Config\installed). RADE did not change it: ask for help before you install' }
    'unreadable' { return 'the install record of this application could not be read (another program may be using the file). Wait a minute, then run again' }
  }
  return ''
}
function Read-Installed([string]$Key) {
  # This app's record, or $null (no file, a damaged file, or a record from a newer RADE).
  $r = Read-InstalledRaw $Key
  if ($r.State -ne 'ok') { return $null }
  try {
    $st = [ordered]@{}
    if ($r.Json.steps) { foreach ($s in @($r.Json.steps.PSObject.Properties)) {
      $at = $s.Value.at; if ($at -is [datetime]) { $at = $at.ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture) }
      $made = @(); foreach ($m in @($s.Value.made)) { if ($null -ne $m) { $made += [ordered]@{ kind = [string]$m.kind; name = [string]$m.name } } }
      $st[$s.Name] = [ordered]@{ state = [string]$s.Value.state; version = [string]$s.Value.version; at = [string]$at; made = $made }
    } }
    return [ordered]@{ installed = (ConvertTo-InstalledRun $r.Json.installed); lastRun = (ConvertTo-InstalledRun $r.Json.lastRun); steps = $st }
  } catch { return $null }   # a damaged file reads as nothing installed
}
function Get-InstalledText($A) {
  # One short text for the Choose card and the log; '' for an app that is not a deploy.
  if ([string]$A.Mode -ne 'deploy') { return '' }
  if (Test-InstalledNewer $A) { return ('version ' + $A.Version + ' (' + $newerRadeText + ')') }
  $e = (Read-Installed (Get-InstalledKey $A))
  if ($e -and $e.installed) {
    if ($e.installed.version -eq [string]$A.Version) { return ('version ' + $A.Version + ' is installed') }
    return ('version ' + $A.Version + ' (installed now: ' + $e.installed.version + ')')
  }
  return ('version ' + $A.Version + ' (not installed yet)')
}
function Save-Installed([string]$State, [bool]$Whole, $StepRecs) {
  # Every deploy run is the app's lastRun. "installed" changes only when every step of the app ran and PASSED (none off,
  # none skipped). Clean-up is not a step: it only recycles old files, so it may be off.
  # $StepRecs: name -> @{ state; made } for the steps this run reached; a step it did not reach keeps its older record.
  # A step's "made" list adds up over runs (the undo list): an item stays until an undo removes it.
  # Returns '' or the reason the record could not be saved (the caller says it: the record is the upgrade path).
  try {
    $key = Get-InstalledKey $script:app
    $raw = Read-InstalledRaw $key
    $blk = Get-InstalledBlock $script:app; if ($blk) { return $blk }   # S1, S2: never write a record of a newer RADE or of another app, or one that cannot be read
    if ($raw.State -eq 'damaged') {
      # Keep what was there before it is replaced; an older .damaged copy is kept too.
      $keep = $raw.Path + '.damaged'; if (Test-Path -LiteralPath $keep) { $keep += '-' + (Get-Date).ToString('yyyyMMdd-HHmmss', [System.Globalization.CultureInfo]::InvariantCulture) }
      Copy-Item -LiteralPath $raw.Path -Destination $keep -Force
    }
    $old = Read-Installed $key
    $run = [ordered]@{ version = [string]$script:app.Version; build = [string]$buildId; round = [string]$round; at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture) }
    $inst = $null; if ($old) { $inst = $old.installed }
    if ($State -eq 'PASSED' -and $Whole) { $inst = [ordered]@{ version = $run.version; build = $run.build; round = $run.round; at = $run.at } }
    $run.state = $State
    $st = [ordered]@{}; if ($old -and $old.steps) { $st = $old.steps }
    if ($StepRecs) { foreach ($n in @($StepRecs.Keys)) {
      $made = @(); $seen = @{}
      $om = @(); if ($st.Contains($n)) { $om = @($st[$n].made) }
      foreach ($m in ($om + @($StepRecs[$n].made))) { if ($null -eq $m) { continue }; $id = [string]$m.kind + '|' + [string]$m.name; if (-not $seen[$id]) { $seen[$id] = $true; $made += [ordered]@{ kind = [string]$m.kind; name = [string]$m.name } } }
      $st[$n] = [ordered]@{ state = [string]$StepRecs[$n].state; version = $run.version; at = $run.at; made = $made }
    } }
    $doc = [ordered]@{
      schema = 'rade-installed/' + $installedSchema
      about = 'What RADE installed for one app (key: folder/name; a key that ends in @ and letters is one site, as a short hash). "installed" is the last deploy in which every step ran and PASSED; "lastRun" is the last deploy run and its state; "steps" holds each step''s last state and what it made. No user, path or site address is kept here. Only the RADE that installs this app writes this file.'
      key = $key
      installed = $inst
      lastRun = $run
      steps = $st
    }
    Write-FileWhole $raw.Path ($doc | ConvertTo-Json -Depth 9)
    return ''
  } catch { return (ConvertTo-Masked $_.Exception.Message) }
}
function Test-SharedFile([string]$Dir) {
  # Test rounds only (it goes away with the test branch): runs the record functions on a scratch folder, so a round on a
  # work computer proves them on Windows PowerShell 5.1. Returns one line for each test: "PASS ..." or "FAIL ...".
  $out = @(); $keepApp = $script:app
  try {
    $script:configOver = $Dir
    $script:app = @{ Name = 'Self test'; Version = '0.0.1'; Mode = 'test'; Marker = $null }
    $key = Get-InstalledKey $script:app; $p = Get-InstalledFile $key
    $rec = @{ 'step one' = @{ state = 'PASSED'; made = @(@{ kind = 'file'; name = 'a' }) } }
    $w = Save-Installed 'PASSED' $true $rec; $e = Read-Installed $key
    $out += $(if (-not $w -and $e -and $e.installed -and $e.installed.version -eq '0.0.1' -and @($e.steps['step one'].made).Count -eq 1 -and [string]$e.steps['step one'].made[0].name -eq 'a') { 'PASS' } else { 'FAIL' }) + ' shared files: a record is written and read back'
    $w = Save-Installed 'NEEDS REVIEW' $false @{ 'step two' = @{ state = 'NEEDS REVIEW'; made = @() } }; $e = Read-Installed $key
    $left = @(Get-ChildItem -LiteralPath (Split-Path -Parent $p) -Force | Where-Object { $_.Name -ne (Split-Path -Leaf $p) })
    $out += $(if (-not $w -and $e -and $e.lastRun.state -eq 'NEEDS REVIEW' -and $e.installed.version -eq '0.0.1' -and $e.steps.Count -eq 2 -and -not $left.Count) { 'PASS' } else { 'FAIL' }) + ' shared files: a second write replaces the file and leaves no temporary file'
    $newer = '{ "schema": "rade-installed/' + ($installedSchema + 1) + '", "key": "' + $key + '", "later": true }'
    [System.IO.File]::WriteAllText($p, $newer)
    $w = Save-Installed 'PASSED' $true $rec
    $out += $(if ($w -eq $newerRadeText -and (Test-InstalledNewer $script:app) -and $null -eq (Read-Installed $key) -and [System.IO.File]::ReadAllText($p) -eq $newer) { 'PASS' } else { 'FAIL' }) + ' shared files: a record of a newer RADE is not read and not written'
    [System.IO.File]::WriteAllText($p, '{ "schema": "rade-installed/2", "key": "')
    $e0 = Read-Installed $key; $w = Save-Installed 'PASSED' $true $rec; $e = Read-Installed $key
    $out += $(if ($null -eq $e0 -and -not $w -and $e -and $e.installed -and (Test-Path -LiteralPath ($p + '.damaged') -PathType Leaf)) { 'PASS' } else { 'FAIL' }) + ' shared files: a cut record is kept as .damaged and replaced'
  } catch { $out += 'FAIL shared files: the self-test stopped (' + (ConvertTo-Masked $_.Exception.Message) + ')' }
  finally { $script:configOver = $null; $script:app = $keepApp; try { Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue } catch { $null = $_ } }
  return $out
}
function Get-StepPrior {
  # Deploy only: step name -> state, for the steps the record holds at the version this bundle installs.
  $res = @{}
  if (-not (Test-Deploy)) { return $res }
  $e = (Read-Installed (Get-InstalledKey $script:app))
  if ($e -and $e.steps) { foreach ($n in @($e.steps.Keys)) { if ([string]$e.steps[$n].version -eq [string]$script:app.Version) { $res[[string]$n] = [string]$e.steps[$n].state } } }
  return $res
}
function Get-StepDefault([int]$K) {
  # Safe second run (deploy v1 item 3): a step that PASSED at this version starts off, so a second run does only what is
  # left. When every step of the app has PASSED, the run is a repair: every step starts on again.
  # Optional = the manifest says "default": false. Every other step is needed: in a deploy it is on until it has PASSED
  # at this version, whatever a files-changed default says (that default is for test rounds).
  if (-not (Test-Deploy) -or [bool]$steps[$K].Optional) { return [bool]$steps[$K].Default }
  $prior = Get-StepPrior
  # Only needed steps count: an optional step that never ran must not block the repair (review).
  $all = $true; foreach ($j in $script:appSteps) { if (-not [bool]$steps[$j].Optional -and $prior[[string]$steps[$j].Name] -ne 'PASSED') { $all = $false } }
  if ($all) { return $true }
  return ($prior[[string]$steps[$K].Name] -ne 'PASSED')
}
# The RADE page (R28: the newer-version notice points here, not to the app page; the Administrator, 2026-11-17).
$radeUrl = 'https://rhope-ops.github.io/RADE'
function Get-NewerVersion {
  # Reads rade-release.json in the app repository (data, not code): { "apps": { "<app name>": "<version>" } }.
  # Returns that version when it is newer than the one this bundle installs, else ''. Short timeout; any failure is silent.
  # R28: in a test round too (the Administrator, 2026-11-17): the notice shows for every application that names a version.
  if (-not [string]$script:app.Version) { return '' }   # no version: nothing to compare, no request
  try {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch { $null = $_ }
    $rq = [System.Net.WebRequest]::Create($releaseUrl)
    $rq.Timeout = 4000
    try { $rq.UserAgent = $webAgent } catch { $null = $_ }
    try { $rq.UseDefaultCredentials = $true } catch { $null = $_ }
    if ($rq.Proxy) { $rq.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials }
    $rs = $rq.GetResponse()
    try { $text = (New-Object System.IO.StreamReader($rs.GetResponseStream())).ReadToEnd() } finally { $rs.Close() }
    $v = [string](($text | ConvertFrom-Json).apps.PSObject.Properties | Where-Object { $_.Name -eq [string]$script:app.Name } | ForEach-Object { $_.Value } | Select-Object -First 1)
    if ($v -match '^\d+\.\d+(\.\d+)?$' -and ([version]$v) -gt ([version][string]$script:app.Version)) { return $v }
  } catch { $null = $_ }
  return ''
}
function Get-NewerVersionText {
  $v = Get-NewerVersion
  if ($v) { return ('A newer version, ' + $v + ', of ' + $script:app.Name + ' is on the RADE page (' + $radeUrl + '). Use that one instead.') }
  return ''
}
function Get-StartPath {
  # R28: the app's start script (manifest app.start), inside its local install folder; '' when the app has none, the path is
  # not inside the folder, or the file is not there. Nothing is downloaded.
  $st = [string]$script:app.Start
  if (-not $st) { return '' }
  try { $base = [System.IO.Path]::GetFullPath((Get-BasePath)).TrimEnd('\', '/')
    $full = [System.IO.Path]::GetFullPath((Join-Path $base ($st -replace '/', [string][System.IO.Path]::DirectorySeparatorChar)))
    if (-not $full.StartsWith($base + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { return '' }
    if (Test-Path -LiteralPath $full -PathType Leaf) { return $full }
  } catch { $null = $_ }
  return ''
}
function Get-PowerShellExe {
  if ($env:SystemRoot) { $x = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'; if (Test-Path -LiteralPath $x -PathType Leaf) { return $x } }
  return 'powershell.exe'
}
# The installed runner (R28, the Administrator, 2026-11-17): RADE had none, so the desktop shortcut had nothing to open. The smallest
# one: after a deploy has passed, a copy of the pasted text is saved as OneDrive\RADE\rade-runner.ps1 (the newest deploy's paste
# replaces it; the file is a whole bundle, so it carries its own engine and its own applications). The shortcut runs it.
$script:selfText = ''
try { if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath -PathType Leaf)) { $script:selfText = [System.IO.File]::ReadAllText($PSCommandPath) } } catch { $null = $_ }
if (-not $script:selfText) { try { if ($psISE -and $psISE.CurrentFile) { $script:selfText = [string]$psISE.CurrentFile.Editor.Text } } catch { $null = $_ } }
if (-not $script:selfText) { try { $script:selfText = [string]$MyInvocation.MyCommand.ScriptBlock } catch { $null = $_ } }
function Save-RunnerCopy {
  # Returns $true when the runner is saved. Only the text of this bundle is saved (its build id must be in it). Never an error.
  # Only a newer RADE replaces a saved copy (the Administrator, 2026-11-17): a copy with a higher or equal engine release stays.
  try { if (-not $script:selfText -or -not $script:selfText.Contains("`$buildId = '" + $buildId + "'")) { return $false }
    $rp = Join-Path (Get-RadePath) 'rade-runner.ps1'
    if (Test-Path -LiteralPath $rp -PathType Leaf) {
      $m = [regex]::Match([IO.File]::ReadAllText($rp), '(?m)^\$engineRelease = (\d+)')
      if ($m.Success -and [int]$m.Groups[1].Value -ge [int]$engineRelease) { return $false } }
    Write-FileWhole $rp $script:selfText; return $true } catch { return $false }
}
function Add-DesktopIcon {
  # One shortcut named RADE in the user's own Desktop folder (it follows OneDrive), made once, only when missing, with no
  # administrator rights (WScript.Shell). Returns the plain line the Done card shows, or '' when there is nothing to say.
  try { $runner = Join-Path (Get-RadePath) 'rade-runner.ps1'
    if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) { return '' }
    $desk = [Environment]::GetFolderPath('Desktop')
    if (-not $desk -or -not (Test-Path -LiteralPath $desk -PathType Container)) { return 'RADE could not find your Desktop folder, so it made no desktop shortcut. Open RADE from the RADE page instead.' }
    $lnk = Join-Path $desk 'RADE.lnk'
    if (Test-Path -LiteralPath $lnk) { return '' }
    $sh = New-Object -ComObject WScript.Shell; $sc = $sh.CreateShortcut($lnk)
    $sc.TargetPath = (Get-PowerShellExe); $sc.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Minimized -File "' + $runner + '"'
    $sc.WorkingDirectory = (Get-RadePath); $sc.Description = 'Open RADE'; $sc.WindowStyle = 7; $sc.Save()
    return 'A shortcut named RADE is now on your desktop. It opens RADE.'
  } catch { return 'RADE could not make a desktop shortcut. Open RADE from the RADE page instead.' }
}
function Get-MadeLine {
  # Deploy: what the installs of the chosen app made, from the record (deploy v1 item 4: the list a user needs to remove it by hand).
  $out = @()
  $e = (Read-Installed (Get-InstalledKey $script:app))
  if ($e -and $e.steps) { foreach ($n in @($e.steps.Keys)) { foreach ($m in @($e.steps[$n].made)) { if ($null -ne $m) { $out += ('  ' + [string]$m.kind + ': ' + [string]$m.name + '  (' + [string]$n + ')') } } } }
  if ($out.Count) { return (@('Made by this app''s installs on this computer and site (to remove the app, remove these by hand):') + $out) }
  return @()
}
function Get-HelpLine { return ('For help, ask in the Teams channel ' + $helpChannel + '.') }
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

# ---- Checks (PFM 14 Nov 26: RADE checks, from its window, that this computer can install the chosen app and
# that the PFM has the rights to see it done end to end). Read-only except: one test file in the OneDrive folder and one
# temporary script in the Windows temp folder, each deleted at once, and the site address in Config when the PFM enters it.
# Kind: auto = runs on its own when the Check screen opens; signin = needs a CAC sign-in (button); guide = the PFM looks
# in another program and answers (button). Advisory: a problem is a WARNING, never a FAILED.
$checkDefs = @(
  @{ Id = 'nipr'; Group = 'Local'; Name = 'This computer is on NIPR (area52 domain)'; Kind = 'auto' },
  @{ Id = 'ps'; Group = 'Local'; Name = 'PowerShell is version 5.1 or newer'; Kind = 'auto' },
  @{ Id = 'lang'; Group = 'Local'; Name = 'PowerShell is not restricted'; Kind = 'auto' },
  @{ Id = 'onedrive'; Group = 'Local'; Name = 'Your OneDrive folder is set up'; Kind = 'auto' },
  @{ Id = 'disk'; Group = 'Local'; Name = 'There is enough free disk space'; Kind = 'auto' },
  @{ Id = 'write'; Group = 'Local'; Name = 'Files can be saved in OneDrive'; Kind = 'auto' },
  @{ Id = 'child'; Group = 'Local'; Name = 'RADE can run its scripts'; Kind = 'auto' },
  @{ Id = 'outlook'; Group = 'Local'; Name = 'Outlook can make the results e-mail'; Kind = 'auto'; Advisory = $true },
  @{ Id = 'word'; Group = 'Local'; Name = 'Word is installed'; Kind = 'auto' },
  @{ Id = 'pnp'; Group = 'Local'; Name = 'The SharePoint tool (PnP.PowerShell 1.12.0) is installed'; Short = 'The SharePoint tool (PnP 1.12.0) is installed'; Kind = 'auto' },
  @{ Id = 'net-bookmark'; Group = 'Network'; Name = 'The repository can be reached'; Kind = 'auto'; Advisory = $true },
  @{ Id = 'net-site'; Group = 'Network'; Name = 'Your SharePoint site can be reached'; Kind = 'auto' },
  @{ Id = 'net-flow'; Group = 'Network'; Name = 'Power Automate can be reached'; Kind = 'auto' },
  @{ Id = 'site-rights'; Group = 'Access'; Name = 'You can change the site (sign in with your CAC)'; Short = 'You can change the site (CAC sign-in)'; Kind = 'signin' },
  @{ Id = 'flow-guide'; Group = 'Access'; Name = 'You can import flows in Power Automate (you look)'; Short = 'You can import flows (you look)'; Kind = 'guide' }
)
# Short: the name in the window's narrow check column (the Administrator, 2026-11-14); the log and the e-mail keep Name.
$dot = ' ' + [char]0x00B7 + ' '   # a middle dot between facts, made at run time so the bundle stays ASCII
# ---- Environment guard (the Administrator, 15 Nov 26): RADE runs on NIPR computers only. It reads this computer's own
# full name (host name and its domain: two local values; nothing is sent and no host is contacted) and goes on only when
# that name contains the NIPR domain label below. It cannot prove NIPR; it stops an honest mistake. The name is never shown or saved.
$niprLabel = '.area52.'
function Get-OwnFqdn { try { $g = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties(); return [string]$g.HostName + '.' + [string]$g.DomainName } catch { return '' } }
function Test-NiprDevice { return ([string](Get-OwnFqdn)).Trim().ToLowerInvariant().Contains($niprLabel) }
function Get-CheckDef([string]$Id) { foreach ($d in $checkDefs) { if ($d.Id -eq $Id) { return $d } }; return $null }
function Get-SiteUrl([string]$Base) {
  # Config\@@PREFIX@@-site.txt: the same file T16 site setup keeps (one place for the site address; never in the repo).
  $p = Get-ConfigFile $Base '@@PREFIX@@-site.txt'
  if (Test-Path -LiteralPath $p -PathType Leaf) { try { return ([string](Get-Content -LiteralPath $p -TotalCount 1)).Trim() } catch { return '' } }
  return ''
}
$sitePrefix = 'https://usaf.dps.mil/sites/'   # the DAF SharePoint address every site starts with; the box starts with it
# Guardrail (the Administrator, 14 Nov 26): only a site on the DAF SharePoint host is accepted, so RADE never signs in to
# or writes to another host.
function Test-SiteUrl([string]$Url) { return ($Url -match ('^' + [regex]::Escape($sitePrefix) + '[^/\\\s"]+/?$')) }
function Save-SiteUrl([string]$Base, [string]$Url) {
  $p = Get-ConfigFile $Base '@@PREFIX@@-site.txt'
  $dir = Split-Path -Parent $p
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
  [System.IO.File]::WriteAllText($p, ($Url.Trim() + "`r`n"), (New-Object System.Text.UTF8Encoding $true))
}
function Get-FlowPortal([string]$Base) {
  # The address the guide steps open (editable there, remembered in Config); the first app step that names one wins.
  foreach ($k in $script:appSteps) {
    $s = $steps[$k]
    if ($s.Url) {
      if ($s.UrlConfig) { $p = Get-ConfigFile $Base $s.UrlConfig; if (Test-Path -LiteralPath $p -PathType Leaf) { try { $v = ([string](Get-Content -LiteralPath $p -TotalCount 1)).Trim(); if ($v -match '^https://') { return @{ Url = $v; Config = $p } } } catch { $null = $_ } } }
      return @{ Url = $s.Url; Config = $(if ($s.UrlConfig) { Get-ConfigFile $Base $s.UrlConfig } else { '' }) }
    }
  }
  return @{ Url = ''; Config = '' }
}
function Test-WebReach([string]$Url) {
  # TLS 1.2 first (found in R19, fixed for R20: Windows PowerShell 5.1 starts with TLS 1.0, which GitHub closes: [ReceiveFailure]; Edge uses 1.2).
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 } catch { $null = $_ }
  # Does the host answer? Any HTTP answer counts (401 or 403 = it answers but wants a sign-in). Windows sign-in for the proxy.
  # Returns no address and no message text (they can hold the site or tenant name): only the code or the error kind.
  try {
    $rq = [System.Net.WebRequest]::Create($Url)
    $rq.Timeout = 6000
    # R20: [ReceiveFailure] stayed with TLS 1.2 set. A request with no User-Agent can be closed by a filtering proxy (agent
    # finding, Confidence low); send the one Edge's family sends.
    try { $rq.UserAgent = $webAgent } catch { $null = $_ }
    try { $rq.UseDefaultCredentials = $true } catch { $null = $_ }
    try { $rq.AllowAutoRedirect = $false } catch { $null = $_ }
    try { if ($rq.Proxy) { $rq.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials } } catch { $null = $_ }
    $rs = $rq.GetResponse()
    $code = 0; try { $code = [int]$rs.StatusCode } catch { $null = $_ }
    $rs.Close()
    return @{ Ok = $true; Code = $code }
  } catch {
    $e = $_.Exception
    while ($e -and -not ($e -is [System.Net.WebException]) -and $e.InnerException) { $e = $e.InnerException }
    if ($e -is [System.Net.WebException] -and $e.Response) {
      $code = 0; try { $code = [int]$e.Response.StatusCode } catch { $null = $_ }
      if ($code -eq 407) { return @{ Ok = $false; Why = 'Network sign-in required, code [407]' } }
      return @{ Ok = $true; Code = $code }
    }
    if ($e -is [System.Net.WebException]) {
      $why = @{ Timeout = 'no reply in time'; NameResolutionFailure = 'address not found'; ConnectFailure = 'could not connect'; ProxyNameResolutionFailure = 'network proxy not found'; TrustFailure = 'the security certificate was not trusted'; SecureChannelFailure = 'secure connection failed' }[[string]$e.Status]
      if (-not $why) { $why = 'network error' }
      $why += ' [' + [string]$e.Status + ']'
      # R21 diagnostics: the inner error kinds, a socket error code and the TLS setting (names and numbers only, no address).
      $kinds = @(); $x = $e.InnerException
      while ($x) { $k = $x.GetType().Name; if ($x -is [System.Net.Sockets.SocketException]) { $k += ' ' + [int]$x.ErrorCode } elseif ($x.HResult) { $k += ' 0x' + ('{0:X8}' -f $x.HResult) }; $kinds += $k; $x = $x.InnerException }
      $tls = ''; try { $tls = [string][Net.ServicePointManager]::SecurityProtocol } catch { $null = $_ }
      if ($kinds.Count -or $tls) { $why += ' (' + (@($kinds) + @('TLS ' + $tls) -join '; ') + ')' }
      return @{ Ok = $false; Why = $why }
    }
    return @{ Ok = $false; Why = 'network error [' + $e.GetType().Name + ']' }
  }
}
function Invoke-ChildScript([string]$Text, [string]$ArgText, [int]$Seconds, [scriptblock]$Tick) {
  # Runs a short embedded check script as a child powershell.exe, the way steps run. The script is written to the Windows
  # temp folder and deleted at once. Returns the exit code and the output lines.
  $exe = 'powershell.exe'
  if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { $exe = 'pwsh' }
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('@@PREFIX@@-check-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.ps1')
  $res = @{ Exit = -1; Lines = @(); Why = '' }
  try {
    [System.IO.File]::WriteAllText($tmp, $Text, (New-Object System.Text.UTF8Encoding $true))
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $tmp + '"' + $(if ($ArgText) { ' ' + $ArgText } else { '' })
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $script:child = $p   # Exit stops a check too (review R17)
    $outTask = $p.StandardOutput.ReadToEndAsync(); $errTask = $p.StandardError.ReadToEndAsync()
    $deadline = (Get-Date).AddSeconds($Seconds)
    while (-not $p.WaitForExit(30)) {
      if ($Tick) { & $Tick }
      if ((Get-Date) -gt $deadline) { try { $p.Kill() } catch { $null = $_ }; $res.Why = 'it ran longer than ' + $Seconds + ' seconds'; break }
    }
    $p.WaitForExit()
    $res.Exit = $p.ExitCode
    $res.Lines = @(([string]$outTask.Result) -split "`r?`n" | Where-Object { $_ })
    if (-not $res.Why -and ([string]$errTask.Result).Trim()) { $res.Why = 'it wrote error output' }
  } catch { $res.Why = $_.Exception.GetType().Name }
  finally { $script:child = $null; try { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force } } catch { $null = $_ } }
  return $res
}
$rightsScript = @'
param([string]$Site, [string]$MarkerList = '', [string]$MarkerKey = '', [string]$MarkerField = '')
# RADE check (read-only): signs in with the CAC (web login, as T16 does) and prints your rights on the site, whether your
# own account is a site collection administrator (one flag; no list of administrators) and, when the app keeps an install
# record on the site, the version in that one row. Prints only right names, True/False and a version, never the site,
# your name or an error message.
try {
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { 'RESULT no-pnp'; exit 3 }
  $pin = @($mod | Where-Object { [string]$_.Version -eq '1.12.0' }); if ($pin.Count) { $mod = $pin }   # the tested version first (2.x needs PowerShell 7)
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  $null = & { Connect-PnPOnline -Url $Site -UseWebLogin -ErrorAction Stop } *>&1
  $script:web = $null
  $null = & { $script:web = Get-PnPWeb -Includes EffectiveBasePermissions -ErrorAction Stop } *>&1
  $p = $script:web.EffectiveBasePermissions
  $k = [Microsoft.SharePoint.Client.PermissionKind]
  foreach ($n in 'ViewListItems', 'AddListItems', 'EditListItems', 'ManageLists', 'ManageWeb', 'ManagePermissions') { 'RIGHT ' + $n + ' ' + $p.Has($k::$n) }
  try {
    $script:adm = $null
    $null = & { $script:adm = (Get-PnPWeb -Includes CurrentUser -ErrorAction Stop).CurrentUser.IsSiteAdmin } *>&1
    if ($script:adm -is [bool]) { 'ADMIN ' + $script:adm } else { 'ADMIN unknown' }
  } catch { 'ADMIN unknown' }
  if ($MarkerList) {
    try {
      $script:mk = 'none'
      $null = & {
        $l = Get-PnPList -Identity $MarkerList -ErrorAction Stop   # a list that does not exist gives nothing, not an error
        if ($l) {
          $q = "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>" + $MarkerKey + "</Value></Eq></Where></Query><RowLimit>1</RowLimit></View>"
          $it = @(Get-PnPListItem -List $l -Query $q -ErrorAction Stop)
          if ($it.Count) {
            $v = ([string]$it[0][$MarkerField]).Trim()
            if ($v -match '^([0-9][0-9.]*)') { $script:mk = 'found ' + $Matches[1] } elseif ($v) { $script:mk = 'found 0' }   # any value is an install
          }
        }
      } *>&1
      'MARKER ' + $script:mk
    } catch { 'MARKER unknown' }
  }
  exit 0
} catch { 'RESULT not-connected ' + $_.Exception.GetType().Name; exit 2 }
'@
$rightWords = @{ ViewListItems = 'read items'; AddListItems = 'add items'; EditListItems = 'edit items'; ManageLists = 'manage lists'; ManageWeb = 'manage the site'; ManagePermissions = 'manage permissions' }
$rightsNeeded = @('ManageLists', 'ManageWeb', 'ManagePermissions')   # what T16 site setup and list set-up use
# ---- Install record on the site (the Administrator, 14 Nov 26: one install per site). An app with "marker" in the
# manifest keeps one row (Title = Key) in its own list: the installed version and the date, no name. The record in
# RADE\Config is per account; this row is what another account's RADE sees. A site that has the row and an account
# that did not install it: the deploy is blocked (a second import would run every flow twice).
function Get-MarkerArg {
  $m = $script:app.Marker
  if (-not $m) { return '' }
  return (' -MarkerList "' + $m.List + '" -MarkerKey "' + $m.Key + '" -MarkerField "' + $m.Field + '"')
}
function Get-SiteMark([string]$Site) {
  if (-not (Test-SiteUrl $Site)) { return '' }
  return (Get-ShortHash $Site.Trim().TrimEnd('/').ToLowerInvariant())
}
function Test-InstalledHere {
  # True when this account's record for this site (Get-InstalledKey) holds a step: a deploy from this account reached
  # a step here. A run that reached no step does not count.
  if (-not (Get-SiteMark (Get-SiteUrl (Get-BasePath)))) { return $false }
  $e = (Read-Installed (Get-InstalledKey $script:app))
  return [bool]($e -and $e.steps -and $e.steps.Count)
}
function Test-FirstInstall { return ((Test-Deploy) -and [bool]$script:app.Marker -and -not (Test-InstalledHere)) }
$markerScript = @'
param([string]$Site, [string]$MarkerList, [string]$MarkerKey, [string]$MarkerField, [string]$Value)
# RADE (one write): signs in with the CAC and sets one row of the app's own list to the installed version and the date.
# Adds the row when it is missing; changes nothing else. Prints one RESULT word, never the site, a name or an error message.
try {
  $mod = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
  if (-not $mod.Count) { 'RESULT no-pnp'; exit 3 }
  $pin = @($mod | Where-Object { [string]$_.Version -eq '1.12.0' }); if ($pin.Count) { $mod = $pin }
  $null = & { Import-Module PnP.PowerShell -RequiredVersion $mod[0].Version -DisableNameChecking } *>&1
  $null = & { Connect-PnPOnline -Url $Site -UseWebLogin -ErrorAction Stop } *>&1
  $script:res = 'no-list'
  $null = & {
    $l = Get-PnPList -Identity $MarkerList -ErrorAction Stop
    if ($l) {
      $q = "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>" + $MarkerKey + "</Value></Eq></Where></Query><RowLimit>1</RowLimit></View>"
      $it = @(Get-PnPListItem -List $l -Query $q -ErrorAction Stop)
      if ($it.Count) { $null = Set-PnPListItem -List $l -Identity $it[0].Id -Values @{ $MarkerField = $Value } -ErrorAction Stop; $script:res = 'updated' }
      else { $null = Add-PnPListItem -List $l -Values @{ Title = $MarkerKey; $MarkerField = $Value } -ErrorAction Stop; $script:res = 'added' }
    }
  } *>&1
  'RESULT ' + $script:res
  exit 0
} catch { 'RESULT failed ' + $_.Exception.GetType().Name; exit 2 }
'@
function Write-SiteMarker([string]$Base, [bool]$Whole) {
  # After a deploy that ran a step: a part install is recorded too (its flows may be imported already), with the word
  # "partial". Returns the one line for the log and the report.
  $m = $script:app.Marker; $site = Get-SiteUrl $Base
  $where = '"' + $m.List + '", row "' + $m.Key + '"'
  $again = ' Until it is written, another account is not stopped from a second install on this site: run this deploy again'
  if (-not (Test-SiteUrl $site)) { return ('NOTE: the install record on the site (' + $where + ') was not written: no site address.' + $again) }
  $val = [string]$script:app.Version + ' ' + (Get-Date).ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture) + $(if ($Whole) { '' } else { ' partial' })
  $r = Invoke-ChildScript $markerScript ('-Site "' + $site + '"' + (Get-MarkerArg) + ' -Value "' + $val + '"') 300 $null
  $w = ''; foreach ($l in $r.Lines) { if ($l -match '^RESULT (\S+)') { $w = $Matches[1] } }
  if ($w -in 'added', 'updated') { return ('Install record on the site: ' + $where + ' now holds version ' + $script:app.Version + ' and the date' + $(if ($Whole) { '' } else { ', marked partial' }) + ' (' + $w + ').') }
  $why = $(switch ($w) { 'no-list' { 'the list was not found' } 'no-pnp' { 'the SharePoint tool is not installed' } default { 'the sign-in or the write did not finish' } })
  return ('NOTE: the install record on the site (' + $where + ') was not written: ' + $why + '.' + $again)
}
function Split-Sentence([string]$Text) {
  # One sentence per line on screen (PFM 14 Nov 26): a break after . ! or ? when a capital, a quote or a bracket follows.
  return ($Text -replace '(?<=[.!?])\s+(?=[A-Z"\[])', "`r`n")
}
function Format-CheckResult([string]$State, [string]$Detail, [string]$Fix) {
  # Text rule (the Administrator, 2026-11-14, replaces the full-stop rule): each Details line starts with a capital and ends
  # with no full stop; one fact per line, never joined with ";". Names on the screen (buttons, menus) are in "double quotes";
  # literal values the computer reports (versions, codes, error names) are in [brackets].
  if ($Detail) { $Detail = $Detail.Substring(0, 1).ToUpper() + $Detail.Substring(1); $Detail = $Detail -replace '\.$', '' }
  if ($Fix) { $Fix = $Fix -replace '\.$', '' }
  return @{ State = $State; Detail = $Detail; Fix = $Fix }
}
function Invoke-Check($Def, [string]$Base, [string]$Site, [scriptblock]$Tick) {
  # One check. States: PASSED, WARNING, FAILED, NOT RUN. Detail and Fix never hold the site address or the DODID.
  $one = $null
  try {
    switch ($Def.Id) {
      'nipr' {
        # Reads only this computer's own full name (Test-NiprDevice); the name itself is never shown or saved.
        if (Test-NiprDevice) { $one = Format-CheckResult 'PASSED' 'Read this computer''s own full name: it is in the area52 domain' '' }
        else { $one = Format-CheckResult 'FAILED' 'This application cannot be installed in your environment.' '' }
      }
      'ps' {
        $v = $PSVersionTable.PSVersion
        if ($v -ge [version]'5.1') { $one = Format-CheckResult 'PASSED' ('version [' + $v + ']') '' }
        else { $one = Format-CheckResult 'FAILED' ('version [' + $v + ']') 'Open Windows PowerShell ISE from the Start menu, then paste the round again' }
      }
      'lang' {
        $m = [string]$ExecutionContext.SessionState.LanguageMode
        if ($m -eq 'FullLanguage') { $one = Format-CheckResult 'PASSED' 'Not restricted' '' }
        else { $one = Format-CheckResult 'FAILED' ('Restricted [' + $m + ']') 'PowerShell is restricted on this computer. Contact your ISSM and send the results e-mail as is' }
      }
      'onedrive' {
        $od = Get-OneDrivePath
        if (Test-Path -LiteralPath $od -PathType Container) { $one = Format-CheckResult 'PASSED' 'found' '' }
        else { $one = Format-CheckResult 'FAILED' 'not found' 'Sign in to OneDrive, wait until it is up to date, then select "Run checks again"' }
      }
      'disk' {
        $od = Get-OneDrivePath
        $root = [System.IO.Path]::GetPathRoot($od); if (-not $root) { $root = [System.IO.Path]::GetPathRoot([System.IO.Path]::GetTempPath()) }
        $free = (New-Object System.IO.DriveInfo($root)).AvailableFreeSpace
        $need = 200MB; foreach ($f in $files) { $need += 2 * $f.Data.Length }
        $mb = [math]::Floor($free / 1MB)
        if ($free -lt $need) { $one = Format-CheckResult 'FAILED' ('{0:N0} MB free, {1:N0} MB needed' -f $mb, [math]::Ceiling($need / 1MB)) 'Free up space (for example, empty the Recycle Bin), then select "Run checks again"' }
        elseif ($free -lt 1GB) { $one = Format-CheckResult 'WARNING' ('{0:N0} MB free' -f $mb) 'Enough for this deployment. Free up space soon' }
        else { $one = Format-CheckResult 'PASSED' ('{0:N0} MB free' -f $mb) '' }
      }
      'write' {
        $od = Get-OneDrivePath
        if (-not (Test-Path -LiteralPath $od -PathType Container)) { $one = Format-CheckResult 'NOT RUN' 'No OneDrive folder' 'Resolve the OneDrive check first' }
        else {
          $t = Join-Path $od ('@@PREFIX@@-write-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.tmp')
          [System.IO.File]::WriteAllText($t, 'test'); Remove-Item -LiteralPath $t -Force
          $one = Format-CheckResult 'PASSED' 'Test file saved and deleted' ''
        }
      }
      'child' {
        # Steps run as child scripts with -ExecutionPolicy Bypass; a Group Policy can still block them.
        $r = Invoke-ChildScript "'child ok'`r`nexit 7`r`n" '' 60 $Tick
        $pol = ''
        try { $pol = (@(Get-ExecutionPolicy -List | Where-Object { $_.Scope -match 'Policy$' -and [string]$_.ExecutionPolicy -ne 'Undefined' } | ForEach-Object { [string]$_.Scope + '=' + [string]$_.ExecutionPolicy }) -join ', ') } catch { $null = $_ }
        if ($r.Exit -eq 7) { $one = Format-CheckResult 'PASSED' ('Test script ran' + $(if ($pol) { ', policy [' + $pol + ']' } else { '' })) '' }
        else { $one = Format-CheckResult 'FAILED' ('Test script did not run, exit code [' + $r.Exit + ']' + $(if ($r.Why) { ', ' + $r.Why } else { '' }) + $(if ($pol) { ', policy [' + $pol + ']' } else { '' })) 'This computer blocks RADE scripts. Contact your ISSM and send the results e-mail as is' }
      }
      'outlook' {
        if ($env:OS -ne 'Windows_NT') { $one = Format-CheckResult 'WARNING' 'Not Windows' 'RADE opens the results folder and copies the summary for your e-mail' }
        elseif ([type]::GetTypeFromProgID('Outlook.Application')) { $one = Format-CheckResult 'PASSED' 'Installed' '' }
        else { $one = Format-CheckResult 'WARNING' 'Classic Outlook not found (new Outlook cannot make drafts)' 'RADE opens the results folder and copies the summary for your e-mail' }
      }
      'word' {
        if ($env:OS -eq 'Windows_NT' -and [type]::GetTypeFromProgID('Word.Application')) {
          if (Test-WordOpen) { $one = Format-CheckResult 'FAILED' 'Installed, but open now' 'Save your work, close Word, then select "Run checks again"' }   # PFM 14 Nov 26: blocks (1B)
          else { $one = Format-CheckResult 'PASSED' 'Installed' '' }
        } else { $one = Format-CheckResult 'FAILED' 'Not found' 'This application requires Microsoft Word' }
      }
      'pnp' {
        $m = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending)
        if (-not $m.Count) { $one = Format-CheckResult 'FAILED' 'Not installed' 'Site steps require it. Use the manual steps in the repository' }
        elseif ([string]$m[0].Version -eq '1.12.0') { $one = Format-CheckResult 'PASSED' 'version [1.12.0]' '' }
        else { $one = Format-CheckResult 'WARNING' ('Version [' + $m[0].Version + '], tested with [1.12.0]') 'Likely compatible. If a site step fails, send the results as is' }
      }
      'net-bookmark' {
        $w = Test-WebReach $goUrl   # the file the "newer round" notice reads
        if ($w.Ok) { $one = Format-CheckResult 'PASSED' ('reached' + $(if ($w.Code) { ', code [' + $w.Code + ']' } else { '' })) '' }
        else { $one = Format-CheckResult 'WARNING' ('Not reached: ' + $w.Why) 'Optional: only the new-round notice uses it' }
      }
      'net-site' {
        if (-not (Test-SiteUrl $Site)) { $one = Format-CheckResult 'NOT RUN' 'No site address' ('Complete the "Site address" box (it starts with ' + $sitePrefix + '), then select "Run checks again"') }
        else {
          $w = Test-WebReach $Site
          if ($w.Ok) { $one = Format-CheckResult 'PASSED' ('Reached' + $(if ($w.Code -in 401, 403) { ', code [' + $w.Code + '] (sign-in required, as expected)' } elseif ($w.Code) { ', code [' + $w.Code + ']' } else { '' })) '' }
          else { $one = Format-CheckResult 'FAILED' ('Not reached: ' + $w.Why) 'Verify the address opens in Edge, then select "Run checks again"' }
        }
      }
      'net-flow' {
        $fp = Get-FlowPortal $Base
        if (-not $fp.Url) { $one = Format-CheckResult 'NOT RUN' 'No Power Automate address' '' }
        else {
          $w = Test-WebReach $fp.Url
          if ($w.Ok) { $one = Format-CheckResult 'PASSED' ('reached' + $(if ($w.Code) { ', code [' + $w.Code + ']' } else { '' })) '' }
          else { $one = Format-CheckResult 'FAILED' ('Not reached: ' + $w.Why) 'If Power Automate opens in Edge, select "Check Power Automate"' }
        }
      }
      'site-rights' {
        if (-not (Test-SiteUrl $Site)) { $one = Format-CheckResult 'NOT RUN' 'No site address' ('Complete the "Site address" box first (it starts with ' + $sitePrefix + ')') }
        else {
          $r = Invoke-ChildScript $rightsScript ('-Site "' + $Site + '"' + (Get-MarkerArg)) 300 $Tick
          $have = @{}; $adm = 'unknown'; $mk = ''
          foreach ($l in $r.Lines) {
            if ($l -match '^RIGHT (\w+) (True|False)$') { $have[$Matches[1]] = ($Matches[2] -eq 'True') }
            if ($l -match '^ADMIN (True|False|unknown)$') { $adm = $Matches[1] }
            if ($l -match '^MARKER (none|unknown|found [0-9.]+)$') { $mk = $Matches[1] }
          }
          $admText = 'Site collection administrator: ' + $(switch ($adm) { 'True' { 'yes' } 'False' { 'no' } default { 'not read' } }) + ' (shown only, not required)'
          if (-not $have.Count) {
            $why = 'Sign-in did not finish'; foreach ($l in $r.Lines) { if ($l -match '^RESULT (\S+)') { $why = $Matches[1] } }
            if ($why -eq 'not-connected') { $why = 'Sign-in did not finish' }
            if ($why -eq 'no-pnp') { $one = Format-CheckResult 'FAILED' 'SharePoint tool not installed' 'See the SharePoint tool check' }
            else { $one = Format-CheckResult 'FAILED' ($why + $(if ($r.Why) { ', ' + $r.Why } else { '' })) 'Select "Sign in and check site rights" and complete the CAC sign-in' }
          } else {
            $miss = @($rightsNeeded | Where-Object { -not $have[$_] } | ForEach-Object { $rightWords[$_] })
            $got = @($have.Keys | Sort-Object | Where-Object { $have[$_] } | ForEach-Object { $rightWords[$_] })
            if ($miss.Count) { $one = Format-CheckResult 'FAILED' ('Missing: ' + ($miss -join ', ')) 'Ask a site owner to add you to the site Owners group' }
            elseif ((Test-FirstInstall) -and $mk -like 'found *') { $one = Format-CheckResult 'FAILED' ('This site already has an install of this application [version ' + $(if ($mk -eq 'found 0') { 'not readable' } else { $mk.Substring(6) }) + '], made from another account or for another site') 'Do not install again: every flow would run twice. Ask the person who installed it to run RADE' }
            elseif ((Test-FirstInstall) -and $mk -ne 'none') { $one = Format-CheckResult 'FAILED' 'The install record on the site could not be read' 'Select "Sign in and check site rights" again' }
            else { $one = Format-CheckResult 'PASSED' ('Rights: ' + ($got -join ', ') + '. ' + $admText) '' }
          }
        }
      }
      'flow-guide' {
        if ($script:textMode) {
          $fp = Get-FlowPortal $Base
          Write-Host ('  Open Power Automate (' + $fp.Url + '). Look at the left menu for "Solutions" (it may be under "More"), then select "My flows" and look for "Import".')
          $a = ([string](Read-Host 'Did you see both "Solutions" and "Import"? Type Y or N and press Enter')).Trim()
          if ($a -match '^[Yy]') { $one = Format-CheckResult 'PASSED' 'Confirmed by you' '' }
          else { $one = Format-CheckResult 'FAILED' '"Solutions" or "Import" not shown' 'Ask your Power Automate administrator for maker access' }
        }
        else {
          $fp = Get-FlowPortal $Base
          $g = @{ Name = 'Check Power Automate'; File = ''; Url = $fp.Url; DoneText = 'Yes: I see both'; NoText = 'No: one is missing'; SkipText = 'Not now'
            Guide = @('You look in Power Automate and answer (about 2 minutes, an estimate). Nothing is changed.',
              '1. Select Open in browser. Power Automate opens; sign in with your CAC if asked.',
              '2. Look at the left menu: it must show Solutions (it may be under More).',
              '3. Select My flows: Import must show at the top of the page.',
              '4. Come back here. Select Yes if you saw both, No if one is missing.') }
          $a = 'Cancel'; if ($script:guideUi) { $a = [string](@(& $script:guideUi $g '' $fp.Url $fp.Config))[-1] }
          if ($a -eq 'OK') { $one = Format-CheckResult 'PASSED' 'Confirmed by you' '' }
          elseif ($a -eq 'No') { $one = Format-CheckResult 'FAILED' '"Solutions" or "Import" not shown' 'Ask your Power Automate administrator for maker access' }
          else { $one = Format-CheckResult 'NOT RUN' 'Not answered' 'Select "Check Power Automate" when ready' }
        }
      }
      default { $one = Format-CheckResult 'NOT RUN' 'unknown check' '' }
    }
  } catch { $one = Format-CheckResult 'FAILED' ('Check stopped with an error [' + $_.Exception.GetType().Name + ']') 'Select "Run checks again". If it repeats, send the results as is' }
  if ($Def.Advisory -and $one.State -eq 'FAILED') { $one.State = 'WARNING' }
  return $one
}
function Get-CheckSummary($Results) {
  # For the summary and the e-mail: one count line, then one line for each check that did not pass.
  $c = @{ PASSED = 0; WARNING = 0; FAILED = 0; 'NOT RUN' = 0 }
  $rest = @(); $saved = 0
  foreach ($id in $script:appChecks) {
    $r = $Results[$id]; $d = Get-CheckDef $id
    if (-not $r) { $r = Format-CheckResult 'NOT RUN' 'not run' '' }
    $c[$r.State]++
    if ($r.Saved) { $saved++ }
    if ($r.State -ne 'PASSED') { $rest += ('  ' + $r.State + ': ' + $d.Name + '. ' + $r.Detail) }
  }
  $savedText = $(if ($saved) { ' (' + $saved + ' from saved results)' } else { '' })
  return @(@(('Checks. Passed: ' + $c.PASSED + $savedText + '. Warnings: ' + $c.WARNING + '. Failed: ' + $c.FAILED + '. Not run: ' + $c['NOT RUN'] + '.')) + $rest) | ForEach-Object { ConvertTo-Masked $_ }
}
function Get-CheckBlock($Results) {
  # PFM 14 Nov 26: no deploy unless every check passes (a half-done deploy is hard to undo). FAILED or NOT RUN blocks;
  # a WARNING (an advisory check, or a problem the deploy can live with) does not. No "deploy anyway".
  foreach ($id in $script:appChecks) { $r = $Results[$id]; if (-not $r -or $r.State -in 'FAILED', 'NOT RUN', 'RUNNING') { return $true } }
  return $false
}
# ---- Saved checks (PFM 14 Nov 26, R17): RADE\Config\rade-checks.json keeps each check that PASSED, so a later run (of
# any app on this computer) can skip it. A saved result is used only when it is at most $checkMaxDays days old, the
# PowerShell and PnP versions and the computer are the same, and its scope (the site or the Power Automate address, as a
# hash) matches. A check that did not pass is never saved. No DODID, name or address is in the file (details are masked).
$checkMaxDays = 7
# Checks whose answer can change between two runs on the same day always run (review R17 MAJOR 2: "Word is open" blocks a
# deploy, PFM 14 Nov 26 1B; free space; a test file in OneDrive).
$checkNoSave = @('nipr', 'word', 'disk', 'write')
function Get-ShortHash([string]$Text) {
  if (-not $Text) { return '' }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return (-join ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text.ToLowerInvariant().TrimEnd('/'))) | Select-Object -First 6 | ForEach-Object { $_.ToString('x2') })) } finally { $sha.Dispose() }
}
function Get-CheckHost {
  # What makes a saved result stale when it changes: PowerShell, the PnP module, the computer (hashed).
  if ($script:checkHost) { return $script:checkHost }
  $pnp = ''; try { $m = @(Get-Module -ListAvailable -Name PnP.PowerShell | Sort-Object Version -Descending); if ($m.Count) { $pnp = [string]$m[0].Version } } catch { $null = $_ }
  $script:checkHost = @{ powershell = [string]$PSVersionTable.PSVersion; pnp = $pnp; computer = (Get-ShortHash ([string]$env:COMPUTERNAME)) }
  return $script:checkHost
}
function Get-CheckScope([string]$Id, [string]$Base, [string]$Site) {
  # A result about one site or one address is good only for that site or address.
  if ($Id -in 'net-site', 'site-rights') { return ('site:' + (Get-ShortHash $Site)) }
  if ($Id -in 'net-flow', 'flow-guide') { return ('flow:' + (Get-ShortHash (Get-FlowPortal $Base).Url)) }
  return ''
}
function Read-CheckCache {
  $p = Get-RadeConfigFile 'rade-checks.json'
  $res = @{}
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $res }
  try {
    $j = [System.IO.File]::ReadAllText($p) | ConvertFrom-Json
    $h = Get-CheckHost
    if ([string]$j.host.powershell -ne $h.powershell -or [string]$j.host.pnp -ne $h.pnp -or [string]$j.host.computer -ne $h.computer) { return $res }
    foreach ($c in @($j.checks.PSObject.Properties)) {
      $v = $c.Value
      $at = $v.at; if ($at -is [datetime]) { $at = $at.ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture) }   # PowerShell 7 reads it as a date
      $res[$c.Name] = @{ State = [string]$v.state; Detail = [string]$v.detail; Fix = ''; At = [string]$at; Scope = [string]$v.scope }
    }
  } catch { $null = $_ }   # a damaged file is ignored: every check runs
  return $res
}
function Get-CheckAge([string]$At) {
  # Days since a saved result (fractional); -1 when the date cannot be read.
  $d = [datetime]::MinValue
  if ([datetime]::TryParseExact($At, 'yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture, 'None', [ref]$d)) { return ((Get-Date) - $d).TotalDays }
  return 99999   # unreadable: too old
}
function Get-SavedCheck($Cache, [string]$Id, [string]$Scope) {
  # The saved result to use, or $null (with the reason in $script:savedWhy[$Id] when one was found but is too old).
  if ($checkNoSave -contains $Id) { return $null }
  $c = $Cache[$Id]
  if (-not $c -or $c.State -ne 'PASSED' -or $c.Scope -ne $Scope) { return $null }
  $age = Get-CheckAge $c.At
  if ($age -lt -0.01) { $script:savedWhy[$Id] = 'Last check date is in the future (clock changed)'; return $null }
  if ($age -gt $checkMaxDays) { $script:savedWhy[$Id] = ('Last check ' + [int][math]::Floor([math]::Max(0, $age)) + ' days ago, older than ' + $checkMaxDays + ' days'); return $null }
  # Two lines (the Administrator, 2026-11-14): "Last check: 17 Nov 26", then what that check found; no full stops.
  $d0 = [datetime]::ParseExact($c.At, 'yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
  $found = ([string]$c.Detail) -replace '\.$', ''; if ($found) { $found = $found.Substring(0, 1).ToUpperInvariant() + $found.Substring(1) }
  return @{ State = 'PASSED'; Detail = ('Last check: ' + $d0.ToString('d MMM yy', [System.Globalization.CultureInfo]::InvariantCulture)); Fix = $found; Saved = $true; Found = $found }
}
function Save-CheckCache($Results, [string]$Base, [string]$Site) {
  # Keeps the old file's other entries (other apps' checks), replaces this run's: PASSED is saved, anything else removed.
  try {
    $p = Get-RadeConfigFile 'rade-checks.json'
    $keep = @{}
    if (Test-Path -LiteralPath $p -PathType Leaf) {
      try { $j = [System.IO.File]::ReadAllText($p) | ConvertFrom-Json; foreach ($c in @($j.checks.PSObject.Properties)) { $keep[$c.Name] = $c.Value } } catch { $null = $_ }
      try { $h0 = Get-CheckHost; if ([string]$j.host.powershell -ne $h0.powershell -or [string]$j.host.pnp -ne $h0.pnp -or [string]$j.host.computer -ne $h0.computer) { $keep = @{} } } catch { $null = $_ }
    }
    foreach ($id in @($Results.Keys)) {
      $r = $Results[$id]
      if ($r.Saved) { continue }   # a saved result keeps its first date
      if ($checkNoSave -contains $id) { if ($keep.ContainsKey($id)) { $keep.Remove($id) }; continue }
      if ($r.State -eq 'PASSED') {
        $keep[$id] = [ordered]@{ state = 'PASSED'; detail = (ConvertTo-Masked ([string]$r.Detail)); at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture); scope = (Get-CheckScope $id $Base $Site) }
      } elseif ($keep.ContainsKey($id) -and $r.State -ne 'RUNNING') { $keep.Remove($id) }
    }
    $sorted = [ordered]@{}; foreach ($k in @($keep.Keys | Sort-Object)) { $sorted[$k] = $keep[$k] }
    $doc = [ordered]@{
      schema = 'rade-checks/1'
      about = ('Saved RADE checks. Any app may read this file: use an entry only when its state is PASSED, its "at" is at most ' + $checkMaxDays + ' days old, "host" equals this computer (PowerShell, PnP and the hashed computer name), and "scope" matches (site: or flow: plus the first 12 hex of the SHA-256 of the lower-case address). Write only PASSED results; remove an entry when the check does not pass.')
      maxAgeDays = $checkMaxDays
      host = (Get-CheckHost)
      checks = $sorted
    }
    Write-FileWhole $p ($doc | ConvertTo-Json -Depth 5)
  } catch { $null = $_ }   # saving is a convenience: never stop for it
}
function Get-CheckToRun($Def, $Cache, [string]$Base, [string]$Site, [bool]$Force) {
  # $null = run it now; else the saved result to show.
  if ($Force) { return $null }
  if ($Def.Id -eq 'site-rights' -and (Test-FirstInstall)) { return $null }   # a first install always reads the site's install record fresh
  return (Get-SavedCheck $Cache $Def.Id (Get-CheckScope $Def.Id $Base $Site))
}
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
if ($gui) {
  try {
    # The "One thing" window (the Administrator, 2026-11-14; docs/window-design.md): the window shows one statement or one
    # question at a time; everything else (all checks, the step boxes, the files, the made list, the log) is in the Record
    # (F2). Each answer moves on: there is no Next / Back row and no Exit button (Esc goes back, and exits on Choose; the window's X exits).
    # Every window value lives in $ui: handlers and the engine's callbacks run inside engine functions, where a plain
    # variable name could meet a local of the same name. A block stored in $ui reads only $ui and the bundle's globals.
    # R28 item 1 (the Administrator, 2026-11-17): text scales with the controls. Two ways were possible: (a) ask Windows for the real
    # dpi (SetProcessDPIAware, GetDpiForWindow: a native call from user32) and size everything from it, or (b) AutoScaleMode Font.
    # (b) scales by the form font, which Windows draws at 96 dpi on the R25 device (dpiX 96, autoScale 144, font 18 px): it gives
    # no scaling at all there. RADE takes (a) and keeps one scale source: the controls follow the form's auto-scale (as before),
    # and every font is made bigger by the same factor when the screen draws text smaller ($ui.FontScale in engine/rade_ui.ps1).
    # The native call is asked for before any form exists; it changes nothing when the process already has an awareness
    # (the call fails), and when a native call cannot be compiled (Constrained Language Mode) the window runs as before.
    $script:native = $false
    if ($env:OS -eq 'Windows_NT') {
      try { Add-Type -Namespace Rade -Name Native -MemberDefinition ('[DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); ' +
          '[DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hWnd); [DllImport("user32.dll")] public static extern bool HideCaret(IntPtr hWnd);') -ErrorAction Stop
        $script:native = $true; try { $null = [Rade.Native]::SetProcessDPIAware() } catch { $null = $_ } } catch { $script:native = $false }
    }
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $ui = @{ View = ''; Running = $false; Busy = $false; RecOn = $false; Edit = $false; Answer = ''; Acts = @(); Back = $null; OnOpt = $null; FieldDo = $null
      Log = (New-Object System.Collections.Generic.List[string]); Summary = @(); Sel = @{}; Clean = $true; StepState = @{}; Plan = $null; Picked = $false
      BaseIds = @(); BaseRes = @{}; Blocked = @{}; Newer = @{}; Bars = @{}; G = $null; GUrl = ''; CurId = ''; StepI = 0; StepN = 0; StepNow = ''; BusyShown = $false; Always = @($false, $false, $false, $false, $false); Cancel = $false; Dpi = 96.0; ScreenDpi = 96.0; FontK = 1.0; FontDpi = 96.0; Scaled = $false; Full = @{}; Clock = [System.Diagnostics.Stopwatch]::StartNew(); CardAt = -1000000.0; GuardMs = 400; Calm = $false; ContentW = 780 }
    $ui.Hist = Read-RoundHistory (Get-BasePath)
    $script:secret = Get-Secret (Get-ProfileLeaf) (Get-ProfileLeaf)   # saved checks are masked before they are written
    try { $ui.Calm = -not [System.Windows.Forms.SystemInformation]::UIEffectsEnabled } catch { $null = $_ }
    $ui.Form = New-Object System.Windows.Forms.Form
    $ui.Form.Text = 'RADE - ' + 'Test and deploy apps for your organization' + ' - ' + $round + ' - build ' + $buildId   # the tagline (no "DoD": the Administrator, 14 Nov 26) is in the title bar; the window itself has none
    $ui.Form.SuspendLayout()
    $ui.Form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96); $ui.Form.AutoScaleMode = 'Dpi'   # sizes below are at 100 % scaling
    @@UI@@
    $ui.Form.ClientSize = New-Object System.Drawing.Size(1020, 760)   # at 100 %; the minimum size is set when the window has its scale (Shown)
    $ui.Form.StartPosition = 'CenterScreen'; $ui.Form.KeyPreview = $true; $ui.Form.BackColor = $ui.C.White
    $ui.Form.ShowInTaskbar = $true; $ui.Form.MinimizeBox = $true   # its own taskbar button: a minimized window can be restored (R24)

    # ---- The fixed parts: the light (6 px), the logo line, the card, the bottom line and the bar on the bottom edge.
    $ui.Light = New-Object System.Windows.Forms.Panel
    $ui.Light.Dock = 'Top'; $ui.Light.Height = 6; $ui.Light.BackColor = $ui.C.White; $ui.Light.AccessibleRole = 'StaticText'; $ui.Light.AccessibleName = 'Status light: off'
    $ui.Light.Add_Paint({ try { $pn = New-Object System.Drawing.Pen($ui.C.Navy, [single]1); $_.Graphics.DrawLine($pn, 0, ($this.ClientSize.Height - 1), $this.ClientSize.Width, ($this.ClientSize.Height - 1)); $pn.Dispose() } catch { $null = $_ } })   # a 1 px navy line: the light is a part of the screen, 3 to 1 against white also when it is off
    $ui.Top = New-Object System.Windows.Forms.FlowLayoutPanel
    $ui.Top.Dock = 'Top'; $ui.Top.Height = 64; $ui.Top.WrapContents = $false; $ui.Top.Padding = (& $ui.Pad 32 12 32 0); $ui.Top.BackColor = $ui.C.White
    try {
      $ui.Logo = New-Object System.Windows.Forms.PictureBox
      $ui.Logo.Size = New-Object System.Drawing.Size(40, 40); $ui.Logo.SizeMode = 'Zoom'; $ui.Logo.Margin = (& $ui.Pad 0 0 12 0); $ui.Logo.AccessibleName = 'RADE logo'
      $ui.Logo.Image = [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(, [System.Convert]::FromBase64String($logoPng))))
      [void]$ui.Top.Controls.Add($ui.Logo)
    } catch { $null = $_ }   # the window runs without the logo
    $ui.WordL = & $ui.Label $ui.F.Word $ui.C.Navy 5; $ui.WordL.Text = 'RADE'; $ui.WordL.Visible = $true
    $ui.AppL = & $ui.Label $ui.F.Small $ui.C.Gray 14; $ui.AppL.Margin = (& $ui.Pad 10 14 0 0); $ui.AppL.Visible = $true
    $ui.AppL.AutoSize = $false; $ui.AppL.AutoEllipsis = $true; $ui.AppL.Size = New-Object System.Drawing.Size(600, 22)   # a long name and version: cut with "..."; its width follows the window ($ui.Fit)
    [void]$ui.Top.Controls.Add($ui.WordL); [void]$ui.Top.Controls.Add($ui.AppL)
    $ui.Bottom = New-Object System.Windows.Forms.TableLayoutPanel
    $ui.Bottom.Dock = 'Bottom'; $ui.Bottom.Height = 46; $ui.Bottom.AutoSize = $true; $ui.Bottom.AutoSizeMode = 'GrowAndShrink'; $ui.Bottom.MinimumSize = New-Object System.Drawing.Size(0, 46); $ui.Bottom.ColumnCount = 4; $ui.Bottom.RowCount = 1; $ui.Bottom.Padding = (& $ui.Pad 28 3 32 3); $ui.Bottom.BackColor = $ui.C.White
    foreach ($cs in @('AutoSize', 'AutoSize', 'Percent', 'AutoSize')) { [void]$ui.Bottom.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle($cs, 100))) }
    [void]$ui.Bottom.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))   # as tall as the links with their margin and focus ring, 46 at least (R24: 1 px cut at 150 %)
    $ui.RecB = & $ui.LinkBtn 'Record (F2)'; $ui.RecB.AccessibleName = 'Record: all checks, steps, files and the log (F2)'
    $ui.BackB = & $ui.LinkBtn 'Back'; $ui.BackB.AccessibleName = 'Back (Esc)'; $ui.BackB.Visible = $false
    $ui.RightL = & $ui.Label $ui.F.Small $ui.C.Gray 0; $ui.RightL.Anchor = 'Right'; $ui.RightL.Visible = $true
    $ui.Bottom.Controls.Add($ui.RecB, 0, 0); $ui.Bottom.Controls.Add($ui.BackB, 1, 0); $ui.Bottom.Controls.Add($ui.RightL, 3, 0); & $ui.Ring $ui.Bottom
    # Bars: RADE draws them (R17). A 30 ms timer eases the fill to its value; with Windows animations off it jumps. No bar
    # moves back inside a run (all) or a step (step). The bar on the bottom edge is all steps; the short one is this step.
    $ui.DrawBar = { param($P, $G) try { $b = $ui.Bars[[string]$P.Tag]; $G.Clear($(if ($b.On) { $ui.C.Track } else { $ui.C.White })); $fw = [int][math]::Round($P.ClientSize.Width * $b.Shown); if ($b.On -and $fw -gt 0) { $br = New-Object System.Drawing.SolidBrush($b.Fill); $G.FillRectangle($br, 0, 0, $fw, $P.ClientSize.Height); $br.Dispose() } } catch { $null = $_ } }
    $ui.MkBar = { param([string]$Name, [string]$Label)
      $p = New-Object System.Windows.Forms.Panel; $p.Height = 4; $p.Tag = $Name; $p.AccessibleRole = 'ProgressBar'; $p.AccessibleName = $Label; $p.AccessibleDescription = '0 %'
      try { [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic, Instance').SetValue($p, $true, $null) } catch { $null = $_ }
      $ui.Bars[$Name] = @{ Panel = $p; Target = 0.0; Shown = 0.0; On = $false; Fill = $ui.C.Blue }
      $p.Add_Paint({ & $ui.DrawBar $this $_.Graphics }); $p }
    $ui.SetBar = { param([string]$Name, [double]$Value, [bool]$On)
      $b = $ui.Bars[$Name]; $v = [math]::Max(0.0, [math]::Min(1.0, $Value))
      if ($v -lt $b.Target - 0.001 -or $ui.Calm) { $b.Shown = $v }   # a new step starts at 0 with no slide back
      $b.Target = $v; $b.On = $On; $b.Panel.AccessibleDescription = [string][int]($v * 100) + ' %'; $b.Panel.Invalidate() }
    $ui.Edge = & $ui.MkBar 'all' 'Progress of all steps'; $ui.Edge.Dock = 'Bottom'
    $ui.Anim = New-Object System.Windows.Forms.Timer
    $ui.Anim.Interval = 30
    $ui.Anim.Add_Tick({ if ([bool]$ui.Busy -ne [bool]$ui.BusyShown) { $ui.BusyShown = [bool]$ui.Busy; try { $ui.Form.Invalidate($true) } catch { $null = $_ } }; foreach ($b in @($ui.Bars.Values)) { $d = $b.Target - $b.Shown; if ([math]::Abs($d) -gt 0.0005) { $b.Shown = $(if ($ui.Calm) { $b.Target } else { $b.Shown + $d * 0.18 }); $b.Panel.Invalidate() } } })

    # ---- The card: one block, left edge at 12 % of the width, 40 % of the spare height above it. Top to bottom: a small
    # line in capitals, the sentence, up to four paragraphs, the choices, a box with its label, the numbered lines of a hand
    # step (then its unnumbered lines), the step line, the error box, two file links, a note, the help line, the closing line
    # of a hand step, the buttons, a last gray line, and the owner's test extras. A card shows only the parts it names ($ui.SetCard).
    $ui.Card = New-Object System.Windows.Forms.TableLayoutPanel
    $ui.Card.Dock = 'Fill'; $ui.Card.ColumnCount = 3; $ui.Card.RowCount = 3; $ui.Card.BackColor = $ui.C.White
    foreach ($w in @(11.75, 76.5, 11.75)) { [void]$ui.Card.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', $w))) }
    [void]$ui.Card.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 40))); [void]$ui.Card.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))); [void]$ui.Card.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 60)))
    # The card is a stack of two: the body (every part above the buttons) and the tail (the buttons, the last gray line
    # and the test extras). The body sits in a panel that scrolls only when the card is taller than the window, so the
    # buttons are always in view (the Administrator, 2026-11-15; $ui.Squeeze). No scroll at 1020 x 616 and larger.
    $ui.MkStack = { $t = New-Object System.Windows.Forms.TableLayoutPanel; $t.AutoSize = $true; $t.AutoSizeMode = 'GrowAndShrink'; $t.ColumnCount = 1; $t.Margin = (& $ui.Pad 0 0 0 0); $t.BackColor = $ui.C.White
      [void]$t.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize'))); $t }
    $ui.Stack = & $ui.MkStack; $ui.Stack.Anchor = 'Top, Left'; $ui.Body = & $ui.MkStack; $ui.Tail = & $ui.MkStack
    $ui.Scroll = New-Object System.Windows.Forms.Panel
    $ui.Scroll.AutoScroll = $true; $ui.Scroll.Margin = (& $ui.Pad 0 0 0 0); $ui.Scroll.BackColor = $ui.C.White; $ui.Scroll.AccessibleName = 'Card text'
    $ui.Body.Location = New-Object System.Drawing.Point(0, 0); [void]$ui.Scroll.Controls.Add($ui.Body)
    $ui.Kick = & $ui.Text $ui.F.SmallB $ui.C.Gray 0 'Card line'
    $ui.SentRow = & $ui.Flow $ui.Z.G1; $ui.SentRow.Visible = $true
    $ui.TickP = New-Object System.Windows.Forms.Panel
    $ui.TickP.Size = New-Object System.Drawing.Size(30, 30); $ui.TickP.Margin = (& $ui.Pad 0 9 12 0); $ui.TickP.Visible = $false; $ui.TickP.AccessibleRole = 'StaticText'; $ui.TickP.AccessibleName = 'Passed'
    $ui.TickP.Add_Paint({ try { $g = $_.Graphics; $g.SmoothingMode = 'AntiAlias'; $w = $this.ClientSize.Width; $pn = New-Object System.Drawing.Pen($ui.C.Green, [single]($w * 0.14)); $pn.StartCap = 'Round'; $pn.EndCap = 'Round'
      $g.DrawLines($pn, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([single](0.16 * $w), [single](0.54 * $w))), (New-Object System.Drawing.PointF([single](0.40 * $w), [single](0.76 * $w))), (New-Object System.Drawing.PointF([single](0.84 * $w), [single](0.26 * $w))))); $pn.Dispose() } catch { $null = $_ } })
    $ui.Sent = & $ui.Text $ui.F.Sent $ui.C.Navy 0 'Card headline'; $ui.Sent.Visible = $true
    [void]$ui.SentRow.Controls.Add($ui.TickP); [void]$ui.SentRow.Controls.Add($ui.Sent)
    $ui.P = @(); foreach ($k in 0..3) { $ui.P += (& $ui.Text $ui.F.Body $ui.C.Navy $(if ($k) { $ui.Z.G1 } else { $ui.Z.G3 }) ('Card text ' + ($k + 1))) }
    $ui.Opts = & $ui.Flow $ui.Z.G6; $ui.Opts.FlowDirection = 'TopDown'; $ui.Opts.AccessibleName = 'Choices'
    # The numbered lines of a hand step: a table of two columns, the number (right-aligned, "1.") and the text (wraps, aligned
    # to the text column). A line with no number follows the list as one small gray text ($ui.Rest). Filled by $ui.SetSteps.
    # Numbers, texts and $ui.Rest are card text ($ui.Text): they can be selected and copied.
    $ui.Steps = New-Object System.Windows.Forms.TableLayoutPanel
    $ui.Steps.AutoSize = $true; $ui.Steps.AutoSizeMode = 'GrowAndShrink'; $ui.Steps.ColumnCount = 2; $ui.Steps.BackColor = $ui.C.White; $ui.Steps.Margin = (& $ui.Pad 0 $ui.Z.G3 0 0); $ui.Steps.Visible = $false; $ui.Steps.AccessibleName = 'Steps to do'
    [void]$ui.Steps.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize'))); [void]$ui.Steps.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize')))
    $ui.NumTexts = @(); $ui.NumLabels = @()
    $ui.Rest = & $ui.Text $ui.F.Small $ui.C.Gray $ui.Z.G3 'More about this step'
    $ui.StepRow = & $ui.Flow $ui.Z.G3; $ui.StepRow.WrapContents = $true   # a long step name: the bar goes to the next line
    $ui.StepName = & $ui.Text $ui.F.Body $ui.C.Navy 0 'Step name'; $ui.StepName.Visible = $true
    $ui.StepBar = & $ui.MkBar 'step' 'Progress of this step'; $ui.StepBar.Width = 200; $ui.StepBar.Margin = (& $ui.Pad 14 11 14 0)
    $ui.StepFrac = & $ui.Label $ui.F.Small $ui.C.Gray 2; $ui.StepFrac.Visible = $true
    foreach ($c in @($ui.StepName, $ui.StepBar, $ui.StepFrac)) { [void]$ui.StepRow.Controls.Add($c) }
    $ui.LastLog = New-Object System.Windows.Forms.Label
    $ui.LastLog.AutoSize = $false; $ui.LastLog.AutoEllipsis = $true; $ui.LastLog.UseMnemonic = $false; $ui.LastLog.Height = 20; $ui.LastLog.Width = 780; $ui.LastLog.Font = $ui.F.Small; $ui.LastLog.ForeColor = $ui.C.Gray; $ui.LastLog.Margin = (& $ui.Pad 0 $ui.Z.G2 0 0); $ui.LastLog.Visible = $false; $ui.LastLog.AccessibleName = 'Last log line'
    $ui.FieldRow = & $ui.Flow $ui.Z.G2; $ui.FieldRow.WrapContents = $true; & $ui.Ring $ui.FieldRow
    $ui.FieldL = & $ui.Label $ui.F.SmallB $ui.C.Gray 9; $ui.FieldL.Visible = $true
    # A one-line box: a frame as tall as a compact button with RADE's own 1 px edge, the text box inside it with no border,
    # in the middle (a text box cannot be made taller with its text in the middle). The ring goes around the frame.
    $ui.Boxes = @()
    $ui.BoxFit = { param($P) if (-not $ui.Scaled) { return }; try { $tb = $P.Controls[0]; $in = & $ui.Sc 6; $tb.Width = [math]::Max(10, $P.ClientSize.Width - 2 * $in); $tb.Location = New-Object System.Drawing.Point($in, [int][math]::Floor(($P.ClientSize.Height - $tb.Height) / 2)) } catch { $null = $_ } }
    $ui.MkBox = { param($Tb, [int]$W)
      $p = New-Object System.Windows.Forms.Panel; $p.Size = New-Object System.Drawing.Size($W, $ui.Z.CompactH); $p.BackColor = $ui.C.White; $p.AccessibleName = 'Text box'
      $Tb.BorderStyle = 'None'; $Tb.Font = $ui.F.Small; $Tb.ForeColor = $ui.C.Ink; [void]$p.Controls.Add($Tb); $Tb.Add_GotFocus({ try { $this.Parent.Parent.Invalidate() } catch { $null = $_ } }); $Tb.Add_LostFocus({ try { $this.Parent.Parent.Invalidate() } catch { $null = $_ } })
      $p.Add_Paint({ try { $pn = New-Object System.Drawing.Pen($ui.C.Edge); $_.Graphics.DrawRectangle($pn, 0, 0, ($this.ClientSize.Width - 1), ($this.ClientSize.Height - 1)); $pn.Dispose() } catch { $null = $_ } })
      $p.Add_SizeChanged({ & $ui.BoxFit $this }); $p.Add_Click({ try { [void]$this.Controls[0].Focus() } catch { $null = $_ } }); $ui.Boxes += $p; $p }
    $ui.Field = New-Object System.Windows.Forms.TextBox
    $ui.FieldBox = & $ui.MkBox $ui.Field 420; $ui.FieldBox.Margin = (& $ui.Pad $ui.Z.G2 $ui.Z.M $ui.Z.M $ui.Z.M)   # 8 from the label; 4 + the button's 4 = 8 to the button
    $ui.FieldB = & $ui.Btn 'compact'
    $ui.FieldB.Add_Click({ if ($ui.FieldDo) { & $ui.FieldDo } })
    foreach ($c in @($ui.FieldL, $ui.FieldBox, $ui.FieldB)) { [void]$ui.FieldRow.Controls.Add($c) }
    $ui.ErrRow = & $ui.Flow $ui.Z.G2; & $ui.Ring $ui.ErrRow
    $ui.ErrBox = New-Object System.Windows.Forms.TextBox
    $ui.ErrBox.Multiline = $true; $ui.ErrBox.ScrollBars = 'Vertical'; $ui.ErrBox.Size = New-Object System.Drawing.Size(600, 96); $ui.ErrBox.Margin = (& $ui.Pad 4 4 4 4); $ui.ErrBox.BorderStyle = 'FixedSingle'; $ui.ErrBox.Font = $ui.F.Small; $ui.ErrBox.ForeColor = $ui.C.Ink; $ui.ErrBox.AccessibleName = 'Error message'; & $ui.Cue $ui.ErrBox
    [void]$ui.ErrRow.Controls.Add($ui.ErrBox)
    $ui.LinkRow = & $ui.Flow 0; $ui.LinkRow.WrapContents = $true; $ui.LinkRow.Margin = (& $ui.Pad (-$ui.Z.M) 0 0 0); & $ui.Ring $ui.LinkRow
    $ui.CopyPathB = & $ui.LinkBtn 'Copy file path'; $ui.ShowFileB = & $ui.LinkBtn 'Show file in folder'; $ui.PageB = & $ui.LinkBtn 'Open the RADE page'
    $ui.PageB.AccessibleName = 'Open the RADE page in your browser'; $ui.PageB.Visible = $false
    foreach ($c in @($ui.CopyPathB, $ui.ShowFileB, $ui.PageB)) { [void]$ui.LinkRow.Controls.Add($c) }
    $ui.Note = & $ui.Text $ui.F.Small $ui.C.Gray $ui.Z.G2 'Note'
    $ui.Help = & $ui.Text $ui.F.Body $ui.C.Navy $ui.Z.G4 'Help'
    $ui.Close = & $ui.Text $ui.F.Small $ui.C.Gray $ui.Z.G4 'Closing line'   # the hand card's closing line, directly above the buttons ($ui.VHand)
    $ui.BtnRow = & $ui.Flow $ui.Z.G4; $ui.BtnRow.WrapContents = $true; $ui.BtnRow.Margin = (& $ui.Pad (-$ui.Z.M) ($ui.Z.G4 - $ui.Z.M) 0 0); & $ui.Ring $ui.BtnRow   # the buttons' own 4 px margin is part of the 16 px gap
    $ui.B = @(); foreach ($k in 0..4) { $b = & $ui.Btn 'action'; $b.Tag = $k; $b.Add_Click({ $a = $ui.Acts[[int]$this.Tag]; if ($a -and (-not $ui.Busy -or $ui.Always[[int]$this.Tag]) -and (& $ui.Settled)) { & $a } }); $ui.B += $b; [void]$ui.BtnRow.Controls.Add($b) }
    $ui.Foot = & $ui.Text $ui.F.Small $ui.C.Gray ($ui.Z.G6 - $ui.Z.M) 'Last line'
    # The owner's test extras (test rounds only; they go away with the test branch): the results address, the e-mail draft
    # and "the window displayed correctly". A deploy never shows them: it sends nothing.
    $ui.TestRow = & $ui.Flow ($ui.Z.G6 - $ui.Z.M); $ui.TestRow.WrapContents = $true; & $ui.Ring $ui.TestRow
    $ui.TestL = & $ui.Label $ui.F.SmallB $ui.C.Gray 10; $ui.TestL.Text = 'Test rounds only'; $ui.TestL.Visible = $true
    $ui.ToBox = New-Object System.Windows.Forms.TextBox
    $ui.ToBox.AccessibleName = 'Send results to (e-mail)'; $ui.ToBoxF = & $ui.MkBox $ui.ToBox 240; $ui.ToBoxF.Margin = (& $ui.Pad $ui.Z.G2 $ui.Z.M $ui.Z.M $ui.Z.M)
    $ui.DraftB = & $ui.LinkBtn 'Make e-mail draft'
    $ui.OkBox = New-Object System.Windows.Forms.CheckBox
    $ui.OkBox.AutoSize = $true; $ui.OkBox.Checked = $true; $ui.OkBox.Text = 'The window displayed correctly'; $ui.OkBox.ForeColor = $ui.C.Gray; $ui.OkBox.Margin = (& $ui.Pad 4 9 4 4); $ui.OkBox.AccessibleName = 'The window displayed correctly (nothing overlapped or cut off)'
    foreach ($c in @($ui.TestL, $ui.ToBoxF, $ui.DraftB, $ui.OkBox)) { [void]$ui.TestRow.Controls.Add($c) }
    $ui.Fill = { param($T, $Parts) $row = 0; foreach ($c in @($Parts)) { [void]$T.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))); $T.Controls.Add($c, 0, $row); $row++ }; $T.RowCount = $row }
    & $ui.Fill $ui.Body @($ui.Kick, $ui.SentRow, $ui.P[0], $ui.P[1], $ui.P[2], $ui.P[3], $ui.Opts, $ui.FieldRow, $ui.Steps, $ui.Rest, $ui.StepRow, $ui.LastLog, $ui.ErrRow, $ui.LinkRow, $ui.Note, $ui.Help)
    & $ui.Fill $ui.Tail @($ui.Close, $ui.BtnRow, $ui.Foot, $ui.TestRow)
    & $ui.Fill $ui.Stack @($ui.Scroll, $ui.Tail)
    $ui.Card.Controls.Add($ui.Stack, 1, 1); $ui.Card.SetColumnSpan($ui.Stack, 2)   # two columns: room for the scroll bar beside the text

    # ---- The Record (F2): all checks by group with their result, the steps with a box each (they can be changed only
    # before the run), and one text box with the files (New, Replace, Recycle), what the installs made, and the log.
    $ui.Rec = New-Object System.Windows.Forms.TableLayoutPanel
    $ui.Rec.Dock = 'Fill'; $ui.Rec.ColumnCount = 3; $ui.Rec.RowCount = 2; $ui.Rec.Padding = (& $ui.Pad 28 0 28 8); $ui.Rec.BackColor = $ui.C.White; $ui.Rec.Visible = $false
    foreach ($w in @(36, 30, 34)) { [void]$ui.Rec.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', $w))) }
    [void]$ui.Rec.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))); [void]$ui.Rec.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
    $ui.RecHead = New-Object System.Windows.Forms.FlowLayoutPanel
    $ui.RecHead.AutoSize = $true; $ui.RecHead.WrapContents = $false; $ui.RecHead.BackColor = $ui.C.White; $ui.RecHead.Margin = (& $ui.Pad 0 0 0 4); & $ui.Ring $ui.RecHead
    $ui.RecClose = & $ui.Btn 'compact'; $ui.RecClose.Text = 'Back (Esc)'; $ui.RecClose.AccessibleName = 'Close the Record (Esc)'
    $ui.RecTitle = & $ui.Label $ui.F.Body $ui.C.Navy 9; $ui.RecTitle.Margin = (& $ui.Pad 10 9 0 0); $ui.RecTitle.Text = 'Record'; $ui.RecTitle.Visible = $true
    [void]$ui.RecHead.Controls.Add($ui.RecClose); [void]$ui.RecHead.Controls.Add($ui.RecTitle)
    $ui.RecChecks = New-Object System.Windows.Forms.Panel
    $ui.RecChecks.Dock = 'Top'; $ui.RecChecks.BackColor = $ui.C.White; $ui.RecChecks.AccessibleRole = 'StaticText'; $ui.RecChecks.AccessibleName = 'Checks'
    try { [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic, Instance').SetValue($ui.RecChecks, $true, $null) } catch { $null = $_ }
    $ui.RecSteps = New-Object System.Windows.Forms.FlowLayoutPanel
    $ui.RecSteps.Dock = 'Fill'; $ui.RecSteps.FlowDirection = 'TopDown'; $ui.RecSteps.WrapContents = $false; $ui.RecSteps.AutoScroll = $true; $ui.RecSteps.BackColor = $ui.C.White; $ui.RecSteps.Margin = (& $ui.Pad 0 0 16 0); $ui.RecSteps.AccessibleName = 'Steps'
    $ui.RecText = New-Object System.Windows.Forms.TextBox
    $ui.RecText.Dock = 'Fill'; $ui.RecText.Multiline = $true; $ui.RecText.ReadOnly = $true; $ui.RecText.ScrollBars = 'Vertical'; $ui.RecText.WordWrap = $true; $ui.RecText.Font = $ui.F.Mono; $ui.RecText.BackColor = $ui.C.White; $ui.RecText.ForeColor = $ui.C.Ink; $ui.RecText.BorderStyle = 'FixedSingle'; $ui.RecText.Margin = (& $ui.Pad 4 4 4 4); $ui.RecText.AccessibleName = 'Files, made list and log'
    $ui.Rec.Controls.Add($ui.RecHead, 0, 0); $ui.Rec.SetColumnSpan($ui.RecHead, 3)
    # The painted list sits in a panel that scrolls only when the list is taller than the window (many reused checks at 150 %).
    $ui.RecScroll = New-Object System.Windows.Forms.Panel
    $ui.RecScroll.Dock = 'Fill'; $ui.RecScroll.AutoScroll = $true; $ui.RecScroll.BackColor = $ui.C.White; $ui.RecScroll.Margin = (& $ui.Pad 4 0 24 0)
    $ui.RecScroll.Controls.Add($ui.RecChecks)
    $ui.Rec.Controls.Add($ui.RecScroll, 0, 1); $ui.Rec.Controls.Add($ui.RecSteps, 1, 1); $ui.Rec.Controls.Add($ui.RecText, 2, 1)
    # The Fill parts go in first: they dock last, inside the light, the logo line, the bottom line and the edge bar.
    foreach ($c in @($ui.Card, $ui.Rec, $ui.Bottom, $ui.Edge, $ui.Top, $ui.Light)) { $ui.Form.Controls.Add($c) }
    $ui.Form.ResumeLayout($false); $ui.Form.PerformLayout()

    # The numbered lines of a hand step (the Administrator, 2026-11-17): a guide line that starts with "<digits>. " goes in the
    # table, its number in the right-aligned left column and its text, wrapped, in the right column; any other line follows the
    # list as one small gray text ($ui.Rest). $ui.NumLabels are the numbers and $ui.NumTexts the texts, card text boxes ($ui.Text:
    # selectable, wrapped through $ui.SetWrap); long words are broken like other body text ($ui.BreakAll).
    $ui.SetSteps = { param($Guide)
      $old = @($ui.Steps.Controls); $ui.Steps.Controls.Clear(); $ui.Steps.RowStyles.Clear(); $ui.Steps.RowCount = 0; foreach ($o in $old) { [void]$ui.Wrap.Remove($o); [void]$ui.Raw.Remove($o); $o.Dispose() }
      $ui.NumTexts = @(); $ui.NumLabels = @(); $ui.NumWide = $null; $rest = @(); $row = 0
      foreach ($g in @($Guide)) {
        $g = [string]$g
        if ($g -match '^(\d+)\.\s+(\S.*)$') {
          $num = $Matches[1] + '.'; $txt = $Matches[2]; $top = $(if ($row) { & $ui.Sc $ui.Z.G1 } else { 0 })
          $n = & $ui.Text $ui.F.Body $ui.C.Navy $top ('Step ' + $Matches[1] + ' number'); $n.Text = $num; $n.Visible = $true; $n.Anchor = 'Top, Right'; $n.Margin = (& $ui.Pad 0 $top 0 0)
          $t = & $ui.Text $ui.F.Body $ui.C.Navy $top ('Step ' + $Matches[1]); $t.Text = $txt; $t.Visible = $true; $t.Margin = (& $ui.Pad (& $ui.Sc 8) $top 0 0)
          [void]$ui.Steps.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))); $ui.Steps.Controls.Add($n, 0, $row); $ui.Steps.Controls.Add($t, 1, $row); $row++
          $ui.NumLabels += $n; $ui.NumTexts += $t
          if (-not $ui.NumWide -or $n.Text.Length -gt $ui.NumWide.Text.Length) { $ui.NumWide = $n }
        } elseif ($g.Trim()) { $rest += $g.Trim() }
      }
      $ui.Steps.RowCount = $row; $ui.Steps.Visible = [bool]$row
      & $ui.Show $ui.Rest ($rest -join "`r`n"); & $ui.FitSteps }
    $ui.FitSteps = { try { if (-not $ui.ContentW) { return }
        $nw = 0; foreach ($l in @($ui.NumLabels)) { & $ui.Reflow $l; $nw = [math]::Max($nw, [int]$l.Width) }   # a number is one line: its box is as wide as its text ($ui.Reflow)
        $w = [math]::Max((& $ui.Sc 120), [int]$ui.ContentW - $nw - (& $ui.Sc 8)); foreach ($t in @($ui.NumTexts)) { & $ui.SetWrap $t $w } } catch { $null = $_ } }
    $ui.Fit = {
      if (-not $ui.Scaled) { return }   # R1 review: a size set while Windows Forms scales the form would be scaled again
      # Text wraps at the card's width; the choices are as wide as the card.
      $cw = [math]::Max((& $ui.Sc 240), [int]($ui.Card.ClientSize.Width * 0.765) - (& $ui.Sc 4)); $ui.ContentW = $cw
      foreach ($l in @($ui.Kick, $ui.P[0], $ui.P[1], $ui.P[2], $ui.P[3], $ui.Rest, $ui.Note, $ui.Help, $ui.Foot, $ui.Close)) { & $ui.SetWrap $l $cw }
      & $ui.SetWrap $ui.Sent ($cw - (& $ui.Sc 44)); $ui.LastLog.Width = $cw
      # Rows wrap at the card's width (a button or a box is never cut), and no box is wider than the card.
      $mm = & $ui.Sc $ui.Z.M
      foreach ($r in @($ui.BtnRow, $ui.LinkRow, $ui.TestRow, $ui.FieldRow, $ui.StepRow)) { $r.MaximumSize = New-Object System.Drawing.Size(($cw + 2 * $mm), 0) }
      & $ui.SetWrap $ui.StepName $cw; $ui.ErrBox.Width = [math]::Min((& $ui.Sc 600), ($cw - 2 * $mm))
      try { $ui.AppL.Width = [math]::Max((& $ui.Sc 60), ($ui.Top.ClientSize.Width - $ui.AppL.Left - (& $ui.Sc 32))) } catch { $null = $_ }
      try { $ui.AppL.Height = $ui.AppL.PreferredSize.Height } catch { $null = $_ }
      & $ui.FitRow; & $ui.Apart; & $ui.FitSent; & $ui.FitSteps; & $ui.FitEdges; & $ui.AlignRows
      foreach ($o in @($ui.Opts.Controls)) { $o.Width = $cw; try { $o.Height = (& $ui.OptPlan $o.Tag $cw).H } catch { $null = $_ } }
      & $ui.Squeeze }
    # ---- Alignment (the Administrator, 2026-11-15, after the R24 pictures; docs/window-design.md "Sizes"). An aligned row:
    # its parts share one vertical midpoint (each part's top margin is set from the tallest part). One left edge per card:
    # a label draws its text after a padding that grows with its font (Windows text padding: about 1/6 of the line), so a
    # 22 pt headline started about 3 px right of a 9 pt line and of the buttons. Each part moves by its own padding.
    # Where a part's ink starts, measured: the part drawn into a bitmap by Windows (DrawToBitmap: the same drawing as on
    # screen, with its own flags, padding and the first glyph's side bearing), the first column that differs from its back
    # color. A button with an edge starts at its edge. Without a bitmap (the test stand-ins), the text padding Windows adds
    # (1/6 em, rounded up). R24 job: a formula and a with/without-NoPadding measure both missed by 3 to 6 px.
    # One edge per card at $ui.Sc 10 from the card's column: room for the largest text inset (a 22 pt headline: about 7)
    # and for a button's 4 px margin, because a negative margin is taken as 0 in a table cell (R24 job).
    $ui.FitEdges = { try {
        $mm = & $ui.Sc $ui.Z.M; $x = & $ui.Sc 10; $ui.EdgeX = $x
        foreach ($l in @($ui.Kick, $ui.P[0], $ui.P[1], $ui.P[2], $ui.P[3], $ui.Rest, $ui.Note, $ui.Help, $ui.Foot, $ui.Close, $ui.LastLog, $ui.FieldL, $ui.TestL)) { & $ui.SetLeft $l ($x - (& $ui.Ink $l)) }
        & $ui.SetLeft $ui.TickP 0; & $ui.SetLeft $ui.SentRow ($x - $(if ($ui.TickP.Visible) { & $ui.Ink $ui.TickP } else { & $ui.Ink $ui.Sent }))
        & $ui.SetLeft $ui.StepRow ($x - (& $ui.Ink $ui.StepName)); & $ui.SetLeft $ui.ErrRow ($x - $ui.ErrBox.Margin.Left)
        & $ui.SetLeft $ui.BtnRow ($x - $mm)   # a button's own 4 px margin (room for the ring)
        $l1 = @($ui.LinkRow.Controls | Where-Object { $_.Visible })[0]; if ($l1) { & $ui.SetLeft $ui.LinkRow ($x - $mm - (& $ui.Ink $l1)) }   # a link's text is in the middle of its box
        if ($ui.NumWide) { & $ui.SetLeft $ui.Steps ($x - (& $ui.Ink $ui.NumWide)) }   # the widest number sits on the edge; shorter ones are right-aligned to it
        & $ui.SetLeft $ui.Opts $x } catch { $null = $_ } }
    $ui.AlignRow = { param($Parts, [int]$Base)
      try { $hs = @($Parts | ForEach-Object { if ($_.AutoSize) { [int]$_.PreferredSize.Height } else { [int]$_.Height } }); $hh = [int]($hs | Measure-Object -Maximum).Maximum
        for ($i = 0; $i -lt $Parts.Count; $i++) { $m = $Parts[$i].Margin; $t = $Base + [int][math]::Floor(($hh - $hs[$i]) / 2); $b = $Base + $hh - $hs[$i] - ($t - $Base)
          if ($m.Top -ne $t -or $m.Bottom -ne $b) { $Parts[$i].Margin = New-Object System.Windows.Forms.Padding($m.Left, $t, $m.Right, $b) } } } catch { $null = $_ } }
    $ui.RowParts = { param([string]$Row) switch ($Row) { 'Top' { @(@($ui.Logo) + @($ui.WordL, $ui.AppL) | Where-Object { $_ }) } 'FieldRow' { @($ui.FieldL, $ui.FieldBox) + @($(if ($ui.FieldBOn) { $ui.FieldB })) } 'TestRow' { @($ui.TestL, $ui.ToBoxF, $ui.DraftB, $ui.OkBox) } } }
    $ui.AlignRows = { try { $bh = [int]$ui.FieldB.PreferredSize.Height; if ($bh -gt 0) { foreach ($p in $ui.Boxes) { if ($p.Height -ne $bh) { $p.Height = $bh } } } } catch { $null = $_ }   # a box is as tall as the compact button, measured
      foreach ($p in $ui.Boxes) { & $ui.BoxFit $p }   # the text box fills its frame (R24 job: a frame whose size never changed kept a 100 px text box at its top)
      & $ui.AlignRow (& $ui.RowParts 'Top') 0; $mm = & $ui.Sc $ui.Z.M; & $ui.AlignRow (& $ui.RowParts 'FieldRow') $mm; & $ui.AlignRow (& $ui.RowParts 'TestRow') $mm }
    # The question headline (the prompt's first sentence, manifest "answers") shrinks to fit one line: from the headline size
    # in 0.5 pt steps to 60 % of it (never under the body size); only at that size does it wrap. Other cards keep the headline size.
    $ui.SentFonts = @{}
    # Every text the window puts into a wrapping label of the card: a word wider than the line is broken (M3 review). A
    # label's text set elsewhere since the last break (for example a note) is taken as its new text.
    $ui.Raw = @{}
    $ui.BreakAll = { foreach ($l in (@($ui.Kick, $ui.P[0], $ui.P[1], $ui.P[2], $ui.P[3], $ui.Rest, $ui.StepName, $ui.Note, $ui.Help, $ui.Foot, $ui.Close) + @($ui.NumTexts))) {
        try { $w = [int](& $ui.GetWrap $l); if ($w -le 0 -or -not $l.Text) { continue }
          $e = $ui.Raw[$l]; $raw = $(if ($e -and [string]$l.Text -ceq [string]$e.Out) { [string]$e.Raw } else { [string]$l.Text })
          $b = & $ui.BreakLong $raw $l.Font $w; $ui.Raw[$l] = @{ Raw = $raw; Out = $b }; if ([string]$l.Text -cne $b) { $l.Text = $b } } catch { $null = $_ } } }
    $ui.FitSent = { try {
        $f = $ui.F.Sent; $w = [int](& $ui.GetWrap $ui.Sent); $t = [string]$ui.SentRaw
        if ($ui.View -eq 'answer') { $pt = [double]$ui.F.Sent.SizeInPoints / $ui.FontK; $floor = [math]::Max($pt * 0.6, [double]$ui.F.Body.SizeInPoints / $ui.FontK)
          while ($w -gt 0 -and $pt -gt $floor -and [System.Windows.Forms.TextRenderer]::MeasureText($t, $f).Width -gt $w) {
            $pt = [math]::Max($floor, $pt - 0.5); $k = [string]$pt; if (-not $ui.SentFonts.ContainsKey($k)) { $ui.SentFonts[$k] = & $ui.Font ([string]$ui.F.Sent.Name) $pt $null }; $f = $ui.SentFonts[$k] }
        }
        if (-not [object]::ReferenceEquals($ui.Sent.Font, $f)) { $ui.Sent.Font = $f }
        $b = & $ui.BreakLong $t $f $w; if ($ui.Sent.Text -ne $b) { $ui.Sent.Text = $b } } catch { $null = $_ }
      & $ui.BreakAll }
    $ui.FitRow = {
      # The box of a box row takes the width that is left beside its label and its button (at most 420).
      try { $cw = $ui.ContentW; $left = $cw - $ui.FieldL.PreferredSize.Width - (& $ui.Sc 20)
        if ($ui.FieldBOn) { $left -= ($ui.FieldB.PreferredSize.Width + (& $ui.Sc 8)) }
        $ui.FieldBox.Width = [math]::Max((& $ui.Sc 160), [math]::Min((& $ui.Sc 420), [int]$left)) } catch { $null = $_ } }
    $ui.Apart = {
      # The destructive button (Buttons: Apart) is alone at the right end of the row. When the row is too narrow for
      # that, it starts its own row at the left edge.
      try { $mm = & $ui.Sc $ui.Z.M; $n = -1; $prev = -1; $used = 0
        for ($k = 0; $k -lt 5; $k++) { $ui.BtnRow.SetFlowBreak($ui.B[$k], $false); if ($ui.BOn[$k]) { $ui.B[$k].Margin = (& $ui.Pad $mm $mm $mm $mm); if ($ui.BApart[$k]) { $n = $k } } }
        if ($n -lt 1) { return }
        for ($k = 0; $k -lt $n; $k++) { if ($ui.BOn[$k]) { $prev = $k; $used += $ui.B[$k].PreferredSize.Width + 2 * $mm } }
        $left = $ui.ContentW + $mm - $used - $ui.B[$n].PreferredSize.Width
        if ($prev -lt 0) { return }
        if ($left -ge (& $ui.Sc 32)) { $ui.B[$n].Margin = (& $ui.Pad ([int]$left) $mm $mm $mm) } else { $ui.BtnRow.SetFlowBreak($ui.B[$prev], $true) }
      } catch { $null = $_ } }
    $ui.Squeeze = {
      if (-not $ui.Scaled) { return }
      # The body is as tall as its parts. Only when the card is then taller than the window, the body gets the height
      # that is left above the buttons and a scroll bar; the buttons stay in view.
      if ($ui.InSqueeze) { return }; $ui.InSqueeze = $true
      try { $bh = [int]$ui.Body.Height; $bw = [int]$ui.Body.Width; $avail = [int]$ui.Card.ClientSize.Height - [int]$ui.Tail.Height; $sh = $bh; $bar = 0
        if ($bh -gt $avail) { $sh = [math]::Max((& $ui.Sc 80), $avail); $bar = [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth + (& $ui.Sc 4) }
        $ui.Scrolls = [bool]$bar
        if ($ui.Scroll.Width -ne ($bw + $bar) -or $ui.Scroll.Height -ne $sh) { $ui.Scroll.Size = New-Object System.Drawing.Size(($bw + $bar), $sh) }
      } catch { $null = $_ } finally { $ui.InSqueeze = $false } }
    $ui.Body.Add_SizeChanged({ & $ui.Squeeze }); $ui.Tail.Add_SizeChanged({ & $ui.Squeeze })
    $ui.Card.Add_SizeChanged({ try { & $ui.Fit } catch { $null = $_ } })
    $ui.Rows = { param([string]$Text, $Font, [int]$W, [int]$LineH, [int]$Most) if (-not $Text) { return 0 }; [math]::Min($Most, [math]::Max(1, [int][math]::Round((& $ui.Meas $Text $Font $W).Height / [math]::Max(1, $LineH)))) }
    $ui.OptPlan = { param($o, [int]$w)
      # Where the parts of one choice go, and how tall it is. The name gets its width first. The two facts stay on the
      # right when the name and they fit on one line; else they go on one line under the summary. The summary, a blocked
      # application's reason and its "What to do" wrap to 2 lines each, then end with "...".
      $pad = & $ui.Sc 16; $x = $pad + (& $ui.Sc 38); $inner = $w - $x - $pad; $gap = & $ui.Sc 12
      $h1 = [System.Windows.Forms.TextRenderer]::MeasureText('Ag', $ui.F.Body).Height; $h2 = [System.Windows.Forms.TextRenderer]::MeasureText('Ag', $ui.F.Small).Height
      $vw = 0; if ($o.Ver) { $vw = [System.Windows.Forms.TextRenderer]::MeasureText([string]$o.Ver, $ui.F.Small).Width }
      $nw = [System.Windows.Forms.TextRenderer]::MeasureText([string]$o.Name, $ui.F.Body).Width
      $rw = 0; foreach ($r in @($o.R1, $o.R2)) { if ($r) { $rw = [math]::Max($rw, [System.Windows.Forms.TextRenderer]::MeasureText([string]$r, $ui.F.SmallB).Width) } }
      $under = [bool]($rw -and -not $o.Off -and ($nw + $vw + $gap + $rw) -gt $inner)
      $tw = $inner; if ($rw -and -not $under) { $tw = $inner - $rw - $gap }
      $s1 = & $ui.Rows ([string]$o.Sub) $(if ($o.Off) { $ui.F.SmallB } else { $ui.F.Small }) $tw $h2 2; $s2 = & $ui.Rows ([string]$o.Sub2) $ui.F.Small $tw $h2 2; $nl = & $ui.Rows ([string]$o.Note) $ui.F.SmallB $tw $h2 2
      $need = $h1 + ($s1 + $s2 + $nl + [int]$under) * $h2
      $hh = [math]::Max((& $ui.Sc 66), ($need + (& $ui.Sc 20)))
      return @{ H = [int]$hh; Pad = $pad; X = $x; Tw = [int]$tw; Rw = $rw; Under = $under; S1 = $s1; S2 = $s2; NL = $nl; H1 = $h1; H2 = $h2; Vw = $vw; Nw = $nw; Y = [int](($hh - $need) / 2) } }
    $ui.PaintOpt = { param($P, $G)
      # One choice: a key (1 to 9), the name and version, the summary, an optional notice, and two facts. An application
      # that cannot run here is not a button: a red cross, the reason, what to do, and the word FAILED.
      try {
        $o = $P.Tag; $w = $P.ClientSize.Width; $h = $P.ClientSize.Height; $G.Clear($ui.C.White)
        $pl = & $ui.OptPlan $o $w; $pad = $pl.Pad; $x = $pl.X; $y = $pl.Y; $h1 = $pl.H1; $h2 = $pl.H2; $tw = $pl.Tw; $rw = $pl.Rw
        $one = 'Left, Top, NoPrefix, SingleLine, EndEllipsis'; $wrap = 'Left, Top, NoPrefix, WordBreak, EndEllipsis, TextBoxControl'
        if ($o.Off) {
          $pn = New-Object System.Drawing.Pen($ui.C.Hair); $G.DrawLine($pn, 0, 0, $w, 0); $pn.Dispose()
          $cp = New-Object System.Drawing.Pen($ui.C.Red, [single](& $ui.Sc 2)); $d = & $ui.Sc 12; $cx = $pad + (& $ui.Sc 6); $cy = [int](($h - $d) / 2)
          $G.DrawLine($cp, $cx, $cy, ($cx + $d), ($cy + $d)); $G.DrawLine($cp, ($cx + $d), $cy, $cx, ($cy + $d)); $cp.Dispose()
        } else {
          $foc = [bool]$P.Focused; $t = $(if ($foc) { & $ui.Sc 2 } else { 1 })
          $pn = New-Object System.Drawing.Pen($(if ($foc) { $ui.C.Navy } else { $ui.C.Edge }), [single]$t); $i = [int]($t / 2); $G.DrawRectangle($pn, $i, $i, ($w - 1 - 2 * $i), ($h - 1 - 2 * $i)); $pn.Dispose()
          $k = & $ui.Sc 24; $ky = [int](($h - $k) / 2); $kp = New-Object System.Drawing.Pen($ui.C.Edge); $G.DrawRectangle($kp, $pad, $ky, $k, $k); $kp.Dispose()
          & $ui.Word $G ([string]$o.Key) $ui.F.SmallB $ui.C.Gray $pad $ky $k $k 'HorizontalCenter, VerticalCenter, NoPrefix, SingleLine'
        }
        $nw = [math]::Max((& $ui.Sc 40), [math]::Min($pl.Nw, ($tw - $pl.Vw)))   # the name first; the version keeps its place after it
        & $ui.Word $G ([string]$o.Name) $ui.F.Body $(if ($o.Off) { $ui.C.Gray } else { $ui.C.Navy }) $x $y $nw $h1 $one
        if ($o.Ver) { & $ui.Word $G ([string]$o.Ver) $ui.F.Small $ui.C.Gray ($x + $nw) $y ([math]::Max(1, ($tw - $nw))) $h1 $one }
        $yy = $y + $h1
        if ($o.Sub) { & $ui.Word $G ([string]$o.Sub) $(if ($o.Off) { $ui.F.SmallB } else { $ui.F.Small }) $(if ($o.Off) { $ui.C.Navy } else { $ui.C.Gray }) $x $yy $tw ($pl.S1 * $h2) $wrap; $yy += $pl.S1 * $h2 }
        if ($o.Sub2) { & $ui.Word $G ([string]$o.Sub2) $ui.F.Small $ui.C.Navy $x $yy $tw ($pl.S2 * $h2) $wrap; $yy += $pl.S2 * $h2 }
        if ($pl.Under) { & $ui.Word $G ((@($o.R1, $o.R2) | Where-Object { $_ }) -join $dot) $ui.F.Small $ui.C.Navy $x $yy $tw $h2 $one; $yy += $h2 }
        if ($o.Note) { & $ui.Word $G ([string]$o.Note) $ui.F.SmallB $ui.C.Navy $x $yy $tw ($pl.NL * $h2) $wrap }
        if ($rw -and -not $pl.Under) {
          $rx = $w - $pad - $rw
          if ($o.R1) { & $ui.Word $G ([string]$o.R1) $(if ($o.Off) { $ui.F.SmallB } else { $ui.F.Small }) $(if ($o.Off) { $ui.C.Red } else { $ui.C.Navy }) $rx ($y + (& $ui.Sc 2)) $rw $h2 'Right, Top, NoPrefix, SingleLine' }
          if ($o.R2) { & $ui.Word $G ([string]$o.R2) $ui.F.Small $ui.C.Gray $rx ($y + $h1) $rw $h2 'Right, Top, NoPrefix, SingleLine' }
        }
      } catch { $null = $_ } }
    $ui.FillOpts = { param($List)
      $ui.Trash = @($ui.Trash) + @($ui.Opts.Controls); $ui.Opts.Controls.Clear()   # old choices are disposed after the window has closed: a button is never disposed inside its own Click
      $n = 0
      foreach ($o in @($List | Where-Object { $_ })) {
        $said = (@($o.Name, $o.Ver, $o.Sub, $o.Sub2, $o.Note, $o.R1, $o.R2) | Where-Object { $_ }) -join '. '
        if ($o.Off) { $c = New-Object System.Windows.Forms.Panel; $c.AccessibleRole = 'StaticText'; $c.AccessibleName = $said }
        else {
          $n++; $o.Key = $n
          $c = New-Object System.Windows.Forms.Button; $c.FlatStyle = 'Flat'; $c.FlatAppearance.BorderSize = 0; $c.UseVisualStyleBackColor = $false; $c.Text = ''; $c.AccessibleName = ('Choice ' + $n + ': ' + $said)
          $c.Add_Click({ if ($ui.OnOpt -and -not $ui.Busy -and (& $ui.Settled)) { & $ui.OnOpt ([int]$this.Tag.Index) } }); $c.Add_GotFocus({ $this.Invalidate() }); $c.Add_LostFocus({ $this.Invalidate() })
        }
        $c.Tag = $o; $c.BackColor = $ui.C.White; $c.Margin = (& $ui.Pad 0 0 0 (& $ui.Sc 8))
        $hh = & $ui.Sc $(if ($o.Note -or $o.Sub2) { 86 } else { 66 }); try { $hh = (& $ui.OptPlan $o $ui.ContentW).H } catch { $null = $_ }   # as tall as its lines, 66 at least
        $c.Size = New-Object System.Drawing.Size($ui.ContentW, $hh)
        $c.Add_Paint({ & $ui.PaintOpt $this $_.Graphics })
        [void]$ui.Opts.Controls.Add($c)
      } }
    $ui.Measure = { param([string]$Card)
      # The numbers for RowBad and EdgeBad, from the real layout (screen pixels).
      $out = @(); $sr = { param($C) $C.RectangleToScreen($C.ClientRectangle) }
      foreach ($row in 'Top', 'FieldRow', 'TestRow') {
        $ps = @(& $ui.RowParts $row); if ($ps.Count -lt 2 -or -not $ps[0].Parent.Visible) { continue }   # the parts AlignRow aligns (R5 review: one rule for both)
        $out += & $ui.RowBad $Card $row @($ps | ForEach-Object { $rr = & $sr $_; @{ N = (& $ui.NameOf $_); Top = $rr.Top; H = $rr.Height; Line = $rr.Top - $_.Margin.Top; Kind = $(if ($ui.Boxes -contains $_) { 'box' } elseif ($_ -is [System.Windows.Forms.Button] -and $_.FlatAppearance.BorderSize -gt 0) { 'button' } else { 'other' }) } })
      }
      if (-not $ui.RecOn) {
        $tx = { param($C) (& $sr $C).Left + (& $ui.Ink $C) }   # where its ink starts (text, edge or drawing), measured
        $es = @()
        if ($ui.Kick.Visible) { $es += @{ N = 'Kick'; X = (& $tx $ui.Kick) } }
        if ($ui.TickP.Visible) { $es += @{ N = 'TickP'; X = (& $tx $ui.TickP) } } elseif ($ui.Sent.Visible -and $ui.Sent.Text) { $es += @{ N = 'Sent'; X = (& $tx $ui.Sent) } }
        foreach ($l in @(@($ui.P) + @($ui.Rest, $ui.Close, $ui.StepName, $ui.LastLog, $ui.FieldL, $ui.Note, $ui.Help, $ui.Foot, $ui.TestL))) { if ($l.Visible -and $l.Text) { $es += @{ N = (& $ui.NameOf $l); X = (& $tx $l) } } }
        if ($ui.Steps.Visible -and $ui.NumWide) { $es += @{ N = 'Steps'; X = (& $tx $ui.NumWide) } }   # the widest number of the numbered list
        if ($ui.ErrBox.Visible) { $es += @{ N = 'ErrBox'; X = (& $sr $ui.ErrBox).Left } }
        $k1 = @($ui.LinkRow.Controls | Where-Object { $_.Visible })[0]; if ($k1) { $es += @{ N = (& $ui.NameOf $k1); X = (& $tx $k1); D = ('link ink ' + (& $ui.Ink $k1) + ', width ' + $k1.Width + ', margin ' + $k1.Margin.Left + ', row margin ' + $ui.LinkRow.Margin.Left) } }
        $o1 = @($ui.Opts.Controls | Where-Object { $_.Visible })[0]; if ($o1) { $es += @{ N = 'choice 1'; X = (& $sr $o1).Left } }
        $b1 = @($ui.B | Where-Object { $_.Visible })[0]; if ($b1) { $es += @{ N = (& $ui.NameOf $b1); X = (& $tx $b1) } }
        $out += & $ui.EdgeBad $Card $es
      }
      return $out }
    $ui.Scale = {
      # The scaling facts, numbers only (R24: the screen dpi said 100 % while every size was 1.5 x). DeviceDpi exists from .NET 4.7.
      try { $f = $ui.Form; $dd = 'n/a'; try { $pp = $f.GetType().GetProperty('DeviceDpi'); if ($pp) { $dd = [string]$pp.GetValue($f, $null) } } catch { $null = $_ }
        $as = $f.CurrentAutoScaleDimensions; $sn = [System.Windows.Forms.Screen]::FromControl($f)
        # The process dpi awareness, read from Windows Forms itself (its internal DpiHelper, .NET 4.7+); no native call: that
        # would need C# compiled on the work computer. PerMonitorV2 with dpiX 96 and autoScale 144 is the R24 case.
        $aw = 'n/a'; try { $dh = $f.GetType().Assembly.GetType('System.Windows.Forms.DpiHelper'); if ($dh) { $bf = [System.Reflection.BindingFlags]'NonPublic, Public, Static'; $pm = $dh.GetProperty('IsPerMonitorV2Awareness', $bf)
            if ($pm) { $aw = $(if ([bool]$pm.GetValue($null, $null)) { 'PerMonitorV2' } else { 'not-PerMonitorV2' }) } } } catch { $null = $_ }
        $sd = $f.AutoScaleDimensions; $rd = 'n/a'; try { if ($script:native -and $f.IsHandleCreated) { $rd = [string][Rade.Native]::GetDpiForWindow($f.Handle) } } catch { $null = $_ }
        $lg = $(if ($ui.Logo) { [string]$ui.Logo.Width + 'x' + $ui.Logo.Height } else { 'n/a' }); $b1 = @($ui.B | Where-Object { $_.Visible })[0]; $bt = $(if ($b1) { [string]$b1.Width + 'x' + $b1.Height } else { 'n/a' })
        return ('SCALE dpiX=' + [int]$ui.ScreenDpi + ' deviceDpi=' + $dd + ' mode=' + [string]$f.AutoScaleMode + ' asd=' + [int]$sd.Width + 'x' + [int]$sd.Height + ' autoScale=' + [int]$as.Width + 'x' + [int]$as.Height + ' font=' + [int]$f.Font.Height + ' fontPt=' + $f.Font.SizeInPoints + ' fontScale=' + $ui.FontK + ' ctlScale=' + [math]::Round($ui.Dpi / 96.0, 2) + ' realDpi=' + $rd + ' aware=' + $aw + ' screen=' + $sn.Bounds.Width + 'x' + $sn.Bounds.Height +
          ' work=' + $sn.WorkingArea.Width + 'x' + $sn.WorkingArea.Height + ' client=' + $f.ClientSize.Width + 'x' + $f.ClientSize.Height + ' state=' + [string]$f.WindowState + ' logo=' + $lg + ' btn=' + $bt + ' shown=' + $(if ($ui.ShownAt) { $ui.ShownAt } else { 'n/a' }) + ' placed=' + $ui.Placed + ' lastClose=' + $(if ($ui.LastClose) { $ui.LastClose } else { 'n/a' }))
      } catch { return ('SCALE could not be read: ' + (ConvertTo-Masked ([string]$_.Exception.Message))) } }
    $ui.LayLine = {
      & $ui.Check
      $pct = [int][math]::Round($ui.Dpi / 96.0 * 100); $sp = [int][math]::Round($ui.ScreenDpi / 96.0 * 100)   # the form's scale (the one source); the screen dpi beside it when it differs
      $size = [string]$ui.Form.ClientSize.Width + ' x ' + $ui.Form.ClientSize.Height + ' at ' + [string]$pct + ' %' + $(if ($sp -ne $pct) { ' (the form auto-scale; the screen dpi says ' + $sp + ' %)' } else { '' })
      $sc = $(if ($ui.LayScroll.Count) { '; the text scrolls on: ' + ((@($ui.LayScroll.Keys) | Sort-Object) -join ', ') } else { '' })
      if ($ui.LayBad.Count) { return ('Layout self-check: ' + $ui.LayBad.Count + ' defects in ' + $ui.LayCards.Count + ' cards (' + $size + ')' + $sc + "`r`n" + (& $ui.Scale) + "`r`n" + (@($ui.LayBad) -join "`r`n")) }
      return ('Layout self-check: PASS layout, ' + $ui.LayCards.Count + ' cards (' + $size + ')' + $sc + "`r`n" + (& $ui.Scale)) }
    $ui.Show = { param($C, [string]$Text) $C.Text = $Text; $C.Visible = [bool]$Text }
    $ui.SetCard = { param($c)
      # Shows one card. $c names the parts: View, Light ('you' = yellow, 'bad' = dark red), Kicker, Sentence, Tick, P (up to 4
      # paragraphs), Options + OnOption, Lines (guide lines, in order: numbered ones in the table, others after it), StepRow, Field (Label, Text, Name, Button, Do, Max), Err, Links, Note, Help, Close (the hand card's closing line),
      # Buttons (Text, Kind, Do, Apart), Foot, Test, Right, Back, NoAccept, Focus.
      & $ui.Check   # the card that goes away (test rounds only)
      $ui.Hot = $null; $ui.Down = $null   # no hover or pressed state is carried over (R4 review)
      if ($ui.RecOn -and ($c.Light -or $c.View -eq 'done')) { $ui.RecOn = $false; $ui.Rec.Visible = $false; $ui.Card.Visible = $true; $ui.RecB.Visible = $true }   # a card that needs you closes the Record
      $ui.View = [string]$c.View; $ui.Card.SuspendLayout()
      $ui.Light.BackColor = $(if ($c.Light -eq 'you') { $ui.C.Yellow } elseif ($c.Light -eq 'bad') { $ui.C.Red } else { $ui.C.White })
      $ui.Light.AccessibleName = 'Status light: ' + $(if ($c.Light -eq 'you') { 'RADE is waiting for you' } elseif ($c.Light -eq 'bad') { 'failed' } else { 'off' })
      & $ui.Show $ui.Kick ([string]$c.Kicker).ToUpperInvariant()
      $ui.SentRaw = [string]$c.Sentence; $ui.Sent.Text = $ui.SentRaw; $ui.TickP.Visible = [bool]$c.Tick
      $ps = @($c.P | Where-Object { $_ }); for ($k = 0; $k -lt 4; $k++) { & $ui.Show $ui.P[$k] $(if ($k -lt $ps.Count) { [string]$ps[$k] } else { '' }) }
      $ui.OnOpt = $c.OnOption; & $ui.FillOpts $c.Options; $ui.Opts.Visible = [bool]$ui.Opts.Controls.Count
      & $ui.SetSteps $c.Lines
      $ui.StepRow.Visible = [bool]$c.StepRow; $ui.LastLog.Visible = [bool]$c.StepRow; if ($c.StepRow) { $ui.LastLog.Text = '' }
      $ui.FieldRow.Visible = [bool]$c.Field; $ui.FieldDo = $null
      if ($c.Field) { $ui.FieldL.Text = [string]$c.Field.Label; $ui.Field.Text = [string]$c.Field.Text; $ui.Field.AccessibleName = [string]$c.Field.Name; $ui.FieldB.Visible = [bool]$c.Field.Button; $ui.FieldBOn = [bool]$c.Field.Button; $ui.FieldB.Text = [string]$c.Field.Button; $ui.FieldDo = $c.Field.Act; $ui.Field.MaxLength = $(if ($c.Field.Max) { [int]$c.Field.Max } else { 32767 }); & $ui.FitRow }
      $ui.ErrRow.Visible = [bool]$c.Err; if ($c.Err) { $ui.ErrBox.Text = '' }
      $ui.LinkRow.Visible = [bool]($c.Links -or $c.PageLink); $ui.CopyPathB.Visible = [bool]$c.Links; $ui.ShowFileB.Visible = [bool]$c.Links; $ui.PageB.Visible = [bool]$c.PageLink
      & $ui.Show $ui.Note ([string]$c.Note); & $ui.Show $ui.Help ([string]$c.Help); & $ui.Show $ui.Foot ([string]$c.Foot); & $ui.Show $ui.Close ([string]$c.Close)
      $bm = & $ui.Sc $(if ($c.Close) { $ui.Z.G2 - $ui.Z.M } else { $ui.Z.G4 - $ui.Z.M }); $bn = $ui.BtnRow.Margin; if ($bn.Top -ne $bm) { $ui.BtnRow.Margin = New-Object System.Windows.Forms.Padding($bn.Left, $bm, $bn.Right, $bn.Bottom) }   # 8 under the closing line, else 16
      $bs = @($c.Buttons | Where-Object { $_ }); $ui.Acts = @(); $first = $null; $accept = $null; $ui.BOn = @($false) * 5; $ui.BApart = @($false) * 5; $ui.Always = @($false) * 5
      for ($k = 0; $k -lt 5; $k++) {
        $b = $ui.B[$k]
        if ($k -lt $bs.Count) {
          $b.Text = [string]$bs[$k].Text; & $ui.Style $b ([string]$bs[$k].Kind); $b.Visible = $true; $ui.Acts += $bs[$k].Act; $ui.BOn[$k] = $true; $ui.BApart[$k] = [bool]$bs[$k].Apart; $ui.Always[$k] = [bool]$bs[$k].Always
          if ($b.Enabled -and -not $first) { $first = $b }; if ($b.Enabled -and -not $accept -and $bs[$k].Kind -eq 'primary') { $accept = $b }
        } else { $b.Visible = $false; $ui.Acts += $null }
      }
      & $ui.Apart
      $ui.BtnRow.Visible = [bool]$bs.Count
      $ui.TestRow.Visible = [bool]$c.Test
      $ui.Form.AcceptButton = $(if ($c.NoAccept) { $null } else { $accept })   # Enter = the primary button, except on a hand step
      $ui.Back = $c.Back; $ui.BackB.Visible = ([bool]$c.Back -and -not $ui.RecOn); $ui.RightL.Text = [string]$c.Right
      & $ui.FitSent; & $ui.FitEdges; & $ui.AlignRows
      $ui.Card.ResumeLayout(); try { $ui.Card.PerformLayout() } catch { $null = $_ }
      try { $ui.Scroll.AutoScrollPosition = New-Object System.Drawing.Point(0, 0) } catch { $null = $_ }; & $ui.Squeeze   # a new card starts at its top
      $f = $null
      if ($c.Focus -eq 'field') { $f = $ui.Field } elseif ($c.Focus -eq 'fieldbutton') { $f = $ui.FieldB } elseif ($c.Focus -eq 'err') { $f = $ui.ErrBox }
      elseif ($ui.Opts.Controls.Count) { foreach ($o in @($ui.Opts.Controls)) { if (-not $o.Tag.Off) { $f = $o; break } } }
      if (-not $f) { $f = $accept }; if (-not $f) { $f = $first }; if (-not $f) { $f = $ui.RecB }
      if (-not $ui.RecOn) { try { [void]$f.Focus() } catch { $null = $_ } }
      # The guard counts from here, when the card is built and the person can see it (M2 review): a click that waited in the
      # queue while the card was built comes in during this DoEvents, inside the guard, and is dropped.
      $ui.CardAt = $ui.Clock.Elapsed.TotalMilliseconds
      [System.Windows.Forms.Application]::DoEvents() }
    $ui.ToFront = { try { if ([string]$ui.Form.WindowState -eq 'Minimized') { $ui.Form.WindowState = 'Normal' }; $ui.Form.TopMost = $true; $ui.Form.Activate(); $ui.Form.TopMost = $false } catch { $null = $_ } }
    $ui.Say1 = { param([string]$Text) $ui.Note.Text = $Text; $ui.Note.Visible = [bool]$Text }   # one gray line under the card's box or buttons

    # ---- When the window opens: the Local checks of every application in the paste run once (base checks before Choose).
    # An application with a FAILED one cannot be chosen. A newer version on the RADE page is read here too (test and deploy).
    $ui.RunBase = {
      $ui.BaseIds = @(); foreach ($a in $apps) { foreach ($id in @($a.Checks)) { $d = Get-CheckDef $id; if ($d -and $d.Group -eq 'Local' -and $d.Kind -eq 'auto' -and $ui.BaseIds -notcontains $id) { $ui.BaseIds += $id } } }
      $cache = Read-CheckCache; $bp = Get-BasePath; $site = Get-SiteUrl $bp; $i = 0; $ui.Busy = $true; $ui.BaseRes = @{}
      try {
        foreach ($id in $ui.BaseIds) {
          if ($ui.Form.IsDisposed -or $script:closing) { return }
          $i++; $d = Get-CheckDef $id; $ui.RightL.Text = 'Check ' + $i + ' of ' + $ui.BaseIds.Count
          $r = Get-CheckToRun $d $cache $bp $site $false
          if (-not $r) { $r = Invoke-Check $d $bp $site { [System.Windows.Forms.Application]::DoEvents() } }
          $ui.BaseRes[$id] = $r
        }
        # One read per application (4 s at most each); after one slow read the others are not tried.
        $slow = $false
        for ($j = 0; $j -lt $apps.Count; $j++) {
          if ($slow -or $ui.Newer.ContainsKey($j)) { continue }
          $t0 = Get-Date; $script:app = $apps[$j]; $ui.Newer[$j] = [string](Get-NewerVersion); if (((Get-Date) - $t0).TotalSeconds -gt 3) { $slow = $true }
        }
        if (-not $ui.ContainsKey('NewRound')) { $ui.NewRound = [string](Get-NewerRound) }
      } finally { $ui.Busy = $false; Select-App 0 } }
    $ui.VNoApps = {
      # R28: a paste that lists no application (a manifest or build fault): say so, with what to do, instead of an empty list.
      & $ui.SetCard @{ View = 'noapps'; Light = 'bad'; Kicker = 'Nothing to choose'; Sentence = 'No application is listed in this paste.'
        P = @('This paste has nothing that RADE can install or run.', 'What to do: close this window and copy the paste again from the RADE page. If it is still empty, ask in the Teams channel.'); Help = (Get-HelpLine)
        Buttons = @(@{ Text = 'Close'; Kind = 'primary'; Act = { $ui.Form.Close() } }) } }
    $ui.VBootErr = { param([string]$Why)
      # R28: the checks that run when the window opens stopped with an error: a card, not a blank window.
      & $ui.SetCard @{ View = 'booterr'; Light = 'bad'; Kicker = 'Stopped'; Sentence = 'RADE could not check this computer.'
        P = @($Why, 'Nothing was changed.', 'What to do: select "Try again". If it stops again, ask in the Teams channel.'); Help = (Get-HelpLine)
        Buttons = @(@{ Text = 'Try again'; Kind = 'primary'; Act = { & $ui.Boot } }, @{ Text = 'Close'; Act = { $ui.Form.Close() } }) }
      & $ui.ToFront }
    $ui.VChoose = {
      if (@($apps).Count -eq 0) { & $ui.VNoApps; return }
      Select-App 0; $ui.Picked = $false; $ui.Plan = $null; $ui.AppL.Text = ''; $list = @(); $dep = $false; $ui.Blocked = @{}; $ui.BlockedFix = @{}
      for ($j = 0; $j -lt $apps.Count; $j++) { foreach ($id in @($apps[$j].Checks)) { $r = $ui.BaseRes[$id]; if ($r -and $r.State -eq 'FAILED') { $ui.Blocked[$j] = ((Get-CheckDef $id).Name + ': ' + $r.Detail); $ui.BlockedFix[$j] = $(if ($r.Fix) { 'What to do: ' + $r.Fix } else { '' }); break } } }
      for ($j = 0; $j -lt $apps.Count; $j++) {
        $a = $apps[$j]; if ([string]$a.Mode -eq 'deploy') { $dep = $true }
        if ($ui.Blocked.ContainsKey($j)) { $list += @{ Off = $true; Index = $j; Name = [string]$a.Name; Ver = $(if ($a.Version) { ' ' + $a.Version } else { '' }); Sub = [string]$ui.Blocked[$j]; Sub2 = [string]$ui.BlockedFix[$j]; R1 = 'FAILED' }; continue }
        $f = Get-AppFact $a $ui.Hist
        $list += @{ Index = $j; Name = [string]$a.Name; Ver = $(if ($a.Version) { ' ' + $a.Version } else { '' }); Sub = [string]$a.Summary; R1 = $f.Steps; R2 = $f.Installed
          Note = $(if ($ui.Newer[$j]) { 'Version ' + $ui.Newer[$j] + ' is on the RADE page. This paste installs ' + $a.Version + '.' } else { '' }) }
      }
      $nr = [string]$ui.NewRound
      & $ui.SetCard @{ View = 'choose'; Sentence = $(if ($dep) { 'Which application do you want to install?' } else { 'Which application do you want to run?' })
        P = @($(if ($nr) { 'A newer round, ' + $nr + ', is in the repository. Close this window and run ' + $nr + ' instead.' } else { '' })); Options = $list; OnOption = { param($j) & $ui.Pick $j }
        PageLink = [bool](@($ui.Newer.Values | Where-Object { $_ }).Count)
        Buttons = @($(if ($ui.Blocked.Count) { @{ Text = 'Check this computer again'; Act = { & $ui.Boot } } } else { $null })); Foot = $(if ($dep) { '' } else { Get-LastRoundText $ui.Hist }) } }
    $ui.Boot = {
      & $ui.SetCard @{ View = 'boot'; Sentence = 'Checking this computer.'; P = @('This takes a few seconds. Nothing is changed.') }
      try { & $ui.RunBase } catch { if (-not ($ui.Form.IsDisposed -or $script:closing)) { & $ui.VBootErr (ConvertTo-Masked ([string]$_.Exception.Message)) }; return }
      if (-not ($ui.Form.IsDisposed -or $script:closing)) { & $ui.VChoose } }
    $ui.InitSel = { $ui.Sel = @{}; foreach ($k in $script:appSteps) { $ui.Sel[[int]$k] = [bool](Get-StepDefault $k) }; $ui.Clean = $true; $ui.StepState = @{} }
    $ui.Pick = { param([int]$J)
      Select-App $J; $ui.Picked = $true
      # The base checks are not run twice, except the ones whose answer can change at any time ($checkNoSave: Word open, disk, write).
      foreach ($id in $script:appChecks) { if ($ui.BaseRes.ContainsKey($id) -and $checkNoSave -notcontains $id -and $ui.BaseRes[$id].State -in 'PASSED', 'WARNING') { $script:checkResults[$id] = $ui.BaseRes[$id] } }
      $ui.AppL.Text = $dot.TrimStart() + $script:app.Name + $(if ($script:app.Version) { ' ' + $script:app.Version } else { '' })
      & $ui.InitSel
      $e = $null; if (Test-Deploy) { $e = (Read-Installed (Get-InstalledKey $script:app)) }
      if ($e -and $e.installed) { & $ui.VMaint $e.installed } else { & $ui.Checks $false } }
    $ui.VMaint = { param($Inst)
      # Maintenance (the Administrator, 2026-11-14; docs/engine.md "Maintenance run types"): shown for an application that is
      # installed. Install works ("Update to <version>" or "Repair"). Diagnose, Back up, Restore and Uninstall have no engine
      # function yet: they are shown off, Uninstall set apart.
      $on = ''; try { $on = $dot + 'installed ' + ([datetime][string]$Inst.at).ToString('d MMM yy', [System.Globalization.CultureInfo]::InvariantCulture) } catch { $null = $_ }
      $verb = 'Install ' + $script:app.Version
      try { $c = ([version][string]$script:app.Version).CompareTo([version][string]$Inst.version); if ($c -gt 0) { $verb = 'Update to ' + $script:app.Version } elseif ($c -eq 0) { $verb = 'Repair' } } catch { $null = $_ }
      & $ui.SetCard @{ View = 'maint'; Kicker = ($script:app.Name + ' ' + $Inst.version + $on); Sentence = 'Maintenance'
        P = @($(if ($verb -eq 'Repair') { 'Repair adds what is missing and keeps your data.' } else { $verb + ' adds what is missing and keeps your data.' }))
        Note = 'Diagnose, Back up, Restore and Uninstall are not in this version of RADE yet.'
        Buttons = @(@{ Text = $verb; Kind = 'primary'; Act = { & $ui.Checks $false } }, @{ Text = 'Diagnose'; Kind = 'off' }, @{ Text = 'Back up'; Kind = 'off' }, @{ Text = 'Restore'; Kind = 'off' }, @{ Text = 'Uninstall'; Kind = 'dangeroff'; Apart = $true })
        Back = { & $ui.VChoose } } }
    $ui.NeedSite = { [bool](@($script:appChecks | Where-Object { $_ -in 'net-site', 'site-rights' }).Count) }
    $ui.VSite = {
      $v = Get-SiteUrl (Get-BasePath); if (-not $v) { $v = $sitePrefix }   # PFM 14 Nov 26: the box starts with the DAF SharePoint address
      & $ui.SetCard @{ View = 'site'; Sentence = 'Which site does the application go to?'; P = @('RADE writes to this SharePoint site. The address is saved for next time.')
        Field = @{ Label = 'Site address'; Text = $v; Name = 'Site address, starts with https://' }; Focus = 'field'
        Buttons = @(@{ Text = 'Continue'; Kind = 'primary'; Act = { & $ui.SaveSite } }); Back = { & $ui.VChoose } }
      try { $ui.Field.SelectionStart = $ui.Field.Text.Length; $ui.Field.SelectionLength = 0 } catch { $null = $_ } }
    $ui.SaveSite = {
      $v = $ui.Field.Text.Trim()
      if (-not (Test-SiteUrl $v)) { & $ui.Say1 ('The address must look like ' + $sitePrefix + 'name'); return }
      try { $null = Save-SiteUrl (Get-BasePath) $v } catch { $null = $_ }
      foreach ($id in 'net-site', 'site-rights') { if ($script:checkResults.ContainsKey($id)) { $script:checkResults.Remove($id) } }
      & $ui.Checks $false }
    $ui.Checks = { param([bool]$Force)
      # The chosen application's checks that run on their own. A check with a result from this window is kept unless $Force
      # ("Run checks again"); a saved result (RADE\Config\rade-checks.json) is reused as before.
      $bp = Get-BasePath; $site = Get-SiteUrl $bp
      if ((& $ui.NeedSite) -and -not (Test-SiteUrl $site)) { & $ui.VSite; return }
      $ids = @($script:appChecks); $cache = Read-CheckCache; $script:savedWhy = @{}
      $ui.Cancel = $false
      & $ui.SetCard @{ View = 'checking'; Sentence = 'Checking this computer and your access.'; P = @('Read-only. Nothing is changed.'); Buttons = @(@{ Text = 'Cancel'; Always = $true; Act = { & $ui.CancelChecks } }) }
      & $ui.SetBar 'all' 0 $true; $ui.Bars['all'].Fill = $ui.C.Blue; $ui.Busy = $true
      try {
        for ($i = 0; $i -lt $ids.Count; $i++) {
          if ($ui.Form.IsDisposed -or $script:closing) { return }
          if ($ui.Cancel) { break }
          $id = $ids[$i]; $d = Get-CheckDef $id; $have = $script:checkResults[$id]
          if ($d.Kind -ne 'auto') { if (-not $have) { $sv = Get-CheckToRun $d $cache $bp $site $false; if ($sv) { $script:checkResults[$id] = $sv } }; continue }   # a sign-in or look check: its saved result, else it asks later
          if ($have -and -not $Force) { continue }
          $sv = Get-CheckToRun $d $cache $bp $site $Force
          if ($sv) { $script:checkResults[$id] = $sv; continue }
          $ui.P[0].Text = [string]$d.Name; $ui.RightL.Text = 'Check ' + ($i + 1) + ' of ' + $ids.Count; & $ui.SetBar 'all' ($i / [math]::Max(1, $ids.Count)) $true
          [System.Windows.Forms.Application]::DoEvents()
          $script:checkResults[$id] = Invoke-Check $d $bp $site { [System.Windows.Forms.Application]::DoEvents() }
          if ($ui.BaseRes.ContainsKey($id)) { $ui.BaseRes[$id] = $script:checkResults[$id] }   # Choose shows the newest result of a base check
        }
      } finally { $null = Save-CheckCache $script:checkResults $bp $site; $ui.Busy = $false; & $ui.SetBar 'all' 0 $false }
      if ($ui.Cancel) { $ui.Cancel = $false; & $ui.VChoose; return }   # Cancel: back to Choose, nothing changed (a check that ran is kept)
      & $ui.Next }
    $ui.CancelChecks = {
      # The check that is running ends first (a sign-in window cannot be closed from here); then RADE goes back to Choose.
      $ui.Cancel = $true; & $ui.Say1 'RADE stops after the check that is running.' }
    $ui.Next = {
      # One question at a time: the first FAILED check, else the first check that waits for you, else the plan.
      if ($ui.Form.IsDisposed -or $script:closing) { return }
      $ids = @($script:appChecks); $fails = @(); $needs = @()
      for ($i = 0; $i -lt $ids.Count; $i++) { $r = $script:checkResults[$ids[$i]]; if (-not $r -or $r.State -in 'NOT RUN', 'RUNNING') { $needs += $i } elseif ($r.State -eq 'FAILED') { $fails += $i } }
      if ($fails.Count) { & $ui.VFail $fails[0] $fails.Count; return }
      if ($needs.Count) { & $ui.VNeed $needs[0]; return }
      & $ui.VReady }
    $ui.VFail = { param([int]$I, [int]$Count)
      $ids = @($script:appChecks); $ui.CurId = [string]$ids[$I]; $d = Get-CheckDef $ids[$I]; $r = $script:checkResults[$ids[$I]]
      # A check that runs on its own: "Run checks again". A sign-in or look-and-answer check: its own button, as on the card that asks for it.
      $again = $(if ($d.Kind -eq 'signin') { @{ Text = 'Sign in and check site rights'; Kind = 'primary'; Act = { & $ui.One } } } elseif ($d.Kind -eq 'guide') { @{ Text = 'Check Power Automate'; Kind = 'primary'; Act = { & $ui.One } } } else { @{ Text = 'Run checks again'; Kind = 'primary'; Act = { & $ui.Checks $true } } })
      $ok = @($ids | Where-Object { $script:checkResults[$_] -and $script:checkResults[$_].State -in 'PASSED', 'WARNING' }).Count
      & $ui.SetCard @{ View = 'fail'; Light = 'bad'; Kicker = ('Check ' + ($I + 1) + ' of ' + $ids.Count + $dot + 'FAILED'); Sentence = $(if ($Count -eq 1) { 'One check failed.' } else { [string]$Count + ' checks failed. This is the first.' })
        P = @([string]$d.Name, [string]$r.Detail, $(if ($r.Fix) { 'What to do: ' + $r.Fix } else { '' }))
        Buttons = @($again, $(if (& $ui.NeedSite) { @{ Text = 'Change the site address'; Act = { & $ui.VSite } } } else { $null }))
        Foot = ([string]$ok + ' of ' + $ids.Count + ' checks passed. RADE changes nothing until every check passes.'); Back = { & $ui.VChoose } }
      & $ui.ToFront }
    $ui.VNeed = { param([int]$I)
      $ids = @($script:appChecks); $ui.CurId = [string]$ids[$I]; $d = Get-CheckDef $ui.CurId; $r = $script:checkResults[$ui.CurId]
      $how = $(if ($d.Kind -eq 'signin') { 'CAC sign-in, read-only' } elseif ($d.Kind -eq 'guide') { 'You look and answer, read-only' } else { 'Not run yet' })
      $text = $(if ($d.Kind -eq 'signin') { 'Sign in and check site rights' } elseif ($d.Kind -eq 'guide') { 'Check Power Automate' } else { 'Run checks again' })
      & $ui.SetCard @{ View = 'need'; Light = 'you'; Kicker = ('Check ' + ($I + 1) + ' of ' + $ids.Count + $dot + 'your turn'); Sentence = 'One check needs you.'
        P = @([string]$d.Name, $(if ($r -and $r.Detail) { [string]$r.Detail } elseif ($script:savedWhy[$ui.CurId]) { [string]$script:savedWhy[$ui.CurId] } else { $how }), $(if ($r -and $r.Fix) { 'What to do: ' + $r.Fix } else { '' }))
        Buttons = @(@{ Text = $text; Kind = 'primary'; Act = $(if ($d.Kind -eq 'auto') { { & $ui.Checks $true } } else { { & $ui.One } }) }); Back = { & $ui.VChoose } } }
    $ui.One = {
      # A check that needs you: the CAC sign-in opens its own window; the look-and-answer check shows a hand card.
      $d = Get-CheckDef $ui.CurId; $bp = Get-BasePath; $site = Get-SiteUrl $bp
      $ui.Cancel = $false
      & $ui.SetCard @{ View = 'checking'; Light = 'you'; Sentence = $(if ($d.Kind -eq 'signin') { 'Waiting for your sign-in.' } else { 'Checking.' }); P = @([string]$d.Name); Buttons = @(@{ Text = 'Cancel'; Always = $true; Act = { & $ui.CancelChecks } }) }
      $ui.Busy = $true
      try { $script:checkResults[$ui.CurId] = Invoke-Check $d $bp $site { [System.Windows.Forms.Application]::DoEvents() } }
      finally { $null = Save-CheckCache $script:checkResults $bp $site; $ui.Busy = $false }
      & $ui.ToFront; if ($ui.Cancel) { $ui.Cancel = $false; & $ui.VChoose; return }; & $ui.Next }
    $ui.VReady = {
      # The plan in three lines; the detail (each file, each step's box) is in the Record.
      if ($ui.Form.IsDisposed -or $script:closing) { return }
      $plan = Get-RoundPlan; $ui.Plan = $plan; $dep = Test-Deploy
      if (-not $plan.Found) {
        & $ui.SetCard @{ View = 'nodrive'; Light = 'bad'; Sentence = 'Your OneDrive folder was not found.'; P = @('RADE saves its files in your OneDrive folder.', 'What to do: open OneDrive from the Start menu and sign in. Then select "Look again".')
          Buttons = @(@{ Text = 'Look again'; Kind = 'primary'; Act = { & $ui.VReady } }); Back = { & $ui.VChoose } }
        return }
      $new = @($plan.Lines | Where-Object { $_ -match '^  New ' }).Count; $rep = @($plan.Lines | Where-Object { $_ -match '^  Replace ' }).Count
      $rec = 0; $in = $false; foreach ($l in $plan.Lines) { if ($l -match '^Clean-up \(runs first') { $in = $true } elseif ($in) { if ($l) { $rec++ } else { $in = $false } } }
      $n = [int][bool]($cleanup.Count -and $ui.Clean); $est = 0; $you = ''; $done = 0   # Clean-up counts as a step, as in the run's "Step k of n"
      foreach ($k in $script:appSteps) {
        if (-not $ui.Sel[[int]$k]) { if ($dep -and -not [bool]$steps[$k].Optional -and -not (Get-StepDefault $k)) { $done++ }; continue }
        $n++; $est += (Get-StepWeight $ui.Hist $steps[$k]).Seconds; if (-not $you -and $steps[$k].Kind -eq 'guide') { $you = 'Step ' + $n + ' needs you.' }
      }
      $ids = @($script:appChecks); $warn = @($ids | Where-Object { $script:checkResults[$_].State -eq 'WARNING' })
      $w1 = ''; if ($warn.Count) { $w1 = 'Warning: ' + (Get-CheckDef $warn[0]).Name + '. ' + $script:checkResults[$warn[0]].Detail + $(if ($warn.Count -gt 1) { ' (and ' + ($warn.Count - 1) + ' more in the Record)' } else { '' }) }
      # The saved site, by name, before anything is written (the Administrator, 2026-11-15): the steps use it with no
      # question, so a wrong site must show here. On the card only: a card's text never enters the log or the report.
      $siteName = ''; if ((& $ui.NeedSite) -and (Test-SiteUrl (Get-SiteUrl (Get-BasePath)))) { $siteName = ([string](Get-SiteUrl (Get-BasePath))).TrimEnd('/') -replace '^.*/', '' }
      # Start (R28, the Administrator, 2026-11-17): for an application that is installed and has a start script in its local folder, after the
      # checks pass. It is the main button when the installed version is this paste's version; when this paste is newer, Install stays
      # the main button.
      $startB = $null; $startPrimary = $false
      if ($dep -and [string]$script:app.Start) {
        $inst = Read-Installed (Get-InstalledKey $script:app)
        if ($inst -and $inst.installed -and (Get-StartPath)) { $startPrimary = ([string]$inst.installed.version -eq [string]$script:app.Version); $startB = @{ Text = 'Start ' + $script:app.Name; Kind = $(if ($startPrimary) { 'primary' } else { '' }); Act = { & $ui.StartApp } } }
      }
      & $ui.SetCard @{ View = 'ready'
        Kicker = $(if ($warn.Count) { [string]($ids.Count - $warn.Count) + ' checks passed' + $dot + $warn.Count + $(if ($warn.Count -eq 1) { ' warning' } else { ' warnings' }) } else { 'All ' + $ids.Count + ' checks passed' })
        Sentence = $(if ($dep) { 'Ready to install ' + $script:app.Name + ' ' + $script:app.Version + '.' } else { 'Ready to run round ' + $round + '.' })
        P = @(('Writes to ' + $plan.Shown + ': ' + $new + ' new files, ' + $rep + ' replaced, ' + $rec + ' moved to the Recycle Bin.'),
          ([string]$n + $(if ($n -eq 1) { ' step' } else { ' steps' }) + ', about ' + [math]::Max(1, [int][math]::Round($est / 60)) + ' min. ' + $you + $(if ($done) { ' ' + $done + ' already done for this version and off.' } else { '' })),
          $(if (Test-WordOpen) { 'Word is open. Save your documents and close Word before you start.' } else { '' }), $w1)
        Buttons = @($startB, @{ Text = $(if ($dep) { 'Install' } else { 'Run' }); Kind = $(if (($n -or ($cleanup.Count -and $ui.Clean)) -and -not $startPrimary) { 'primary' } elseif ($n -or ($cleanup.Count -and $ui.Clean)) { '' } else { 'off' }); Act = { & $ui.Run } }, @{ Text = 'Record'; Act = { $ui.Edit = $true; & $ui.VRecord } },
          $(if ($siteName) { @{ Text = 'Change the site address'; Act = { & $ui.VSite } } } else { $null }))
        Foot = $(if ($siteName) { 'Site: ' + $siteName } else { '' })
        Back = { & $ui.VChoose } } }

    # ---- The run. Invoke-Round calls back: a log line ($ui.Say), a tick ($ui.Tick), a step that starts ($ui.OnStatus) and
    # a step that ends ($ui.OnStep). A step you do by hand comes in through $script:guideUi.
    $ui.Say = { param($t) Add-RunLog $t; $ui.Log.Add([string]$t); $x = ([string]$t).Trim(); if ($x -and $ui.View -eq 'run') { $ui.LastLog.Text = $x }; if ($ui.RecOn) { try { $ui.RecText.AppendText([string]$t + "`r`n") } catch { $null = $_ } }; try { [System.Windows.Forms.Application]::DoEvents() } catch { $null = $_ } }
    $ui.Paint = {
      if (-not $script:prog -or -not $script:stepStart) { return }
      $g = Get-Progress
      & $ui.SetBar 'all' ([math]::Max($g.All, $ui.Bars['all'].Target)) $true; & $ui.SetBar 'step' ([math]::Max($g.StepShown, $ui.Bars['step'].Target)) $true
      if ($ui.View -ne 'run') { return }
      $fr = $(if ($script:prog.Frac -ge 0) { [string]$script:prog.FracText } else { '' }); if ($ui.StepFrac.Text -ne $fr) { $ui.StepFrac.Text = $fr }
      # R21 W6: a time left only when earlier runs give one; never "a guess".
      $rt = [string][int]($g.All * 100) + ' %' + $(if ($g.Known) { $dot + 'about ' + [math]::Max(1, [int][math]::Ceiling($g.Left / 60)) + $(if ([math]::Ceiling($g.Left / 60) -le 1) { ' minute' } else { ' minutes' }) + ' left' } else { '' }); if ($ui.RightL.Text -ne $rt) { $ui.RightL.Text = $rt } }
    $ui.Tick = { $null = & $ui.Paint; [System.Windows.Forms.Application]::DoEvents() }   # a callback must emit nothing: its output would join the engine function's return value
    $ui.TitleOf = { param([string]$Name) foreach ($s in @($steps)) { if ([string]$s.Name -ceq $Name) { return (Get-StepTitle $s) } }; return $Name }   # the title of the step with this name
    $ui.ShowRun = {
      & $ui.SetCard @{ View = 'run'; Kicker = $(if ($ui.StepI) { 'Step ' + $ui.StepI + ' of ' + $ui.StepN } else { 'Starting' }); Sentence = $(if (Test-Deploy) { 'Installing ' + $script:app.Name + '.' } else { 'Running round ' + $round + '.' })
        StepRow = $true; Buttons = @(@{ Text = 'Cancel'; Always = $true; Act = { $ui.Form.Close() } })   # asks first while a step runs (the window's X does the same)
        Foot = $(if (@($ui.Guides).Count) { 'RADE needs you next at "' + (& $ui.TitleOf $ui.Guides[0]) + '". Until then, keep this window open.' } else { 'Nothing is needed from you. Keep this window open.' }) }
      $ui.StepName.Text = (& $ui.TitleOf $ui.StepNow); $null = & $ui.FitEdges }   # the edge follows the ink of the new text's first letter (titles start with any letter)
    $ui.OnStatus = { param($i, $count, $name, $estimate)
      $script:statusBase = $name; $script:stepStart = Get-Date; $script:stepEst = $estimate
      if ($i -le 1) { $null = & $ui.SetBar 'all' 0 $true }
      $ui.StepI = [int]$i; $ui.StepN = [int]$count; $ui.StepNow = [string]$name
      if ($ui.View -ne 'run') { $null = & $ui.ShowRun } else { $ui.Kick.Text = ('Step ' + $i + ' of ' + $count).ToUpperInvariant(); $ui.StepName.Text = (& $ui.TitleOf $name); $null = & $ui.FitEdges }
      $null = & $ui.SetBar 'step' 0 $true; $ui.StepFrac.Text = ''
      $null = & $ui.Paint; [System.Windows.Forms.Application]::DoEvents() }
    $ui.OnStep = { param($k, $line)
      $nm = [string]$steps[$k].Name + ': '; $rest = [string]$line; if ($rest.StartsWith($nm, [System.StringComparison]::Ordinal)) { $rest = $rest.Substring($nm.Length) }
      $st = 'DONE'; foreach ($w in 'NEEDS REVIEW', 'FAILED', 'SKIPPED', 'PASSED') { if ($rest.StartsWith($w, [System.StringComparison]::Ordinal)) { $st = $w; break } }
      $ui.StepState[[int]$k] = $st; $null = & $ui.Paint }
    $ui.WindowLine = { $w = $(if ($ui.OkBox.Checked) { 'Window: OK' } else { 'Window: NOT OK - write here what overlapped or was cut off' }); if ($ui.LayOn -and ($env:RADE_LAYOUT -eq '1' -or -not (Test-Deploy))) { $w + "`r`n" + (& $ui.LayLine) } else { $w } }
    $ui.StartApp = {
      # The installed app opens from its local copy in its own powershell.exe process; then RADE closes.
      $p = Get-StartPath; if (-not $p) { & $ui.Say1 'The start file of this application was not found. Select "Install" to put it back.'; return }
      try { $pr = Start-Process -FilePath (Get-PowerShellExe) -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -STA -File "' + $p + '"') -WorkingDirectory (Split-Path -Parent $p) -PassThru
        if ($pr) { $null = $pr.Handle }   # Windows PowerShell 5.1 keeps the exit code only when the handle is held
        # A start script that a policy blocks or that fails at once ends within a moment: say so and keep RADE open.
        if ($pr -and $pr.WaitForExit(2500) -and $pr.ExitCode -ne 0) { & $ui.Say1 ('The application stopped as soon as it started (exit code ' + $pr.ExitCode + '). Ask in the Teams channel.'); return }
        $ui.Started = $true; $ui.Form.Close() } catch { & $ui.Say1 'The application could not be started. Select "Start" again, or ask in the Teams channel.' } }
    $ui.Run = {
      $dep = Test-Deploy; $ui.Running = $true; $ui.Summary = @(); $ui.Log.Clear(); $ui.StepState = @{}; $ui.StepI = 0; $ui.StepNow = ''; $ui.Edit = $false
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
      & $ui.ShowRun
      $checkLines = Get-CheckSummary $script:checkResults
      $script:roundStart = Get-Date
      try {
        $ui.Summary = Invoke-Round ([bool]($cleanup.Count -and $ui.Clean)) $sel $to $ui.Say $ui.Tick $ui.OnStep $ui.OnStatus $ui.WindowLine $answers $checkLines
        $script:stepStart = $null; $ui.Running = $false
        if (-not ($script:closing -or $ui.Form.IsDisposed)) { & $ui.VDone }   # closed in the last moments of the run: no clipboard, no folder
      } catch {
        $script:stepStart = $null; $ui.Running = $false
        if ($script:closing -or $ui.Form.IsDisposed) { return }   # Exit during a step: the report on disk says STOPPED
        $msg = 'STOPPED: ' + (ConvertTo-Masked ([string]$_)); & $ui.Say $msg
        $what = [string](Get-WhatToDo $msg); if ($what) { & $ui.Say $what }
        & $ui.VStopped $msg.Substring(9) $what
      } finally { $ui.Running = $false; $sv = $ui.StepState; & $ui.InitSel; $ui.StepState = $sv } }
    $ui.MadeText = {
      # Deploy: how many things the installs of this application made, by kind (the list is in the Record).
      $c = [ordered]@{}; $e = (Read-Installed (Get-InstalledKey $script:app))
      if ($e -and $e.steps) { foreach ($n in @($e.steps.Keys)) { foreach ($m in @($e.steps[$n].made)) { if ($null -ne $m) { $k = [string]$m.kind; if ($c.Contains($k)) { $c[$k] = [int]$c[$k] + 1 } else { $c[$k] = 1 } } } } }
      if (-not $c.Count) { return '' }
      $parts = @(); foreach ($k in @($c.Keys)) { $parts += ([string]$c[$k] + ' ' + $k + $(if ($c[$k] -ne 1) { 's' } else { '' })) }
      return ('The installs of this application made: ' + ($parts -join ', ') + '.') }
    $ui.Copy = {
      $t = $(if (@($ui.Summary).Count) { @($ui.Summary) } else { @($ui.Log) }) -join "`r`n"
      try { [System.Windows.Forms.Clipboard]::SetText($t); & $ui.Say1 'Copied.' } catch { & $ui.Say1 'The clipboard is busy. Select the button again.' } }
    $ui.Open = { if ($script:resultsDir) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $script:resultsDir + '"') } }
    $ui.VDone = {
      $sum = @($ui.Summary); $dep = Test-Deploy; $bad = ([string]$sum[0] -match 'NEEDS REVIEW'); $made = ''; if ($dep) { $made = [string](& $ui.MadeText) }
      $took = Format-Duration ((Get-Date) - $script:roundStart).TotalSeconds
      $ui.Bars['all'].Fill = $(if ($bad) { $ui.C.Blue } else { $ui.C.Green }); & $ui.SetBar 'all' $(if ($bad) { $ui.Bars['all'].Target } else { 1 }) $true
      $mail = $(if ($script:draftMade) { 'An Outlook draft is open with the summary and all result files. Review it, then select Send.' } else { 'The results folder is open and the summary is on the clipboard. Paste it into an e-mail and attach the files.' })
      $bMade = $(if ($made) { @{ Text = 'Record'; Act = { & $ui.VRecord } } } else { $null })
      $iconNote = ''; if ($dep -and -not $bad) { $null = Save-RunnerCopy; $iconNote = [string](Add-DesktopIcon) }   # R28: the runner copy and the desktop shortcut (a deploy that passed)
      if (-not $bad) {
        $inst = ($dep -and (Get-InstalledText $script:app) -match 'is installed$')
        & $ui.SetCard @{ View = 'done'; Tick = $true; Kicker = $(if ($dep -and -not $inst) { 'Passed' } else { 'All steps passed' }); Right = $took
          Sentence = $(if (-not $dep) { 'Round ' + $round + ' is done.' } elseif ($inst) { $script:app.Name + ' ' + $script:app.Version + ' is installed.' } else { 'The run passed, but version ' + $script:app.Version + ' is not recorded as installed.' })
          P = @($(if ($dep -and -not $inst) { 'Some steps were off or skipped. Run again with every step on.' } else { '' }), $(if ($dep) { 'Nothing was sent. The report stays on this computer.' } else { $mail }), $made, $iconNote)
          Buttons = @(@{ Text = 'Close'; Kind = 'primary'; Act = { $ui.Form.Close() } }, $bMade, @{ Text = 'Open results folder'; Act = { & $ui.Open } }, @{ Text = 'Copy summary'; Act = { & $ui.Copy } })
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

    # ---- A step you do by hand, or a check you answer by looking (R13, R14, R18): the card holds the numbered lines, the
    # address (it can be changed; it is remembered in Config), the file path on the clipboard, and the answers. The engine
    # waits in $script:guideUi until an answer is set: OK = Done or Yes, No, Abort = It failed (with the error text),
    # Cancel = Skip, Not now, or the window closed. Enter never answers here: Done needs a deliberate click.
    $ui.VHand = {
      $st = $ui.G.Step; $file = [string]$ui.G.File
      $clip = $(if (-not $file) { '' } elseif (Copy-TextToClipboard $file) { 'The path of ' + $st.File + ' is on the clipboard.' } else { 'Select "Copy file path" to put the path of ' + $st.File + ' on the clipboard.' })
      $two = $(if ($st.NoText) { @{ Text = [string]$st.NoText; Act = { $ui.Answer = 'No' } } } else { @{ Text = 'It failed'; Act = { & $ui.VHandFail } } })
      & $ui.SetCard @{ View = 'hand'; Light = 'you'; Kicker = $(if ($ui.Running -and $ui.StepI) { 'Step ' + $ui.StepI + ' of ' + $ui.StepN + $dot + 'your turn' } else { 'Your turn' }); Sentence = (Get-StepTitle $st)
        P = @([string]$st.Note); Lines = @($st.Guide); Close = ('When you finish in the browser, come back to this window and select "' + $(if ($st.DoneText) { [string]$st.DoneText } else { 'Done' }) + '".')
        Field = @{ Label = 'Address'; Text = $ui.GUrl; Name = 'Address to open'; Button = 'Open in browser'; Act = { & $ui.OpenUrl } }; Links = [bool]$file; Note = $clip
        Buttons = @(@{ Text = $(if ($st.DoneText) { [string]$st.DoneText } else { 'Done' }); Kind = 'primary'; Act = { $ui.Answer = 'OK' } }, $two, @{ Text = $(if ($st.SkipText) { [string]$st.SkipText } else { 'Skip' }); Act = { $ui.Answer = 'Cancel' } })
        Right = 'RADE is waiting for you'; NoAccept = $true; Focus = 'fieldbutton' } }
    $ui.VHandFail = {
      & $ui.SetCard @{ View = 'handfail'; Light = 'you'; Kicker = 'It failed'; Sentence = 'What did the error say?'; P = @('Paste the error message here. Do not include names or a site address.'); Err = $true
        Buttons = @(@{ Text = 'Report the failure'; Kind = 'primary'; Act = { $script:guideError = [string]$ui.ErrBox.Text; $ui.Answer = 'Abort' } }, @{ Text = 'Back'; Act = { & $ui.VHand } }); Right = 'RADE is waiting for you'; NoAccept = $true; Focus = 'err' } }
    # A question of a hand step (manifest "answers"), after Done: the prompt is the sentence; yes/no and pick answer with
    # one button per word, a text with one line (120 characters at most; empty is allowed) and "Continue". No Back.
    $ui.ReplyActs = @({ $ui.Reply = [string]$ui.B[0].Text }, { $ui.Reply = [string]$ui.B[1].Text }, { $ui.Reply = [string]$ui.B[2].Text }, { $ui.Reply = [string]$ui.B[3].Text })
    $ui.VAnswer = { param($Q, [int]$I, [int]$N)
      $ui.Reply = $null
      $c = @{ View = 'answer'; Light = 'you'; Kicker = ($(if ($ui.Running -and $ui.StepI) { 'Step ' + $ui.StepI + ' of ' + $ui.StepN + $dot } else { '' }) + 'Question ' + $I + ' of ' + $N); Sentence = [string]$Q.Prompt; Right = 'RADE is waiting for you' }
      # The prompt's first sentence (up to the first "?", "." or ":" followed by a space or the end) is the headline; the rest
      # is a body line under it (the Administrator, 2026-11-15, rework B). A first sentence too long for one line shrinks ($ui.FitSent).
      if ([string]$Q.Prompt -match '^(.+?[?.:])(?:\s+(\S.*))?$') { $c.Sentence = $Matches[1]; if ($Matches[2]) { $c.P = @($Matches[2].Trim()) } }
      if ($Q.Kind -eq 'text') { $c.Field = @{ Label = 'Your answer'; Text = ''; Name = [string]$Q.Prompt; Max = 120 }; $c.Focus = 'field'; $c.Buttons = @(@{ Text = 'Continue'; Kind = 'primary'; Act = { $ui.Reply = [string]$ui.Field.Text } }) }
      else { $ws = @($(if ($Q.Kind -eq 'yesno') { 'Yes', 'No' } else { $Q.Choices })); $c.Buttons = @(for ($k = 0; $k -lt $ws.Count; $k++) { @{ Text = [string]$ws[$k]; Act = $ui.ReplyActs[$k] } }) }
      & $ui.SetCard $c }
    $ui.OpenUrl = {
      $u = $ui.Field.Text.Trim()
      if ($u -notmatch '^https://') { & $ui.Say1 'The address must start with https://'; return }
      $ui.GUrl = $u; try { if ($ui.G.UrlFile) { Set-Content -LiteralPath $ui.G.UrlFile -Value $u -Encoding UTF8 } } catch { $null = $_ }
      try { Start-Process -FilePath $u; & $ui.Say1 'Opened in your browser. Do the steps on this card, then come back to this window.' } catch { & $ui.Say1 ('The browser could not be opened: ' + $_.Exception.Message) } }
    $ui.CopyPathB.Add_Click({ & $ui.Say1 $(if (Copy-TextToClipboard ([string]$ui.G.File)) { 'File path copied. Press Ctrl+V in the "File name" box' } else { 'The clipboard is busy. Select "Copy file path" again.' }) })
    $ui.PageB.Add_Click({ try { Start-Process -FilePath $radeUrl } catch { & $ui.Say1 'The browser could not be opened. Open the RADE page from your bookmarks.' } })
    $ui.ShowFileB.Add_Click({ if ($ui.G.File) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"' + $ui.G.File + '"') } })
    $script:guideUi = { param($Step, [string]$File, [string]$Url, [string]$UrlFile)
      $ui.G = @{ Step = $Step; File = $File; UrlFile = $UrlFile }; $ui.GUrl = $Url; $script:guideError = ''; $ui.Answer = ''; $was = $ui.Busy; $ui.Busy = $false
      $null = & $ui.VHand; $null = & $ui.ToFront
      while (-not $ui.Answer -and -not $script:closing -and -not $ui.Form.IsDisposed) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 25 }
      # After Done (not after "It failed" or Skip): the step's questions, one card each, in order. Their time is the step's time.
      $script:guideAnswers = @{}; $qs = @($(if ($ui.Answer -eq 'OK') { $Step.Answers }) | Where-Object { $_ })
      for ($i = 0; $i -lt $qs.Count -and -not $script:closing -and -not $ui.Form.IsDisposed; $i++) {
        $null = & $ui.VAnswer $qs[$i] ($i + 1) $qs.Count
        while ($null -eq $ui.Reply -and -not $script:closing -and -not $ui.Form.IsDisposed) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 25 }
        if ($null -ne $ui.Reply) { $script:guideAnswers[[string]$qs[$i].Key] = [string]$ui.Reply }
      }
      $ui.Busy = $was; $res = [string]$ui.Answer; if (-not $res) { $res = 'Cancel' }
      $ui.Guides = @($ui.Guides | Where-Object { $_ -ne [string]$Step.Name })
      if ($ui.Running -and -not $script:closing) { $null = & $ui.ShowRun }
      return $res }

    # ---- The Record
    $ui.StateInk = { param([string]$St) $(if ($St -eq 'PASSED') { $ui.C.GreenInk } elseif ($St -in 'FAILED', 'NEEDS REVIEW') { $ui.C.Red } elseif ($St -in 'WARNING', 'RUNNING') { $ui.C.Navy } else { $ui.C.Gray }) }   # the word is always shown: never color alone
    $ui.RecRows = {
      # The checks to list: the chosen application's, or (before a choice) the base checks. Group, name, state, and the rows under it.
      $ids = $(if ($ui.Picked) { @($script:appChecks) } else { @($ui.BaseIds) }); $rows = @(); $g0 = ''
      foreach ($id in $ids) {
        $d = Get-CheckDef $id; $r = $(if ($ui.Picked) { $script:checkResults[$id] } else { $ui.BaseRes[$id] }); if (-not $r) { $r = @{ State = 'NOT RUN'; Detail = ''; Fix = '' } }
        if ([string]$d.Group -ne $g0) { $g0 = [string]$d.Group; $rows += @{ Head = $g0.ToUpperInvariant() } }
        $nm = [string]$d.Short; if (-not $nm) { $nm = [string]$d.Name }
        $rows += @{ Name = $nm; State = [string]$r.State; More = $(if ($r.State -ne 'PASSED' -or $r.Saved) { @(@($r.Detail, $r.Fix) | Where-Object { $_ }) } else { @() }) }   # not passed: what was found, then what to do; reused (Get-SavedCheck): "Last check: 17 Nov 26", then what it found
      }
      return $rows }
    $ui.RecPlan = { param([int]$w)
      # Where each row of the check list goes. The result word has its own column (as wide as the widest plain result
      # word): no name and no detail enters it. A qualifier ("fallback") goes under the word in gray. A name and each
      # detail wrap to 2 lines at most.
      $h0 = [System.Windows.Forms.TextRenderer]::MeasureText('Ag', $ui.F.Small).Height; $hc = [System.Windows.Forms.TextRenderer]::MeasureText('Ag', $ui.F.SmallB).Height; $v = & $ui.Sc 3
      $sw = 0; foreach ($t in 'NOT RUN', 'WARNING', 'RUNNING', 'PASSED', 'FAILED', 'fallback') { $sw = [math]::Max($sw, [System.Windows.Forms.TextRenderer]::MeasureText($t, $ui.F.SmallB).Width) }
      $sw += & $ui.Sc 4; $lw = [math]::Max((& $ui.Sc 60), ($w - $sw - (& $ui.Sc 8))); $in = & $ui.Sc 12; $y = 0; $rows = @()
      foreach ($r in @($ui.RecData)) {
        if ($r.Head) { $y += & $ui.Sc 8; $rows += @{ R = $r; Y = $y; H = ($h0 + $v) }; $y += $h0 + $v; continue }
        $word = [string]$r.State; $qual = ''; if ($word -match '^(.+?) \((.+)\)$') { $word = $Matches[1]; $qual = $Matches[2] }
        $nh = (& $ui.Rows ([string]$r.Name) $ui.F.Small $lw $h0 2) * $h0 + $v; if ($qual) { $nh = [math]::Max($nh, (2 * $hc + $v)) }
        $more = @(); $my = $y + $nh
        foreach ($m in @($r.More)) { $mh = (& $ui.Rows ([string]$m) $ui.F.Small ($lw - $in) $h0 2) * $h0 + $v; $more += @{ T = [string]$m; Y = $my; H = $mh }; $my += $mh }
        $rows += @{ R = $r; Y = $y; H = $nh; Word = $word; Qual = $qual; More = $more }; $y = $my
      }
      return @{ Rows = $rows; Tall = $y; Sw = $sw; Lw = $lw; In = $in; H0 = $h0; Hc = $hc } }
    $ui.RecChecks.Add_Paint({
      try {
        $g = $_.Graphics; $g.Clear($ui.C.White); $w = $this.ClientSize.Width; $pl = & $ui.RecPlan $w; $sw = $pl.Sw; $lw = $pl.Lw
        $wrap = 'Left, Top, NoPrefix, WordBreak, EndEllipsis, TextBoxControl'
        foreach ($q in @($pl.Rows)) {
          $r = $q.R
          if ($r.Head) { & $ui.Word $g ([string]$r.Head) $ui.F.SmallB $ui.C.Gray 0 $q.Y $w $q.H 'Left, VerticalCenter, NoPrefix, SingleLine'; continue }
          & $ui.Word $g ([string]$r.Name) $ui.F.Small $ui.C.Navy 0 ($q.Y + (& $ui.Sc 1)) $lw ($q.H - (& $ui.Sc 1)) $wrap
          & $ui.Word $g ([string]$q.Word) $ui.F.SmallB (& $ui.StateInk ([string]$q.Word)) ($w - $sw) ($q.Y + (& $ui.Sc 2)) $sw $pl.Hc 'Right, Top, NoPrefix, SingleLine'
          if ($q.Qual) { & $ui.Word $g ([string]$q.Qual) $ui.F.Small $ui.C.Gray ($w - $sw) ($q.Y + (& $ui.Sc 2) + $pl.Hc) $sw $pl.Hc 'Right, Top, NoPrefix, SingleLine' }
          foreach ($m in @($q.More)) { & $ui.Word $g $m.T $ui.F.Small $ui.C.Gray $pl.In ($m.Y + (& $ui.Sc 1)) ($lw - $pl.In) ($m.H - (& $ui.Sc 1)) $wrap }   # what was found, then what to do
        }
      } catch { $null = $_ } })
    $ui.RecTall = { if (-not $ui.Scaled) { return }; try { $t = (& $ui.RecPlan $ui.RecChecks.ClientSize.Width).Tall + (& $ui.Sc 4); if ($ui.RecChecks.Height -ne $t) { $ui.RecChecks.Height = $t } } catch { $null = $_ } }
    $ui.RecChecks.Add_Resize({ if ($ui.RecOn -and [int]$ui.RecW -ne [int]$this.ClientSize.Width) { $ui.RecW = [int]$this.ClientSize.Width; & $ui.RecTall }; $this.Invalidate() })
    # The step list: a label or a long step name wraps at the column's width, also after the window changes its size.
    $ui.RecFit = { if (-not $ui.Scaled) { return }; try { $mw = [math]::Max((& $ui.Sc 120), ($ui.RecSteps.ClientSize.Width - (& $ui.Sc 28))); foreach ($l in @($ui.RecSteps.Controls)) { if ($l -is [System.Windows.Forms.CheckBox]) { $fu = $ui.Full[$l]; if ($null -ne $fu) { & $ui.Shorten $l ([string]$fu) $mw }; $l.Size = New-Object System.Drawing.Size($mw, $l.PreferredSize.Height) } else { $l.MaximumSize = New-Object System.Drawing.Size($mw, 0) } } } catch { $null = $_ } }   # a step box is one line, as wide as the column, and ends with "..." when its text is longer
    $ui.RecSteps.Add_SizeChanged({ & $ui.RecFit })
    & $ui.Ring $ui.RecSteps; & $ui.Ring $ui.Rec; & $ui.Cue $ui.RecText   # focus is always visible: the step boxes and the text box too
    $ui.VRecord = {
      & $ui.Check
      $ui.RecOn = $true; $ui.RecData = @(& $ui.RecRows)
      $ui.RecW = 0; & $ui.RecTall   # as tall as its rows (the same plan as the Paint handler)
      $ui.RecChecks.AccessibleName = 'Checks. ' + ((@($ui.RecData) | ForEach-Object { if ($_.Head) { $_.Head + ':' } else { $_.Name + ' ' + $_.State + $(if (@($_.More).Count) { ', ' + (@($_.More) -join ', ') } else { '' }) } }) -join '. ')
      $old = @($ui.RecSteps.Controls); $ui.RecSteps.Controls.Clear(); foreach ($o in $old) { $o.Dispose() }; $ui.Full = @{}
      $mk = { param([string]$Text, $Font, $Color) $l = New-Object System.Windows.Forms.Label; $l.AutoSize = $true; $l.UseMnemonic = $false; $l.MaximumSize = New-Object System.Drawing.Size(([math]::Max((& $ui.Sc 120), $ui.RecSteps.ClientSize.Width - (& $ui.Sc 24))), 0); $l.Text = $Text; $l.Font = $Font; $l.ForeColor = $Color; $l.Margin = (& $ui.Pad (& $ui.Sc 5) 0 0 (& $ui.Sc 6)); [void]$ui.RecSteps.Controls.Add($l) }
      & $mk 'STEPS' $ui.F.SmallB $ui.C.Gray
      if (-not $ui.Picked) { & $mk 'Choose an application first.' $ui.F.Small $ui.C.Gray }
      else {
        if (-not $ui.Edit) { & $mk $(if ($ui.Running) { 'The run has started: the boxes are locked.' } else { 'To change the boxes, go to "Ready" and select "Record".' }) $ui.F.Small $ui.C.Gray }
        $list = @(); if ($cleanup.Count) { $list += -1 }; $list += @($script:appSteps); $n = 0
        foreach ($k in $list) {
          $cb = New-Object System.Windows.Forms.CheckBox
          $cb.AutoSize = $false; $cb.UseMnemonic = $false; $cb.Margin = (& $ui.Pad (& $ui.Sc 5) (& $ui.Sc 4) (& $ui.Sc 4) (& $ui.Sc 4)); & $ui.Cue $cb; $cb.Enabled = [bool]$ui.Edit; $cb.Tag = [int]$k; $cb.Font = $ui.F.SmallB; $cb.ForeColor = $ui.C.Navy
          if ($k -lt 0) { $cb.Text = 'Clean-up'; $cb.Checked = [bool]$ui.Clean; $more = 'Moves finished files to the Recycle Bin' }
          else {
            $n++; $s1 = $steps[$k]; $cb.Checked = [bool]$ui.Sel[[int]$k]
            $cb.Text = [string]$n + '  ' + (Get-StepTitle $s1) + $(if ($s1.AskParam) { '  (asks for a folder)' } elseif ($s1.Kind -eq 'guide') { '  (needs you)' } else { '' })
            $more = $(if ($ui.StepState[[int]$k]) { [string]$ui.StepState[[int]$k] } elseif ((Test-Deploy) -and -not [bool]$s1.Optional -and -not (Get-StepDefault $k)) { 'Already done for version ' + $script:app.Version + '. Tick the box to run it again' } else { [string]$s1.Note })
          }
          $cb.AccessibleName = $cb.Text + $(if ($more) { '. ' + $more } else { '' }); $ui.Full[$cb] = [string]$cb.Text   # the full name; the box may show it shortened ($ui.RecFit)
          $cb.Add_CheckedChanged({ if ([int]$this.Tag -lt 0) { $ui.Clean = [bool]$this.Checked } else { $ui.Sel[[int]$this.Tag] = [bool]$this.Checked } })
          [void]$ui.RecSteps.Controls.Add($cb)
          if ($more) { & $mk $more $ui.F.Small (& $ui.StateInk $more) }
        }
      }
      $t = @()
      if ($ui.Picked) {
        if (-not $ui.Plan) { $ui.Plan = Get-RoundPlan }
        $t += $ui.Plan.Lines
        if (Test-Deploy) { $ml = @(Get-MadeLine); if ($ml.Count) { $t += ''; $t += $ml } else { $t += @('', 'The installs of this application have made nothing yet.') } }
      }
      if ($ui.Log.Count -or $ui.Running) { $t += @('', 'LOG'); $t += @($ui.Log) }
      $ui.RecText.Text = ($t -join "`r`n") + "`r`n"   # ends with a line break: a live log line is added below
      $ui.RecTitle.Text = 'Record' + $(if ($ui.Picked) { $dot + $script:app.Name } else { '' })
      & $ui.RecFit
      $ui.Card.Visible = $false; $ui.Rec.Visible = $true; & $ui.RecTall; $ui.RecChecks.Invalidate(); $ui.RecB.Visible = $false; $ui.BackB.Visible = $false
      try { [void]$ui.RecClose.Focus() } catch { $null = $_ } }
    $ui.CloseRecord = {
      & $ui.Check
      $ui.RecOn = $false; $ui.Rec.Visible = $false; $ui.Card.Visible = $true; $ui.RecB.Visible = $true; $ui.BackB.Visible = [bool]$ui.Back
      if ($ui.Edit) { $ui.Edit = $false; if ($ui.View -eq 'ready') { & $ui.VReady } }   # the plan line follows the boxes
      try { [void]$ui.RecB.Focus() } catch { $null = $_ } }
    $ui.RecB.Add_Click({ & $ui.VRecord })
    $ui.RecClose.Add_Click({ & $ui.CloseRecord })
    $ui.BackB.Add_Click({ if ($ui.Back -and -not $ui.RecOn -and -not $ui.Busy -and -not $ui.Running) { & $ui.Back } })

    # ---- Keys: F2 = the Record (Page Down and Page Up move its check list, and on a card that is taller than the window its text); Esc = close the Record, else Back, and on Choose (no Back) it exits; 1 to 9 = a choice. Tab reaches every control.
    $ui.Form.Add_KeyDown({
      $k = [string]$_.KeyCode
      if ($_.Control -and $k -eq 'C' -and (& $ui.CopyText $ui.Form.ActiveControl)) { $_.SuppressKeyPress = $true }   # Ctrl+C copies the selected card text
      elseif ($k -eq 'F2') { $_.SuppressKeyPress = $true; if ($ui.RecOn) { & $ui.CloseRecord } else { & $ui.VRecord } }
      elseif ($ui.RecOn -and $k -in 'PageDown', 'Next', 'PageUp', 'Prior' -and -not (& $ui.InField)) {   # the check list by keyboard when it is taller than the window; Windows names these keys Next and Prior; in the log box they page the log
        $_.SuppressKeyPress = $true; try { $y = [math]::Abs($ui.RecScroll.AutoScrollPosition.Y) + $(if ($k -in 'PageDown', 'Next') { 1 } else { -1 }) * [math]::Max((& $ui.Sc 40), $ui.RecScroll.ClientSize.Height - (& $ui.Sc 40)); $ui.RecScroll.AutoScrollPosition = New-Object System.Drawing.Point(0, [math]::Max(0, $y)) } catch { $null = $_ } }
      elseif (-not $ui.RecOn -and $ui.Scrolls -and $k -in 'PageDown', 'Next', 'PageUp', 'Prior' -and -not (& $ui.InField)) {   # the text of a card that is taller than the window, by keyboard
        $_.SuppressKeyPress = $true; try { $y = [math]::Abs($ui.Scroll.AutoScrollPosition.Y) + $(if ($k -in 'PageDown', 'Next') { 1 } else { -1 }) * [math]::Max((& $ui.Sc 40), $ui.Scroll.ClientSize.Height - (& $ui.Sc 40)); $ui.Scroll.AutoScrollPosition = New-Object System.Drawing.Point(0, [math]::Max(0, $y)) } catch { $null = $_ } }
      elseif ($k -eq 'Escape') { $_.SuppressKeyPress = $true; if ($ui.RecOn) { & $ui.CloseRecord } elseif ($ui.Back -and -not $ui.Busy -and -not $ui.Running) { & $ui.Back } elseif ($ui.View -eq 'choose' -and -not $ui.Busy) { $ui.Form.Close() } }
      elseif ($k -match '^(D|NumPad)([1-9])$' -and -not $ui.RecOn -and -not $ui.Busy -and $ui.Opts.Visible -and -not (& $ui.InField)) {
        $n = [int]$Matches[2]; foreach ($o in @($ui.Opts.Controls)) { if (-not $o.Tag.Off -and [int]$o.Tag.Key -eq $n) { $_.SuppressKeyPress = $true; $o.PerformClick(); break } } } })
    # Window size and place (R28, the Administrator, 2026-11-17): the window opens where the user last closed it (RADE\Config\rade-window.json;
    # bounds that are off every current screen are ignored); the first time it is maximized on the screen that shows the mouse. The
    # minimum size is 1280 x 720 at 100 % (cut to the work area of a small screen). The size and the state at Shown and at close are
    # recorded, and the layout self-check runs again after each resize (debounced: 400 ms after the last size change).
    $ui.Place = {
      $f = $ui.Form; $saved = Read-WindowState; $ui.Placed = 'first run'; $ui.LastClose = $(if ($saved) { [string]$saved.Closed } else { '' })
      try {
        $use = $null; $wa = $null
        if ($saved) { $r = New-Object System.Drawing.Rectangle($saved.X, $saved.Y, $saved.W, $saved.H)
          foreach ($sc in @([System.Windows.Forms.Screen]::AllScreens)) { $i = [System.Drawing.Rectangle]::Intersect($sc.WorkingArea, $r); if ($i.Width -ge (& $ui.Sc 120) -and $i.Height -ge (& $ui.Sc 60)) { $use = $r; $wa = $sc.WorkingArea; break } } }
        if ($use) {
          $w = $use.Width; $h = $use.Height
          if ($saved.Dpi -gt 0 -and [int]$ui.Dpi -ne $saved.Dpi) { $w = [int]($w * $ui.Dpi / $saved.Dpi); $h = [int]($h * $ui.Dpi / $saved.Dpi) }   # the screen scale changed since: the size follows
          $w = [math]::Min($w, $wa.Width); $h = [math]::Min($h, $wa.Height)
          $x = [math]::Max($wa.Left, [math]::Min($use.X, $wa.Right - $w)); $y = [math]::Max($wa.Top, [math]::Min($use.Y, $wa.Bottom - $h))
          $f.Bounds = New-Object System.Drawing.Rectangle($x, $y, $w, $h); $ui.Placed = 'saved'
          if ($saved.State -eq 'Maximized') { $f.WindowState = 'Maximized' }
        } else {
          $sc = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position); $wa = $sc.WorkingArea
          $f.Width = [int]($wa.Width * 0.95); $f.Height = [int]($wa.Height * 0.95); $f.Left = $wa.Left + [int](($wa.Width - $f.Width) / 2); $f.Top = $wa.Top + [int](($wa.Height - $f.Height) / 2)   # where Restore goes
          $f.WindowState = 'Maximized'
        }
        $f.MinimumSize = New-Object System.Drawing.Size([math]::Min((& $ui.Sc 1280), $wa.Width), [math]::Min((& $ui.Sc 720), $wa.Height))
      } catch { $null = $_ } }
    $ui.WinNow = { $f = $ui.Form; $s = [string]$f.WindowState; if ($s -notin 'Normal', 'Maximized', 'Minimized') { $s = 'Normal' }; return ([string]$f.ClientSize.Width + 'x' + $f.ClientSize.Height + '/' + $s) }
    $ui.ResizeT = New-Object System.Windows.Forms.Timer; $ui.ResizeT.Interval = 400
    $ui.ResizeT.Add_Tick({ $ui.ResizeT.Stop(); try { if ($ui.Scaled -and [string]$ui.Form.WindowState -ne 'Minimized') { & $ui.Fit; & $ui.Check } } catch { $null = $_ } })
    $ui.Form.Add_Resize({ try { if ($ui.Scaled) { $ui.ResizeT.Stop(); $ui.ResizeT.Start() } } catch { $null = $_ } })
    $ui.Form.Add_Shown({
      $ui.Opened = $true; & $ui.FormDpi; $ui.Scaled = $true   # the form has its scale now: from here the size handlers work (each runs once below or on the first card)
      & $ui.Place
      & $ui.Fit; $ui.ShownAt = & $ui.WinNow; $ui.Anim.Start()
      & $ui.Boot })
    $ui.Form.Add_FormClosing({
      # The window's X (there is no Exit button): ask first only while a step runs, because closing stops it (R17).
      if ($ui.Running -and -not $script:closing) {
        $a = [System.Windows.Forms.MessageBox]::Show($ui.Form, 'A step is running. If you exit now, RADE stops it and the round ends as STOPPED (the report in the results folder says so). Exit now?', 'RADE - Exit', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning, [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
        if ([string]$a -ne 'Yes') { $_.Cancel = $true; return }
      }
      $script:closing = $true; try { $ui.Anim.Stop(); $ui.ResizeT.Stop() } catch { $null = $_ }
      try { $f = $ui.Form; $ui.CloseAt = & $ui.WinNow; $st = [string]$f.WindowState; if ($st -eq 'Minimized') { $st = 'Normal' }
        $b = $(if ([string]$f.WindowState -eq 'Normal') { $f.Bounds } else { $f.RestoreBounds }); $cp = ($ui.CloseAt -split '/'); $cs = ([string]$cp[0] -split 'x')   # split on / first: "Maximized" holds an x
        Save-WindowState $b.X $b.Y $b.Width $b.Height $st ([int]$ui.Dpi) ([int]$cs[0]) ([int]$cs[1]) ([string]$cp[1])
        Write-Host ('RADE window at close: client ' + ($ui.CloseAt -replace '/', ', ') + '.') } catch { $null = $_ }
      if ($script:child -and -not $script:child.HasExited) { try { $script:child.Kill() } catch { $null = $_ } } })
    # The window is the main form of this thread, with no owner (R24: shown with ShowDialog from PowerShell ISE, ISE owned
    # it, so it had no taskbar button and could not be restored after it was minimized). When a message loop already runs
    # on this thread, Application.Run cannot start one: then ShowDialog, as before. Run disposes the form when it closes.
    $ui.Opened = $false
    try { [System.Windows.Forms.Application]::Run($ui.Form) }
    catch {
      $ex = $_.Exception; while ($ex -and -not ($ex -is [System.InvalidOperationException])) { $ex = $ex.InnerException }
      if (-not $ex -or $ui.Opened -or $ui.Form.IsDisposed) { throw }   # only a loop that could not start: the window never showed
      [void]$ui.Form.ShowDialog()
    }
    foreach ($o in @($ui.Trash)) { try { $o.Dispose() } catch { $null = $_ } }   # after the window has closed: no handler is running
    return
  } catch {
    $gui = $false; $script:noWindowWhy = [string]$_.Exception.Message
    if ($_.InvocationInfo) { $script:noWindowWhy += ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')' }
    $shown = $script:noWindowWhy
    if ($env:USERPROFILE) { $shown = $shown -replace [regex]::Escape([string]$env:USERPROFILE), 'C:\Users\<DODID>' }
    Write-Host ('No window could open (' + (ConvertTo-Masked $shown) + '). The round runs in text mode.')
  }
}
try {
  $script:textMode = $true
  $say = { param($t) Add-RunLog $t; Write-Host $t }
  Write-Host ('RADE - ' + $round + ' - build ' + $buildId)
  Write-Host (Get-LastRoundText (Read-RoundHistory (Get-BasePath)))
  $newer = Get-NewerRound
  if ($newer) { Write-Host ('A newer round, ' + $newer + ', is in the repository. Type N and press Enter to stop, then run ' + $newer + '.') }
  if ($apps.Count -gt 1) {
    for ($i = 0; $i -lt $apps.Count; $i++) { Write-Host ('  ' + ($i + 1) + '. ' + $apps[$i].Name) }
    $pick = ([string](Read-Host ('Type the number of the application to deploy (1 to ' + $apps.Count + ') and press Enter'))).Trim()
    $pi = 0; if ([int]::TryParse($pick, [ref]$pi) -and $pi -ge 1 -and $pi -le $apps.Count) { Select-App ($pi - 1) }
  }
  Write-Host ('Application: ' + $script:app.Name)
  # All checks run here too: the sign-in check opens its own sign-in window; the Power Automate check asks in the console.
  $site0 = Get-SiteUrl (Get-BasePath)
  if (-not (Test-SiteUrl $site0) -and @($script:appChecks | Where-Object { $_ -in 'net-site', 'site-rights' }).Count) {
    $v = ([string](Read-Host 'Type the site address (it starts with https://usaf.dps.mil/sites/), then press Enter')).Trim()
    if (Test-SiteUrl $v) { $site0 = $v; try { Save-SiteUrl (Get-BasePath) $v } catch { $null = $_ } }   # saved as the window does: the record and the steps read it
  }
  $script:secret = Get-Secret (Get-ProfileLeaf) (Get-ProfileLeaf)
  $cache = Read-CheckCache
  foreach ($id in $script:appChecks) {
    $d = Get-CheckDef $id
    $r = Get-CheckToRun $d $cache (Get-BasePath) $site0 $false
    if (-not $r) { $r = Invoke-Check $d (Get-BasePath) $site0 $null }
    $script:checkResults[$id] = $r
    Write-Host ('  ' + $r.State + ': ' + $d.Name + '. ' + $r.Detail + $(if ($r.Fix -and ($r.State -ne 'PASSED' -or $r.Saved)) { ' | ' + $r.Fix } else { '' }))
  }
  Save-CheckCache $script:checkResults (Get-BasePath) $site0
  if ($checkGate -and (Get-CheckBlock $script:checkResults)) {
    # PFM 14 Nov 26: no deploy unless every check passes. Nothing has been written.
    Write-Host ''
    Write-Host 'You cannot deploy yet: a check is FAILED or NOT RUN (see above). Only the saved checks (RADE\Config\rade-checks.json) were written.'
    Write-Host 'Fix each one, then paste the round again.'
    return
  }
  foreach ($l in (Get-RoundPlan).Lines) { Write-Host $l }
  if (Test-WordOpen) { Write-Host 'Word is open. Save your documents and close Word before you run (renders use Word).' }
  $to = $(if (Test-Deploy) { '' } else { Get-MailTo (Get-BasePath) })
  # The plan above shows first; Enter starts the run (PFM 13 Nov), N stops before anything is written.
  $go = ([string](Read-Host 'Press Enter to start the round, or type N and press Enter to stop with no changes')).Trim()
  if ($go -match '^[Nn]') { Write-Host 'Stopped. Only the saved checks (RADE\Config\rade-checks.json) were written.'; return }
  $sel = @(); for ($k = 0; $k -lt $steps.Count; $k++) { $sel += ($script:appSteps -contains $k -and (Get-StepDefault $k) -and -not $steps[$k].AskParam) }   # text mode: steps that need a folder are skipped
  $onStatusText = { param($i, $count, $name, $estimate) $null = $name; $null = $estimate; $g = Get-Progress; Write-Host ('  Overall: step ' + $i + ' of ' + $count + ', ' + [int]($g.All * 100) + ' % done, about ' + (Format-Duration $g.Left) + ' left (a guess)') }
  $checkLines = Get-CheckSummary $script:checkResults
  $sum = Invoke-Round $true $sel $to $say { } { } $onStatusText { 'Window: text mode (no window opened)' } @() $checkLines
  if (Test-Deploy) { return }   # a deploy sends nothing: no folder pop-up, no clipboard
  if ($script:resultsDir -and $env:OS -eq 'Windows_NT' -and -not $script:draftMade) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $script:resultsDir + '"') }
  if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) { try { Set-Clipboard -Value ($sum -join "`r`n"); Write-Host 'Summary copied to the clipboard.' } catch { Write-Host 'The clipboard is not available.' } }
} catch {
  Write-Host ''
  $m = 'STOPPED: ' + (ConvertTo-Masked ([string]$_))
  Write-Host $m
  $w = Get-WhatToDo $m; if ($w) { Write-Host $w }
}
'''

# Checks every application runs (the rest come from its steps' "needs"). Ids must exist in the engine's $checkDefs.
BASE_CHECKS = ['nipr', 'ps', 'lang', 'onedrive', 'disk', 'write', 'child', 'outlook', 'net-bookmark']
CHECK_IDS = re.findall(r"@\{ Id = '([a-z-]+)'", ENGINE)


START_RE = re.compile(r'[A-Za-z0-9][A-Za-z0-9 ._-]*(/[A-Za-z0-9][A-Za-z0-9 ._-]*)*\.ps1')   # schemas/rade-manifest.schema.json app.start says the same


def app_lines(b):
    """The embedded catalog (PFM 14 Nov 26: the chooser lists only applications inside the paste; no fetch, PFM 3A).
    "apps" in the JSON: [{name, summary, steps: [step names]}]; without it, one application with every step."""
    names = [s['name'] for s in b['steps']]
    apps = b.get('apps') or [{'name': b.get('app', APP['name']), 'summary': b['title'], 'steps': names}]
    out = []
    for a in apps:
        idx = [names.index(n) for n in a['steps']]
        mode, version = a.get('mode', 'test'), a.get('version', '')
        assert mode != 'deploy' or version, 'app %r: a deploy needs a version' % a['name']
        # A deploy sends nothing (deploy v1, the Administrator 14 Nov 26), so it needs no Outlook check.
        need = set(BASE_CHECKS) - ({'outlook'} if mode == 'deploy' else set())
        for i in idx:
            for n in b['steps'][i].get('needs', []):
                assert n in CHECK_IDS, 'unknown check %r in step %r' % (n, names[i])
                need.add(n)
        checks = [c for c in CHECK_IDS if c in need]
        # "after": each step a step needs is in this app and runs before it. In a deploy, automatic steps come first
        # (deploy v1 item 3): a script step may follow a hand (guide) step only when it needs that step, directly or not.
        byname = {names[i]: b['steps'][i] for i in idx}
        def reach(n, seen=None):
            seen = seen if seen is not None else set()
            for d in byname[n].get('after', []):
                if d not in seen:
                    seen.add(d); reach(d, seen)
            return seen
        hand = []
        for i in sorted(idx):
            s = b['steps'][i]
            for d in s.get('after', []):
                if d not in byname or names.index(d) >= i:
                    raise SystemExit('app %r: step %r needs %r (after), which is not an earlier step of this app' % (a['name'], names[i], d))
            if s.get('kind') == 'guide':
                hand.append(names[i])
            elif mode == 'deploy' and hand and not (reach(names[i]) & set(hand)):
                raise SystemExit('app %r: automatic step %r comes after the hand step %r but does not need it: move it before, or name the step it needs in "after"' % (a['name'], names[i], hand[0]))
        # "marker": the app's install record on the site (one row of its own list). Plain names only: they go into a
        # command line and a CAML query. It needs the sign-in check, which reads it.
        mk = a.get('marker')
        marker = '$null'
        if mk:
            assert re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9 ]*', mk['list']) and re.fullmatch(r'[A-Za-z0-9]+', mk['key']) and re.fullmatch(r'[A-Za-z0-9_]+', mk['field']), 'app %r: marker list, key and field hold letters and digits only' % a['name']
            assert mode == 'deploy' and 'site-rights' in need, 'app %r: a marker needs mode deploy and a step that needs site-rights' % a['name']
            marker = '@{ List = %s; Key = %s; Field = %s }' % (q(mk['list']), q(mk['key']), q(mk['field']))
        # "start" (R28): the app's start script, a path inside its local install folder (OneDrive\\RADE\\<folder>). RADE's Start button runs
        # it in its own powershell.exe process after the checks pass; nothing is downloaded. Plain relative .ps1 paths only.
        start = a.get('start', '')
        assert not start or START_RE.fullmatch(start), 'app %r: start must be a relative .ps1 path of plain names (letters, digits, space, ".", "_", "-"), for example App/Start-App.ps1' % a['name']
        out.append('$apps += @{ Name = %s; Summary = %s; Steps = @(%s); Checks = @(%s); Mode = %s; Version = %s; Marker = %s; Start = %s }'
                   % (q(a['name']), q(a['summary']), ', '.join(str(i) for i in idx), ', '.join(q(c) for c in checks), q(mode), q(version), marker, q(start)))
    return out


ANSWER_KINDS = ('yesno', 'pick', 'text')


def answers_part(s):
    """The "answers" of a guide step (questions asked after Done; docs/engine.md "Step contract") as the end of its
    $steps line, or '' when it has none. A bad list stops the build (the schema says the same: scripts/check_manifest.py)."""
    if 'answers' not in s:
        return ''
    qs = s['answers']
    def no(why):
        raise SystemExit('step %r: answers: %s' % (s['name'], why))
    if s.get('kind', 'script') != 'guide':
        no('only a guide step (kind "guide") can ask questions')
    if not isinstance(qs, list) or not 1 <= len(qs) <= 4:
        no('1 to 4 questions, not %s' % (len(qs) if isinstance(qs, list) else type(qs).__name__))
    keys, out = set(), []
    for i, a in enumerate(qs, 1):
        if not isinstance(a, dict) or set(a) - {'key', 'prompt', 'kind', 'choices'}:
            no('question %d: only key, prompt, kind and choices' % i)
        key, prompt, kind, choices = a.get('key'), a.get('prompt'), a.get('kind'), a.get('choices')
        if not isinstance(key, str) or not re.fullmatch(r'[a-z][a-z0-9-]{0,23}', key):
            no('question %d: the key must be 1 to 24 lowercase letters, digits or "-", starting with a letter' % i)
        if key in keys:
            no('question %d: the key %r is used twice' % (i, key))
        keys.add(key)
        if not isinstance(prompt, str) or not 1 <= len(prompt) <= TEXT_LIMITS['answer prompt']:
            no('question %r: the prompt must have 1 to %d characters' % (key, TEXT_LIMITS['answer prompt']))
        if kind not in ANSWER_KINDS:
            no('question %r: the kind must be yesno, pick or text' % key)
        if kind == 'pick':
            if not isinstance(choices, list) or not 2 <= len(choices) <= 4 or not all(isinstance(c, str) and 1 <= len(c) <= TEXT_LIMITS['answer choice'] for c in choices):
                no('question %r: a pick needs 2 to 4 choices of 1 to %d characters' % (key, TEXT_LIMITS['answer choice']))
            if len({c.strip().lower() for c in choices}) != len(choices):
                no('question %r: the choices of a pick must differ (case and spaces ignored)' % key)
        elif 'choices' in a:
            no('question %r: only a pick has choices' % key)
        out.append('@{ Key = %s; Prompt = %s; Kind = %s; Choices = @(%s) }' % (q(key), q(prompt.strip()), q(kind), ', '.join(q(c.strip()) for c in choices or [])))
    return '; Answers = @(%s)' % ', '.join(out)


def build(b):
    parts = []
    for f in b['files']:
        src = ROOT / f['src']
        data = src.read_bytes()
        sha = hashlib.sha256(data).hexdigest()[:12]
        if src.suffix.lower() in TEXT:
            body, kind = here(data.decode('ascii')), 'text'
        else:
            b64 = base64.b64encode(data).decode('ascii')
            body, kind = "@'\n" + '\n'.join(textwrap.wrap(b64, 100)) + "\n'@", 'base64'
        parts.append("$files += @{ Dir = %s; Name = %s; Kind = '%s'; Sha = '%s'; Data = %s }"
                     % (q(f['dir']), q(src.name), kind, sha, body))
    # kind "guide": a step the PFM does in another program (guide lines, an address to open, a marker file on Done).
    steps = ['$steps += @{ Name = %s; Title = %s; Dir = %s; File = %s; Default = $%s; AskParam = %s; AskPrompt = %s; ScreenOnly = %s; Minutes = %d; Args = %s; Note = %s; Kind = %s; Guide = @(%s); Url = %s; UrlConfig = %s; Marker = %s; Estimate = %d; DoneText = %s; DoneLog = %s; Makes = @(%s); After = @(%s); Optional = $%s; Help = %s }'
             % (q(s['name']), q(s.get('title', '')), q(s['dir']), q(s['file']), 'true' if step_default(s) else 'false',
                q(s.get('ask', {}).get('param', '')), q(s.get('ask', {}).get('prompt', '')), q(s.get('screenOnly', '')),
                int(s.get('minutes', 30)), q(s.get('args', '')), q(s.get('note', '')), q(s.get('kind', 'script')),
                ', '.join(q(g) for g in s.get('guide', [])), q(s.get('url', '')), q(s.get('urlConfig', '')), q(s.get('marker', '')),
                int(s.get('estimate', 0)) * 60, q(s.get('doneText', '')), q(s.get('doneLog', '')),
                ', '.join('@{ kind = %s; name = %s }' % (q(m['kind']), q(m['name'])) for m in s.get('makes', [])), ', '.join(q(a) for a in s.get('after', [])),
                'true' if s.get('default', True) is False else 'false', q(s.get('help', '')))   # optional = "default": false only; a files-changed default is still a needed step
             for s in b['steps']]
    steps = [line[:-2] + answers_part(s) + ' }' for line, s in zip(steps, b['steps'])]   # a step without "answers": the line as before
    apps = app_lines(b)
    # Data files the round downloads (not code, PFM 3A): repo files from raw main, checked by SHA-256; public pages as they are.
    fetch = []
    for f in b.get('fetch', []):
        if 'src' in f:
            data = (ROOT / f['src']).read_bytes()
            # A tagged release (bundle "release") gives a fixed address; without it the file comes from main.
            url = 'https://raw.githubusercontent.com/' + APP['repo'] + '/' + b.get('release', 'main') + '/' + f['src']
            fetch.append((f['dir'], Path(f['src']).name, url, hashlib.sha256(data).hexdigest()))
        else:
            fetch.append((f['dir'], f['name'], f['url'], ''))
    fetchs = ['$fetch += @{ Dir = %s; Name = %s; Url = %s; Sha = %s }' % tuple(q(x) for x in t) for t in fetch]
    for s in b['steps']:
        assert (s.get('kind') == 'guide' and not s['file']) or any(f['dir'] == s['dir'] and Path(f['src']).name == s['file'] for f in b['files']), s
    collect = ['$collect += @{ Dir = %s; Name = %s; Step = %s }' % (q(c['dir']), q(c['name']), q(c.get('step', ''))) for c in b['collect']]
    cleanup = ['$cleanup += @{ Path = %s; Kind = %s }' % (q(c['path']), q(c['kind'])) for c in b.get('cleanup', [])]
    # Support scripts that keep their names (they load each other) and samples: made by 90-161.Z, so cleanup may recycle them.
    known = sorted({f.name for d, pat in APP['knownDirs'] for f in (ROOT / d).glob(pat)})
    logo = base64.b64encode(LOGO.read_bytes()).decode('ascii')   # the window's logo
    ui_text = UI_FILE.read_text(encoding='ascii')
    assert '@@' not in ui_text, 'engine/rade_ui.ps1 must not hold a placeholder'
    engine = ENGINE.replace('    @@UI@@', '\n'.join(('    ' + x) if x else x for x in ui_text.rstrip('\n').split('\n')))
    engine = engine.replace('@@HOME@@', APP['home']).replace('@@PREFIX@@', APP['prefix']).replace('@@APP@@', APP['folder'])
    own = '$ownPatterns = @(' + ', '.join(q(p) for p in APP['own']) + ')\n'
    go = q('https://raw.githubusercontent.com/' + APP['repo'] + '/main/go.md')
    rel = q('https://raw.githubusercontent.com/' + APP['repo'] + '/main/rade-release.json')
    body = ('$goUrl = %s\n$releaseUrl = %s\n$webAgent = \'Mozilla/5.0 (Windows NT 10.0; Win64; x64) RADE\'\n$logoPng = \'%s\'\n%s$round = %s\n$appFolder = %s\n$usersRoot = \'C:\\Users\'\n$files = @()\n%s\n$fetch = @()\n%s\n$steps = @()\n%s\n$collect = @()\n%s\n$cleanup = @()\n%s\n$known = @(%s)\n$apps = @()\n%s\n%s'
            % (go, rel, logo, own, q(b['round']), q(APP['folder']), '\n'.join(parts), '\n'.join(fetchs), '\n'.join(steps), '\n'.join(collect), '\n'.join(cleanup), ', '.join(q(k) for k in known), '\n'.join(apps), engine))
    build_id = hashlib.sha256(body.encode('ascii')).hexdigest()[:8]
    modes = {a.get('mode', 'test') for a in b.get('apps', [])} or {'test'}
    sends = ' on this computer. It sends nothing.' if modes == {'deploy'} else ', then opens an Outlook draft with them (never sent; a deploy makes no draft).' if 'deploy' in modes else ', then opens an Outlook draft with them (never sent).'
    head = ('<#\n  RADE, round bundle: %s.\n'
            '  GENERATED by the RADE engine (rhope-ops/RADE engine/rade_build.py, sha256 %s; engine/rade_ui.ps1, sha256 %s) from %s; do not edit.\n'
            '  How to run: open Windows PowerShell ISE, File > New, paste all of this text into the script pane, press F5.\n'
            '  The RADE window opens: press Enter (or Run); it uses your Windows profile folder. It writes the files below into the task folders under\n'
            '  C:\\Users\\<DODID>\\OneDrive - United States Air Force\\RADE\\%s (replacing older copies), runs the steps,\n'
            '  and saves its results in Rounds\\%s%s No download, no admin rights.\n'
            '#>\n$buildId = \'%s\'\n$engineRelease = %d\n' % (b['title'], ENGINE_SHA[:12], hashlib.sha256(ui_text.encode('ascii')).hexdigest()[:12], MANIFEST, APP['folder'], b['round'], sends, build_id, ENGINE_RELEASE))
    return head + body


# Text lengths (the Administrator, 2026-11-15; docs/window-design.md "Text lengths"). The most characters of each text an
# application gives the window, set from the real font (Segoe UI, measured in the window by the Windows job) and the
# narrowest card (604 px: 1280 x 800 at 150 % scaling). The window never cuts a part off: a longer text wraps or ends
# with "..." as the table in the document says. In this release a longer text is a WARNING line of the build, not a
# failure; a later release makes it a failure. This table is the one source: tests/engine_test.sh checks that the
# document has the same numbers.
TEXT_LIMITS = {'application name': 48, 'version': 14, 'summary': 150, 'step name': 56, 'step note': 200,
               'step title': 56, 'guide line': 100, 'guide lines': 10, 'doneText': 24, 'step help': 160, 'answer prompt': 120, 'answer choice': 40}


def text_lengths(b):
    """One WARNING line for each text of a bundle that is longer than its limit."""
    found = []
    def over(what, field, value):
        if isinstance(value, str) and len(value) > TEXT_LIMITS[field]:
            found.append('WARNING text length: %s: %s has %d characters, the limit is %d (docs/window-design.md "Text lengths")'
                         % (what, field, len(value), TEXT_LIMITS[field]))
    if not b.get('apps') and APP:
        over('application %r' % str(APP.get('name', ''))[:40], 'application name', APP.get('name'))
    for app in b.get('apps', []):
        what = 'application %r' % app.get('name', '')[:40]
        over(what, 'application name', app.get('name'))
        over(what, 'version', app.get('version'))
        over(what, 'summary', app.get('summary'))
    for st in b.get('steps', []):
        what = 'step %r' % st.get('name', '')[:40]
        over(what, 'step name', st.get('name'))
        over(what, 'step title', st.get('title'))
        over(what, 'step note', st.get('note'))
        over(what, 'doneText', st.get('doneText'))
        over(what, 'step help', st.get('help'))
        for g in st.get('guide', []):
            over(what, 'guide line', g)
        numbered = [g for g in st.get('guide', []) if isinstance(g, str) and re.match(r'\d+\.\s+\S', g)]
        if len(numbered) > TEXT_LIMITS['guide lines']:   # a count, not a length: more than the limit of numbered lines
            found.append('WARNING text length: %s: guide has %d numbered lines, the limit is %d (docs/window-design.md "Text lengths")'
                         % (what, len(numbered), TEXT_LIMITS['guide lines']))
    return found


def main():
    global ROOT, APP, MANIFEST
    import argparse
    ap = argparse.ArgumentParser(description='Build RADE round bundles for one application.')
    ap.add_argument('--app-root', help='the application repo root')
    ap.add_argument('--manifest', default='scripts/paste_bundles.json', help='manifest path inside the app repo')
    ap.add_argument('--check', action='store_true', help='exit 1 if a bundle is out of date')
    ap.add_argument('--sha', action='store_true', help="print this engine file's sha256 and exit")
    a = ap.parse_args()
    if a.sha:
        print(ENGINE_SHA); return
    if not a.app_root:
        ap.error('--app-root is required')
    ROOT, MANIFEST = Path(a.app_root).resolve(), a.manifest
    m = json.loads((ROOT / MANIFEST).read_text())
    APP = m['application']
    stale = 0
    for b in m['bundles']:
        out = ROOT / b['out']
        text = build(b)
        if a.check:
            if not out.exists() or out.read_bytes() != text.encode('ascii'):
                print('STALE ' + b['out']); stale += 1
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(text.encode('ascii'))
        print('BUILT %s bytes=%d files=%d steps=%d' % (b['out'], len(text), len(b['files']), len(b['steps'])))
        for line in text_lengths(b):
            print(line)
    if a.check:
        print('PASTE bundles=%d stale=%d' % (len(m['bundles']), stale))
        sys.exit(1 if stale else 0)


ENGINE_SHA = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
# The number of the next engine release (tag engine-v<N>); raise it before each release (docs/engine.md "Releases").
# The saved runner copy is replaced only by a bundle with a higher number (the Administrator, 2026-11-17).
ENGINE_RELEASE = 8
APP, MANIFEST = None, None

if __name__ == '__main__':
    main()
