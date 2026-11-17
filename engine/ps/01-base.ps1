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
