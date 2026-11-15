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
The window has three screens (PFM 14 Nov 26, the base of the application deployment engine): 1 Choose the
application (the catalog embedded in the paste, "apps" in the JSON), 2 Check (this computer, network, site rights by CAC
sign-in, Power Automate by a look-and-answer window; each step's "needs" adds its checks), 3 Deploy with two bars
(overall, weighted by expected seconds, with time left; this step, from "PROGRESS n/m" lines or elapsed time). All text
the PFM sees is plain, simple English (PFM 14 Nov 26). R17 (PFM 14 Nov 26): every check and step row is two lines high
(the screen does not move while checks run), the bars are drawn by RADE (smooth, still when Windows animations are off),
and an Exit button closes the window (it asks first only while a step runs).
A catalog app of mode deploy (deploy v1, docs/engine.md; the Administrator 14 Nov 26) sends nothing: no draft, no saved
address; it updates RADE\\Config\\rade-installed.json (the version installed and the last deploy run).
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
LOGO = ENGINE_ROOT / 'assets/logo/logo-K-128.png'   # RADE's own logo (layout B rail)
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
function Test-WordOpen { return (@(Get-Process -Name WINWORD -ErrorAction SilentlyContinue).Count -gt 0) }
function Test-MailTo([string]$To) {
  $one = '[^@\s;,]+@[^@\s;,]+\.[^@\s;,]+'
  return ($To -match ('^\s*' + $one + '(\s*;\s*' + $one + ')*\s*;?\s*$'))
}
function Get-ConfigFile([string]$Base, [string]$Name) { return (Join-Path (Join-Path $Base 'Config') $Name) }
function Get-RadeConfigFile([string]$Name) { return (Join-Path (Join-Path (Get-RadePath) 'Config') $Name) }   # the engine's own settings (R17)
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
        $got = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($got -ne $f.Sha) { Remove-Item -LiteralPath $path -Force; throw 'the file changed since this round was built' }
      }
      $ok++; & $Say ('  Downloaded   ' + $f.Dir + '\' + $f.Name + '  (' + ('{0:N0}' -f (Get-Item -LiteralPath $path).Length) + ' bytes)')
    } catch {
      $bad++
      if (Test-Path -LiteralPath $path -PathType Leaf) { try { Remove-Item -LiteralPath $path -Force } catch { $null = $_ } }   # no partial file left behind
      & $Say ('  Download failed   ' + $f.Dir + '\' + $f.Name + ': ' + (ConvertTo-Masked $_.Exception.Message) + ' (save it from the repository instead)')
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
    $e = (Read-Installed)[(Get-InstalledKey $script:app)]
    if ($e) {
      if ($e.installed) { $inst = [string]$e.installed.version }
      $s = $e.steps[[string]$Step.Name]; if ($s -and [string]$s.version -eq [string]$script:app.Version) { $last = [string]$s.state }
    }
  }
  return [ordered]@{ RADE_CONTRACT = '1'; RADE_MODE = [string]$script:app.Mode; RADE_APP = [string]$script:app.Name; RADE_APP_VERSION = [string]$script:app.Version
    RADE_INSTALLED_VERSION = $inst; RADE_STEP_LAST = $last; RADE_SITE = [string](Get-SiteUrl $Base) }
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
  $r = @{ Pass = 0; Fail = 0; Skip = 0; Exit = $null; Made = @() }
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
    # Lines that may name a unit or a file (for example seal details) never reach the report (data boundary).
    if ($Step.ScreenOnly -and $line -match $Step.ScreenOnly) { $line = ($line -replace '^(\S+).*$', '$1') + ' (detail hidden: it may hold a name; run the step script by hand to see it)' }
    # "MADE <kind>: <name>": something the step created (a list, a flow, a file); kept for the undo list (step contract).
    # A MADE line is never a result: it is logged with the cleaned name and not counted as PASS, FAIL or SKIP (review).
    if ($line -cmatch '^\s*MADE\s+([a-z][a-z-]{0,30}):\s+(\S.*)$') {
      $mk = $Matches[1]; $mn = ConvertTo-MadeName $Matches[2] $siteNow; $r.Made += @{ kind = $mk; name = $mn }
      & $Say ('    MADE ' + $mk + ': ' + $mn); $lineTask = $p.StandardOutput.ReadLineAsync(); continue
    }
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
  if ($R.Skipped) { return ($Step.Name + ': SKIPPED by you') }
  if ($Step.Kind -eq 'guide' -and $R.FailText) { return ($Step.Name + ': FAILED (reported by you) in ' + (Format-Duration $Seconds) + ': ' + $R.FailText) }
  if ($Step.Kind -eq 'guide') { return ($Step.Name + ': ' + $state + ' (confirmed by you) in ' + (Format-Duration $Seconds)) }
  return ($Step.Name + ': ' + $state + ' (' + $R.Pass + ' passed, ' + $R.Fail + ' failed' + $(if ($R.Skip) { ', ' + $R.Skip + ' skipped' } else { '' }) + ', exit code ' + $R.Exit + ') in ' + (Format-Duration $Seconds))
}
function Copy-TextToClipboard([string]$Text) {
  try { [System.Windows.Forms.Clipboard]::SetText($Text); return $true } catch { $null = $_ }
  try { if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) { Set-Clipboard -Value $Text; return $true } } catch { $null = $_ }
  return $false
}
function Show-GuideDialog($Step, [string]$File, [string]$Url, [string]$UrlFile) {
  # A step done by the PFM in another program (for example a flow import): numbered instructions, the address to open
  # (editable, remembered in Config), the file path on the clipboard. Done = the PFM confirms; Skip = the step is skipped.
  $d = New-Object System.Windows.Forms.Form
  $d.Text = 'RADE - ' + $Step.Name
  $d.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96); $d.AutoScaleMode = 'Dpi'
  $d.Font = New-Object System.Drawing.Font('Segoe UI', 10)
  # R14 (PFM 14 Nov 26: the R13 window could not be minimized and covered the browser): a normal window that can be
  # minimized, never always-on-top, placed as a narrow panel at the right edge of the screen so the browser stays visible.
  $d.StartPosition = 'Manual'; $d.ClientSize = New-Object System.Drawing.Size(460, 640); $d.MinimumSize = New-Object System.Drawing.Size(380, 360)
  $d.MinimizeBox = $true; $d.MaximizeBox = $false; $d.ShowInTaskbar = $true; $d.TopMost = $false
  $g = New-Object System.Windows.Forms.TableLayoutPanel
  $g.AutoScroll = $true; $g.Padding = New-Object System.Windows.Forms.Padding(12); $g.ColumnCount = 1; $g.RowCount = 5; $g.Dock = 'Fill'
  $wrap = New-Object System.Drawing.Size(410, 0)
  $head = New-Object System.Windows.Forms.Label
  $head.AutoSize = $true; $head.MaximumSize = $wrap; $head.Text = $Step.Name
  try { $head.Font = New-Object System.Drawing.Font($d.Font.FontFamily, [single]11, [Enum]::Parse(('System.Drawing.FontStyle' -as [type]), 'Bold')) } catch { $null = $_ }
  $body = New-Object System.Windows.Forms.Label
  $body.AutoSize = $true; $body.MaximumSize = $wrap; $body.Margin = New-Object System.Windows.Forms.Padding(3, 8, 3, 8)
  $body.Text = (@($Step.Guide) -join "`r`n")
  $urlPanel = New-Object System.Windows.Forms.FlowLayoutPanel
  $urlPanel.AutoSize = $true; $urlPanel.WrapContents = $true; $urlPanel.MaximumSize = $wrap
  $urlLabel = New-Object System.Windows.Forms.Label
  $urlLabel.Text = 'Address to open:'; $urlLabel.AutoSize = $true; $urlLabel.Margin = New-Object System.Windows.Forms.Padding(3, 7, 3, 3)
  $urlBox = New-Object System.Windows.Forms.TextBox
  $urlBox.Width = 400; $urlBox.Text = $Url
  $urlPanel.Controls.AddRange(@($urlLabel, $urlBox))
  $btns = New-Object System.Windows.Forms.FlowLayoutPanel
  $btns.AutoSize = $true; $btns.WrapContents = $true; $btns.MaximumSize = $wrap
  $mk = { param($text) $b = New-Object System.Windows.Forms.Button; $b.Text = $text; $b.AutoSize = $true; $b.MinimumSize = New-Object System.Drawing.Size(110, 32); $b }
  $openB = & $mk 'Open in browser'
  $copyB = & $mk 'Copy file path'
  $showB = & $mk 'Show file in folder'
  $doneB = & $mk $(if ($Step.DoneText) { $Step.DoneText } else { 'Done: the run has started' })
  $skipB = & $mk $(if ($Step.SkipText) { $Step.SkipText } else { 'Skip this step' })
  $doneB.DialogResult = 'OK'; $skipB.DialogResult = 'Cancel'
  # A check (no file) has a third answer, No: what the PFM saw shows a problem. A file step (R18, PFM 14 Nov 26: in R17 both
  # imports failed and the only way out was Skip) has It failed: the error text from the box goes into the log and the e-mail.
  $script:guideError = ''
  $errLabel = New-Object System.Windows.Forms.Label
  $errLabel.AutoSize = $true; $errLabel.MaximumSize = $wrap; $errLabel.Margin = New-Object System.Windows.Forms.Padding(3, 8, 3, 3)
  $errLabel.Text = 'If it failed, paste the error message here (no names or site address), then select "It failed"'
  $errBox = New-Object System.Windows.Forms.TextBox
  $errBox.Multiline = $true; $errBox.ScrollBars = 'Vertical'; $errBox.Width = 400; $errBox.Height = 72; $errBox.AccessibleName = 'Error message'
  $failB = & $mk 'It failed'
  $failB.DialogResult = 'Abort'
  $failB.Add_Click({ $script:guideError = [string]$errBox.Text })
  if ($File) { $btns.Controls.AddRange(@($openB, $copyB, $showB, $doneB, $failB, $skipB)) }
  elseif ($Step.NoText) { $noB = & $mk $Step.NoText; $noB.DialogResult = 'No'; $btns.Controls.AddRange(@($openB, $doneB, $noB, $skipB)) }
  else { $btns.Controls.AddRange(@($openB, $doneB, $failB, $skipB)) }   # a round step with no file (R18: the export step)
  $note = New-Object System.Windows.Forms.Label
  $note.AutoSize = $true; $note.MaximumSize = $wrap
  if (-not $File) { $note.Text = $(if ($Step.NoText) { 'No file is needed for this check.' } else { 'No file is needed for this step.' }) }
  else { $note.Text = $(if (Copy-TextToClipboard $File) { 'The full path of ' + $Step.File + ' is on the clipboard.' } else { 'Select Copy file path to put the path of ' + $Step.File + ' on the clipboard.' }) }
  $parts = @($head, $body, $urlPanel, $note); if (-not $Step.NoText) { $parts += @($errLabel, $errBox) }; $parts += $btns
  $g.RowCount = $parts.Count
  $row = 0; foreach ($c in $parts) { $g.Controls.Add($c, 0, $row); $row++ }
  $d.Controls.Add($g)
  $openB.Add_Click({
    $u = $urlBox.Text.Trim()
    if ($u -notmatch '^https://') { $note.Text = 'The address must start with https://'; return }
    try { if ($UrlFile) { Set-Content -LiteralPath $UrlFile -Value $u -Encoding UTF8 } } catch { $null = $_ }
    try { Start-Process -FilePath $u; $note.Text = 'Opened in your browser. Complete the steps above, then select "Done"' } catch { $note.Text = 'The browser could not be opened: ' + $_.Exception.Message }
  })
  $copyB.Add_Click({ $note.Text = $(if (Copy-TextToClipboard $File) { 'File path copied. Press Ctrl+V in the "File name" box' } else { 'The clipboard is busy. Select Copy file path again.' }) })
  $showB.Add_Click({ Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"' + $File + '"') })
  $d.CancelButton = $skipB
  $d.Add_Shown({
    try { $wa = [System.Windows.Forms.Screen]::FromControl($d).WorkingArea; $d.Height = [Math]::Min($d.Height, $wa.Height); $d.Left = $wa.Right - $d.Width; $d.Top = $wa.Top } catch { $null = $_ }
    $openB.Focus() | Out-Null })   # Enter on the focused button opens the browser; Done needs a deliberate click
  $res = [string]$d.ShowDialog()
  $d.Dispose()
  return $res   # OK = Done or Yes, No = a check found a problem, Abort = It failed ($script:guideError), Cancel = Skip or closed
}
function Invoke-GuideStep([string]$Base, $Step, [scriptblock]$Say) {
  $r = @{ Pass = 0; Fail = 0; Exit = 0; Skipped = $false; FailText = '' }
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
  } else { $res = [string](Show-GuideDialog $Step $file $url $urlFile) }
  $ok = ($res -eq 'OK')
  if ($res -eq 'Abort') {
    $t = ((ConvertTo-Masked ([string]$script:guideError)) -replace '\s+', ' ').Trim()
    $t = $t -replace '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '<EMAIL>'   # e-mail first: the site rule would leave the name before @
    $t = $t -replace 'https?://\S+', '<SITE>' -replace '[A-Za-z0-9.-]+\.(sharepoint|sharepoint-mil|onmicrosoft)\.[A-Za-z.]+\S*', '<SITE>'   # no address reaches the e-mail
    if ($t.Length -gt 600) { $t = $t.Substring(0, 600) + ' ...' }
    if (-not $t) { $t = 'no error text given' }
    $r.Fail = 1; $r.FailText = $t
    & $Say ('    Failed (reported by you): ' + $t)
  } elseif ($ok) {
    if ($Step.Marker) { try { Set-Content -LiteralPath (Join-Path $dir $Step.Marker) -Value (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -Encoding UTF8 } catch { $null = $_ } }
    $r.Pass = 1
    & $Say ('    ' + $(if ($Step.DoneLog) { $Step.DoneLog } else { 'Confirmed by you: the flow is imported and its run has started.' }))
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
# ---- Installed versions (the Administrator, 14 Nov 26, deploy v1): RADE\Config\rade-installed.json keeps, per app, the
# version a deploy last installed and the last deploy run. It holds no user name, path, site or DODID. A deploy run sends
# nothing: no e-mail draft, no saved address; its report stays in Rounds\<round> on this computer.
function Get-InstalledKey($A) { return ($appFolder + '/' + [string]$A.Name) }
function ConvertTo-InstalledRun($V) {
  if ($null -eq $V) { return $null }
  $at = $V.at; if ($at -is [datetime]) { $at = $at.ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture) }   # PowerShell 7 reads it as a date
  $o = [ordered]@{ version = [string]$V.version; build = [string]$V.build; round = [string]$V.round; at = [string]$at }
  if ($null -ne $V.state) { $o.state = [string]$V.state }
  return $o
}
function Read-Installed {
  $res = @{}
  $p = Get-RadeConfigFile 'rade-installed.json'
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $res }
  try {
    $j = [System.IO.File]::ReadAllText($p) | ConvertFrom-Json
    foreach ($c in @($j.apps.PSObject.Properties)) {
      $st = [ordered]@{}
      if ($c.Value.steps) { foreach ($s in @($c.Value.steps.PSObject.Properties)) {
        $at = $s.Value.at; if ($at -is [datetime]) { $at = $at.ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture) }
        $made = @(); foreach ($m in @($s.Value.made)) { if ($null -ne $m) { $made += [ordered]@{ kind = [string]$m.kind; name = [string]$m.name } } }
        $st[$s.Name] = [ordered]@{ state = [string]$s.Value.state; version = [string]$s.Value.version; at = [string]$at; made = $made }
      } }
      $res[$c.Name] = [ordered]@{ installed = (ConvertTo-InstalledRun $c.Value.installed); lastRun = (ConvertTo-InstalledRun $c.Value.lastRun); steps = $st }
    }
  } catch { $res = @{} }   # a damaged file reads as nothing installed
  return $res
}
function Get-InstalledText($A) {
  # One short text for the Choose card and the log; '' for an app that is not a deploy.
  if ([string]$A.Mode -ne 'deploy') { return '' }
  $e = (Read-Installed)[(Get-InstalledKey $A)]
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
    $p = Get-RadeConfigFile 'rade-installed.json'
    if ((Test-Path -LiteralPath $p -PathType Leaf)) {
      $bad = $false; try { $null = [System.IO.File]::ReadAllText($p) | ConvertFrom-Json } catch { $bad = $true }
      if ($bad) { Copy-Item -LiteralPath $p -Destination ($p + '.damaged') -Force }   # keep what was there before it is replaced
    }
    $all = Read-Installed
    $key = Get-InstalledKey $script:app
    $run = [ordered]@{ version = [string]$script:app.Version; build = [string]$buildId; round = [string]$round; at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture) }
    $inst = $null; if ($all.ContainsKey($key)) { $inst = $all[$key].installed }
    if ($State -eq 'PASSED' -and $Whole) { $inst = [ordered]@{ version = $run.version; build = $run.build; round = $run.round; at = $run.at } }
    $run.state = $State
    $st = [ordered]@{}; if ($all.ContainsKey($key) -and $all[$key].steps) { $st = $all[$key].steps }
    if ($StepRecs) { foreach ($n in @($StepRecs.Keys)) {
      $made = @(); $seen = @{}
      $old = @(); if ($st.Contains($n)) { $old = @($st[$n].made) }
      foreach ($m in ($old + @($StepRecs[$n].made))) { if ($null -eq $m) { continue }; $id = [string]$m.kind + '|' + [string]$m.name; if (-not $seen[$id]) { $seen[$id] = $true; $made += [ordered]@{ kind = [string]$m.kind; name = [string]$m.name } } }
      $st[$n] = [ordered]@{ state = [string]$StepRecs[$n].state; version = $run.version; at = $run.at; made = $made }
    } }
    $all[$key] = [ordered]@{ installed = $inst; lastRun = $run; steps = $st }
    $sorted = [ordered]@{}; foreach ($k in @($all.Keys | Sort-Object)) { $sorted[$k] = $all[$k] }
    $doc = [ordered]@{
      schema = 'rade-installed/1'
      about = 'Versions RADE installed on this computer, by app (folder/name). "installed" is the last deploy in which every step ran and PASSED; "lastRun" is the last deploy run and its state; "steps" holds each step''s last state and what it made. No user, path or site is kept here.'
      apps = $sorted
    }
    $dir = Split-Path -Parent $p
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    [System.IO.File]::WriteAllText($p, ($doc | ConvertTo-Json -Depth 9), (New-Object System.Text.UTF8Encoding $false))
    return ''
  } catch { return (ConvertTo-Masked $_.Exception.Message) }
}
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
  $whole = $true; foreach ($k in $script:appSteps) { if (-not $Selected[$k]) { $whole = $false } }
  $stepRecs = @{}
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
  & $speak ('RADE (Redacted Application Deployment Engine), round ' + $round + ' (build ' + $buildId + '), started ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
  $base = Move-ToRade $speak
  & $speak ('Working folder: ' + (ConvertTo-Masked $base))
  if ($modeLine) { & $speak $modeLine }
  if ($script:noWindowWhy) { & $speak ('Note: no window could open, so the round runs in text mode. Reason: ' + (ConvertTo-Masked $script:noWindowWhy)) }
  if (Test-WordOpen) { & $speak 'Note: Word is open. Renders use Word: save your documents and close Word if a step stops.' }
  & $speak ''
  Write-BundleFile $base $speak
  if ($script:closing) { throw 'the window was closed (Exit) while the round ran; no step ran' }
  $fl = Save-RoundDownload $base $speak
  if ($fl) { $summary += $fl }
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
    if (-not $Selected[$k]) { if ($script:appSteps -contains $k) { $summary += ($steps[$k].Name + ': not selected') }; continue }
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
    if ($steps[$k].Kind -eq 'guide') { $r = Invoke-GuideStep $base $steps[$k] $speak }
    else { $r = Invoke-RoundStep $base $steps[$k] $speak $Tick $ans }
    if ((Get-StepState $r) -ne 'SKIPPED') { $script:ranSteps += $steps[$k].Name }   # a step you skip, or one that only printed SKIP, expects no result files
    $secs = ((Get-Date) - $t0).TotalSeconds
    $state = Get-StepState $r
    if ($state -eq 'NEEDS REVIEW') { $script:roundBad = $true }
    if ($state -ne 'PASSED') { $whole = $false }   # a skipped step is not installed (review, deploy v1)
    $made = @($r.Made | Where-Object { $_ }); if ($state -eq 'PASSED') { foreach ($m in @($steps[$k].Makes)) { $made += @{ kind = [string]$m.kind; name = [string]$m.name } } }
    $stepRecs[[string]$steps[$k].Name] = @{ state = $state; made = $made }
    $line = Get-StepLine $steps[$k] $r $secs
    $summary += $line
    & $speak ('  Result: ' + ($line.Substring($steps[$k].Name.Length + 2)))
    $script:prog.Done += $script:prog.Cur; $script:prog.Cur = 0; $script:prog.Frac = -1
    & $OnStep $k $line
    Add-RoundHistory $base $steps[$k].Name $(if ($state -eq 'PASSED') { 'OK' } else { 'CHECK' }) ([int]$secs)
  }
  & $speak ''
  if ($script:closing) { throw 'the window was closed (Exit) while the round ran' }
  $summary += (Get-FolderInventory $base)
  } catch {
    # A run that stops midway still leaves a report to send (summary so far + the log up to the stop).
    $summary[0] = '@@PREFIX@@ ' + $round + ' STOPPED'
    $summary += ('STOPPED: ' + (ConvertTo-Masked ([string]$_)))
    if ($deploy) { $sv = Save-Installed 'STOPPED' $whole $stepRecs; if ($sv) { $summary += ('NOTE: the installed-version record could not be saved: ' + $sv) } }
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
    if ($sv) { & $speak ('NOTE: the installed-version record (RADE\Config\rade-installed.json) could not be saved: ' + $sv) }
    if ($bad) { & $speak ('Note: one or more items need review (see above). The report in Rounds\' + $round + ' shows what went wrong. Nothing was sent.') }
    elseif (-not $whole) { & $speak ('Note: some steps were off or skipped, so version ' + $script:app.Version + ' is not recorded as installed. Run again with every step on.') }
    else { & $speak ('Version ' + $script:app.Version + ' of ' + $script:app.Name + ' is recorded as installed.') }
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
function Get-CheckDef([string]$Id) { foreach ($d in $checkDefs) { if ($d.Id -eq $Id) { return $d } }; return $null }
function Get-SiteUrl([string]$Base) {
  # Config\@@PREFIX@@-site.txt: the same file T16 site setup keeps (one place for the site address; never in the repo).
  $p = Get-ConfigFile $Base '@@PREFIX@@-site.txt'
  if (Test-Path -LiteralPath $p -PathType Leaf) { try { return ([string](Get-Content -LiteralPath $p -TotalCount 1)).Trim() } catch { return '' } }
  return ''
}
$sitePrefix = 'https://usaf.dps.mil/sites/'   # the DAF SharePoint address every site starts with; the box starts with it
function Test-SiteUrl([string]$Url) { return ($Url -match '^https://[^/\s"]+/sites/[^/\s"]+/?$') }
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
param([string]$Site)
# RADE check (read-only): signs in with the CAC (web login, as T16 does) and prints your rights on the site.
# Prints only right names and True/False, never the site, your name or an error message.
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
  exit 0
} catch { 'RESULT not-connected ' + $_.Exception.GetType().Name; exit 2 }
'@
$rightWords = @{ ViewListItems = 'read items'; AddListItems = 'add items'; EditListItems = 'edit items'; ManageLists = 'manage lists'; ManageWeb = 'manage the site'; ManagePermissions = 'manage permissions' }
$rightsNeeded = @('ManageLists', 'ManageWeb', 'ManagePermissions')   # what T16 site setup and list set-up use
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
        if (-not (Test-SiteUrl $Site)) { $one = Format-CheckResult 'NOT RUN' 'No site address' 'Complete the "Site address" box, then select "Run checks again"' }
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
        if (-not (Test-SiteUrl $Site)) { $one = Format-CheckResult 'NOT RUN' 'No site address' 'Complete the "Site address" box first' }
        else {
          $r = Invoke-ChildScript $rightsScript ('-Site "' + $Site + '"') 300 $Tick
          $have = @{}
          foreach ($l in $r.Lines) { if ($l -match '^RIGHT (\w+) (True|False)$') { $have[$Matches[1]] = ($Matches[2] -eq 'True') } }
          if (-not $have.Count) {
            $why = 'Sign-in did not finish'; foreach ($l in $r.Lines) { if ($l -match '^RESULT (\S+)') { $why = $Matches[1] } }
            if ($why -eq 'not-connected') { $why = 'Sign-in did not finish' }
            if ($why -eq 'no-pnp') { $one = Format-CheckResult 'FAILED' 'SharePoint tool not installed' 'See the SharePoint tool check' }
            else { $one = Format-CheckResult 'FAILED' ($why + $(if ($r.Why) { ', ' + $r.Why } else { '' })) 'Select "Sign in and check site rights" and complete the CAC sign-in' }
          } else {
            $miss = @($rightsNeeded | Where-Object { -not $have[$_] } | ForEach-Object { $rightWords[$_] })
            $got = @($have.Keys | Sort-Object | Where-Object { $have[$_] } | ForEach-Object { $rightWords[$_] })
            if ($miss.Count) { $one = Format-CheckResult 'FAILED' ('Missing: ' + ($miss -join ', ')) 'Ask a site owner to add you to the site Owners group' }
            else { $one = Format-CheckResult 'PASSED' ('Rights: ' + ($got -join ', ')) '' }
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
          $a = Show-GuideDialog $g '' $fp.Url $fp.Config
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
$checkNoSave = @('word', 'disk', 'write')
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
  # Two lines (the Administrator, 2026-11-14): "Last check: DD-MM-YY", then what that check found; no full stops.
  $d0 = [datetime]::ParseExact($c.At, 'yyyy-MM-ddTHH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
  $found = ([string]$c.Detail) -replace '\.$', ''; if ($found) { $found = $found.Substring(0, 1).ToUpperInvariant() + $found.Substring(1) }
  return @{ State = 'PASSED'; Detail = ('Last check: ' + $d0.ToString('dd-MM-yy', [System.Globalization.CultureInfo]::InvariantCulture)); Fix = $found; Saved = $true; Found = $found }
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
    $dir = Split-Path -Parent $p
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    [System.IO.File]::WriteAllText($p, ($doc | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding $false))
  } catch { $null = $_ }   # saving is a convenience: never stop for it
}
function Get-CheckToRun($Def, $Cache, [string]$Base, [string]$Site, [bool]$Force) {
  # $null = run it now; else the saved result to show.
  if ($Force) { return $null }
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
function Get-ProgressText($G, [string]$Name) {
  $p = $script:prog
  $all = 'Overall: step ' + $p.Index + ' of ' + $p.Count + ', ' + [int]($G.All * 100) + ' % done, about ' + (Format-Duration $G.Left) + ' left (' + $(if ($G.Known) { 'based on your last runs' } else { 'a guess: no earlier runs' }) + ')'
  $one = 'This step: ' + $Name + '   ' + (Format-Duration $G.Elapsed)
  if ($p.Frac -ge 0) { $one += '   (' + $p.FracText + ', ' + [int]($p.Frac * 100) + ' %)' }
  elseif ($p.CurKnown) { $one += '   (last time it took ' + (Format-Duration $p.Cur) + ')' }
  else { $one += '   (first time: no time estimate yet)' }
  # Layout P1 (the Administrator, 2026-11-14): one line over each bar, what on the left, how far on the right.
  $allR = [string][int]($G.All * 100) + ' %' + $dot + 'about ' + (Format-Duration $G.Left) + ' left (' + $(if ($G.Known) { 'based on your last runs' } else { 'a guess: no earlier runs' }) + ')'
  $stepR = $(if ($p.Frac -ge 0) { $p.FracText + ', ' + [int]($p.Frac * 100) + ' %' } elseif ($p.CurKnown) { 'last time ' + (Format-Duration $p.Cur) } else { 'first time: no estimate yet' })
  return @{ All = $all; Step = $one; AllL = ('Overall' + $dot + 'step ' + $p.Index + ' of ' + $p.Count); AllR = $allR; StepL = ('This step: ' + $Name + $dot + (Format-Duration $G.Elapsed)); StepR = $stepR }
}
$script:secret = @(); $script:dodid = ''; $script:child = $null; $script:runLog = $null; $script:resultsDir = ''; $script:draftMade = $false; $script:textMode = $false; $script:helped = @{}; $stepMinutes = 30
$script:statusBase = ''; $script:stepStart = $null; $script:stepEst = 0; $script:noWindowWhy = ''; $script:ranSteps = @(); $script:prog = $null; $script:roundStart = Get-Date
$script:checkResults = @{}; $script:closing = $false; $checkGate = $true   # tests turn the gate off to run steps
$script:checkHost = $null; $script:savedWhy = @{}
function Select-App([int]$I) {
  # The chosen application: its steps and the checks they need (the embedded catalog; PFM 14 Nov 26: no fetch, 3A).
  $script:app = $apps[$I]; $script:appSteps = @($script:app.Steps); $script:appChecks = @($script:app.Checks); $script:checkResults = @{}
}
Select-App 0
function Get-AppText($A, $Hist) {
  # Choose screen: the summary, then one line of facts (steps, time, checks).
  $est = 0; $known = $true; $you = 0
  foreach ($k in $A.Steps) { $w = Get-StepWeight $Hist $steps[$k]; $est += $w.Seconds; if (-not $w.Known) { $known = $false }; if ($steps[$k].Kind -eq 'guide') { $you++ } }
  $min = [math]::Max(1, [int][math]::Round($est / 60))
  return @{ Summary = $A.Summary
    Meta = (@($A.Steps).Count.ToString() + ' steps' + $(if ($you) { ' (' + $you + $(if ($you -eq 1) { ' needs you)' } else { ' need you)' }) } else { '' }) + $dot + 'about ' + $min + ' min' + $(if ($known) { '' } else { ' (a guess)' }) + $dot + @($A.Checks).Count + ' checks before you deploy' + $(if ([string]$A.Mode -eq 'deploy') { $dot + (Get-InstalledText $A) } else { '' })) }
}
function Get-CheckColor([string]$State) {
  # One meaning per color, with the word always shown too. Contrast PASSED, WARNING, FAILED, NOT RUN: on white 7.4, 7.1,
  # 10.0, 5.5 to 1; on the gray window background (#F0F0F0) 6.5, 6.2, 8.8, 4.8 to 1 (WCAG AA text: 4.5).
  $n = @{ PASSED = 'DarkGreen'; WARNING = 'SaddleBrown'; FAILED = 'DarkRed'; 'NOT RUN' = 'DimGray'; RUNNING = 'Navy' }[$State]
  if (-not $n) { $n = 'Black' }
  return (('System.Drawing.Color' -as [type])::FromName($n))
}
$gui = $true
try { Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing } catch { $gui = $false; $script:noWindowWhy = 'Windows Forms not available: ' + $_.Exception.Message }
if ($gui) {
  try {
    # Three screens in one window (PFM 14 Nov 26, the base of the application deployment engine): 1 Choose the application,
    # 2 Check this computer and your rights, 3 Deploy with two progress bars. Layout follows the font and screen scaling
    # (R02): rows in a TableLayoutPanel, no fixed positions.
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $basePath = Get-BasePath
    $hist0 = Read-RoundHistory $basePath
    $bold = $null; try { $bold = [Enum]::Parse(('System.Drawing.FontStyle' -as [type]), 'Bold') } catch { $null = $_ }
    $mkLabel = { param($text) $l = New-Object System.Windows.Forms.Label; $l.AutoSize = $true; $l.MaximumSize = $wrap; $l.Text = $text; $l }
    $mkButton = { param($text) $b = New-Object System.Windows.Forms.Button; $b.Text = $text; $b.AutoSize = $true; $b.MinimumSize = New-Object System.Drawing.Size(132, 34); $b }   # one button height: 34 (layout P1)
    $mkRows = { param([string[]]$Heights)
      $t = New-Object System.Windows.Forms.TableLayoutPanel
      $t.Dock = 'Fill'; $t.ColumnCount = 1; $t.RowCount = $Heights.Count; $t.Margin = New-Object System.Windows.Forms.Padding(0)
      [void]$t.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
      foreach ($h in $Heights) { [void]$t.RowStyles.Add((New-Object System.Windows.Forms.RowStyle($h, 100))) }
      $t }
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'RADE (Redacted Application Deployment Engine) - ' + $round + ' - build ' + $buildId
    $form.SuspendLayout()
    $form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96); $form.AutoScaleMode = 'Dpi'   # sizes below are at 100 % scaling
    $form.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $form.ClientSize = New-Object System.Drawing.Size(1020, 760)   # PFM 14 Nov 26: wide enough for little wrapping, not wider; $form.MinimumSize = New-Object System.Drawing.Size(680, 540)
    $form.StartPosition = 'CenterScreen'; $form.KeyPreview = $true
    $wrap = New-Object System.Drawing.Size(760, 0)   # layout B: the main area is the window less the 220 px rail
    $script:secret = Get-Secret (Get-ProfileLeaf) (Get-ProfileLeaf)   # saved checks are masked before they are written
    # R17 (PFM 14 Nov 26): rows and status lines have a fixed height (two lines), so nothing moves while checks and steps run.
    # $lineH is in screen pixels (grid rows, added after layout). Controls sized before layout are scaled by Windows for the
    # screen (AutoScaleMode Dpi), so they use $lineH96, the same height at 100 % (96 DPI).
    $lineH = [int][System.Windows.Forms.TextRenderer]::MeasureText('Ag', $form.Font).Height
    $dpi = 96.0; try { $gx = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero); $dpi = [double]$gx.DpiX; $gx.Dispose() } catch { $null = $_ }
    $at96 = { param([double]$Px) [int][math]::Ceiling($Px * 96.0 / $dpi) }
    $lineH96 = & $at96 $lineH
    $fitText = { param([string]$Text, $Font, [int]$Width)
      # One line that fits $Width pixels: whole words, then " ..." (the full text is in the tooltip and the log).
      $Text = ([string]$Text -replace '\s+', ' ').Trim()
      if (-not $Text -or $Width -lt 40) { return $Text }
      if ([System.Windows.Forms.TextRenderer]::MeasureText($Text, $Font).Width -le $Width) { return $Text }
      $words = @($Text -split ' '); $lo = 1; $hi = $words.Count - 1; $best = $words[0] + ' ...'
      while ($lo -le $hi) {
        $mid = [int][math]::Floor(($lo + $hi) / 2); $s = (($words[0..($mid - 1)]) -join ' ') + ' ...'
        if ([System.Windows.Forms.TextRenderer]::MeasureText($s, $Font).Width -le $Width) { $best = $s; $lo = $mid + 1 } else { $hi = $mid - 1 }
      }
      return $best }
    $setCell = { param($Cell, [string]$A, [string]$B)
      # A two-line cell: line 1 and line 2 each cut to the column width; the full text is the tooltip.
      $Cell.Tag = @($A, $B)
      $w = $Cell.OwningColumn.Width - 12; $f = $Cell.DataGridView.Font
      $Cell.Value = (& $fitText $A $f $w) + "`r`n" + (& $fitText $B $f $w)
      $Cell.ToolTipText = ((@($A, $B) | Where-Object { $_ }) -join "`r`n") }
    $refit = { param($View, [int]$Col)
      foreach ($r in $View.Rows) { $c = $r.Cells[$Col]; if ($c.Tag -is [array]) { & $setCell $c $c.Tag[0] $c.Tag[1] } } }
    # Layout A "Quiet table" (the Administrator, 2026-11-14; docs/window-design.md): white main area, borderless grids with
    # row lines only, two-line cells drawn in two styles, results as tinted chips (the word always shown).
    $ink = [System.Drawing.Color]::FromArgb(27, 36, 48); $soft = [System.Drawing.Color]::FromArgb(90, 101, 115)   # 15.6 and 5.9 to 1 on white
    $hairline = [System.Drawing.Color]::FromArgb(227, 232, 238)
    $smallFont = $form.Font; try { $smallFont = New-Object System.Drawing.Font($form.Font.FontFamily, [single]9) } catch { $null = $_ }   # type scale (layout P1): 20 b, 15 sb, 11, 10, 10 b, 9, chips 8.5 b
    $semiFont = $form.Font; try { $semiFont = New-Object System.Drawing.Font($form.Font.FontFamily, [single]10, $bold) } catch { $null = $_ }
    $chipFont = $smallFont; try { $chipFont = New-Object System.Drawing.Font($form.Font.FontFamily, [single]8.5, $bold) } catch { $null = $_ }
    $smallBold = $smallFont; try { $smallBold = New-Object System.Drawing.Font($form.Font.FontFamily, [single]9, $bold) } catch { $null = $_ }
    $linkFont = $semiFont; try { $linkFont = New-Object System.Drawing.Font($form.Font.FontFamily, [single]10, [Enum]::Parse(('System.Drawing.FontStyle' -as [type]), 'Bold, Underline')) } catch { $null = $_ }   # links: underlined, not color alone
    $titleFont = $form.Font; try { $titleFont = New-Object System.Drawing.Font('Segoe UI Semibold', [single]15) } catch { $null = $_ }
    $subFont = $smallFont
    # Line heights in screen pixels; $sc turns a size at 100 % into screen pixels for controls made after the window shows.
    $lineS = [int][System.Windows.Forms.TextRenderer]::MeasureText('Ag', $smallFont).Height
    $lineB = [int][System.Windows.Forms.TextRenderer]::MeasureText('Ag', $semiFont).Height
    $sc = { param([double]$Px) [int][math]::Round($Px * $dpi / 96.0) }
    $paleEdge = [System.Drawing.Color]::FromArgb(201, 210, 220); $rowLine = [System.Drawing.Color]::FromArgb(238, 241, 244)
    $roundRect = { param([int]$X, [int]$Y, [int]$W, [int]$H, [int]$R)
      # A rounded rectangle; R = H / 2 gives a pill (bars, chips).
      $d = [math]::Max(1, [math]::Min(2 * $R, [math]::Min($W, $H))); $pa = New-Object System.Drawing.Drawing2D.GraphicsPath
      $pa.AddArc($X, $Y, $d, $d, 180, 90); $pa.AddArc($X + $W - $d, $Y, $d, $d, 270, 90); $pa.AddArc($X + $W - $d, $Y + $H - $d, $d, $d, 0, 90); $pa.AddArc($X, $Y + $H - $d, $d, $d, 90, 90); $pa.CloseFigure(); $pa }
    # Chip tints; text colors from Get-CheckColor (contrast on the tint: green 6.8, brown 6.0, red 8.6, gray 4.9, navy 13 to 1).
    $chipTint = @{ PASSED = @(230, 242, 234); WARNING = @(248, 237, 227); FAILED = @(248, 230, 230); 'NEEDS REVIEW' = @(248, 230, 230); RUNNING = @(227, 236, 246) }
    $chipInk = @{ 'NEEDS REVIEW' = 'FAILED'; WAITING = 'NOT RUN'; SKIPPED = 'NOT RUN'; OFF = 'NOT RUN' }
    $flags1 = [System.Windows.Forms.TextFormatFlags]'Left, Top, NoPrefix, SingleLine'
    $drawChip = { param($G, [string]$St, [int]$X, [int]$Top, [int]$H)
      # A tinted pill with the state word, centered in the band Top..Top+H (the word is always shown: one meaning per color).
      if (-not $St) { return }
      $tc = $chipTint[$St]; if (-not $tc) { $tc = @(238, 241, 244) }
      $ik = $chipInk[$St]; if (-not $ik) { $ik = $St }
      $sz = [System.Windows.Forms.TextRenderer]::MeasureText($St, $chipFont)
      $ch = $sz.Height + 4; $cw = [math]::Max($ch, $sz.Width + 12); $y = $Top + [int](($H - $ch) / 2)
      $path = & $roundRect $X $y $cw $ch ([int]($ch / 2))
      $old = $G.SmoothingMode; $G.SmoothingMode = 'AntiAlias'
      $br = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($tc[0], $tc[1], $tc[2])); $G.FillPath($br, $path); $br.Dispose(); $path.Dispose()
      $G.SmoothingMode = $old
      [System.Windows.Forms.TextRenderer]::DrawText($G, $St, $chipFont, (New-Object System.Drawing.Rectangle($X, $y, $cw, $ch)), (Get-CheckColor $ik), [System.Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, NoPrefix, SingleLine') }
    $paintCell = { param($V, $E)
      try {
        if ($E.ColumnIndex -lt 0) { return }
        $col = $V.Columns[$E.ColumnIndex]; $kind = [string]$col.Tag; $g = $E.Graphics; $r = $E.CellBounds
        if ($E.RowIndex -lt 0) {   # header: white, bold gray words, one hairline under it
          $g.FillRectangle([System.Drawing.Brushes]::White, $r)
          $hp = New-Object System.Drawing.Pen($hairline); $g.DrawLine($hp, $r.Left, $r.Bottom - 1, $r.Right, $r.Bottom - 1); $hp.Dispose()
          [System.Windows.Forms.TextRenderer]::DrawText($g, [string]$col.HeaderText, $V.ColumnHeadersDefaultCellStyle.Font, (New-Object System.Drawing.Rectangle(($r.Left + 6), $r.Top, [math]::Max(1, $r.Width - 8), $r.Height)), $soft, [System.Windows.Forms.TextFormatFlags]'Left, VerticalCenter, EndEllipsis, NoPrefix')
          $E.Handled = $true; return }
        if (-not $kind) { return }   # the check box column paints itself
        $E.Paint($r, [System.Windows.Forms.DataGridViewPaintParts]'Background, Border')
        if ($V.Focused -and $V.CurrentCell -and $V.CurrentCell.RowIndex -eq $E.RowIndex) {   # keyboard users see the current row
          $fb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(231, 241, 251)); $g.FillRectangle($fb, $r.Left, $r.Top, $r.Width, $r.Height - 1); $fb.Dispose() }
        $cell = $V.Rows[$E.RowIndex].Cells[$E.ColumnIndex]
        if ($kind -eq 'chip') {
          & $drawChip $g ([string]$cell.Value) ($r.Left + 6) $r.Top $r.Height
        } else {
          # 'over': small gray line 1 over the main line 2 (Check: group, then name). 'title': semibold line 1. Else plain line 1.
          $t = $cell.Tag; if (-not ($t -is [array])) { $t = @([string]$cell.Value, '') }
          $f1 = $(if ($kind -eq 'over') { $smallFont } elseif ($kind -eq 'title') { $semiFont } else { $V.Font }); $c1 = $(if ($kind -eq 'over') { $soft } else { $ink })
          $f2 = $(if ($kind -eq 'over') { $V.Font } else { $smallFont }); $c2 = $(if ($kind -eq 'over') { $ink } else { $soft })
          $w = [math]::Max(1, $r.Width - 12)
          $h1 = [System.Windows.Forms.TextRenderer]::MeasureText('Ag', $f1).Height; $h2 = $(if ($t[1]) { [System.Windows.Forms.TextRenderer]::MeasureText('Ag', $f2).Height } else { 0 })
          $y = $r.Top + [int](($r.Height - $h1 - $h2) / 2)
          [System.Windows.Forms.TextRenderer]::DrawText($g, (& $fitText ([string]$t[0]) $f1 $w), $f1, (New-Object System.Drawing.Rectangle(($r.Left + 6), $y, $w, $h1)), $c1, $flags1)
          if ($t[1]) { [System.Windows.Forms.TextRenderer]::DrawText($g, (& $fitText ([string]$t[1]) $f2 $w), $f2, (New-Object System.Drawing.Rectangle(($r.Left + 6), ($y + $h1), $w, $h2)), $c2, $flags1) }
        }
        $E.Handled = $true
      } catch { $null = $_ } }   # cosmetics never stop the window: on an error the cell paints as plain text
    $paintSecondary = { param($X) if ($X.Enabled) { $X.BackColor = [System.Drawing.Color]::White; $X.ForeColor = $ink; $X.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(122, 135, 148) } else { $X.BackColor = [System.Drawing.Color]::FromArgb(233, 236, 240); $X.ForeColor = [System.Drawing.Color]::FromArgb(85, 85, 85); $X.FlatAppearance.BorderColor = $paleEdge } }   # edge #7A8794, 3.7:1   # form scope: handlers run later
    $styleSecondary = { param($B) try { $B.FlatStyle = 'Flat'; & $paintSecondary $B; $B.Add_EnabledChanged({ try { & $paintSecondary $this } catch { $null = $_ } }) } catch { $null = $_ } }
    $styleLink = { param($B) try { $B.FlatStyle = 'Flat'; $B.FlatAppearance.BorderSize = 0; $B.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(238, 244, 250); $B.BackColor = [System.Drawing.Color]::White; $B.ForeColor = [System.Drawing.Color]::FromArgb(0, 83, 159); $B.Font = $linkFont; $B.MinimumSize = New-Object System.Drawing.Size(0, 28); $B.Padding = New-Object System.Windows.Forms.Padding(0) } catch { $null = $_ } }   # a link: AF blue, bold, underlined, 28 high
    $mkTitle = { param([string]$Text) $l = & $mkLabel $Text; $l.Margin = New-Object System.Windows.Forms.Padding(3, 3, 3, 2); try { $l.Font = $titleFont; $l.ForeColor = [System.Drawing.Color]::FromArgb(11, 37, 69) } catch { $null = $_ }; $l }
    $mkSub = { param([string]$Text) $l = & $mkLabel $Text; $l.Margin = New-Object System.Windows.Forms.Padding(3, 0, 3, 12); try { $l.Font = $subFont; $l.ForeColor = $soft } catch { $null = $_ }; $l }
    $mkGrid = { param([string]$Name)
      $v = New-Object System.Windows.Forms.DataGridView
      $v.ReadOnly = $true; $v.AllowUserToAddRows = $false; $v.AllowUserToDeleteRows = $false; $v.AllowUserToResizeRows = $false
      $v.RowHeadersVisible = $false; $v.SelectionMode = 'FullRowSelect'; $v.MultiSelect = $false; $v.BorderStyle = 'FixedSingle'
      $v.AutoSizeRowsMode = 'None'; $v.ColumnHeadersHeightSizeMode = 'AutoSize'; $v.AccessibleName = $Name
      try { $v.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font($form.Font.FontFamily, [single]10, $bold) } catch { $null = $_ }   # bold headers (the Administrator, 2026-11-14)
      $v.RowTemplate.Height = 2 * $lineH + 10
      try { $v.BorderStyle = 'None'; $v.CellBorderStyle = 'SingleHorizontal'; $v.GridColor = [System.Drawing.Color]::FromArgb(238, 241, 244); $v.EnableHeadersVisualStyles = $false; $v.ColumnHeadersBorderStyle = 'None' } catch { $null = $_ }
      $v.Add_CellPainting({ & $paintCell $this $_ })
      $v.Add_GotFocus({ $this.Invalidate() }); $v.Add_LostFocus({ $this.Invalidate() }); $v.Add_CurrentCellChanged({ $this.Invalidate() })
      try { $v.BackgroundColor = [System.Drawing.SystemColors]::Window; $v.DefaultCellStyle.WrapMode = 'True'; $v.DefaultCellStyle.Alignment = 'MiddleLeft'
        $v.DefaultCellStyle.Padding = New-Object System.Windows.Forms.Padding(4, 2, 4, 2)
        $v.DefaultCellStyle.SelectionBackColor = [System.Drawing.SystemColors]::Window; $v.DefaultCellStyle.SelectionForeColor = [System.Drawing.SystemColors]::WindowText } catch { $null = $_ }
      $v.Add_ColumnWidthChanged({ & $refit $this $_.Column.Index })
      # A Fill column may get its real width only when the screen shows (review R17): refit every column then.
      $v.Add_VisibleChanged({ if ($this.Visible) { for ($c = 0; $c -lt $this.Columns.Count; $c++) { & $refit $this $c } } })
      $v.Add_SizeChanged({ for ($c = 0; $c -lt $this.Columns.Count; $c++) { & $refit $this $c } })
      $v }
    # R17 (PFM 14 Nov 26: the light-green sweep of the Windows bar was not smooth): RADE draws its own bars. A 30 ms timer
    # eases the fill to its new value and moves one soft light band across it. R18 (PFM 14 Nov 26): both bars fill from left
    # to right; the gliding back-and-forth block for an unknown step is gone. With Windows animations off ($calm) the fill
    # jumps and nothing moves.
    $script:bars = @{}
    $calm = $false; try { $calm = -not [System.Windows.Forms.SystemInformation]::UIEffectsEnabled } catch { $null = $_ }
    # Layout B colors (Wing Master Version II, RADE docs/window-design.md): navy to Air Force blue, AF yellow for trim.
    $navy = [System.Drawing.Color]::FromArgb(11, 37, 69); $afBlue = [System.Drawing.Color]::FromArgb(0, 83, 159)
    $gold = [System.Drawing.Color]::FromArgb(255, 213, 32); $mist = [System.Drawing.Color]::FromArgb(221, 232, 243)
    $trackColor = [System.Drawing.Color]::FromArgb(238, 241, 245)
    $twoPi = 2 * [math]::PI
    $drawBar = { param($P, $G)
      # Thin rounded bars with no border (the Administrator, 2026-11-14, layout P1): a light track and the fill on top.
      $b = $script:bars[[string]$P.Tag]; if (-not $b) { return }
      $w = $P.ClientSize.Width; $h = $P.ClientSize.Height; if ($w -lt 4 -or $h -lt 2) { return }
      $G.Clear([System.Drawing.Color]::White); $G.SmoothingMode = 'AntiAlias'
      $track = & $roundRect 0 0 $w $h ([int]($h / 2)); $tb = New-Object System.Drawing.SolidBrush($trackColor); $G.FillPath($tb, $track); $tb.Dispose(); $track.Dispose()
      $fw = [int][math]::Round($w * $b.Shown)
      if ($fw -gt 0) {
        $fw = [math]::Max($fw, $h)   # a small fill still shows as a round dot
        $fp = & $roundRect 0 0 $fw $h ([int]($h / 2))
        $fb = New-Object System.Drawing.SolidBrush($b.Fill); $G.FillPath($fb, $fp); $fb.Dispose()
        if ($b.Sheen -and -not $calm -and $fw -gt 12) {
          $bw = [math]::Max(24, [int]($w * 0.08)); $x = [int](($b.Phase / $twoPi) * ($fw + $bw)) - $bw
          $rect = New-Object System.Drawing.Rectangle($x, 0, $bw, $h)
          $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $b.Fill, $b.Fill, [single]0)
          $cb = New-Object System.Drawing.Drawing2D.ColorBlend(3)
          $cb.Colors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(0, 255, 255, 255), [System.Drawing.Color]::FromArgb(110, 255, 255, 255), [System.Drawing.Color]::FromArgb(0, 255, 255, 255))
          $cb.Positions = [single[]]@(0, 0.5, 1); $lg.InterpolationColors = $cb
          $G.SetClip($fp); $G.FillRectangle($lg, $rect); $G.ResetClip(); $lg.Dispose()
        }
        $fp.Dispose()
      } }
    $mkBar = { param([string]$Name, [int]$H, [string]$Label, $Fill)
      $p = New-Object System.Windows.Forms.Panel
      $p.Anchor = 'Left, Right'; $p.Height = $H; $p.Margin = New-Object System.Windows.Forms.Padding(3, 3, 3, 3); $p.Tag = $Name
      $p.AccessibleRole = 'ProgressBar'; $p.AccessibleName = $Label; $p.AccessibleDescription = '0 %'
      try { [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic, Instance').SetValue($p, $true, $null) } catch { $null = $_ }
      $script:bars[$Name] = @{ Panel = $p; Target = 0.0; Shown = 0.0; Sheen = $false; Phase = 0.0; Fill = $Fill }
      $p.Add_Paint({ & $drawBar $this $_.Graphics })
      $p }
    $setBar = { param([string]$Name, [double]$Value, [bool]$Sheen)
      $b = $script:bars[$Name]; if (-not $b) { return }
      $v = [math]::Max(0.0, [math]::Min(1.0, $Value))
      if ($v -lt $b.Target - 0.001) { $b.Shown = $v }   # never slide backwards (a new step starts at 0)
      $b.Target = $v; $b.Sheen = $Sheen
      $b.Panel.AccessibleDescription = [string][int]($v * 100) + ' %'
      $b.Panel.Invalidate() }
    $anim = New-Object System.Windows.Forms.Timer
    $anim.Interval = 30
    $anim.Add_Tick({
      foreach ($b in @($script:bars.Values)) {
        $dirty = $false
        $d = $b.Target - $b.Shown
        if ([math]::Abs($d) -gt 0.0005) { $b.Shown = $(if ($calm) { $b.Target } else { $b.Shown + $d * 0.18 }); $dirty = $true }
        elseif ($b.Shown -ne $b.Target) { $b.Shown = $b.Target; $dirty = $true }
        if ($b.Sheen -and -not $calm) { $b.Phase += 0.05; if ($b.Phase -gt $twoPi) { $b.Phase -= $twoPi }; $dirty = $true }
        if ($dirty) { $b.Panel.Invalidate() }
      } })
    $grid = & $mkRows @('AutoSize', 'AutoSize', 'Percent', 'AutoSize')
    $grid.Padding = New-Object System.Windows.Forms.Padding(21, 17, 21, 11)   # with 3 px margins: 24 left and right, 20 top (the logo's top), 14 bottom
    try { $grid.BackColor = [System.Drawing.Color]::White } catch { $null = $_ }   # layout A: a white main area
    # Header on every screen: where you are (screen k of 3), last round, newer round.
    $crumb = & $mkLabel ''
    try { $crumb.ForeColor = Get-CheckColor 'NOT RUN' } catch { $null = $_ }
    $banner = & $mkLabel (Get-LastRoundText $hist0)
    $banner.Margin = New-Object System.Windows.Forms.Padding(3, 2, 3, 6)
    try { $banner.ForeColor = Get-CheckColor 'NOT RUN' } catch { $null = $_ }
    $newer = Get-NewerRound
    if ($newer) { $banner.Text = 'A newer round, ' + $newer + ', is in the repository. Close this window and run ' + $newer + ' instead.'; try { $banner.ForeColor = Get-CheckColor 'FAILED' } catch { $null = $_ } }
    $banner.Visible = [bool]$newer   # layout A: the last round shows under the Choose title; only a newer round shows on every screen
    $body = New-Object System.Windows.Forms.Panel
    $body.Dock = 'Fill'; $body.Margin = New-Object System.Windows.Forms.Padding(0)
    # One nav row on every screen (layout P1, the Administrator, 2026-11-14): a hint on the left that says what to do next,
    # then Exit, Back and the primary button (Next, or Run on Deploy) at the bottom right. Tab reaches the primary first.
    $nav = New-Object System.Windows.Forms.TableLayoutPanel
    $nav.AutoSize = $true; $nav.Dock = 'Fill'; $nav.ColumnCount = 2; $nav.RowCount = 1; $nav.Margin = New-Object System.Windows.Forms.Padding(0)
    $nav.Padding = New-Object System.Windows.Forms.Padding(0, 12, 0, 0)
    [void]$nav.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100))); [void]$nav.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize')))
    $nav.Add_Paint({ $hp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(227, 232, 238)); $_.Graphics.DrawLine($hp, 0, 0, $this.Width, 0); $hp.Dispose() })   # one hairline over the buttons
    $navHint = New-Object System.Windows.Forms.Label
    $navHint.AutoSize = $false; $navHint.AutoEllipsis = $true; $navHint.Dock = 'Fill'; $navHint.TextAlign = 'MiddleLeft'; $navHint.Margin = New-Object System.Windows.Forms.Padding(3, 3, 12, 3)
    try { $navHint.Font = $smallFont; $navHint.ForeColor = $soft } catch { $null = $_ }
    $navBtns = New-Object System.Windows.Forms.FlowLayoutPanel
    $navBtns.AutoSize = $true; $navBtns.WrapContents = $false; $navBtns.Margin = New-Object System.Windows.Forms.Padding(0); $navBtns.Anchor = 'Right'
    $next = & $mkButton 'Next'
    $back = & $mkButton 'Back'
    $exitB = & $mkButton 'E&xit'; $exitB.AccessibleName = 'Exit RADE'   # PFM 14 Nov 26 (R17); Alt+X
    $run = & $mkButton 'Run'; $run.Visible = $false   # Deploy's primary, in Next's place
    $navBtns.Controls.AddRange(@($exitB, $back, $next, $run))
    $next.TabIndex = 0; $run.TabIndex = 1; $back.TabIndex = 2; $exitB.TabIndex = 3
    $nav.Controls.Add($navHint, 0, 0); $nav.Controls.Add($navBtns, 1, 0)
    $script:hints = @{ 0 = @('Select an application to continue', ''); 1 = @('', ''); 2 = @('', '') }
    $showHint = { $h = $script:hints[[int]$script:screen]; $navHint.Text = [string]$h[0]; try { $navHint.ForeColor = $(if ($h[1]) { Get-CheckColor ([string]$h[1]) } else { $soft }) } catch { $null = $_ } }
    $setHint = { param([int]$S, [string]$Text, [string]$State) $script:hints[$S] = @($Text, $State); if ([int]$script:screen -eq $S) { & $showHint } }

    # ---- Screen 1: choose the application
    # Layout P1 (the Administrator, 2026-11-14): one card per application (radio, name / facts / summary). Nothing is
    # selected when the window opens and Next stays off until a choice, so no application looks chosen for you.
    $pChoose = & $mkRows @('AutoSize', 'AutoSize', 'Percent')
    $chooseHead = & $mkTitle 'Choose an application'
    $chooseSub = & $mkSub (Get-LastRoundText $hist0)
    $appList = New-Object System.Windows.Forms.ListBox
    $appList.Dock = 'Fill'; $appList.IntegralHeight = $false; $appList.BorderStyle = 'None'; $appList.AccessibleName = 'Applications (select one)'
    foreach ($a in $apps) { [void]$appList.Items.Add($a.Name) }   # the item text is what a screen reader says
    $tips = New-Object System.Windows.Forms.ToolTip
    try {
      $appList.DrawMode = 'OwnerDrawFixed'; $appList.ItemHeight = [math]::Min(255, $lineB + 2 * $lineS + (& $sc 29))   # card 72 + gap 8 at 100 %
      $appList.Add_DrawItem({
        try {
          $e = $_; if ($e.Index -lt 0) { return }
          $g = $e.Graphics; $bd = $e.Bounds; $a = $apps[$e.Index]
          $sel = (([int]$e.State -band [int][System.Windows.Forms.DrawItemState]::Selected) -ne 0)
          $g.FillRectangle([System.Drawing.Brushes]::White, $bd)
          $old = $g.SmoothingMode; $g.SmoothingMode = 'AntiAlias'
          $card = New-Object System.Drawing.Rectangle(($bd.Left + 1), ($bd.Top + 1), ($bd.Width - 3), ($bd.Height - (& $sc 8) - 2))
          $cp = & $roundRect $card.X $card.Y $card.Width $card.Height (& $sc 6)
          $cb = New-Object System.Drawing.SolidBrush($(if ($sel) { [System.Drawing.Color]::FromArgb(243, 248, 253) } else { [System.Drawing.Color]::White })); $g.FillPath($cb, $cp); $cb.Dispose()
          $pen = $(if ($sel) { New-Object System.Drawing.Pen($afBlue, [single](& $sc 2)) } else { New-Object System.Drawing.Pen($paleEdge, [single]1) }); $g.DrawPath($pen, $cp); $pen.Dispose(); $cp.Dispose()
          # The radio: a gray ring (#5A6573, 5.9:1); selected: an AF blue ring with a dot, the card edge AF blue (7.7:1).
          $rd = & $sc 18; $rx = $card.Left + (& $sc 16); $ry = $card.Top + [int](($card.Height - $rd) / 2)
          $rp = New-Object System.Drawing.Pen($(if ($sel) { $afBlue } else { $soft }), [single]$(if ($sel) { & $sc 2 } else { & $sc 1.5 }))
          $g.DrawEllipse($rp, [single]($rx + 1), [single]($ry + 1), [single]($rd - 2), [single]($rd - 2)); $rp.Dispose()
          if ($sel) { $dd = & $sc 8; $db = New-Object System.Drawing.SolidBrush($afBlue); $g.FillEllipse($db, [single]($rx + ($rd - $dd) / 2), [single]($ry + ($rd - $dd) / 2), [single]$dd, [single]$dd); $db.Dispose() }
          $g.SmoothingMode = $old
          $x = $rx + $rd + (& $sc 14); $w = [math]::Max(1, $card.Right - $x - (& $sc 12))
          $y = $card.Top + [int](($card.Height - $lineB - 2 * $lineS) / 2)
          $t = Get-AppText $a $hist0
          [System.Windows.Forms.TextRenderer]::DrawText($g, (& $fitText ([string]$a.Name) $semiFont $w), $semiFont, (New-Object System.Drawing.Rectangle($x, $y, $w, $lineB)), $(if ($sel) { $navy } else { $ink }), $flags1)
          [System.Windows.Forms.TextRenderer]::DrawText($g, (& $fitText ([string]$t.Meta) $smallFont $w), $smallFont, (New-Object System.Drawing.Rectangle($x, ($y + $lineB), $w, $lineS)), $soft, $flags1)
          [System.Windows.Forms.TextRenderer]::DrawText($g, (& $fitText ([string]$t.Summary) $smallFont $w), $smallFont, (New-Object System.Drawing.Rectangle($x, ($y + $lineB + $lineS), $w, $lineS)), $soft, $flags1)
          if ((([int]$e.State -band [int][System.Windows.Forms.DrawItemState]::Focus) -ne 0) -and (([int]$e.State -band [int][System.Windows.Forms.DrawItemState]::NoFocusRect) -eq 0)) {
            [System.Windows.Forms.ControlPaint]::DrawFocusRectangle($g, (New-Object System.Drawing.Rectangle(($card.Left + (& $sc 4)), ($card.Top + (& $sc 4)), ($card.Width - (& $sc 8)), ($card.Height - (& $sc 8))))) }
        } catch { $null = $_ } })
      $script:tipIndex = -2   # the full summary as a tooltip on the card under the mouse
      $appList.Add_MouseMove({ $i = $appList.IndexFromPoint($_.Location); if ($i -ne $script:tipIndex) { $script:tipIndex = $i; $tips.SetToolTip($appList, $(if ($i -ge 0) { [string]$apps[$i].Summary } else { '' })) } })
    } catch { $appList.DrawMode = 'Normal' }
    $row = 0; foreach ($c in @($chooseHead, $chooseSub, $appList)) { $pChoose.Controls.Add($c, 0, $row); $row++ }

    # ---- Screen 2: checks
    # Layout P1 (the Administrator, 2026-11-14): every check on screen with no scroll (pixel budget: docs/window-design.md).
    # Two columns: the first group (Local) on the left, the other groups (Network, Access) on the right. Each row has two
    # lines (the name; what was found and what to do, joined by a middle dot; the full text is the tooltip, the log and the
    # e-mail) and the result chip on the right. A check that needs you (sign-in, look and answer) has its link in its own
    # row. A screen smaller than the budget (1280 x 800 at 150 %) scrolls the columns; nothing is cut off.
    $pCheck = & $mkRows @('AutoSize', 'AutoSize', 'AutoSize', 'Percent', 'AutoSize')
    $checkHead = & $mkTitle ''
    $checkWhat = & $mkSub ('Read-only. Passed checks are reused for ' + $checkMaxDays + ' days')
    $sitePanel = New-Object System.Windows.Forms.TableLayoutPanel
    $sitePanel.AutoSize = $true; $sitePanel.Dock = 'Fill'; $sitePanel.ColumnCount = 2; $sitePanel.RowCount = 1; $sitePanel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 9)
    [void]$sitePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize'))); [void]$sitePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    $siteLabel = & $mkLabel 'Site address'
    try { $siteLabel.Font = $semiFont; $siteLabel.ForeColor = $soft } catch { $null = $_ }
    $siteLabel.Anchor = 'Left'; $siteLabel.Margin = New-Object System.Windows.Forms.Padding(3, 3, 12, 3)
    $siteBox = New-Object System.Windows.Forms.TextBox
    $siteBox.Anchor = 'Left, Right'; $siteBox.Text = Get-SiteUrl $basePath; if (-not $siteBox.Text) { $siteBox.Text = $sitePrefix }   # PFM 14 Nov 26: start the box with the DAF SharePoint address
    try { $siteBox.BorderStyle = 'FixedSingle' } catch { $null = $_ }
    $siteBox.Add_GotFocus({ $siteBox.SelectionStart = $siteBox.Text.Length; $siteBox.SelectionLength = 0 }); $siteBox.AccessibleName = 'Site address, starts with https://'
    $sitePanel.Controls.Add($siteLabel, 0, 0); $sitePanel.Controls.Add($siteBox, 1, 0)
    $mkStack = { $t = New-Object System.Windows.Forms.TableLayoutPanel; $t.ColumnCount = 1; $t.RowCount = 0; $t.AutoSize = $true; $t.Anchor = 'Top, Left, Right'; $t.Margin = New-Object System.Windows.Forms.Padding(0); [void]$t.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100))); $t }
    $stackAdd = { param($St, $C) $St.RowCount = $St.RowCount + 1; [void]$St.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))); $St.Controls.Add($C, 0, ($St.RowCount - 1)) }
    $stackClear = { param($St) $old = @($St.Controls); $St.Controls.Clear(); foreach ($c in $old) { $c.Dispose() }; $St.RowStyles.Clear(); $St.RowCount = 0 }
    $checkScroll = New-Object System.Windows.Forms.Panel
    $checkScroll.Dock = 'Fill'; $checkScroll.AutoScroll = $true; $checkScroll.Margin = New-Object System.Windows.Forms.Padding(0)
    $checkCols = New-Object System.Windows.Forms.TableLayoutPanel
    $checkCols.Dock = 'Top'; $checkCols.AutoSize = $true; $checkCols.ColumnCount = 2; $checkCols.RowCount = 1; $checkCols.Margin = New-Object System.Windows.Forms.Padding(0)
    [void]$checkCols.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 50))); [void]$checkCols.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 50)))
    [void]$checkCols.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))
    $colL = & $mkStack; $colR = & $mkStack
    $colL.Margin = New-Object System.Windows.Forms.Padding(3, 0, 12, 0); $colR.Margin = New-Object System.Windows.Forms.Padding(12, 0, 3, 0)   # 24 px between the columns
    $checkCols.Controls.Add($colL, 0, 0); $checkCols.Controls.Add($colR, 1, 0)
    $checkScroll.Controls.Add($checkCols)
    $script:checkRows = @{}; $script:rowBtns = @()
    $script:rowCheckH = $lineH + $lineS + (& $sc 5)   # 40 at 100 %: the name and one line of details
    $paintCheckRow = { param($P, $G)
      try {
        $t = $P.Tag; $w = $P.ClientSize.Width
        $G.Clear([System.Drawing.Color]::White)
        $hp = New-Object System.Drawing.Pen($rowLine); $G.DrawLine($hp, 0, ($P.Height - 1), $w, ($P.Height - 1)); $hp.Dispose()
        $chipW = & $sc 84; $pad = & $sc 4; $tw = [math]::Max(1, $w - $chipW - 2 * $pad)
        $band = $script:rowCheckH; $y = [int](($band - $lineH - $lineS) / 2)
        $two = @(@($t.A, $t.B) | Where-Object { $_ }) -join $dot
        [System.Windows.Forms.TextRenderer]::DrawText($G, (& $fitText ([string]$t.Name) $form.Font $tw), $form.Font, (New-Object System.Drawing.Rectangle($pad, $y, $tw, $lineH)), $ink, $flags1)
        [System.Windows.Forms.TextRenderer]::DrawText($G, (& $fitText $two $smallFont $tw), $smallFont, (New-Object System.Drawing.Rectangle($pad, ($y + $lineH), $tw, $lineS)), $soft, $flags1)
        & $drawChip $G ([string]$t.State) ($w - $chipW) 0 $band
      } catch { $null = $_ } }
    $mkGroupHead = { param([string]$Name)
      $l = New-Object System.Windows.Forms.Label
      $l.AutoSize = $false; $l.Anchor = 'Left, Right'; $l.Height = $lineS + (& $sc 8); $l.Margin = New-Object System.Windows.Forms.Padding(0)
      $l.Text = $Name.ToUpperInvariant(); $l.TextAlign = 'BottomLeft'; $l.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, (& $sc 4))
      try { $l.Font = $smallBold; $l.ForeColor = $soft } catch { $null = $_ }
      $l.Add_Paint({ $hp = New-Object System.Drawing.Pen($hairline); $_.Graphics.DrawLine($hp, 0, ($this.Height - 1), $this.Width, ($this.Height - 1)); $hp.Dispose() })
      $l }
    $mkCheckRow = { param($Def)
      # Made when the Check screen fills, after the window has scaled: sizes go through $sc.
      $p = New-Object System.Windows.Forms.Panel
      $act = ($Def.Kind -eq 'signin' -or $Def.Kind -eq 'guide')
      $p.Anchor = 'Left, Right'; $p.Margin = New-Object System.Windows.Forms.Padding(0); $p.BackColor = [System.Drawing.Color]::White
      $p.Height = $script:rowCheckH + $(if ($act) { & $sc 24 } else { 0 })
      try { [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic, Instance').SetValue($p, $true, $null) } catch { $null = $_ }
      $nm = [string]$Def.Short; if (-not $nm) { $nm = [string]$Def.Name }
      $p.Tag = @{ Name = $nm; Full = [string]$Def.Name; State = 'NOT RUN'; A = ''; B = '' }
      $p.AccessibleName = [string]$Def.Name
      $p.Add_Paint({ & $paintCheckRow $this $_.Graphics })
      $p.Add_Resize({ $this.Invalidate() })
      if ($act) {
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $(if ($Def.Kind -eq 'signin') { 'Sign in and check site rights' } else { 'Check Power Automate' }); $b.Tag = [string]$Def.Kind
        & $styleLink $b
        $b.AutoSize = $false; $b.MinimumSize = New-Object System.Drawing.Size(0, 0); $b.Size = New-Object System.Drawing.Size(([System.Windows.Forms.TextRenderer]::MeasureText($b.Text, $linkFont).Width + (& $sc 12)), (& $sc 24)); $b.Location = New-Object System.Drawing.Point(0, ($script:rowCheckH - (& $sc 2)))
        $b.Add_Click({ if ([string]$this.Tag -eq 'signin') { & $runChecks @('signin') @('site-rights') $true } else { & $runChecks @('guide') @('flow-guide') $true } })
        $p.Controls.Add($b); $script:rowBtns += $b
      }
      $p }
    $againB = & $mkButton 'Run checks again'
    & $styleLink $againB
    # Counts, each in its own color (PFM 14 Nov 26); a zero count is not shown (layout A).
    $countPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $countPanel.AutoSize = $true; $countPanel.WrapContents = $true; $countPanel.Dock = 'Fill'
    $countLabels = @{}
    foreach ($st in 'PASSED', 'WARNING', 'FAILED', 'NOT RUN') {
      $l = & $mkLabel ''; $l.Margin = New-Object System.Windows.Forms.Padding(3, 3, 14, 0)
      try { $l.ForeColor = Get-CheckColor $st; $l.Font = New-Object System.Drawing.Font($form.Font.FontFamily, [single]10, $bold) } catch { $null = $_ }
      # A fixed width (the widest count text), so a count going from 9 to 10 does not push the others (R17).
      try { $l.AutoSize = $false; $l.Width = (& $at96 ([System.Windows.Forms.TextRenderer]::MeasureText('99 warnings', $l.Font).Width)) + 8; $l.Height = $lineH96 + 4 } catch { $null = $_ }
      $countLabels[$st] = $l; [void]$countPanel.Controls.Add($l)
    }
    # One row: counts on the left, "Run checks again" on the right.
    $checkBar = New-Object System.Windows.Forms.TableLayoutPanel
    $checkBar.Dock = 'Fill'; $checkBar.AutoSize = $true; $checkBar.ColumnCount = 2; $checkBar.RowCount = 1; $checkBar.Margin = New-Object System.Windows.Forms.Padding(0, 9, 0, 0)
    [void]$checkBar.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100))); [void]$checkBar.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize')))
    $countPanel.Anchor = 'Left'; $againB.Anchor = 'Right'; $countPanel.Dock = 'None'
    $checkBar.Controls.Add($countPanel, 0, 0); $checkBar.Controls.Add($againB, 1, 0)
    $row = 0; foreach ($c in @($checkHead, $checkWhat, $sitePanel, $checkScroll, $checkBar)) { $pCheck.Controls.Add($c, 0, $row); $row++ }

    # ---- Screen 3: deploy
    # Layout P1 (the Administrator, 2026-11-14): title, "Writes to" and the path, one line over each bar (8 px AF blue, 4 px
    # green, rounded, no border), the steps (Run, Step, Status), the log (it hides itself below 80 px), "Results to", then
    # the "Window" box with the result buttons, which show once the round is DONE. Run is in the nav row, in Next's place.
    $pDeploy = & $mkRows @('AutoSize', 'AutoSize', 'AutoSize', 'AutoSize', 'AutoSize', 'AutoSize', 'AutoSize', 'AutoSize', 'Percent', 'AutoSize', 'AutoSize', 'AutoSize')
    $deployHead = & $mkTitle ''
    $wherePanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $wherePanel.AutoSize = $true; $wherePanel.WrapContents = $true; $wherePanel.Dock = 'Fill'; $wherePanel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 9)
    $whereLead = & $mkLabel 'Writes to'
    try { $whereLead.ForeColor = $soft } catch { $null = $_ }   # one 10 pt line; the path in bold
    $whereLead.Margin = New-Object System.Windows.Forms.Padding(3, 0, 0, 3)
    $where = & $mkLabel ''
    $where.Margin = New-Object System.Windows.Forms.Padding(0, 0, 3, 3)
    $wherePanel.Controls.AddRange(@($whereLead, $where))
    # Cosmetics never stop the window. R06 fell back to text mode: Font('Segoe UI', 10, 'Bold') fails at binding with
    # "Multiple ambiguous overloads" (string 'Bold' fits FontStyle and GraphicsUnit). Typed enum here; each in its own try.
    try { $where.Font = New-Object System.Drawing.Font($form.Font.FontFamily, [single]10, $bold) } catch { $null = $_ }
    $warn = & $mkLabel ''
    try { $warn.ForeColor = Get-CheckColor 'FAILED' } catch { $null = $_ }
    # Steps: a grid of two-line rows (R17): a check box to run it, then the step name / its note or result, then a status chip.
    # Click the box or press Space to tick or clear a step; Enter runs.
    $stepView = & $mkGrid 'Steps to run'
    $stepView.Anchor = 'Left, Right'; $stepView.TabStop = $true
    $stepView.RowTemplate.Height = $lineB + $lineS + (& $sc 9)   # 44 at 100 %: the step name (bold) and one line
    $runCol = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $runCol.HeaderText = 'Run'; $runCol.Width = 52; $runCol.AutoSizeMode = 'None'; $runCol.SortMode = 'NotSortable'
    [void]$stepView.Columns.Add($runCol)
    $ci = $stepView.Columns.Add('Step', 'Step'); $stepView.Columns[$ci].AutoSizeMode = 'Fill'; $stepView.Columns[$ci].SortMode = 'NotSortable'; $stepView.Columns[$ci].Tag = 'title'
    $ci = $stepView.Columns.Add('Status', 'Status'); $stepView.Columns[$ci].AutoSizeMode = 'None'; $stepView.Columns[$ci].Width = 132; $stepView.Columns[$ci].SortMode = 'NotSortable'; $stepView.Columns[$ci].Tag = 'chip'
    $stepAdd = { param([string]$Name, [string]$Status, [bool]$On)
      $i = $stepView.Rows.Add(); $stepView.Rows[$i].Cells[0].Value = $On; & $setCell $stepView.Rows[$i].Cells[1] $Name $Status; $stepView.Rows[$i].Cells[2].Value = 'WAITING'; $i }
    $stepOn = { param([int]$I) [bool]$stepView.Rows[$I].Cells[0].Value }
    $stepSay = { param([int]$I, [string]$Status, [string]$State)
      # The chip shows the state word; line 2 the rest ("PASSED (1 passed, 0 failed) in 0m 02s" -> "1 passed, 0 failed, in 0m 02s").
      if (-not $State) { $State = 'WAITING'; foreach ($w in 'NEEDS REVIEW', 'FAILED', 'SKIPPED', 'PASSED') { if ($Status.StartsWith($w, [System.StringComparison]::Ordinal)) { $State = $w; $Status = $Status.Substring($w.Length).Trim(); break } } }
      if ($State -eq 'SKIPPED' -and $Status -match '^by ') { $Status = 'Skipped ' + $Status }
      if ($Status -match '^\((.*)\) in (.+)$') { $Status = $Matches[1] + ', in ' + $Matches[2] }
      if ($Status) { $Status = $Status.Substring(0, 1).ToUpperInvariant() + $Status.Substring(1) }
      $c = $stepView.Rows[$I].Cells[1]; & $setCell $c ([string]$c.Tag[0]) $Status; $stepView.Rows[$I].Cells[2].Value = $State; $stepView.InvalidateRow($I) }
    $stepToggle = { param([int]$I) if (-not $script:running -and $I -ge 0) { $c = $stepView.Rows[$I].Cells[0]; $c.Value = -not [bool]$c.Value; $stepView.Rows[$I].Cells[2].Value = $(if ($c.Value) { 'WAITING' } else { 'OFF' }); $stepView.InvalidateRow($I) } }
    $stepView.Add_CellClick({ if ($_.ColumnIndex -eq 0) { & $stepToggle $_.RowIndex } })
    $stepView.Add_PreviewKeyDown({ if ($_.KeyCode -eq 'Return') { $_.IsInputKey = $true } })   # Enter reaches KeyDown (runs), not the grid's next-row move
    $stepView.Add_KeyDown({
      if ($_.KeyCode -eq 'Space') { $_.SuppressKeyPress = $true; if ($stepView.CurrentRow) { & $stepToggle $stepView.CurrentRow.Index } }
      elseif ($_.KeyCode -eq 'Return') { $_.SuppressKeyPress = $true; if ($run.Enabled) { $run.PerformClick() } } })
    $mkSplit = { param($Font, $Color)
      # One line: what on the left (cut with "..." to fit), how far on the right.
      $t = New-Object System.Windows.Forms.TableLayoutPanel
      $t.Dock = 'Fill'; $t.AutoSize = $true; $t.ColumnCount = 2; $t.RowCount = 1; $t.Margin = New-Object System.Windows.Forms.Padding(0)
      [void]$t.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100))); [void]$t.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize')))
      $l = New-Object System.Windows.Forms.Label; $l.AutoSize = $false; $l.AutoEllipsis = $true; $l.Dock = 'Fill'; $l.Margin = New-Object System.Windows.Forms.Padding(3, 0, 3, 0)
      $r = New-Object System.Windows.Forms.Label; $r.AutoSize = $true; $r.Anchor = 'Right'; $r.Margin = New-Object System.Windows.Forms.Padding(3, 0, 3, 0)
      try { $l.Font = $Font; $l.ForeColor = $Color; $r.Font = $Font; $r.ForeColor = $soft } catch { $null = $_ }
      $l.Height = (& $at96 ([System.Windows.Forms.TextRenderer]::MeasureText('Ag', $l.Font).Height)) + 1
      $t.Controls.Add($l, 0, 0); $t.Controls.Add($r, 1, 0)
      return @{ Panel = $t; L = $l; R = $r } }
    $allRow = & $mkSplit $semiFont $ink; $allLabel = $allRow.L; $allRight = $allRow.R
    $allLabel.Text = 'Overall: not started'
    $bar = & $mkBar 'all' 8 'Overall progress' $afBlue
    $bar.Margin = New-Object System.Windows.Forms.Padding(3, 6, 3, 8)
    $stepRow = & $mkSplit $smallFont $soft; $stepLabel = $stepRow.L; $stepRight = $stepRow.R
    $stepLabel.Text = 'This step: none running'
    $stepBar = & $mkBar 'step' 4 'Progress of this step' ([System.Drawing.Color]::FromArgb(46, 133, 64))   # green #2E8540, 4.1:1 on the track (the Administrator, 2026-11-14); overall bar stays blue
    $stepBar.Margin = New-Object System.Windows.Forms.Padding(3, 6, 3, 13)
    $log = New-Object System.Windows.Forms.TextBox
    $log.Dock = 'Fill'; $log.Multiline = $true; $log.ScrollBars = 'Both'; $log.WordWrap = $false; $log.ReadOnly = $true; $log.AccessibleName = 'Log'
    try { $log.BorderStyle = 'FixedSingle'; $log.BackColor = [System.Drawing.Color]::FromArgb(247, 249, 251); $log.ForeColor = $ink } catch { $null = $_ }
    $log.Font = New-Object System.Drawing.Font('Consolas', 9); $log.Margin = New-Object System.Windows.Forms.Padding(3, 9, 3, 3)
    $toPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $toPanel.AutoSize = $true; $toPanel.Dock = 'Fill'; $toPanel.ColumnCount = 3; $toPanel.RowCount = 1; $toPanel.Margin = New-Object System.Windows.Forms.Padding(0, 9, 0, 0)
    [void]$toPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize'))); [void]$toPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize'))); [void]$toPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100)))
    $toLabel = & $mkLabel 'Results to'
    try { $toLabel.Font = $semiFont; $toLabel.ForeColor = $soft } catch { $null = $_ }
    $toLabel.Anchor = 'Left'; $toLabel.Margin = New-Object System.Windows.Forms.Padding(3, 3, 12, 3)
    $toBox = New-Object System.Windows.Forms.TextBox
    $toBox.Width = 360; $toBox.Anchor = 'Left'; $toBox.Text = Get-MailTo $basePath; $toBox.AccessibleName = 'Send results to (e-mail)'
    try { $toBox.BorderStyle = 'FixedSingle' } catch { $null = $_ }
    $logLink = New-Object System.Windows.Forms.LinkLabel
    $logLink.AutoSize = $true; $logLink.Text = 'Hide log'; $logLink.Anchor = 'Right'; $logLink.Margin = New-Object System.Windows.Forms.Padding(16, 3, 3, 3); $logLink.AccessibleName = 'Show or hide the log'
    try { $logLink.Font = $semiFont; $logLink.LinkColor = $afBlue; $logLink.ActiveLinkColor = $navy } catch { $null = $_ }
    $script:logUser = $true; $script:logForce = $false
    $fitLog = {
      # The log fills what is left; with less than 80 px (at 100 %) it hides itself and the link reads "Show log" (layout P1).
      $hs = $pDeploy.GetRowHeights(); $other = 0; for ($k = 0; $k -lt $hs.Count; $k++) { if ($k -ne 8) { $other += $hs[$k] } }
      $room = $pDeploy.ClientSize.Height - $pDeploy.Padding.Vertical - $other - $log.Margin.Vertical
      $want = ($script:logUser -and ($script:logForce -or $room -ge (& $sc 80)))
      if ($log.Visible -ne $want) { $log.Visible = $want; $pDeploy.RowStyles[8].SizeType = $(if ($want) { 'Percent' } else { 'AutoSize' }) }
      $logLink.Text = $(if ($log.Visible) { 'Hide log' } else { 'Show log' }) }
    $logLink.Add_LinkClicked({ $script:logUser = -not $log.Visible; $script:logForce = $script:logUser; try { & $fitLog } catch { $null = $_ } })
    $pDeploy.Add_SizeChanged({ if ($pDeploy.Visible) { try { & $fitLog } catch { $null = $_ } } })
    $toPanel.Controls.Add($toLabel, 0, 0); $toPanel.Controls.Add($toBox, 1, 0); $toPanel.Controls.Add($logLink, 2, 0)
    $okRow = New-Object System.Windows.Forms.TableLayoutPanel
    $okRow.AutoSize = $true; $okRow.Dock = 'Fill'; $okRow.ColumnCount = 2; $okRow.RowCount = 1; $okRow.Margin = New-Object System.Windows.Forms.Padding(0, 9, 0, 0)
    [void]$okRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100))); [void]$okRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize')))
    $okBox = New-Object System.Windows.Forms.CheckBox
    $okBox.AutoSize = $true; $okBox.Checked = $true; $okBox.Anchor = 'Left'
    $okBox.Text = 'The window displayed correctly (nothing overlapped or cut off)'
    try { $okBox.ForeColor = $soft; $okBox.Font = $smallFont } catch { $null = $_ }
    $resultBtns = New-Object System.Windows.Forms.FlowLayoutPanel
    $resultBtns.AutoSize = $true; $resultBtns.WrapContents = $false; $resultBtns.Anchor = 'Right'; $resultBtns.Margin = New-Object System.Windows.Forms.Padding(0); $resultBtns.MinimumSize = New-Object System.Drawing.Size(0, 40)   # keeps the row height when they are hidden
    $draft = & $mkButton 'Make e-mail draft'
    $copy = & $mkButton 'Copy summary'
    $open = & $mkButton 'Open results folder'
    foreach ($rb in @($draft, $copy, $open)) { $rb.Enabled = $false; $rb.Visible = $false; & $styleSecondary $rb; $rb.Add_EnabledChanged({ $this.Visible = $this.Enabled }) }   # shown once the round is DONE
    $resultBtns.Controls.AddRange(@($draft, $copy, $open))
    $okRow.Controls.Add($okBox, 0, 0); $okRow.Controls.Add($resultBtns, 1, 0)
    $filler = New-Object System.Windows.Forms.Label; $filler.Height = 0; $filler.Margin = New-Object System.Windows.Forms.Padding(0)   # takes the spare height while the log is hidden
    $row = 0; foreach ($c in @($deployHead, $wherePanel, $warn, $allRow.Panel, $bar, $stepRow.Panel, $stepBar, $stepView, $log, $toPanel, $okRow, $filler)) { $pDeploy.Controls.Add($c, 0, $row); $row++ }

    foreach ($pnl in @($pChoose, $pCheck, $pDeploy)) { $pnl.Visible = $false; $body.Controls.Add($pnl) }
    $row = 0; foreach ($c in @($crumb, $banner, $body, $nav)) { $grid.Controls.Add($c, 0, $row); $row++ }
    # ---- Layout B (PFM 14 Nov 26; RADE docs/window-design.md): a navy-to-blue rail on the left with a yellow edge: logo K,
    # the word RADE beside it on the logo's midpoint, the tagline below, the three screens as steps, the round and build.
    # Cosmetics never stop the window: if any part fails, the window runs without the rail.
    $rail = $null; $railSteps = @()
    try {
      $rail = New-Object System.Windows.Forms.Panel
      $rail.Dock = 'Left'; $rail.Width = 220; $rail.Margin = New-Object System.Windows.Forms.Padding(0)
      try { [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic, Instance').SetValue($rail, $true, $null) } catch { $null = $_ }
      $rail.Add_Paint({
        $r = $this.ClientRectangle; if ($r.Width -lt 4 -or $r.Height -lt 4) { return }
        $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($r, $navy, $afBlue, [single]90); $_.Graphics.FillRectangle($lg, $r); $lg.Dispose()
        $gb = New-Object System.Drawing.SolidBrush($gold); $_.Graphics.FillRectangle($gb, $r.Right - 3, 0, 3, $r.Height); $gb.Dispose() })
      $rail.Add_Resize({ $this.Invalidate() })
      $rt = & $mkRows @('AutoSize', 'AutoSize', 'AutoSize', 'AutoSize', 'Percent', 'AutoSize', 'AutoSize')
      $rt.BackColor = [System.Drawing.Color]::Transparent; $rt.Padding = New-Object System.Windows.Forms.Padding(18, 20, 21, 16)
      $lock = New-Object System.Windows.Forms.TableLayoutPanel
      $lock.AutoSize = $true; $lock.ColumnCount = 2; $lock.RowCount = 1; $lock.BackColor = [System.Drawing.Color]::Transparent; $lock.Margin = New-Object System.Windows.Forms.Padding(0)
      $logoBox = New-Object System.Windows.Forms.PictureBox
      $logoBox.Size = New-Object System.Drawing.Size(56, 56); $logoBox.SizeMode = 'Zoom'; $logoBox.BackColor = [System.Drawing.Color]::Transparent
      $logoBox.Margin = New-Object System.Windows.Forms.Padding(0, 0, 12, 0); $logoBox.AccessibleName = 'RADE logo'
      $logoBox.Image = [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(, [System.Convert]::FromBase64String($logoPng))))
      $word = New-Object System.Windows.Forms.Label
      $word.AutoSize = $true; $word.Text = 'RADE'; $word.ForeColor = [System.Drawing.Color]::White; $word.BackColor = [System.Drawing.Color]::Transparent
      $word.Anchor = 'Left'; $word.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 0)   # Anchor Left: centered on the logo's midpoint
      try { $word.Font = New-Object System.Drawing.Font($form.Font.FontFamily, [single]20, $bold) } catch { $null = $_ }
      $lock.Controls.Add($logoBox, 0, 0); $lock.Controls.Add($word, 1, 0)
      $tag = New-Object System.Windows.Forms.Label
      $tag.AutoSize = $true; $tag.MaximumSize = New-Object System.Drawing.Size(180, 0); $tag.Text = 'Test and deploy apps for your organization'
      $tag.ForeColor = $mist; $tag.BackColor = [System.Drawing.Color]::Transparent; $tag.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 16)
      $rule = New-Object System.Windows.Forms.Panel
      $rule.Height = 1; $rule.Width = 178; $rule.BackColor = [System.Drawing.Color]::FromArgb(70, 105, 150); $rule.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 14)
      $stepBox = New-Object System.Windows.Forms.FlowLayoutPanel
      $stepBox.AutoSize = $true; $stepBox.FlowDirection = 'TopDown'; $stepBox.WrapContents = $false; $stepBox.BackColor = [System.Drawing.Color]::Transparent; $stepBox.Margin = New-Object System.Windows.Forms.Padding(0)
      $railFonts = @((New-Object System.Drawing.Font($form.Font.FontFamily, [single]11)), (New-Object System.Drawing.Font($form.Font.FontFamily, [single]11, $bold)))   # made once, reused
      $railNames = @('Choose', 'Check', 'Deploy')
      $paintRailStep = { param($P, $G)
        # Rail steps (layout P1): a 22 px circle per screen. This screen: AF yellow with a navy number, the name yellow and
        # bold. Done: a white ring with a check mark, the name white. Later: a mist ring with the number, the name mist.
        try {
          $k = [int]$P.Tag; $now = [int]$script:screen; $d = & $sc 22; $y = [int](($P.Height - $d) / 2)
          $col = $(if ($k -eq $now) { $gold } elseif ($k -lt $now) { [System.Drawing.Color]::White } else { $mist })
          $center = [System.Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, NoPrefix, SingleLine'
          $G.SmoothingMode = 'AntiAlias'
          if ($k -eq $now) {
            $br = New-Object System.Drawing.SolidBrush($gold); $G.FillEllipse($br, 0, $y, $d, $d); $br.Dispose()
            [System.Windows.Forms.TextRenderer]::DrawText($G, [string]($k + 1), $smallBold, (New-Object System.Drawing.Rectangle(0, $y, $d, $d)), $navy, $center)
          } else {
            $pn = New-Object System.Drawing.Pen($col, [single][math]::Max(1, (& $sc 1))); $G.DrawEllipse($pn, [single]1, [single]($y + 1), [single]($d - 2), [single]($d - 2)); $pn.Dispose()
            if ($k -lt $now) {
              $pk = New-Object System.Drawing.Pen($col, [single](1.8 * $dpi / 96.0)); $pk.StartCap = 'Round'; $pk.EndCap = 'Round'
              $pts = [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([single](0.30 * $d), [single]($y + 0.52 * $d))), (New-Object System.Drawing.PointF([single](0.45 * $d), [single]($y + 0.68 * $d))), (New-Object System.Drawing.PointF([single](0.72 * $d), [single]($y + 0.36 * $d))))
              $G.DrawLines($pk, $pts); $pk.Dispose()
            } else { [System.Windows.Forms.TextRenderer]::DrawText($G, [string]($k + 1), $smallFont, (New-Object System.Drawing.Rectangle(0, $y, $d, $d)), $mist, $center) }
          }
          $tx = $d + (& $sc 10)
          [System.Windows.Forms.TextRenderer]::DrawText($G, [string]$railNames[$k], $railFonts[[int]($k -eq $now)], (New-Object System.Drawing.Rectangle($tx, 0, [math]::Max(1, $P.Width - $tx), $P.Height)), $col, [System.Windows.Forms.TextFormatFlags]'Left, VerticalCenter, NoPrefix, SingleLine')
        } catch { $null = $_ } }
      for ($k = 0; $k -lt 3; $k++) {
        $l = New-Object System.Windows.Forms.Panel
        $l.Size = New-Object System.Drawing.Size(180, 28); $l.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 2); $l.BackColor = [System.Drawing.Color]::Transparent; $l.Tag = $k
        $l.AccessibleRole = 'StaticText'; $l.AccessibleName = 'Step ' + ($k + 1) + ' of 3: ' + $railNames[$k]
        try { [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic, Instance').SetValue($l, $true, $null) } catch { $null = $_ }
        $l.Add_Paint({ & $paintRailStep $this $_.Graphics })
        $railSteps += $l; [void]$stepBox.Controls.Add($l)
      }
      $railFoot = New-Object System.Windows.Forms.Label
      $railFoot.AutoSize = $true; $railFoot.MaximumSize = New-Object System.Drawing.Size(180, 0); $railFoot.ForeColor = $mist; $railFoot.BackColor = [System.Drawing.Color]::Transparent
      $railFoot.Text = 'Round ' + $round + "`r`n" + 'Build ' + $buildId
      try { $railFoot.Font = New-Object System.Drawing.Font($form.Font.FontFamily, [single]9) } catch { $null = $_ }
      # A newer round shows here, at the foot of the rail (layout P1): it takes no height from the screens. Dark red = a problem.
      $newBox = New-Object System.Windows.Forms.Label
      $newBox.AutoSize = $true; $newBox.MaximumSize = New-Object System.Drawing.Size(178, 0); $newBox.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12); $newBox.Padding = New-Object System.Windows.Forms.Padding(8, 6, 8, 6)
      $newBox.BackColor = [System.Drawing.Color]::FromArgb(139, 26, 26); $newBox.ForeColor = [System.Drawing.Color]::White   # 9.3:1
      try { $newBox.Font = $smallFont } catch { $null = $_ }
      $newBox.Text = $(if ($newer) { 'A newer round, ' + $newer + ', is in the repository. Close RADE and run ' + $newer + ' instead.' } else { '' }); $newBox.Visible = [bool]$newer
      $row = 0; foreach ($c in @($lock, $tag, $rule, $stepBox, (New-Object System.Windows.Forms.Label), $newBox, $railFoot)) { $rt.Controls.Add($c, 0, $row); $row++ }
      $rail.Controls.Add($rt)
    } catch { $rail = $null; $railSteps = @() }
    # Primary buttons (Next, Run): Air Force blue with white text; gray when disabled, so the text keeps its contrast.
    # $paintState lives at this (form) scope, not inside $stylePrimary: event handlers run after $stylePrimary returns,
    # so a variable local to it is gone and '& $paintState' threw on Next (rade failure e-mail, 14 Nov 26).
    $paintState = { param($X) if ($X.Enabled) { $X.BackColor = $afBlue; $X.ForeColor = [System.Drawing.Color]::White; $X.FlatAppearance.BorderColor = $afBlue } else { $X.BackColor = [System.Drawing.Color]::FromArgb(233, 236, 240); $X.ForeColor = [System.Drawing.Color]::FromArgb(85, 85, 85); $X.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(201, 210, 220) } }
    $stylePrimary = { param($B)
      try {
        $B.FlatStyle = 'Flat'; $B.FlatAppearance.BorderColor = $afBlue; $B.ForeColor = [System.Drawing.Color]::White; $B.BackColor = $afBlue
        try { $B.Font = New-Object System.Drawing.Font($form.Font.FontFamily, [single]10, $bold) } catch { $null = $_ }
        $B.Add_EnabledChanged({ try { & $paintState $this } catch { $null = $_ } }); & $paintState $B   # light gray, dark-gray text (6.3:1) when disabled; styled from the start
        $B.Add_MouseEnter({ if ($this.Enabled) { $this.BackColor = $navy } }); $B.Add_MouseLeave({ try { & $paintState $this } catch { $null = $_ } })   # a click that disables Next leaves no navy hover
      } catch { $null = $_ } }
    & $stylePrimary $next; & $stylePrimary $run; & $styleSecondary $back; & $styleSecondary $exitB
    # One size for the bottom-right buttons, whatever the text ("Next: check", "Next: deploy", Run, Back, Exit).
    foreach ($nb in @($next, $back, $exitB, $run)) { try { $nb.AutoSize = $false; $nb.MinimumSize = New-Object System.Drawing.Size(132, 34); $nb.Size = New-Object System.Drawing.Size(132, 34) } catch { $null = $_ } }
    $form.Controls.Add($grid)
    if ($rail) { $form.Controls.Add($rail); $grid.BringToFront(); $crumb.Visible = $false; $banner.Visible = $false }   # the rail shows the screen steps and a newer round
    # the Fill control docks last, beside the rail; titles are navy from $mkTitle
    $form.ResumeLayout($false); $form.PerformLayout()

    $script:screen = 0; $script:running = $false; $script:off = 0
    $fillDeploy = {
      # The chosen app's steps only. $script:listIndex maps a step to its row in the list.
      $stepView.Rows.Clear(); $script:off = 0; $script:listIndex = @{}
      if ($cleanup.Count) { [void](& $stepAdd 'Clean-up' 'Moves finished files to the Recycle Bin. Clear the box to skip' $true); $script:off = 1 }
      foreach ($k in $script:appSteps) {
        $s = $steps[$k]
        $script:listIndex[$k] = $stepView.Rows.Count
        [void](& $stepAdd ($s.Name + $(if ($s.AskParam) { '  (asks for a folder)' } elseif ($s.Kind -eq 'guide') { '  (needs you)' } else { '' })) $(if ($s.Note) { $s.Note } else { '' }) ([bool]$s.Default))
      }
      $stepView.Height = $stepView.ColumnHeadersHeight + $stepView.RowTemplate.Height * [math]::Max(2, $stepView.Rows.Count) + 4
      $stepView.ClearSelection()
      $first = Get-RoundPlan
      $deployHead.Text = 'Deploy ' + $script:app.Name
      $dep = Test-Deploy; $toLabel.Visible = -not $dep; $toBox.Visible = -not $dep; $okBox.Visible = -not $dep   # a deploy sends nothing
      $where.Text = $first.Shown + $(if ($first.Found) { '' } else { '   (NOT found)' })
      $warnings = @()
      if (-not $first.Found) { $warnings += 'OneDrive folder NOT found in this Windows profile: open OneDrive from the Start menu and sign in, then paste and run again.' }
      $warn.Text = ($warnings -join "`r`n"); $warn.Visible = [bool]$warnings.Count
      $est = 0; $known = $true; foreach ($k in $script:appSteps) { $w = Get-StepWeight $hist0 $steps[$k]; $est += $w.Seconds; if (-not $w.Known) { $known = $false } }
      $allLabel.Text = 'Ready' + $dot + 'about ' + (Format-Duration $est) + ' in all'; $allRight.Text = $(if ($known) { 'based on earlier runs' } else { 'an estimate: no earlier runs' })
      $stepLabel.Text = 'This step: none running'; $stepRight.Text = ''
      if ($first.Found) { & $setHint 2 'Press Enter or select Run. Clear a step''s box to skip it' '' } else { & $setHint 2 'Sign in to OneDrive first (see the red line above)' 'FAILED' }
      $howTo = @('HOW TO USE THIS SCREEN',
        '  1. Confirm that "Writes to" shows your OneDrive folder, and enter the results e-mail address (saved for next time).',
        '  2. Press Enter or select Run. Clear a step''s box to skip it. Keep this window open until the log shows DONE.',
        '     Steps marked "(needs you)" open a short guide. Complete it, then select "Done".',
        '  3. At DONE, an Outlook draft opens with the summary and all result files. Review it, then select Send.',
        '     If no draft opens, the results folder opens and the summary is on the clipboard.',
        '  Closing this window stops the running step.', '')
      if ($dep) {
        $howTo = @('HOW TO USE THIS SCREEN',
          '  1. Confirm that "Writes to" shows your OneDrive folder.',
          '  2. Press Enter or select Run. Keep this window open until the log shows DONE.',
          '     Steps marked "(needs you)" open a short guide. Complete it, then select "Done".',
          '  3. At DONE, the report is in the results folder on this computer. Nothing is sent.',
          '  Closing this window stops the running step.', '')
      }
      $log.Text = (($howTo + $first.Lines) -join "`r`n") + "`r`n"
    }
    $setRow = { param([int]$I, $R)
      $p = $script:checkRows[$I]; if (-not $p) { return }
      $t = $p.Tag; $t.State = [string]$R.State; $t.A = [string]$R.Detail; $t.B = [string]$R.Fix
      $full = @(@($t.Full, ($t.State + ': ' + $t.A), $t.B) | Where-Object { $_ }) -join "`r`n"
      try { $tips.SetToolTip($p, $full); $p.AccessibleName = ($full -replace "`r`n", '. ') } catch { $null = $_ }
      $p.Invalidate()
      [System.Windows.Forms.Application]::DoEvents() }
    $showCheckState = {
      $c = @{ PASSED = 0; WARNING = 0; FAILED = 0; 'NOT RUN' = 0 }
      foreach ($id in $script:appChecks) { $r = $script:checkResults[$id]; if ($r) { $c[$r.State]++ } else { $c['NOT RUN']++ } }
      $block = Get-CheckBlock $script:checkResults
      $countLabels['PASSED'].Text = [string]$c.PASSED + ' passed'; $countLabels['WARNING'].Text = [string]$c.WARNING + $(if ($c.WARNING -eq 1) { ' warning' } else { ' warnings' })
      $countLabels['FAILED'].Text = [string]$c.FAILED + ' failed'; $countLabels['NOT RUN'].Text = [string]$c['NOT RUN'] + ' not run'
      foreach ($st in 'WARNING', 'FAILED', 'NOT RUN') { $countLabels[$st].Visible = [bool]$c[$st] }   # layout A: a zero count is not shown
      $sv = @($script:appChecks | Where-Object { $script:checkResults[$_].Saved }).Count
      & $setHint 1 ($(if ($c.FAILED) { 'Resolve each FAILED check, then select "Run checks again"' } elseif ($block) { 'Run each check marked NOT RUN with the link in its row' } else { 'Ready to deploy. Press Enter or select "Next: deploy"' }) +
        $(if ($sv) { ' (' + $sv + ' of ' + $script:appChecks.Count + ' reused from earlier runs)' } else { '' })) $(if ($block) { 'FAILED' } elseif ($c.WARNING) { 'WARNING' } else { 'PASSED' })
      $next.Enabled = (-not $block) }
    $runChecks = { param([string[]]$Kinds, [string[]]$Only, [bool]$Force)
      # Saved results (R17): a check with a good saved result is not run again unless $Force ("Run checks again" or a button).
      $site = $siteBox.Text.Trim()
      if (Test-SiteUrl $site) { try { if ($site -ne (Get-SiteUrl $basePath)) { Save-SiteUrl $basePath $site } } catch { $null = $_ } }
      $againB.Enabled = $false; foreach ($x in $script:rowBtns) { $x.Enabled = $false }; $next.Enabled = $false; $back.Enabled = $false
      $cache = Read-CheckCache; $script:savedWhy = @{}
      try {
      for ($i = 0; $i -lt $script:appChecks.Count; $i++) {
        $id = $script:appChecks[$i]; $d = Get-CheckDef $id
        if ($form.IsDisposed -or $script:closing) { return }   # the window was closed during a check
        if ($Kinds -notcontains $d.Kind) {
          # A sign-in or look-and-answer check that was not asked for now: use its saved result, or say it is too old.
          $have = $script:checkResults[$id]
          if ($have) { & $setRow $i $have }
          else {
            $sv = Get-CheckToRun $d $cache $basePath $site $false
            if ($sv) { $script:checkResults[$id] = $sv; & $setRow $i $sv }
            elseif ($script:savedWhy[$id]) { & $setRow $i (Format-CheckResult 'NOT RUN' $script:savedWhy[$id] $(if ($d.Kind -eq 'signin') { 'Select "Sign in and check site rights"' } else { 'Select "Check Power Automate"' })) }
          }
          continue
        }
        if ($Only -and $Only -notcontains $id) { continue }
        $sv = Get-CheckToRun $d $cache $basePath $site $Force
        if ($sv) { $script:checkResults[$id] = $sv; & $setRow $i $sv; continue }
        & $setRow $i (Format-CheckResult 'RUNNING' 'checking now' '')
        & $setHint 1 ('Checking: ' + $d.Name + ' ...') 'RUNNING'
        $r = Invoke-Check $d $basePath $site { [System.Windows.Forms.Application]::DoEvents() }
        $script:checkResults[$id] = $r
        & $setRow $i $r
      }
      } finally {
        Save-CheckCache $script:checkResults $basePath $site
        if (-not ($form.IsDisposed -or $script:closing)) { $againB.Enabled = $true; foreach ($x in $script:rowBtns) { if (-not $x.IsDisposed) { $x.Enabled = $true } }; $back.Enabled = $true; & $showCheckState }
      } }
    $fillChecks = {
      # The app's checks by group; the first group (Local) fills the left column, the others the right one (layout P1).
      $checkHead.Text = 'Check ' + $script:app.Name
      $checkCols.SuspendLayout()
      & $stackClear $colL; & $stackClear $colR
      $script:checkRows = @{}; $script:rowBtns = @()
      $groups = @(); foreach ($id in $script:appChecks) { $gr = [string](Get-CheckDef $id).Group; if ($groups -notcontains $gr) { $groups += $gr } }
      foreach ($gr in $groups) {
        $st = $(if ($gr -eq $groups[0]) { $colL } else { $colR })
        if ($gr -ne $groups[0] -and $colR.RowCount) { $gap = New-Object System.Windows.Forms.Panel; $gap.Height = & $sc 16; $gap.Margin = New-Object System.Windows.Forms.Padding(0); & $stackAdd $colR $gap }
        & $stackAdd $st (& $mkGroupHead $gr)
        for ($i = 0; $i -lt $script:appChecks.Count; $i++) {
          $d = Get-CheckDef $script:appChecks[$i]; if ([string]$d.Group -ne $gr) { continue }
          $p = & $mkCheckRow $d; $script:checkRows[$i] = $p; & $stackAdd $st $p
          & $setRow $i (Format-CheckResult 'NOT RUN' $(if ($d.Kind -eq 'signin') { 'CAC sign-in, read-only' } elseif ($d.Kind -eq 'guide') { 'You look and answer, read-only' } else { 'Waiting' }) '')
        }
      }
      $checkCols.ResumeLayout(); $checkScroll.AutoScrollPosition = New-Object System.Drawing.Point(0, 0)
      $needSite = [bool](@($script:appChecks | Where-Object { $_ -in 'net-site', 'site-rights' }).Count)
      $sitePanel.Visible = $needSite }
    $showScreen = { param([int]$I)
      $script:screen = $I
      $pChoose.Visible = ($I -eq 0); $pCheck.Visible = ($I -eq 1); $pDeploy.Visible = ($I -eq 2)
      $crumb.Text = @('Step 1 of 3: Choose', 'Step 2 of 3: Check', 'Step 3 of 3: Deploy')[$I]
      for ($j = 0; $j -lt $railSteps.Count; $j++) {   # the rail circles ($paintRailStep reads $script:screen)
        try { $railSteps[$j].AccessibleName = 'Step ' + ($j + 1) + ' of 3: ' + @('Choose', 'Check', 'Deploy')[$j] + $(if ($j -eq $I) { ', this screen' } elseif ($j -lt $I) { ', done' } else { '' }); $railSteps[$j].Invalidate() } catch { $null = $_ } }
      $back.Visible = ($I -gt 0); $next.Visible = ($I -lt 2); $run.Visible = ($I -eq 2)
      $next.Text = $(if ($I -eq 0) { 'Next: check' } else { 'Next: deploy' })
      & $showHint
      if ($I -eq 0) { $next.Enabled = ($appList.SelectedIndex -ge 0); $form.AcceptButton = $next; $appList.Focus() | Out-Null }
      if ($I -eq 1) {
        $next.Enabled = (-not (Get-CheckBlock $script:checkResults))
        $form.AcceptButton = $next
        if ($sitePanel.Visible -and -not (Test-SiteUrl $siteBox.Text.Trim())) { $siteBox.Focus() | Out-Null } elseif ($next.Enabled) { $next.Focus() | Out-Null } else { $againB.Focus() | Out-Null }
      }
      if ($I -eq 2) {
        # Enter starts the run (PFM 13 Nov). Focus: the address box when it is empty, else Run.
        $form.AcceptButton = $run
        try { $pDeploy.PerformLayout(); & $fitLog } catch { $null = $_ }
        if ($toBox.Text -or (Test-Deploy)) { $run.Focus() | Out-Null } else { $toBox.Focus() | Out-Null }
      } }
    $appList.Add_SelectedIndexChanged({
      if ($appList.SelectedIndex -ge 0) { Select-App $appList.SelectedIndex; & $setHint 0 ($script:app.Name + ' selected. Press Enter or select "Next: check"') '' }
      if ($script:screen -eq 0) { $next.Enabled = ($appList.SelectedIndex -ge 0) } })
    $appList.Add_DoubleClick({ if ($appList.SelectedIndex -ge 0) { $next.PerformClick() } })
    $next.Add_Click({
      if ($script:screen -eq 0 -and $appList.SelectedIndex -lt 0) { return }   # nothing chosen yet
      if ($script:screen -eq 0) { & $fillChecks; & $showScreen 1; & $runChecks @('auto') @() $false; & $showScreen 1; return }
      if ($script:screen -eq 1 -and -not (Get-CheckBlock $script:checkResults)) { & $fillDeploy; & $showScreen 2 } })
    $back.Add_Click({ if (-not $script:running -and $script:screen -gt 0) { & $showScreen ($script:screen - 1) } })
    $form.Add_KeyDown({ if ($_.KeyCode -eq 'Escape' -and $back.Visible -and -not $script:running) { $_.SuppressKeyPress = $true; $back.PerformClick() } })
    $againB.Add_Click({ & $runChecks @('auto') @() $true })
    # Enter in a box moves on instead of acting (review R06 #3: a stray Enter must not start a cleanup).
    $siteBox.Add_Enter({ $form.AcceptButton = $null })
    $siteBox.Add_Leave({ $form.AcceptButton = $next })
    $siteBox.Add_KeyDown({ if ($_.KeyCode -eq 'Return') { $_.SuppressKeyPress = $true; & $runChecks @('auto') @('net-site') $true; $next.Focus() | Out-Null } })
    $toBox.Add_Enter({ $form.AcceptButton = $null })
    $toBox.Add_Leave({ $form.AcceptButton = $run })
    $toBox.Add_KeyDown({ if ($_.KeyCode -eq 'Return') { $_.SuppressKeyPress = $true; $run.Focus() | Out-Null } })
    $form.Add_Shown({
      # Fit the screen (R09: 1280 x 800 at 150 % scaling is smaller than the window).
      $wa = [System.Windows.Forms.Screen]::FromControl($form).WorkingArea
      $form.Width = [Math]::Min($form.Width, [int]($wa.Width * 0.95)); $form.Height = [Math]::Min($form.Height, [int]($wa.Height * 0.95))
      $form.Left = $wa.Left + [int](($wa.Width - $form.Width) / 2); $form.Top = $wa.Top + [int](($wa.Height - $form.Height) / 2)
      $anim.Start()   # no application is selected for you (layout P1)
      & $showScreen 0 })

    $script:lastSummary = @()
    $say = { param($t) Add-RunLog $t; try { $log.AppendText($t + "`r`n"); [System.Windows.Forms.Application]::DoEvents() } catch { Write-Host $t } }
    $paint = {
      # Both bars from Get-Progress (the timer draws them). Both fill from left to right; with no PROGRESS lines the step bar
      # follows the time so far against the step's weight (Get-Progress StepShown, at most 90 %).
      if (-not $script:prog -or -not $script:stepStart) { return }
      $g = Get-Progress; $t = Get-ProgressText $g $script:statusBase
      & $setBar 'all' ([math]::Max($g.All, $script:bars['all'].Target)) $true   # the overall bar never moves back in a run
      & $setBar 'step' ([math]::Max($g.StepShown, $script:bars['step'].Target)) $true   # nor the step bar inside one step
      foreach ($pr in @(@($allLabel, $t.AllL), @($allRight, $t.AllR), @($stepLabel, $t.StepL), @($stepRight, $t.StepR))) { if ($pr[0].Text -ne [string]$pr[1]) { $pr[0].Text = [string]$pr[1] } } }
    $tick = { & $paint; [System.Windows.Forms.Application]::DoEvents() }
    $onStep = { param($k, $line)
      $i = $script:listIndex[$k]
      if ($null -ne $i) { $nm = $steps[$k].Name + ': '; & $stepSay $i $(if ($line.StartsWith($nm)) { $line.Substring($nm.Length) } else { $line }) }
      & $paint }
    $onStatus = { param($i, $count, $name, $estimate)
      $null = $i; $null = $count   # the labels read $script:prog
      $script:statusBase = $name; $script:stepStart = Get-Date; $script:stepEst = $estimate
      if ($i -le 1) { & $setBar 'all' 0 $false }   # a new run starts the overall bar at 0
      # The step row says it is running; the clean-up row (row 0) says done once the next step starts.
      if ($script:off -eq 1 -and $name -ne 'Clean-up' -and [string]$stepView.Rows[0].Cells[2].Value -eq 'RUNNING') { & $stepSay 0 'Finished files moved to the Recycle Bin (see the log)' 'PASSED' }
      $now = 'Started ' + (Get-Date -Format 'HH:mm')
      if ($name -eq 'Clean-up' -and $script:off -eq 1) { & $stepSay 0 $now 'RUNNING' }
      else { foreach ($kk in @($script:listIndex.Keys)) { if ($steps[$kk].Name -eq $name) { & $stepSay $script:listIndex[$kk] $now 'RUNNING' } } }
      & $setBar 'step' 0 $false
      & $paint; [System.Windows.Forms.Application]::DoEvents() }
    $windowLine = { if ($okBox.Checked) { 'Window: OK' } else { 'Window: NOT OK - write here what overlapped or was cut off' } }
    $toFront = { $form.TopMost = $true; $form.Activate(); $form.TopMost = $false }
    $run.Add_Click({
      $run.Enabled = $false; $draft.Enabled = $false; $copy.Enabled = $false; $open.Enabled = $false; $back.Enabled = $false; $script:running = $true
      & $setHint 2 'Running. Keep this window open until the log shows DONE' 'RUNNING'
      foreach ($sr in $stepView.Rows) { $sr.Cells[2].Value = $(if ([bool]$sr.Cells[0].Value) { 'WAITING' } else { 'OFF' }) }; $stepView.Invalidate()   # a second run starts clean
      $to = $(if (Test-Deploy) { '' } else { $toBox.Text.Trim() })
      if ($to -and -not (Test-MailTo $to)) {
        $script:helped = @{}; & $say 'The e-mail address does not look right.'; & $say (Get-WhatToDo 'e-mail address does not look right')
        $run.Enabled = $true; $back.Enabled = $true; $script:running = $false; & $setHint 2 'The e-mail address does not look right. Correct it, then select Run' 'FAILED'; $toBox.Focus() | Out-Null; return
      }
      $clean = ($script:off -eq 1 -and (& $stepOn 0))
      $sel = @(); for ($k = 0; $k -lt $steps.Count; $k++) { $i = $script:listIndex[$k]; $sel += ($null -ne $i -and (& $stepOn $i)) }
      # A checked step that needs a folder asks for it now; Cancel skips that step.
      $answers = @(); for ($k = 0; $k -lt $steps.Count; $k++) {
        $a = ''
        if ($sel[$k] -and $steps[$k].AskParam) {
          $pick = New-Object System.Windows.Forms.FolderBrowserDialog
          $pick.Description = $steps[$k].AskPrompt; $pick.ShowNewFolderButton = $false
          if ($pick.ShowDialog($form) -eq 'OK') { $a = $pick.SelectedPath } else { $sel[$k] = $false; & $say ($steps[$k].Name + ': skipped (no folder picked)') }
          $pick.Dispose()
        }
        $answers += $a
      }
      $checkLines = Get-CheckSummary $script:checkResults
      $script:roundStart = Get-Date
      try {
        $script:lastSummary = Invoke-Round $clean $sel $to $say $tick $onStep $onStatus $windowLine $answers $checkLines
        $script:basePath = Get-BasePath   # RADE may have moved the app folder (R17)
        $script:stepStart = $null; & $setBar 'all' 1 $false; & $setBar 'step' 1 $false
        $allLabel.Text = 'DONE in ' + (Format-Duration ((Get-Date) - $script:roundStart).TotalSeconds); $allRight.Text = [string]$script:lastSummary[0]
        $stepLabel.Text = $(if ($script:draftMade) { 'The Outlook draft is open' } else { 'The results folder is open and the summary is copied' }); $stepRight.Text = ''
        & $setHint 2 $(if ($script:draftMade) { 'Done. Review the Outlook draft, then select Send' } else { 'Done. Paste the summary into an e-mail and attach the results files' }) $(if ([string]$script:lastSummary[0] -match 'NEEDS REVIEW') { 'FAILED' } else { 'PASSED' })
        if (Test-Deploy) {
          $stepLabel.Text = 'The report is in the results folder'
          & $setHint 2 'Done. Nothing was sent' $(if ([string]$script:lastSummary[0] -match 'NEEDS REVIEW') { 'FAILED' } else { 'PASSED' })
          $copy.Enabled = $true; $open.Enabled = $true; & $toFront; $open.Focus() | Out-Null
        } else {
        $copy.Enabled = $true; $open.Enabled = $true; $draft.Enabled = $true
        $copy.PerformClick()
        if (-not $script:draftMade) { $open.PerformClick(); & $toFront; $copy.Focus() | Out-Null }
        }
      }
      catch {
        $script:stepStart = $null
        if ($script:closing -or $form.IsDisposed) { return }   # Exit during a step: the report on disk says STOPPED
        $script:basePath = Get-BasePath
        $msg = 'STOPPED: ' + (ConvertTo-Masked ([string]$_)); & $say $msg
        $w = Get-WhatToDo $msg; if ($w) { & $say $w }
        & $setBar 'step' $script:bars['step'].Target $false; & $setBar 'all' $script:bars['all'].Target $false
        $allLabel.Text = 'STOPPED'; $allRight.Text = 'See the last lines of the log'; & $setHint 2 'Stopped. See the last lines of the log' 'FAILED'; & $toFront
      }
      $run.Enabled = $true; $back.Enabled = $true; $script:running = $false
    })
    $draft.Add_Click({
      $why = Save-RoundDraft $script:resultsDir $script:lastSummary $toBox.Text.Trim() (& $windowLine)
      if ($why) { $script:helped = @{}; $m = 'The Outlook draft could not be created (' + $why + ').'; & $say $m; & $say (Get-WhatToDo $m) } else { & $say 'The Outlook draft is open.' }
    })
    $copy.Add_Click({
      try { [System.Windows.Forms.Clipboard]::SetText(($script:lastSummary -join "`r`n")); & $say $(if (Test-Deploy) { 'Summary copied.' } else { 'Summary copied. Paste it into the e-mail body; its first line is the subject.' }) }
      catch { & $say ('The clipboard is busy. Select Copy summary again. (' + $_.Exception.Message + ')') }
    })
    $open.Add_Click({ if ($script:resultsDir) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $script:resultsDir + '"') } })
    $exitB.Add_Click({ $form.Close() })
    $form.Add_FormClosing({
      # Exit (or the X): ask first only while a step runs, because closing stops it (R17, PFM 14 Nov 26).
      if ($script:running -and -not $script:closing) {
        $a = [System.Windows.Forms.MessageBox]::Show($form, 'A step is running. If you exit now, RADE stops it and the round ends as STOPPED (the report in the results folder says so). Exit now?', 'RADE - Exit', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning, [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
        if ([string]$a -ne 'Yes') { $_.Cancel = $true; return }
      }
      $script:closing = $true; try { $anim.Stop() } catch { $null = $_ }
      if ($script:child -and -not $script:child.HasExited) { try { $script:child.Kill() } catch { $null = $_ } } })
    [void]$form.ShowDialog()
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
  Write-Host ('RADE (Redacted Application Deployment Engine) - ' + $round + ' - build ' + $buildId)
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
    if (Test-SiteUrl $v) { $site0 = $v }
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
  $sel = @(); for ($k = 0; $k -lt $steps.Count; $k++) { $sel += ($script:appSteps -contains $k -and [bool]$steps[$k].Default -and -not $steps[$k].AskParam) }   # text mode: steps that need a folder are skipped
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
BASE_CHECKS = ['ps', 'lang', 'onedrive', 'disk', 'write', 'child', 'outlook', 'net-bookmark']
CHECK_IDS = re.findall(r"@\{ Id = '([a-z-]+)'", ENGINE)


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
        out.append('$apps += @{ Name = %s; Summary = %s; Steps = @(%s); Checks = @(%s); Mode = %s; Version = %s }'
                   % (q(a['name']), q(a['summary']), ', '.join(str(i) for i in idx), ', '.join(q(c) for c in checks), q(mode), q(version)))
    return out


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
    steps = ['$steps += @{ Name = %s; Dir = %s; File = %s; Default = $%s; AskParam = %s; AskPrompt = %s; ScreenOnly = %s; Minutes = %d; Args = %s; Note = %s; Kind = %s; Guide = @(%s); Url = %s; UrlConfig = %s; Marker = %s; Estimate = %d; DoneText = %s; DoneLog = %s; Makes = @(%s) }'
             % (q(s['name']), q(s['dir']), q(s['file']), 'true' if step_default(s) else 'false',
                q(s.get('ask', {}).get('param', '')), q(s.get('ask', {}).get('prompt', '')), q(s.get('screenOnly', '')),
                int(s.get('minutes', 30)), q(s.get('args', '')), q(s.get('note', '')), q(s.get('kind', 'script')),
                ', '.join(q(g) for g in s.get('guide', [])), q(s.get('url', '')), q(s.get('urlConfig', '')), q(s.get('marker', '')),
                int(s.get('estimate', 0)) * 60, q(s.get('doneText', '')), q(s.get('doneLog', '')),
                ', '.join('@{ kind = %s; name = %s }' % (q(m['kind']), q(m['name'])) for m in s.get('makes', [])))
             for s in b['steps']]
    apps = app_lines(b)
    # Data files the round downloads (not code, PFM 3A): repo files from raw main, checked by SHA-256; public pages as they are.
    fetch = []
    for f in b.get('fetch', []):
        if 'src' in f:
            data = (ROOT / f['src']).read_bytes()
            url = 'https://raw.githubusercontent.com/' + APP['repo'] + '/main/' + f['src']
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
    logo = base64.b64encode(LOGO.read_bytes()).decode('ascii')   # layout B rail (PFM 14 Nov 26)
    engine = ENGINE.replace('@@HOME@@', APP['home']).replace('@@PREFIX@@', APP['prefix']).replace('@@APP@@', APP['folder'])
    own = '$ownPatterns = @(' + ', '.join(q(p) for p in APP['own']) + ')\n'
    go = q('https://raw.githubusercontent.com/' + APP['repo'] + '/main/go.md')
    body = ('$goUrl = %s\n$webAgent = \'Mozilla/5.0 (Windows NT 10.0; Win64; x64) RADE\'\n$logoPng = \'%s\'\n%s$round = %s\n$appFolder = %s\n$usersRoot = \'C:\\Users\'\n$files = @()\n%s\n$fetch = @()\n%s\n$steps = @()\n%s\n$collect = @()\n%s\n$cleanup = @()\n%s\n$known = @(%s)\n$apps = @()\n%s\n%s'
            % (go, logo, own, q(b['round']), q(APP['folder']), '\n'.join(parts), '\n'.join(fetchs), '\n'.join(steps), '\n'.join(collect), '\n'.join(cleanup), ', '.join(q(k) for k in known), '\n'.join(apps), engine))
    build_id = hashlib.sha256(body.encode('ascii')).hexdigest()[:8]
    modes = {a.get('mode', 'test') for a in b.get('apps', [])} or {'test'}
    sends = ' on this computer. It sends nothing.' if modes == {'deploy'} else ', then opens an Outlook draft with them (never sent; a deploy makes no draft).' if 'deploy' in modes else ', then opens an Outlook draft with them (never sent).'
    head = ('<#\n  RADE (Redacted Application Deployment Engine), round bundle: %s.\n'
            '  GENERATED by the RADE engine (rhope-ops/RADE engine/rade_build.py, sha256 %s) from %s; do not edit.\n'
            '  How to run: open Windows PowerShell ISE, File > New, paste all of this text into the script pane, press F5.\n'
            '  The RADE window opens: press Enter (or Run); it uses your Windows profile folder. It writes the files below into the task folders under\n'
            '  C:\\Users\\<DODID>\\OneDrive - United States Air Force\\RADE\\%s (replacing older copies), runs the steps,\n'
            '  and saves its results in Rounds\\%s%s No download, no admin rights.\n'
            '#>\n$buildId = \'%s\'\n' % (b['title'], ENGINE_SHA[:12], MANIFEST, APP['folder'], b['round'], sends, build_id))
    return head + body


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
    if a.check:
        print('PASTE bundles=%d stale=%d' % (len(m['bundles']), stale))
        sys.exit(1 if stale else 0)


ENGINE_SHA = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
APP, MANIFEST = None, None

if __name__ == '__main__':
    main()
