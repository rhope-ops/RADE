# RADE window part 11, the Maintenance tools on the Maintenance screen (the Administrator, 2026-11-20): a click on the
# Diagnose or the Back up row runs it (engine/ps/13-maintenance.ps1), with a card while it runs and a card with its result.
# Restore stays "Not available yet". Listed before 10-keys.ps1 in engine/rade_build.py (that part shows the form).
# Network: none here (part 13 names what each tool reaches).
# Writes: none here.
# Credentials: none.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# The rows of the Maintenance screen. Diagnose and Back up work (engine-v30); Restore is not built yet.
$ui.ToolRows = {
  $n = @($script:app.Backup).Count; $lists = $(if ($n -eq 1) { '1 list' } elseif ($n) { [string]$n + ' lists' } else { 'No lists named' })
  @(@{ Index = 0; Name = 'Diagnose'; Ver = ''; Sub = 'Checks the install and runs the checks again. Changes nothing.'; R1 = 'Report on this computer' },
    @{ Index = 1; Name = 'Back up'; Ver = ''; Sub = "Saves the app's lists to this computer. Changes nothing on the site."; R1 = $lists },
    @{ Off = $true; Index = 2; Name = 'Restore'; Ver = ''; Sub = 'Puts saved rows back on the site, after a dry run.'; R1 = 'Not available yet'; Soon = $true }) }

$ui.RunTool = {
  <#
  .SYNOPSIS
  Runs one Maintenance tool from its row: a card while it runs, then the result card.
  .PARAMETER J
  The row: 0 Diagnose, 1 Back up (Restore is off and cannot be clicked).
  #>
  param([int]$J)
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
  Shows the result card of a Maintenance tool: what it found or saved, and the file or folder it wrote.
  .PARAMETER Name
  The tool: Diagnose or Back up.
  .PARAMETER Res
  Its result: Invoke-Diagnose (Lines, Path, Findings) or Invoke-Backup (State, Lines, Path).
  #>
  param([string]$Name, $Res)
  $diag = ($Name -eq 'Diagnose'); $bad = $(if ($diag) { [int]$Res.Findings -gt 0 } else { [string]$Res.State -eq 'failed' })
  $sent = $(if ($diag -and $bad) { 'Diagnose found ' + $Res.Findings + ' thing(s) to fix.' } elseif ($diag) { 'Diagnose found nothing to fix.' }
    elseif ($Res.State -eq 'done') { 'Back up saved the lists.' } elseif ($Res.State -eq 'none') { 'Back up has no lists to save.' }
    elseif ($Res.State -eq 'no-site') { 'Back up saved nothing.' } else { 'Back up did not save everything.' })
  $lines = @($Res.Lines); $path = $(if ($Res.Path) { [string]$Res.Path } else { $null })
  & $ui.SetCard @{ View = 'toolres'; Light = $(if ($bad) { 'bad' } else { '' }); Kicker = [string]$ui.Kick.Text; Sentence = $sent
    P = @($lines | Select-Object -First 2); Lines = @($lines | Select-Object -Skip 2); Path = $path
    Buttons = @(@{ Text = 'Done'; Kind = 'primary'; Act = { & $ui.VTools $ui.MaintVerb } }); Back = { & $ui.VTools $ui.MaintVerb } }
  & $ui.ToFront }
