<#!
.SYNOPSIS
Installs/ensures required PowerShell modules.

.DESCRIPTION
Configures TLS for down-level hosts, ensures NuGet provider and PSGallery trust, then
installs requested modules idempotently for CurrentUser scope.
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
if ($Quiet) { $Global:DOTFILES_QUIET = $true }

function Set-Tls12IfNeeded {
    param()
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        try { 
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
        } 
        catch { 
            Write-Verbose 'Failed to set TLS1.2' 
        }
    }
}

function Install-NuGetProviderIfMissing {
    param()
    $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue
    if (-not $nuget) {
        Write-Info 'Installing NuGet package provider (CurrentUser).'
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
    }
}

function Set-TrustedPSGallery {
    param()
    try {
        $repo = Get-PSRepository -Name 'PSGallery' -ErrorAction Stop
        if ($repo.InstallationPolicy -ne 'Trusted') {
            Write-Info 'Setting PSGallery installation policy to Trusted for this user.'
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
        }
    } catch { 
        Write-Warn "PSGallery repository not found: $($_.Exception.Message)" 
    }
}

############################################################
# Functions
############################################################
function Install-ModuleIfMissing {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [string] $MinimumVersion
    )
    $have = Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if ($have) {
        if ($MinimumVersion) {
            if ([Version]$have.Version -ge [Version]$MinimumVersion) { Write-Ok "Already available: $Name."; return }
        } else { Write-Ok "Already available: $Name."; return }
    }
    Write-Info "Installing PowerShell module: $Name."
    try {
    $moduleInstallParams = @{ Name = $Name; Scope = 'CurrentUser'; Repository = 'PSGallery'; Force = $true; AllowClobber = $true }
    if ($MinimumVersion) { $moduleInstallParams.MinimumVersion = $MinimumVersion }
    Install-Module @moduleInstallParams
        Write-Ok "Installed module: $Name."
    } catch {
        Write-Err "Failed to install module ${Name}: $($_.Exception.Message)"
    }
}

############################################################
# Execution
############################################################
Set-Tls12IfNeeded
Install-NuGetProviderIfMissing
Set-TrustedPSGallery

# Requested modules
Install-ModuleIfMissing -Name 'PSReadLine' -MinimumVersion '2.2.0'
Install-ModuleIfMissing -Name 'CompletionPredictor'

Write-Ok 'Module installation workflow completed.'
