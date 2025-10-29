<#!
.SYNOPSIS
Bootstraps dotfiles environment on a Windows system.

.DESCRIPTION
Ensures symlink capability (optionally enabling Developer Mode), sets XDG config path,
verifies winget, fetches or uses local repo, installs packages, modules, fonts, creates
symlinked config directories, installs profile stubs, and runs self-tests optionally.
#>
[CmdletBinding()]
param (
    [string]$RepoZipUrl,
    [switch]$Quiet,
    [switch]$ElevateLink,
    [switch]$Verify,
    [switch]$Help
)
############################################################
# Initialization
############################################################

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"
if ($Quiet) { $Global:DOTFILES_QUIET = $true }

function Show-BootstrapHelp {
    @'
Usage: bootstrap.ps1 [options]

Options:
    -RepoZipUrl <URL>  Download & use a ZIP archive (no git clone needed). If omitted, assumes current directory is the repo.
    -ElevateLink       If non-admin symlink creation fails, elevate ONLY the link step (principle of least privilege).
    -Verify            Run self-test after setup (invokes self-test.ps1).
    -Quiet             Suppress informational [INFO] messages (warnings/errors still shown).
    -Help / -?         Show this help and exit.

Standard PowerShell common parameters (e.g. -Verbose, -WhatIf where supported) are also available.

Examples:
    # Fresh setup using remote archive (will extract into $HOME/.dotfiles):
    ./bin/bootstrap.ps1 -RepoZipUrl https://github.com/user/repo/archive/refs/heads/main.zip -ElevateLink -Verify

    # Existing clone, minimized noise:
    ./bin/bootstrap.ps1 -ElevateLink -Quiet

Behavior Summary:
    1. Ensures (or enables) Developer Mode for symlink privilege (may elevate only that registry write).
    2. Sets XDG_CONFIG_HOME (user scope) if not already set.
    3. Verifies winget availability.
    4. Acquires repo (from ZIP if provided) into $HOME/.dotfiles.
    5. Installs packages, modules, font, links configs, installs profile stubs.
    6. Optional self-test (package drift, font, profile, symlink check).
    7. Provides audit/revert scripts for later maintenance.
'@ | Write-Host
}

if ($Help -or $PSBoundParameters['?']) { Show-BootstrapHelp; return }

############################################################
# Functions
############################################################
function Test-SymlinkCapability {
    param()
    try {
        $g = [guid]::NewGuid().Guid
        $src = Join-Path $env:TEMP "df_link_src_$g"
        $ln = Join-Path $env:TEMP "df_link_ln_$g"
        New-Item -ItemType Directory -Path $src -ErrorAction Stop | Out-Null
        try {
            New-Item -ItemType SymbolicLink -Path $ln -Target $src -ErrorAction Stop | Out-Null
            return $true
        }
        catch { return $false }
        finally {
            Remove-Item -LiteralPath $ln -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $src -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    catch { return $false }
}

function Ensure-DeveloperModeIfNeeded {
    param()
    $hasCapability = Test-SymlinkCapability
    if ($hasCapability) { Write-Ok 'Symlink capability confirmed (no elevation needed).'; return }
    try {
        $key = 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
        $name = 'AllowDevelopmentWithoutDevLicense'
        $enabled = 0
        if (Test-Path $key) { $enabled = (Get-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue).$name }
        if ($enabled -ne 1) {
            Write-Info 'Attempting to enable Windows Developer Mode for symlink privilege.'
            $devModeScript = "New-Item -Path '$key' -Force | Out-Null; Set-ItemProperty -Path '$key' -Name '$name' -Type DWord -Value 1"
            $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $devModeScript) -Verb RunAs -PassThru
            $proc.WaitForExit()
            if ($proc.ExitCode -eq 0) { Write-Ok 'Developer Mode registry flag set.' }
            else { Write-Warn 'Developer Mode enable attempt did not complete successfully.' }
        }
        else { Write-Ok 'Developer Mode registry flag already set.' }
    }
    catch { Write-Warn "Unable to set Developer Mode flag: $($_.Exception.Message)" }
    if (Test-SymlinkCapability) { Write-Ok 'Symlink capability available after Dev Mode check.' }
    else { Write-Warn 'Symlink capability still unavailable; will rely on elevation (-ElevateLink).' }
}

function Set-XdgConfig {
    param()
    $xdg = [Environment]::GetEnvironmentVariable('XDG_CONFIG_HOME', 'User')
    if ([string]::IsNullOrWhiteSpace($xdg)) {
        $path = Join-Path $HOME '.config'
        [Environment]::SetEnvironmentVariable('XDG_CONFIG_HOME', $path, 'User')
        $env:XDG_CONFIG_HOME = $path
        Write-Ok "XDG_CONFIG_HOME has been set to '$path' for the current user."
    }
    else {
        $env:XDG_CONFIG_HOME = $xdg
        Write-Ok "XDG_CONFIG_HOME is already set to '$xdg'."
    }
    $cfg = Join-Path $HOME '.config'
    if (-not (Test-Path $cfg)) { New-Item -ItemType Directory -Path $cfg | Out-Null }
}

function Test-WingetAvailable {
    param()
    if (Get-Command winget -ErrorAction SilentlyContinue) { Write-Ok 'Winget is available.'; return }
    throw "Winget is not available. Please install 'App Installer' from the Microsoft Store, and then re-run the bootstrap script."
}

function Invoke-FontInstall { param(); & "$PSScriptRoot/fonts.ps1" }

function Invoke-PackageInstall { param(); & "$PSScriptRoot/install.ps1" }

function Set-ConfigLinks { param(); & "$PSScriptRoot/link.ps1" -Force -Quiet:$Quiet }

function Get-RepoLocal {
    param()
    $dot = Join-Path $HOME '.dotfiles'
    # Check if .dotfiles already exists and has content
    if (Test-Path (Join-Path $dot '.config')) { return $dot }
    
    # If no URL provided, assume current directory is the repo
    if (-not $RepoZipUrl) {
        Write-Info 'No -RepoZipUrl was provided. Assuming the current folder is the repository.'
        return (Get-Location).Path
    }
    
    # Only create .dotfiles directory when we're about to download and extract
    if (-not (Test-Path $dot)) { New-Item -ItemType Directory -Path $dot | Out-Null }
    
    $zip = Join-Path $env:TEMP 'dotfiles.zip'
    Write-Info "Downloading repository archive from $RepoZipUrl."
    Invoke-WebRequest -Uri $RepoZipUrl -OutFile $zip -UseBasicParsing
    Write-Info 'Extracting the repository archive.'
    $tmpDir = Join-Path $env:TEMP ('dotfiles_' + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $tmpDir | Out-Null
    Expand-Archive -Path $zip -DestinationPath $tmpDir -Force
    $inner = Get-ChildItem $tmpDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    if (-not $inner) { throw 'The repository archive did not contain a directory.' }
    Copy-Item -Path (Join-Path $inner.FullName '*') -Destination $dot -Recurse -Force
    Write-Ok "Repository extracted to $dot."
    return $dot
}

function Ensure-BatSystemBatConfigSymlink {
    param()
    $source = Join-Path $HOME '.config/bat/config'
    if (-not (Test-Path $source)) { Write-Info 'Skipping ProgramData bat config link (user config absent).'; return }
    $target = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'bat/config'
    try {
        # If target exists and is already the correct symlink, exit early.
        if (Test-Path $target) {
            $item = Get-Item -LiteralPath $target -Force -ErrorAction Stop
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $cur = try { $item.Target } catch { $null }
                if ($cur -eq $source) { Write-Ok 'ProgramData bat config link already in place.'; return }
                Write-Warn 'Replacing existing ProgramData bat config symlink with new target.'
                Remove-Item -LiteralPath $target -Force
            }
            else {
                Write-Warn 'ProgramData bat config exists (not a symlink); overriding with symlink.'
                try { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop } catch { throw }
            }
        }
        else {
            $dir = Split-Path -Parent $target
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        }
        New-Item -ItemType SymbolicLink -Path $target -Target $source -Force | Out-Null
        Write-Ok 'ProgramData bat config link created.'
    }
    catch {
        $m = $_.Exception.Message
        if ($ElevateLink -and ($m -match 'denied|privilege|Administrator')) {
            Write-Info 'Retrying ProgramData bat config link creation with elevation.'
            $cmd = "if (Test-Path '$target') { Remove-Item -LiteralPath '$target' -Force }; if (-not (Test-Path '$(Split-Path -Parent $target)')) { New-Item -ItemType Directory -Path '$(Split-Path -Parent $target)' -Force | Out-Null }; New-Item -ItemType SymbolicLink -Path '$target' -Target '$source' -Force"
            try {
                $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmd) -Verb RunAs -PassThru
                $proc.WaitForExit()
                if (Test-Path $target) {
                    $it = Get-Item -LiteralPath $target -Force
                    if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) { Write-Ok 'ProgramData bat config link created (elevated).'; return }
                }
            }
            catch { Write-Warn "Elevated attempt failed: $($_.Exception.Message)" }
        }
        Write-Warn "Could not create ProgramData bat config link: $m"
        Write-Info "Manual (elevated) command: New-Item -ItemType SymbolicLink -Path '$target' -Target '$source' -Force"
    }
}

############################################################
# Execution
############################################################
try {
    Ensure-DeveloperModeIfNeeded
    Set-XdgConfig
    Test-WingetAvailable
    $repoPath = Get-RepoLocal
    Push-Location $repoPath
    Invoke-PackageInstall
    & "$PSScriptRoot/modules.ps1" -Quiet:$Quiet
    Invoke-FontInstall
    # Create symlinks; if it fails and -ElevateLink is set, retry with elevation
    try {
        Set-ConfigLinks
    }
    catch {
        if ($ElevateLink) {
            Write-Warn 'Linking failed, attempting to elevate only the link step.'
            $origHome = $HOME
            $linkScript = Join-Path $PSScriptRoot 'link.ps1'
            $elevArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $linkScript, '-Force', '-TargetHomePath', $origHome)
            if ($Quiet) { $elevArgs += '-Quiet' }
            if (-not $Global:DOTFILES_QUIET) { Write-Info ("Elevated link command args: " + ($elevArgs -join ' ')) }
            try {
                $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList $elevArgs -Verb RunAs -PassThru
                $proc.WaitForExit()
                if ($proc.ExitCode -eq 0) {
                    # Verify links actually exist (elevated output isn't captured in parent)
                    $repoConfigPath = Join-Path (Get-Location) '.config'
                    if (-not (Test-Path $repoConfigPath)) { Write-Warn 'Post-elevation: repo .config not found for verification.' }
                    $homeConfigPath = Join-Path $origHome '.config'
                    $missing = @(); $okCount = 0
                    if (Test-Path $repoConfigPath) {
                        Get-ChildItem -Path $repoConfigPath -Directory | ForEach-Object {
                            $dst = Join-Path $homeConfigPath $_.Name
                            if (Test-Path $dst) {
                                try {
                                    $it = Get-Item -LiteralPath $dst -Force -ErrorAction Stop
                                    if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) { $okCount++ }
                                    else { $missing += $_.Name }
                                }
                                catch { $missing += $_.Name }
                            }
                            else { $missing += $_.Name }
                        }
                    }
                    if ($missing.Count -eq 0 -and $okCount -gt 0) {
                        Write-Ok "Elevated link step verified ($okCount link(s) present)."
                    }
                    else {
                        Write-Warn "Elevated link step returned success but $($missing.Count) link(s) missing: $([string]::Join(', ', $missing))"
                        Write-Warn "Manual remediation: run an elevated PowerShell and execute:`n  powershell -NoProfile -ExecutionPolicy Bypass -File '$linkScript' -Force -TargetHomePath '$origHome'"
                    }
                }
                else {
                    Write-Err "Elevated link step failed with exit code $($proc.ExitCode)."
                    Write-Warn "If UAC elevation was blocked (e.g. non-interactive environment), manually run:`n  powershell -NoProfile -ExecutionPolicy Bypass -File '$linkScript' -Force -TargetHomePath '$origHome'"
                }
            }
            catch {
                Write-Err "Failed starting elevated link process: $($_.Exception.Message)"
                Write-Warn "Manual fallback: run elevated and execute link.ps1 with -Force and -TargetHomePath '$origHome'."
            }
        }
        else { throw }
    }
    & "$PSScriptRoot/profile-setup.ps1" -Quiet:$Quiet
    Ensure-BatSystemBatConfigSymlink
    if ($Verify) { & "$PSScriptRoot/self-test.ps1" -Quiet:$Quiet }
    Pop-Location
    Write-Ok 'Bootstrap completed successfully.'
    Write-Info 'To update later, run bin/sync.ps1 to download the latest archive and refresh links.'
}
catch {
    Write-Err $_
    exit 1
}
