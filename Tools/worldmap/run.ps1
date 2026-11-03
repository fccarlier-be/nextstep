<#
.SYNOPSIS
    Extracts the world map overlay tables from the local WoW Forever install and
    generates the "map without fog" data of NextStep.

.DESCRIPTION
    1. Downloads TACTSharp (pinned commit) and builds its TACTTool CLI.
    2. Downloads the WoWDBDefs definitions of the two tables (pinned commit).
    3. TACTTool reads WorldMapOverlay.db2 and WorldMapOverlayTile.db2 from the local
       CASC storage (read only; missing files come from Blizzard's CDN into the cache).
    4. Export (DBCD) decodes them into TSV files.
    5. generate.lua writes addon\NextStep\Data\Imported\Client\MapOverlays.lua and
       Tools\worldmap\last-import.md.
    6. Tools\check.ps1 runs luacheck and the out-of-game tests.
    Everything downloaded or built goes to Tools\worldmap\cache (ignored by git).
    Requires the .NET 10 SDK, git and Tools\setup.ps1 (LuaJIT, luacheck).
    Pausing a running game download is advised: the storage is read while it runs.

.PARAMETER GameDir
    The World of Warcraft folder containing .build.info (parent of _forever_).

.EXAMPLE
    .\Tools\worldmap\run.ps1
#>
param(
    [string]$GameDir = "C:\Program Files (x86)\World of Warcraft"
)
$ErrorActionPreference = "Stop"

$lock = @{}
foreach ($line in Get-Content (Join-Path $PSScriptRoot "worldmap.lock")) {
    if ($line -match "^\s*([^#=]+?)\s*=\s*(.+?)\s*$") { $lock[$Matches[1]] = $Matches[2] }
}

$dotnet = (Get-Command dotnet -ErrorAction SilentlyContinue).Source
if (-not $dotnet) { $dotnet = Join-Path $env:ProgramFiles "dotnet\dotnet.exe" }
if (-not (Test-Path $dotnet)) { throw ".NET SDK not found: install the .NET 10 SDK (winget install Microsoft.DotNet.SDK.10)." }

# Version installée : les définitions de WoWDBDefs doivent la couvrir.
$buildInfo = Join-Path $GameDir ".build.info"
if (-not (Test-Path $buildInfo)) { throw "No .build.info in $GameDir (use -GameDir)." }
$infoLines = Get-Content $buildInfo
$header = $infoLines[0].Split("|") | ForEach-Object { $_.Split("!")[0] }
$entry = $infoLines | Select-Object -Skip 1 | ForEach-Object {
    $values = $_.Split("|"); $row = @{}
    for ($i = 0; $i -lt $header.Count; $i++) { $row[$header[$i]] = $values[$i] }
    $row
} | Where-Object { $_.Product -eq $lock.product } | Select-Object -First 1
if (-not $entry) { throw "Product $($lock.product) not installed in $GameDir." }
if ($entry.Version -ne $lock.build) {
    throw "Installed client is $($entry.Version), worldmap.lock expects $($lock.build): check that WoWDBDefs covers it, then update the lock."
}

$cache = Join-Path $PSScriptRoot "cache"
New-Item -ItemType Directory -Force -Path $cache | Out-Null

# 1. TACTSharp
$tact = Join-Path $cache "TACTSharp"
if (-not (Test-Path (Join-Path $tact ".git"))) {
    New-Item -ItemType Directory -Force -Path $tact | Out-Null
    git -C $tact init --quiet
    git -C $tact remote add origin $lock.tactsharp
}
Write-Host "Fetching TACTSharp ($($lock.tactsharp_commit))..."
git -C $tact fetch --quiet --depth 1 origin $lock.tactsharp_commit
if ($LASTEXITCODE -ne 0) { throw "git fetch failed" }
git -C $tact checkout --quiet --force FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "git checkout failed" }
$tactBin = Join-Path $cache "bin\TACTTool"
& $dotnet build (Join-Path $tact "TACTTool") -c Release -o $tactBin --nologo -v quiet
if ($LASTEXITCODE -ne 0) { throw "TACTTool build failed" }

# 2. WoWDBDefs
$defs = Join-Path $cache "definitions"
New-Item -ItemType Directory -Force -Path $defs | Out-Null
foreach ($table in "WorldMapOverlay", "WorldMapOverlayTile") {
    $url = "https://raw.githubusercontent.com/wowdev/WoWDBDefs/$($lock.wowdbdefs_commit)/definitions/$table.dbd"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile (Join-Path $defs "$table.dbd")
}

# 3. Extraction (TACTTool écrit son propre cache dans le dossier courant)
$db2 = Join-Path $cache "db2"
New-Item -ItemType Directory -Force -Path $db2 | Out-Null
$list = Join-Path $cache "files.txt"
@(
    "$($lock.fdid_WorldMapOverlay);WorldMapOverlay.db2",
    "$($lock.fdid_WorldMapOverlayTile);WorldMapOverlayTile.db2"
) | Set-Content -Encoding ascii $list
foreach ($table in "WorldMapOverlay", "WorldMapOverlayTile") { Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $db2 "$table.db2") }
Push-Location $cache
try {
    & (Join-Path $tactBin "TACTTool.exe") -p $lock.product -r $lock.region -d $GameDir -m list -i $list -o $db2
    if ($LASTEXITCODE -ne 0) { throw "TACTTool failed" }
} finally {
    Pop-Location
}
foreach ($table in "WorldMapOverlay", "WorldMapOverlayTile") {
    if (-not (Test-Path (Join-Path $db2 "$table.db2"))) { throw "$table.db2 was not extracted." }
}

# 4. Décodage
$tsv = Join-Path $cache "tsv"
& $dotnet run --project (Join-Path $PSScriptRoot "Export") -c Release --nologo -v quiet -- $db2 $defs $lock.build $tsv
if ($LASTEXITCODE -ne 0) { throw "Export failed" }

# 5. Données de l'addon, puis 6. vérifications
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $root
try {
    $luajit = (Get-Command luajit -ErrorAction SilentlyContinue).Source
    if (-not $luajit) { $luajit = Join-Path $env:LOCALAPPDATA "Programs\LuaJIT\bin\luajit.exe" }
    New-Item -ItemType Directory -Force -Path "addon\NextStep\Data\Imported\Client" | Out-Null
    & $luajit Tools/worldmap/generate.lua $tsv Tools/worldmap/worldmap.lock
    if ($LASTEXITCODE -ne 0) { throw "generate failed" }

    & (Join-Path $PSScriptRoot "..\check.ps1")
    if ($LASTEXITCODE -ne 0) { throw "checks failed" }
} finally {
    Pop-Location
}
