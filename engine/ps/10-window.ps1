# RADE engine part 10, the window slot: the window parts (engine/ps/window) are put in here when the bundle
# is built. If the window cannot open, the round falls back to text mode (11-text-mode.ps1).
# Joined into every bundle by engine/rade_build.py; Windows PowerShell 5.1.

if ($gui) {
  $script:dpiOld = [IntPtr]::Zero   # set by window part 01 when it changes the thread's dpi awareness
  try {
    # @@WINDOW@@
  } catch {
    $gui = $false; $script:noWindowWhy = [string]$_.Exception.Message
    if ($_.InvocationInfo) { $script:noWindowWhy += ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')' }
    $shown = $script:noWindowWhy
    if ($env:USERPROFILE) { $shown = $shown -replace [regex]::Escape([string]$env:USERPROFILE), 'C:\Users\<DODID>' }
    Write-Host ('No window could open (' + (ConvertTo-Masked $shown) + '). The round runs in text mode.')
  } finally {
    # R34 (review of PR 124): the thread's own dpi awareness comes back also when the window failed (window part 01 changed it).
    if ($script:dpiOld -ne [IntPtr]::Zero) {
      try { $null = [Rade.Dpi]::SetThreadDpiAwarenessContext($script:dpiOld) } catch { $null = $_ }   # a failure leaves the closed window's setting
      $script:dpiOld = [IntPtr]::Zero }
  }
}
