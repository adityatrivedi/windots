<#!
.SYNOPSIS
Installs packages listed in packages/windows-winget.json via winget.

.DESCRIPTION
Reads the manifest (array of package objects with ID and optional scope) and performs 
idempotent installations, preferring user scope unless scope is explicitly set to "machine".
Skips already installed packages using a cached 'winget list' snapshot to reduce overhead.
Safe for repeated runs and provides concise logging.
#>
[CmdletBinding()]
param(
    [switch]$Quiet
)
############################################################
# Initialization
############################################################
$PSDefaultParameterValues = @{}
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot\_common.ps1"
if ($Quiet) { $Global:DOTFILES_QUIET = $true }

############################################################
# Data / Manifest Load
############################################################
$wingetPkgs = Get-Content -Raw -Path (Join-Path $PSScriptRoot '..\packages\windows-winget.json') | ConvertFrom-Json

# Capture a snapshot of installed packages. We'll refresh this after each install to avoid stale checks.
function Refresh-WingetListCache {
    try {
        $Global:__DOTFILES_WINGET_LIST_CACHE = winget list --accept-source-agreements 2>$null | Out-String
    }
    catch { $Global:__DOTFILES_WINGET_LIST_CACHE = '' }
}
Refresh-WingetListCache

############################################################
# Functions
############################################################
function Test-Installed {
    param(
        [Parameter(Mandatory)][string]$Id,
        [switch]$Live
    )
    if ($Live) {
        # More precise but a bit slower; used only after install attempts.
        try {
            $out = winget list --id $Id -e --accept-source-agreements 2>$null | Out-String
            return ($out -match "(?im)\b$([regex]::Escape($Id))\b")
        }
        catch { return $false }
    }
    if (-not $Global:__DOTFILES_WINGET_LIST_CACHE) { return $false }
    # Regex word boundary match of the ID to reduce false positives.
    return ($Global:__DOTFILES_WINGET_LIST_CACHE -match "(?im)\b$([regex]::Escape($Id))\b")
}

function Invoke-WingetInstall {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Scope = 'user'
    )
    
    if ($Scope -eq 'machine') {
        Write-Info "Installing $Id via Winget (machine-scope)."
        $output = winget install --id $Id --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Winget installation failed for ${Id}: $output" }
        return
    }
    
    Write-Info "Installing $Id via Winget in user-scope."
    $output = winget install --id $Id --source winget --silent --accept-package-agreements --accept-source-agreements --scope user 2>&1
    if ($LASTEXITCODE -eq 0) { return }
    # Retry without scope if user-scope installer is not applicable (may prompt UAC)
    if ($output -match 'No applicable installer found') {
        Write-Info "Retrying $Id with default scope (a UAC prompt may appear)."
        $output = winget install --id $Id --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1
    }
    if ($LASTEXITCODE -ne 0) { throw "Winget installation failed for ${Id}: $output" }
}

############################################################
# Winget-only install execution
############################################################
foreach ($pkg in $wingetPkgs) {
    if ($pkg -is [string]) {
        $id = $pkg
        $scope = 'user'
    }
    else {
        $id = $pkg.id
        $scope = if ($pkg.PSObject.Properties['scope']) { $pkg.scope } else { 'user' }
    }
    
    if (Test-Installed $id) {
        Write-Ok "Already installed: $id."; continue
    }
    try {
        Invoke-WingetInstall -Id $id -Scope $scope
    }
    catch {
        Write-Warn "Installation failed for ${id}: $($_.Exception.Message)"
        continue
    }
    # Refresh cache and confirm using a precise live check to avoid false negatives from stale cache.
    Refresh-WingetListCache
    if (Test-Installed $id -Live) {
        Write-Ok "Installed: $id."; continue
    }
    Write-Warn "Winget did not confirm the installation of $id. It may require Microsoft Store interaction or manual installation."
}
