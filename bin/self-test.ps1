<#!
.SYNOPSIS
Runs post-bootstrap validation tests.

.DESCRIPTION
Executes a series of idempotent checks (symlink capability or existing links, font,
packages, modules, profile stubs) and reports pass/warn/fail results with exit codes.
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

$fail = @()
$warn = @()

############################################################
# Functions
############################################################
function Test-Step {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ScriptBlock]$Block,
        [switch]$WarnOnFail
    )
    try { & $Block | Out-Null; Write-Ok "${Name}: PASS" }
    catch {
        if ($WarnOnFail) {
            $warn += "${Name}: $($_.Exception.Message)"; Write-Warn "${Name}: WARN - $($_.Exception.Message)"
        }
        else {
            $fail += "${Name}: $($_.Exception.Message)"; Write-Err "${Name}: FAIL - $($_.Exception.Message)"
        }
    }
}

############################################################
# Tests
############################################################
# 1 Symlink capability (functional) – if missing but required links already exist, suppress warning
Test-Step 'SymlinkCapability' {
    $g = [guid]::NewGuid().Guid; $src = Join-Path $env:TEMP "df_st_src_$g"; $ln = Join-Path $env:TEMP "df_st_ln_$g";
    New-Item -ItemType Directory -Path $src -ErrorAction Stop | Out-Null
    $ok = $true
    try { New-Item -ItemType SymbolicLink -Path $ln -Target $src -ErrorAction Stop | Out-Null } catch { $ok = $false } finally { Remove-Item -LiteralPath $ln -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath $src -Recurse -Force -ErrorAction SilentlyContinue }
    if (-not $ok) {
        # Check if repo links are already present; if so treat as pass (no need for further capability now)
        $repoConfig = Join-Path (Split-Path $PSScriptRoot -Parent) '.config'
        $homeConfig = Join-Path $HOME '.config'
        $missing = @()
        if (Test-Path $repoConfig) {
            if (Test-Path $homeConfig) {
            Get-ChildItem -Path $repoConfig -Directory | ForEach-Object {
                $dst = Join-Path $homeConfig $_.Name
                if (-not (Test-Path $dst)) { $missing += $_.Name }
            }
            }
        }
        if ($missing.Count -gt 0) { throw 'Administrator privilege required for this operation.' }
    }
} -WarnOnFail

# 2 Font present
Test-Step 'FontInstalled' {
    $fontsDir = Join-Path $env:LOCALAPPDATA 'Microsoft/Windows/Fonts'
    Get-ChildItem -Path $fontsDir -Filter '*Cascadia*Code*NF*.ttf' -ErrorAction Stop | Out-Null
}

# 3 Packages installed
Test-Step 'PackagesInstalled' {
    $list = winget list 2>$null | Out-String
    $pkgFile = Join-Path (Split-Path $PSScriptRoot -Parent) 'packages/windows-winget.json'
    $pkgs = Get-Content -Raw -Path $pkgFile | ConvertFrom-Json
    foreach ($pkg in $pkgs) {
        $id = if ($pkg -is [string]) { $pkg } else { $pkg.id }
        if ($list -notmatch [regex]::Escape($id)) { throw "Missing package: $id" }
    }
}

# 4 PS Modules (fallback to InstalledModule if ListAvailable misses it)
Test-Step 'ModulesInstalled' {
    foreach ($m in 'PSReadLine', 'CompletionPredictor') {
        $list = Get-Module -ListAvailable -Name $m -ErrorAction SilentlyContinue
        if (-not $list) {
            $inst = Get-InstalledModule -Name $m -ErrorAction SilentlyContinue
            if (-not $inst) { throw "Missing module: $m" }
        }
    }
}

# 5 Profile stub
Test-Step 'ProfileStub' {
    $p1 = Join-Path $HOME 'Documents/PowerShell/Microsoft.PowerShell_profile.ps1'
    $p2 = Join-Path $HOME 'Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1'
    if (-not (Test-Path $p1) -and -not (Test-Path $p2)) { throw 'No profile stubs found' }
}

############################################################
# Summary / Exit
############################################################
if ($fail.Count -gt 0) {
    Write-Err "Self-test failed: $($fail.Count) issue(s)."; $fail | ForEach-Object { Write-Err $_ }
    if ($warn.Count -gt 0) { Write-Warn "Warnings: $($warn.Count)"; $warn | ForEach-Object { Write-Warn $_ } }
    exit 1
}
else {
    if ($warn.Count -gt 0) {
        Write-Ok 'Self-test passed with warnings.'; $warn | ForEach-Object { Write-Warn $_ }
    }
    else { Write-Ok 'All self-tests passed.' }
}
