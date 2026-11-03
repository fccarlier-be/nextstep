<#
.SYNOPSIS
    Lints the code with luacheck and runs the out-of-game tests.

.DESCRIPTION
    Same checks as the GitHub CI. Run Tools\setup.ps1 once beforehand.
    Exit code is non-zero if any check fails.
#>
$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
    $failed = $false

    $luacheck = Join-Path $PSScriptRoot "bin\luacheck.exe"
    if (-not (Test-Path $luacheck)) { throw "luacheck not found: run Tools\setup.ps1 first." }
    Write-Host "== luacheck"
    & $luacheck addon tests Tools/diagnostic Tools/import --codes
    if ($LASTEXITCODE -ne 0) { $failed = $true }

    $luajit = (Get-Command luajit -ErrorAction SilentlyContinue).Source
    if (-not $luajit) { $luajit = Join-Path $env:LOCALAPPDATA "Programs\LuaJIT\bin\luajit.exe" }
    if (-not (Test-Path $luajit)) { throw "LuaJIT not found: run Tools\setup.ps1 first." }
    Write-Host "== tests"
    & $luajit tests/run.lua
    if ($LASTEXITCODE -ne 0) { $failed = $true }

    if ($failed) { exit 1 }
} finally {
    Pop-Location
}
