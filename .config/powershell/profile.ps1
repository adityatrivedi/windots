<#
 Central PowerShell profile (dotfiles)
 - Dot-sourced by per-shell stubs in standard $PROFILE locations
 - Keep lightweight: perform cheap checks first, then conditional inits
 - Idempotent: safe to Reload
 - Non-essential tools (zoxide, CompletionPredictor) are deferred to OnIdle
#>

############################################################
# 0. Core Environment / Paths
############################################################
if (-not $env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME = Join-Path $HOME '.config' }
if (-not $env:EDITOR) { $env:EDITOR = 'nvim' }
if (-not $env:PAGER) { $env:PAGER = 'bat' }
if (-not $env:BAT_CONFIG_DIR) { $env:BAT_CONFIG_DIR = Join-Path $env:XDG_CONFIG_HOME 'bat' }
if (-not $env:BAT_CONFIG_PATH) { $env:BAT_CONFIG_PATH = Join-Path $env:BAT_CONFIG_DIR 'config' }
if (-not $env:YAZI_CONFIG_HOME) { $env:YAZI_CONFIG_HOME = Join-Path $env:XDG_CONFIG_HOME 'yazi' }

# Prevent routing of native command failures through $ErrorActionPreference
$PSNativeCommandUseErrorActionPreference = $false

############################################################
# 1. Utilities
############################################################
function Test-Cmd { param([Parameter(Mandatory)][string]$Name) [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue) }
function Import-SafeModule {
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Get-Module -Name $Name)) { Import-Module $Name -ErrorAction SilentlyContinue }
}
function Refresh-Profile {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $profilePath = Join-Path $env:XDG_CONFIG_HOME 'powershell/profile.ps1'
    if (-not (Test-Path $profilePath)) { Write-Warning "Profile not found: $profilePath"; return }
    . $profilePath
    $sw.Stop(); Write-Information "[profile reloaded in $($sw.ElapsedMilliseconds) ms]"
}

############################################################
# 2. Prompt (synchronous — needed for first render)
############################################################
if (Test-Cmd starship) {
    $env:STARSHIP_CONFIG = Join-Path $env:XDG_CONFIG_HOME 'starship/starship.toml'
    try { Invoke-Expression (& starship init powershell) }
    catch { Write-Verbose ("Starship init failed: " + $_.Exception.Message) }
}

############################################################
# 3. Line Editing / Prediction (synchronous — needed for input)
############################################################
Import-SafeModule PSReadLine
if (Get-Module PSReadLine) {
    $psrlOpts = @{
        EditMode                      = 'Windows'
        PredictionSource              = 'History'
        PredictionViewStyle           = 'ListView'
        HistorySearchCursorMovesToEnd = $true
    }
    Set-PSReadLineOption @psrlOpts -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward -ErrorAction SilentlyContinue
}

############################################################
# 4. Yazi Wrapper (cd on exit)
############################################################
function Invoke-Yazi {
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi $args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -ErrorAction SilentlyContinue
    if ($cwd -and $cwd -ne $PWD.Path -and (Test-Path $cwd)) {
        Set-Location -LiteralPath $cwd
    }
    Remove-Item -Path $tmp -ErrorAction SilentlyContinue
}

############################################################
# 5. Eza Configuration
############################################################
function Get-ChildItemEza {
    param(
        [string]$Path = (Get-Location)
    )
    eza -all --git-repos-no-status -long --show-symlinks --header --icons --hyperlink --color always --group-directories-first --time-style relative $Path
}

############################################################
# 6. Aliases
############################################################
function .. { Set-Location .. }
Set-Alias -Name cat -Value bat -Option AllScope
Set-Alias -Name g   -Value git
Set-Alias -Name lg  -Value lazygit
Set-Alias -Name ls  -Value Get-ChildItemEza -Option AllScope
Set-Alias -Name v   -Value nvim
Set-Alias -Name y   -Value Invoke-Yazi

############################################################
# 6. Deferred Init (loads after first prompt via OnIdle)
############################################################
$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    # Zoxide (directory jumper)
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        try { Invoke-Expression (& { (zoxide init powershell | Out-String) }) }
        catch {}
    }

    # CompletionPredictor (enhances PSReadLine predictions)
    Import-Module CompletionPredictor -ErrorAction SilentlyContinue
    if (Get-Module CompletionPredictor) {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction SilentlyContinue
    }
}
