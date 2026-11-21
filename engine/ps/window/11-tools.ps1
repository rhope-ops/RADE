# RADE window part 11, the Maintenance tools on the Maintenance screen (the Administrator, 2026-11-20): a click on the
# Diagnose or the Back up row runs it (engine/ps/13-maintenance.ps1), with a card while it runs and a card with its result.
# Restore (engine-v31, the Administrator, 2026-11-21): pick a backup, the dry-run card with its counts, the typed app
# name, then the write and its result card. Listed before 10-keys.ps1 in engine/rade_build.py (that part shows the form).
# Network: none here (part 13 names what each tool reaches).
# Writes: none here.
# Credentials: none.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# The rows of the Maintenance screen. Diagnose and Back up (engine-v30); Restore (engine-v31) for an app that names it.
$ui.ToolRows = {
  $n = @($script:app.Backup).Count; $lists = $(if ($n -eq 1) { '1 list' } elseif ($n) { [string]$n + ' lists' } else { 'No lists named' })
  @(@{ Index = 0; Name = 'Diagnose'; Ver = ''; Sub = 'Checks the install and runs the checks again. Changes nothing.'; R1 = 'Report on this computer' },
    @{ Index = 1; Name = 'Back up'; Ver = ''; Sub = "Saves the app's lists to this computer. Changes nothing on the site."; R1 = $lists },
    $(if ($script:app.Restore) { @{ Index = 2; Name = 'Restore'; Ver = ''; Sub = 'Puts missing rows back from a backup, after a dry run. Test sites only.'; R1 = 'Writes to the site' } }
      else { @{ Off = $true; Index = 2; Name = 'Restore'; Ver = ''; Sub = 'Puts missing rows back from a backup, after a dry run.'; R1 = 'Not set up by this app'; Soon = $true } })) }

$ui.RunTool = {
  <#
  .SYNOPSIS
  Runs one Maintenance tool from its row: a card while it runs, then the result card.
  .PARAMETER J
  The row: 0 Diagnose, 1 Back up, 2 Restore (its first card: $ui.VRestorePick).
  #>
  param([int]$J)
  if ($J -eq 2 -and -not $ui.Busy) { & $ui.VRestorePick; return }
  if ($J -notin 0, 1 -or $ui.Busy) { return }
  $name = $(if ($J -eq 0) { 'Diagnose' } else { 'Back up' })
  $what = $(if ($J -eq 0) { 'Read-only. Nothing is changed.' } else { 'Reads the lists and saves them on this computer. Nothing on the site changes. A sign-in window may open.' })
  & $ui.SetCard @{ View = 'toolrun'; Kicker = [string]$ui.Kick.Text; Sentence = ($name + ' is running.'); P = @($what) }
  $ui.Busy = $true; [System.Windows.Forms.Application]::DoEvents(); $res = $null
  try { $bp = Get-BasePath
    if ($J -eq 0) { $res = Invoke-Diagnose $bp { [System.Windows.Forms.Application]::DoEvents() } } else { $res = Invoke-Backup $bp { [System.Windows.Forms.Application]::DoEvents() } } }
  catch { $res = @{ State = 'failed'; Findings = 1; Path = ''; Lines = @(($name + ' stopped with an error [' + $_.Exception.GetType().Name + '].'), 'Nothing was changed. Select it again.') } }
  finally { $ui.Busy = $false }
  if ($ui.Form.IsDisposed -or $script:closing) { return }
  & $ui.ToolResult $name $res }

$ui.ToolResult = {
  <#
  .SYNOPSIS
  Shows the result card of a Maintenance tool: what it found, saved or put back, and the file or folder it wrote.
  .PARAMETER Name
  The tool: Diagnose, Back up or Restore.
  .PARAMETER Res
  Its result: Invoke-Diagnose (Lines, Path, Findings), Invoke-Backup or Invoke-Restore (State, Lines, Path).
  #>
  param([string]$Name, $Res)
  $diag = ($Name -eq 'Diagnose'); $bad = $(if ($diag) { [int]$Res.Findings -gt 0 } else { [string]$Res.State -in 'failed', 'refused', 'changed' })
  $st = [string]$Res.State
  $sent = $(if ($diag -and $bad) { 'Diagnose found ' + $Res.Findings + ' thing(s) to fix.' } elseif ($diag) { 'Diagnose found nothing to fix.' }
    elseif ($Name -eq 'Restore') { $(switch ($st) { 'done' { 'Restore put the missing rows back.' } 'refused' { 'Restore cannot run here.' } 'none' { 'Restore has no backup to use.' }
        'changed' { 'Restore wrote nothing: the site changed after the dry run.' } default { 'Restore did not finish.' } }) }
    elseif ($st -eq 'done') { 'Back up saved the lists.' } elseif ($st -eq 'none') { 'Back up has no lists to save.' }
    elseif ($st -eq 'no-site') { 'Back up saved nothing.' } else { 'Back up did not save everything.' })
  $lines = @($Res.Lines); $path = $(if ($Res.Path) { [string]$Res.Path } else { $null })
  & $ui.SetCard @{ View = 'toolres'; Light = $(if ($bad) { 'bad' } else { '' }); Kicker = [string]$ui.Kick.Text; Sentence = $sent
    P = @($lines | Select-Object -First 2); Lines = @($lines | Select-Object -Skip 2); Path = $path
    Buttons = @(@{ Text = 'Done'; Kind = 'primary'; Act = { & $ui.VTools $ui.MaintVerb } }); Back = { & $ui.VTools $ui.MaintVerb } }
  & $ui.ToFront }

# Restore, card 1 (view restpick): the backups on this computer, newest first, one row each. A site that is not a test
# site, or no backup, goes straight to the result card. Takes nothing.
$ui.VRestorePick = {
  $appPath = Get-BasePath; $siteCheck = Test-RestoreSite $appPath
  if (-not $siteCheck.Ok) { & $ui.ToolResult 'Restore' @{ State = 'refused'; Path = ''; Lines = $siteCheck.Lines }; return }
  $ui.RestoreSets = @(Get-BackupSet $appPath)
  if (-not $ui.RestoreSets.Count) { & $ui.ToolResult 'Restore' @{ State = 'none'; Path = ''; Lines = @('There is no backup of this app on this computer.', 'Select "Back up" first.') }; return }
  $rows = @(for ($k = 0; $k -lt $ui.RestoreSets.Count; $k++) { $set = $ui.RestoreSets[$k]
      @{ Index = $k; Name = $set.Name; Ver = ''; Sub = ([string]$set.Lists + ' of ' + @($script:app.Backup).Count + ' lists'); R1 = $(if ($k -eq 0) { 'Newest' } else { '' }) } })
  & $ui.SetCard @{ View = 'restpick'; Kicker = [string]$ui.Kick.Text; Sentence = 'Which backup does Restore use?'
    P = @('Restore first runs a dry run on the site and shows what it would put back. Nothing is written before you confirm.')
    Options = $rows; OnOption = { param($j) & $ui.RestorePlan $j }; Back = { & $ui.VTools $ui.MaintVerb } } }

$ui.RestorePlan = {
  <#
  .SYNOPSIS
  Restore, card 2: runs the dry run of the backup picked (reads the site only), then shows the confirm card.
  .PARAMETER Row
  The backup's row number on the restpick card.
  #>
  param([int]$Row)
  if ($ui.Busy -or $Row -ge @($ui.RestoreSets).Count) { return }
  $ui.RestoreDir = [string]$ui.RestoreSets[$Row].Path
  & $ui.SetCard @{ View = 'toolrun'; Kicker = [string]$ui.Kick.Text; Sentence = 'The Restore dry run is running.'; P = @('Reads the site. Nothing is written. A sign-in window may open.') }
  $ui.Busy = $true; [System.Windows.Forms.Application]::DoEvents(); $dry = $null
  try { $dry = Invoke-RestorePlan (Get-BasePath) $ui.RestoreDir { [System.Windows.Forms.Application]::DoEvents() } }
  catch { $dry = @{ State = 'failed'; Lines = @(('The dry run stopped with an error [' + $_.Exception.GetType().Name + '].'), 'Nothing was changed.') } }
  finally { $ui.Busy = $false }
  if ($ui.Form.IsDisposed -or $script:closing) { return }
  if ($dry.State -ne 'plan') { & $ui.ToolResult 'Restore' $dry; return }
  $ui.RestoreDry = $dry; & $ui.VRestoreConfirm }

$ui.VRestoreConfirm = {
  <#
  .SYNOPSIS
  Restore, card 3 (view restconfirm): the dry run's counts for each list and, when rows would come back, the box for
  the app name.
  .DESCRIPTION
  The Administrator, 2026-11-21: the user types the app name, then RADE saves a fresh backup, then writes. With nothing
  to put back the card has Done only. Reads $ui.RestoreDry (Invoke-RestorePlan); takes no parameter.
  #>
  $dry = $ui.RestoreDry; $lines = @($dry.Lines)
  if (-not $dry.Missing) { & $ui.SetCard @{ View = 'restconfirm'; Kicker = [string]$ui.Kick.Text; Sentence = 'Nothing to restore.'
      P = @($lines | Select-Object -First 1); Lines = @($lines | Select-Object -Skip 1)
      Buttons = @(@{ Text = 'Done'; Kind = 'primary'; Act = { & $ui.VTools $ui.MaintVerb } }); Back = { & $ui.VRestorePick } }; return }
  $pauseDef = $script:app.Restore.Pause
  $flow = $(if ($pauseDef) { "RADE turns the app's pause switch on while it writes, then puts it back." } else { 'This app names no pause switch: its flows keep running while rows come back.' })
  & $ui.SetCard @{ View = 'restconfirm'; Light = 'you'; Kicker = [string]$ui.Kick.Text; Sentence = ('Put back ' + $dry.Missing + ' rows on the site?')
    # One operator (the Administrator, 2026-11-21): the record of re-made rows is in this RADE folder only.
    $one = 'Only one person runs Restore for this site, from this RADE folder.'
    P = @($lines[0], ('RADE first saves a fresh backup. Rows on the lists now are not changed. ' + $flow + ' ' + $one)); Lines = @($lines | Select-Object -Skip 1)
    Field = @{ Label = ('Type ' + $script:app.Name + ' to confirm'); Text = ''; Name = 'The app name, to confirm Restore' }; Focus = 'field'
    Buttons = @(@{ Text = 'Restore'; Kind = 'primary'; Act = { & $ui.RestoreGo } }); Back = { & $ui.VRestorePick } } }

# Restore, card 4: checks the typed name, then runs the write (Invoke-Restore) and shows its result. Takes nothing.
$ui.RestoreGo = {
  if ($ui.Busy) { return }
  if ($ui.Field.Text.Trim() -cne [string]$script:app.Name) { & $ui.Say1 ('Type the app name as shown: ' + $script:app.Name); return }
  & $ui.SetCard @{ View = 'toolrun'; Kicker = [string]$ui.Kick.Text; Sentence = 'Restore is running.'; P = @('It saves a fresh backup, then puts the missing rows back. Do not close RADE.') }
  $ui.Busy = $true; [System.Windows.Forms.Application]::DoEvents(); $res = $null
  try { $res = Invoke-Restore (Get-BasePath) $ui.RestoreDir $ui.RestoreDry { [System.Windows.Forms.Application]::DoEvents() } }
  catch { $res = @{ State = 'failed'; Path = ''; Lines = @(('Restore stopped with an error [' + $_.Exception.GetType().Name + '].'), 'Run Restore again: it puts back only what is still missing.') } }
  finally { $ui.Busy = $false; $ui.RestoreDry = $null }
  if ($ui.Form.IsDisposed -or $script:closing) { return }
  & $ui.ToolResult 'Restore' $res }
