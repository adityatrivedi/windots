#Requires -RunAsAdministrator

# Set working directory
Set-Location $PSScriptRoot
[Environment]::CurrentDirectory = $PSScriptRoot

# Linked Files (Destination => Source)
$symlinks = @{
    $PROFILE.CurrentUserAllHosts                                                                    = ".\powershell\profile.ps1"
    "$HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" = ".\windowsterminal\settings.json"
    "$HOME\.gitconfig"                                                                              = ".\git\.gitconfig"
}

# Dependencies
$wingetPackages = @(
    "AgileBits.1Password.CLI",
    "AgileBits.1Password",
    "Armin2208.WindowsAutoNightMode",
    "Git.Git",
    "GitHub.cli",
    "JanDeDobbeleer.OhMyPosh",
    "JesseDuffield.lazygit",
    "Microsoft.PowerToys",
    "Microsoft.VisualStudioCode",
    "Microsoft.WindowsTerminal"
)

$scoopPackages = @(
    "Cascadia-Code",
    "neovim",
    "psreadline",
    "terminal-icons", 
    "z"
)

$scoopBuckets = @(
    "extras",
    "nerd-fonts"
)

# PS Modules
$psModules = @(
    "PSScriptAnalyzer",
    "CompletionPredictor"
)

# Install dependencies
Write-Host "Installing missing dependencies..."

$installedwingetPackages = winget list | Out-String
foreach ($wingetDep in $wingetPackages) {
    if ($installedwingetPackages -notmatch $wingetDep) {
        winget install --id $wingetDep
    }
}

# Set environment Path
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Install Scoop if not installed
if (-not (Get-Command "scoop" -ErrorAction SilentlyContinue)) {
    Invoke-RestMethod get.scoop.sh | Invoke-Expression
}

# Function to check if a Scoop package is installed.
function Test-ScoopPackageInstalled {
    <#
    .SYNOPSIS
    Checks if a Scoop package is installed.

    .DESCRIPTION
    This function checks if a specified Scoop package is installed on the system.

    .PARAMETER packageName
    The name of the Scoop package to check.

    .EXAMPLE
    Test-ScoopPackageInstalled -packageName "neovim"

    This command checks if the "neovim" package is installed via Scoop.
    #>

    param(
        [string]$packageName
    )

    $installedPackages = scoop list
    return $installedPackages -like "*$packageName*"
}

# Function to check if a Scoop bucket is added.
function Test-ScoopBucketAdded {
    <#
    .SYNOPSIS
    Checks if a Scoop bucket is added.

    .DESCRIPTION
    This function checks if a specified Scoop bucket is added to the system.

    .PARAMETER bucketName
    The name of the Scoop bucket to check.

    .EXAMPLE
    Test-ScoopBucketAdded -bucketName "extras"

    This command checks if the "extras" bucket is added to Scoop.
    #>

    param(
        [string]$bucketName
    )

    $addedBuckets = scoop bucket known
    return $addedBuckets -contains $bucketName
}

# Function to install Scoop buckets.
function Install-ScoopBuckets {
    <#
    .SYNOPSIS
    Installs Scoop buckets if they are not already added.

    .DESCRIPTION
    This function installs specified Scoop buckets if they are not already added to the system.

    .PARAMETER bucketNames
    An array of names of the Scoop buckets to install.

    .EXAMPLE
    Install-ScoopBuckets -bucketNames @("extras", "nerd-fonts")

    This command installs the "extras" and "nerd-fonts" Scoop buckets if they are not already added.
    #>

    param(
        [string[]]$bucketNames
    )

    foreach ($bucket in $bucketNames) {
        if (-not (Test-ScoopBucketAdded $bucket)) {
            scoop bucket add $bucket
        }
    }
}

# Function to install Scoop packages.
function Install-ScoopPackages {
    <#
    .SYNOPSIS
    Installs Scoop packages if they are not already installed.

    .DESCRIPTION
    This function installs specified Scoop packages if they are not already installed on the system.

    .PARAMETER packages
    An array of names of the Scoop packages to install.

    .EXAMPLE
    Install-ScoopPackages -packages @("Cascadia-Code", "neovim")

    This command installs the "Cascadia-Code" and "neovim" Scoop packages if they are not already installed.
    #>

    param(
        [string[]]$packages
    )

    foreach ($package in $packages) {
        if (-not (Test-ScoopPackageInstalled $package)) {
            Write-Host "Installing $package..."
            scoop install $package
        }
    }
}

# Install Scoop buckets
Install-ScoopBuckets -bucketNames $scoopBuckets

# Install Scoop packages
Install-ScoopPackages -packages $scoopPackages

# Install PS Modules
foreach ($psModule in $psModules) {
    if (!(Get-Module -ListAvailable -Name $psModule)) {
        Install-Module -Name $psModule -Force -AcceptLicense -Scope CurrentUser
    }
}

# Create Symbolic Links
Write-Host "Creating Symbolic Links..."
foreach ($symlink in $symlinks.GetEnumerator()) {
    Get-Item -Path $symlink.Key -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    New-Item -ItemType SymbolicLink -Path $symlink.Key -Target (Resolve-Path $symlink.Value) -Force | Out-Null
}

# Git configurations
& ".\script\gituser.ps1"
