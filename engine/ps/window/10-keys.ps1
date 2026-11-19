# RADE window part 10, keys and form events: the key handlers (F2, Esc, Enter, Ctrl+C), the window place
# saved and restored, and the call that shows the form. It is the last window part.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# ---- Keys: F1 = Help (the RADE tour); F2 = the Record (Page Down and Page Up move its check list, and on a card that is taller than the window its text); Esc = close the Record, else Back, and on Choose (no Back) it exits; 1 to 9 = a choice. Tab reaches every control.
$ui.Form.Add_KeyDown({
  $k = [string]$_.KeyCode
  if ($_.Control -and $k -eq 'C' -and (& $ui.CopyText $ui.Form.ActiveControl)) { $_.SuppressKeyPress = $true }   # Ctrl+C copies the selected card text
  elseif ($k -eq 'F1') { $_.SuppressKeyPress = $true; & $ui.OpenTour }   # L6: Help = the RADE tour
  elseif ($k -eq 'F2') { $_.SuppressKeyPress = $true; if ($ui.RecOn) { & $ui.CloseRecord } else { & $ui.VRecord } }
  elseif ($ui.RecOn -and $k -in 'PageDown', 'Next', 'PageUp', 'Prior' -and -not (& $ui.InField)) {   # the check list by keyboard when it is taller than the window; Windows names these keys Next and Prior; in the log box they page the log
    $_.SuppressKeyPress = $true; try { $y = [math]::Abs($ui.RecScroll.AutoScrollPosition.Y) + $(if ($k -in 'PageDown', 'Next') { 1 } else { -1 }) * [math]::Max((& $ui.Sc 40), $ui.RecScroll.ClientSize.Height - (& $ui.Sc 40)); $ui.RecScroll.AutoScrollPosition = New-Object System.Drawing.Point(0, [math]::Max(0, $y)) } catch { $null = $_ } }
  elseif (-not $ui.RecOn -and $ui.Scrolls -and $k -in 'PageDown', 'Next', 'PageUp', 'Prior' -and -not (& $ui.InField)) {   # the text of a card that is taller than the window, by keyboard
    $_.SuppressKeyPress = $true; try { $y = [math]::Abs($ui.Scroll.AutoScrollPosition.Y) + $(if ($k -in 'PageDown', 'Next') { 1 } else { -1 }) * [math]::Max((& $ui.Sc 40), $ui.Scroll.ClientSize.Height - (& $ui.Sc 40)); $ui.Scroll.AutoScrollPosition = New-Object System.Drawing.Point(0, [math]::Max(0, $y)) } catch { $null = $_ } }
  elseif ($k -eq 'Escape') { $_.SuppressKeyPress = $true; if ($ui.RecOn) { & $ui.CloseRecord } elseif ($ui.Back -and -not $ui.Busy -and -not $ui.Running) { & $ui.Back } elseif ($ui.View -eq 'choose' -and -not $ui.Busy) { $ui.Form.Close() } }
  elseif ($k -match '^(D|NumPad)([1-9])$' -and -not $ui.RecOn -and -not $ui.Busy -and $ui.Opts.Visible -and -not (& $ui.InField)) {
    $n = [int]$Matches[2]; foreach ($o in @($ui.Opts.Controls)) { if (-not $o.Tag.Off -and [int]$o.Tag.Key -eq $n) { $_.SuppressKeyPress = $true; $o.PerformClick(); break } } } })
# Window size and place (R28, the Administrator, 2026-11-17): the window opens where the user last closed it (RADE\Config\rade-window.json;
# bounds that are off every current screen are ignored); the first time it is maximized on the screen that shows the mouse. The
# minimum size is engine/window.json minSize (640 x 480 at 100 %, so Windows Snap can offer its zones; the Administrator, 2026-11-18;
# 1280 x 720 before), cut to the work area of a small screen. The size and the state at Shown and at close are
# recorded, and the layout self-check runs again after each resize (debounced: 400 ms after the last size change).
$ui.Place = {
  $f = $ui.Form; $saved = Read-WindowState; $ui.Placed = 'first run'; $ui.LastClose = $(if ($saved) { [string]$saved.Closed } else { '' })
  try {
    $use = $null; $wa = $null
    if ($saved) { $r = New-Object System.Drawing.Rectangle($saved.X, $saved.Y, $saved.W, $saved.H)
      foreach ($sc in @([System.Windows.Forms.Screen]::AllScreens)) { $i = [System.Drawing.Rectangle]::Intersect($sc.WorkingArea, $r); if ($i.Width -ge (& $ui.Sc 120) -and $i.Height -ge (& $ui.Sc 60)) { $use = $r; $wa = $sc.WorkingArea; break } } }
    if ($use) {
      $w = $use.Width; $h = $use.Height
      if ($saved.Dpi -gt 0 -and [int]$ui.Dpi -ne $saved.Dpi) { $w = [int]($w * $ui.Dpi / $saved.Dpi); $h = [int]($h * $ui.Dpi / $saved.Dpi) }   # the screen scale changed since: the size follows
      $w = [math]::Min($w, $wa.Width); $h = [math]::Min($h, $wa.Height)
      $x = [math]::Max($wa.Left, [math]::Min($use.X, $wa.Right - $w)); $y = [math]::Max($wa.Top, [math]::Min($use.Y, $wa.Bottom - $h))
      $f.Bounds = New-Object System.Drawing.Rectangle($x, $y, $w, $h); $ui.Placed = 'saved'
      if ($saved.State -eq 'Maximized') { $f.WindowState = 'Maximized' }
    } else {
      $sc = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position); $wa = $sc.WorkingArea
      $f.Width = [int]($wa.Width * 0.95); $f.Height = [int]($wa.Height * 0.95); $f.Left = $wa.Left + [int](($wa.Width - $f.Width) / 2); $f.Top = $wa.Top + [int](($wa.Height - $f.Height) / 2)   # where Restore goes
      $f.WindowState = 'Maximized'
    }
    $f.MinimumSize = New-Object System.Drawing.Size([math]::Min((& $ui.Sc $ui.Layout.MinW), $wa.Width), [math]::Min((& $ui.Sc $ui.Layout.MinH), $wa.Height))
  } catch { $null = $_ } }
# Gives the form's client size and window state as text like "1020x760/Normal". Takes nothing.
$ui.WinNow = { $f = $ui.Form; $s = [string]$f.WindowState; if ($s -notin 'Normal', 'Maximized', 'Minimized') { $s = 'Normal' }; return ([string]$f.ClientSize.Width + 'x' + $f.ClientSize.Height + '/' + $s) }
$ui.ResizeT = New-Object System.Windows.Forms.Timer; $ui.ResizeT.Interval = 400
$ui.ResizeT.Add_Tick({ $ui.ResizeT.Stop(); try { if ($ui.Scaled -and [string]$ui.Form.WindowState -ne 'Minimized') { & $ui.Fit; & $ui.Check } } catch { $null = $_ } })
$ui.Form.Add_Resize({ try { if ($ui.Scaled) { $ui.ResizeT.Stop(); $ui.ResizeT.Start() } } catch { $null = $_ } })
$ui.Form.Add_Shown({
  $ui.Opened = $true; & $ui.FormDpi; $ui.Scaled = $true   # the form has its scale now: from here the size handlers work (each runs once below or on the first card)
  & $ui.Place
  & $ui.Fit; $ui.ShownAt = & $ui.WinNow; $ui.Anim.Start()
  & $ui.Boot })
$ui.Form.Add_FormClosing({
  # The window's X (there is no Exit button): ask first only while a step runs, because closing stops it (R17).
  if ($ui.Running -and -not $script:closing) {
    $a = [System.Windows.Forms.MessageBox]::Show($ui.Form, 'A step is running. If you exit now, RADE stops it and the round ends as STOPPED (the report in the results folder says so). Exit now?', 'RADE - Exit', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning, [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
    if ([string]$a -ne 'Yes') { $_.Cancel = $true; return }
  }
  $script:closing = $true; try { $ui.Anim.Stop(); $ui.ResizeT.Stop(); $ui.TimeT.Stop() } catch { $null = $_ }
  try { $f = $ui.Form; $ui.CloseAt = & $ui.WinNow; $st = [string]$f.WindowState; if ($st -eq 'Minimized') { $st = 'Normal' }
    $b = $(if ([string]$f.WindowState -eq 'Normal') { $f.Bounds } else { $f.RestoreBounds }); $cp = ($ui.CloseAt -split '/'); $cs = ([string]$cp[0] -split 'x')   # split on / first: "Maximized" holds an x
    Save-WindowState $b.X $b.Y $b.Width $b.Height $st ([int]$ui.Dpi) ([int]$cs[0]) ([int]$cs[1]) ([string]$cp[1])
    Write-Host ('RADE window at close: client ' + ($ui.CloseAt -replace '/', ', ') + '.') } catch { $null = $_ }
  if ($script:child -and -not $script:child.HasExited) { try { $script:child.Kill() } catch { $null = $_ } } })
# The window is the main form of this thread, with no owner (R24: shown with ShowDialog from PowerShell ISE, ISE owned
# it, so it had no taskbar button and could not be restored after it was minimized). When a message loop already runs
# on this thread, Application.Run cannot start one: then ShowDialog, as before. Run disposes the form when it closes.
$ui.Opened = $false
try { [System.Windows.Forms.Application]::Run($ui.Form) }
catch {
  $ex = $_.Exception; while ($ex -and -not ($ex -is [System.InvalidOperationException])) { $ex = $ex.InnerException }
  if (-not $ex -or $ui.Opened -or $ui.Form.IsDisposed) { throw }   # only a loop that could not start: the window never showed
  [void]$ui.Form.ShowDialog()
}
foreach ($o in @($ui.Trash)) { try { $o.Dispose() } catch { $null = $_ } }   # after the window has closed: no handler is running
return
