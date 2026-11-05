<#
.SYNOPSIS
    Imports What's Training's class spells into NextStep: fetch, convert, then lint and test.

.DESCRIPTION
    1. fetch.ps1 downloads the commit pinned in whatstraining.lock (cached).
    2. import.lua converts it and writes Data\Imported\WhatsTraining and last-import.md.
    3. Tools\check.ps1 runs luacheck and the out-of-game tests.
    To import a newer version, edit whatstraining.lock first.
#>
$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $root
try {
    & (Join-Path $PSScriptRoot "fetch.ps1")

    $luajit = (Get-Command luajit -ErrorAction SilentlyContinue).Source
    if (-not $luajit) { $luajit = Join-Path $env:LOCALAPPDATA "Programs\LuaJIT\bin\luajit.exe" }
    & $luajit Tools/trainer/import.lua Tools/trainer/cache/whatstraining Tools/trainer/whatstraining.lock
    if ($LASTEXITCODE -ne 0) { throw "import failed" }

    & (Join-Path $PSScriptRoot "..\check.ps1")
    if ($LASTEXITCODE -ne 0) { throw "checks failed" }
} finally {
    Pop-Location
}
