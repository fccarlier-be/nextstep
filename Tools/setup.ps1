<#
.SYNOPSIS
    Installs the local development tools: LuaJIT (Lua 5.1, like the game) and luacheck.

.DESCRIPTION
    LuaJIT is installed with winget. luacheck is downloaded as a standalone executable
    into Tools\bin (ignored by git). Safe to run again: existing tools are kept.
#>
$ErrorActionPreference = "Stop"

$bin = Join-Path $PSScriptRoot "bin"
New-Item -ItemType Directory -Force -Path $bin | Out-Null

$luajit = Join-Path $env:LOCALAPPDATA "Programs\LuaJIT\bin\luajit.exe"
if (Test-Path $luajit) {
    Write-Host "LuaJIT already installed: $luajit"
} else {
    Write-Host "Installing LuaJIT with winget..."
    winget install --id DEVCOM.LuaJIT --exact --accept-package-agreements --accept-source-agreements --silent
}

$luacheck = Join-Path $bin "luacheck.exe"
if (Test-Path $luacheck) {
    Write-Host "luacheck already present: $luacheck"
} else {
    Write-Host "Downloading luacheck..."
    $url = "https://github.com/lunarmodules/luacheck/releases/latest/download/luacheck.exe"
    Invoke-WebRequest -Uri $url -OutFile $luacheck -UseBasicParsing
}

Write-Host "Done. Run Tools\check.ps1 to lint and test."
