param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$assetRoot = Join-Path $ProjectRoot "assets"
$outputPath = Join-Path $ProjectRoot "gdd\project-data.js"
$supportedExtensions = @(".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp")

Add-Type -AssemblyName System.Drawing

function Get-ImageDimensions {
    param([string]$Path)

    try {
        $image = [System.Drawing.Image]::FromFile($Path)
        try {
            return @($image.Width, $image.Height)
        }
        finally {
            $image.Dispose()
        }
    }
    catch {
        return @(0, 0)
    }
}

function Get-CatalogGroup {
    param([string]$RelativePath)

    $normalized = $RelativePath.ToLowerInvariant()
    if ($normalized -match '^assets/generated/sprites/\.sprite-skeleton/') { return "production" }
    if ($normalized -match '^assets/(characters|enemies)/' -or $normalized -match '^assets/generated/sprites/') { return "characters" }
    if ($normalized -match '^assets/buildings/') { return "buildings" }
    if ($normalized -match '^assets/(items|loot|equipment|weapons)/') { return "items" }
    if ($normalized -match '^assets/ui/') { return "ui" }
    if ($normalized -match '^assets/vehicles/') { return "vehicles" }
    if ($normalized -match '^assets/interiors/') { return "interiors" }
    if ($normalized -match '^assets/(tiles|backgrounds|landmarks|environment)/') { return "world" }
    if ($normalized -match '^assets/(props|events|lore|extraction)/') { return "props" }
    if ($normalized -match '^assets/opening/') { return "cinematics" }
    if ($normalized -match '^assets/generated/') { return "production" }
    return "other"
}

function Get-CharacterId {
    param([string]$RelativePath)

    $path = $RelativePath.ToLowerInvariant()
    if ($path -match '^assets/characters/(cat_8way|cat_melee|cat_roll|loaf)/' -or
        $path -match '^assets/generated/sprites/(cat_8way|cat_demo|cat_left|character|character-2|character-3|character-4|character-10)/') { return "yunseo" }
    if ($path -match '^assets/characters/female_cat_companion/') { return "seorin" }
    if ($path -match '^assets/characters/cowering_resident/') { return "moka" }
    if ($path -match '^assets/characters/worker_cat/' -or $path -match '^assets/generated/sprites/(1|character-6|character-8)/') { return "dodam" }
    if ($path -match '^assets/characters/merchant_cat/') { return "jango" }
    if ($path -match '^assets/generated/sprites/character-5/' -or $path -match '^assets/enemies/character_5/') { return "bonggu" }
    if ($path -match '^assets/generated/sprites/character-7/') { return "lumi" }
    if ($path -match '^assets/generated/sprites/character-11/') { return "gangcheol" }
    if ($path -match '^assets/generated/sprites/character-12/') { return "tani" }
    if ($path -match '^assets/generated/sprites/character-9/' -or $path -match '^assets/enemies/rocket_boss/') { return "pohwa" }
    if ($path -match '^assets/generated/sprites/enemy_grenadier/') { return "pin" }
    if ($path -match '^assets/generated/sprites/npc/') { return "danpung" }
    if ($path -match '^assets/characters/survivor_') { return "hana" }
    if ($path -match '^assets/enemies/enemy_pistol') { return "raider_marksman" }
    if ($path -match '^assets/enemies/enemy_melee') { return "raider_bruiser" }
    return "unassigned"
}

$assets = @()
$imageFiles = Get-ChildItem -LiteralPath $assetRoot -Recurse -File | Where-Object {
    $supportedExtensions -contains $_.Extension.ToLowerInvariant() -and
    $_.FullName -notmatch '[\\/]\.frames\.sg-staging[\\/]'
}

foreach ($file in $imageFiles) {
    $relativePath = $file.FullName.Substring($ProjectRoot.Length + 1).Replace("\", "/")
    $assetRelative = $file.FullName.Substring($assetRoot.Length + 1)
    $segments = $assetRelative -split "[\\/]"
    $category = if ($segments.Count -gt 1) { $segments[0] } else { "uncategorized" }
    $dimensions = Get-ImageDimensions -Path $file.FullName

    $assets += [ordered]@{
        name = $file.Name
        path = $relativePath
        category = $category
        catalog_group = Get-CatalogGroup -RelativePath $relativePath
        character_id = Get-CharacterId -RelativePath $relativePath
        ext = $file.Extension.TrimStart(".").ToLowerInvariant()
        bytes = $file.Length
        kb = [math]::Round($file.Length / 1KB, 1)
        width = $dimensions[0]
        height = $dimensions[1]
        modified = $file.LastWriteTime.ToString("yyyy-MM-dd")
    }
}

$assets = @($assets | Sort-Object category, name, path)
$runtimeImages = @($assets | Where-Object {
    $_.path -notmatch "/generated/" -and $_.path -notmatch "(?i)reference|source|request|raw"
}).Count

$projectVersion = "4.5.1"
$projectFile = Join-Path $ProjectRoot "project.godot"
if (Test-Path -LiteralPath $projectFile) {
    $featureLine = Select-String -LiteralPath $projectFile -Pattern 'config/features=' | Select-Object -First 1
    if ($featureLine -and $featureLine.Line -match '"([0-9]+\.[0-9]+)"') {
        $projectVersion = $Matches[1]
    }
}

$payload = [ordered]@{
    generated_at = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    project = [ordered]@{
        name = "Grey Dawn: Seoul Survival Cats"
        godot_version = $projectVersion
    }
    stats = [ordered]@{
        images = $assets.Count
        runtime_images = $runtimeImages
        scripts = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot "scripts") -File -Filter "*.gd").Count
        scenes = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot "scenes") -Recurse -File -Filter "*.tscn").Count
        tests = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot "tests") -File -Filter "*_test.gd").Count
        asset_categories = @($assets.category | Sort-Object -Unique).Count
    }
    assets = $assets
}

$json = $payload | ConvertTo-Json -Depth 6 -Compress
$javascript = "window.PROJECT_DATA = $json;"
[System.IO.File]::WriteAllText($outputPath, $javascript, [System.Text.UTF8Encoding]::new($false))

Write-Output "GDD catalog updated: $($assets.Count) image assets"
Write-Output $outputPath
