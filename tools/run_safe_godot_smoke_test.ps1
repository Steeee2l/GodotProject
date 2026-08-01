param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptPath,

    [string]$GodotPath = "C:\Users\rain2\Apps\Godot_4.5.1\Godot_v4.5.1-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"

$interactiveGodot = Get-Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.ProcessName -like "Godot*" -and $_.ProcessName -notlike "*console*"
    }

if ($interactiveGodot) {
    Write-Error "Godot editor or embedded game is running. Stop it before starting a separate headless validation process."
    exit 10
}

if (-not (Test-Path -LiteralPath $GodotPath)) {
    Write-Error "Godot console executable was not found: $GodotPath"
    exit 11
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$logDirectory = Join-Path $env:TEMP "GodotProject-Codex-Logs"
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$safeName = [IO.Path]::GetFileNameWithoutExtension($ScriptPath) -replace '[^A-Za-z0-9_-]', '_'
$logPath = Join-Path $logDirectory ("{0}-{1}.log" -f $safeName, [DateTime]::Now.ToString("yyyyMMdd-HHmmss"))

& $GodotPath `
    --headless `
    --log-file $logPath `
    --path $projectRoot `
    --script $ScriptPath

exit $LASTEXITCODE
