<#
.SYNOPSIS
    Links the addon folders of this repository into the WoW Forever AddOns folder.

.DESCRIPTION
    Creates one directory junction per folder of addon\ (NextStep, NextStep_Alliance,
    NextStep_Horde), plus the development addon Tools\diagnostic\NextStep_Diagnostic,
    in <GamePath>\Interface\AddOns. The game then reads the files straight from the
    repository: a /reload is enough to test a change.
    An existing folder that is not a junction is never touched.
    If access is denied (the game lives in Program Files), run once as administrator.

.PARAMETER GamePath
    The WoW Forever folder (the one containing Wow.exe).

.PARAMETER Remove
    Removes the junctions instead of creating them.

.EXAMPLE
    .\Tools\deploy.ps1
    .\Tools\deploy.ps1 -Remove
#>
param(
    [string]$GamePath = "C:\Program Files (x86)\World of Warcraft\_forever_",
    [switch]$Remove
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path (Join-Path $GamePath "Wow.exe"))) {
    throw "WoW Forever not found in: $GamePath (use -GamePath)"
}

$sources = @(Get-ChildItem -Path (Join-Path $PSScriptRoot "..\addon") -Directory) +
    @(Get-ChildItem -Path (Join-Path $PSScriptRoot "diagnostic") -Directory)
$addOns = Join-Path $GamePath "Interface\AddOns"

try {
    if (-not $Remove) {
        New-Item -ItemType Directory -Force -Path $addOns | Out-Null
    }
    foreach ($source in $sources) {
        $target = Join-Path $addOns $source.Name
        $existing = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        if ($existing) {
            if ($existing.LinkType -ne "Junction") {
                Write-Warning "$target exists and is not a junction: skipped."
                continue
            }
            # Removes the link only, never the repository files it points to.
            [System.IO.Directory]::Delete($target)
        }
        if ($Remove) {
            Write-Host "Removed: $target"
        } else {
            New-Item -ItemType Junction -Path $target -Target $source.FullName | Out-Null
            Write-Host "Linked: $target -> $($source.FullName)"
        }
    }
} catch [System.UnauthorizedAccessException] {
    throw "Access denied to $addOns. Run this script once from an administrator PowerShell."
}
