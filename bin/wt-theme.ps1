<#!
.SYNOPSIS
Exports or imports Windows Terminal theme data.

.DESCRIPTION
Captures the active Windows Terminal color schemes, UI themes, and profile defaults
(colorScheme, font) into a portable JSON file stored in the repo.  On import, merges
the saved theme data into the target machine's Windows Terminal settings non-destructively.

.PARAMETER Export
Reads the current machine's Windows Terminal settings.json and writes theme data to
packages/windows-terminal-theme.json.

.PARAMETER Import
Reads packages/windows-terminal-theme.json and merges theme data into the current
machine's Windows Terminal settings.json.

.PARAMETER Quiet
Suppress informational messages.
#>
[CmdletBinding()]
param(
    [switch]$Export,
    [switch]$Import,
    [switch]$Quiet
)
############################################################
# Initialization
############################################################
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"
if ($Quiet) { $Global:DOTFILES_QUIET = $true }

$repoRoot = Split-Path $PSScriptRoot -Parent
$themeFile = Join-Path $repoRoot 'packages\windows-terminal-theme.json'

############################################################
# Helpers
############################################################
function Find-WTSettingsPath {
    $candidates = Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState\settings.json" -ErrorAction SilentlyContinue
    if (-not $candidates) { return $null }
    return ($candidates | Select-Object -First 1).FullName
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path)
    Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Data
    )
    $Data | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

############################################################
# Export
############################################################
function Invoke-ThemeExport {
    $wtSettings = Find-WTSettingsPath
    if (-not $wtSettings) { Write-Err 'Windows Terminal settings.json not found.'; exit 1 }
    Write-Info "Reading Windows Terminal settings from: $wtSettings"

    $settings = Read-JsonFile -Path $wtSettings

    $schemes = @()
    if ($settings.PSObject.Properties['schemes']) { $schemes = @($settings.schemes) }

    $themes = @()
    if ($settings.PSObject.Properties['themes']) { $themes = @($settings.themes) }

    $profileDefaults = @{}
    if ($settings.PSObject.Properties['profiles'] -and $settings.profiles.PSObject.Properties['defaults']) {
        $defaults = $settings.profiles.defaults
        if ($defaults.PSObject.Properties['colorScheme']) {
            $profileDefaults['colorScheme'] = $defaults.colorScheme
        }
        if ($defaults.PSObject.Properties['font']) {
            $profileDefaults['font'] = $defaults.font
        }
    }

    $exportData = [ordered]@{
        schemes         = $schemes
        themes          = $themes
        profileDefaults = $profileDefaults
    }

    Write-JsonFile -Path $themeFile -Data $exportData
    Write-Ok "Exported Windows Terminal theme to: $themeFile"
    Write-Info "Schemes: $($schemes.Count), Themes: $($themes.Count)"
}

############################################################
# Import
############################################################
function Invoke-ThemeImport {
    if (-not (Test-Path $themeFile)) { Write-Info 'No saved Windows Terminal theme file found; skipping.'; return }

    $wtSettings = Find-WTSettingsPath
    if (-not $wtSettings) { Write-Info 'Windows Terminal not installed; skipping theme import.'; return }
    Write-Info "Importing theme into: $wtSettings"

    $theme = Read-JsonFile -Path $themeFile
    $settings = Read-JsonFile -Path $wtSettings

    # Merge schemes (add/replace by name)
    $existingSchemes = @{}
    if ($settings.PSObject.Properties['schemes']) {
        foreach ($s in $settings.schemes) { $existingSchemes[$s.name] = $s }
    }
    foreach ($s in $theme.schemes) { $existingSchemes[$s.name] = $s }
    $settings.schemes = @($existingSchemes.Values)

    # Merge themes (add/replace by name)
    $existingThemes = @{}
    if ($settings.PSObject.Properties['themes']) {
        foreach ($t in $settings.themes) { $existingThemes[$t.name] = $t }
    }
    foreach ($t in $theme.themes) { $existingThemes[$t.name] = $t }
    $settings.themes = @($existingThemes.Values)

    # Set profile defaults
    if ($theme.PSObject.Properties['profileDefaults'] -and $theme.profileDefaults) {
        if (-not $settings.PSObject.Properties['profiles']) {
            $settings | Add-Member -NotePropertyName 'profiles' -NotePropertyValue ([pscustomobject]@{ defaults = [pscustomobject]@{} })
        }
        if (-not $settings.profiles.PSObject.Properties['defaults']) {
            $settings.profiles | Add-Member -NotePropertyName 'defaults' -NotePropertyValue ([pscustomobject]@{})
        }
        $pd = $theme.profileDefaults
        if ($pd.PSObject.Properties['colorScheme']) {
            if ($settings.profiles.defaults.PSObject.Properties['colorScheme']) {
                $settings.profiles.defaults.colorScheme = $pd.colorScheme
            }
            else {
                $settings.profiles.defaults | Add-Member -NotePropertyName 'colorScheme' -NotePropertyValue $pd.colorScheme
            }
        }
        if ($pd.PSObject.Properties['font']) {
            if ($settings.profiles.defaults.PSObject.Properties['font']) {
                $settings.profiles.defaults.font = $pd.font
            }
            else {
                $settings.profiles.defaults | Add-Member -NotePropertyName 'font' -NotePropertyValue $pd.font
            }
        }
    }

    Write-JsonFile -Path $wtSettings -Data $settings
    Write-Ok 'Windows Terminal theme imported successfully.'
}

############################################################
# Execution
############################################################
if (-not $Export -and -not $Import) {
    Write-Err 'Specify -Export or -Import.'; exit 1
}
if ($Export) { Invoke-ThemeExport }
if ($Import) { Invoke-ThemeImport }
