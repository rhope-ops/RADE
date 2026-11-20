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
# R34 (the Administrator, 2026-11-19, "a"): in PowerShell ISE the window read 96 dpi on a 150 % screen while the console drew it
# smaller and sharper; SetProcessDPIAware above cannot change a process whose awareness is already set. So RADE also reads the
# awareness of its own thread (Windows 10 1607 or later) and, only when it is "unaware" (Windows then stretches the window),
# makes the thread "system aware" before the form exists; engine/ps/10-window.ps1 sets the old value back when the window has closed or failed.
# A separate type (Rade.Dpi): a bundle pasted again in the same session must not fail on a changed Rade.Native.
# $script:dpiThread is the SCALE line's "thread=" (the awareness, and "unaware>system" when RADE changed it).
$script:dpiThread = 'n/a'
if ($script:native) {
  try { Add-Type -Namespace Rade -Name Dpi -MemberDefinition ('[DllImport("user32.dll")] public static extern IntPtr GetThreadDpiAwarenessContext(); ' +
      '[DllImport("user32.dll")] public static extern int GetAwarenessFromDpiAwarenessContext(IntPtr c); [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr c); ' +
      '[DllImport("user32.dll")] public static extern uint GetDpiForSystem();') -ErrorAction Stop
    $aw = [Rade.Dpi]::GetAwarenessFromDpiAwarenessContext([Rade.Dpi]::GetThreadDpiAwarenessContext())
    $script:dpiThread = $(if ($aw -ge 0 -and $aw -le 2) { @('unaware', 'system', 'permonitor')[$aw] } else { 'invalid' })
    if ($aw -eq 0) { $script:dpiOld = [Rade.Dpi]::SetThreadDpiAwarenessContext([IntPtr](-2)); if ($script:dpiOld -ne [IntPtr]::Zero) { $script:dpiThread = 'unaware>system' } }   # -2 = DPI_AWARENESS_CONTEXT_SYSTEM_AWARE
  } catch { $script:dpiThread = 'n/a' }   # before Windows 10 1607 (no such function) or no compiler: the window runs as before
}
[System.Windows.Forms.Application]::EnableVisualStyles()
$ui = @{ View = ''; Running = $false; Busy = $false; RecOn = $false; Edit = $false; Answer = ''; Acts = @(); Back = $null; OnOpt = $null; FieldDo = $null
  Log = (New-Object System.Collections.Generic.List[string]); Summary = @(); Sel = @{}; Clean = $true; StepState = @{}; Plan = $null; Picked = $false
  BaseIds = @(); BaseRes = @{}; Blocked = @{}; Newer = @{}; Bars = @{}; G = $null; GUrl = ''; CurId = ''; StepI = 0; StepN = 0; StepNow = ''; BusyShown = $false; Always = @($false, $false, $false, $false, $false, $false); NB = 6; StartAfter = $false; Cancel = $false; Dpi = 96.0; ScreenDpi = 96.0; FontK = 1.0; FontDpi = 96.0; Scaled = $false; Full = @{}; Clock = [System.Diagnostics.Stopwatch]::StartNew(); CardAt = -1000000.0; GuardMs = 400; Calm = $false; ContentW = 780 }
# The tagline (the Administrator, 2026-11-19): shown where the application's name shows, until an application is chosen.
$ui.Tagline = 'Test, deploy, enjoy.'
# Layout values from engine/window.json, put in by the build (text column share and cap, minimum window size, minimum height of the card frame; pixels at 100 %; the minimum time of a step on the Run card, ms).
$ui.Layout = @{ Share = [double]'@@TEXT_SHARE@@'; MaxW = [int]'@@TEXT_MAX@@'; MinW = [int]'@@MIN_W@@'; MinH = [int]'@@MIN_H@@'; FrameMin = [int]'@@FRAME_MIN@@'; StepMs = [int]'@@MIN_STEP_MS@@' }
$ui.Hist = Read-RoundHistory (Get-BasePath)
$script:secret = Get-Secret (Get-ProfileLeaf) (Get-ProfileLeaf)   # saved checks are masked before they are written
try { $ui.Calm = -not [System.Windows.Forms.SystemInformation]::UIEffectsEnabled } catch { $null = $_ }
$ui.Form = New-Object System.Windows.Forms.Form
$ui.Form.Text = 'Redacted Application Deployment Engine' + $dot + 'build ' + $buildId   # the Administrator, 2026-11-19: the full name and the build, no round; the bundle hash stays in the log and the report (docs/specs/bundle-hash.md); the window itself has no title
# The title-bar icon is RADE's logo (Fulcrum everywhere, the PFM, 2026-11-20), drawn at 32 px from the bundle's PNG.
try {
  $ib = New-Object System.Drawing.Bitmap((New-Object System.IO.MemoryStream(, [System.Convert]::FromBase64String($logoPng))))
  $ui.Form.Icon = [System.Drawing.Icon]::FromHandle((New-Object System.Drawing.Bitmap($ib, 32, 32)).GetHicon())
} catch { $null = $_ }   # a logo System.Drawing cannot read keeps the default icon
$ui.Form.SuspendLayout()
$ui.Form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96); $ui.Form.AutoScaleMode = 'Dpi'   # sizes below are at 100 % scaling
# @@UI@@
$ui.Form.ClientSize = New-Object System.Drawing.Size(1020, 760)   # at 100 %; the minimum size is set when the window has its scale (Shown)
$ui.Form.StartPosition = 'CenterScreen'; $ui.Form.KeyPreview = $true; $ui.Form.BackColor = $ui.C.White
$ui.Form.ShowInTaskbar = $true; $ui.Form.MinimizeBox = $true   # its own taskbar button: a minimized window can be restored (R24)

