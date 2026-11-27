# RADE window part 02, the fixed parts: the band with the stage now, the light line under it, the bottom line (Details
# and Help links) and the progress bars with the timer that eases them. Builds on 01-setup.ps1.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# ---- The fixed parts: the band, the light line under it, the card, the bottom line and the bar on the bottom edge.
# The band (plan engine-v48 D5, "B + C"; the PFM, 2026-11-27): 56 px in the band color, the logo at 36 px, the word in
# capitals and "in RADE" under it; at the right the stage now (Choose, Check or Install: a disc with its number, a tick when
# the run passed, and a 3 px underline, $ui.PaintStage). Full size also shows the subtitle line and, at the right, the
# version and round; half size (a window narrower than $ui.Z.Narrow at 100 %) shows only the logo, the word, "in RADE" and
# the stage ($ui.BandFit). It replaces the logo block of engine-v43 to v47 (logo 64 px, word, line, subtitle).
$ui.Band = New-Object System.Windows.Forms.Panel
$ui.Band.Dock = 'Top'; $ui.Band.Height = $ui.Z.BandH; $ui.Band.BackColor = $ui.C.Band; $ui.Band.AccessibleName = 'Band'
# Makes one text of the band: a label in the band colors that ends with "..." when its room is short. Takes the font, the
# color and the screen-reader name; gives back the label.
$ui.BandText = { param($Font, $Color, [string]$Name) $l = New-Object System.Windows.Forms.Label; $l.AutoSize = $false; $l.AutoEllipsis = $true
  $l.UseMnemonic = $false; $l.Font = $Font; $l.ForeColor = $Color; $l.BackColor = $ui.C.Band; $l.TextAlign = 'MiddleLeft'; $l.AccessibleName = $Name; $l }
# Reads one logo from base64 PNG text. Takes the text; gives back the image, or $null (no text, or not readable).
$ui.LogoImg = { param([string]$Png) if (-not $Png) { return $null }
  try { return [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(, [System.Convert]::FromBase64String($Png)))) } catch { return $null } }   # no logo: the band shows its text only
$ui.RadeImg = & $ui.LogoImg $logoPng; $ui.AppImg = & $ui.LogoImg $ui.AppPng   # RADE's logo; the app's logo of the theme (01-setup.ps1)
$ui.Logo = New-Object System.Windows.Forms.PictureBox
$ui.Logo.Size = New-Object System.Drawing.Size($ui.Z.BandLogo, $ui.Z.BandLogo); $ui.Logo.SizeMode = 'Zoom'; $ui.Logo.BackColor = $ui.C.Band; $ui.Logo.AccessibleName = 'RADE logo'
$ui.BandWord = & $ui.BandText $ui.F.Word $ui.C.BandInk 'Name'
$ui.BandSub = & $ui.BandText $ui.F.Small $ui.C.BandMuted 'in RADE'
$ui.BandLine = & $ui.BandText $ui.F.Small $ui.C.BandMuted 'Subtitle'
$ui.BandVer = & $ui.BandText $ui.F.Small $ui.C.BandMuted 'Version and round'; $ui.BandVer.TextAlign = 'MiddleRight'
$ui.Stage = New-Object System.Windows.Forms.Panel
$ui.Stage.BackColor = $ui.C.Band; $ui.Stage.AccessibleRole = 'StaticText'; $ui.Stage.AccessibleName = 'Stage now'
$ui.StageNow = @{ N = 1; Word = 'Choose'; Done = $false }
foreach ($c in @($ui.Logo, $ui.BandWord, $ui.BandSub, $ui.BandLine, $ui.BandVer, $ui.Stage)) { [void]$ui.Band.Controls.Add($c) }
# The stage of each card: 1 Choose (what to install or do), 2 Check (the checks and Ready), 3 Install (the run and its end).
$ui.StageViews = @{ site = 2; checking = 2; fail = 2; need = 2; ready = 2; nodrive = 2; run = 3; hand = 3; handfail = 3; answer = 3; answerfail = 3; feedback = 3
  done = 3; review = 3; stopped = 3; stepfail = 3; cancelq = 3 }
$ui.StageWords = @('Choose', 'Check', 'Install')
# Sets the stage now for a card. Takes the view and whether the run passed (a tick in the disc); repaints the stage.
$ui.SetStage = { param([string]$View, [bool]$Done) $n = $(if ($ui.StageViews.ContainsKey($View)) { [int]$ui.StageViews[$View] } else { 1 })
  $ui.StageNow = @{ N = $n; Word = [string]$ui.StageWords[$n - 1]; Done = $Done }
  $ui.Stage.AccessibleName = 'Stage now: ' + $ui.StageNow.Word + ', ' + $n + ' of 3' + $(if ($Done) { ', passed' } else { '' }); & $ui.BandFit; $ui.Stage.Invalidate() }
$ui.PaintStage = {
  <#
  .SYNOPSIS
  Draws the stage now: a disc in the band's text color with the number (a tick when the run passed), the word, and a 3 px
  underline as wide as the stage (Cards v2 mock).
  .PARAMETER P
  The stage panel.
  .PARAMETER G
  Its graphics.
  .OUTPUTS
  Nothing; a failure draws nothing (the band keeps its color).
  #>
  param($P, $G)
  try { $G.Clear($ui.C.Band); $G.SmoothingMode = 'AntiAlias'; $d = & $ui.Sc $ui.Z.Disc; $h = $P.ClientSize.Height; $y = [int](($h - $d) / 2); $u = & $ui.Sc 3
    $br = New-Object System.Drawing.SolidBrush($ui.C.BandInk); $G.FillEllipse($br, 0, $y, $d, $d); $br.Dispose()
    if ($ui.StageNow.Done) { $pt = [System.Drawing.PointF[]]@(@(0.28, 0.52), @(0.44, 0.68), @(0.74, 0.34) | ForEach-Object { New-Object System.Drawing.PointF([single]($d * $_[0]), [single]($y + $d * $_[1])) })
      $pn = New-Object System.Drawing.Pen($ui.C.Band, [single](& $ui.Sc 2)); $G.DrawLines($pn, $pt); $pn.Dispose() }   # the tick: the run passed
    else { & $ui.Word $G ([string]$ui.StageNow.N) $ui.F.SmallB $ui.C.Band 0 $y $d $d 'HorizontalCenter, VerticalCenter, NoPrefix, SingleLine' }
    & $ui.Word $G ([string]$ui.StageNow.Word) $ui.F.SmallB $ui.C.BandInk ($d + (& $ui.Sc 8)) 0 ($P.ClientSize.Width - $d - (& $ui.Sc 8)) $h 'Left, VerticalCenter, NoPrefix, SingleLine'
    $ub = New-Object System.Drawing.SolidBrush($ui.C.BandInk); $G.FillRectangle($ub, 0, ($h - $u), $P.ClientSize.Width, $u); $ub.Dispose() } catch { $null = $_ } }   # a stage that cannot be drawn: the band shows the rest
$ui.Stage.Add_Paint({ & $ui.PaintStage $this $_.Graphics })
$ui.BandFit = {
  <#
  .SYNOPSIS
  Places the parts of the band for the window's width: the logo and the name column at the left, the stage at the right,
  and at full size the subtitle line after the name and the version and round before the stage.
  .DESCRIPTION
  Half size (a window narrower than $ui.Z.Narrow at 100 %, plan engine-v48 step 2) hides the subtitle line and the
  version. Each text is one line, as tall as its font, and ends with "..." when its room is short.
  .OUTPUTS
  Nothing. Does nothing before the window has its scale.
  #>
  if (-not $ui.Scaled) { return }
  try { $W = [int]$ui.Band.ClientSize.Width; $H = [int]$ui.Band.ClientSize.Height; $pad = & $ui.Sc $ui.Z.G4; $gap = & $ui.Sc $ui.Z.G3
    $ui.Narrow = ([int]$ui.Form.ClientSize.Width -lt (& $ui.Sc $ui.Z.Narrow)); $lg = & $ui.Sc $ui.Z.BandLogo
    $ui.Logo.Visible = [bool]$ui.Logo.Image; $x0 = $pad; if ($ui.Logo.Visible) { $ui.Logo.Bounds = New-Object System.Drawing.Rectangle($pad, [int](($H - $lg) / 2), $lg, $lg); $x0 = $pad + $lg + $gap }
    $sw = (& $ui.Sc ($ui.Z.Disc + $ui.Z.G2)) + [int](& $ui.Meas ([string]$ui.StageNow.Word) $ui.F.SmallB 100000).Width + (& $ui.Sc $ui.Z.G1)
    $ui.Stage.Bounds = New-Object System.Drawing.Rectangle(($W - $pad - $sw), 0, $sw, $H); $rx = $W - $pad - $sw - $gap
    $ui.BandVer.Visible = [bool](-not $ui.Narrow -and [string]$ui.BandVer.Text)
    if ($ui.BandVer.Visible) { $vw = [int](& $ui.Meas ([string]$ui.BandVer.Text) $ui.F.Small 100000).Width + (& $ui.Sc 4); $vh = & $ui.LineH $ui.F.Small; $ui.BandVer.Bounds = New-Object System.Drawing.Rectangle(($rx - $vw), [int](($H - $vh) / 2), $vw, $vh); $rx -= $vw + $gap }
    $wh = & $ui.LineH $ui.F.Word; $sh = $(if ([string]$ui.BandSub.Text) { & $ui.LineH $ui.F.Small } else { 0 }); $ui.BandSub.Visible = [bool]$sh; $top = [int](($H - $wh - $sh) / 2)
    $cw = [math]::Max((& $ui.Meas ([string]$ui.BandWord.Text) $ui.F.Word 100000).Width, (& $ui.Meas ([string]$ui.BandSub.Text) $ui.F.Small 100000).Width) + (& $ui.Sc 4); $cw = [int][math]::Max((& $ui.Sc 40), [math]::Min($cw, $rx - $x0))
    $ui.BandWord.Bounds = New-Object System.Drawing.Rectangle($x0, $top, $cw, $wh); if ($sh) { $ui.BandSub.Bounds = New-Object System.Drawing.Rectangle($x0, ($top + $wh), $cw, $sh) }
    $lx = $x0 + $cw + (& $ui.Sc $ui.Z.G4); $lh = & $ui.LineH $ui.F.Small
    $ui.BandLine.Visible = [bool](-not $ui.Narrow -and [string]$ui.BandLine.Text -and ($rx - $lx) -ge (& $ui.Sc 60))
    if ($ui.BandLine.Visible) { $ui.BandLine.Bounds = New-Object System.Drawing.Rectangle($lx, [int](($H - $lh) / 2), ($rx - $lx), $lh) } } catch { $null = $_ } }   # no measure yet: the next fit places them
$ui.Band.Add_SizeChanged({ & $ui.BandFit })
# Sets the texts and the logo of the band. Takes $true once an application is chosen (its logo, word and subtitle), else
# RADE's own (the word RADE, RADE's full name as the subtitle). An app with productName and a logo shows its own from the
# first screen (engine-v47, the PFM, 2026-11-26: "it should be the KANON logo").
$ui.SetBand = { param([bool]$App)
  $own = [bool]($App -or ([string]$appProduct -and $ui.AppImg)); $img = $(if ($own -and $ui.AppImg) { $ui.AppImg } else { $ui.RadeImg })
  if (-not [object]::ReferenceEquals($ui.Logo.Image, $img)) { $ui.Logo.Image = $img }; $ui.Logo.AccessibleName = $(if ($own -and $ui.AppImg) { (Get-AppWord) + ' logo' } else { 'RADE logo' })
  $ui.BandWord.Text = $(if ($own) { (Get-AppWord).ToUpperInvariant() } else { 'RADE' }); $ui.BandSub.Text = $(if ($own) { 'in RADE' } else { '' })
  $ui.BandLine.Text = $(if ($own) { [string](Get-AppSubtitle) } else { $ui.Tagline }); $r = $(if (Test-RunnerStart) { '' } else { [string]$round })
  $ui.BandVer.Text = (@($(if ($App -and [string]$script:app.Version) { [string]$script:app.Version }), $r) | Where-Object { $_ }) -join $dot; & $ui.BandFit }
# The light line under the band (plan engine-v48 step 2): 4 px in the line color when nothing is asked, 4 px green when a
# run passed, 8 px yellow on your turn (yellow means only that), 8 px in the error color on a failure. The card's words
# always say it too.
$ui.Light = New-Object System.Windows.Forms.Panel
$ui.Light.Dock = 'Top'; $ui.Light.Height = $ui.Z.LineIdle; $ui.Light.BackColor = $ui.C.Hair; $ui.Light.AccessibleRole = 'StaticText'; $ui.Light.AccessibleName = 'Status light: off'
# Sets the light line. Takes the card's Light: 'you', 'bad', 'pass' or none.
$ui.SetLight = { param([string]$State)
  $loud = ($State -in 'you', 'bad'); $h = $(if ($loud) { $ui.Z.LineLoud } else { $ui.Z.LineIdle }); if ($ui.Scaled) { $h = & $ui.Sc $h }; if ($ui.Light.Height -ne $h) { $ui.Light.Height = $h }
  $ui.Light.BackColor = $(if ($State -eq 'you') { $ui.C.Yellow } elseif ($State -eq 'bad') { $ui.C.Red } elseif ($State -eq 'pass') { $ui.C.Green } else { $ui.C.Hair })
  $ui.Light.AccessibleName = 'Status light: ' + $(if ($State -eq 'you') { 'your turn' } elseif ($State -eq 'bad') { 'failed' } elseif ($State -eq 'pass') { 'passed' } else { 'off' }) }
$ui.Bottom = New-Object System.Windows.Forms.TableLayoutPanel
$ui.Bottom.Dock = 'Bottom'; $ui.Bottom.Height = 46; $ui.Bottom.AutoSize = $true; $ui.Bottom.AutoSizeMode = 'GrowAndShrink'; $ui.Bottom.MinimumSize = New-Object System.Drawing.Size(0, 46); $ui.Bottom.ColumnCount = 5; $ui.Bottom.RowCount = 1; $ui.Bottom.Padding = (& $ui.Pad ($ui.Z.Inset - $ui.Z.M) 3 $ui.Z.Inset 3); $ui.Bottom.BackColor = $ui.C.White
foreach ($cs in @('AutoSize', 'AutoSize', 'AutoSize', 'Percent', 'AutoSize')) { [void]$ui.Bottom.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle($cs, 100))) }
[void]$ui.Bottom.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))   # as tall as the links with their margin and focus ring, 46 at least (R24: 1 px cut at 150 %)
$ui.RecB = & $ui.LinkBtn 'Details (F2)'; $ui.RecB.AccessibleName = 'Details: all checks, steps, files and the log (F2)'
# UI standard v1 (B6, the Administrator, 2026-11-20): one Back pattern, a "Back (Esc)" button (40 high: one height, Cards v2) at the left end of the
# card's action row (03-card.ps1 puts it there); Details (F2), Help (F1) and Feedback are the only links of the bottom line.
$ui.BackB = & $ui.Btn 'action'; $ui.BackB.Text = 'Back (Esc)'; $ui.BackB.AccessibleName = 'Back (Esc)'; $ui.BackB.Visible = $false
# Feedback (B13): the same place on every card of a test round; it opens the feedback card for the card on screen ($ui.VNote).
$ui.FeedB = & $ui.LinkBtn 'Feedback'; $ui.FeedB.AccessibleName = 'Feedback: a comment and a picture of this window for the round'; $ui.FeedB.Visible = $false
$ui.RightL = & $ui.Label $ui.F.Small $ui.C.Gray 0; $ui.RightL.Anchor = 'Right'; $ui.RightL.Visible = $true; $ui.RightL.TextAlign = 'MiddleRight'
# Its widest values (the percent of a run, the count of the checks, a result word, the time a run took: $ui.FixW): one size.
$ui.Most[$ui.RightL] = @('100 %', 'Check 999 of 999', 'Needs review', 'Stopped', '999m 59s'); $ui.RightL.Add_TextChanged({ & $ui.FixW $this })
# L6 (the Administrator, 2026-11-19): "Help (F1)" opens the RADE tour again; shown on a card that is not busy ($ui.HelpViews).
$ui.TourB = & $ui.LinkBtn 'Help (F1)'; $ui.TourB.AccessibleName = 'Help: the RADE tour (F1)'; $ui.TourB.Visible = $false
foreach ($b in @($ui.RecB, $ui.TourB, $ui.FeedB)) { $b.Anchor = 'Left' }   # R32: no top anchor, so a link sits on the middle of the line, as the text at the right does (they were 3.5 px apart at 150 %)
$ui.Bottom.Controls.Add($ui.RecB, 0, 0); $ui.Bottom.Controls.Add($ui.TourB, 1, 0); $ui.Bottom.Controls.Add($ui.FeedB, 2, 0); $ui.Bottom.Controls.Add($ui.RightL, 4, 0); & $ui.Ring $ui.Bottom
# Bars: RADE draws them (R17). A 30 ms timer eases the fill to its value; with Windows animations off it jumps. No bar
# moves back inside a run (all) or a step (step). The bar on the bottom edge is all steps; the short one is this step.
$ui.DrawBar = { param($P, $G) try { $b = $ui.Bars[[string]$P.Tag]; $G.Clear($(if ($b.On) { $ui.C.Track } else { $ui.C.White })); $fw = [int][math]::Round($P.ClientSize.Width * $b.Shown); if ($b.On -and $fw -gt 0) { $br = New-Object System.Drawing.SolidBrush($b.Fill); $G.FillRectangle($br, 0, 0, $fw, $P.ClientSize.Height); $br.Dispose() } } catch { $null = $_ } }
# Makes one thin progress bar (a panel the engine draws itself) and registers it in $ui.Bars. Takes the bar name and its
# screen-reader label; gives back the panel.
$ui.MkBar = { param([string]$Name, [string]$Label)
  $p = New-Object System.Windows.Forms.Panel; $p.Height = 4; $p.Tag = $Name; $p.AccessibleRole = 'ProgressBar'; $p.AccessibleName = $Label; $p.AccessibleDescription = '0 %'
  try { [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic, Instance').SetValue($p, $true, $null) } catch { $null = $_ }
  $ui.Bars[$Name] = @{ Panel = $p; Target = 0.0; Shown = 0.0; On = $false; Fill = $ui.C.Blue }
  $p.Add_Paint({ & $ui.DrawBar $this $_.Graphics }); $p }
# Sets what a bar shows. Takes the bar name, the fraction (0 to 1) and whether it is on; the fill eases to it, and a
# smaller value jumps back at once. Gives back nothing.
$ui.SetBar = { param([string]$Name, [double]$Value, [bool]$On)
  $b = $ui.Bars[$Name]; $v = [math]::Max(0.0, [math]::Min(1.0, $Value))
  if ($v -lt $b.Target - 0.001 -or $ui.Calm) { $b.Shown = $v }   # a new step starts at 0 with no slide back
  $b.Target = $v; $b.On = $On; $b.Panel.AccessibleDescription = [string][int]($v * 100) + ' %'; $b.Panel.Invalidate() }
$ui.Edge = & $ui.MkBar 'all' 'Progress of all steps'; $ui.Edge.Dock = 'Bottom'
$ui.Anim = New-Object System.Windows.Forms.Timer
$ui.Anim.Interval = 30
$ui.Anim.Add_Tick({ if ([bool]$ui.Busy -ne [bool]$ui.BusyShown) { $ui.BusyShown = [bool]$ui.Busy; try { $ui.Form.Invalidate($true) } catch { $null = $_ } }; foreach ($b in @($ui.Bars.Values)) { $d = $b.Target - $b.Shown; if ([math]::Abs($d) -gt 0.0005) { $b.Shown = $(if ($ui.Calm) { $b.Target } else { $b.Shown + $d * 0.18 }); $b.Panel.Invalidate() } } })

