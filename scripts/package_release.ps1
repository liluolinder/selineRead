# 打包一个「双击即可运行」的 Windows release。
#
# 产出：
#   dist\SelineRead-<version>-win64\      （可直接拷走的目录）
#   dist\SelineRead-<version>-win64.zip   （分发用压缩包）
#
# 包含运行时所需的全部非系统 DLL：
#   - 仓颉运行时：libcangjie-runtime.dll / libboundscheck.dll
#   - SDL：SDL3.dll / SDL3_ttf.dll
#   - OpenSSL：libssl-3-x64.dll / libcrypto-3-x64.dll（从本机 System32 取，3.x）
#   - VC 运行时：VCRUNTIME140.dll
#   - assets\：窗口图标 + 默认封面
#
# 目标机不需要安装仓颉 SDK：Windows 会优先从 exe 所在目录加载这些 DLL。

param(
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrEmpty($OutputRoot)) {
    $OutputRoot = Join-Path $root "dist"
}

# ---------- 版本号 ----------
$toml = Get-Content (Join-Path $root "cjpm.toml") -Raw
$version = "0.0.0"
# 注意别匹配到 `cjc-version`；只认行首的 version
if ($toml -match '(?m)^\s*version\s*=\s*"([^"]+)"') { $version = $Matches[1] }
$hash = (git -C $root rev-parse --short HEAD 2>$null)
if ([string]::IsNullOrEmpty($hash)) { $hash = "nogit" }
$name = "SelineRead-$version-$hash-win64"

# ---------- 构建 ----------
Write-Host "== build =="
& (Join-Path $root "build.ps1")
if ($LASTEXITCODE -ne 0) { throw "build failed: $LASTEXITCODE" }

$bin = Join-Path $root "target\release\bin"
$runtime = "C:\Program\SDK\Cangjie\runtime\lib\windows_x86_64_cjnative"
$sdl = Join-Path $root "..\chui\sdl\.sdl3"
$system32 = Join-Path $env:WINDIR "System32"

# ---------- 组装目录 ----------
$stage = Join-Path $OutputRoot $name
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

function Copy-Needed([string]$source, [string]$targetName = "") {
    if (-not (Test-Path $source)) { throw "missing dependency: $source" }
    if ([string]::IsNullOrEmpty($targetName)) { $targetName = Split-Path $source -Leaf }
    Copy-Item $source (Join-Path $stage $targetName) -Force
    Write-Host ("  + " + $targetName)
}

# 主程序（改个像样的名字；资源按 exe 同目录的 assets\ 解析，与文件名无关）
Copy-Needed (Join-Path $bin "main.exe") "SelineRead.exe"

# 仓颉运行时
Copy-Needed (Join-Path $runtime "libcangjie-runtime.dll")
Copy-Needed (Join-Path $runtime "libboundscheck.dll")

# SDL
Copy-Needed (Join-Path $sdl "SDL3.dll")
Copy-Needed (Join-Path $sdl "SDL3_ttf.dll")

# OpenSSL（3.x，libssl 依赖 libcrypto）
Copy-Needed (Join-Path $system32 "libssl-3-x64.dll")
Copy-Needed (Join-Path $system32 "libcrypto-3-x64.dll")

# VC 运行时（OpenSSL 依赖）
Copy-Needed (Join-Path $system32 "VCRUNTIME140.dll")

# 资源
$assets = Join-Path $root "assets"
if (Test-Path $assets) {
    $targetAssets = Join-Path $stage "assets"
    New-Item -ItemType Directory -Force -Path $targetAssets | Out-Null
    Copy-Item (Join-Path $assets "*") $targetAssets -Force
    Write-Host "  + assets\"
}

# 说明文件（UTF-8 BOM，记事本可直接看）
$readme = @"
Seline Read $version ($hash)

== 运行 ==
双击 SelineRead.exe 即可。本目录里的 DLL 已包含全部运行库（仓颉运行时、SDL、OpenSSL、VC 运行时），
不需要安装仓颉 SDK，也不要移动或删除这些 DLL。

== 要求 ==
Windows 10 / 11 64 位。

== 数据位置 ==
- 账号与设置：%USERPROFILE%\seline_read\
- 封面缓存与调试日志：%TEMP%\SelineRead\ 、%TEMP%\seline_read_debug.log

== 卸载 ==
直接删除本目录；如需清干净，再删掉上面两个数据目录。
"@
$readmePath = Join-Path $stage "README.txt"
[System.IO.File]::WriteAllText($readmePath, $readme, (New-Object System.Text.UTF8Encoding($true)))
Write-Host "  + README.txt"

# ---------- 压缩 ----------
$zip = Join-Path $OutputRoot ($name + ".zip")
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip -CompressionLevel Optimal
Write-Host "== done =="

# ---------- 报告 ----------
$dirSize = (Get-ChildItem $stage -Recurse -File | Measure-Object -Property Length -Sum).Sum
$zipItem = Get-Item $zip
Write-Host ("dir : {0}  ({1:N1} MB)" -f $stage, ($dirSize / 1MB))
Write-Host ("zip : {0}  ({1:N1} MB)" -f $zip, ($zipItem.Length / 1MB))
Write-Host ("sha256: " + (Get-FileHash $zip -Algorithm SHA256).Hash)
Get-ChildItem $stage -Recurse -File |
    Sort-Object FullName |
    ForEach-Object { "  {0,10:N0}  {1}" -f $_.Length, $_.FullName.Substring($stage.Length + 1) }
