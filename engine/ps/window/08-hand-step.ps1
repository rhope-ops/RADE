# RADE window part 08, a hand step: the cards for a step the user does by hand (It failed, questions,
# open the address) and $script:guideUi, which the engine waits in until the user answers.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# ---- A step you do by hand, or a check you answer by looking (R13, R14, R18): the card holds the numbered lines, the
# address (it can be changed; it is remembered in Config), the file path on the clipboard, and the answers. The engine
# waits in $script:guideUi until an answer is set: OK = Done or Yes, No, Abort = It failed (with the error text),
# Cancel = Skip, Not now, or the window closed. Enter never answers here: Done needs a deliberate click.
$ui.VHand = {
  $st = $ui.G.Step; $file = [string]$ui.G.File
  $clip = $(if (-not $file) { '' } elseif (Copy-TextToClipboard $file) { 'The path of ' + $st.File + ' is on the clipboard.' } else { 'Select "Copy file path" to put the path of ' + $st.File + ' on the clipboard.' })
  $two = $(if ($st.NoText) { @{ Text = [string]$st.NoText; Act = { $ui.Answer = 'No' } } } else { @{ Text = 'It failed'; Act = { & $ui.VHandFail } } })
  # R28 N1: the address row only when the step has an address (or a saved one it can take); N6: the file's full path on the card.
  $addr = [bool]($ui.GUrl -or $st.UrlConfig); $dw = $(if ($st.DoneText) { [string]$st.DoneText } else { 'Done' })
  & $ui.SetCard @{ View = 'hand'; Light = 'you'; Kicker = $(if ($ui.Running -and $ui.StepI) { 'Step ' + $ui.StepI + ' of ' + $ui.StepN + $dot + 'your turn' } else { 'Your turn' }); Sentence = (Get-StepTitle $st)
    P = @([string]$st.Note); Lines = @($st.Guide); Close = $(if ($addr) { 'When you finish in the browser, come back to this window and select "' + $dw + '".' } else { 'When you finish, select "' + $dw + '".' })
    Field = $(if ($addr) { @{ Label = 'Address'; Text = $ui.GUrl; Name = 'Address to open'; Button = 'Open in browser'; Act = { & $ui.OpenUrl } } } else { $null }); Path = $file; Links = [bool]$file; Note = $clip
    Buttons = @(@{ Text = $dw; Kind = 'primary'; Act = { $ui.Answer = 'OK' } }, $two, @{ Text = $(if ($st.SkipText) { [string]$st.SkipText } else { 'Skip' }); Act = { $ui.Answer = 'Cancel' } })
    Right = 'RADE is waiting for you'; NoAccept = $true; Focus = $(if ($addr) { 'fieldbutton' } else { 'text' }) } }
# Shows the card where the user pastes the error of a hand step that failed; its button sets the answer to Abort. Takes
# nothing.
$ui.VHandFail = {
  & $ui.SetCard @{ View = 'handfail'; Light = 'you'; Kicker = 'It failed'; Sentence = 'What did the error say?'; P = @('Paste the error message here. Do not include names or a site address.'); Err = $true
    Buttons = @(@{ Text = 'Report the failure'; Kind = 'primary'; Act = { $script:guideError = [string]$ui.ErrBox.Text; $ui.Answer = 'Abort' } }, @{ Text = 'Back'; Act = { & $ui.VHand } }); Right = 'RADE is waiting for you'; NoAccept = $true; Focus = 'err' } }
# A question of a hand step (manifest "answers"), after Done: the prompt is the sentence; yes/no and pick answer with
# one button per word, a text with one line (2,000 characters at most; empty is allowed; R28: kept whole) and "Continue". No Back.
$ui.ReplyActs = @({ $ui.Reply = [string]$ui.B[0].Text }, { $ui.Reply = [string]$ui.B[1].Text }, { $ui.Reply = [string]$ui.B[2].Text }, { $ui.Reply = [string]$ui.B[3].Text })
# Shows one question of a hand step (text, yes or no, or a pick). The first sentence of the prompt is the headline.
# Takes the question, its number and the count; the answer is set in $ui.Reply.
$ui.VAnswer = { param($Q, [int]$I, [int]$N)
  $ui.Reply = $null
  $c = @{ View = 'answer'; Light = 'you'; Kicker = ($(if ($ui.Running -and $ui.StepI) { 'Step ' + $ui.StepI + ' of ' + $ui.StepN + $dot } else { '' }) + 'Question ' + $I + ' of ' + $N); Sentence = [string]$Q.Prompt; Right = 'RADE is waiting for you' }
  # The prompt's first sentence (up to the first "?", "." or ":" followed by a space or the end) is the headline; the rest
  # is a body line under it (the Administrator, 2026-11-15, rework B). A first sentence too long for one line shrinks ($ui.FitSent).
  if ([string]$Q.Prompt -match '^(.+?[?.:])(?:\s+(\S.*))?$') { $c.Sentence = $Matches[1]; if ($Matches[2]) { $c.P = @($Matches[2].Trim()) } }
  if ($Q.Kind -eq 'text') { $c.Field = @{ Label = 'Your answer'; Text = ''; Name = [string]$Q.Prompt; Max = 2000 }; $c.Focus = 'field'; $c.Buttons = @(@{ Text = 'Continue'; Kind = 'primary'; Act = { $ui.Reply = [string]$ui.Field.Text } }) }
  else { $ws = @($(if ($Q.Kind -eq 'yesno') { 'Yes', 'No' } else { $Q.Choices })); $c.Buttons = @(for ($k = 0; $k -lt $ws.Count; $k++) { @{ Text = [string]$ws[$k]; Act = $ui.ReplyActs[$k] } }) }
  & $ui.SetCard $c }
# Opens the address in the box in the browser and remembers it (also in its file). Takes nothing; says so when the
# address does not start with https://.
$ui.OpenUrl = {
  $u = $ui.Field.Text.Trim()
  if ($u -notmatch '^https://') { & $ui.Say1 'The address must start with https://'; return }
  $ui.GUrl = $u; try { if ($ui.G.UrlFile) { Set-Content -LiteralPath $ui.G.UrlFile -Value $u -Encoding UTF8 } } catch { $null = $_ }
  try { Start-Process -FilePath $u; & $ui.Say1 'Opened in your browser. Do the steps on this card, then come back to this window.' } catch { & $ui.Say1 ('The browser could not be opened: ' + $_.Exception.Message) } }
$ui.CopyPathB.Add_Click({ & $ui.Say1 $(if (Copy-TextToClipboard ([string]$ui.G.File)) { 'File path copied. Press Ctrl+V in the "File name" box' } else { 'The clipboard is busy. Select "Copy file path" again.' }) })
$ui.PageB.Add_Click({ try { Start-Process -FilePath $radeUrl } catch { & $ui.Say1 'The browser could not be opened. Open the RADE page from your bookmarks.' } })
$ui.ShowFileB.Add_Click({ if ($ui.G.File) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"' + $ui.G.File + '"') } })
# Shows a hand step and waits until the user answers, then asks the step's questions. Takes the step, the file path, the
# address and the address file; gives back OK, Abort or Cancel.
$script:guideUi = { param($Step, [string]$File, [string]$Url, [string]$UrlFile)
  $ui.G = @{ Step = $Step; File = $File; UrlFile = $UrlFile }; $ui.GUrl = $Url; $script:guideError = ''; $ui.Answer = ''; $was = $ui.Busy; $ui.Busy = $false
  $null = & $ui.VHand; $null = & $ui.ToFront
  while (-not $ui.Answer -and -not $script:closing -and -not $ui.Form.IsDisposed) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 25 }
  # After Done (not after "It failed" or Skip): the step's questions, one card each, in order. Their time is the step's time.
  $script:guideAnswers = @{}; $qs = @($(if ($ui.Answer -eq 'OK') { $Step.Answers }) | Where-Object { $_ })
  for ($i = 0; $i -lt $qs.Count -and -not $script:closing -and -not $ui.Form.IsDisposed; $i++) {
    $null = & $ui.VAnswer $qs[$i] ($i + 1) $qs.Count
    while ($null -eq $ui.Reply -and -not $script:closing -and -not $ui.Form.IsDisposed) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 25 }
    if ($null -ne $ui.Reply) { $script:guideAnswers[[string]$qs[$i].Key] = [string]$ui.Reply }
  }
  $ui.Busy = $was; $res = [string]$ui.Answer; if (-not $res) { $res = 'Cancel' }
  $ui.Guides = @($ui.Guides | Where-Object { $_ -ne [string]$Step.Name })
  if ($ui.Running -and -not $script:closing) { $null = & $ui.ShowRun }
  return $res }

