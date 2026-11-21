# RADE window part 11, the Maintenance tools on the Maintenance screen (the Administrator, 2026-11-20): a click on the
# Diagnose or the Back up row runs it (engine/ps/13-maintenance.ps1), with a card while it runs and a card with its result.
# Restore (engine-v31, the Administrator, 2026-11-21): pick a backup, the dry-run card with its counts, the typed app
# name, then the write and its result card. The local test-site mark (engine-v32, the Administrator, 2026-11-21): for an
# app with "testSites": "local", a card where the person types the site name marks the saved site as a test site.
# Listed before 10-keys.ps1 in engine/rade_build.py (that part shows the form).
# Network: none here (parts 13 and 14 name what each tool reaches).
# Writes: the mark file, from the mark card (Save-RestoreMark, engine/ps/14-restore.ps1).
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

$ui.VRestorePick = {
  <#
  .SYNOPSIS
  Restore, card 1 (view restpick): the backups on this computer, newest first, one row each.
  .DESCRIPTION
  A site that only lacks the local test-site mark (engine-v32) goes to the mark card ($ui.VRestoreMark); a site that is
  not a test site, or no backup, goes straight to the result card. Keeps the site name for the "Test site:" line of the
  dry-run and confirm cards ($ui.RestoreSite). Takes no parameter.
  #>
  $appPath = Get-BasePath; $siteCheck = Test-RestoreSite $appPath
  if ($siteCheck.NeedMark) { & $ui.VRestoreMark; return }
  if (-not $siteCheck.Ok) { & $ui.ToolResult 'Restore' @{ State = 'refused'; Path = ''; Lines = $siteCheck.Lines }; return }
  $ui.RestoreSite = [string]$siteCheck.Name
  $ui.RestoreSets = @(Get-BackupSet $appPath)
  if (-not $ui.RestoreSets.Count) { & $ui.ToolResult 'Restore' @{ State = 'none'; Path = ''; Lines = @('There is no backup of this app on this computer.', 'Select "Back up" first.') }; return }
  $rows = @(for ($k = 0; $k -lt $ui.RestoreSets.Count; $k++) { $set = $ui.RestoreSets[$k]
      @{ Index = $k; Name = $set.Name; Ver = ''; Sub = ([string]$set.Lists + ' of ' + @($script:app.Backup).Count + ' lists'); R1 = $(if ($k -eq 0) { 'Newest' } else { '' }) } })
  & $ui.SetCard @{ View = 'restpick'; Kicker = [string]$ui.Kick.Text; Sentence = 'Which backup does Restore use?'
    P = @('Restore first runs a dry run on the site and shows what it would put back. Nothing is written before you confirm.')
    Options = $rows; OnOption = { param($j) & $ui.RestorePlan $j }; Back = { & $ui.VTools $ui.MaintVerb } } }

$ui.VRestoreMark = {
  <#
  .SYNOPSIS
  Restore, the mark card (view restmark): the person types the saved site's name to mark it as a test site on this
  computer.
  .DESCRIPTION
  The Administrator, 2026-11-21: for an app whose manifest gives "testSites": "local" (its public repo names no site).
  The card does not show the name: the person types it, so the mark says they know which site this is. The mark is
  stored only on this computer, next to the site address (Config). Takes no parameter.
  #>
  $where = "The mark stays on this computer only, in the app's Config folder. Restore refuses every site without it."
  & $ui.SetCard @{ View = 'restmark'; Light = 'you'; Kicker = [string]$ui.Kick.Text; Sentence = 'Is the saved site a test site?'
    P = @('Restore writes only to a test site. To mark the saved site as one, type its name: the part of its address after the last /.', $where)
    Field = @{ Label = 'Site name'; Text = ''; Name = 'The site name, to mark the saved site as a test site'; Max = 200 }; Focus = 'field'
    Buttons = @(@{ Text = 'Mark as test site'; Kind = 'primary'; Act = { & $ui.RestoreMarkGo } }); Back = { & $ui.VTools $ui.MaintVerb } } }

# Restore, the mark card's button: checks the typed name against the saved site (without case; a pasted full address
# counts too), saves the mark, then shows card 1. Takes nothing.
$ui.RestoreMarkGo = {
  if ($ui.Busy) { return }
  $appPath = Get-BasePath; $siteCheck = Test-RestoreSite $appPath; $typed = $ui.Field.Text.Trim().TrimEnd('/')
  if ($typed.StartsWith($sitePrefix, [System.StringComparison]::OrdinalIgnoreCase)) { $typed = $typed.Substring($sitePrefix.Length) }
  if (-not $siteCheck.Name -or $typed -ne $siteCheck.Name) { & $ui.Say1 'That is not the name of the saved site. Type the part of its address after the last /.'; return }
  try { Save-RestoreMark $appPath $siteCheck.Name }
  catch { & $ui.Say1 ('The mark could not be saved [' + $_.Exception.GetType().Name + ']. Nothing was changed.'); return }
  & $ui.VRestorePick }

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
  $siteLine = 'Test site: ' + $ui.RestoreSite
  & $ui.SetCard @{ View = 'toolrun'; Kicker = [string]$ui.Kick.Text; Sentence = 'The Restore dry run is running.'; P = @($siteLine, 'Reads the site. Nothing is written. A sign-in window may open.') }
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
  $dry = $ui.RestoreDry; $lines = @($dry.Lines); $siteLine = 'Test site: ' + $ui.RestoreSite
  if (-not $dry.Missing) { & $ui.SetCard @{ View = 'restconfirm'; Kicker = [string]$ui.Kick.Text; Sentence = 'Nothing to restore.'
      P = @($siteLine, $lines[0]); Lines = @($lines | Select-Object -Skip 1)
      Buttons = @(@{ Text = 'Done'; Kind = 'primary'; Act = { & $ui.VTools $ui.MaintVerb } }); Back = { & $ui.VRestorePick } }; return }
  $pauseDef = $script:app.Restore.Pause
  $flow = $(if ($pauseDef) { "RADE turns the app's pause switch on while it writes, then puts it back." } else { 'This app names no pause switch: its flows keep running while rows come back.' })
  # One operator (the Administrator, 2026-11-21): the record of re-made rows is in this RADE folder only.
  $oneOperator = 'Only one person runs Restore for this site, from this RADE folder.'
  & $ui.SetCard @{ View = 'restconfirm'; Light = 'you'; Kicker = [string]$ui.Kick.Text; Sentence = ('Put back ' + $dry.Missing + ' rows on the site?')
    P = @($siteLine, $lines[0], ('RADE first saves a fresh backup. Rows on the lists now are not changed. ' + $flow + ' ' + $oneOperator)); Lines = @($lines | Select-Object -Skip 1)
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
