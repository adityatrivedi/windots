<#!
.SYNOPSIS
Installs per-shell profile stubs that source the central profile.

.DESCRIPTION
Ensures Windows PowerShell and PowerShell 7 profile paths contain a minimal stub that
dot-sources the central managed profile under XDG-style config path.
#>
[CmdletBinding()]
param(
    [switch]$Quiet
)
############################################################
# Initialization
############################################################
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"
if ($Quiet) {
    $Global:DOTFILES_QUIET = $true
}

$centralProfile = Join-Path $HOME '.config\powershell\profile.ps1'
if (-not (Test-Path $centralProfile)) {
    Write-Warn "Central profile not found at $centralProfile. Skipping stub installation."
    exit 0
}

############################################################
# Functions
############################################################
function Install-ProfileStub {
    param(
        [Parameter(Mandatory)][string]$ProfilePath
    )
    $dir = Split-Path $ProfilePath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $content = @"
# Dotfiles profile stub - do not remove.
if (Test-Path -LiteralPath "$centralProfile") { . "$centralProfile" }
"@
    Set-Content -LiteralPath $ProfilePath -Value $content -Encoding UTF8
    Write-Ok "Installed PowerShell profile stub: $ProfilePath."
}

############################################################
# Execution
############################################################
# Windows PowerShell (5.1)
$winPsProfile = Join-Path $HOME 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
Install-ProfileStub -ProfilePath $winPsProfile

# PowerShell 7+
$ps7Profile = Join-Path $HOME 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
Install-ProfileStub -ProfilePath $ps7Profile

Write-Ok 'Profile setup completed.'
