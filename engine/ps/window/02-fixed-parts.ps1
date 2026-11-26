# RADE window part 02, the fixed parts: the status light, the logo block, the bottom line (Record and Back
# links) and the progress bars with the timer that eases them. Builds on 01-setup.ps1.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# ---- The fixed parts: the light (6 px), the logo block, the card, the bottom line and the bar on the bottom edge.
$ui.Light = New-Object System.Windows.Forms.Panel
$ui.Light.Dock = 'Top'; $ui.Light.Height = 6; $ui.Light.BackColor = $ui.C.White; $ui.Light.AccessibleRole = 'StaticText'; $ui.Light.AccessibleName = 'Status light: off'
$ui.Light.Add_Paint({ try { $pn = New-Object System.Drawing.Pen($ui.C.Navy, [single]1); $_.Graphics.DrawLine($pn, 0, ($this.ClientSize.Height - 1), $this.ClientSize.Width, ($this.ClientSize.Height - 1)); $pn.Dispose() } catch { $null = $_ } })   # a 1 px navy line: the light is a part of the screen, 3 to 1 against white also when it is off
# The logo block (the Administrator, 2026-11-18; docs/window-design.md "Fixed parts"): the RADE row (logo and the word
# RADE), and once an application is chosen, a short link line and the application row (its logo and its name in gray).
# Both logos are 64 px, the baseline size. The block is as tall as its rows (R28 N9: no fixed heights).
$ui.Top = New-Object System.Windows.Forms.FlowLayoutPanel
$ui.Top.Dock = 'Top'; $ui.Top.AutoSize = $true; $ui.Top.AutoSizeMode = 'GrowAndShrink'; $ui.Top.FlowDirection = 'TopDown'; $ui.Top.WrapContents = $false
$ui.Top.Padding = (& $ui.Pad $ui.Z.Inset $ui.Z.G3 $ui.Z.Inset 0); $ui.Top.BackColor = $ui.C.White   # UI standard v1: one side inset, 24
# Makes one row of the logo block: a left-to-right flow panel as tall as its parts. Takes nothing; gives back the panel.
$ui.LogoRow = { $r = New-Object System.Windows.Forms.FlowLayoutPanel; $r.AutoSize = $true; $r.AutoSizeMode = 'GrowAndShrink'; $r.WrapContents = $false
  $r.Margin = (& $ui.Pad 0 0 0 0); $r.Padding = (& $ui.Pad 0 0 0 0); $r.BackColor = $ui.C.White; $r }
# Makes one 64 px logo picture from base64 PNG text. Takes the text and the screen-reader name; gives back the picture,
# or $null when there is no text or System.Drawing cannot read it (the window then runs without that logo).
$ui.LogoPic = { param([string]$Png, [string]$Name)
  if (-not $Png) { return $null }
  try {
    $p = New-Object System.Windows.Forms.PictureBox
    $p.Size = New-Object System.Drawing.Size(64, 64); $p.SizeMode = 'Zoom'; $p.Margin = (& $ui.Pad 0 0 12 0); $p.AccessibleName = $Name
    $p.Image = [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(, [System.Convert]::FromBase64String($Png)))); $p
  } catch { $null } }   # no logo: the row shows its text only
$ui.TopRow = & $ui.LogoRow
$ui.Logo = & $ui.LogoPic $logoPng 'RADE logo'; if ($ui.Logo) { [void]$ui.TopRow.Controls.Add($ui.Logo) }
# One text column of the logo block (L1; name spot L2): the help is in the block.
$ui.HeadCol = {
  <#
  .SYNOPSIS
  Makes one text column of the logo block: a word, a thin line under it and a subtitle, and optionally a version text.
  .DESCRIPTION
  L1 (the PFM, 2026-11-26): a word (15 pt bold navy), under it a thin line as wide as the word's ink and the subtitle
  (small, gray), 4 px, 1 px, 4 px ink to ink (L2, 2026-11-19; $ui.FitHead). The word and the subtitle draw their own
  text ink-tight ($ui.InkText in engine/rade_ui_text.ps1). Name spot L2 (engine-v45; the PFM, 2026-11-26): a column with
  a version text has a word row: the word, which keeps room for descenders, and the version text (Small gray) on the
  word's base line ($ui.FitHead); the line then comes under the lowest ink of that row.
  .PARAMETER WordName
  The word's screen-reader name.
  .PARAMETER SubName
  The subtitle's screen-reader name.
  .PARAMETER VerName
  The version text's screen-reader name; '' (the default) for a column with no version text.
  .OUTPUTS
  @{ Col; Word; Rule; Sub; Ver }: Ver is $null without a version text.
  #>
  param([string]$WordName, [string]$SubName, [string]$VerName = '')
  $c = New-Object System.Windows.Forms.FlowLayoutPanel
  $c.AutoSize = $true; $c.AutoSizeMode = 'GrowAndShrink'; $c.FlowDirection = 'TopDown'; $c.WrapContents = $false
  $c.Margin = (& $ui.Pad 0 0 0 0); $c.Padding = (& $ui.Pad 0 0 0 0); $c.BackColor = $ui.C.White
  $w = & $ui.InkText $ui.F.Word $ui.C.Navy $WordName ([bool]$VerName); $w.Visible = $true; $v = $null; $top = $w
  if ($VerName) { $top = & $ui.Flow 0; $top.AutoSizeMode = 'GrowAndShrink'; $top.Visible = $true   # the word row: the word, then the version text
    $v = & $ui.InkText $ui.F.Small $ui.C.Gray $VerName $true; $v.Margin = (& $ui.Pad $ui.Z.G2 0 0 0); $v.Visible = $true
    [void]$top.Controls.Add($w); [void]$top.Controls.Add($v) }
  $r = New-Object System.Windows.Forms.Panel
  $r.Size = New-Object System.Drawing.Size(40, 1); $r.BackColor = $ui.C.Edge; $r.Margin = (& $ui.Pad 0 $ui.Z.G1 0 0); $r.Visible = $true
  $s = & $ui.InkText $ui.F.Small $ui.C.Gray $SubName $true; $s.Margin = (& $ui.Pad 0 $ui.Z.G1 0 0); $s.Visible = $true   # a long subtitle: cut with "..."; its widest size follows the window ($ui.Fit)
  foreach ($x in @($top, $r, $s)) { [void]$c.Controls.Add($x) }
  @{ Col = $c; Word = $w; Rule = $r; Sub = $s; Ver = $v } }
# VerBad (name spot L2, the PFM, 2026-11-26): each text of the word row ends its ink inside its own panel (no cut), each
# text after the word stands on the word's base line (1 px, scaled), and no ink of the row reaches the line under it
# (R44: the "g" of "sign-in" was cut by the line). Takes the card, the texts of the row, word first, each
# @{ N; Ink = @{ Bottom; Base; Panel } } in screen pixels ($ui.TextInk), and the line's top ($null: no line); gives back
# the defect lines.
$ui.VerBad = { param([string]$Card, [object[]]$Row, $RuleTop)
  $out = @(); $tol = [math]::Max(1, (& $ui.Sc 1)); $w = $Row[0]
  foreach ($t in $Row) { if ([int]$t.Ink.Bottom -gt [int]$t.Ink.Panel) { $out += ('LAYOUT ' + $Card + ' header ' + $t.N + ': its ink goes down to ' + $t.Ink.Bottom + ', its panel ends at ' + $t.Ink.Panel) }
    if (-not [object]::ReferenceEquals($t, $w) -and [math]::Abs([int]$t.Ink.Base - [int]$w.Ink.Base) -gt $tol) { $out += ('LAYOUT ' + $Card + ' header ' + $t.N + ': its base line is at ' + $t.Ink.Base + ', the word''s is at ' + $w.Ink.Base) } }
  $low = [int](@($Row | ForEach-Object { $_.Ink.Bottom }) | Measure-Object -Maximum).Maximum
  if ($null -ne $RuleTop -and $low -gt [int]$RuleTop) { $out += ('LAYOUT ' + $Card + ' header line: at ' + $RuleTop + ', the ink of the word row goes down to ' + $low) }
  return $out }
# Name spot L2: where the whole ink of an ink-tight text ends, as Windows draws the text with no panel around it ($ui.InkOf),
# and its base line, both on the screen; Panel is where its panel ends. Takes the panel and its screen rectangle; gives
# back @{ Bottom; Base; Panel } (Bottom is the panel's end when the text cannot be measured).
$ui.TextInk = { param($P, $R) $fi = & $ui.FontInk $P.Font; $y0 = [int]$R.Top - [int]$fi.Top; $b = $null; if ([string]$P.Text) { $b = & $ui.InkOf ([string]$P.Text) $P.Font }
  @{ Bottom = $(if ($b) { $y0 + [int]$b.Bottom } else { [int]$R.Bottom }); Base = $y0 + [int]$fi.Base; Panel = [int]$R.Bottom } }
# The RADE column: the word RADE and, under it at all times, the tagline (L1, the PFM, 2026-11-26: "RADE (new line) Test,
# deploy, enjoy"; it replaces 2026-11-19, where a chosen application's name took the tagline's place).
$hc = & $ui.HeadCol 'RADE' 'Test, deploy, enjoy'
$ui.TitleCol = $hc.Col; $ui.WordL = $hc.Word; $ui.HeadRule = $hc.Rule; $ui.TagL = $hc.Sub
$ui.WordL.Text = 'RADE'; $ui.TagL.Text = $ui.Tagline; [void]$ui.TopRow.Controls.Add($ui.TitleCol)
# The link line: 1 px gray, 12 px long, on the middle of the logos ("something minimal"); shown with the application row
# when both logos are there.
$ui.LinkLine = New-Object System.Windows.Forms.Panel
$ui.LinkLine.Size = New-Object System.Drawing.Size(1, 12); $ui.LinkLine.BackColor = $ui.C.Gray; $ui.LinkLine.Margin = (& $ui.Pad 32 4 0 4); $ui.LinkLine.Visible = $false
# The application row, once an application is chosen (L1): its logo (when it has one) and a column like the RADE column:
# the application name in the word style, and under it the manifest's application.subtitle (for example "Kanon, a bullet,
# Publications and Forms Management"); without a subtitle, the name only. Hidden on boot and on Choose ($ui.ShowAppRow).
# An application with no logo has no row of its own: its name stands under RADE in the tagline's place (the window keeps
# the height of engine-v42; the Windows job's smallest window had no room for a second row).
$ui.AppRow = & $ui.LogoRow; $ui.AppRow.Visible = $false
$ui.AppLogo = & $ui.LogoPic $appLogoPng 'Application logo'; if ($ui.AppLogo) { [void]$ui.AppRow.Controls.Add($ui.AppLogo) }
$ac = & $ui.HeadCol 'Application' 'Application subtitle' 'Application version and round'
$ui.AppCol = $ac.Col; $ui.AppWordL = $ac.Word; $ui.AppRule = $ac.Rule; $ui.AppL = $ac.Sub; $ui.AppVerL = $ac.Ver; [void]$ui.AppRow.Controls.Add($ui.AppCol)
foreach ($c in @($ui.TopRow, $ui.LinkLine, $ui.AppRow)) { [void]$ui.Top.Controls.Add($c) }
$ui.Bottom = New-Object System.Windows.Forms.TableLayoutPanel
$ui.Bottom.Dock = 'Bottom'; $ui.Bottom.Height = 46; $ui.Bottom.AutoSize = $true; $ui.Bottom.AutoSizeMode = 'GrowAndShrink'; $ui.Bottom.MinimumSize = New-Object System.Drawing.Size(0, 46); $ui.Bottom.ColumnCount = 5; $ui.Bottom.RowCount = 1; $ui.Bottom.Padding = (& $ui.Pad ($ui.Z.Inset - $ui.Z.M) 3 $ui.Z.Inset 3); $ui.Bottom.BackColor = $ui.C.White
foreach ($cs in @('AutoSize', 'AutoSize', 'AutoSize', 'Percent', 'AutoSize')) { [void]$ui.Bottom.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle($cs, 100))) }
[void]$ui.Bottom.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))   # as tall as the links with their margin and focus ring, 46 at least (R24: 1 px cut at 150 %)
$ui.RecB = & $ui.LinkBtn 'Details (F2)'; $ui.RecB.AccessibleName = 'Details: all checks, steps, files and the log (F2)'
# UI standard v1 (B6, the Administrator, 2026-11-20): one Back pattern, a compact "Back (Esc)" button at the left end of the
# card's action row (03-card.ps1 puts it there); Details (F2), Help (F1) and Feedback are the only links of the bottom line.
$ui.BackB = & $ui.Btn 'compact'; $ui.BackB.Text = 'Back (Esc)'; $ui.BackB.AccessibleName = 'Back (Esc)'; $ui.BackB.Visible = $false
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

