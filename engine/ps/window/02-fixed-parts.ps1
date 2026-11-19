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
$ui.Top.Padding = (& $ui.Pad 32 12 32 0); $ui.Top.BackColor = $ui.C.White
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
# The title column beside the RADE logo: the word RADE, and under it, when the application has no logo of its own, a thin
# line and the application name (L2, the Administrator, 2026-11-19: 4 px, a 1 px line as wide as the word, 4 px, ink to
# ink; $ui.FitHead). The word and the name draw their own text ink-tight ($ui.InkText in engine/rade_ui.ps1).
$ui.TitleCol = New-Object System.Windows.Forms.FlowLayoutPanel
$ui.TitleCol.AutoSize = $true; $ui.TitleCol.AutoSizeMode = 'GrowAndShrink'; $ui.TitleCol.FlowDirection = 'TopDown'; $ui.TitleCol.WrapContents = $false
$ui.TitleCol.Margin = (& $ui.Pad 0 0 0 0); $ui.TitleCol.Padding = (& $ui.Pad 0 0 0 0); $ui.TitleCol.BackColor = $ui.C.White
$ui.WordL = & $ui.InkText $ui.F.Word $ui.C.Navy 'RADE' $false; $ui.WordL.Text = 'RADE'; $ui.WordL.Visible = $true
$ui.HeadRule = New-Object System.Windows.Forms.Panel
$ui.HeadRule.Size = New-Object System.Drawing.Size(40, 1); $ui.HeadRule.BackColor = $ui.C.Edge; $ui.HeadRule.Margin = (& $ui.Pad 0 $ui.Z.G1 0 0); $ui.HeadRule.Visible = $false
[void]$ui.TitleCol.Controls.Add($ui.WordL); [void]$ui.TitleCol.Controls.Add($ui.HeadRule); [void]$ui.TopRow.Controls.Add($ui.TitleCol)
# The link line: 1 px gray, 12 px long, on the middle of the logos ("something minimal"); shown with the application row
# when both logos are there.
$ui.LinkLine = New-Object System.Windows.Forms.Panel
$ui.LinkLine.Size = New-Object System.Drawing.Size(1, 12); $ui.LinkLine.BackColor = $ui.C.Gray; $ui.LinkLine.Margin = (& $ui.Pad 32 4 0 4); $ui.LinkLine.Visible = $false
$ui.AppRow = & $ui.LogoRow; $ui.AppRow.Visible = $false
$ui.AppLogo = & $ui.LogoPic $appLogoPng 'Application logo'; if ($ui.AppLogo) { [void]$ui.AppRow.Controls.Add($ui.AppLogo) }
# The application name and version, gray, no mark before it. With an application logo it is beside that logo, in the
# application row; without one it is the subtitle under the word RADE, in the title column ($ui.AppUnder; shown by $ui.ShowAppRow).
$ui.AppUnder = -not $ui.AppLogo
$ui.AppL = & $ui.InkText $ui.F.Small $ui.C.Gray 'Application' $true; $ui.AppL.Margin = (& $ui.Pad 0 $(if ($ui.AppUnder) { $ui.Z.G1 } else { 0 }) 0 0)   # a long name and version: cut with "..."; its widest size follows the window ($ui.Fit)
if ($ui.AppUnder) { [void]$ui.TitleCol.Controls.Add($ui.AppL) } else { [void]$ui.AppRow.Controls.Add($ui.AppL) }
# Boot looks like a chosen application (the Administrator, 2026-11-19): from the first frame the tagline stands where the
# name will stand, in the same style, and the logo block has its full height; a chosen application's name replaces it.
$ui.AppL.Text = $ui.Tagline; & $ui.InkFit $ui.AppL; $ui.AppL.Visible = $true; if ($ui.AppUnder) { $ui.HeadRule.Visible = $true } else { $ui.AppRow.Visible = $true; $ui.LinkLine.Visible = [bool]$ui.Logo }
foreach ($c in @($ui.TopRow, $ui.LinkLine, $ui.AppRow)) { [void]$ui.Top.Controls.Add($c) }
$ui.Bottom = New-Object System.Windows.Forms.TableLayoutPanel
$ui.Bottom.Dock = 'Bottom'; $ui.Bottom.Height = 46; $ui.Bottom.AutoSize = $true; $ui.Bottom.AutoSizeMode = 'GrowAndShrink'; $ui.Bottom.MinimumSize = New-Object System.Drawing.Size(0, 46); $ui.Bottom.ColumnCount = 5; $ui.Bottom.RowCount = 1; $ui.Bottom.Padding = (& $ui.Pad 28 3 32 3); $ui.Bottom.BackColor = $ui.C.White
foreach ($cs in @('AutoSize', 'AutoSize', 'AutoSize', 'Percent', 'AutoSize')) { [void]$ui.Bottom.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle($cs, 100))) }
[void]$ui.Bottom.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))   # as tall as the links with their margin and focus ring, 46 at least (R24: 1 px cut at 150 %)
$ui.RecB = & $ui.LinkBtn 'Record (F2)'; $ui.RecB.AccessibleName = 'Record: all checks, steps, files and the log (F2)'
$ui.BackB = & $ui.LinkBtn 'Back'; $ui.BackB.AccessibleName = 'Back (Esc)'; $ui.BackB.Visible = $false
$ui.RightL = & $ui.Label $ui.F.Small $ui.C.Gray 0; $ui.RightL.Anchor = 'Right'; $ui.RightL.Visible = $true
# L6 (the Administrator, 2026-11-19): "Help (F1)" opens the RADE tour again; shown on a card that is not busy ($ui.HelpViews).
$ui.TourB = & $ui.LinkBtn 'Help (F1)'; $ui.TourB.AccessibleName = 'Help: the RADE tour (F1)'; $ui.TourB.Visible = $false
foreach ($b in @($ui.RecB, $ui.TourB, $ui.BackB)) { $b.Anchor = 'Left' }   # R32: no top anchor, so a link sits on the middle of the line, as the text at the right does (they were 3.5 px apart at 150 %)
$ui.Bottom.Controls.Add($ui.RecB, 0, 0); $ui.Bottom.Controls.Add($ui.TourB, 1, 0); $ui.Bottom.Controls.Add($ui.BackB, 2, 0); $ui.Bottom.Controls.Add($ui.RightL, 4, 0); & $ui.Ring $ui.Bottom
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

