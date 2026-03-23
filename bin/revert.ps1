<#!
.SYNOPSIS
Reverts prior dotfiles setup actions selectively or entirely.

.DESCRIPTION
Supports granular removal of links, packages, profile stubs, modules, environment
variables, and extracted repo copy. Use -All to perform every revert action.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Quiet,
    [switch]$RemoveLinks,
    [switch]$UninstallPackages,
    [switch]$RemoveProfiles,
    [switch]$UninstallModules,
    [switch]$ResetEnv,
    [switch]$RevertTheme,
    [switch]$RemoveRepo,
    [switch]$All
)
############################################################
# Initialization
############################################################

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"
if ($Quiet) { $Global:DOTFILES_QUIET = $true }

$repoRoot = Split-Path $PSScriptRoot -Parent
$repoConfig = Join-Path $repoRoot '.config'
$homeConfig = Join-Path $HOME '.config'

############################################################
# Functions
############################################################
function Remove-ConfigLinks {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
    param()
    if (-not (Test-Path $repoConfig)) { return }
    if (-not (Test-Path $homeConfig)) { return }
    Get-ChildItem -Path $repoConfig -Directory | ForEach-Object {
        $name = $_.Name
        $dst = Join-Path $homeConfig $name
        if (Test-Path $dst) {
            try {
                $item = Get-Item -LiteralPath $dst -Force -ErrorAction Stop
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                    if ($PSCmdlet.ShouldProcess($dst, 'Remove link/junction')) {
                        Remove-Item -LiteralPath $dst -Force -Recurse -Confirm:$false
                        Write-Ok "Removed link: $dst."
                    }
                }
                else { Write-Warn "Skipping non-link at $dst." }
            }
            catch { Write-Warn "Failed to inspect or remove ${dst}: $($_.Exception.Message)" }
        }
    }
}

function Uninstall-Packages {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()
    $pkgListPath = Join-Path $repoRoot 'packages\windows-winget.json'
    if (-not (Test-Path $pkgListPath)) { Write-Warn 'Package list not found; skipping package uninstall.'; return }
    $pkgs = Get-Content -Raw -Path $pkgListPath | ConvertFrom-Json
    foreach ($pkg in $pkgs) {
        # Support both string format (legacy) and object format with id/scope
        $id = if ($pkg -is [string]) { $pkg } else { $pkg.id }

        Write-Info "Attempting to uninstall $id via Winget."
        $null = winget list -e --id $id 2>$null
        if ($LASTEXITCODE -ne 0) { Write-Ok "Not installed or not detectable: $id."; continue }
        if ($PSCmdlet.ShouldProcess($id, 'Uninstall package via Winget')) {
            $output = winget uninstall -e --id $id --silent 2>&1
            if ($LASTEXITCODE -eq 0) { Write-Ok "Uninstalled: $id." }
            else { Write-Warn "Unable to uninstall ${id}: $output" }
        }
        else { Write-Info "Would uninstall: $id." }
    }
}

function Remove-ProfileStubs {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
    param()
    $paths = @(
        (Join-Path $HOME 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
        (Join-Path $HOME 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1')
    )
    foreach ($p in $paths) {
        if (Test-Path $p) {
            $content = Get-Content -LiteralPath $p -Raw -ErrorAction SilentlyContinue
            if ($content -match 'Dotfiles profile stub') {
                if ($PSCmdlet.ShouldProcess($p, 'Remove profile stub')) {
                    Remove-Item -LiteralPath $p -Force -Confirm:$false
                    Write-Ok "Removed profile stub: $p."
                }
            }
            else { Write-Warn "Skipping profile (no stub marker): $p." }
        }
    }
}

function Uninstall-Modules {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()
    foreach ($m in @('CompletionPredictor', 'PSReadLine')) {
        try {
            if ($PSCmdlet.ShouldProcess($m, 'Uninstall module')) {
                Uninstall-Module -Name $m -AllVersions -Force -ErrorAction SilentlyContinue
                Write-Ok "Requested uninstall for module: $m."
            }
        }
        catch { Write-Warn "Failed to uninstall module ${m}: $($_.Exception.Message)" }
    }
}

function Reset-Env {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
    param()
    try {
        $current = [Environment]::GetEnvironmentVariable('XDG_CONFIG_HOME', 'User')
        $expected = Join-Path $HOME '.config'
        if ($current -and ($current -eq $expected)) {
            if ($PSCmdlet.ShouldProcess('XDG_CONFIG_HOME', 'Clear User environment variable')) {
                [Environment]::SetEnvironmentVariable('XDG_CONFIG_HOME', $null, 'User')
                Write-Ok 'Cleared User environment variable: XDG_CONFIG_HOME.'
            }
        }
        else { Write-Warn 'XDG_CONFIG_HOME not set to the default path or already cleared; leaving unchanged.' }
    }
    catch { Write-Warn "Failed to reset XDG_CONFIG_HOME: $($_.Exception.Message)" }
}

function Remove-Repo {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param()
    $dot = Join-Path $HOME '.dotfiles'
    if (Test-Path $dot) {
        if ($PSCmdlet.ShouldProcess($dot, 'Remove extracted dotfiles repo')) {
            Remove-Item -LiteralPath $dot -Recurse -Force -Confirm:$false
            Write-Ok "Removed $dot."
        }
    }
}

function Revert-WTTheme {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Low')]
    param()
    $themeFile = Join-Path $repoRoot 'packages\windows-terminal-theme.json'
    if (-not (Test-Path $themeFile)) { Write-Info 'No saved theme file; skipping theme revert.'; return }

    $candidates = Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState\settings.json" -ErrorAction SilentlyContinue
    if (-not $candidates) { Write-Info 'Windows Terminal not installed; skipping theme revert.'; return }
    $wtSettingsPath = ($candidates | Select-Object -First 1).FullName

    $theme    = Get-Content -Raw -LiteralPath $themeFile | ConvertFrom-Json
    $settings = Get-Content -Raw -LiteralPath $wtSettingsPath | ConvertFrom-Json

    # Remove imported schemes by name
    if ($settings.PSObject.Properties['schemes'] -and $theme.PSObject.Properties['schemes']) {
        $importedNames = @($theme.schemes | ForEach-Object { $_.name })
        $settings.schemes = @($settings.schemes | Where-Object { $_.name -notin $importedNames })
    }
    # Remove imported themes by name
    if ($settings.PSObject.Properties['themes'] -and $theme.PSObject.Properties['themes']) {
        $importedNames = @($theme.themes | ForEach-Object { $_.name })
        $settings.themes = @($settings.themes | Where-Object { $_.name -notin $importedNames })
    }
    # Clear profile defaults set by import
    if ($theme.PSObject.Properties['profileDefaults'] -and $settings.PSObject.Properties['profiles'] -and $settings.profiles.PSObject.Properties['defaults']) {
        $pd = $theme.profileDefaults
        if ($pd.PSObject.Properties['colorScheme'] -and $settings.profiles.defaults.PSObject.Properties['colorScheme']) {
            if ($settings.profiles.defaults.colorScheme -eq $pd.colorScheme) {
                $settings.profiles.defaults.PSObject.Properties.Remove('colorScheme')
            }
        }
        if ($pd.PSObject.Properties['font'] -and $settings.profiles.defaults.PSObject.Properties['font']) {
            $settings.profiles.defaults.PSObject.Properties.Remove('font')
        }
    }

    if ($PSCmdlet.ShouldProcess($wtSettingsPath, 'Revert imported Windows Terminal theme')) {
        $settings | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $wtSettingsPath -Encoding UTF8
        Write-Ok 'Reverted Windows Terminal theme.'
    }
}

############################################################
# Execution
############################################################
try {
    if ($All) {
        $RemoveLinks = $true; $UninstallPackages = $true; $RemoveProfiles = $true; $UninstallModules = $true; $ResetEnv = $true; $RevertTheme = $true; $RemoveRepo = $true
    }
    if ($RemoveLinks) { Remove-ConfigLinks }
    if ($UninstallPackages) { Uninstall-Packages }
    if ($RemoveProfiles) { Remove-ProfileStubs }
    if ($UninstallModules) { Uninstall-Modules }
    if ($ResetEnv) { Reset-Env }
    if ($RevertTheme) { Revert-WTTheme }
    if ($RemoveRepo) { Remove-Repo }
    Write-Ok 'Revert completed.'
}
catch {
    Write-Err $_
    exit 1
}
