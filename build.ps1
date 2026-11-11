# 构建辅助：先杀掉残留进程再编译。
#
# `main.exe` 还在运行时链接器无法覆盖它，报
# `ld.lld: error: failed to write the output file: Permission denied`，
# 容易被误判成代码错误。编译完把 SDL3 运行库复制到可执行文件旁。
param([switch]$Test)
Get-Process -Name main -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 700
$env:PATH = "C:\Program\SDK\Cangjie\runtime\lib\windows_x86_64_cjnative;$env:PATH"
if ($Test) {
    cjpm test --no-progress
    exit $LASTEXITCODE
}
cjpm build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$bin = Join-Path $PSScriptRoot "target\release\bin"
$sdl = Join-Path $PSScriptRoot "..\chui\sdl\.sdl3"
foreach ($dll in @("SDL3.dll", "SDL3_ttf.dll")) {
    $source = Join-Path $sdl $dll
    if (Test-Path $source) { Copy-Item $source $bin -Force }
}
Write-Output "build ok: $bin\main.exe"
