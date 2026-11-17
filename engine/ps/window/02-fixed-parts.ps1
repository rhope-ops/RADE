# RADE window part 02, the fixed parts: the status light, the logo line, the bottom line (Record and Back
# links) and the progress bars with the timer that eases them. Builds on 01-setup.ps1.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# ---- The fixed parts: the light (6 px), the logo line, the card, the bottom line and the bar on the bottom edge.
$ui.Light = New-Object System.Windows.Forms.Panel
$ui.Light.Dock = 'Top'; $ui.Light.Height = 6; $ui.Light.BackColor = $ui.C.White; $ui.Light.AccessibleRole = 'StaticText'; $ui.Light.AccessibleName = 'Status light: off'
$ui.Light.Add_Paint({ try { $pn = New-Object System.Drawing.Pen($ui.C.Navy, [single]1); $_.Graphics.DrawLine($pn, 0, ($this.ClientSize.Height - 1), $this.ClientSize.Width, ($this.ClientSize.Height - 1)); $pn.Dispose() } catch { $null = $_ } })   # a 1 px navy line: the light is a part of the screen, 3 to 1 against white also when it is off
$ui.Top = New-Object System.Windows.Forms.FlowLayoutPanel
$ui.Top.Dock = 'Top'; $ui.Top.AutoSize = $true; $ui.Top.AutoSizeMode = 'GrowAndShrink'; $ui.Top.MinimumSize = New-Object System.Drawing.Size(0, 64); $ui.Top.WrapContents = $false;   # 64 at least; taller when its text needs it (R28 N9: no fixed heights)
$ui.Top.Padding = (& $ui.Pad 32 12 32 0); $ui.Top.BackColor = $ui.C.White
try {
  $ui.Logo = New-Object System.Windows.Forms.PictureBox
  $ui.Logo.Size = New-Object System.Drawing.Size(40, 40); $ui.Logo.SizeMode = 'Zoom'; $ui.Logo.Margin = (& $ui.Pad 0 0 12 0); $ui.Logo.AccessibleName = 'RADE logo'
  $ui.Logo.Image = [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(, [System.Convert]::FromBase64String($logoPng))))
  [void]$ui.Top.Controls.Add($ui.Logo)
} catch { $null = $_ }   # the window runs without the logo
$ui.WordL = & $ui.Label $ui.F.Word $ui.C.Navy 5; $ui.WordL.Text = 'RADE'; $ui.WordL.Visible = $true
$ui.AppL = & $ui.Label $ui.F.Small $ui.C.Gray 14; $ui.AppL.Margin = (& $ui.Pad 10 14 0 0); $ui.AppL.Visible = $true
$ui.AppL.AutoSize = $false; $ui.AppL.AutoEllipsis = $true; $ui.AppL.Size = New-Object System.Drawing.Size(600, 22)   # a long name and version: cut with "..."; its width follows the window ($ui.Fit)
[void]$ui.Top.Controls.Add($ui.WordL); [void]$ui.Top.Controls.Add($ui.AppL)
$ui.Bottom = New-Object System.Windows.Forms.TableLayoutPanel
$ui.Bottom.Dock = 'Bottom'; $ui.Bottom.Height = 46; $ui.Bottom.AutoSize = $true; $ui.Bottom.AutoSizeMode = 'GrowAndShrink'; $ui.Bottom.MinimumSize = New-Object System.Drawing.Size(0, 46); $ui.Bottom.ColumnCount = 4; $ui.Bottom.RowCount = 1; $ui.Bottom.Padding = (& $ui.Pad 28 3 32 3); $ui.Bottom.BackColor = $ui.C.White
foreach ($cs in @('AutoSize', 'AutoSize', 'Percent', 'AutoSize')) { [void]$ui.Bottom.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle($cs, 100))) }
[void]$ui.Bottom.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize')))   # as tall as the links with their margin and focus ring, 46 at least (R24: 1 px cut at 150 %)
$ui.RecB = & $ui.LinkBtn 'Record (F2)'; $ui.RecB.AccessibleName = 'Record: all checks, steps, files and the log (F2)'
$ui.BackB = & $ui.LinkBtn 'Back'; $ui.BackB.AccessibleName = 'Back (Esc)'; $ui.BackB.Visible = $false
$ui.RightL = & $ui.Label $ui.F.Small $ui.C.Gray 0; $ui.RightL.Anchor = 'Right'; $ui.RightL.Visible = $true
$ui.Bottom.Controls.Add($ui.RecB, 0, 0); $ui.Bottom.Controls.Add($ui.BackB, 1, 0); $ui.Bottom.Controls.Add($ui.RightL, 3, 0); & $ui.Ring $ui.Bottom
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

