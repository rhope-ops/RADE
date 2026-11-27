# RADE shared UI file, part 2 (engine/rade_ui_text.ps1): where ink starts, the text RADE draws ink-tight, long words and
# one-line texts, shortened text, and drawing and measuring ($ui.Ink to $ui.Meas). Moved out of engine/rade_ui.ps1 on
# 2026-11-23 to keep each file at 450 lines or fewer (fleet v2 DEC 6). rade_build.py puts it into every bundle right
# after engine/rade_ui.ps1, at the same marker line; an app window that copies engine/rade_ui.ps1 copies this file after
# it, as it is. Its code runs when the window calls it (no part of engine/rade_ui.ps1 calls it while it loads).
# ASCII only (a bundle is ASCII). Needs from engine/rade_ui.ps1: $ui.Sc, $ui.Pad, $ui.C, $ui.FontDpi, $ui.Scaled, $ui.Trash.
# Network: none.
# Writes: none (it measures and draws on the window only).
# Credentials: none.
# ---- Where ink starts
$ui.Inks = @{}
$ui.Ink = {
  <#
  .SYNOPSIS
  Gives how far in from a control's left edge its ink starts, in pixels (the alignment rules: docs/window-design.md "Sizes").
  .DESCRIPTION
  Measured on what Windows drew (DrawToBitmap) and kept for each control kind, font, text start and size; an estimate
  from the font size when it cannot be measured (the estimate is not kept). A button with an edge gives 0.
  .PARAMETER C
  The control.
  .OUTPUTS
  The number of pixels, as an int.
  #>
  param($C)
  if ($C -is [System.Windows.Forms.ButtonBase] -and [int]$C.FlatAppearance.BorderSize -gt 0) { return 0 }
  # R28 (the Kick fix): the control is brought to the size the layout will give it BEFORE the cache key is made. The key held
  # the width the control had before it was resized, so a text measured at one width was used for another.
  try { if ($C.AutoSize -and $C.Text) { $pz = $C.PreferredSize; if ($C.Width -ne $pz.Width -or $C.Height -ne $pz.Height) { $C.Size = $pz } } } catch { $null = $_ }
  $f = $C.Font; $k = $C.GetType().Name + '|' + $f.Name + '|' + $f.SizeInPoints + '|' + $f.Style + '|' + ([string]$C.Text).PadRight(2).Substring(0, 2) + '|' +
    $(if ($C -is [System.Windows.Forms.ButtonBase] -or $C -is [System.Windows.Forms.Panel]) { [string]$C.Width + 'x' + $C.Height } else { '' })
  if ($ui.Inks.ContainsKey($k)) { return [int]$ui.Inks[$k] }
  $v = [int][math]::Ceiling([double]$f.SizeInPoints * $ui.FontDpi / 72.0 / 6.0); $got = $false
  if (-not $C.Text -and -not ($C -is [System.Windows.Forms.Panel])) { return $v }   # nothing drawn: nothing to measure
  try { $w = [math]::Max(1, $C.Width); $h = [math]::Max(1, $C.Height); $bm = New-Object System.Drawing.Bitmap($w, $h)
    try { $C.DrawToBitmap($bm, (New-Object System.Drawing.Rectangle(0, 0, $w, $h))); $bg = $C.BackColor; $hit = -1
      for ($x = 0; $x -lt [math]::Min($w, (& $ui.Sc 40)) -and $hit -lt 0; $x++) { for ($y = 0; $y -lt $h; $y++) { $px = $bm.GetPixel($x, $y); if ([math]::Abs($px.R - $bg.R) +
        [math]::Abs($px.G - $bg.G) + [math]::Abs($px.B - $bg.B) -gt 90) { $hit = $x; break } } }
      if ($hit -ge 0) { $v = $hit; $got = $true } } finally { $bm.Dispose() } } catch { $null = $_ }
  if ($got) { $ui.Inks[$k] = $v }; return $v }   # only a measure is kept; the estimate is tried again next time
# Sets the left margin of a control to L pixels (0 at least), only when it differs. Takes the control and the margin.
$ui.SetLeft = { param($C, [int]$L) $L = [math]::Max(0, $L); $m = $C.Margin; if ($m.Left -ne $L) { $C.Margin = New-Object System.Windows.Forms.Padding($L, $m.Top, $m.Right, $m.Bottom) } }
# ---- Text that RADE draws ink-tight (L2, the Administrator, 2026-11-19: the header)
# A label keeps empty room above its capitals and under its baseline (about 5 and 7 px for the word RADE), so two labels
# can never be 9 px apart ink to ink. The word RADE and the application name are panels that draw their own text and are
# exactly as tall as the ink: from the top of the capitals to the baseline (the word) or to the bottom of a "g" (a name).
# $ui.FontInk measures those rows for a font one time: "H" and "g" drawn into a bitmap by Windows. Without a bitmap (the
# test stand-ins) it gives an estimate from the text height.
$ui.FontInks = @{}
# The first and last row and column of a bitmap that hold ink (a pixel that differs from white). Takes the bitmap; gives
# back @{ Top; Bottom; Left; Right } (Bottom and Right are one past the ink), or $null when the bitmap has no ink.
$ui.InkScan = { param($Bm)
  $t = -1; $b = -1; $l = $Bm.Width; $r = -1
  for ($y = 0; $y -lt $Bm.Height; $y++) { for ($x = 0; $x -lt $Bm.Width; $x++) { $px = $Bm.GetPixel($x, $y)
      if ((255 - $px.R) + (255 - $px.G) + (255 - $px.B) -gt 90) { if ($t -lt 0) { $t = $y }; $b = $y; if ($x -lt $l) { $l = $x }; if ($x -gt $r) { $r = $x } } } }
  if ($t -lt 0) { return $null }
  return @{ Top = $t; Bottom = $b + 1; Left = $l; Right = $r + 1 } }
# Draws a text in black on a white bitmap, as $ui.InkPaint draws it (no padding, one line), and gives back its ink box
# ($ui.InkScan), or $null when nothing can be drawn (no System.Drawing bitmap). Takes the text and the font.
$ui.InkOf = { param([string]$Text, $Font)
  try { $fl = [System.Windows.Forms.TextFormatFlags]'Left, Top, NoPadding, NoPrefix, SingleLine'
    $sz = [System.Windows.Forms.TextRenderer]::MeasureText($Text, $Font, (New-Object System.Drawing.Size(100000, 0)), $fl)
    $bm = New-Object System.Drawing.Bitmap(([math]::Max(1, [int]$sz.Width + 4)), ([math]::Max(1, [int]$sz.Height + 4)))
    try { $g = [System.Drawing.Graphics]::FromImage($bm); $g.Clear([System.Drawing.Color]::White)
      [System.Windows.Forms.TextRenderer]::DrawText($g, $Text, $Font, (New-Object System.Drawing.Point(0, 0)), [System.Drawing.Color]::Black, [System.Drawing.Color]::White, $fl); $g.Dispose()
      return (& $ui.InkScan $bm) } finally { $bm.Dispose() } } catch { return $null } }
# The rows of a font's ink in a text cell: Top = the top of the capitals, Base = the baseline (one past the bottom of "H"),
# Bottom = one past the bottom of "g". Measured one time for each font; an estimate when it cannot be measured.
$ui.FontInk = { param($Font)
  $k = [string]$Font.Name + '|' + $Font.SizeInPoints + '|' + $Font.Style; if ($ui.FontInks.ContainsKey($k)) { return $ui.FontInks[$k] }
  $h = 18; try { $h = [int][System.Windows.Forms.TextRenderer]::MeasureText('Hg', $Font).Height } catch { $null = $_ }   # no measure: the height of the form font
  $v = @{ Top = [int][math]::Round($h * 0.27); Base = [int][math]::Round($h * 0.8); Bottom = $h }
  $a = & $ui.InkOf 'H' $Font; $d = & $ui.InkOf 'g' $Font
  if ($a -and $d) { $v = @{ Top = [int]$a.Top; Base = [int]$a.Bottom; Bottom = [int][math]::Max($a.Bottom, $d.Bottom) }; $ui.FontInks[$k] = $v }   # only a measure is kept
  return $v }
# Makes a panel that draws its own Text ink-tight. Takes the font, the color, the screen-reader name and whether the
# panel keeps room for descenders ($true: a name; $false: capitals only, the panel ends on the baseline). Gives back the
# panel; $ui.InkFit sizes it when its text changes and when the window has its scale.
$ui.InkText = { param($Font, $Color, [string]$Name, [bool]$Desc)
  $p = New-Object System.Windows.Forms.Panel; $p.Font = $Font; $p.ForeColor = $Color; $p.BackColor = $ui.C.White; $p.Margin = (& $ui.Pad 0 0 0 0); $p.Size = New-Object System.Drawing.Size(1, 1)
  $p.AccessibleRole = 'StaticText'; $p.AccessibleName = $Name; $p.Tag = @{ Desc = $Desc; Left = 0; MaxW = 0; Cut = $false }; $p.Visible = $false
  $p.Add_Paint({ & $ui.InkPaint $this $_.Graphics }); $p.Add_TextChanged({ & $ui.InkFit $this }); $p }
# Sizes an ink-tight panel to its text: as wide as the ink (at most Tag.MaxW when that is set: the text then ends with
# "...") and as tall as the font's ink rows. Does nothing before the window has its scale. Takes the panel.
$ui.InkFit = { param($P)
  if (-not $ui.Scaled) { return }
  try { $fi = & $ui.FontInk $P.Font; $h = $(if ($P.Tag.Desc) { $fi.Bottom } else { $fi.Base }) - $fi.Top; $w = 1; $P.Tag.Left = 0
    if ($P.Text) { $box = & $ui.InkOf ([string]$P.Text) $P.Font
      if ($box) { $P.Tag.Left = [int]$box.Left; $w = [int]$box.Right - [int]$box.Left }
      else { $w = [int][System.Windows.Forms.TextRenderer]::MeasureText([string]$P.Text, $P.Font).Width } }
    $P.Tag.Cut = ([int]$P.Tag.MaxW -gt 0 -and $w -gt [int]$P.Tag.MaxW)   # cut = the text is wider than its widest size: only then it ends with "..."
    if ($P.Tag.Cut) { $w = [int]$P.Tag.MaxW }
    $ns = New-Object System.Drawing.Size(([math]::Max(1, $w)), ([math]::Max(1, $h))); if ($P.Width -ne $ns.Width -or $P.Height -ne $ns.Height) { $P.Size = $ns }
    if ($P.Text) { $P.AccessibleName = [string]$P.Text }; $P.Invalidate() } catch { $null = $_ } }   # no size now: the next fit sizes it
# Draws the text of an ink-tight panel: moved left and up by the empty room of its text cell, so the ink starts at the
# panel's left and top edge; a text cut to its widest size (Tag.Cut) ends with "...". Takes the panel and its Graphics.
$ui.InkPaint = { param($P, $G)
  try { $G.Clear($P.BackColor); if (-not $P.Text) { return }
    $fi = & $ui.FontInk $P.Font; $l = [int]$P.Tag.Left
    # R32 (the Administrator, 2026-11-18: "RA..." at 150 %): the panel is as wide as the ink, and Windows needs the text's whole
    # cell (the ink and the last letter's side room, 1 or 2 px more at a large size) or it ends the text with "...". So a text
    # that is not cut gets room past the panel's edge (nothing is drawn there) and no "..." rule; a cut text keeps both.
    $room = $P.ClientSize.Width + $l; $fl = 'Left, Top, NoPadding, NoPrefix, SingleLine, EndEllipsis'
    if (-not $P.Tag.Cut) { $room += [int][math]::Max(8, $fi.Bottom); $fl = 'Left, Top, NoPadding, NoPrefix, SingleLine' }
    [System.Windows.Forms.TextRenderer]::DrawText($G, [string]$P.Text, $P.Font, (New-Object System.Drawing.Rectangle((-$l), (-[int]$fi.Top), $room, ([int]$fi.Bottom + 4))), $P.ForeColor, $P.BackColor,
      [System.Windows.Forms.TextFormatFlags]$fl) } catch { $null = $_ } }   # drawing never stops the window
# Where the ink of a control is, measured on what Windows drew (DrawToBitmap; the first 240 px of its width): gives back
# @{ Top; Bottom; Left; Right } in the control's own pixels, or its whole box when it cannot be measured. Takes the control.
$ui.InkBox = { param($C)
  $all = @{ Top = 0; Bottom = [int]$C.Height; Left = 0; Right = [int]$C.Width }
  try { $w = [math]::Max(1, [math]::Min([int]$C.Width, (& $ui.Sc 240))); $h = [math]::Max(1, [int]$C.Height); $bm = New-Object System.Drawing.Bitmap($w, $h)
    try { $C.DrawToBitmap($bm, (New-Object System.Drawing.Rectangle(0, 0, $w, $h))); $box = & $ui.InkScan $bm;
      if ($box) { return $box } } finally { $bm.Dispose() } } catch { $null = $_ }   # no bitmap (the test stand-ins): the whole box
  return $all }
# ---- Long words and one-line texts
# A word wider than the line (no space in it) is cut into pieces that fit, one per line: it wraps by character and is
# never clipped (R7 review). Only what the window shows changes; the report keeps the text.
# The width a label needs to show a text in one line: asked of a label that is never shown, with the same font and flags
# as the window's labels (R24 job: TextRenderer's default flags gave 3 to 9 px more than a label uses).
$ui.Probe = New-Object System.Windows.Forms.Label; $ui.Probe.AutoSize = $true; $ui.Probe.UseMnemonic = $false;
  $ui.Trash = @(@($ui.Trash) | Where-Object { $_ }) + @($ui.Probe)   # disposed when the window has closed
# The width a label needs to show a text in one line ($ui.Probe). Takes the text and the font; gives back pixels.
$ui.WordW = { param([string]$T, $F) try { $ui.Probe.Font = $F; $ui.Probe.Text = $T; return [int]$ui.Probe.PreferredSize.Width } catch { return [int][System.Windows.Forms.TextRenderer]::MeasureText($T,
  $F).Width } }
$ui.Most = @{}   # the widest values of each label of changing values ($ui.FixW)
# A label that shows changing values (a percent, a count, a time; $ui.Most[label] = the widest values it can show) keeps one
# size: as wide as the widest of them and one line tall, so nothing beside it moves when the value changes (the
# Administrator, 2026-11-19). A value wider than all of them still fits: the label grows for it. Does nothing before the
# window has its scale (Windows Forms would scale the size again). Takes the label; gives back nothing.
$ui.FixW = { param($L) if (-not $ui.Scaled) { return }
  try { $w = 0; foreach ($x in @(@($ui.Most[$L]) + @([string]$L.Text) | Where-Object { $_ })) { $w = [math]::Max($w, (& $ui.WordW ([string]$x) $L.Font)) }
    $ui.Probe.Font = $L.Font; $ui.Probe.Text = '0'; $h = [int]$ui.Probe.PreferredSize.Height; if ($L.AutoSize) { $L.AutoSize = $false }
    if ($L.Width -ne $w -or $L.Height -ne $h) { $L.Size = New-Object System.Drawing.Size($w, $h) } } catch { $null = $_ } }   # no measure: the next fit sets it
# The height of one line of text in a font, as Windows draws it (TextRenderer: on a 150 % screen it can be taller than
# what a text box gives itself; R35 "Field line cut: one line needs 32 high, has 27"). Takes the font; gives back pixels.
$ui.LineH = { param($Font) [int][System.Windows.Forms.TextRenderer]::MeasureText('Ag', $Font).Height }
$ui.BreakLong = {
  <#
  .SYNOPSIS
  Cuts each word of a text that is wider than the line into pieces that fit, one per line (the comment above).
  .PARAMETER T
  The text.
  .PARAMETER F
  The font it shows in.
  .PARAMETER W
  The line width, in pixels (0 or less: the text is not changed).
  .OUTPUTS
  The text with the long words cut, as a string; the line breaks of the text are kept.
  #>
  param([string]$T, $F, [int]$W)
  if ($W -le 0 -or -not $T) { return $T }
  $parts = foreach ($ln in ($T -split '(\r?\n)')) {   # line by line; the line breaks are kept
    if ($ln -match '^\r?\n$') { $ln; continue }
    $ws = foreach ($wd in ($ln -split ' ')) {
      if ((& $ui.WordW $wd $F) -le $W) { $wd; continue }
      # by text element (M4 review): a surrogate pair or a letter with its accents is never split
      $pc = @(); $cur = ''; $en = [System.Globalization.StringInfo]::GetTextElementEnumerator($wd)
      while ($en.MoveNext()) { $ch = [string]$en.GetTextElement(); if ($cur -and (& $ui.WordW ($cur + $ch) $F) -gt $W) { $pc += $cur; $cur = '' }; $cur += $ch }
      $pc += $cur; $pc -join "`n" }
    @($ws) -join ' ' }
  return (@($parts) -join '') }
# ---- Shortened text
# A one-line text cut to fit a width with "..." at the end, measured by the control itself (M5 review: no AutoEllipsis,
# which shows a tooltip). Binary search on the number of text elements.
$ui.Shorten = { param($C, [string]$Full, [int]$W)
  $C.Text = $Full; if ($C.PreferredSize.Width -le $W) { return }
  $si = New-Object System.Globalization.StringInfo($Full); $lo = 0; $hi = $si.LengthInTextElements
  while ($lo -lt $hi) { $mid = [int][math]::Ceiling(($lo + $hi) / 2.0); $C.Text = $si.SubstringByTextElements(0, $mid).TrimEnd() + '...';
    if ($C.PreferredSize.Width -le $W) { $lo = $mid } else { $hi = $mid - 1 } }
  $C.Text = $(if ($lo -gt 0) { $si.SubstringByTextElements(0, $lo).TrimEnd() } else { '' }) + '...' }
# Cuts a text to N lines with "..." (the help below).
$ui.FitLines = {
  <#
  .SYNOPSIS
  Cuts a text to at most N lines at a width, with "..." at its end when it is cut (the Administrator, 2026-11-19).
  .DESCRIPTION
  Measured as a card text box wraps ($ui.Meas). Binary search on the number of text elements, so a letter with its accents
  is never split. The text is not changed when it fits.
  .PARAMETER T
  The text.
  .PARAMETER F
  The font it shows in.
  .PARAMETER W
  The wrap width, in pixels.
  .PARAMETER N
  The most lines it may take.
  .OUTPUTS
  The text that fits, as a string.
  #>
  param([string]$T, $F, [int]$W, [int]$N)
  if (-not $T -or $W -le 0 -or $N -le 0) { return $T }
  $most = $N * (& $ui.Meas 'Ag' $F 100000).Height
  if ((& $ui.Meas $T $F $W).Height -le $most) { return $T }
  $si = New-Object System.Globalization.StringInfo($T); $lo = 0; $hi = $si.LengthInTextElements
  while ($lo -lt $hi) { $mid = [int][math]::Ceiling(($lo + $hi) / 2.0); $x = $si.SubstringByTextElements(0, $mid).TrimEnd() + '...';
    if ((& $ui.Meas $x $F $W).Height -le $most) { $lo = $mid } else { $hi = $mid - 1 } }
  return ($(if ($lo -gt 0) { $si.SubstringByTextElements(0, $lo).TrimEnd() } else { '' }) + '...') }
# The self-check's rule for it: a word of a text that wraps is never wider than the line the text may take (a label's
# MaximumSize, a card text box's $ui.GetWrap; else the word is cut). Not the label's own width: a wrapping label is as wide
# as its widest line by its own measure, about 1 % narrower than the probe's, so a cut piece that is the widest line would
# always seem too wide (R28 job: 591/588, 597/591, 592/588).
$ui.WordBad = { param([string]$Card, [string]$Name, [string]$Text, $F, [int]$W)
  foreach ($wd in ($Text -split '\s+')) { if ($wd) { $ww = & $ui.WordW $wd $F; if ($ww -gt $W + 1) { return ('LAYOUT ' + $Card + ' ' + $Name + ' text: the word "' +
    $(if ($wd -match '[\\/]') { '<a path>' } elseif ($wd.Length -gt 20) { $wd.Substring(0, 20) + '...' } else { $wd }) + '" needs ' + $ww + ', the line is ' + $W) } } }
  return $null }
# ---- Drawing and measuring
# Draws a text in a box with TextRenderer. Takes the Graphics, the text, the font, the color, the box and the flags.
$ui.Word = { param($G, [string]$Text, $Font, $Color, [int]$X, [int]$Y, [int]$W, [int]$H, [string]$Flags) [System.Windows.Forms.TextRenderer]::DrawText($G, $Text, $Font,
  (New-Object System.Drawing.Rectangle($X, $Y, [math]::Max(1, $W), $H)), $Color, [System.Windows.Forms.TextFormatFlags]$Flags) }
# The size of a text that wraps at a width (the real font; docs/window-design.md "Text lengths").
$ui.Meas = { param([string]$Text, $Font, [int]$W) [System.Windows.Forms.TextRenderer]::MeasureText($Text, $Font, (New-Object System.Drawing.Size([math]::Max(1, $W), 0)),
  [System.Windows.Forms.TextFormatFlags]'WordBreak, NoPrefix, TextBoxControl') }
# ---- Copy and paste of card text (moved from engine/rade_ui.ps1 for engine-v48, to keep it at 450 lines or fewer)
# Copy gives the text as written (R28 N4): a word that RADE broke to fit a line is whole again (the break is a lone line feed), and the
# lines of a hand step (a rich text box) lose the tabs of their number column: "1. Open the page." on its own line.
$ui.CopyText = { param($C)
  try { if (-not ($C -is [System.Windows.Forms.TextBoxBase]) -or $C.SelectionLength -le 0) { return $false }
    $s = [string]$C.SelectedText
    if ($C -is [System.Windows.Forms.RichTextBox]) { $s = ($s -replace '\r?\n', "`n" -replace ([string][char]0x2007), '' -replace '\t', ' ') -replace "`n", "`r`n" }
    elseif (& $ui.IsCardText $C) { $s = $s -replace '(?<!\r)\n', '' }
    if ($s) { [System.Windows.Forms.Clipboard]::SetText($s); return $true } } catch { $null = $_ }
  return $false }
# R34 (the PFM: the answer box did not take a pasted block): a one-line box keeps only the first line of a paste, so a
# paste into it comes here. $ui.OneLine joins the lines of a text with one space and cuts it to the room that is left.
# Takes the text and the room (characters); gives back the text to put in.
$ui.OneLine = { param([string]$T, [int]$Room)
  $s = ($T -replace '\s*(\r\n|\r|\n)\s*', ' ' -replace '\t', ' ').Trim(); if ($Room -lt 0) { $Room = 0 }; if ($s.Length -gt $Room) { $s = $s.Substring(0, $Room) }; return $s }
