# RADE window part 05, alignment and layout: centers a row of controls, breaks and fits long text, keeps the
# card inside the window (Squeeze) and runs the layout self-check. Builds on 03-card.ps1.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# ---- Alignment (the Administrator, 2026-11-15, after the R24 pictures; docs/window-design.md "Sizes"). An aligned row:
# its parts share one vertical midpoint (each part's top margin is set from the tallest part). One left edge per card:
# a label draws its text after a padding that grows with its font (Windows text padding: about 1/6 of the line), so a
# 22 pt headline started about 3 px right of a 9 pt line and of the buttons. Each part moves by its own padding.
# Where a part's ink starts, measured: the part drawn into a bitmap by Windows (DrawToBitmap: the same drawing as on
# screen, with its own flags, padding and the first glyph's side bearing), the first column that differs from its back
# color. A button with an edge starts at its edge. Without a bitmap (the test stand-ins), the text padding Windows adds
# (1/6 em, rounded up). R24 job: a formula and a with/without-NoPadding measure both missed by 3 to 6 px.
# One edge per card at $ui.Sc 10 from the card's column: room for the largest text inset (a 22 pt headline: about 7)
# and for a button's 4 px margin, because a negative margin is taken as 0 in a table cell (R24 job).
$ui.FitEdges = { try {
    $mm = & $ui.Sc $ui.Z.M; $x = & $ui.Sc 10; $ui.EdgeX = $x
    foreach ($l in @($ui.Kick, $ui.P[0], $ui.P[1], $ui.P[2], $ui.P[3], $ui.PathL, $ui.PathT, $ui.Note, $ui.Help, $ui.Foot, $ui.Close, $ui.Now, $ui.FieldL, $ui.TestL)) { & $ui.SetLeft $l ($x - (& $ui.Ink $l)) }
    & $ui.SetLeft $ui.TickP 0; & $ui.SetLeft $ui.SentRow ($x - $(if ($ui.TickP.Visible) { & $ui.Ink $ui.TickP } else { & $ui.Ink $ui.Sent }))
    & $ui.SetLeft $ui.StepRow ($x - (& $ui.Ink $ui.StepName)); & $ui.SetLeft $ui.ErrRow ($x - $ui.ErrBox.Margin.Left)
    & $ui.SetLeft $ui.BtnRow ($x - $mm)   # a button's own 4 px margin (room for the ring)
    $l1 = @($ui.LinkRow.Controls | Where-Object { $_.Visible })[0]; if ($l1) { & $ui.SetLeft $ui.LinkRow ($x - $mm - (& $ui.Ink $l1)) }   # a link's text is in the middle of its box
    if ($ui.Guide.Visible) { & $ui.SetLeft $ui.Guide ($x - (& $ui.GuideInk)) }   # the widest number sits on the edge; shorter ones are right-aligned to it
    & $ui.SetLeft $ui.Opts $x } catch { $null = $_ }
  & $ui.FitHead }
# R29b V1: the word RADE and the application name under it start their ink on one edge. Each sits at the same x in its row
# (after a 64 px logo and its 12 px gap, or at 0) and draws its text ink-tight ($ui.InkText); what is left of a difference
# (measured) moves each to the larger of the two. Takes nothing; changes the left margins of $ui.WordL, $ui.AppL and
# $ui.HeadRule, and the width of $ui.HeadRule.
$ui.FitHead = { try {
    if (-not (& $ui.HeadPair)) { & $ui.SetLeft $ui.WordL 0; & $ui.SetLeft $ui.AppL 0; return }
    $iw = & $ui.Ink $ui.WordL; $ia = & $ui.Ink $ui.AppL; $e = [math]::Max($iw, $ia)
    & $ui.SetLeft $ui.WordL ($e - $iw); & $ui.SetLeft $ui.AppL ($e - $ia)
    # L2: the line under the word is as wide as the word's ink and starts where it starts.
    if ($ui.AppUnder) { & $ui.SetLeft $ui.HeadRule $e; $rw = [math]::Max(1, [int]$ui.WordL.Width - $iw); if ($ui.HeadRule.Width -ne $rw) { $ui.HeadRule.Width = $rw } } } catch { $null = $_ } }   # no measure (no window handle yet): the next fit sets the edges
# Whether the header shows the application name on the edge of the word RADE: the name has text and shows, and both rows
# start at the same x (both logos, or no application logo). Takes nothing; gives back $true or $false.
$ui.HeadPair = { [bool]([string]$ui.AppL.Text -and $(if ($ui.AppUnder) { $ui.AppL.Visible } else { $ui.AppRow.Visible }) -and ($ui.AppUnder -or $ui.Logo)) }
# The x of a control inside one of its parents (the sum of the lefts on the way up). Takes the control and the parent;
# gives back the pixels.
$ui.LeftIn = { param($C, $P) $x = 0; $c = $C; while ($c -and -not [object]::ReferenceEquals($c, $P)) { $x += [int]$c.Left; $c = $c.Parent }; $x }
# The step bar's own top margin, scaled ($ui.Z.BarTop at 100 %). Takes nothing; gives back the pixels.
$ui.BarTop = { & $ui.Sc $ui.Z.BarTop }
# The height a label has with a text in it. An empty label asks for less (31 against 33 px at 150 %; R32), so a row aligned
# before its first text was 1.5 px off the bar afterwards. Takes the label; gives back the pixels.
$ui.LabelH = { param($L) try { if (-not [string]$L.Text) { $ui.Probe.Font = $L.Font; $ui.Probe.Text = '0'; return [int]$ui.Probe.PreferredSize.Height } } catch { $null = $_ }; return [int]$L.PreferredSize.Height }   # no probe: the label's own answer
# R29b N3: the time in this step and its count sit on the vertical midpoint of the step's bar (the same flow line: each
# part's top is the line's top plus its top margin). A text taller than the bar's place moves the bar down; that lift is
# worked out from $ui.BarTop each time, so it never adds up. Takes nothing; changes the top margins of $ui.StepBar,
# $ui.StepTime and $ui.StepFrac.
$ui.AlignTick = { try {
    $b0 = [int](& $ui.BarTop)
    $h = [int](& $ui.LabelH $ui.StepTime); $lift = [int][math]::Max(0, [math]::Ceiling($h / 2.0 - ($b0 + [double]$ui.StepBar.Height / 2.0)))   # a text taller than the bar's place: the bar moves down
    $m = $ui.StepBar.Margin; if ($m.Top -ne $b0 + $lift) { $ui.StepBar.Margin = New-Object System.Windows.Forms.Padding($m.Left, ($b0 + $lift), $m.Right, $m.Bottom) }
    $bm = [double]$ui.StepBar.Margin.Top + [double]$ui.StepBar.Height / 2.0
    foreach ($l in @($ui.StepTime, $ui.StepFrac)) { $hl = [int](& $ui.LabelH $l); $t = [int][math]::Max(0, [math]::Round($bm - $hl / 2.0, [System.MidpointRounding]::AwayFromZero)); $m = $l.Margin
      if ($m.Top -ne $t) { $l.Margin = New-Object System.Windows.Forms.Padding($m.Left, $t, $m.Right, $m.Bottom) } } } catch { $null = $_ } }   # no bar yet: the next fit aligns the row
# R32 (the Administrator, 2026-11-18: "too much dead space", "the bar is not on the middle of the sentence"): in a narrow
# window a step title of some length left no room for the 200 px bar, so the bar went to a line of its own under the
# title. The bar now takes the room that is left beside the title and the time (200 px at most, 60 at least, at 100 %)
# and goes under the title only when even 60 does not fit. Takes nothing; changes the width of $ui.StepBar.
$ui.FitBar = { try {
    $full = & $ui.Sc 200; $m = $ui.StepBar.Margin; $row = [int]$ui.StepRow.MaximumSize.Width; if ($row -le 0) { return }
    $tw = [int][math]::Max((& $ui.WordW '00m 00s' $ui.StepTime.Font), [int]$ui.StepTime.PreferredSize.Width)
    $fw = [int]$ui.StepFrac.PreferredSize.Width + $ui.StepFrac.Margin.Left   # the count is in the row also when it is empty: with no room it took a line of its own, which was the empty space under the title
    $room = $row - [int]$ui.StepName.Width - $ui.StepName.Margin.Left - $m.Left - $m.Right - $tw - $fw - (& $ui.Sc 8)
    $w = $(if ($room -ge (& $ui.Sc 60)) { [int][math]::Min($full, $room) } else { $full })
    if ($ui.StepBar.Width -ne $w) { $ui.StepBar.Width = $w } } catch { $null = $_ } }   # no measure yet: the next fit sets it
# Centers a row of controls up and down by changing their top and bottom margins. Takes the controls and the top margin
# of the row; gives back nothing.
$ui.AlignRow = { param($Parts, [int]$Base)
  try { $hs = @($Parts | ForEach-Object { if ($_.AutoSize) { [int]$_.PreferredSize.Height } else { [int]$_.Height } }); $hh = [int]($hs | Measure-Object -Maximum).Maximum
    for ($i = 0; $i -lt $Parts.Count; $i++) { $m = $Parts[$i].Margin; $t = $Base + [int][math]::Floor(($hh - $hs[$i]) / 2); $b = $Base + $hh - $hs[$i] - ($t - $Base)
      if ($m.Top -ne $t -or $m.Bottom -ne $b) { $Parts[$i].Margin = New-Object System.Windows.Forms.Padding($m.Left, $t, $m.Right, $b) } } } catch { $null = $_ } }
# Returns the controls of one aligned row (Top, FieldRow, ...). Takes the row name.
$ui.RowParts = { param([string]$Row) switch ($Row) { 'Top' { @(@($ui.Logo, $ui.TitleCol) | Where-Object { $_ }) } 'AppRow' { @(@($ui.AppLogo, $ui.AppL) | Where-Object { $_ }) } 'FieldRow' { @($ui.FieldL, $ui.FieldBox) + @($(if ($ui.FieldBOn) { $ui.FieldB })) } 'TestRow' { @($ui.TestL, $ui.ToBoxF, $ui.DraftB, $ui.OkBox) } } }
# Lines up every fixed row: box heights, the text box in its frame, then each row on one center line.
$ui.AlignRows = { try { $bh = [int]$ui.FieldB.PreferredSize.Height; if ($bh -gt 0) { foreach ($p in $ui.Boxes) { if ($p.Height -ne $bh) { $p.Height = $bh } } } } catch { $null = $_ }   # a box is as tall as the compact button, measured
  foreach ($p in $ui.Boxes) { & $ui.BoxFit $p }   # the text box fills its frame (R24 job: a frame whose size never changed kept a 100 px text box at its top)
  & $ui.AlignRow (& $ui.RowParts 'Top') 0; if (-not $ui.AppUnder) { & $ui.AlignRow (& $ui.RowParts 'AppRow') 0 };   # no application logo: the name is in the title column with its own 4 px gap (review of PR 106: a row of one part set it to 0)
  $mm = & $ui.Sc $ui.Z.M; & $ui.AlignRow (& $ui.RowParts 'TestRow') $mm; & $ui.AlignTick
  # L3 (the Administrator, 2026-11-19): a label above its box (a text answer). The box is on the next line, on the card's edge, 4 px under the label.
  if ($ui.FieldAbove) { $ui.FieldL.Margin = New-Object System.Windows.Forms.Padding($ui.FieldL.Margin.Left, $mm, 0, 0); $ui.FieldBox.Margin = New-Object System.Windows.Forms.Padding([int]$ui.EdgeX, (& $ui.Sc $ui.Z.G1), $mm, $mm) }
  else { $bx = $ui.FieldBox.Margin; $g2 = & $ui.Sc $ui.Z.G2; if ($bx.Left -ne $g2) { $ui.FieldBox.Margin = New-Object System.Windows.Forms.Padding($g2, $bx.Top, $mm, $bx.Bottom) }; & $ui.AlignRow (& $ui.RowParts 'FieldRow') $mm } }
# The question headline (the prompt's first sentence, manifest "answers") shrinks to fit one line: from the headline size
# in 0.5 pt steps to 60 % of it (never under the body size); only at that size does it wrap. Other cards keep the headline size.
$ui.SentFonts = @{}
# Every text the window puts into a wrapping label of the card: a word wider than the line is broken (M3 review). A
# label's text set elsewhere since the last break (for example a note) is taken as its new text.
$ui.Raw = @{}
# Re-breaks the long words of every card text so each line fits its width. Takes nothing; changes the label texts (the
# raw text is kept in $ui.Raw).
$ui.BreakAll = { foreach ($l in @($ui.Kick, $ui.P[0], $ui.P[1], $ui.P[2], $ui.P[3], $ui.PathT, $ui.StepName, $ui.Note, $ui.Help, $ui.Foot, $ui.Close)) {
    try { $w = [int](& $ui.GetWrap $l); if ($w -le 0 -or -not $l.Text) { continue }
      $e = $ui.Raw[$l]; $raw = $(if ($e -and [string]$l.Text -ceq [string]$e.Out) { [string]$e.Raw } else { [string]$l.Text })
      $b = & $ui.BreakLong $raw $l.Font $w; $ui.Raw[$l] = @{ Raw = $raw; Out = $b }; if ([string]$l.Text -cne $b) { $l.Text = $b } } catch { $null = $_ } }
  & $ui.CutNow }   # the now-doing line is cut again from its whole text at the new width (review of PR 121)
# Fits the headline: on an answer card the font shrinks, not below the body size, until the text fits one line; then it
# breaks long words and calls $ui.BreakAll. Takes nothing; changes $ui.Sent.
$ui.FitSent = { try {
    $f = $ui.F.Sent; $w = [int](& $ui.GetWrap $ui.Sent); $t = [string]$ui.SentRaw
    if ($ui.View -eq 'answer') { $pt = [double]$ui.F.Sent.SizeInPoints / $ui.FontK; $floor = [math]::Max($pt * 0.6, [double]$ui.F.Body.SizeInPoints / $ui.FontK)
      while ($w -gt 0 -and $pt -gt $floor -and [System.Windows.Forms.TextRenderer]::MeasureText($t, $f).Width -gt $w) {
        $pt = [math]::Max($floor, $pt - 0.5); $k = [string]$pt; if (-not $ui.SentFonts.ContainsKey($k)) { $ui.SentFonts[$k] = & $ui.Font ([string]$ui.F.Sent.Name) $pt $null }; $f = $ui.SentFonts[$k] }
    }
    if (-not [object]::ReferenceEquals($ui.Sent.Font, $f)) { $ui.Sent.Font = $f }
    $b = & $ui.BreakLong $t $f $w; if ($ui.Sent.Text -ne $b) { $ui.Sent.Text = $b } } catch { $null = $_ }
  & $ui.BreakAll }
$ui.FitRow = {
  # The box of a box row takes the width that is left beside its label and its button (at most 420). A box under its
  # label (L3) is as wide as the card's text: from the card's edge to the end of the text column.
  try { $cw = $ui.ContentW
    if ($ui.FieldAbove) { $ui.FieldBox.Width = [math]::Max((& $ui.Sc 160), ($cw - (& $ui.Sc 10))); return }
    $left = $cw - $ui.FieldL.PreferredSize.Width - (& $ui.Sc 20)
    if ($ui.FieldBOn) { $left -= ($ui.FieldB.PreferredSize.Width + (& $ui.Sc 8)) }
    $ui.FieldBox.Width = [math]::Max((& $ui.Sc 160), [math]::Min((& $ui.Sc 420), [int]$left)) } catch { $null = $_ } }
$ui.Apart = {
  # The destructive button (Buttons: Apart) is alone at the right end of the row. When the row is too narrow for
  # that, it starts its own row at the left edge.
  try { $mm = & $ui.Sc $ui.Z.M; $n = -1; $prev = -1; $used = 0
    for ($k = 0; $k -lt $ui.NB; $k++) { $ui.BtnRow.SetFlowBreak($ui.B[$k], $false); if ($ui.BOn[$k]) { $ui.B[$k].Margin = (& $ui.Pad $mm $mm $mm $mm); if ($ui.BApart[$k]) { $n = $k } } }
    if ($n -lt 1) { return }
    for ($k = 0; $k -lt $n; $k++) { if ($ui.BOn[$k]) { $prev = $k; $used += $ui.B[$k].PreferredSize.Width + 2 * $mm } }
    $left = $ui.ContentW + $mm - $used - $ui.B[$n].PreferredSize.Width
    if ($prev -lt 0) { return }
    if ($left -ge (& $ui.Sc 32)) { $ui.B[$n].Margin = (& $ui.Pad ([int]$left) $mm $mm $mm) } else { $ui.BtnRow.SetFlowBreak($ui.B[$prev], $true) }
  } catch { $null = $_ } }
# Places the card frame (L1) and lets the card's text scroll when the card is taller than the window (the help below).
$ui.Squeeze = {
  <#
  .SYNOPSIS
  Places the card frame (L1) and lets the card's text scroll when the card is taller than the window, so the buttons stay in view.
  .DESCRIPTION
  The frame's top is fixed for a window size; a card too tall for the room under it moves up before it scrolls. A short
  card gets a gap above its buttons, so the frame is its minimum height.
  .OUTPUTS
  Nothing. Sets the card's top row, the size of $ui.Scroll and $ui.Gap, $ui.Scrolls and $ui.Frame (what the self-check compares).
  #>
  if (-not $ui.Scaled) { return }
  if ($ui.InSqueeze) { return }; $ui.InSqueeze = $true
  try { $bh = [int]$ui.Body.Height; $bw = [int]$ui.Body.Width; $H = [int]$ui.Card.ClientSize.Height; $hh = [int]$ui.Head.Height; $th = [int]$ui.Tail.Height
    $min = [math]::Min((& $ui.Sc $ui.Layout.FrameMin), $H); $want = [int][math]::Floor(($H - $min) * 0.4); $top = $want
    $need = $hh + $bh + $th; if ($need -gt $H - $top) { $top = [math]::Max(0, $H - $need) }   # a tall card moves up before it gets a scroll bar
    $avail = $H - $top - $hh - $th; $sh = $bh; $bar = 0
    if ($bh -gt $avail) { $sh = [math]::Max((& $ui.Sc 80), $avail); $bar = [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth + (& $ui.Sc 4) }
    $ui.Scrolls = [bool]$bar; $gap = [math]::Max(0, $min - $hh - $sh - $th)
    $ui.Frame = @{ WantTop = $want; MinH = $min; Moved = ($top -ne $want) }
    if ($ui.Scroll.Width -ne ($bw + $bar) -or $ui.Scroll.Height -ne $sh) { $ui.Scroll.Size = New-Object System.Drawing.Size(($bw + $bar), $sh) }
    if ($ui.Gap.Height -ne $gap) { $ui.Gap.Height = $gap }; if ($ui.Gap.Visible -ne [bool]$gap) { $ui.Gap.Visible = [bool]$gap }
    try { if ([int]$ui.CardRows[0].Height -ne $top) { $ui.CardRows[0].Height = $top } } catch { $null = $_ }   # stand-in types: no row styles
  } catch { $null = $_ } finally { $ui.InSqueeze = $false } }   # a size that cannot be read: the next fit places the frame
$ui.Body.Add_SizeChanged({ & $ui.Squeeze }); $ui.Tail.Add_SizeChanged({ & $ui.Squeeze }); $ui.Head.Add_SizeChanged({ & $ui.Squeeze })
$ui.Card.Add_SizeChanged({ try { & $ui.Fit } catch { $null = $_ } })
# Counts how many lines a text takes at a width, at least 1 and at most a limit (0 for no text). Takes the text, font,
# width, one line's height and the limit; gives back the number.
$ui.Rows = { param([string]$Text, $Font, [int]$W, [int]$LineH, [int]$Most) if (-not $Text) { return 0 }; [math]::Min($Most, [math]::Max(1, [int][math]::Round((& $ui.Meas $Text $Font $W).Height / [math]::Max(1, $LineH)))) }
$ui.OptPlan = { param($o, [int]$w)
  # Where the parts of one choice go, and how tall it is. The name gets its width first. The two facts stay on the
  # right when the name and they fit on one line; else they go on one line under the summary. The summary, a blocked
  # application's reason and its "What to do" wrap to 2 lines each, then end with "...".
  $pad = & $ui.Sc 16; $x = $pad + (& $ui.Sc 38); $inner = $w - $x - $pad; $gap = & $ui.Sc 12
  $h1 = [System.Windows.Forms.TextRenderer]::MeasureText('Ag', $ui.F.Body).Height; $h2 = [System.Windows.Forms.TextRenderer]::MeasureText('Ag', $ui.F.Small).Height
  $vw = 0; if ($o.Ver) { $vw = [System.Windows.Forms.TextRenderer]::MeasureText([string]$o.Ver, $ui.F.Small).Width }
  $nw = [System.Windows.Forms.TextRenderer]::MeasureText([string]$o.Name, $ui.F.Body).Width
  $rw = 0; foreach ($r in @($o.R1, $o.R2)) { if ($r) { $rw = [math]::Max($rw, [System.Windows.Forms.TextRenderer]::MeasureText([string]$r, $ui.F.SmallB).Width) } }
  $under = [bool]($rw -and -not $o.Off -and ($nw + $vw + $gap + $rw) -gt $inner)
  $tw = $inner; if ($rw -and -not $under) { $tw = $inner - $rw - $gap }
  $s1 = & $ui.Rows ([string]$o.Sub) $(if ($o.Off) { $ui.F.SmallB } else { $ui.F.Small }) $tw $h2 2; $s2 = & $ui.Rows ([string]$o.Sub2) $ui.F.Small $tw $h2 2; $nl = & $ui.Rows ([string]$o.Note) $ui.F.SmallB $tw $h2 2
  $need = $h1 + ($s1 + $s2 + $nl + [int]$under) * $h2
  $hh = [math]::Max((& $ui.Sc 66), ($need + (& $ui.Sc 20)))
  return @{ H = [int]$hh; Pad = $pad; X = $x; Tw = [int]$tw; Rw = $rw; Under = $under; S1 = $s1; S2 = $s2; NL = $nl; H1 = $h1; H2 = $h2; Vw = $vw; Nw = $nw; Y = [int](($hh - $need) / 2) } }
$ui.PaintOpt = { param($P, $G)
  # One choice: a key (1 to 9), the name and version, the summary, an optional notice, and two facts. An application
  # that cannot run here is not a button: a red cross, the reason, what to do, and the word FAILED.
  try {
    $o = $P.Tag; $w = $P.ClientSize.Width; $h = $P.ClientSize.Height; $G.Clear($ui.C.White)
    $pl = & $ui.OptPlan $o $w; $pad = $pl.Pad; $x = $pl.X; $y = $pl.Y; $h1 = $pl.H1; $h2 = $pl.H2; $tw = $pl.Tw; $rw = $pl.Rw
    $one = 'Left, Top, NoPrefix, SingleLine, EndEllipsis'; $wrap = 'Left, Top, NoPrefix, WordBreak, EndEllipsis, TextBoxControl'
    if ($o.Off) {
      $pn = New-Object System.Drawing.Pen($ui.C.Hair); $G.DrawLine($pn, 0, 0, $w, 0); $pn.Dispose()
      $cp = New-Object System.Drawing.Pen($ui.C.Red, [single](& $ui.Sc 2)); $d = & $ui.Sc 12; $cx = $pad + (& $ui.Sc 6); $cy = [int](($h - $d) / 2)
      $G.DrawLine($cp, $cx, $cy, ($cx + $d), ($cy + $d)); $G.DrawLine($cp, ($cx + $d), $cy, $cx, ($cy + $d)); $cp.Dispose()
    } else {
      $foc = [bool]$P.Focused; $t = $(if ($foc) { & $ui.Sc 2 } else { 1 })
      $pn = New-Object System.Drawing.Pen($(if ($foc) { $ui.C.Navy } else { $ui.C.Edge }), [single]$t); $i = [int]($t / 2); $G.DrawRectangle($pn, $i, $i, ($w - 1 - 2 * $i), ($h - 1 - 2 * $i)); $pn.Dispose()
      $k = & $ui.Sc 24; $ky = [int](($h - $k) / 2); $kp = New-Object System.Drawing.Pen($ui.C.Edge); $G.DrawRectangle($kp, $pad, $ky, $k, $k); $kp.Dispose()
      & $ui.Word $G ([string]$o.Key) $ui.F.SmallB $ui.C.Gray $pad $ky $k $k 'HorizontalCenter, VerticalCenter, NoPrefix, SingleLine'
    }
    $nw = [math]::Max((& $ui.Sc 40), [math]::Min($pl.Nw, ($tw - $pl.Vw)))   # the name first; the version keeps its place after it
    & $ui.Word $G ([string]$o.Name) $ui.F.Body $(if ($o.Off) { $ui.C.Gray } else { $ui.C.Navy }) $x $y $nw $h1 $one
    if ($o.Ver) { & $ui.Word $G ([string]$o.Ver) $ui.F.Small $ui.C.Gray ($x + $nw) $y ([math]::Max(1, ($tw - $nw))) $h1 $one }
    $yy = $y + $h1
    if ($o.Sub) { & $ui.Word $G ([string]$o.Sub) $(if ($o.Off) { $ui.F.SmallB } else { $ui.F.Small }) $(if ($o.Off) { $ui.C.Navy } else { $ui.C.Gray }) $x $yy $tw ($pl.S1 * $h2) $wrap; $yy += $pl.S1 * $h2 }
    if ($o.Sub2) { & $ui.Word $G ([string]$o.Sub2) $ui.F.Small $ui.C.Navy $x $yy $tw ($pl.S2 * $h2) $wrap; $yy += $pl.S2 * $h2 }
    if ($pl.Under) { & $ui.Word $G ((@($o.R1, $o.R2) | Where-Object { $_ }) -join $dot) $ui.F.Small $ui.C.Navy $x $yy $tw $h2 $one; $yy += $h2 }
    if ($o.Note) { & $ui.Word $G ([string]$o.Note) $ui.F.SmallB $ui.C.Navy $x $yy $tw ($pl.NL * $h2) $wrap }
    if ($rw -and -not $pl.Under) {
      $rx = $w - $pad - $rw
      if ($o.R1) { & $ui.Word $G ([string]$o.R1) $(if ($o.Off) { $ui.F.SmallB } else { $ui.F.Small }) $(if ($o.Off) { $ui.C.Red } else { $ui.C.Navy }) $rx ($y + (& $ui.Sc 2)) $rw $h2 'Right, Top, NoPrefix, SingleLine' }
      if ($o.R2) { & $ui.Word $G ([string]$o.R2) $ui.F.Small $ui.C.Gray $rx ($y + $h1) $rw $h2 'Right, Top, NoPrefix, SingleLine' }
    }
  } catch { $null = $_ } }
# Fills the choice list with one button for each item (the old ones are kept to dispose after the window closes).
# Takes the list of items (name, version, notes).
$ui.FillOpts = { param($List)
  $ui.Trash = @($ui.Trash) + @($ui.Opts.Controls); $ui.Opts.Controls.Clear()   # old choices are disposed after the window has closed: a button is never disposed inside its own Click
  $n = 0
  foreach ($o in @($List | Where-Object { $_ })) {
    $said = (@($o.Name, $o.Ver, $o.Sub, $o.Sub2, $o.Note, $o.R1, $o.R2) | Where-Object { $_ }) -join '. '
    if ($o.Off) { $c = New-Object System.Windows.Forms.Panel; $c.AccessibleRole = 'StaticText'; $c.AccessibleName = $said }
    else {
      $n++; $o.Key = $n
      $c = New-Object System.Windows.Forms.Button; $c.FlatStyle = 'Flat'; $c.FlatAppearance.BorderSize = 0; $c.UseVisualStyleBackColor = $false; $c.Text = ''; $c.AccessibleName = ('Choice ' + $n + ': ' + $said)
      $c.Add_Click({ if ($ui.OnOpt -and -not $ui.Busy -and (& $ui.Settled)) { & $ui.OnOpt ([int]$this.Tag.Index) } }); $c.Add_GotFocus({ $this.Invalidate() }); $c.Add_LostFocus({ $this.Invalidate() })
    }
    $c.Tag = $o; $c.BackColor = $ui.C.White; $c.Margin = (& $ui.Pad 0 0 0 (& $ui.Sc 8))
    $hh = & $ui.Sc $(if ($o.Note -or $o.Sub2) { 86 } else { 66 }); try { $hh = (& $ui.OptPlan $o $ui.ContentW).H } catch { $null = $_ }   # as tall as its lines, 66 at least
    $c.Size = New-Object System.Drawing.Size($ui.ContentW, $hh)
    $c.Add_Paint({ & $ui.PaintOpt $this $_.Graphics })
    [void]$ui.Opts.Controls.Add($c)
  } }
$ui.Measure = { param([string]$Card)
  # The numbers for RowBad and EdgeBad, from the real layout (screen pixels).
  $out = @(); $sr = { param($C) $C.RectangleToScreen($C.ClientRectangle) }
  foreach ($row in 'Top', 'AppRow', 'FieldRow', 'TestRow') {
    $ps = @(& $ui.RowParts $row); if ($ps.Count -lt 2 -or -not $ps[0].Parent.Visible) { continue }   # the parts AlignRow aligns (R5 review: one rule for both)
    $out += & $ui.RowBad $Card $row @($ps | ForEach-Object { $rr = & $sr $_; @{ N = (& $ui.NameOf $_); Top = $rr.Top; H = $rr.Height; Line = $rr.Top - $_.Margin.Top; Kind = $(if ($ui.Boxes -contains $_) { 'box' } elseif ($_ -is [System.Windows.Forms.Button] -and $_.FlatAppearance.BorderSize -gt 0) { 'button' } else { 'other' }) } })
  }
  # R32: the bottom line's link and its text at the right share one midpoint.
  if ($ui.RecB.Visible -and $ui.RightL.Visible -and [string]$ui.RightL.Text) { $out += & $ui.RowBad $Card 'Bottom' @(@($ui.RecB, $ui.RightL) | ForEach-Object { $rr = & $sr $_; @{ N = (& $ui.NameOf $_); Top = $rr.Top; H = $rr.Height; Line = 0; Kind = 'other' } }) }
  # R29b: the header's two lines start their ink on one edge (no difference allowed), and the step's time and count sit on
  # the bar's midpoint (1 px at any scale) when they are on the bar's line.
  # Returns where a control's ink starts (its left edge plus the measured ink offset: text, edge or drawing). Takes the control.
  $tx = { param($C) (& $sr $C).Left + (& $ui.Ink $C) }
  if ($ui.WordL.Visible -and (& $ui.HeadPair)) { $out += & $ui.HeadBad $Card @{ N = 'WordL'; X = (& $tx $ui.WordL) } @{ N = 'AppL'; X = (& $tx $ui.AppL) } }
  if ($ui.AppUnder -and $ui.WordL.Visible -and (& $ui.HeadPair)) {   # L2: the word, 4 px, the line, 4 px, the name, measured on the ink Windows drew
    $rw = & $sr $ui.WordL; $rr = & $sr $ui.HeadRule; $ra = & $sr $ui.AppL; $wi = & $ui.InkBox $ui.WordL; $ai = & $ui.InkBox $ui.AppL
    $out += & $ui.HeadRuleBad $Card @{ WordBottom = $rw.Top + $wi.Bottom; WordLeft = $rw.Left + $wi.Left; WordW = $wi.Right - $wi.Left; RuleTop = $rr.Top; RuleBottom = $rr.Bottom; RuleLeft = $rr.Left; RuleW = $rr.Width
      AppTop = $(if ([string]$ui.AppL.Text -cmatch '[A-Z0-9bdfhklt]') { $ra.Top + $ai.Top } else { $null }) } (& $ui.Sc $ui.Z.G1) }
  if ($ui.FieldRow.Visible -and $ui.FieldAbove -and -not $ui.RecOn) { $rl = & $sr $ui.FieldL; $rb = & $sr $ui.FieldBox   # L3: the label above its box
    $out += & $ui.AboveBad $Card @{ LabelBottom = $rl.Bottom; BoxTop = $rb.Top; BoxLeft = $rb.Left; BoxW = $rb.Width; Edge = (& $tx $ui.FieldL); TextW = ($ui.ContentW - (& $ui.Sc 10)) } }
  if ($ui.Frame -and -not $ui.RecOn) { $rh = & $sr $ui.Head; $rt = & $sr $ui.Tail; $rc = & $sr $ui.Card   # L1: the header row at the fixed top, the frame at its minimum height at least
    $out += & $ui.FrameBad $Card @{ Top = $rh.Top - $rc.Top; WantTop = $ui.Frame.WantTop; H = $rt.Bottom - $rh.Top; MinH = $ui.Frame.MinH; Moved = $ui.Frame.Moved } }
  if ($ui.StepRow.Visible -and -not $ui.RecOn) { $rb = & $sr $ui.StepBar
    foreach ($l in @($ui.StepTime, $ui.StepFrac)) { $rl = & $sr $l; if (($rl.Top - $l.Margin.Top) -eq ($rb.Top - $ui.StepBar.Margin.Top) -and $rl.Left -gt $rb.Left) { $out += & $ui.TickBad $Card @{ Top = $rb.Top; H = $rb.Height } @{ N = (& $ui.NameOf $l); Top = $rl.Top; H = $rl.Height } } } }
  if (-not $ui.RecOn) {
    $es = @()   # the card column: where each part's ink starts ($tx above)
    if ($ui.Kick.Visible) { $es += @{ N = 'Kick'; X = (& $tx $ui.Kick) } }
    if ($ui.TickP.Visible) { $es += @{ N = 'TickP'; X = (& $tx $ui.TickP) } } elseif ($ui.Sent.Visible -and $ui.Sent.Text) { $es += @{ N = 'Sent'; X = (& $tx $ui.Sent) } }
    foreach ($l in @(@($ui.P) + @($ui.PathL, $ui.PathT, $ui.Close, $ui.StepName, $ui.Now, $ui.FieldL, $ui.Note, $ui.Help, $ui.Foot, $ui.TestL))) { if ($l.Visible -and $l.Text) { $es += @{ N = (& $ui.NameOf $l); X = (& $tx $l) } } }
    if ($ui.Guide.Visible) { $es += @{ N = 'Guide'; X = (& $sr $ui.Guide).Left + (& $ui.GuideInk) } }   # the widest number of the numbered list
    if ($ui.ErrBox.Visible) { $es += @{ N = 'ErrBox'; X = (& $sr $ui.ErrBox).Left } }
    $k1 = @($ui.LinkRow.Controls | Where-Object { $_.Visible })[0]; if ($k1) { $es += @{ N = (& $ui.NameOf $k1); X = (& $tx $k1); D = ('link ink ' + (& $ui.Ink $k1) + ', width ' + $k1.Width + ', margin ' + $k1.Margin.Left + ', row margin ' + $ui.LinkRow.Margin.Left) } }
    $o1 = @($ui.Opts.Controls | Where-Object { $_.Visible })[0]; if ($o1) { $es += @{ N = 'choice 1'; X = (& $sr $o1).Left } }
    $b1 = @($ui.B | Where-Object { $_.Visible })[0]; if ($b1) { $es += @{ N = (& $ui.NameOf $b1); X = (& $tx $b1) } }
    $out += & $ui.EdgeBad $Card $es
  }
  return $out }
$ui.Scale = {
  # The scaling facts, numbers only (R24: the screen dpi said 100 % while every size was 1.5 x). DeviceDpi exists from .NET 4.7.
  try { $f = $ui.Form; $dd = 'n/a'; try { $pp = $f.GetType().GetProperty('DeviceDpi'); if ($pp) { $dd = [string]$pp.GetValue($f, $null) } } catch { $null = $_ }
    $as = $f.CurrentAutoScaleDimensions; $sn = [System.Windows.Forms.Screen]::FromControl($f)
    # The process dpi awareness, read from Windows Forms itself (its internal DpiHelper, .NET 4.7+); no native call: that
    # would need C# compiled on the work computer. PerMonitorV2 with dpiX 96 and autoScale 144 is the R24 case.
    $aw = 'n/a'; try { $dh = $f.GetType().Assembly.GetType('System.Windows.Forms.DpiHelper'); if ($dh) { $bf = [System.Reflection.BindingFlags]'NonPublic, Public, Static'; $pm = $dh.GetProperty('IsPerMonitorV2Awareness', $bf)
        if ($pm) { $aw = $(if ([bool]$pm.GetValue($null, $null)) { 'PerMonitorV2' } else { 'not-PerMonitorV2' }) } } } catch { $null = $_ }
    $sd = $f.AutoScaleDimensions; $rd = 'n/a'; try { if ($script:native -and $f.IsHandleCreated) { $rd = [string][Rade.Native]::GetDpiForWindow($f.Handle) } } catch { $null = $_ }
    $lg = $(if ($ui.Logo) { [string]$ui.Logo.Width + 'x' + $ui.Logo.Height } else { 'n/a' }); $b1 = @($ui.B | Where-Object { $_.Visible })[0]; $bt = $(if ($b1) { [string]$b1.Width + 'x' + $b1.Height } else { 'n/a' })
    return ('SCALE dpiX=' + [int]$ui.ScreenDpi + ' deviceDpi=' + $dd + ' mode=' + [string]$f.AutoScaleMode + ' asd=' + [int]$sd.Width + 'x' + [int]$sd.Height + ' autoScale=' + [int]$as.Width + 'x' + [int]$as.Height + ' font=' + [int]$f.Font.Height + ' fontPt=' + $f.Font.SizeInPoints + ' fontScale=' + $ui.FontK + ' ctlScale=' + [math]::Round($ui.Dpi / 96.0, 2) + ' realDpi=' + $rd + ' aware=' + $aw + ' screen=' + $sn.Bounds.Width + 'x' + $sn.Bounds.Height +
      ' work=' + $sn.WorkingArea.Width + 'x' + $sn.WorkingArea.Height + ' client=' + $f.ClientSize.Width + 'x' + $f.ClientSize.Height + ' state=' + [string]$f.WindowState + ' logo=' + $lg + ' btn=' + $bt + ' shown=' + $(if ($ui.ShownAt) { $ui.ShownAt } else { 'n/a' }) + ' placed=' + $ui.Placed + ' lastClose=' + $(if ($ui.LastClose) { $ui.LastClose } else { 'n/a' }))
  } catch { return ('SCALE could not be read: ' + (ConvertTo-Masked ([string]$_.Exception.Message))) } }
# Gives the result of the layout self-check: its pass line, or the defects found, with the window size and scale. Takes
# nothing; gives back the text.
$ui.LayLine = {
  & $ui.Check
  $pct = [int][math]::Round($ui.Dpi / 96.0 * 100); $sp = [int][math]::Round($ui.ScreenDpi / 96.0 * 100)   # the form's scale (the one source); the screen dpi beside it when it differs
  $size = [string]$ui.Form.ClientSize.Width + ' x ' + $ui.Form.ClientSize.Height + ' at ' + [string]$pct + ' %' + $(if ($sp -ne $pct) { ' (the form auto-scale; the screen dpi says ' + $sp + ' %)' } else { '' })
  $sc = $(if ($ui.LayScroll.Count) { '; the text scrolls on: ' + ((@($ui.LayScroll.Keys) | Sort-Object) -join ', ') } else { '' })
  if ($ui.LayBad.Count) { return ('Layout self-check: ' + $ui.LayBad.Count + ' defects in ' + $ui.LayCards.Count + ' cards (' + $size + ')' + $sc + "`r`n" + (& $ui.Scale) + "`r`n" + (@($ui.LayBad) -join "`r`n")) }
  return ('Layout self-check: PASS layout, ' + $ui.LayCards.Count + ' cards (' + $size + ')' + $sc + "`r`n" + (& $ui.Scale)) }
# Sets a label's text and shows it only when the text is not empty. Takes the label and the text; gives back nothing.
$ui.Show = { param($C, [string]$Text) $C.Text = $Text; $C.Visible = [bool]$Text }
$ui.SetCard = { param($c)
  # Shows one card. $c names the parts: View, Light ('you' = yellow, 'bad' = dark red), Kicker, Sentence, Tick, P (up to 4
  # paragraphs), Options + OnOption, Lines (guide lines, in order: numbered ones first, others after them; one selectable text), Path (a file path), StepRow, Field (Label, Text, Name, Button, Do, Max, Above), Err, Links, Note, Help, Close (the hand card's closing line),
  # Buttons (Text, Kind, Do, Apart; up to $ui.NB), Foot, Test, Right, Back, NoAccept, Focus ('field', 'fieldbutton', 'err' or 'text').
  & $ui.Check   # the card that goes away (test rounds only)
  $ui.Hot = $null; $ui.Down = $null   # no hover or pressed state is carried over (R4 review)
  if ($ui.RecOn -and ($c.Light -or $c.View -eq 'done')) { $ui.RecOn = $false; $ui.Rec.Visible = $false; $ui.Card.Visible = $true; $ui.RecB.Visible = $true }   # a card that needs you closes the Record
  $ui.View = [string]$c.View; $ui.Card.SuspendLayout()
  $ui.Light.BackColor = $(if ($c.Light -eq 'you') { $ui.C.Yellow } elseif ($c.Light -eq 'bad') { $ui.C.Red } else { $ui.C.White })
  $ui.Light.AccessibleName = 'Status light: ' + $(if ($c.Light -eq 'you') { 'your turn' } elseif ($c.Light -eq 'bad') { 'failed' } else { 'off' })
  & $ui.Show $ui.Kick ([string]$c.Kicker).ToUpperInvariant()
  $ui.SentRaw = [string]$c.Sentence; $ui.Sent.Text = $ui.SentRaw; $ui.TickP.Visible = [bool]$c.Tick
  $ps = @($c.P | Where-Object { $_ }); for ($k = 0; $k -lt 4; $k++) { & $ui.Show $ui.P[$k] $(if ($k -lt $ps.Count) { [string]$ps[$k] } else { '' }) }
  $ui.OnOpt = $c.OnOption; & $ui.FillOpts $c.Options; $ui.Opts.Visible = [bool]$ui.Opts.Controls.Count
  & $ui.SetSteps $c.Lines
  $ui.PathL.Visible = [bool]$c.Path; & $ui.Show $ui.PathT ([string]$c.Path)
  $ui.StepRow.Visible = [bool]$c.StepRow; $ui.NowRaw = ''; $ui.Now.Text = ''; $ui.Now.Visible = [bool]$c.StepRow; if ($c.StepRow) { $ui.StepTime.Text = '' }   # the run card keeps the now-doing room, empty until a text comes
  $ui.FieldRow.Visible = [bool]$c.Field; $ui.FieldDo = $null
  $ui.FieldAbove = [bool]($c.Field -and $c.Field.Above); try { $ui.FieldRow.SetFlowBreak($ui.FieldL, $ui.FieldAbove) } catch { $null = $_ }   # L3: the box goes under its label
  if ($c.Field) { $ui.FieldL.Text = [string]$c.Field.Label; $ui.Field.Text = [string]$c.Field.Text; $ui.Field.AccessibleName = [string]$c.Field.Name; $ui.FieldB.Visible = [bool]$c.Field.Button; $ui.FieldBOn = [bool]$c.Field.Button; $ui.FieldB.Text = [string]$c.Field.Button; $ui.FieldDo = $c.Field.Act; $ui.Field.MaxLength = $(if ($c.Field.Max) { [int]$c.Field.Max } else { 32767 }); & $ui.FitRow }
  $ui.ErrRow.Visible = [bool]$c.Err; if ($c.Err) { $ui.ErrBox.Text = '' }
  $ui.LinkRow.Visible = [bool]($c.Links -or $c.PageLink); $ui.CopyPathB.Visible = [bool]$c.Links; $ui.ShowFileB.Visible = [bool]$c.Links; $ui.PageB.Visible = [bool]$c.PageLink
  & $ui.Show $ui.Note ([string]$c.Note); & $ui.Show $ui.Help ([string]$c.Help); & $ui.Show $ui.Foot ([string]$c.Foot); & $ui.Show $ui.Close ([string]$c.Close)
  $bm = & $ui.Sc $(if ($c.Close) { $ui.Z.G2 - $ui.Z.M } else { $ui.Z.G4 - $ui.Z.M }); $bn = $ui.BtnRow.Margin; if ($bn.Top -ne $bm) { $ui.BtnRow.Margin = New-Object System.Windows.Forms.Padding($bn.Left, $bm, $bn.Right, $bn.Bottom) }   # 8 under the closing line, else 16
  $bs = @($c.Buttons | Where-Object { $_ }); $ui.Acts = @(); $first = $null; $accept = $null; $ui.BOn = @($false) * $ui.NB; $ui.BApart = @($false) * $ui.NB; $ui.Always = @($false) * $ui.NB
  for ($k = 0; $k -lt $ui.NB; $k++) {
    $b = $ui.B[$k]
    if ($k -lt $bs.Count) {
      $b.Text = [string]$bs[$k].Text; & $ui.Style $b ([string]$bs[$k].Kind); $b.Visible = $true; $ui.Acts += $bs[$k].Act; $ui.BOn[$k] = $true; $ui.BApart[$k] = [bool]$bs[$k].Apart; $ui.Always[$k] = [bool]$bs[$k].Always
      if ($b.Enabled -and -not $first) { $first = $b }; if ($b.Enabled -and -not $accept -and $bs[$k].Kind -eq 'primary') { $accept = $b }
    } else { $b.Visible = $false; $ui.Acts += $null }
  }
  & $ui.Apart
  $ui.BtnRow.Visible = [bool]$bs.Count
  $ui.TestRow.Visible = [bool]$c.Test
  $ui.Form.AcceptButton = $(if ($c.NoAccept) { $null } else { $accept })   # Enter = the primary button, except on a hand step
  $ui.CardNow = $c; $ui.TourB.Visible = ($ui.HelpViews -contains [string]$c.View -and -not $ui.RecOn)   # L6: Help on a card that can be shown again
  $ui.Back = $c.Back; $ui.BackB.Visible = ([bool]$c.Back -and -not $ui.RecOn); $ui.RightL.Text = $(if ($c.Right) { [string]$c.Right } elseif ($c.Light -eq 'you') { $ui.Words.You } else { '' })   # L5: a card that waits for the person says "Your turn."
  & $ui.FitSent; & $ui.FitEdges; & $ui.AlignRows
  $ui.Card.ResumeLayout(); try { $ui.Card.PerformLayout() } catch { $null = $_ }
  if ($ui.Guide.Visible) { try { $ui.Guide.Refresh() } catch { $null = $_ }; & $ui.GuideFit; & $ui.FitEdges }   # the rich text box finishes its layout when it paints: paint it (no message pump), then measure its edge again (R28 job: 4 to 13 px off on the first hand card)
  try { $ui.Scroll.AutoScrollPosition = New-Object System.Drawing.Point(0, 0) } catch { $null = $_ }; & $ui.Squeeze   # a new card starts at its top
  $f = $null
  if ($c.Focus -eq 'field') { $f = $ui.Field } elseif ($c.Focus -eq 'fieldbutton') { $f = $ui.FieldB } elseif ($c.Focus -eq 'err') { $f = $ui.ErrBox } elseif ($c.Focus -eq 'text') { $f = $(if ($ui.Guide.Visible) { $ui.Guide } else { $ui.Sent }) }   # a card with no box: the focus on its text, so Enter answers nothing
  elseif ($ui.Opts.Controls.Count) { foreach ($o in @($ui.Opts.Controls)) { if (-not $o.Tag.Off) { $f = $o; break } } }
  if (-not $f) { $f = $accept }; if (-not $f) { $f = $first }; if (-not $f) { $f = $ui.RecB }
  if (-not $ui.RecOn) { try { [void]$f.Focus() } catch { $null = $_ } }
  # The guard counts from here, when the card is built and the person can see it (M2 review): a click that waited in the
  # queue while the card was built comes in during this DoEvents, inside the guard, and is dropped.
  $ui.CardAt = $ui.Clock.Elapsed.TotalMilliseconds
  [System.Windows.Forms.Application]::DoEvents() }
# Brings the window to the front (restores it when minimized) without keeping it on top.
$ui.ToFront = { try { if ([string]$ui.Form.WindowState -eq 'Minimized') { $ui.Form.WindowState = 'Normal' }; $ui.Form.TopMost = $true; $ui.Form.Activate(); $ui.Form.TopMost = $false } catch { $null = $_ } }
# Shows one gray line under the card's box or buttons, or hides it for empty text. Takes the text.
$ui.Say1 = { param([string]$Text) $ui.Note.Text = $Text; $ui.Note.Visible = [bool]$Text }   # one gray line under the card's box or buttons

