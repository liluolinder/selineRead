<#
.SYNOPSIS
    页面压测：逐帧耗时统计（用于"哪些页面会卡"的回归测量）。

.DESCRIPTION
    启动 release 产物（`SELINE_READ_FRAME_TRACE=1`），把窗口切到前台，
    在内容区发滚轮滚动，然后从 %TEMP%\seline_read_debug.log 里读 `F <帧号> <间隔ms>`
    逐帧记录，输出 avg / p50 / p95 / p99 / max / 超过 33ms 的帧数。

    需要先在 main.cj 里带帧追踪探针（临时压测补丁），release 构建即可。

.EXAMPLE
    pwsh -NoProfile -File scripts\stress_pages.ps1 -Page home -Scroll 40
    pwsh -NoProfile -File scripts\stress_pages.ps1 -Page search -Keyword 三体 -Scroll 30
#>
param(
    [ValidateSet("home", "favorites", "booklists", "settings", "downloads", "search", "detail")]
    [string]$Page = "home",
    [string]$Keyword = "",
    [string]$BookId = "",
    [int]$Scroll = 30,
    [int]$WarmupSeconds = 9,
    [int]$SettleSeconds = 5,
    [double]$WheelStepPauseMs = 60,
    [switch]$RailToggle,
    [string]$ExeDir = ""
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
if (-not $ExeDir) { $ExeDir = Join-Path $repo "target\release\bin" }
$exe = Join-Path $ExeDir "main.exe"
if (-not (Test-Path $exe)) { throw "找不到 $exe（先 cjpm build）" }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class StressWin {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr h);
    public const uint WHEEL = 0x800;
}
'@ -ErrorAction SilentlyContinue

function Force-Foreground([IntPtr]$h) {
    $fg = [StressWin]::GetForegroundWindow()
    $fgThread = [StressWin]::GetWindowThreadProcessId($fg, [IntPtr]::Zero)
    $myThread = [StressWin]::GetCurrentThreadId()
    [void][StressWin]::AttachThreadInput($fgThread, $myThread, $true)
    [void][StressWin]::ShowWindow($h, 9)
    [void][StressWin]::SetForegroundWindow($h)
    [void][StressWin]::SetFocus($h)
    [void][StressWin]::AttachThreadInput($fgThread, $myThread, $false)
    Start-Sleep -Milliseconds 500
}

$appArgs = @("--perf", "--tab=0")
switch ($Page) {
    "home"      { $appArgs = @("--perf", "--tab=0") }
    "favorites" { $appArgs = @("--perf", "--tab=1") }
    "booklists" { $appArgs = @("--perf", "--tab=2") }
    "downloads" { $appArgs = @("--perf", "--tab=3") }
    "settings"  { $appArgs = @("--perf", "--tab=4") }
    "search"    { $appArgs = @("--perf", "--search=$Keyword") }
    "detail"    { $appArgs = @("--perf", "--book=$BookId") }
}

Get-Process main -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
$logPath = Join-Path $env:TEMP "seline_read_debug.log"
Remove-Item $logPath -ErrorAction SilentlyContinue
$env:SELINE_READ_FRAME_TRACE = "1"
$proc = Start-Process -FilePath $exe -WorkingDirectory $ExeDir -ArgumentList $appArgs -PassThru
Start-Sleep -Seconds $WarmupSeconds
if ($proc.HasExited) { throw "进程提前退出：$Page" }

$h = (Get-Process -Id $proc.Id).MainWindowHandle
Force-Foreground $h
$rect = New-Object StressWin+RECT
[void][StressWin]::GetWindowRect($h, [ref]$rect)
$cx = [int](($rect.L + $rect.R) / 2)
$cy = [int](($rect.T + $rect.B) / 2)
[void][StressWin]::SetCursorPos($cx, $cy)
Start-Sleep -Milliseconds 400

$wheelDown = [uint32]4294967176   # -120 的补码
for ($i = 0; $i -lt $Scroll; $i++) {
    [StressWin]::mouse_event([StressWin]::WHEEL, 0, 0, $wheelDown, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds $WheelStepPauseMs
}
if ($RailToggle) {
    # 点左上角"展开/收起侧栏"按钮（折叠态是 x≈36,y≈100 的箭头行）
    [void][StressWin]::SetCursorPos([int]($rect.L + 36), [int]($rect.T + 100))
    Start-Sleep -Milliseconds 350
    [StressWin]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)   # LEFTDOWN
    Start-Sleep -Milliseconds 120
    [StressWin]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)   # LEFTUP
    Start-Sleep -Milliseconds 1500
}
Start-Sleep -Seconds $SettleSeconds
$memMB = -1
$alive = -not $proc.HasExited
$q = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
if ($q) { $memMB = [math]::Round($q.PrivateMemorySize64 / 1MB, 0) }
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Remove-Item Env:SELINE_READ_FRAME_TRACE

$frames = New-Object System.Collections.Generic.List[int]
foreach ($line in (Get-Content $logPath -ErrorAction SilentlyContinue)) {
    $m = [regex]::Match($line, '^F (\d+) (\d+)$')
    if ($m.Success) { $frames.Add([int]$m.Groups[2].Value) }
}
if ($frames.Count -eq 0) {
    Write-Output "[$Page] 没有帧追踪数据（main.cj 是否带压测探针？）"
    exit 1
}
$sorted = $frames | Sort-Object
$avg = [math]::Round((($frames | Measure-Object -Average).Average), 1)
$p50 = $sorted[[int]($sorted.Count * 0.50)]
$p95 = $sorted[[Math]::Min($sorted.Count - 1, [int]($sorted.Count * 0.95))]
$p99 = $sorted[[Math]::Min($sorted.Count - 1, [int]($sorted.Count * 0.99))]
$slow = ($frames | Where-Object { $_ -gt 33 }).Count
# 前 80% 帧算滚动阶段，后 20% 算停稳阶段
$cut = [int]($frames.Count * 0.8)
$scrollPart = $frames.GetRange(0, $cut)
$idlePart = $frames.GetRange($cut, $frames.Count - $cut)
$scrollSorted = $scrollPart | Sort-Object

Write-Output ("[{0}] alive={1} mem={2}MB frames={3} avg={4}ms p50={5} p95={6} p99={7} max={8} >33ms={9} ({10}%)" -f `
    $Page, $alive, $memMB, $frames.Count, $avg, $p50, $p95, $p99, $sorted[-1], $slow,
    [math]::Round(100.0 * $slow / $frames.Count, 2))
Write-Output ("        滚动阶段: avg={0}ms p95={1} max={2} >33ms={3}" -f `
    [math]::Round((($scrollPart | Measure-Object -Average).Average), 1),
    $scrollSorted[[Math]::Min($scrollSorted.Count - 1, [int]($scrollSorted.Count * 0.95))],
    $scrollSorted[-1], (($scrollPart | Where-Object { $_ -gt 33 }).Count))
