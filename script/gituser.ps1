# Usage: .\script\gituser.ps1
# Sets up user Git configuration.

$GITCONFIG_USER = "$HOME\.gitconfig_user"

# Create $GITCONFIG_USER if nonexistent
if (-not (Test-Path $GITCONFIG_USER)) {
    New-Item -ItemType File -Path $GITCONFIG_USER | Out-Null
}

# Set user.name if nonexistent
$USER_NAME = (git config --file $GITCONFIG_USER user.name)
if (-not $USER_NAME) {
    Write-Host "What is your full name?"
    $USER_NAME = Read-Host
    git config --file $GITCONFIG_USER user.name $USER_NAME
} else {
    Write-Host "user.name=$USER_NAME"
}

# Set user.email if nonexistent
$USER_EMAIL = (git config --file $GITCONFIG_USER user.email)
if (-not $USER_EMAIL) {
    Write-Host "What is your email?"
    $USER_EMAIL = Read-Host
    git config --file $GITCONFIG_USER user.email $USER_EMAIL
} else {
    Write-Host "user.email=$USER_EMAIL"
}

# Set github.user if nonexistent
$GITHUB_USER = (git config --file $GITCONFIG_USER github.user)
if (-not $GITHUB_USER) {
    Write-Host "What is your GitHub username?"
    $GITHUB_USER = Read-Host
    git config --file $GITCONFIG_USER github.user $GITHUB_USER
} else {
    Write-Host "github.user=$GITHUB_USER"
}
