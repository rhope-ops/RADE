# RADE window part 01, setup: asks Windows for the real screen dpi, creates the $ui table that holds every
# window value, and creates the form. The window parts run inside "if ($gui) { try {" of 10-window.ps1 and use no other part before this one.
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

# The "One thing" window (the Administrator, 2026-11-14; docs/window-design.md): the window shows one statement or one
# question at a time; everything else (all checks, the step boxes, the files, the made list, the log) is in the Record
# (F2). Each answer moves on: there is no Next / Back row and no Exit button (Esc goes back, and exits on Choose; the window's X exits).
# Every window value lives in $ui: handlers and the engine's callbacks run inside engine functions, where a plain
# variable name could meet a local of the same name. A block stored in $ui reads only $ui and the bundle's globals.
# R28 item 1 (the Administrator, 2026-11-17): text scales with the controls. Two ways were possible: (a) ask Windows for the real
# dpi (SetProcessDPIAware, GetDpiForWindow: a native call from user32) and size everything from it, or (b) AutoScaleMode Font.
# (b) scales by the form font, which Windows draws at 96 dpi on the R25 device (dpiX 96, autoScale 144, font 18 px): it gives
# no scaling at all there. RADE takes (a) and keeps one scale source: the controls follow the form's auto-scale (as before),
# and every font is made bigger by the same factor when the screen draws text smaller ($ui.FontScale in engine/rade_ui.ps1).
# The native call is asked for before any form exists; it changes nothing when the process already has an awareness
# (the call fails), and when a native call cannot be compiled (Constrained Language Mode) the window runs as before.
$script:native = $false
if ($env:OS -eq 'Windows_NT') {
  try { Add-Type -Namespace Rade -Name Native -MemberDefinition ('[DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); ' +
      '[DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hWnd); [DllImport("user32.dll")] public static extern bool HideCaret(IntPtr hWnd);') -ErrorAction Stop
    $script:native = $true; try { $null = [Rade.Native]::SetProcessDPIAware() } catch { $null = $_ } } catch { $script:native = $false }
}
[System.Windows.Forms.Application]::EnableVisualStyles()
$ui = @{ View = ''; Running = $false; Busy = $false; RecOn = $false; Edit = $false; Answer = ''; Acts = @(); Back = $null; OnOpt = $null; FieldDo = $null
  Log = (New-Object System.Collections.Generic.List[string]); Summary = @(); Sel = @{}; Clean = $true; StepState = @{}; Plan = $null; Picked = $false
  BaseIds = @(); BaseRes = @{}; Blocked = @{}; Newer = @{}; Bars = @{}; G = $null; GUrl = ''; CurId = ''; StepI = 0; StepN = 0; StepNow = ''; BusyShown = $false; Always = @($false, $false, $false, $false, $false, $false); NB = 6; StartAfter = $false; Cancel = $false; Dpi = 96.0; ScreenDpi = 96.0; FontK = 1.0; FontDpi = 96.0; Scaled = $false; Full = @{}; Clock = [System.Diagnostics.Stopwatch]::StartNew(); CardAt = -1000000.0; GuardMs = 400; Calm = $false; ContentW = 780 }
# Layout values from engine/window.json, put in by the build (text column share and cap, minimum window size; pixels at 100 %).
$ui.Layout = @{ Share = [double]'@@TEXT_SHARE@@'; MaxW = [int]'@@TEXT_MAX@@'; MinW = [int]'@@MIN_W@@'; MinH = [int]'@@MIN_H@@' }
$ui.Hist = Read-RoundHistory (Get-BasePath)
$script:secret = Get-Secret (Get-ProfileLeaf) (Get-ProfileLeaf)   # saved checks are masked before they are written
try { $ui.Calm = -not [System.Windows.Forms.SystemInformation]::UIEffectsEnabled } catch { $null = $_ }
$ui.Form = New-Object System.Windows.Forms.Form
$ui.Form.Text = 'RADE - ' + 'Test, deploy, enjoy' + ' - ' + $round + ' - build ' + $buildId   # the tagline (the Administrator, 18 Nov 26) is in the title bar; the window itself has none
$ui.Form.SuspendLayout()
$ui.Form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96); $ui.Form.AutoScaleMode = 'Dpi'   # sizes below are at 100 % scaling
# @@UI@@
$ui.Form.ClientSize = New-Object System.Drawing.Size(1020, 760)   # at 100 %; the minimum size is set when the window has its scale (Shown)
$ui.Form.StartPosition = 'CenterScreen'; $ui.Form.KeyPreview = $true; $ui.Form.BackColor = $ui.C.White
$ui.Form.ShowInTaskbar = $true; $ui.Form.MinimizeBox = $true   # its own taskbar button: a minimized window can be restored (R24)

