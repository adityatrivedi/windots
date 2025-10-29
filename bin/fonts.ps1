<#!
.SYNOPSIS
Installs Cascadia Code Nerd Font (user scope only).

.DESCRIPTION
Downloads latest Cascadia Code Nerd Font release, extracts TTFs, and copies any missing
files into the user's local fonts directory. Idempotent and supports WhatIf/Confirm.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
param(
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
# Native helpers (GDI/User32) for immediate font availability
############################################################
if (-not ('Dotfiles.Win32' -as [type])) {
    $typeDef = @"
using System;
using System.Runtime.InteropServices;
namespace Dotfiles {
    public static class Win32 {
        [DllImport("gdi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
        public static extern int AddFontResourceEx(string lpszFileName, uint fl, IntPtr pdv);

        [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
    }
}
"@
    Add-Type -TypeDefinition $typeDef -Language CSharp
}

function Register-FontFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        $added = [Dotfiles.Win32]::AddFontResourceEx($Path, 0, [IntPtr]::Zero)
        if ($added -gt 0) { return $true } else { return $false }
    }
    catch { return $false }
}

function Notify-FontChange {
    try {
        $HWND_BROADCAST = [IntPtr]0xffff
        $WM_FONTCHANGE = 0x001D
        $SMTO_ABORTIFHUNG = 0x0002
        $rv = [UIntPtr]::Zero
        [void][Dotfiles.Win32]::SendMessageTimeout($HWND_BROADCAST, [uint32]$WM_FONTCHANGE, [UIntPtr]::Zero, [IntPtr]::Zero, [uint32]$SMTO_ABORTIFHUNG, 2000, [ref]$rv)
        Write-Ok 'Broadcasted WM_FONTCHANGE to notify applications of new fonts.'
    }
    catch { Write-Warn ("Failed to broadcast font change: " + $_.Exception.Message) }
}

############################################################
# Ensure Target Directory
############################################################
$fontsDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
if (-not (Test-Path $fontsDir)) {
    New-Item -ItemType Directory -Path $fontsDir | Out-Null
}

############################################################
# Short-Circuit If Already Installed
############################################################
$existingNf = @(Get-ChildItem -Path $fontsDir -Filter '*Caskaydia*NF*.ttf' -ErrorAction SilentlyContinue) + @(Get-ChildItem -Path $fontsDir -Filter '*Cascadia*Code*NF*.ttf' -ErrorAction SilentlyContinue)
if ($existingNf.Count -gt 0) {
    Write-Ok 'Cascadia Code Nerd Font is already present in the user fonts directory.'
    return
}

############################################################
# Download & Extract
############################################################
$zipUrl = 'https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip'
$zipPath = Join-Path $env:TEMP 'CascadiaCode.zip'
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
$extract = Join-Path $env:TEMP ('CascadiaCode_' + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $extract | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $extract -Force

############################################################
# Copy (Idempotent)
############################################################
$copied = $false
Get-ChildItem -Path $extract -Filter '*.ttf' -Recurse | ForEach-Object {
    $dest = Join-Path $fontsDir $_.Name
    if (-not (Test-Path $dest)) {
        if ($PSCmdlet.ShouldProcess($dest, 'Install font')) {
            Copy-Item $_.FullName $dest
            $copied = $true
            # Proactively register in current session so apps see it immediately
            if (-not (Register-FontFile -Path $dest)) { Write-Verbose "GDI did not report adding font: $($_.Name)" }
        }
    }
}
if ($copied) {
    # Notify the system so running apps refresh their font lists
    Notify-FontChange
    Write-Ok 'Cascadia Code Nerd Font has been installed for the current user.'
}
else {
    Write-Ok 'Cascadia Code Nerd Font is already present in the user fonts directory.'
}
