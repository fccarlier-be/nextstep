<#
.SYNOPSIS
    Downloads the Polestar files that NextStep imports, at the commit pinned in polestar.lock.

.DESCRIPTION
    Sparse, shallow checkout into Tools\import\cache\polestar (ignored by git): only the
    compiled guide packs, the French pack, the gear weights, the item and quest databases, the walking router and its maps (Polestar_Nav*), the flight and transport tables and the licence files are downloaded.
#>
$ErrorActionPreference = "Stop"

$lock = @{}
foreach ($line in Get-Content (Join-Path $PSScriptRoot "polestar.lock")) {
    if ($line -match "^\s*([^#=]+?)\s*=\s*(.+?)\s*$") { $lock[$Matches[1]] = $Matches[2] }
}

$dest = Join-Path $PSScriptRoot "cache\polestar"
if (-not (Test-Path (Join-Path $dest ".git"))) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    git -C $dest init --quiet
    git -C $dest remote add origin $lock.repository
    git -C $dest sparse-checkout set --no-cone `
        "/LICENSE" "/THIRD_PARTY.md" `
        "/addon/Polestar_Guides/" "/addon/Polestar_Guides_Alliance/" "/addon/Polestar_Guides_Horde/" `
        "/addon/Polestar_frFR/" "/addon/Polestar/Gear/" `
        "/addon/Polestar_ItemDB/" "/forever-db/"
}
# Anciens caches : ajoute les dossiers apparus depuis (poids de stats, phase 6).
git -C $dest sparse-checkout add "/addon/Polestar/Gear/" "/addon/Polestar_ItemDB/" "/forever-db/" `
    "/addon/Polestar_Nav/" "/addon/Polestar_Nav_EK/" "/addon/Polestar_Nav_Kalimdor/" `
    "/addon/Polestar/Nav/TravelData.lua" "/addon/Polestar/Maps/FlightPaths.lua"

# Butin des boss : Polestar l'a retiré en 0.4.3 ; Forever.lua et sa notice sont repris de la
# version `loot` (cache\polestar-loot).
if ($lock.loot) {
    $lootDir = Join-Path $PSScriptRoot "cache\polestar-loot"
    $lootFile = Join-Path $lootDir "Forever.lua"
    $stamp = Join-Path $lootDir "commit.txt"
    if (-not ((Test-Path $lootFile) -and (Test-Path $stamp) -and ((Get-Content $stamp) -eq $lock.loot))) {
        Write-Host "Fetching boss loot from Polestar $($lock.lootversion) ($($lock.loot))..."
        New-Item -ItemType Directory -Force -Path $lootDir | Out-Null
        git -C $dest -c core.longpaths=true fetch --quiet --depth 1 --filter=blob:none origin $lock.loot
        if ($LASTEXITCODE -ne 0) { throw "git fetch (loot) failed" }
        foreach ($name in "Forever.lua", "LICENSE-DATA.txt") {
            $text = git -C $dest show "$($lock.loot):addon/Polestar_ItemDB/$name" | Out-String
            if ($LASTEXITCODE -ne 0) { throw "git show $name (loot) failed" }
            [IO.File]::WriteAllText((Join-Path $lootDir $name), $text, (New-Object Text.UTF8Encoding $false))
        }
        Set-Content -Path $stamp -Value $lock.loot
    }
}

Write-Host "Fetching Polestar $($lock.version) ($($lock.commit))..."
# blob:none: only the files kept by the sparse checkout are downloaded.
git -C $dest -c core.longpaths=true fetch --quiet --depth 1 --filter=blob:none origin $lock.commit
if ($LASTEXITCODE -ne 0) { throw "git fetch failed" }
git -C $dest -c core.longpaths=true checkout --quiet --force FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "git checkout failed" }
Write-Host "Polestar files ready in $dest"
