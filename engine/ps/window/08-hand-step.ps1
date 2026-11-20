# RADE window part 08, a hand step: the cards for a step the user does by hand (It failed, questions,
# open the address) and $script:guideUi, which the engine waits in until the user answers.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# ---- A step you do by hand, or a check you answer by looking (R13, R14, R18): the card holds the numbered lines, the
# address (it can be changed; it is remembered in Config), the file path on the clipboard, and the answers. The engine
# waits in $script:guideUi until an answer is set: OK = Done or Yes, No, Abort = It failed (with the error text),
# Cancel = Skip, Not now, or the window closed. Enter never answers here: Done needs a deliberate click.
$ui.VHand = {
  $st = $ui.G.Step; $file = [string]$ui.G.File; $hide = @($st.Hide)
  $clip = $(if (-not $file) { '' } elseif (Copy-TextToClipboard $file) { 'The path of ' + $st.File + ' is on the clipboard.' } else { 'Select "Copy file path" to put the path of ' + $st.File + ' on the clipboard.' })
  $two = $(if ($st.NoText) { @{ Text = [string]$st.NoText; Act = { $ui.Answer = 'No' } } } else { @{ Text = 'It failed'; Act = { & $ui.VHandFail } } })
  # R28 N1: the address row only when the step has an address (or a saved one it can take); N6: the file's full path on the card.
  $addr = [bool]($ui.GUrl -or $st.UrlConfig); $dw = $(if ($st.DoneText) { [string]$st.DoneText } else { 'Done' })
  # E1 (the Administrator, 2026-11-19): the step's "hide" takes buttons off the card; one button always stays (the build checks it).
  $one = @{ Text = $dw; Kind = 'primary'; Act = { $ui.Answer = 'OK' } }; $three = @{ Text = $(if ($st.SkipText) { [string]$st.SkipText } else { 'Skip' }); Act = { $ui.Answer = 'Cancel' } }
  $bs = @($(if ($hide -notcontains 'done') { $one }), $(if ($hide -notcontains 'failed') { $two }), $(if ($hide -notcontains 'skip') { $three }))
  $close = $(if ($hide -contains 'done') { '' } elseif ($addr) { 'When you finish in the browser, come back to this window and select "' + $dw + '".' } else { 'When you finish, select "' + $dw + '".' })
  & $ui.SetCard @{ View = 'hand'; Light = 'you'; Kicker = $(if ($ui.Running -and $ui.StepI) { 'Step ' + $ui.StepI + ' of ' + $ui.StepN } else { '' }); Sentence = (Get-StepTitle $st)
    P = @([string]$st.Note); Lines = @($st.Guide); Close = $close
    Field = $(if ($addr) { @{ Label = 'Address'; Text = $ui.GUrl; Name = 'Address to open'; Button = 'Open in browser'; Act = { & $ui.OpenUrl } } } else { $null }); Path = $file; Links = [bool]$file; Note = $clip
    Buttons = $bs; NoAccept = $true; Focus = $(if ($addr) { 'fieldbutton' } else { 'text' }) } }
# Shows the card where the user pastes the error of a hand step that failed; its button sets the answer to Abort. Takes
# nothing.
$ui.VHandFail = {
  & $ui.SetCard @{ View = 'handfail'; Light = 'you'; Kicker = 'It failed'; Sentence = 'What did the error say?'; P = @('Paste the error message here. Do not include names or a site address.'); Err = $true
    Buttons = @(@{ Text = 'Report the failure'; Kind = 'primary'; Act = { $script:guideError = [string]$ui.ErrBox.Text; $ui.Answer = 'Abort' } }); Back = { & $ui.VHand }; NoAccept = $true; Focus = 'err' } }
# A question of a hand step (manifest "answers"), after Done: the prompt is the sentence; yes/no and pick answer with
# one button per word, a text with one line (10,000 characters at most; empty is allowed; R28: kept whole) and "Continue". No Back.
$ui.ReplyActs = @({ $ui.Reply = [string]$ui.B[0].Text }, { $ui.Reply = [string]$ui.B[1].Text }, { $ui.Reply = [string]$ui.B[2].Text }, { $ui.Reply = [string]$ui.B[3].Text })
# Shows one question of a hand step (text, yes or no, or a pick). The first sentence of the prompt is the headline.
# Takes the question, its number and the count; the answer is set in $ui.Reply.
$ui.VAnswer = { param($Q, [int]$I, [int]$N)
  $ui.Reply = $null
  $c = @{ View = 'answer'; Light = 'you'; Kicker = ($(if ($ui.Running -and $ui.StepI) { 'Step ' + $ui.StepI + ' of ' + $ui.StepN + $dot } else { '' }) + 'Question ' + $I + ' of ' + $N); Sentence = [string]$Q.Prompt }
  # The prompt's first sentence (up to the first "?", "." or ":" followed by a space or the end) is the headline; the rest
  # is a body line under it (the Administrator, 2026-11-15, rework B). A first sentence too long for one line shrinks ($ui.FitSent).
  if ([string]$Q.Prompt -match '^(.+?[?.:])(?:\s+(\S.*))?$') { $c.Sentence = $Matches[1]; if ($Matches[2]) { $c.P = @($Matches[2].Trim()) } }
  if ($Q.Kind -eq 'text') { $c.Field = @{ Label = 'Your answer'; Text = ''; Name = [string]$Q.Prompt; Max = 10000; Above = $true }
    $c.Focus = 'field'; $c.Buttons = @(@{ Text = 'Continue'; Kind = 'primary'; Act = { $ui.Reply = [string]$ui.Field.Text } }) }
  else { $ws = @($(if ($Q.Kind -eq 'yesno') { 'Yes', 'No' } else { $Q.Choices })); $c.Buttons = @(for ($k = 0; $k -lt $ws.Count; $k++) { @{ Text = [string]$ws[$k]; Act = $ui.ReplyActs[$k] } }) }
  & $ui.SetCard $c }
# E2 (the Administrator, 2026-11-19): after an answer that the manifest marks as a failure ("failOn"), the card where the
# user pastes the error text. Its button keeps the text in $script:guideError and sets $ui.Reply. No Back. Takes nothing.
$ui.VAnswerFail = {
  $ui.Reply = $null
  & $ui.SetCard @{ View = 'answerfail'; Light = 'you'; Kicker = ($(if ($ui.Running -and $ui.StepI) { 'Step ' + $ui.StepI + ' of ' + $ui.StepN + $dot } else { '' }) + 'It failed'); Sentence = 'What did the error say?'
    P = @('Paste the error message here. Do not include names or a site address. If there is no message, leave the box empty.'); Err = $true
    Buttons = @(@{ Text = 'Continue'; Kind = 'primary'; Act = { $script:guideError = [string]$ui.ErrBox.Text; $ui.Reply = 'ok' } }); NoAccept = $true; Focus = 'err' } }
# Waits until the user answers the card that is shown ($ui.Reply is set) or the window closes. Takes nothing.
$ui.WaitReply = { while ($null -eq $ui.Reply -and -not $script:closing -and -not $ui.Form.IsDisposed) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 25 } }
# Asks the questions of a hand step, one card each, in order; a question with "showIf" shows only after one of its
# answers to the earlier question (E3). Keeps the answers in $script:guideAnswers and the answers that mean a failure
# in $script:guideFail; after the first of those it asks for the error text. Takes the step; gives back nothing.
$ui.AskAnswers = { param($Step)
  $qs = @($Step.Answers | Where-Object { $_ })
  for ($i = 0; $i -lt $qs.Count -and -not $script:closing -and -not $ui.Form.IsDisposed; $i++) {
    $q = $qs[$i]; if ($q.ShowKey -and @($q.ShowIn) -cnotcontains [string]$script:guideAnswers[[string]$q.ShowKey]) { continue }
    $null = & $ui.VAnswer $q ($i + 1) $qs.Count; $null = & $ui.WaitReply
    if ($null -eq $ui.Reply) { return }
    $v = [string]$ui.Reply; $script:guideAnswers[[string]$q.Key] = $v
    if (@($q.FailOn) -ccontains $v) { $script:guideFail += ([string]$q.Key + ': ' + $v); if (@($script:guideFail).Count -eq 1) { $null = & $ui.VAnswerFail; $null = & $ui.WaitReply } }
  } }
# Opens the address in the box in the browser and remembers it (also in its file). Takes nothing; says so when the
# address does not start with https://, or is not on the host of the step's own address (the Administrator, 2026-11-17).
$ui.OpenUrl = {
  $u = $ui.Field.Text.Trim()
  if ($u -notmatch '^https://') { & $ui.Say1 'The address must start with https://'; return }
  $fixed = [string]$ui.G.Step.Url
  if (-not $fixed) { & $ui.Say1 'This step gives no address of its own, so RADE cannot open one from here.'; return }
  if (-not (Test-SameHost $u $fixed)) { & $ui.Say1 ('The address must be on ' + ([uri]$fixed).Host + ', like the address this step gives.'); return }
  $ui.GUrl = $u; try { if ($ui.G.UrlFile) { Set-Content -LiteralPath $ui.G.UrlFile -Value $u -Encoding UTF8 } } catch { $null = $_ }
  try { Start-Process -FilePath $u; & $ui.Say1 'Opened in your browser. Do the steps on this card, then come back to this window.' } catch { & $ui.Say1 ('The browser could not be opened: ' + $_.Exception.Message) } }
$ui.CopyPathB.Add_Click({ & $ui.Say1 $(if (Copy-TextToClipboard ([string]$ui.G.File)) { 'File path copied. Press Ctrl+V in the "File name" box' } else { 'The clipboard is busy. Select "Copy file path" again.' }) })
$ui.PageB.Add_Click({ try { Start-Process -FilePath $radeUrl } catch { & $ui.Say1 'The browser could not be opened. Open the RADE page from your bookmarks.' } })
$ui.ShowFileB.Add_Click({ if ($ui.G.File) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"' + $ui.G.File + '"') } })
# Shows a hand step and waits until the user answers, then asks the step's questions; a step with "answersOnly" shows its
# questions at once (E2). Takes the step, the file path, the address and the address file; gives back OK, Abort or Cancel.
$script:guideUi = { param($Step, [string]$File, [string]$Url, [string]$UrlFile)
  $ui.G = @{ Step = $Step; File = $File; UrlFile = $UrlFile }; $ui.GUrl = $Url; $script:guideError = ''; $ui.Answer = ''; $was = $ui.Busy; $ui.Busy = $false
  $script:guideAnswers = @{}; $script:guideFail = @()
  if ($Step.AnswersOnly) { $ui.Answer = 'OK'; $null = & $ui.ToFront }
  else { $null = & $ui.VHand; $null = & $ui.ToFront
    while (-not $ui.Answer -and -not $script:closing -and -not $ui.Form.IsDisposed) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 25 } }
  # After Done (not after "It failed" or Skip): the step's questions, one card each, in order. Their time is the step's time.
  if ($ui.Answer -eq 'OK') { $null = & $ui.AskAnswers $Step }
  $ui.Busy = $was; $res = [string]$ui.Answer; if (-not $res) { $res = 'Cancel' }
  if ($Step.AnswersOnly -and ($script:closing -or $ui.Form.IsDisposed)) { $res = 'Cancel' }   # the window closed before the last answer
  $ui.Guides = @($ui.Guides | Where-Object { $_ -ne [string]$Step.Name })
  if ($ui.Running -and -not $script:closing) { $null = & $ui.ShowRun }
  return $res }
# L4 (the Administrator, 2026-11-19): the last card of a test round, "Anything else about this round or the app?". The
# text is optional and takes up to 10,000 characters, like every text answer (R34, R7); a pasted block becomes one line ($ui.PasteLine); the engine puts it into the report under the line "Other feedback:" (Get-RoundFeedback). Takes
# nothing; waits for Continue; gives back the text ('' when the window closed).
$script:feedbackUi = {
  $null = & $ui.HoldStep   # L8: the last step stays on the Run card for its minimum time first
  $was = $ui.Busy; $ui.Busy = $false; $ui.Reply = $null; $ui.Asked = $true
  $null = & $ui.SetCard @{ View = 'feedback'; Light = 'you'; Kicker = 'Last question'; Sentence = 'Anything else about this round or the app?'
    P = @('This is optional. Do not type names or addresses.'); Field = @{ Label = 'Your answer'; Text = ''; Name = 'Anything else about this round or the app?'; Max = 10000; Above = $true }; Focus = 'field'
    Buttons = @(@{ Text = 'Continue'; Kind = 'primary'; Act = { $ui.Reply = [string]$ui.Field.Text } }) }
  $null = & $ui.ToFront; $null = & $ui.WaitReply
  $ui.Busy = $was; $text = [string]$ui.Reply
  if ($ui.Running -and -not $script:closing) { $null = & $ui.ShowRun }
  return $text }
# ---- Feedback on every card (UI standard v1, B13; the Administrator, 2026-11-20). In a test round the bottom line has the
# link "Feedback" ($ui.FeedB) on every card. It takes a picture of the window as it is (Control.DrawToBitmap of the form),
# then shows a card with a comment box; Save writes the comment (masked as a text answer is) and the picture as
# feedback-NN.txt and feedback-NN.png into Rounds\<round>\Feedback, then shows the card it came from again. The folder is
# under the round's results folder, not in it: the e-mail draft attaches only the files of the results folder itself, and
# the picture shows the real profile path (DoD365 boundary, AGENTS.md "Project rules"), so it stays on this computer.
# Gives back $true when the bundle's chosen (or only) application is a test one: the link shows then. Takes nothing.
$ui.NoteOn = { try { if ($ui.Picked) { return [bool](-not (Test-Deploy)) }; return [bool](@($apps | Where-Object { [string]$_.Mode -ne 'deploy' }).Count) } catch { return $false } }   # no answer: no link
$ui.NoNoteViews = @('note')
$ui.VNote = {
  <#
  .SYNOPSIS
  Shows the feedback card for the card on screen, with a picture of the window taken first.
  .DESCRIPTION
  Does nothing while RADE is busy or a run is on (the Run card keeps updating), in the Record and on the feedback card
  itself. The picture is kept in $ui.NoteShot until Save or Back; no picture (a host that cannot draw the form) is allowed.
  .OUTPUTS
  Nothing.
  #>
  if ($ui.Busy -or $ui.Running -or $ui.RecOn -or -not $ui.CardNow -or [string]$ui.View -in $ui.NoNoteViews) { return }
  $ui.NoteFor = $ui.CardNow; $ui.NoteShot = $null
  try { $w = [int]$ui.Form.Width; $h = [int]$ui.Form.Height; $bm = New-Object System.Drawing.Bitmap($w, $h)
    $ui.Form.DrawToBitmap($bm, (New-Object System.Drawing.Rectangle(0, 0, $w, $h))); $ui.NoteShot = $bm } catch { $null = $_ }   # no picture: the comment alone
  & $ui.SetCard @{ View = 'note'; Kicker = 'Feedback'; Sentence = 'What do you want to tell us about this card?'
    P = @('RADE saves your comment and a picture of the window in the Feedback folder of this round. They stay on this computer and are not attached to the results e-mail.', 'Do not type names or addresses.'); Err = $true
    Buttons = @(@{ Text = 'Save'; Kind = 'primary'; Act = { & $ui.Say1 (& $ui.SaveNote ([string]$ui.ErrBox.Text)); & $ui.NoteBack $false } }); Back = { & $ui.NoteBack $true }; NoAccept = $true; Focus = 'err' } }
$ui.SaveNote = {
  <#
  .SYNOPSIS
  Writes one feedback comment and the picture of $ui.NoteShot into Rounds\<round>\Feedback (UI standard v1, B13).
  .DESCRIPTION
  The files are feedback-NN.txt (the card, the time, the window size and scale, then the comment, masked as a text answer
  is) and feedback-NN.png; NN is the first number not yet used. A picture that cannot be saved leaves the comment saved.
  .PARAMETER Text
  The comment as typed.
  .OUTPUTS
  The line the card shows: what was saved, or why nothing could be saved (masked).
  #>
  param([string]$Text)
  try { $dir = Join-Path (Join-Path (Join-Path (Get-BasePath) 'Rounds') $round) 'Feedback'
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { $null = New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop }
    $n = 1; while (Test-Path -LiteralPath (Join-Path $dir ('feedback-{0:D2}.txt' -f $n))) { $n++ }; $stem = 'feedback-{0:D2}' -f $n
    $win = [string]$ui.Form.ClientSize.Width + ' x ' + $ui.Form.ClientSize.Height + ' at ' + [int][math]::Round($ui.Dpi / 96.0 * 100) + ' %' + $(if ($ui.High) { ', contrast theme' } else { '' })
    $lines = @(('Card: ' + [string]$ui.NoteFor.View), ('Time: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')), ('Window: ' + $win), '', (ConvertTo-UserText $Text))
    [System.IO.File]::WriteAllText((Join-Path $dir ($stem + '.txt')), (($lines -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
    $pic = ''; $png = ('System.Drawing.Imaging.ImageFormat' -as [type])
    if ($ui.NoteShot) { try { $ui.NoteShot.Save((Join-Path $dir ($stem + '.png')), $png::Png); $pic = ' and its picture' } catch { $null = $_ } }   # no picture file: the comment is saved
    return ('Feedback saved: ' + $stem + $pic + ' in the Feedback folder of round ' + $round + '.')
  } catch { return ('The feedback could not be saved: ' + (ConvertTo-Masked ([string]$_.Exception.Message))) } }
# Shows the card the feedback came from again and lets the picture go. Takes $true when Back was selected (the note line
# is cleared then).
$ui.NoteBack = { param([bool]$Cancel)
  $say = [string]$ui.Note.Text; try { if ($ui.NoteShot) { $ui.NoteShot.Dispose() } } catch { $null = $_ }; $ui.NoteShot = $null   # a picture that is gone: nothing to free
  if ($ui.NoteFor) { & $ui.SetCard $ui.NoteFor; if (-not $Cancel) { & $ui.Say1 $say } } }
