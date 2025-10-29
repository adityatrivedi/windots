<#
 Central PowerShell profile (dotfiles)
 - Dot-sourced by per-shell stubs in standard $PROFILE locations
 - Keep lightweight: perform cheap checks first, then conditional inits
 - Idempotent: safe to Reload
#>

############################################################
# 0. Core Environment / Paths
############################################################
if (-not $env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME = Join-Path $HOME '.config' }
if (-not $env:EDITOR) { $env:EDITOR = 'nvim' }
if (-not $env:PAGER) { $env:PAGER = 'bat' }
if (-not $env:BAT_CONFIG_DIR) { $env:BAT_CONFIG_DIR = Join-Path $env:XDG_CONFIG_HOME 'bat' }
if (-not $env:BAT_CONFIG_PATH) { $env:BAT_CONFIG_PATH = Join-Path $env:BAT_CONFIG_DIR 'config' }

############################################################
# 1. Utilities
############################################################
function Test-Cmd { param([Parameter(Mandatory)][string]$Name) [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue) }
function Import-SafeModule {
    param([Parameter(Mandatory)][string]$Name)
    if (Get-Module -ListAvailable -Name $Name) { Import-Module $Name -ErrorAction SilentlyContinue }
}
function Refresh-Profile {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $profilePath = Join-Path $env:XDG_CONFIG_HOME 'powershell/profile.ps1'
    if (-not (Test-Path $profilePath)) { Write-Warning "Profile not found: $profilePath"; return }
    . $profilePath
    $sw.Stop(); Write-Information "[profile reloaded in $($sw.ElapsedMilliseconds) ms]"
}

############################################################
# 2. Prompt & Navigation Tools
############################################################
function Initialize-Starship {
    if (Test-Cmd starship) {
        $env:STARSHIP_CONFIG = Join-Path $env:XDG_CONFIG_HOME 'starship/starship.toml'
        try {
            # PSScriptAnalyzer SuppressMessage PSAvoidUsingInvokeExpression Justification = 'Vendor init emits dynamic script'
            Invoke-Expression (& starship init powershell)
        }
        catch { Write-Verbose ("Starship init failed: " + $_.Exception.Message) }
    }
}
function Initialize-Zoxide {
    if (Test-Cmd zoxide) {
        try {
            # PSScriptAnalyzer SuppressMessage PSAvoidUsingInvokeExpression Justification = 'Vendor init emits dynamic script'
            Invoke-Expression (& { (zoxide init powershell | Out-String) })
        }
        catch { Write-Verbose ("Zoxide init failed: " + $_.Exception.Message) }
    }
}
Initialize-Starship
Initialize-Zoxide

############################################################
# 3. Line Editing / Prediction
############################################################
Import-SafeModule PSReadLine
if (Get-Module PSReadLine) {
    Set-PSReadLineOption -EditMode Windows -ErrorAction SilentlyContinue
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete -ErrorAction SilentlyContinue
    if (Get-Module -ListAvailable -Name CompletionPredictor) {
        Import-SafeModule CompletionPredictor
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction SilentlyContinue
    }
}

############################################################
# 4. Eza Configuration
############################################################
function Get-ChildItemEza {
    param(
        [string]$Path = (Get-Location)
    )
    eza -all --git-repos-no-status -long --show-symlinks --header --icons --hyperlink --color always --group-directories-first --time-style relative $Path
}

############################################################
# 5. Aliases
############################################################
Set-Alias -Name g -Value git
Set-Alias -Name cat -Value bat -Option AllScope
Set-Alias -Name ls -Value Get-ChildItemEza -Option AllScope
Set-Alias -Name lg -Value lazygit
Set-Alias -Name v -Value nvim
