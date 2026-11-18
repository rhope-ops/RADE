# RADE window part 06, the opening views: boot, Choose (pick an application), the site address card, and the
# check cards (needs you, failed). Uses the card of 03-card.ps1 and the engine checks.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

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
# Shows the Choose card: one option for each application, off when one of its checks failed. Takes nothing; selects the
# first application and sets the card.
$ui.VChoose = {
  if (@($apps).Count -eq 0) { & $ui.VNoApps; return }
  Select-App 0; $ui.Picked = $false; $ui.Plan = $null; $ui.StartAfter = $false; $ui.AppL.Text = ''; & $ui.ShowAppRow $false; $list = @(); $dep = $false; $ui.Blocked = @{}; $ui.BlockedFix = @{}
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
# Shows "Checking this computer", runs the base checks and then shows Choose; shows the error card when they stop. Takes
# nothing.
$ui.Boot = {
  & $ui.SetCard @{ View = 'boot'; Sentence = 'Checking this computer.'; P = @('This takes a few seconds. Nothing is changed.') }
  try { & $ui.RunBase } catch { if (-not ($ui.Form.IsDisposed -or $script:closing)) { & $ui.VBootErr (ConvertTo-Masked ([string]$_.Exception.Message)) }; return }
  if (-not ($ui.Form.IsDisposed -or $script:closing)) { & $ui.VChoose } }
# Resets what the user chose: each step to its default, clean-up on, no step states. Takes nothing.
$ui.InitSel = { $ui.Sel = @{}; foreach ($k in $script:appSteps) { $ui.Sel[[int]$k] = [bool](Get-StepDefault $k) }; $ui.Clean = $true; $ui.StepState = @{} }
# Shows or hides the application row of the logo block (its logo, its name) and the link line above it (only when both
# logos are there). Takes whether to show it.
$ui.ShowAppRow = { param([bool]$On)
  $ui.AppRow.Visible = $On; $ui.LinkLine.Visible = ($On -and $ui.Logo -and $ui.AppLogo)
  if ($ui.AppLogo) { $ui.AppLogo.AccessibleName = $(if ($On) { $script:app.Name + ' logo' } else { 'Application logo' }) } }
# Takes the application the user chose: selects it, reuses base check results that can be reused, and shows Maintenance
# (already installed) or the checks. Takes the application number.
$ui.Pick = { param([int]$J)
  Select-App $J; $ui.Picked = $true
  # The base checks are not run twice, except the ones whose answer can change at any time ($checkNoSave: Word open, disk, write).
  foreach ($id in $script:appChecks) { if ($ui.BaseRes.ContainsKey($id) -and $checkNoSave -notcontains $id -and $ui.BaseRes[$id].State -in 'PASSED', 'WARNING') { $script:checkResults[$id] = $ui.BaseRes[$id] } }
  $ui.AppL.Text = $script:app.Name + $(if ($script:app.Version) { ' ' + $script:app.Version } else { '' }); & $ui.ShowAppRow $true
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
  # Start (R28 fix: the PFM found no Start button): the installed application with a start script can be started from here too.
  # It runs the checks first (Start comes only after they pass: AGENTS.md "RADE and the app"), then starts the application.
  $ui.StartAfter = $false; $startB = $null; $startMain = $false
  if ([string]$script:app.Start -and (Get-StartPath)) { $startMain = ([string]$Inst.version -eq [string]$script:app.Version); $startB = @{ Text = 'Start ' + $script:app.Name; Kind = $(if ($startMain) { 'primary' } else { '' }); Act = { $ui.StartAfter = $true; & $ui.Checks $false } } }
  & $ui.SetCard @{ View = 'maint'; Kicker = ($script:app.Name + ' ' + $Inst.version + $on); Sentence = 'Maintenance'
    P = @($(if ($verb -eq 'Repair') { 'Repair adds what is missing and keeps your data.' } else { $verb + ' adds what is missing and keeps your data.' }), $(if ($startB) { 'Start runs the checks, then opens ' + $script:app.Name + '.' } else { '' }))
    Note = 'Diagnose, Back up, Restore and Uninstall are not in this version of RADE yet.'
    Buttons = @($startB, @{ Text = $verb; Kind = $(if ($startMain) { '' } else { 'primary' }); Act = { & $ui.Checks $false } }, @{ Text = 'Diagnose'; Kind = 'off' }, @{ Text = 'Back up'; Kind = 'off' }, @{ Text = 'Restore'; Kind = 'off' }, @{ Text = 'Uninstall'; Kind = 'dangeroff'; Apart = $true })
    Back = { & $ui.VChoose } } }
# Says whether the chosen application has a check that needs the site address. Takes nothing; gives back $true or
# $false.
$ui.NeedSite = { [bool](@($script:appChecks | Where-Object { $_ -in 'net-site', 'site-rights' }).Count) }
# Shows the card that asks for the site address (filled with the saved one, or the DAF SharePoint start).
$ui.VSite = {
  $v = Get-SiteUrl (Get-BasePath); if (-not $v) { $v = $sitePrefix }   # PFM 14 Nov 26: the box starts with the DAF SharePoint address
  & $ui.SetCard @{ View = 'site'; Sentence = 'Which site does the application go to?'; P = @('RADE writes to this SharePoint site. The address is saved for next time.')
    Field = @{ Label = 'Site address'; Text = $v; Name = 'Site address, starts with https://' }; Focus = 'field'
    Buttons = @(@{ Text = 'Continue'; Kind = 'primary'; Act = { & $ui.SaveSite } }); Back = { & $ui.VChoose } }
  try { $ui.Field.SelectionStart = $ui.Field.Text.Length; $ui.Field.SelectionLength = 0 } catch { $null = $_ } }
# Saves the address in the box when it is a valid site address, drops the site checks' old results and runs the checks
# again; else says what is wrong. Takes nothing.
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
# Shows the card of a failed check with what to do and a button to run it again. Takes the check number and the count of
# failed checks.
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
# Shows the card of a check that needs the user (a sign-in, a look-and-answer, or not run yet). Takes the check number.
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
    Field = $(if ($dep -and -not (Test-ShortcutMade)) { @{ Label = 'RADE shortcut in'; Text = (Get-ShortcutDir); Name = 'Folder for the RADE shortcut'; Button = 'Browse'; Act = { & $ui.BrowseDir } } } else { $null })
    Back = { & $ui.VChoose } }
  if ($ui.StartAfter) { $ui.StartAfter = $false; if ($startB) { & $ui.StartApp } else { & $ui.Say1 ('The checks passed, but ' + $script:app.Name + ' cannot be started: it is not recorded as installed, or its start file was not found. Select "Install" to install it again.') } } }   # Start on Maintenance: the checks passed, so the application starts
# R29 N8 (the PFM, 17 Nov 26): the install asks where the RADE shortcut goes; the box starts with the Desktop folder.
$ui.BrowseDir = {
  $pick = New-Object System.Windows.Forms.FolderBrowserDialog
  try { $pick.Description = 'Choose the folder for the RADE shortcut.'; $pick.ShowNewFolderButton = $true; $v = $ui.Field.Text.Trim(); if ($v -and (Test-Path -LiteralPath $v -PathType Container)) { $pick.SelectedPath = $v }
    if ([string]$pick.ShowDialog($ui.Form) -eq 'OK') { $ui.Field.Text = [string]$pick.SelectedPath } } catch { & $ui.Say1 'The folder window could not open. Type the folder in the box.' } finally { $pick.Dispose() } }

