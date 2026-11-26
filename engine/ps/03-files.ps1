# RADE engine part 03, files: the clean-up plan and the move to the Recycle Bin, the folder inventory,
# saving the bundle's files, downloading data files (checked by SHA-256), the environment a step is given and the
# shortcut icon file (engine-v42; Save-AppIcon, used by Add-DesktopIcon in part 05). Uses 01 and 02.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

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
# Moves the files of the clean-up plan, then the folders left empty, to the Recycle Bin and says what it did. Takes the
# base folder and a Say block; gives back the summary line and sets the round to "needs review" if one move failed.
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
# Puts each shared block back into a file's text: a line "# @@SHARED <key>@@ ..." becomes the block $shared[<key>]
# (the bundle keeps a block that many files hold only once; engine/rade_build.py checks the round trip). Takes the
# text of one file; returns the text as it was in the app's repository.
function Expand-SharedBlock([string]$Text) {
  if (-not $Text.Contains('# @@SHARED ')) { return $Text }
  $out = foreach ($line in ($Text -split "`n")) { if ($line -match '^# @@SHARED (\S+)@@') { [string]$shared[$Matches[1]] } else { $line } }
  return ($out -join "`n")
}
# Saves every file of the bundle (text with CRLF and a BOM, or decoded binary) into its folder under the base folder.
# Takes the base folder and a Say block; gives back nothing.
function Write-BundleFile([string]$Base, [scriptblock]$Say) {
  $utf8Bom = New-Object System.Text.UTF8Encoding $true
  & $Say 'Preparing files'
  foreach ($f in $files) {
    $dir = Join-Path $Base $f.Dir
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    $path = Join-Path $dir $f.Name
    if ($f.Kind -eq 'text') { [System.IO.File]::WriteAllText($path, (((Expand-SharedBlock $f.Data) -replace "`r?`n", "`r`n") + "`r`n"), $utf8Bom) }
    else { [System.IO.File]::WriteAllBytes($path, [System.Convert]::FromBase64String(($f.Data -replace '\s', ''))) }
    & $Say ('  Saved   ' + $f.Dir + '\' + $f.Name + '  (SHA-256 ' + $f.Sha + ')')
  }
  & $Say ('  ' + $files.Count + ' files saved.')
}
# Sets the TLS versions of this PowerShell's web calls (fleet v2, DEC 1): assigns TLS 1.2, and adds TLS 1.3 only when
# this .NET has that enum value (Windows PowerShell 5.1 on an older .NET throws on the name). Assigns, never ORs, so
# SSL 3, TLS 1.0 and TLS 1.1 are off. Takes nothing; returns nothing. Called before each download and web request.
function Use-TlsFloor {
  try {
    $p = [Net.SecurityProtocolType]::Tls12
    if ([Enum]::GetNames([Net.SecurityProtocolType]) -contains 'Tls13') { $p = $p -bor [Net.SecurityProtocolType]'Tls13' }
    [Net.ServicePointManager]::SecurityProtocol = $p
  } catch { $null = $_ }   # a host that refuses the setting keeps its own; the request then names the TLS in its error
}

function Save-RoundDownload([string]$Base, [scriptblock]$Say) {
  # Data files only (briefs, public color documents), never code (PFM 3A). The address never gets the Windows sign-in
  # (engine-v14, as in Get-WebRequest); only the work proxy does.
  # A repo file must match its SHA-256; a failed download leaves the link on the bookmark page as the fallback.
  $ok = 0; $bad = 0
  if (-not $fetch.Count) { return '' }
  Use-TlsFloor
  foreach ($f in $fetch) {
    $dir = Join-Path $Base $f.Dir
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    $path = Join-Path $dir $f.Name
    $wc = New-Object System.Net.WebClient
    try {
      $wc.UseDefaultCredentials = $false
      try { $wc.Headers['User-Agent'] = $webAgent } catch { $null = $_ }   # R21: as in Get-WebRequest
      try { if ($wc.Proxy) { $wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials } } catch { $null = $_ }   # no proxy: nothing to sign in to
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
  $o = [ordered]@{ RADE_CONTRACT = '1'; RADE_MODE = [string]$script:app.Mode; RADE_APP = [string]$script:app.Name; RADE_APP_VERSION = [string]$script:app.Version
    RADE_INSTALLED_VERSION = $inst; RADE_STEP_LAST = $last; RADE_SITE = $(if (Test-SiteUrl (Get-SiteUrl $Base)) { [string](Get-SiteUrl $Base) } else { '' }) }
  # Uninstall (engine-v40) sets RADE_MODE=uninstall and RADE_MADE for its own steps only (Invoke-Uninstall, part 13).
  if ($script:stepEnvExtra) { foreach ($k in @($script:stepEnvExtra.Keys)) { $o[[string]$k] = [string]$script:stepEnvExtra[$k] } }
  return $o
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
<#
.SYNOPSIS
Makes the bytes of an .ico file from PNG images, one entry for each image (Windows Vista and later read PNG entries).
.PARAMETER Png
The PNG images, each as a byte array.
.PARAMETER Size
The side in pixels of each image, in the same order (1 to 256).
.OUTPUTS
The bytes of the .ico file.
#>
function ConvertTo-IcoByte([object[]]$Png, [int[]]$Size) {
  $ms = New-Object System.IO.MemoryStream; $bw = New-Object System.IO.BinaryWriter($ms)
  try { $n = $Png.Count; $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$n)   # header: reserved, type 1 (icon), count
    $off = 6 + 16 * $n
    for ($i = 0; $i -lt $n; $i++) { $s = $Size[$i]; $b = [byte]$(if ($s -ge 256) { 0 } else { $s })   # 0 means 256
      $bw.Write($b); $bw.Write($b); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([uint16]1); $bw.Write([uint16]32)
      $bw.Write([uint32]([byte[]]$Png[$i]).Length); $bw.Write([uint32]$off); $off += ([byte[]]$Png[$i]).Length }
    foreach ($p in $Png) { $bw.Write([byte[]]$p) }
    $bw.Flush(); return , $ms.ToArray() } finally { $bw.Dispose() }
}
<#
.SYNOPSIS
Writes the chosen app's shortcut icon as one .ico file (R44 E1).
.DESCRIPTION
The app's logo (else RADE's) at 16, 32, 48 and 256 px, centered on a clear square, each a PNG entry. Needs
System.Drawing; never an error.
.PARAMETER Path
The path of the .ico file.
.OUTPUTS
$true when the file is written, else $false.
#>
function Save-AppIcon([string]$Path) {
  try { $src = $(if ([string]$appLogoPng) { [string]$appLogoPng } else { [string]$logoPng })
    $img = New-Object System.Drawing.Bitmap((New-Object System.IO.MemoryStream(, [System.Convert]::FromBase64String($src))))
    $pngs = @(); $sizes = @(16, 32, 48, 256)
    try { foreach ($s in $sizes) { $bm = New-Object System.Drawing.Bitmap($s, $s, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb); $g = [System.Drawing.Graphics]::FromImage($bm)
        try { $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'HighQuality'; $g.PixelOffsetMode = 'HighQuality'; $g.Clear([System.Drawing.Color]::Transparent)
          $k = [math]::Min($s / [double]$img.Width, $s / [double]$img.Height); $w = [int][math]::Round($img.Width * $k); $h = [int][math]::Round($img.Height * $k)
          $g.DrawImage($img, [int](($s - $w) / 2), [int](($s - $h) / 2), $w, $h)
          $ps = New-Object System.IO.MemoryStream; $bm.Save($ps, [System.Drawing.Imaging.ImageFormat]::Png); $pngs += , $ps.ToArray(); $ps.Dispose() }
        finally { $g.Dispose(); $bm.Dispose() } } } finally { $img.Dispose() }
    [System.IO.File]::WriteAllBytes($Path, (ConvertTo-IcoByte $pngs $sizes)); return $true } catch { return $false }
}
