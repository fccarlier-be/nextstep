<#
.SYNOPSIS
    Imports Polestar's guides into NextStep: fetch, convert, then lint and test.

.DESCRIPTION
    1. fetch.ps1 downloads the Polestar commit pinned in polestar.lock (cached).
    2. import.lua converts it and writes the data files and last-import.md;
       gear.lua writes the stat weights (Data/Imported/Polestar/Gear.lua);
       dungeons.py writes the dungeons, their quests and loot (Dungeons.lua).
    3. Tools\check.ps1 runs luacheck and the out-of-game tests.
    To import a newer Polestar, edit polestar.lock first.
#>
$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $root
try {
    & (Join-Path $PSScriptRoot "fetch.ps1")

    $luajit = (Get-Command luajit -ErrorAction SilentlyContinue).Source
    if (-not $luajit) { $luajit = Join-Path $env:LOCALAPPDATA "Programs\LuaJIT\bin\luajit.exe" }
    & $luajit Tools/import/import.lua Tools/import/cache/polestar Tools/import/polestar.lock
    if ($LASTEXITCODE -ne 0) { throw "import failed" }
    & $luajit Tools/import/gear.lua Tools/import/cache/polestar Tools/import/polestar.lock
    if ($LASTEXITCODE -ne 0) { throw "gear import failed" }
    & python -I Tools/import/dungeons.py Tools/import/cache/polestar Tools/import/polestar.lock
    if ($LASTEXITCODE -ne 0) { throw "dungeons import failed" }

    & (Join-Path $PSScriptRoot "..\check.ps1")
    if ($LASTEXITCODE -ne 0) { throw "checks failed" }
} finally {
    Pop-Location
}
