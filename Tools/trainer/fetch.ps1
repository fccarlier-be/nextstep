<#
.SYNOPSIS
    Downloads the What's Training files that NextStep imports, at the commit pinned in whatstraining.lock.

.DESCRIPTION
    Sparse, shallow checkout into Tools\trainer\cache\whatstraining (ignored by git): only the
    licence and the WoW Forever class tables (Classes/Camelot) are downloaded.
#>
$ErrorActionPreference = "Stop"

$lock = @{}
foreach ($line in Get-Content (Join-Path $PSScriptRoot "whatstraining.lock")) {
    if ($line -match "^\s*([^#=]+?)\s*=\s*(.+?)\s*$") { $lock[$Matches[1]] = $Matches[2] }
}

$dest = Join-Path $PSScriptRoot "cache\whatstraining"
if (-not (Test-Path (Join-Path $dest ".git"))) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    git -C $dest init --quiet
    git -C $dest remote add origin $lock.repository
    git -C $dest sparse-checkout set --no-cone "/LICENSE" "/Classes/Camelot/"
}

Write-Host "Fetching What's Training ($($lock.commit))..."
git -C $dest fetch --quiet --depth 1 --filter=blob:none origin $lock.commit
if ($LASTEXITCODE -ne 0) { throw "git fetch failed" }
git -C $dest checkout --quiet --force FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw "git checkout failed" }
Write-Host "What's Training files ready in $dest"
