<#!
.SYNOPSIS
Creates symbolic links from repo .config to user's home .config.

.DESCRIPTION
Iterates top-level directories in the repository .config and ensures matching links exist
in the target home .config. Supports -Force replacement and WhatIf/Confirm semantics.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
    [switch]$Quiet,
    [switch]$Force,
    [string]$TargetHomePath
)
############################################################
# Initialization
############################################################
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"
if ($Quiet) { $Global:DOTFILES_QUIET = $true }

$repoConfig = Join-Path (Split-Path $PSScriptRoot -Parent) '.config'
$baseHome = if ($TargetHomePath) { $TargetHomePath } else { $HOME }
$homeConfig = Join-Path $baseHome '.config'
if (-not (Test-Path $homeConfig)) {
    New-Item -ItemType Directory -Path $homeConfig | Out-Null
}

############################################################
# Functions
############################################################
function Ensure-GitGlobalConfigInclude {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)][string]$HomePath
    )
    $gitconfig = Join-Path $HomePath '.gitconfig'
    $includeBlock = "[include]`n    path = ~/.config/git/config`n"
    if (-not (Test-Path $gitconfig)) {
        if ($PSCmdlet.ShouldProcess($gitconfig, 'Create .gitconfig to include XDG config')) {
            $includeBlock | Out-File -FilePath $gitconfig -Encoding utf8 -Force
            Write-Ok "Created $gitconfig to include ~/.config/git/config."
        }
        return
    }
    try {
        $content = Get-Content -Raw -LiteralPath $gitconfig -ErrorAction Stop
    }
    catch {
        Write-Warn "Unable to read existing ${gitconfig}: $($_.Exception.Message)"; return
    }
    if ($content -notmatch "(?im)^\s*\[include\]\s*(?:\r?\n)+\s*path\s*=\s*~/.config/git/config\s*$") {
        if ($PSCmdlet.ShouldProcess($gitconfig, 'Append include to XDG config')) {
            Add-Content -LiteralPath $gitconfig -Value ("`n" + $includeBlock)
            Write-Ok "Updated $gitconfig to include ~/.config/git/config."
        }
    }
}
function New-Link {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)][string]$Src,
        [Parameter(Mandatory)][string]$Dst
    )
    if (Test-Path $Dst) {
        # If an existing link/junction points elsewhere, remove and recreate
        try {
            $item = Get-Item -Path $Dst -Force -ErrorAction Stop
            if ($item.LinkType -or $item.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
                if ($PSCmdlet.ShouldProcess($Dst, 'Replace existing symbolic link')) {
                    Remove-Item -Path $Dst -Force -Recurse -Confirm:$false
                }
                else { return }
            }
            else {
                if ($Force) {
                    if ($PSCmdlet.ShouldProcess($Dst, 'Remove existing non-link before linking')) {
                        Remove-Item -Path $Dst -Recurse -Force -Confirm:$false
                        Write-Warn "Replaced existing non-link at $Dst."
                    }
                    else { return }
                }
                else {
                    Write-Warn "Destination exists and is not a link: $Dst (skipping)"
                    return
                }
            }
        }
        catch {
            Write-Warn "Unable to inspect existing destination ${Dst}: $($_.Exception.Message)"
            return
        }
    }
    if ($PSCmdlet.ShouldProcess($Dst, "Create symbolic link to $Src")) {
        try {
            New-Item -ItemType SymbolicLink -Path $Dst -Target $Src -Force | Out-Null
            Write-Ok "Created symbolic link: $Dst -> $Src."
        }
        catch {
            Write-Err "Failed to create symbolic link: $Dst -> $Src. Ensure Windows Developer Mode is enabled or run this script elevated. Error: $($_.Exception.Message)"
            throw
        }
    }
}

############################################################
# Execution
############################################################
Get-ChildItem -Path $repoConfig -Directory | ForEach-Object {
    $name = $_.Name
    New-Link -Src $_.FullName -Dst (Join-Path $homeConfig $name)
}

# Ensure Git picks up the XDG config even on setups that only read %USERPROFILE%\.gitconfig
Ensure-GitGlobalConfigInclude -HomePath $baseHome
