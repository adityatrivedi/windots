<#!
.SYNOPSIS
Bootstraps dotfiles environment on a Windows system.

.DESCRIPTION
Ensures symlink capability (optionally enabling Developer Mode), sets XDG config path,
installs winget (App Installer) automatically if missing, uses local repo, installs
packages, modules, fonts, creates symlinked config directories, installs profile stubs,
and runs self-tests optionally.
#>
[CmdletBinding()]
param (
    [switch]$Quiet,
    [switch]$ElevateLink,
    [switch]$Verify,
    [switch]$Help
)

############################################################
# Handle irm | iex scenario (no $PSScriptRoot)
############################################################
if (-not $PSScriptRoot) {
    # Running via irm | iex - download and run the real bootstrap
    $defaultZip = 'https://github.com/adityatrivedi/windots/archive/refs/heads/main.zip'
    $dot = Join-Path $HOME '.dotfiles'

    Write-Host '[INFO] Detected remote execution (irm | iex). Downloading repository...' -ForegroundColor Cyan

    if (-not (Test-Path $dot)) { New-Item -ItemType Directory -Path $dot -Force | Out-Null }

    $zip = Join-Path $env:TEMP 'dotfiles.zip'
    Invoke-WebRequest -Uri $defaultZip -OutFile $zip -UseBasicParsing

    Write-Host '[INFO] Extracting repository...' -ForegroundColor Cyan
    $tmpDir = Join-Path $env:TEMP ('dotfiles_' + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    Expand-Archive -Path $zip -DestinationPath $tmpDir -Force

    $inner = Get-ChildItem $tmpDir -Directory | Select-Object -First 1
    if (-not $inner) { throw 'Archive did not contain a directory.' }

    Copy-Item -Path (Join-Path $inner.FullName '*') -Destination $dot -Recurse -Force
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host '[ OK ] Repository extracted. Running bootstrap...' -ForegroundColor Green

    # Run the actual bootstrap from disk
    & (Join-Path $dot 'bin\bootstrap.ps1') -ElevateLink -Verify
    return
}

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
    -ElevateLink       If non-admin symlink creation fails, elevate ONLY the link step (principle of least privilege).
    -Verify            Run self-test after setup (invokes self-test.ps1).
    -Quiet             Suppress informational [INFO] messages (warnings/errors still shown).
    -Help / -?         Show this help and exit.

Standard PowerShell common parameters (e.g. -Verbose, -WhatIf where supported) are also available.

Examples:
    # One-liner (downloads & sets up automatically):
    irm https://raw.githubusercontent.com/adityatrivedi/windots/main/bin/bootstrap.ps1 | iex

    # Already cloned, minimized noise:
    ./bin/bootstrap.ps1 -ElevateLink -Quiet

Behavior Summary:
    1. Ensures (or enables) Developer Mode for symlink privilege (may elevate only that registry write).
    2. Sets XDG_CONFIG_HOME (user scope) if not already set.
    3. Installs winget (App Installer) automatically if not found on the system.
    4. Detects repo location ($HOME/.dotfiles or current directory).
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

function Ensure-WingetAvailable {
    param()
    if (Get-Command winget -ErrorAction SilentlyContinue) { Write-Ok 'Winget is available.'; return }

    Write-Info 'Winget not found. Installing App Installer (winget) automatically...'
    $tmpDir = Join-Path $env:TEMP ('dotfiles_winget_' + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    try {
        # 1. VCLibs dependency
        $vcLibs = Join-Path $tmpDir 'Microsoft.VCLibs.x64.Desktop.appx'
        Write-Info 'Downloading Microsoft.VCLibs.140.00.UWPDesktop...'
        Invoke-WebRequest -Uri 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' -OutFile $vcLibs -UseBasicParsing
        Add-AppxPackage -Path $vcLibs -ErrorAction SilentlyContinue

        # 2. Microsoft.UI.Xaml dependency (extract x64 appx from NuGet package)
        $uiXamlNupkg = Join-Path $tmpDir 'Microsoft.UI.Xaml.nupkg.zip'
        Write-Info 'Downloading Microsoft.UI.Xaml...'
        Invoke-WebRequest -Uri 'https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6' -OutFile $uiXamlNupkg -UseBasicParsing
        $uiXamlDir = Join-Path $tmpDir 'uixaml'
        Expand-Archive -Path $uiXamlNupkg -DestinationPath $uiXamlDir -Force
        $uiXamlAppx = Join-Path $uiXamlDir 'tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx'
        if (Test-Path $uiXamlAppx) {
            Add-AppxPackage -Path $uiXamlAppx -ErrorAction SilentlyContinue
        }
        else { Write-Warn 'Microsoft.UI.Xaml appx not found at expected path; winget install may still succeed.' }

        # 3. App Installer (winget)
        $appInstaller = Join-Path $tmpDir 'AppInstaller.msixbundle'
        Write-Info 'Downloading App Installer (winget)...'
        Invoke-WebRequest -Uri 'https://aka.ms/getwinget' -OutFile $appInstaller -UseBasicParsing
        Add-AppxPackage -Path $appInstaller

        # Verify
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Ok 'Winget installed successfully.'
        }
        else {
            throw "Winget installation completed but 'winget' command is still not available. Please install 'App Installer' manually from the Microsoft Store and re-run bootstrap."
        }
    }
    catch {
        throw "Failed to install winget automatically: $($_.Exception.Message). Please install 'App Installer' from the Microsoft Store and re-run bootstrap."
    }
    finally {
        Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-PackageInstall { param(); & "$PSScriptRoot/install.ps1" }

function Set-ConfigLinks { param(); & "$PSScriptRoot/link.ps1" -Force -Quiet:$Quiet }

function Get-RepoLocal {
    param()
    $dot = Join-Path $HOME '.dotfiles'
    # Check if .dotfiles already exists and has content (e.g. from one-liner install)
    if (Test-Path (Join-Path $dot '.config')) { return $dot }

    # Otherwise assume current directory is the repo (git clone workflow)
    Write-Info 'Assuming the current folder is the repository.'
    return (Get-Location).Path
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
    Ensure-WingetAvailable
    $repoPath = Get-RepoLocal
    Push-Location $repoPath
    Invoke-PackageInstall
    & "$PSScriptRoot/modules.ps1" -Quiet:$Quiet
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
    & "$PSScriptRoot/wt-theme.ps1" -Import -Quiet:$Quiet
    Ensure-BatSystemBatConfigSymlink
    # Restore yazi packages (flavors/plugins) from package.toml
    if (Get-Command ya -ErrorAction SilentlyContinue) {
        $yaziPkg = Join-Path (Get-Location) '.config/yazi/package.toml'
        if (Test-Path $yaziPkg) {
            Write-Info 'Restoring yazi packages...'
            $env:YAZI_CONFIG_HOME = Join-Path $HOME '.config/yazi'
            ya pkg install 2>$null
            Write-Ok 'Yazi packages restored.'
        }
    }
    if ($Verify) { & "$PSScriptRoot/self-test.ps1" -Quiet:$Quiet }
    Pop-Location
    Write-Ok 'Bootstrap completed successfully.'
    Write-Info 'To update later, re-run the one-liner or run git pull && ./bin/bootstrap.ps1 from your clone.'
}
catch {
    Write-Err $_
    exit 1
}
