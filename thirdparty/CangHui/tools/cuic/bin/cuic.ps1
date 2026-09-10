param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CliArgs)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Binary = Join-Path $Root "target/release/bin/main.exe"
$NeedsBuild = -not (Test-Path $Binary)

if (-not $NeedsBuild) {
    $BinaryTime = (Get-Item $Binary).LastWriteTimeUtc
    $Manifest = Get-Item (Join-Path $Root "cjpm.toml")
    $NewerSource = Get-ChildItem (Join-Path $Root "src") -File -Recurse |
        Where-Object { $_.LastWriteTimeUtc -gt $BinaryTime } |
        Select-Object -First 1
    $NeedsBuild = $Manifest.LastWriteTimeUtc -gt $BinaryTime -or $null -ne $NewerSource
}

if ($NeedsBuild) {
    Push-Location $Root
    try {
        & cjpm build
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally { Pop-Location }
}

$env:CANGHUI_CLI_ROOT = $Root
& $Binary @CliArgs
exit $LASTEXITCODE
