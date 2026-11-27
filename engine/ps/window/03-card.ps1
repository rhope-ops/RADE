# RADE window part 03, the card: the one block that shows a statement or a question, with its parts (line,
# sentence, paragraphs, choices, box, hand-step text, step line, buttons) and the one-line text box helper.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# ---- The card: one block, its text column centered (76.5 % of the width, at most 680 px: engine/window.json), 40 % of the spare height above it. Top to bottom: a small
# line in capitals (the header row), the sentence, up to four paragraphs, the choices, a box with its label, the lines of a hand step (one
# selectable text: the numbered lines, then the unnumbered ones), the file path of a hand step, the step line (name, bar,
# time in the step, count), the last log line, the error box, two file links, a note, the help line, the closing line of
# a hand step, the buttons, a last gray line, and the owner's test extras. A card shows only the parts it names ($ui.SetCard).
$ui.Card = New-Object System.Windows.Forms.TableLayoutPanel
$ui.Card.Dock = 'Fill'; $ui.Card.ColumnCount = 3; $ui.Card.RowCount = 3; $ui.Card.BackColor = $ui.C.White
# Three columns: a side, the text column, a side. The text column is $ui.Layout.Share % of the width and at most $ui.Layout.MaxW
# (engine/window.json); the two sides share what is left, so the column is centered ($ui.Fit sets the sizes).
$ui.CardCols = @(); $sd = (100 - $ui.Layout.Share) / 2
foreach ($w in @($sd, $ui.Layout.Share, $sd)) { $cs = New-Object System.Windows.Forms.ColumnStyle('Percent', $w); $ui.CardCols += $cs; [void]$ui.Card.ColumnStyles.Add($cs) }
# Three rows: the room above the frame (a fixed height, set by $ui.Squeeze), the frame, the rest (L1, the Administrator, 2026-11-19).
$ui.CardRows = @((New-Object System.Windows.Forms.RowStyle('Absolute', 0)), (New-Object System.Windows.Forms.RowStyle('AutoSize')), (New-Object System.Windows.Forms.RowStyle('Percent', 100))); foreach ($rs in $ui.CardRows) { [void]$ui.Card.RowStyles.Add($rs) }
# The card frame (L1, the Administrator, 2026-11-19): its top is fixed (40 % of the spare height above a frame of
# $ui.Layout.FrameMin, engine/window.json), it is that tall at least and grows down to the bottom line at most. It is a
# stack of four: the header row (the line in capitals, "Step x of n": it never scrolls and never moves), the body, a gap
# that fills a short card up to the minimum height, and the tail, so the buttons sit at the bottom of the frame.
# The card is a stack: the body (every part above the buttons) and the tail (the buttons, the last gray line
# and the test extras). The body sits in a panel that scrolls only when the card is taller than the window, so the
# buttons are always in view (the Administrator, 2026-11-15; $ui.Squeeze). No scroll at 1020 x 616 and larger.
$ui.MkStack = { $t = New-Object System.Windows.Forms.TableLayoutPanel; $t.AutoSize = $true; $t.AutoSizeMode = 'GrowAndShrink'; $t.ColumnCount = 1; $t.Margin = (& $ui.Pad 0 0 0 0); $t.BackColor = $ui.C.White
  [void]$t.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize'))); $t }
$ui.Stack = & $ui.MkStack; $ui.Stack.Anchor = 'Top, Left'; $ui.Body = & $ui.MkStack; $ui.Tail = & $ui.MkStack
$ui.Scroll = New-Object System.Windows.Forms.Panel
$ui.Scroll.AutoScroll = $true; $ui.Scroll.Margin = (& $ui.Pad 0 0 0 0); $ui.Scroll.BackColor = $ui.C.White; $ui.Scroll.AccessibleName = 'Card text'
$ui.Body.Location = New-Object System.Drawing.Point(0, 0); [void]$ui.Scroll.Controls.Add($ui.Body)
$ui.Kick = & $ui.Text $ui.F.SmallB $ui.C.Gray 0 'Card line'; $ui.Kick.Visible = $true; $ui.MinLines[$ui.Kick] = 1   # one line tall also when the card has no line
# The YOUR TURN chip (plan engine-v48 step 3; critique change 1, the PFM, 2026-11-27): on a card where RADE waits for the
# person (the yellow light), a yellow chip "YOUR TURN" stands before the line in capitals; the separate "Your turn" line of
# R35 is gone. Yellow means only this (and the light line).
$ui.Chip = & $ui.Label $ui.F.SmallB $ui.C.OnYellow 0; $ui.Chip.BackColor = $ui.C.Yellow; $ui.Chip.Text = 'YOUR TURN'; $ui.Chip.AccessibleName = 'Your turn'
$ui.Chip.Padding = (& $ui.Pad $ui.Z.G2 $ui.Z.G1 $ui.Z.G2 $ui.Z.G1); $ui.Chip.Margin = (& $ui.Pad 0 0 $ui.Z.G3 0)
# The header row: the chip (on your turn), then the line in capitals, on one line. It never scrolls and never moves.
$ui.Head = & $ui.Flow 0; $ui.Head.Visible = $true; $ui.Head.AccessibleName = 'Card header'
[void]$ui.Head.Controls.Add($ui.Chip); [void]$ui.Head.Controls.Add($ui.Kick)
$ui.Gap = New-Object System.Windows.Forms.Panel; $ui.Gap.Size = New-Object System.Drawing.Size(1, 0); $ui.Gap.Margin = (& $ui.Pad 0 0 0 0); $ui.Gap.BackColor = $ui.C.White; $ui.Gap.Visible = $false
$ui.SentRow = & $ui.Flow $ui.Z.G1; $ui.SentRow.Visible = $true
$ui.TickP = New-Object System.Windows.Forms.Panel
$ui.TickP.Size = New-Object System.Drawing.Size(30, 30); $ui.TickP.Margin = (& $ui.Pad 0 9 12 0); $ui.TickP.Visible = $false; $ui.TickP.AccessibleRole = 'StaticText'; $ui.TickP.AccessibleName = 'Passed'
$ui.TickP.Add_Paint({ try { $g = $_.Graphics; $g.SmoothingMode = 'AntiAlias'; $w = $this.ClientSize.Width; $pn = New-Object System.Drawing.Pen($ui.C.Green, [single]($w * 0.14)); $pn.StartCap = 'Round'; $pn.EndCap = 'Round'
  $g.DrawLines($pn, [System.Drawing.PointF[]]@((New-Object System.Drawing.PointF([single](0.16 * $w), [single](0.54 * $w))), (New-Object System.Drawing.PointF([single](0.40 * $w), [single](0.76 * $w))), (New-Object System.Drawing.PointF([single](0.84 * $w), [single](0.26 * $w))))); $pn.Dispose() } catch { $null = $_ } })
$ui.Sent = & $ui.Text $ui.F.Sent $ui.C.Navy 0 'Card headline'; $ui.Sent.Visible = $true
[void]$ui.SentRow.Controls.Add($ui.TickP); [void]$ui.SentRow.Controls.Add($ui.Sent)
$ui.P = @(); foreach ($k in 0..3) { $ui.P += (& $ui.Text $ui.F.Body $ui.C.Navy $(if ($k) { $ui.Z.G1 } else { $ui.Z.G3 }) ('Card text ' + ($k + 1))) }
$ui.Opts = & $ui.Flow $ui.Z.G6; $ui.Opts.FlowDirection = 'TopDown'; $ui.Opts.AccessibleName = 'Choices'
# The lines of a hand step (R28 N4, the Administrator, 2026-11-17: the text can be selected across many lines): ONE read-only
# rich text box. A numbered line has its number right-aligned in a column and its text, wrapped, in the text column (a
# figure spaces in front of a shorter number, a tab and a hanging indent); a line with no number follows the list, small and gray. Filled by $ui.SetSteps.
$ui.Guide = New-Object System.Windows.Forms.RichTextBox
$ui.Guide.ReadOnly = $true; $ui.Guide.BorderStyle = 'None'; $ui.Guide.ScrollBars = 'None'; $ui.Guide.WordWrap = $true; $ui.Guide.DetectUrls = $false; $ui.Guide.TabStop = $false; $ui.Guide.Multiline = $true
$ui.Guide.BackColor = $ui.C.White; $ui.Guide.ForeColor = $ui.C.Navy; $ui.Guide.Font = $ui.F.Body; $ui.Guide.Margin = (& $ui.Pad 0 $ui.Z.G3 0 0); $ui.Guide.Visible = $false; $ui.Guide.ContextMenuStrip = $ui.Menu; $ui.Guide.AccessibleName = 'Steps to do'
$ui.Guide.Add_ContentsResized({ try { $ui.GuideH = [int]$_.NewRectangle.Height; & $ui.GuideFit } catch { $null = $_ } })
$ui.Guide.Add_GotFocus({ & $ui.NoCaret $this }); $ui.Guide.Add_MouseUp({ & $ui.NoCaret $this }); $ui.Guide.Add_KeyUp({ & $ui.NoCaret $this })
$ui.GuideNums = @(); $ui.GuideTexts = @(); $ui.GuideRest = @(); $ui.GuideH = 0; $ui.GuideInkAt = 0
# The file a hand step made, by its full path (R28 N6: a step that pastes the path from the clipboard shows it, to check it).
$ui.PathL = & $ui.Label $ui.F.SmallB $ui.C.Gray $ui.Z.G3; $ui.PathL.Text = 'File path'
$ui.PathT = & $ui.Text $ui.F.Small $ui.C.Navy $ui.Z.G1 'File path'
# ---- The Run card (plan engine-v48 step 3, Cards v2): one percent and one bar for the whole run, then the step list: the
# steps before the running one ($ui.RunA), the running step ($ui.RunRow), the steps after it ($ui.RunB). The rows of the
# other steps are drawn ($ui.PaintRuns, 07-run.ps1): the name, a second line in 2 lines at most, the status as icon and word.
$ui.PctRow = & $ui.Flow $ui.Z.G3; $ui.PctRow.AccessibleName = 'Progress of the run'
$ui.PctL = & $ui.Label $ui.F.Word $ui.C.Navy 0; $ui.PctL.Visible = $true; $ui.PctL.AccessibleName = 'Percent of the run'; $ui.Most[$ui.PctL] = @('100 %'); $ui.PctL.Add_TextChanged({ & $ui.FixW $this })
$ui.RunBar = & $ui.MkBar 'run' 'Progress of all steps'; $ui.RunBar.Height = 6; $ui.RunBar.Margin = (& $ui.Pad 0 $ui.Z.G1 0 $ui.Z.G3)
[void]$ui.PctRow.Controls.Add($ui.PctL)
# Makes one drawn list of step rows (above or below the running step). Takes the name; gives back the panel.
$ui.MkRuns = { param([string]$Name) $p = New-Object System.Windows.Forms.Panel; $p.Margin = (& $ui.Pad 0 0 0 0); $p.BackColor = $ui.C.White; $p.AccessibleRole = 'StaticText'; $p.AccessibleName = $Name
  $p.Tag = @(); $p.Visible = $false; $p.Add_Paint({ & $ui.PaintRuns $this $_.Graphics }); $p }
$ui.RunA = & $ui.MkRuns 'Steps before this one'; $ui.RunB = & $ui.MkRuns 'Steps after this one'
# The running step: a tinted row with its name and RUNNING at the right, its summary (the step's doing text), its bar with
# the time in the step and the count, and the now-doing line under the bar (2 lines; it wraps).
$ui.RunRow = & $ui.Flow 0; $ui.RunRow.FlowDirection = 'TopDown'; $ui.RunRow.BackColor = $ui.C.Tint; $ui.RunRow.Padding = (& $ui.Pad $ui.Z.G2 $ui.Z.G2 $ui.Z.G2 $ui.Z.G2); $ui.RunRow.AccessibleName = 'The running step'
$ui.RunHead = & $ui.Flow 0; $ui.RunHead.Visible = $true; $ui.RunHead.BackColor = $ui.C.Tint
$ui.StepName = & $ui.Text $ui.F.SmallB $ui.C.Navy 0 'Step name'; $ui.StepName.Visible = $true; $ui.StepName.BackColor = $ui.C.Tint
$ui.RunWord = & $ui.Label $ui.F.SmallB $ui.C.Info 0; $ui.RunWord.Text = 'RUNNING'; $ui.RunWord.Visible = $true; $ui.RunWord.BackColor = $ui.C.Tint; $ui.RunWord.AccessibleName = 'Status: running'
[void]$ui.RunHead.Controls.Add($ui.StepName); [void]$ui.RunHead.Controls.Add($ui.RunWord)
$ui.StepSum = & $ui.Text $ui.F.Small $ui.C.Navy $ui.Z.G1 'What the step does'; $ui.StepSum.BackColor = $ui.C.Tint
$ui.StepRow = & $ui.Flow $ui.Z.G1; $ui.StepRow.Visible = $true; $ui.StepRow.BackColor = $ui.C.Tint
$ui.StepBar = & $ui.MkBar 'step' 'Progress of this step'; $ui.StepBar.Width = 200; $ui.StepBar.Margin = (& $ui.Pad 0 $ui.Z.BarTop $ui.Z.G2 0)
# R28 N10: the time in this step, at the right end of its bar ("4m 12s"), every second ($ui.TimeT). The log keeps "Started".
$ui.StepTime = & $ui.Label $ui.F.Small $ui.C.Gray 2; $ui.StepTime.Visible = $true; $ui.StepTime.AccessibleName = 'Time in this step'; $ui.StepTime.BackColor = $ui.C.Tint
$ui.StepFrac = & $ui.Label $ui.F.Small $ui.C.Gray 2; $ui.StepFrac.Visible = $true; $ui.StepFrac.Margin = (& $ui.Pad $ui.Z.G3 2 0 0); $ui.StepFrac.BackColor = $ui.C.Tint
# The time ("4m 12s", "1h 04m 12s") and the count ("3 of 12") keep one size from their widest value ($ui.FixW), so the bar
# beside them never changes its width as they count (the Administrator, 2026-11-19).
$ui.Most[$ui.StepTime] = @('9h 59m 59s'); $ui.Most[$ui.StepFrac] = @('999 of 999')
foreach ($c in @($ui.StepTime, $ui.StepFrac)) { $c.Add_TextChanged({ & $ui.FixW $this }) }
foreach ($c in @($ui.StepBar, $ui.StepTime, $ui.StepFrac)) { [void]$ui.StepRow.Controls.Add($c) }
# The now-doing line (L7, the Administrator, 2026-11-19): what the running step does now ($ui.ShowNow). It has a fixed room
# of $ui.NowLines lines, shown also with no text, so Cancel under it never moves; a text wraps to those 2 lines (Cards v2).
$ui.Now = & $ui.Text $ui.F.Small $ui.C.Gray $ui.Z.G1 'Now doing'; $ui.Now.BackColor = $ui.C.Tint; $ui.Now.Visible = $true
$ui.NowLines = 2; $ui.Hold[$ui.Now] = $ui.NowLines
foreach ($c in @($ui.RunHead, $ui.StepSum, $ui.StepRow, $ui.Now)) { [void]$ui.RunRow.Controls.Add($c) }
# The WHAT TO DO box of the step-failed card (Cards v2): a 1 px edge around the label and the text.
$ui.Todo = & $ui.Flow $ui.Z.G3; $ui.Todo.FlowDirection = 'TopDown'; $ui.Todo.Padding = (& $ui.Pad $ui.Z.G3 $ui.Z.G2 $ui.Z.G3 $ui.Z.G2); $ui.Todo.AccessibleName = 'What to do'
$ui.TodoL = & $ui.Label $ui.F.SmallB $ui.C.Gray 0; $ui.TodoL.Text = 'WHAT TO DO'; $ui.TodoL.Visible = $true
$ui.TodoT = & $ui.Text $ui.F.Body $ui.C.Navy $ui.Z.G1 'What to do'; $ui.TodoT.Visible = $true
[void]$ui.Todo.Controls.Add($ui.TodoL); [void]$ui.Todo.Controls.Add($ui.TodoT)
$ui.Todo.Add_Paint({ try { $pn = New-Object System.Drawing.Pen($ui.C.Edge); $_.Graphics.DrawRectangle($pn, 0, 0, ($this.ClientSize.Width - 1), ($this.ClientSize.Height - 1)); $pn.Dispose() } catch { $null = $_ } })   # no edge drawn: the box still shows its text
$ui.FieldRow = & $ui.Flow $ui.Z.G2; $ui.FieldRow.WrapContents = $true; & $ui.Ring $ui.FieldRow
$ui.FieldL = & $ui.Label $ui.F.SmallB $ui.C.Gray 9; $ui.FieldL.Visible = $true
# A one-line box: a frame as tall as a compact button with RADE's own 1 px edge, the text box inside it with no border,
# in the middle (a text box cannot be made taller with its text in the middle). The ring goes around the frame.
$ui.Boxes = @()
# Sizes and centers the text box inside its one-line frame. Takes the frame panel; does nothing before the window has
# its scale; gives back nothing.
# The text box is one line of its font tall, as Windows draws the text ($ui.LineH; R35: a box that sized itself was 27 high
# where a line needs 32 at 150 %), and never taller than the frame inside its edge.
$ui.BoxFit = { param($P) if (-not $ui.Scaled) { return }
  try { $tb = $P.Controls[0]; $in = & $ui.Sc 6; $h = [math]::Max(1, [math]::Min((& $ui.LineH $tb.Font), ($P.ClientSize.Height - (& $ui.Sc 2)))); if ($tb.Height -ne $h) { $tb.Height = $h }
    $tb.Width = [math]::Max(10, $P.ClientSize.Width - 2 * $in); $tb.Location = New-Object System.Drawing.Point($in, [int][math]::Floor(($P.ClientSize.Height - $tb.Height) / 2)) } catch { $null = $_ } }
# Wraps a text box in a one-line frame with its own 1 px edge and a focus ring. Takes the text box and the frame width;
# gives back the frame panel and remembers it in $ui.Boxes.
$ui.MkBox = { param($Tb, [int]$W)
  $p = New-Object System.Windows.Forms.Panel; $p.Size = New-Object System.Drawing.Size($W, $ui.Z.CompactH); $p.BackColor = $ui.C.White; $p.AccessibleName = 'Text box'
  $Tb.BorderStyle = 'None'; $Tb.AutoSize = $false; $Tb.Font = $ui.F.Small; $Tb.ForeColor = $ui.C.Ink
  $Tb.BackColor = $ui.C.White; [void]$p.Controls.Add($Tb); $Tb.Add_GotFocus({ try { $this.Parent.Parent.Invalidate() } catch { $null = $_ } }); $Tb.Add_LostFocus({ try { $this.Parent.Parent.Invalidate() } catch { $null = $_ } })
  $p.Add_Paint({ try { $pn = New-Object System.Drawing.Pen($ui.C.Edge); $_.Graphics.DrawRectangle($pn, 0, 0, ($this.ClientSize.Width - 1), ($this.ClientSize.Height - 1)); $pn.Dispose() } catch { $null = $_ } })
  $p.Add_SizeChanged({ & $ui.BoxFit $this }); $p.Add_Click({ try { [void]$this.Controls[0].Focus() } catch { $null = $_ } }); $ui.Boxes += $p; $p }
$ui.Field = New-Object System.Windows.Forms.TextBox
$ui.FieldBox = & $ui.MkBox $ui.Field $ui.Z.FieldM; $ui.FieldBox.Margin = (& $ui.Pad $ui.Z.G2 $ui.Z.M $ui.Z.M $ui.Z.M)   # 8 from the label; 4 + the button's 4 = 8 to the button
$ui.FieldB = & $ui.Btn 'compact'
$ui.FieldB.Add_Click({ if ($ui.FieldDo) { & $ui.FieldDo } })
foreach ($c in @($ui.FieldL, $ui.FieldBox, $ui.FieldB)) { [void]$ui.FieldRow.Controls.Add($c) }
$ui.ErrRow = & $ui.Flow $ui.Z.G2; & $ui.Ring $ui.ErrRow
$ui.ErrBox = New-Object System.Windows.Forms.TextBox
$ui.ErrBox.Multiline = $true; $ui.ErrBox.ScrollBars = 'Vertical'; $ui.ErrBox.Size = New-Object System.Drawing.Size($ui.Z.FieldL, 96)
$ui.ErrBox.Margin = (& $ui.Pad 4 4 4 4); $ui.ErrBox.BorderStyle = 'FixedSingle'; $ui.ErrBox.Font = $ui.F.Small; $ui.ErrBox.ForeColor = $ui.C.Ink; $ui.ErrBox.BackColor = $ui.C.White; $ui.ErrBox.AccessibleName = 'Error message'; & $ui.Cue $ui.ErrBox
[void]$ui.ErrRow.Controls.Add($ui.ErrBox)
$ui.LinkRow = & $ui.Flow 0; $ui.LinkRow.WrapContents = $true; $ui.LinkRow.Margin = (& $ui.Pad (-$ui.Z.M) 0 0 0); & $ui.Ring $ui.LinkRow
$ui.CopyPathB = & $ui.LinkBtn 'Copy file path'; $ui.ShowFileB = & $ui.LinkBtn 'Show file in folder'; $ui.PageB = & $ui.LinkBtn 'Open the RADE page'
$ui.PageB.AccessibleName = 'Open the RADE page in your browser'; $ui.PageB.Visible = $false
foreach ($c in @($ui.CopyPathB, $ui.ShowFileB, $ui.PageB)) { [void]$ui.LinkRow.Controls.Add($c) }
$ui.Note = & $ui.Text $ui.F.Small $ui.C.Gray $ui.Z.G2 'Note'
$ui.Help = & $ui.Text $ui.F.Body $ui.C.Navy $ui.Z.G4 'Help'
$ui.Close = & $ui.Text $ui.F.Small $ui.C.Gray $ui.Z.G4 'Closing line'   # the hand card's closing line, directly above the buttons ($ui.VHand)
$ui.BtnRow = & $ui.Flow $ui.Z.G4; $ui.BtnRow.WrapContents = $true; $ui.BtnRow.Margin = (& $ui.Pad (-$ui.Z.M) ($ui.Z.G4 - $ui.Z.M) 0 0); & $ui.Ring $ui.BtnRow   # the buttons' own 4 px margin is part of the 16 px gap
[void]$ui.BtnRow.Controls.Add($ui.BackB)   # B6: Back (Esc) first, at the left end
$ui.B = @(); foreach ($k in 0..($ui.NB - 1)) { $b = & $ui.Btn 'action'; $b.Tag = $k; $b.Add_Click({ $a = $ui.Acts[[int]$this.Tag]; if ($a -and (-not $ui.Busy -or $ui.Always[[int]$this.Tag]) -and (& $ui.Settled)) { & $a } }); $ui.B += $b; [void]$ui.BtnRow.Controls.Add($b) }
$ui.Foot = & $ui.Text $ui.F.Small $ui.C.Gray ($ui.Z.G6 - $ui.Z.M) 'Last line'
# The owner's test extras (test rounds only; they go away with the test branch): the results address, the e-mail draft
# and "the window displayed correctly". A deploy never shows them: it sends nothing.
$ui.TestRow = & $ui.Flow ($ui.Z.G6 - $ui.Z.M); $ui.TestRow.WrapContents = $true; & $ui.Ring $ui.TestRow
$ui.TestL = & $ui.Label $ui.F.SmallB $ui.C.Gray 10; $ui.TestL.Text = 'Test rounds only'; $ui.TestL.Visible = $true
$ui.ToBox = New-Object System.Windows.Forms.TextBox
$ui.ToBox.AccessibleName = 'Send results to (e-mail)'; $ui.ToBoxF = & $ui.MkBox $ui.ToBox $ui.Z.FieldS; $ui.ToBoxF.Margin = (& $ui.Pad $ui.Z.G2 $ui.Z.M $ui.Z.M $ui.Z.M)
$ui.DraftB = & $ui.LinkBtn 'Make e-mail draft'
$ui.OkBox = New-Object System.Windows.Forms.CheckBox
$ui.OkBox.AutoSize = $true; $ui.OkBox.Checked = $true; $ui.OkBox.Text = 'The window displayed correctly'; $ui.OkBox.ForeColor = $ui.C.Gray; $ui.OkBox.Margin = (& $ui.Pad 4 9 4 4); $ui.OkBox.AccessibleName = 'The window displayed correctly (nothing overlapped or cut off)'
foreach ($c in @($ui.TestL, $ui.ToBoxF, $ui.DraftB, $ui.OkBox)) { [void]$ui.TestRow.Controls.Add($c) }
# Puts controls into a table as one auto-sized row each, top to bottom. Takes the table and the list of controls; sets
# the row count; gives back nothing.
$ui.Fill = { param($T, $Parts) $row = 0; foreach ($c in @($Parts)) { [void]$T.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))); $T.Controls.Add($c, 0, $row); $row++ }; $T.RowCount = $row }
& $ui.Fill $ui.Body @($ui.SentRow, $ui.P[0], $ui.P[1], $ui.P[2], $ui.P[3], $ui.Opts, $ui.FieldRow, $ui.Guide, $ui.PathL, $ui.PathT, $ui.PctRow, $ui.RunBar, $ui.RunA, $ui.RunRow, $ui.RunB,
  $ui.ErrRow, $ui.Todo, $ui.LinkRow, $ui.Note, $ui.Help)
$i = 0; foreach ($x in @($ui.BtnRow.Controls)) { $x.TabIndex = $i; $i++ }   # Tab goes along the row from the left: Back (Esc) first, the primary last (B3, B6)
& $ui.Fill $ui.Tail @($ui.Close, $ui.BtnRow, $ui.Foot, $ui.TestRow)
& $ui.Fill $ui.Stack @($ui.Head, $ui.Scroll, $ui.Gap, $ui.Tail)
$ui.Card.Controls.Add($ui.Stack, 1, 1); $ui.Card.SetColumnSpan($ui.Stack, 2)   # two columns: room for the scroll bar beside the text

# ---- What a card shows around its text (plan engine-v48 steps 2 to 4; $ui.SetCard calls these)
# Esc (Cards v2; critique change 4, the PFM, 2026-11-27): Back only on Choose, Maintenance and the not-installed card, and
# on the Run card Esc opens the Cancel question. Your turn and Done take no Esc; the Back of another card is a plain "Back".
$ui.EscViews = @('choose', 'maint', 'notinst')
$ui.Dress = {
  <#
  .SYNOPSIS
  Sets the parts of a card that are not its text: the light line, the stage now, the YOUR TURN chip, the color of the line
  in capitals and the parts of the Run and step-failed cards.
  .PARAMETER C
  The card (the hashtable of $ui.SetCard): Light ('you', 'bad' or 'pass'), KickColor (a token name), StepRow, Todo.
  .OUTPUTS
  Nothing.
  #>
  param($C)
  & $ui.SetLight ([string]$C.Light); & $ui.SetStage ([string]$C.View) ([string]$C.Light -eq 'pass')
  $ui.Chip.Visible = ([string]$C.Light -eq 'you'); $ui.Kick.ForeColor = $(if ($C.KickColor) { $ui.C[[string]$C.KickColor] } else { $ui.C.Gray })
  if ($ui.Scaled) { & $ui.SetWrap $ui.Kick ([int]$ui.ContentW - $(if ($ui.Chip.Visible) { [int]$ui.Chip.PreferredSize.Width + (& $ui.Sc $ui.Z.G3) } else { 0 })) }   # the line in capitals beside the chip
  foreach ($x in @($ui.PctRow, $ui.RunBar, $ui.RunRow)) { $x.Visible = [bool]$C.StepRow }
  if (-not $C.StepRow) { $ui.RunA.Visible = $false; $ui.RunB.Visible = $false }
  $ui.Todo.Visible = [bool]$C.Todo; $ui.TodoT.Text = [string]$C.Todo
  $ui.P[0].Font = $(if ($C.Strong) { $ui.F.Turn } else { $ui.F.Body }) }   # the Done card's summary line is strong
# Says whether a button text fits the widest button (B1: 240 x 40) with the button's padding, as $ui.BtnSize measures it. A
# main button whose text with " (Enter)" does not fit keeps its text alone (Enter still selects it). Takes the text.
$ui.KeyFits = { param([string]$T) try { return ([int][System.Windows.Forms.TextRenderer]::MeasureText($T, $ui.F.SmallB).Width + (& $ui.Sc (2 * $ui.Z.G2)) -le (& $ui.Sc $ui.Z.WideW)) } catch { return $true } }   # no measure: the key shows
$ui.SetButtons = {
  <#
  .SYNOPSIS
  Fills the action row of a card: the primary button last (B3, B4) with its key in its text ("Done (Enter)"), Back at the
  left end ("Back (Esc)" where Esc does Back), and Enter on the primary unless the card says NoAccept.
  .PARAMETER C
  The card: Buttons (Text, Kind, Act, Always; up to $ui.NB), Back, NoAccept.
  .OUTPUTS
  Nothing. Sets $ui.Acts, $ui.BOn, $ui.BMain, $ui.Always, $ui.Back, $ui.BackOn, $ui.First, $ui.Accept and the AcceptButton.
  #>
  param($C)
  $bs = @(@($C.Buttons | Where-Object { $_ -and [string]$_.Kind -ne 'primary' }) + @($C.Buttons | Where-Object { $_ -and [string]$_.Kind -eq 'primary' }))
  $ui.Acts = @(); $ui.First = $null; $ui.Accept = $null; $ui.BOn = @($false) * $ui.NB; $ui.BMain = @($false) * $ui.NB; $ui.Always = @($false) * $ui.NB
  $ui.Back = $C.Back; $ui.BackOn = ([bool]$C.Back -and -not $ui.RecOn); $ui.BackB.Visible = $ui.BackOn   # B6: Back at the left end of the action row
  $ui.BackB.Text = $(if ($ui.EscViews -contains [string]$C.View) { 'Back (Esc)' } else { 'Back' })
  for ($k = 0; $k -lt $ui.NB; $k++) {
    $b = $ui.B[$k]
    if ($k -ge $bs.Count) { $b.Visible = $false; $ui.Acts += $null; continue }
    $main = ([string]$bs[$k].Kind -eq 'primary'); $key = $(if ($main -and -not $C.NoAccept -and (& $ui.KeyFits ([string]$bs[$k].Text + ' (Enter)'))) { ' (Enter)' } else { '' })
    $b.Text = [string]$bs[$k].Text + $key; & $ui.Style $b ([string]$bs[$k].Kind); $b.Visible = $true; $ui.Acts += $bs[$k].Act; $ui.BOn[$k] = $true; $ui.BMain[$k] = $main; $ui.Always[$k] = [bool]$bs[$k].Always
    if ($b.Enabled -and -not $ui.First) { $ui.First = $b }; if ($b.Enabled -and -not $ui.Accept -and $main) { $ui.Accept = $b } }
  & $ui.Apart
  $ui.BtnRow.Visible = [bool]($bs.Count -or $ui.BackOn)
  $ui.Form.AcceptButton = $(if ($C.NoAccept) { $null } else { $ui.Accept }) }   # Enter = the primary button ("(Enter)" in its text)
