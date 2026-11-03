<#
.SYNOPSIS
    Turns the diagnostic addon's saved variables into docs\reports\diagnostic-<date>.md.

.DESCRIPTION
    In game: /nsdiag, optionally /nsdiag combat then a fight, then /reload.
    Then run this script: it finds the most recent NextStep_Diagnostic.lua under
    <GamePath>\WTF\Account\*\SavedVariables and writes the Markdown report.
#>
param(
    [string]$GamePath = "C:\Program Files (x86)\World of Warcraft\_forever_"
)
$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

$saved = Get-ChildItem -Path (Join-Path $GamePath "WTF\Account") -Recurse -Filter "NextStep_Diagnostic.lua" `
    -ErrorAction SilentlyContinue | Where-Object { $_.Directory.Name -eq "SavedVariables" } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $saved) { throw "No diagnostic saved variables found: run /nsdiag then /reload in game." }

$luajit = (Get-Command luajit -ErrorAction SilentlyContinue).Source
if (-not $luajit) { $luajit = Join-Path $env:LOCALAPPDATA "Programs\LuaJIT\bin\luajit.exe" }

$date = $saved.LastWriteTime.ToString("yyyy-MM-dd")
$output = Join-Path $root "docs\reports\diagnostic-$date.md"
& $luajit (Join-Path $PSScriptRoot "report.lua") $saved.FullName $output
if ($LASTEXITCODE -ne 0) { throw "report generation failed" }
Write-Host "Source: $($saved.FullName)"
