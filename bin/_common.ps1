try {
    $qVar = Get-Variable -Name DOTFILES_QUIET -Scope Global -ErrorAction Stop
} catch {
    $qVar = $null
}
if (-not $qVar) {
    $Global:DOTFILES_QUIET = $false
}

# Logging functions
function Write-Info { param([string]$Message) if ($Global:DOTFILES_QUIET) { return } Write-Information -MessageData "[INFO] $Message" -InformationAction Continue }
function Write-Warn { param([string]$Message) Write-Warning $Message }
function Write-Ok   { param([string]$Message) if ($Global:DOTFILES_QUIET) { return } Write-Information -MessageData "[ OK ] $Message" -InformationAction Continue }
function Write-Err  { param([string]$Message) Write-Error -Message $Message -ErrorAction Continue }
