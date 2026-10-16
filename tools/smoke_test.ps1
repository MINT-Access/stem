# ================================================================
# tools/smoke_test.ps1 — the Windows form of tools/smoke_test.sh: run
# tools/smoke_test.wl so that the report says how the run ended, even when
# the Wolfram kernel dies.
#
# Usage (Windows PowerShell or PowerShell 7; options go to smoke_test.wl):
#   powershell -ExecutionPolicy Bypass -File tools\smoke_test.ps1
#   powershell -ExecutionPolicy Bypass -File tools\smoke_test.ps1 --quick
#   powershell -ExecutionPolicy Bypass -File tools\smoke_test.ps1 --resume
#
# - The console is written to smoke_console_<...>.txt next to the report
#   and echoed here as it grows.
# - Every 10 s while wolframscript runs, smoke_heartbeat_<...>.txt next to
#   the report gets the local time, the seconds since the start and the
#   app being run (the console's last "running <app> ..." line).
# - When wolframscript ends, one line is appended to the report, e.g.
#     The smoke test process ended at 01:52 with exit code -1073741819
#     (0xC0000005, access violation) after 2103 s.
#   Windows has no signals; a crashed process ends with an NTSTATUS code,
#   named here for the common ones. If the report already ends with its
#   Summary line, only the end time is appended.
# Not yet run on Windows (written on macOS, 2026-10-16).
# ================================================================

$here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$root  = Split-Path -Parent $here
$start = Get-Date
$out   = ($args | Where-Object { $_ -like '--out=*' } | Select-Object -First 1)
if ($out) { $out = $out.Substring(6) }

function Get-ReportPath {
  if ($out) { if (Test-Path $out) { return (Resolve-Path $out).Path } else { return $null } }
  Get-ChildItem -Path $root -Filter 'smoke_test_*.txt' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $start.AddSeconds(-1) } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}

function Get-Sibling([string]$report, [string]$kind) {
  $dir = Split-Path -Parent $report; $base = [IO.Path]::GetFileNameWithoutExtension($report)
  if ($base -like 'smoke_test_*') { return (Join-Path $dir ("smoke_{0}_{1}.txt" -f $kind, $base.Substring(11))) }
  return (Join-Path $dir ("{0}.{1}.txt" -f $base, $kind))
}

function Get-ExitText([int]$code) {
  $hex = '0x{0:X8}' -f $code
  $names = @{ '0xC0000005' = 'access violation'; '0xC00000FD' = 'stack overflow';
              '0xC0000409' = 'stack buffer overrun'; '0xC000001D' = 'illegal instruction';
              '0xC0000017' = 'out of memory'; '0xC000013A' = 'interrupted with Ctrl+C';
              '0x40010004' = 'terminated by the debugger or the system' }
  if ($names.ContainsKey($hex)) { return " ($hex, $($names[$hex]))" }
  return ''
}

$tmpOut = [IO.Path]::GetTempFileName(); $tmpErr = [IO.Path]::GetTempFileName()
$wsArgs = @('-file', "`"$(Join-Path $here 'smoke_test.wl')`"", '--') + ($args | ForEach-Object { "`"$_`"" })
$p = Start-Process -FilePath 'wolframscript' -ArgumentList $wsArgs -NoNewWindow -PassThru `
       -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr
$null = $p.Handle   # keeps ExitCode available after the process ends

$report = $null; $shown = 0
while (-not $p.HasExited) {
  if (-not $report) { $report = Get-ReportPath }
  $lines = @(Get-Content -LiteralPath $tmpOut -ErrorAction SilentlyContinue)
  if ($lines.Count -gt $shown) { $lines[$shown..($lines.Count - 1)] | Write-Host; $shown = $lines.Count }
  if ($report) {
    $app = ($lines | Select-String -Pattern 'running (\S+)' | Select-Object -Last 1)
    $app = if ($app) { $app.Matches[0].Groups[1].Value } else { 'the environment checks' }
    '{0} alive, {1} s since the start; running {2} (wolframscript pid {3})' -f `
      (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), [int]((Get-Date) - $start).TotalSeconds, $app, $p.Id |
      Set-Content -LiteralPath (Get-Sibling $report 'heartbeat') -Encoding UTF8
  }
  for ($i = 0; $i -lt 10 -and -not $p.HasExited; $i++) { Start-Sleep -Seconds 1 }
}
$p.WaitForExit(); $code = $p.ExitCode
$lines = @(Get-Content -LiteralPath $tmpOut -ErrorAction SilentlyContinue)
if ($lines.Count -gt $shown) { $lines[$shown..($lines.Count - 1)] | Write-Host }

$endHM = Get-Date -Format 'HH:mm'; $secs = [int]((Get-Date) - $start).TotalSeconds
if (-not $report) { $report = Get-ReportPath }
if (-not $report) {
  $report = Join-Path $root ("smoke_wrapper_{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HHmm'))
  "No report was written by this run; the wrapper's line goes to $report." | Tee-Object -FilePath $report -Append
}
Get-Content -LiteralPath $tmpOut, $tmpErr -ErrorAction SilentlyContinue |
  Set-Content -LiteralPath (Get-Sibling $report 'console') -Encoding UTF8
Remove-Item -LiteralPath $tmpOut, $tmpErr -ErrorAction SilentlyContinue

if (Select-String -LiteralPath $report -Pattern '^Summary: ' -Quiet) {
  $line = "The smoke test process ended at $endHM."
} else {
  $line = "The smoke test process ended at $endHM with exit code $code$(Get-ExitText $code) after $secs s."
}
Add-Content -LiteralPath $report -Value $line -Encoding UTF8
'{0} ended: {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $line |
  Set-Content -LiteralPath (Get-Sibling $report 'heartbeat') -Encoding UTF8
Write-Host $line
Write-Host "Report: $report"
exit $code
