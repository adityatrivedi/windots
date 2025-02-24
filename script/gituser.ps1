<#
.SYNOPSIS
Sets up user Git configuration.

.DESCRIPTION
This script sets up the user's Git configuration by prompting for the user's full name, email, and GitHub username if they are not already set.

.PARAMETER GITCONFIG_USER
The path to the user-specific Git configuration file.

.EXAMPLE
.\script\gituser.ps1
This command runs the script to set up the user's Git configuration.
#>

# Define the path to the user-specific Git configuration file
$GITCONFIG_USER = "$HOME\.gitconfig_user"

# Function to prompt for and set a Git configuration value if it is not already set
function Set-GitConfigValue {
    param (
        [string]$ConfigFile,
        [string]$ConfigKey,
        [string]$PromptMessage
    )

    $ConfigValue = git config --file $ConfigFile $ConfigKey
    if (-not $ConfigValue) {
        Write-Host $PromptMessage
        $ConfigValue = Read-Host
        git config --file $ConfigFile $ConfigKey $ConfigValue
    } else {
        Write-Host "$ConfigKey=$ConfigValue"
    }
}

# Create the user-specific Git configuration file if it does not exist
if (-not (Test-Path $GITCONFIG_USER)) {
    New-Item -ItemType File -Path $GITCONFIG_USER | Out-Null
}

# Set user.name if it is not already set
Set-GitConfigValue -ConfigFile $GITCONFIG_USER -ConfigKey "user.name" -PromptMessage "What is your full name?"

# Set user.email if it is not already set
Set-GitConfigValue -ConfigFile $GITCONFIG_USER -ConfigKey "user.email" -PromptMessage "What is your email?"

# Set github.user if it is not already set
Set-GitConfigValue -ConfigFile $GITCONFIG_USER -ConfigKey "github.user" -PromptMessage "What is your GitHub username?"
