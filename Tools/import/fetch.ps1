<#
.SYNOPSIS
    Downloads the Polestar files that NextStep imports, at the commit pinned in polestar.lock.

.DESCRIPTION
    Sparse, shallow checkout into Tools\import\cache\polestar (ignored by git): only the
    compiled guide packs, the French pack, the gear weights, the item and quest databases and the licence files are downloaded.
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
git -C $dest sparse-checkout add "/addon/Polestar/Gear/" "/addon/Polestar_ItemDB/" "/forever-db/"

Write-Host "Fetching Polestar $($lock.version) ($($lock.commit))..."
# blob:none: only the files kept by the sparse checkout are downloaded.
git -C $dest -c core.longpaths=true fetch --quiet --depth 1 --filter=blob:none origin $lock.commit
if ($LASTEXITCODE -ne 0) { throw "git fetch failed" }
git -C $dest -c core.longpaths=true checkout --quiet --force FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "git checkout failed" }
Write-Host "Polestar files ready in $dest"
