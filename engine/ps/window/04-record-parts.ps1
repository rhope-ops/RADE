# RADE window part 04, the hand-step text and the Record's first parts: builds the rich text of the numbered
# lines of a hand step and fits its box. Builds on 03-card.ps1 (the Guide box).
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# ---- The Record (F2): all checks by group with their result, the steps with a box each (they can be changed only
# before the run), and one text box with the files (New, Replace, Recycle), what the installs made, and the log.
$ui.Rec = New-Object System.Windows.Forms.TableLayoutPanel
$ui.Rec.Dock = 'Fill'; $ui.Rec.ColumnCount = 3; $ui.Rec.RowCount = 2; $ui.Rec.Padding = (& $ui.Pad ($ui.Z.Inset + $ui.Z.M) 0 ($ui.Z.Inset + $ui.Z.M) $ui.Z.G2); $ui.Rec.BackColor = $ui.C.White; $ui.Rec.Visible = $false
foreach ($w in @(36, 30, 34)) { [void]$ui.Rec.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', $w))) }
[void]$ui.Rec.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))); [void]$ui.Rec.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100)))
$ui.RecHead = New-Object System.Windows.Forms.FlowLayoutPanel
$ui.RecHead.AutoSize = $true; $ui.RecHead.WrapContents = $false; $ui.RecHead.BackColor = $ui.C.White; $ui.RecHead.Margin = (& $ui.Pad 0 0 0 4); & $ui.Ring $ui.RecHead
$ui.RecClose = & $ui.Btn 'compact'; $ui.RecClose.Text = 'Back (Esc)'; $ui.RecClose.AccessibleName = 'Close Details (Esc)'
$ui.RecTitle = & $ui.Label $ui.F.Body $ui.C.Navy 9; $ui.RecTitle.Margin = (& $ui.Pad 10 9 0 0); $ui.RecTitle.Text = 'Details'; $ui.RecTitle.Visible = $true
# R33 (the PFM, 19 Nov 26): the check list and the step list are drawn, so they cannot be selected; Copy all puts the whole
# Record (the checks with each detail, the steps, the files and the log) on the clipboard as plain text ($ui.RecAll).
$ui.RecCopy = & $ui.Btn 'compact'; $ui.RecCopy.Text = 'Copy all'; $ui.RecCopy.AccessibleName = 'Copy all of Details as text'
[void]$ui.RecHead.Controls.Add($ui.RecClose); [void]$ui.RecHead.Controls.Add($ui.RecCopy); [void]$ui.RecHead.Controls.Add($ui.RecTitle)
$ui.RecChecks = New-Object System.Windows.Forms.Panel
$ui.RecChecks.Dock = 'Top'; $ui.RecChecks.BackColor = $ui.C.White; $ui.RecChecks.AccessibleRole = 'StaticText'; $ui.RecChecks.AccessibleName = 'Checks'
try { [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic, Instance').SetValue($ui.RecChecks, $true, $null) } catch { $null = $_ }
$ui.RecSteps = New-Object System.Windows.Forms.FlowLayoutPanel
$ui.RecSteps.Dock = 'Fill'; $ui.RecSteps.FlowDirection = 'TopDown'; $ui.RecSteps.WrapContents = $false; $ui.RecSteps.AutoScroll = $true; $ui.RecSteps.BackColor = $ui.C.White; $ui.RecSteps.Margin = (& $ui.Pad 0 0 16 0); $ui.RecSteps.AccessibleName = 'Steps'
$ui.RecText = New-Object System.Windows.Forms.TextBox
$ui.RecText.Dock = 'Fill'; $ui.RecText.Multiline = $true; $ui.RecText.ReadOnly = $true; $ui.RecText.ScrollBars = 'Vertical'; $ui.RecText.WordWrap = $true; $ui.RecText.Font = $ui.F.Mono; $ui.RecText.BackColor = $ui.C.White; $ui.RecText.ForeColor = $ui.C.Ink; $ui.RecText.BorderStyle = 'FixedSingle'; $ui.RecText.Margin = (& $ui.Pad 4 4 4 4); $ui.RecText.AccessibleName = 'Files, made list and log'
$ui.Rec.Controls.Add($ui.RecHead, 0, 0); $ui.Rec.SetColumnSpan($ui.RecHead, 3)
# The painted list sits in a panel that scrolls only when the list is taller than the window (many reused checks at 150 %).
$ui.RecScroll = New-Object System.Windows.Forms.Panel
$ui.RecScroll.Dock = 'Fill'; $ui.RecScroll.AutoScroll = $true; $ui.RecScroll.BackColor = $ui.C.White; $ui.RecScroll.Margin = (& $ui.Pad 4 0 24 0)
$ui.RecScroll.Controls.Add($ui.RecChecks)
$ui.Rec.Controls.Add($ui.RecScroll, 0, 1); $ui.Rec.Controls.Add($ui.RecSteps, 1, 1); $ui.Rec.Controls.Add($ui.RecText, 2, 1)
# The Fill parts go in first: they dock last, inside the light, the logo line, the bottom line and the edge bar.
foreach ($c in @($ui.Card, $ui.Rec, $ui.Bottom, $ui.Edge, $ui.Top, $ui.Light)) { $ui.Form.Controls.Add($c) }
$ui.Form.ResumeLayout($false); $ui.Form.PerformLayout()

# The lines of a hand step (the Administrator, 2026-11-17; R28 N4): a guide line that starts with "<digits>. " is numbered:
# its number right-aligned in the left column, its text wrapped in the right column; any other line follows the list,
# small and gray. All of it is ONE rich text box ($ui.Guide), so a person can select across lines. The plain parts stay in
# $ui.GuideNums, $ui.GuideTexts and $ui.GuideRest (the tests read them). RTF: figure spaces right-align the numbers, a tab
# and a hanging indent start the text column; sizes in twips from the pixels the box draws at.
$ui.SetSteps = { param($Guide)
  $ui.GuideNums = @(); $ui.GuideTexts = @(); $ui.GuideRest = @()
  foreach ($g in @($Guide)) { $g = [string]$g
    if ($g -match '^(\d+)\.\s+(\S.*)$') { $ui.GuideNums += ($Matches[1] + '.'); $ui.GuideTexts += $Matches[2] } elseif ($g.Trim()) { $ui.GuideRest += $g.Trim() } }
  $on = [bool](@($ui.GuideNums).Count -or @($ui.GuideRest).Count); $ui.Guide.Visible = $on
  if (-not $on) { try { $ui.Guide.Clear() } catch { $null = $_ }; return }
  & $ui.GuideBuild; & $ui.FitSteps }
# Escapes text for rich text (RTF): backslash and braces, and characters above 126 as \u codes. Takes the text; gives
# back the escaped text.
$ui.RtfEsc = { param([string]$T) $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $T.ToCharArray()) { $n = [int]$ch; if ($ch -eq [char]92 -or $ch -eq '{' -or $ch -eq '}') { [void]$sb.Append([char]92).Append($ch) } elseif ($n -gt 126) { [void]$sb.Append('\u' + $(if ($n -gt 32767) { $n - 65536 } else { $n }) + '?') } elseif ($n -lt 32) { [void]$sb.Append(' ') } else { [void]$sb.Append($ch) } }
  return $sb.ToString() }
# Builds the rich text of the hand-step box from $ui.GuideNums, $ui.GuideTexts and $ui.GuideRest (numbers right-aligned
# in a column, then the small gray lines) and sets it into the box. Takes nothing; sets $ui.Guide.Rtf, $ui.GuideInkAt
# and the box's screen-reader text.
$ui.GuideBuild = {
  $g = $null; try { $g = $ui.Guide.CreateGraphics() } catch { $null = $_ }
  $dpi = 96.0; try { if ($g -and [double]$g.DpiX -gt 0) { $dpi = [double]$g.DpiX } } catch { $null = $_ }
  # Turns screen pixels into twips (1/1440 inch) at the box's dpi. Takes the pixels; gives back a whole number.
  $tw = { param([double]$Px) [int][math]::Round($Px * 1440.0 / $dpi) }
  $nw = 0; foreach ($n in @($ui.GuideNums)) { $w = 0; try { $w = [int][System.Windows.Forms.TextRenderer]::MeasureText($g, $n, $ui.F.Body, (New-Object System.Drawing.Size(100000, 0)), [System.Windows.Forms.TextFormatFlags]'NoPadding, SingleLine').Width } catch { $w = [int][System.Windows.Forms.TextRenderer]::MeasureText($n, $ui.F.Body).Width }; $nw = [math]::Max($nw, $w) }
  try { if ($g) { $g.Dispose() } } catch { $null = $_ }
  $cT = & $tw ($nw + (& $ui.Sc 8)); $g1 = & $tw (& $ui.Sc $ui.Z.G1); $g3 = & $tw (& $ui.Sc $ui.Z.G3)
  # Writes a color as the RTF color text (red, green, blue). Takes the color; gives back the text.
  $col = { param($C) '\red' + $C.R + '\green' + $C.G + '\blue' + $C.B + ';' }
  $fb = [int][math]::Round([double]$ui.F.Body.SizeInPoints * 2); $fs = [int][math]::Round([double]$ui.F.Small.SizeInPoints * 2)
  $paras = @(); $plain = 0; $wide = ''; $ui.GuideInkAt = 0
  # A shorter number gets figure spaces (as wide as a digit) in front: the numbers end on one line, and every line starts at
  # the left indent, so the first letter's place never depends on a tab (R28 job: a right tab was laid out late).
  $ml = 0; foreach ($n in @($ui.GuideNums)) { $ml = [math]::Max($ml, ([string]$n).Length) }
  for ($i = 0; $i -lt @($ui.GuideNums).Count; $i++) {
    $n = [string]$ui.GuideNums[$i]; $t = [string]$ui.GuideTexts[$i]; $pad = ([string][char]0x2007) * ($ml - $n.Length)
    if ($n.Length -eq $ml -and -not $wide) { $wide = $n; $ui.GuideInkAt = $plain }   # a widest number: its first letter is on the card edge
    $paras += ('\pard\li' + $cT + '\fi-' + $cT + '\tx' + $cT + '\sb' + $(if ($i) { $g1 } else { 0 }) + '\cf1\fs' + $fb + ' ' + (& $ui.RtfEsc ($pad + $n)) + '\tab ' + (& $ui.RtfEsc $t))
    $plain += 2 + $pad.Length + $n.Length + $t.Length }   # padding, number, tab, text, and the line break
  for ($i = 0; $i -lt @($ui.GuideRest).Count; $i++) {
    $paras += ('\pard\li0\fi0\sb' + $(if ($i -or @($ui.GuideNums).Count) { $(if ($i) { 0 } else { $g3 }) } else { 0 }) + '\cf2\fs' + $fs + ' ' + (& $ui.RtfEsc ([string]$ui.GuideRest[$i]))) }
  if (-not @($ui.GuideNums).Count) { $ui.GuideInkAt = 0 }
  $rtf = '{\rtf1\ansi\ansicpg1252\deff0\uc1{\fonttbl{\f0\fnil ' + (& $ui.RtfEsc ([string]$ui.F.Body.Name)) + ';}}{\colortbl ;' + (& $col $ui.C.Navy) + (& $col $ui.C.Gray) + '}\f0 ' + ($paras -join "\par`r`n") + '}'
  if ([int]$ui.ContentW -gt 0 -and $ui.Guide.Width -ne [int]$ui.ContentW) { $ui.Guide.Width = [int]$ui.ContentW }   # its final width first: a text laid out at the default 100 px kept a wrong place for its first letter (R28 job)
  $ui.GuideH = 0; $ui.Guide.Rtf = $rtf
  $ui.Guide.AccessibleDescription = ((@(for ($i = 0; $i -lt @($ui.GuideNums).Count; $i++) { [string]$ui.GuideNums[$i] + ' ' + [string]$ui.GuideTexts[$i] }) + @($ui.GuideRest)) -join ' ') }
# How tall the text is: the rich text box says it (ContentsResized), or the place of its last letter plus one line.
$ui.GuideNeed = { $h = [int]$ui.GuideH
  try { $n = [int]$ui.Guide.TextLength; if ($n -gt 0) { $pt = $ui.Guide.GetPositionFromCharIndex($n - 1); $lf = $(if (@($ui.GuideRest).Count) { $ui.F.Small } else { $ui.F.Body }); $h = [math]::Max($h, [int]$pt.Y + [int][System.Windows.Forms.TextRenderer]::MeasureText('Ag', $lf).Height) } } catch { $null = $_ }
  return $h }
# Sets the hand-step box to its width and the height its text needs. Takes nothing; changes the box size and does
# nothing while it is already fitting.
$ui.GuideFit = { if ($ui.InGuideFit) { return }; $ui.InGuideFit = $true
  try { if ($ui.Guide.Visible) { $w = [int]$ui.ContentW; $h = [math]::Max(1, (& $ui.GuideNeed) + (& $ui.Sc 2)); if ($ui.Guide.Width -ne $w) { $ui.GuideH = 0; $ui.Guide.Width = $w; $h = [math]::Max(1, (& $ui.GuideNeed) + (& $ui.Sc 2)) }; if ($ui.Guide.Height -ne $h) { $ui.Guide.Height = $h } } } catch { $null = $_ } finally { $ui.InGuideFit = $false } }
# Where the ink of the guide's first number starts in the box: the place of the letter (as the box lays it out) plus the
# letter's own left side (drawn once into a bitmap). A rich text box cannot be drawn into a bitmap, so $ui.Ink cannot measure it.
$ui.Bearing = { param([string]$Ch, $F)
  $k = 'bearing|' + $F.Name + '|' + $F.SizeInPoints + '|' + $Ch; if ($ui.Inks.ContainsKey($k)) { return [int]$ui.Inks[$k] }; $v = 0
  try { $bm = New-Object System.Drawing.Bitmap(160, 160); try { $gb = [System.Drawing.Graphics]::FromImage($bm); $gb.Clear([System.Drawing.Color]::White)
      [System.Windows.Forms.TextRenderer]::DrawText($gb, $Ch, $F, (New-Object System.Drawing.Point(0, 0)), [System.Drawing.Color]::Black, [System.Windows.Forms.TextFormatFlags]'NoPadding'); $gb.Dispose(); $hit = -1
      for ($x = 0; $x -lt 80 -and $hit -lt 0; $x++) { for ($y = 0; $y -lt 160; $y++) { $px = $bm.GetPixel($x, $y); if ($px.R + $px.G + $px.B -lt 600) { $hit = $x; break } } }
      if ($hit -ge 0) { $v = $hit; $ui.Inks[$k] = $v } } finally { $bm.Dispose() } } catch { $null = $_ }
  return $v }
# Gives the x place where the ink of the first number starts in the hand-step box (the letter's place plus its side
# bearing); 0 when it cannot be read. Takes nothing.
$ui.GuideInk = { try { $i = [int]$ui.GuideInkAt; $t = [string]$ui.Guide.Text; if ($i -ge $t.Length) { $i = 0 }; if (-not $t) { return 0 }
    $f = $(if (@($ui.GuideNums).Count) { $ui.F.Body } else { $ui.F.Small }); return ([int]$ui.Guide.GetPositionFromCharIndex($i).X + (& $ui.Bearing ([string]$t[$i]) $f)) } catch { return 0 } }
# Fits the hand-step box after its text or the window width changed. Takes nothing; calls $ui.GuideFit.
$ui.FitSteps = { & $ui.GuideFit }
# Lays the card out again for the window's size: text widths, the choices, the step boxes and the buttons.
$ui.Fit = {
  if (-not $ui.Scaled) { return }   # R1 review: a size set while Windows Forms scales the form would be scaled again
  # Text wraps at the card's width; the choices are as wide as the card.
  # The text column: $ui.Layout.Share % of the card's width, at most $ui.Layout.MaxW (engine/window.json; the Administrator,
  # 2026-11-18), centered between the two sides. Below the cap the sides are (100 - share) / 2 % each, as before.
  $W = [int]$ui.Card.ClientSize.Width; $col = [math]::Min([int]($W * $ui.Layout.Share / 100), [int](& $ui.Sc $ui.Layout.MaxW)); $side = [math]::Max(0, [int](($W - $col) / 2))
  try { if (@($ui.CardCols).Count -eq 3 -and ([int]$ui.CardCols[0].Width -ne $side -or [int]$ui.CardCols[1].Width -ne $col)) {
      $ui.CardCols[0].SizeType = 'Absolute'; $ui.CardCols[0].Width = $side; $ui.CardCols[1].SizeType = 'Absolute'; $ui.CardCols[1].Width = $col
      $ui.CardCols[2].SizeType = 'Percent'; $ui.CardCols[2].Width = 100 } } catch { $null = $_ }   # stand-in types or a form being closed: the card keeps its last columns
  $cw = [math]::Max((& $ui.Sc 240), $col - (& $ui.Sc 4)); $ui.ContentW = $cw
  foreach ($l in @($ui.Kick, $ui.Turn, $ui.P[0], $ui.P[1], $ui.P[2], $ui.P[3], $ui.PathT, $ui.Now, $ui.Note, $ui.Help, $ui.Foot, $ui.Close)) { & $ui.SetWrap $l $cw }
  & $ui.SetWrap $ui.Sent ($cw - (& $ui.Sc 44))
  # Rows wrap at the card's width (a button or a box is never cut), and no box is wider than the card.
  $mm = & $ui.Sc $ui.Z.M
  foreach ($r in @($ui.BtnRow, $ui.LinkRow, $ui.TestRow, $ui.FieldRow, $ui.StepRow)) { $r.MaximumSize = New-Object System.Drawing.Size(($cw + 2 * $mm), 0) }
  $ui.BtnRow.MinimumSize = New-Object System.Drawing.Size(($cw + 2 * $mm), 0)   # B3: the action row is as wide as the column, so the primary can stand at its right end (an auto-sized row wraps at its own width)
  & $ui.SetWrap $ui.StepName ($cw - (& $ui.Sc 8)); $ui.ErrBox.Width = [math]::Min((& $ui.Sc $ui.Z.FieldL), ($cw - 2 * $mm))
  # The header's ink-tight texts get their size now that the window has its scale; a long name ends with "..." at the window's edge.
  foreach ($l in @($ui.TagL, $ui.AppWordL, $ui.AppVerL, $ui.AppL)) { try { $l.Tag.MaxW = [math]::Max((& $ui.Sc 60), ($ui.Top.ClientSize.Width - (& $ui.LeftIn $l $ui.Top) - (& $ui.Sc $ui.Z.Inset))) } catch { $null = $_ } }   # L1: each text of the logo block ends at the window's inset
  foreach ($l in @($ui.WordL, $ui.TagL, $ui.AppWordL, $ui.AppVerL, $ui.AppL)) { & $ui.InkFit $l }
  try { $lh = [int][System.Windows.Forms.TextRenderer]::MeasureText('Ag', $ui.Kick.Font).Height + (& $ui.Sc 2); if ($ui.Head.MinimumSize.Height -ne $lh) { $ui.Head.MinimumSize = New-Object System.Drawing.Size(0, $lh) } } catch { $null = $_ }   # L1: the header row keeps its height on a card with no line
  foreach ($l in @($ui.RightL, $ui.StepTime, $ui.StepFrac)) { & $ui.FixW $l }   # labels of changing values: one size from their widest value
  & $ui.FitRow; & $ui.Apart; & $ui.FitSent; & $ui.FitSteps; & $ui.FitEdges; & $ui.FitBar; & $ui.AlignRows
  foreach ($o in @($ui.Opts.Controls)) { $o.Width = $cw; try { $o.Height = (& $ui.OptPlan $o.Tag $cw).H } catch { $null = $_ } }
  & $ui.Squeeze }
