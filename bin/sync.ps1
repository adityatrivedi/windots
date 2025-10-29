<#!
.SYNOPSIS
Synchronizes (refreshes) the local extracted dotfiles repository.

.DESCRIPTION
Downloads the repository ZIP archive from the provided URL, extracts its contents to the
user's ~/.dotfiles directory (creating it if missing), then re-runs link.ps1 to ensure
symbolic links are up to date. Idempotent and safe for repeated execution.

.PARAMETER RepoZipUrl
The URL to a ZIP archive of the dotfiles repository (e.g., GitHub release asset or archive).

.PARAMETER Quiet
Suppresses informational/OK output (warnings/errors still shown).

.EXAMPLE
./sync.ps1 -RepoZipUrl https://example.com/dotfiles.zip
Refresh local dotfiles and relink.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepoZipUrl,
    [switch]$Quiet
)

############################################################
# Initialization
############################################################

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot\_common.ps1"
if ($Quiet) {
    $Global:DOTFILES_QUIET = $true
}

############################################################
# Execution
############################################################
try {
    $dot = Join-Path $HOME '.dotfiles'
    if (-not (Test-Path $dot)) {
        New-Item -ItemType Directory -Path $dot | Out-Null
    }
    $zip = Join-Path $env:TEMP 'dotfiles.zip'
    Write-Info "Downloading repository archive from $RepoZipUrl."
    Invoke-WebRequest -Uri $RepoZipUrl -OutFile $zip -UseBasicParsing
    $tmp = Join-Path $env:TEMP ('dotfiles_sync_' + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $tmp | Out-Null
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $inner = Get-ChildItem $tmp | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    if (-not $inner) {
        throw 'The downloaded ZIP archive does not contain a top-level folder.'
    }
    Copy-Item -Path (Join-Path $inner.FullName '*') -Destination $dot -Recurse -Force
    & (Join-Path $dot 'bin/link.ps1')
    Write-Ok 'Synchronization completed successfully.'
}
############################################################
# Error Handling
############################################################
catch {
    Write-Err $_
    exit 1
}
