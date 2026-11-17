# ---- The card: one block, left edge at 12 % of the width, 40 % of the spare height above it. Top to bottom: a small
# line in capitals, the sentence, up to four paragraphs, the choices, a box with its label, the lines of a hand step (one
# selectable text: the numbered lines, then the unnumbered ones), the file path of a hand step, the step line (name, bar,
# time in the step, count), the last log line, the error box, two file links, a note, the help line, the closing line of
# a hand step, the buttons, a last gray line, and the owner's test extras. A card shows only the parts it names ($ui.SetCard).
$ui.Card = New-Object System.Windows.Forms.TableLayoutPanel
$ui.Card.Dock = 'Fill'; $ui.Card.ColumnCount = 3; $ui.Card.RowCount = 3; $ui.Card.BackColor = $ui.C.White
foreach ($w in @(11.75, 76.5, 11.75)) { [void]$ui.Card.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', $w))) }
[void]$ui.Card.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 40))); [void]$ui.Card.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))); [void]$ui.Card.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 60)))
# The card is a stack of two: the body (every part above the buttons) and the tail (the buttons, the last gray line
# and the test extras). The body sits in a panel that scrolls only when the card is taller than the window, so the
# buttons are always in view (the Administrator, 2026-11-15; $ui.Squeeze). No scroll at 1020 x 616 and larger.
$ui.MkStack = { $t = New-Object System.Windows.Forms.TableLayoutPanel; $t.AutoSize = $true; $t.AutoSizeMode = 'GrowAndShrink'; $t.ColumnCount = 1; $t.Margin = (& $ui.Pad 0 0 0 0); $t.BackColor = $ui.C.White
  [void]$t.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize'))); $t }
$ui.Stack = & $ui.MkStack; $ui.Stack.Anchor = 'Top, Left'; $ui.Body = & $ui.MkStack; $ui.Tail = & $ui.MkStack
$ui.Scroll = New-Object System.Windows.Forms.Panel
$ui.Scroll.AutoScroll = $true; $ui.Scroll.Margin = (& $ui.Pad 0 0 0 0); $ui.Scroll.BackColor = $ui.C.White; $ui.Scroll.AccessibleName = 'Card text'
$ui.Body.Location = New-Object System.Drawing.Point(0, 0); [void]$ui.Scroll.Controls.Add($ui.Body)
$ui.Kick = & $ui.Text $ui.F.SmallB $ui.C.Gray 0 'Card line'
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
$ui.StepRow = & $ui.Flow $ui.Z.G3; $ui.StepRow.WrapContents = $true   # a long step name: the bar goes to the next line
$ui.StepName = & $ui.Text $ui.F.Body $ui.C.Navy 0 'Step name'; $ui.StepName.Visible = $true
$ui.StepBar = & $ui.MkBar 'step' 'Progress of this step'; $ui.StepBar.Width = 200; $ui.StepBar.Margin = (& $ui.Pad 14 11 14 0)
# R28 N10: the time in this step, at the right end of its bar ("4m 12s"), every second ($ui.TimeT). The log keeps "Started".
$ui.StepTime = & $ui.Label $ui.F.Small $ui.C.Gray 2; $ui.StepTime.Visible = $true; $ui.StepTime.AccessibleName = 'Time in this step'
$ui.StepFrac = & $ui.Label $ui.F.Small $ui.C.Gray 2; $ui.StepFrac.Visible = $true; $ui.StepFrac.Margin = (& $ui.Pad $ui.Z.G3 2 0 0)
foreach ($c in @($ui.StepName, $ui.StepBar, $ui.StepTime, $ui.StepFrac)) { [void]$ui.StepRow.Controls.Add($c) }
# The last log line wraps to its full height (R28 N9: a label 20 px high cut it through its middle, and "..." cut its end).
$ui.LastLog = & $ui.Text $ui.F.Small $ui.C.Gray $ui.Z.G2 'Last log line'
$ui.FieldRow = & $ui.Flow $ui.Z.G2; $ui.FieldRow.WrapContents = $true; & $ui.Ring $ui.FieldRow
$ui.FieldL = & $ui.Label $ui.F.SmallB $ui.C.Gray 9; $ui.FieldL.Visible = $true
# A one-line box: a frame as tall as a compact button with RADE's own 1 px edge, the text box inside it with no border,
# in the middle (a text box cannot be made taller with its text in the middle). The ring goes around the frame.
$ui.Boxes = @()
$ui.BoxFit = { param($P) if (-not $ui.Scaled) { return }; try { $tb = $P.Controls[0]; $in = & $ui.Sc 6; $tb.Width = [math]::Max(10, $P.ClientSize.Width - 2 * $in); $tb.Location = New-Object System.Drawing.Point($in, [int][math]::Floor(($P.ClientSize.Height - $tb.Height) / 2)) } catch { $null = $_ } }
$ui.MkBox = { param($Tb, [int]$W)
  $p = New-Object System.Windows.Forms.Panel; $p.Size = New-Object System.Drawing.Size($W, $ui.Z.CompactH); $p.BackColor = $ui.C.White; $p.AccessibleName = 'Text box'
  $Tb.BorderStyle = 'None'; $Tb.Font = $ui.F.Small; $Tb.ForeColor = $ui.C.Ink; [void]$p.Controls.Add($Tb); $Tb.Add_GotFocus({ try { $this.Parent.Parent.Invalidate() } catch { $null = $_ } }); $Tb.Add_LostFocus({ try { $this.Parent.Parent.Invalidate() } catch { $null = $_ } })
  $p.Add_Paint({ try { $pn = New-Object System.Drawing.Pen($ui.C.Edge); $_.Graphics.DrawRectangle($pn, 0, 0, ($this.ClientSize.Width - 1), ($this.ClientSize.Height - 1)); $pn.Dispose() } catch { $null = $_ } })
  $p.Add_SizeChanged({ & $ui.BoxFit $this }); $p.Add_Click({ try { [void]$this.Controls[0].Focus() } catch { $null = $_ } }); $ui.Boxes += $p; $p }
$ui.Field = New-Object System.Windows.Forms.TextBox
$ui.FieldBox = & $ui.MkBox $ui.Field 420; $ui.FieldBox.Margin = (& $ui.Pad $ui.Z.G2 $ui.Z.M $ui.Z.M $ui.Z.M)   # 8 from the label; 4 + the button's 4 = 8 to the button
$ui.FieldB = & $ui.Btn 'compact'
$ui.FieldB.Add_Click({ if ($ui.FieldDo) { & $ui.FieldDo } })
foreach ($c in @($ui.FieldL, $ui.FieldBox, $ui.FieldB)) { [void]$ui.FieldRow.Controls.Add($c) }
$ui.ErrRow = & $ui.Flow $ui.Z.G2; & $ui.Ring $ui.ErrRow
$ui.ErrBox = New-Object System.Windows.Forms.TextBox
$ui.ErrBox.Multiline = $true; $ui.ErrBox.ScrollBars = 'Vertical'; $ui.ErrBox.Size = New-Object System.Drawing.Size(600, 96); $ui.ErrBox.Margin = (& $ui.Pad 4 4 4 4); $ui.ErrBox.BorderStyle = 'FixedSingle'; $ui.ErrBox.Font = $ui.F.Small; $ui.ErrBox.ForeColor = $ui.C.Ink; $ui.ErrBox.AccessibleName = 'Error message'; & $ui.Cue $ui.ErrBox
[void]$ui.ErrRow.Controls.Add($ui.ErrBox)
$ui.LinkRow = & $ui.Flow 0; $ui.LinkRow.WrapContents = $true; $ui.LinkRow.Margin = (& $ui.Pad (-$ui.Z.M) 0 0 0); & $ui.Ring $ui.LinkRow
$ui.CopyPathB = & $ui.LinkBtn 'Copy file path'; $ui.ShowFileB = & $ui.LinkBtn 'Show file in folder'; $ui.PageB = & $ui.LinkBtn 'Open the RADE page'
$ui.PageB.AccessibleName = 'Open the RADE page in your browser'; $ui.PageB.Visible = $false
foreach ($c in @($ui.CopyPathB, $ui.ShowFileB, $ui.PageB)) { [void]$ui.LinkRow.Controls.Add($c) }
$ui.Note = & $ui.Text $ui.F.Small $ui.C.Gray $ui.Z.G2 'Note'
$ui.Help = & $ui.Text $ui.F.Body $ui.C.Navy $ui.Z.G4 'Help'
$ui.Close = & $ui.Text $ui.F.Small $ui.C.Gray $ui.Z.G4 'Closing line'   # the hand card's closing line, directly above the buttons ($ui.VHand)
$ui.BtnRow = & $ui.Flow $ui.Z.G4; $ui.BtnRow.WrapContents = $true; $ui.BtnRow.Margin = (& $ui.Pad (-$ui.Z.M) ($ui.Z.G4 - $ui.Z.M) 0 0); & $ui.Ring $ui.BtnRow   # the buttons' own 4 px margin is part of the 16 px gap
$ui.B = @(); foreach ($k in 0..($ui.NB - 1)) { $b = & $ui.Btn 'action'; $b.Tag = $k; $b.Add_Click({ $a = $ui.Acts[[int]$this.Tag]; if ($a -and (-not $ui.Busy -or $ui.Always[[int]$this.Tag]) -and (& $ui.Settled)) { & $a } }); $ui.B += $b; [void]$ui.BtnRow.Controls.Add($b) }
$ui.Foot = & $ui.Text $ui.F.Small $ui.C.Gray ($ui.Z.G6 - $ui.Z.M) 'Last line'
# The owner's test extras (test rounds only; they go away with the test branch): the results address, the e-mail draft
# and "the window displayed correctly". A deploy never shows them: it sends nothing.
$ui.TestRow = & $ui.Flow ($ui.Z.G6 - $ui.Z.M); $ui.TestRow.WrapContents = $true; & $ui.Ring $ui.TestRow
$ui.TestL = & $ui.Label $ui.F.SmallB $ui.C.Gray 10; $ui.TestL.Text = 'Test rounds only'; $ui.TestL.Visible = $true
$ui.ToBox = New-Object System.Windows.Forms.TextBox
$ui.ToBox.AccessibleName = 'Send results to (e-mail)'; $ui.ToBoxF = & $ui.MkBox $ui.ToBox 240; $ui.ToBoxF.Margin = (& $ui.Pad $ui.Z.G2 $ui.Z.M $ui.Z.M $ui.Z.M)
$ui.DraftB = & $ui.LinkBtn 'Make e-mail draft'
$ui.OkBox = New-Object System.Windows.Forms.CheckBox
$ui.OkBox.AutoSize = $true; $ui.OkBox.Checked = $true; $ui.OkBox.Text = 'The window displayed correctly'; $ui.OkBox.ForeColor = $ui.C.Gray; $ui.OkBox.Margin = (& $ui.Pad 4 9 4 4); $ui.OkBox.AccessibleName = 'The window displayed correctly (nothing overlapped or cut off)'
foreach ($c in @($ui.TestL, $ui.ToBoxF, $ui.DraftB, $ui.OkBox)) { [void]$ui.TestRow.Controls.Add($c) }
$ui.Fill = { param($T, $Parts) $row = 0; foreach ($c in @($Parts)) { [void]$T.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('AutoSize'))); $T.Controls.Add($c, 0, $row); $row++ }; $T.RowCount = $row }
& $ui.Fill $ui.Body @($ui.Kick, $ui.SentRow, $ui.P[0], $ui.P[1], $ui.P[2], $ui.P[3], $ui.Opts, $ui.FieldRow, $ui.Guide, $ui.PathL, $ui.PathT, $ui.StepRow, $ui.LastLog, $ui.ErrRow, $ui.LinkRow, $ui.Note, $ui.Help)
& $ui.Fill $ui.Tail @($ui.Close, $ui.BtnRow, $ui.Foot, $ui.TestRow)
& $ui.Fill $ui.Stack @($ui.Scroll, $ui.Tail)
$ui.Card.Controls.Add($ui.Stack, 1, 1); $ui.Card.SetColumnSpan($ui.Stack, 2)   # two columns: room for the scroll bar beside the text

