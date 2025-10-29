<#!
.SYNOPSIS
Audits installed winget packages versus manifest.

.DESCRIPTION
Normalizes manifest entries, captures a single winget list snapshot, and reports status
per package (Installed, Missing, Drift). Can emit JSON for automation.
#>
[CmdletBinding()]
param(
    [switch]$Quiet,
    [switch]$Json,
    [string]$ManifestPath
)
############################################################
# Initialization
############################################################
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"
if ($Quiet) { $Global:DOTFILES_QUIET = $true }

$repoRoot = Split-Path $PSScriptRoot -Parent
$pkgFile  = if ($ManifestPath) { Resolve-Path -LiteralPath $ManifestPath -ErrorAction Stop } else { Join-Path $repoRoot 'packages\windows-winget.json' }
if (-not (Test-Path $pkgFile)) { Write-Err 'Package manifest not found.'; exit 2 }

try { $raw = Get-Content -Raw -Path $pkgFile | ConvertFrom-Json } catch { Write-Err "Failed to parse package manifest: $($_.Exception.Message)"; exit 2 }

############################################################
# Manifest Normalization
############################################################
$entries = @()
foreach ($e in $raw) {
    if ($e -is [string]) {
        $entries += [pscustomobject]@{ Id = $e; ExpectedVersion = $null; Pinned = $false }
    }
    else {
        $entries += [pscustomobject]@{ Id = $e.id; ExpectedVersion = $e.version; Pinned = [bool]$e.pinned }
    }
}

############################################################
# Snapshot Current State
############################################################
try { $wingetList = winget list --accept-source-agreements 2>$null | Out-String } catch { $wingetList = '' }

############################################################
# Functions
############################################################
function Get-WingetInstalledVersion {
    param([Parameter(Mandatory)][string]$Id)
    if (-not $wingetList) { return $null }
    # Search snapshot lines for one containing the exact ID token
    $lines = $wingetList -split "`r?`n"
    $line = $lines | Where-Object { $_ -match "(?i)\b$([regex]::Escape($Id))\b" } | Select-Object -First 1
    if ($line) {
        # Parse winget list output: columns are typically Name | Id | Version | Available | Source
        # Split by 2+ spaces to handle columns with spaces in them
        $cols = @(($line -split '\s{2,}') | Where-Object { $_ -and ($_ -notmatch '^\-+$') })
        if ($cols -and ($cols -is [System.Array]) -and $cols.Count -ge 3) {
            # Version is typically the third column
            $candidate = ($cols[2] -split '\s+')[0]
            if ($candidate -and $candidate -match '^[0-9]') { 
                return $candidate 
            }
        }
        # Fallback: scan all tokens for version-looking pattern
        $tokens = ($line -split '\s+') | Where-Object { $_ -ne '' }
        $verToken = $tokens | Where-Object { $_ -match '^[0-9]+[0-9A-Za-z._-]*$' } | Select-Object -First 1
        if ($verToken) { return $verToken }
        return 'UNKNOWN'
    }
    return $null
}

############################################################
# Evaluation
############################################################
$result = @()
foreach ($pkg in $entries) {
    $installedVer = Get-WingetInstalledVersion $pkg.Id
    $status = if ($installedVer) { 'Installed' } else { 'Missing' }
    $note = ''
    $ok = $true
    if (-not $installedVer) {
        $ok = $false; $note = 'Not installed'
    }
    elseif ($pkg.Pinned -and $pkg.ExpectedVersion) {
        if ($installedVer -ne $pkg.ExpectedVersion) { $ok = $false; $status = 'Drift'; $note = "Expected ${($pkg.ExpectedVersion)}" }
    }
    elseif ($pkg.ExpectedVersion -and $pkg.Pinned) {
        # already handled; placeholder else
    }
    $result += [pscustomobject]@{
        Id       = $pkg.Id
        Version  = $installedVer
        Expected = $pkg.ExpectedVersion
        Pinned   = $pkg.Pinned
        Status   = $status
        Note     = $note
        OK       = $ok
    }
}

############################################################
# Output
############################################################
if ($Json) { $result | ConvertTo-Json -Depth 4 }
else { $result | Sort-Object Status, Id | Format-Table Id, Version, Expected, Pinned, Status, Note -AutoSize }

############################################################
# Exit Status
############################################################
$bad = @($result | Where-Object { -not $_.OK })
$failCount = $bad.Count
if ($failCount -gt 0) { Write-Err "Audit detected $failCount issue(s)."; exit 1 } else { Write-Ok 'Audit passed (no issues detected).' }
