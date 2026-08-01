param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[A-Za-z0-9_-]+$")]
    [string]$CharacterId,

    [string]$BaseImage,
    [string]$Description = "",
    [string]$RunDir,
    [string]$RequestJson,
    [string]$ReferenceRun = "assets\generated\sprite_reference_packs\8way_cat_player_validated",
    [string]$Python,
    [ValidateSet("none", "codex", "grok")]
    [string]$Provider = "none",
    [int]$CellSize = 256,
    [int]$SafeMargin = 24,
    [ValidateSet("components", "projection")]
    [string]$Segmentation,
    [switch]$AllowSlotFallback,
    [string]$WalkQaState,
    [switch]$SkipPrepare,
    [switch]$PrepareOnly,
    [switch]$SkipPreview,
    [switch]$SkipQa,
    [switch]$OpenCuration,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$spriteGenRoot = Join-Path $projectRoot "tools\sprite-gen"
$prepareScript = Join-Path $spriteGenRoot "scripts\prepare_sprite_run.py"
$generateScript = Join-Path $spriteGenRoot "scripts\generate_sprite_image.py"
$extractScript = Join-Path $spriteGenRoot "scripts\extract_sprite_row_frames.py"
$previewScript = Join-Path $spriteGenRoot "scripts\preview_animation.py"
$composeScript = Join-Path $spriteGenRoot "scripts\compose_sprite_atlas.py"
$inspectScript = Join-Path $spriteGenRoot "scripts\inspect_sprite_run.py"
$scoreScript = Join-Path $spriteGenRoot "scripts\score_sprite_run.py"
$curationScript = Join-Path $spriteGenRoot "scripts\serve_curation.py"

if (-not (Test-Path $spriteGenRoot)) {
    throw "Vendored sprite-gen engine is missing: $spriteGenRoot"
}

if ([string]::IsNullOrWhiteSpace($Python)) {
    $venvPython = Join-Path $projectRoot ".venv-sprite-gen\Scripts\python.exe"
    $Python = if (Test-Path $venvPython) { $venvPython } else { "python" }
}
if (-not (Test-Path $Python) -and -not (Get-Command $Python -ErrorAction SilentlyContinue)) {
    throw "Python 3.10+ is required. Run tools\setup_sprite_pipeline.ps1 or install Python."
}

if ([string]::IsNullOrWhiteSpace($RunDir)) {
    $RunDir = Join-Path $projectRoot ("assets\generated\sprites\" + $CharacterId)
} elseif (-not [IO.Path]::IsPathRooted($RunDir)) {
    $RunDir = Join-Path $projectRoot $RunDir
}
$RunDir = [IO.Path]::GetFullPath($RunDir)

function Get-RelativePath {
    param([string]$BasePath, [string]$TargetPath)
    $baseUri = [Uri](([IO.Path]::GetFullPath($BasePath).TrimEnd('\') + '\'))
    $targetUri = [Uri]([IO.Path]::GetFullPath($TargetPath))
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', '\')
}

function Invoke-SpriteGen {
    param([string]$Script, [string[]]$Arguments)
    Write-Host ("> " + $Python + " " + (Get-RelativePath $projectRoot $Script) + " " + ($Arguments -join " ")) -ForegroundColor DarkGray
    & $Python $Script @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "sprite-gen stage failed ($LASTEXITCODE): $([IO.Path]::GetFileName($Script))"
    }
}

function Install-DirectionalReferencePack {
    param([string]$SourcePath, [string]$TargetRun)
    if ([string]::IsNullOrWhiteSpace($SourcePath)) { return }
    $source = $SourcePath
    if (-not [IO.Path]::IsPathRooted($source)) { $source = Join-Path $projectRoot $source }
    $source = [IO.Path]::GetFullPath($source)
    if (-not (Test-Path $source -PathType Container)) {
        Write-Host "Directional reference pack not found; continuing without it: $source" -ForegroundColor Yellow
        return
    }
    $anchorDir = Join-Path $TargetRun "references\anchors"
    New-Item -ItemType Directory -Force -Path $anchorDir | Out-Null
    $directions = @("down", "down_right", "right", "up_right", "up", "up_left", "left", "down_left")
    $copied = 0
    foreach ($direction in $directions) {
        $candidate = Join-Path $source ("{0}_idle.png" -f $direction)
        if (-not (Test-Path $candidate)) {
            $candidate = Join-Path $source ("{0}_idle-frame-0.png" -f $direction)
        }
        if (Test-Path $candidate) {
            Copy-Item -LiteralPath $candidate -Destination (Join-Path $anchorDir ("{0}_idle.png" -f $direction)) -Force
            $copied++
        }
        $walkCandidate = Join-Path $source ("{0}_walk.png" -f $direction)
        if (Test-Path $walkCandidate) {
            Copy-Item -LiteralPath $walkCandidate -Destination (Join-Path $anchorDir ("{0}_walk.png" -f $direction)) -Force
            $copied++
        }
    }
    if ($copied -gt 0) {
        $metadata = @{
            version = 1
            source = $source
            purpose = "direction-and-layout-only"
            directions = $directions
            copiedAt = (Get-Date).ToUniversalTime().ToString("o")
        }
        $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $TargetRun "references\reference-pack.json") -Encoding UTF8
        Write-Host "Attached $copied directional reference anchors from $source" -ForegroundColor DarkGray
    }
}

if (-not $SkipPrepare) {
    if (-not $RequestJson -and [string]::IsNullOrWhiteSpace($BaseImage)) {
        throw "BaseImage is required for a new run. Use -RequestJson for a custom request or -SkipPrepare for an existing run."
    }

    $prepareArgs = @("--out-dir", $RunDir, "--character-id", $CharacterId, "--cell-size", $CellSize, "--safe-margin", $SafeMargin)
    if ($Force) { $prepareArgs += "--force" }
    if ($RequestJson) {
        $requestPath = $RequestJson
        if (-not [IO.Path]::IsPathRooted($requestPath)) { $requestPath = Join-Path $projectRoot $requestPath }
        $prepareArgs += @("--request", ([IO.Path]::GetFullPath($requestPath)))
        if ($BaseImage) {
            $basePath = $BaseImage
            if (-not [IO.Path]::IsPathRooted($basePath)) { $basePath = Join-Path $projectRoot $basePath }
            if (-not (Test-Path $basePath)) { throw "Base image not found: $basePath" }
            $prepareArgs += @("--base-image", ([IO.Path]::GetFullPath($basePath)))
        }
    } else {
        $basePath = $BaseImage
        if (-not [IO.Path]::IsPathRooted($basePath)) { $basePath = Join-Path $projectRoot $basePath }
        if (-not (Test-Path $basePath)) { throw "Base image not found: $basePath" }
        $prepareArgs += @("--base-image", ([IO.Path]::GetFullPath($basePath)))
        if ($Description) { $prepareArgs += @("--description", $Description) }
    }
    Invoke-SpriteGen $prepareScript $prepareArgs
    Install-DirectionalReferencePack -SourcePath $ReferenceRun -TargetRun $RunDir
    if ($PrepareOnly) {
        Write-Host "Run prepared. Add row PNGs under $RunDir\raw, then rerun with -SkipPrepare." -ForegroundColor Green
        exit 0
    }
}

if (-not (Test-Path (Join-Path $RunDir "sprite-request.json"))) {
    throw "Run directory is not prepared: $RunDir"
}

Install-DirectionalReferencePack -SourcePath $ReferenceRun -TargetRun $RunDir

if ($Provider -ne "none") {
    $promptRoot = Join-Path $RunDir "prompts"
    $baseSource = Get-ChildItem (Join-Path $RunDir "base-source.*") -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $requestData = Get-Content (Join-Path $RunDir "sprite-request.json") -Raw | ConvertFrom-Json
    $directionSet = @($requestData.directions.set)
    $prompts = Get-ChildItem $promptRoot -Filter "*.txt" -Recurse -File
    if (-not $prompts) { throw "No prompts found under $promptRoot" }

    foreach ($prompt in $prompts) {
        $relative = Get-RelativePath $promptRoot $prompt.FullName
        # Windows PowerShell leaves a trailing dot when ChangeExtension(..., $null)
        # is used. Strip the known prompt extension explicitly so nested states
        # become raw\down\idle.png instead of raw\down\idle..png.
        $state = $relative.Substring(0, $relative.Length - $prompt.Extension.Length)
        $rawPath = Join-Path (Join-Path $RunDir "raw") ($state + ".png")
        $guidePath = Join-Path (Join-Path $RunDir "references\layout-guides") ($state + ".png")
        $genArgs = @("--provider", $Provider, "--prompt-file", $prompt.FullName, "--out", $rawPath, "--report", ($rawPath + ".report.json"))
        # The uploaded/generated base is the only colour identity reference.
        # Never replace it with a raw directional anchor or a shared reference
        # pack: those files can belong to another character and the image
        # provider cannot reliably infer their intended role from pixels.
        if ($baseSource) { $genArgs += @("--ref", $baseSource.FullName) }
        $direction = $null
        if ($directionSet.Count -gt 0) {
            $direction = $directionSet | Where-Object { $state.StartsWith("$_`_") } | Sort-Object Length -Descending | Select-Object -First 1
        }
        if (Test-Path $guidePath) { $genArgs += @("--ref", $guidePath) }
        Invoke-SpriteGen $generateScript $genArgs
    }
} else {
    $rawImages = Get-ChildItem (Join-Path $RunDir "raw") -Filter "*.png" -Recurse -File -ErrorAction SilentlyContinue
    if (-not $rawImages) {
        throw "Provider is 'none' and no raw row PNGs exist. Add generated rows under $RunDir\raw or choose -Provider codex/grok."
    }
    Write-Host "Using existing raw rows ($($rawImages.Count) PNGs)." -ForegroundColor DarkGray
}

$extractArgs = @("--run-dir", $RunDir)
if ($Segmentation) { $extractArgs += @("--segmentation", $Segmentation) }
if ($AllowSlotFallback) { $extractArgs += "--allow-slot-fallback" }
Invoke-SpriteGen $extractScript $extractArgs
if (-not $SkipPreview) { Invoke-SpriteGen $previewScript @("--run-dir", $RunDir) }
Invoke-SpriteGen $composeScript @("--run-dir", $RunDir)

if (-not $SkipQa) {
    Invoke-SpriteGen $inspectScript @("--run-dir", $RunDir)
    $inspectReport = Join-Path $RunDir "sprite-inspect.report.json"
    if (Test-Path $inspectReport) {
        Invoke-SpriteGen $scoreScript @("--inspect-report", $inspectReport)
    }
}

if ($WalkQaState) {
    $walkQaScript = Join-Path $projectRoot "tools\qa_walk_cycle.py"
    Invoke-SpriteGen $walkQaScript @("--run-dir", $RunDir, "--state", $WalkQaState)
}

if ($OpenCuration) {
    Start-Process $Python -ArgumentList @($curationScript, "--run-dir", $RunDir, "--port", "0", "--lang", "ko")
}

Write-Host "Sprite pipeline complete." -ForegroundColor Green
Write-Host "Run:      $RunDir"
Write-Host "Atlas:    $(Join-Path $RunDir 'sprite-sheet-alpha.png')"
Write-Host "Manifest: $(Join-Path $RunDir 'manifest.json')"
if ($OpenCuration) { Write-Host "Curation webview launched in a separate process." }
