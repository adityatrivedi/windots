# Check if the script is running with elevated privileges
if ([bool]([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script should not be run in admin mode. Please run it as a regular user." -ForegroundColor Red
    exit 1
}

# Set working directory
Set-Location $PSScriptRoot
[Environment]::CurrentDirectory = $PSScriptRoot

# Function to log messages
function Write-Log {
    <#
    .SYNOPSIS
    Logs a message with a timestamp and type.

    .DESCRIPTION
    This function logs a message with a timestamp and type. The message is color-coded based on the type.

    .PARAMETER Message
    The message to log.

    .PARAMETER Type
    The type of the message (INFO, ERROR, WARN). Default is INFO.

    .EXAMPLE
    Write-Log -Message "Installation completed successfully" -Type "INFO"

    This command logs an informational message indicating that the installation completed successfully.
    #>

    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Type) {
        "INFO" { $color = "Green" }
        "ERROR" { $color = "Red" }
        "WARN" { $color = "Yellow" }
        default { $color = "White" }
    }
    Write-Host "[$timestamp] [$Type] $Message" -ForegroundColor $color
}

# Function to check if a command exists
function Test-CommandExists {
    <#
    .SYNOPSIS
    Checks if a command exists.

    .DESCRIPTION
    This function checks if a specified command exists on the system.

    .PARAMETER Command
    The name of the command to check.

    .EXAMPLE
    Test-CommandExists -Command "git"

    This command checks if the "git" command exists on the system.
    #>

    param (
        [string]$Command
    )
    return Get-Command $Command -ErrorAction SilentlyContinue
}

# Function to install winget packages
function Install-WingetPackages {
    <#
    .SYNOPSIS
    Installs specified winget packages if they are not already installed.

    .DESCRIPTION
    This function installs specified winget packages if they are not already installed on the system.

    .PARAMETER Packages
    An array of names of the winget packages to install.

    .EXAMPLE
    Install-WingetPackages -Packages @("Git.Git", "Microsoft.VisualStudioCode")

    This command installs the "Git.Git" and "Microsoft.VisualStudioCode" winget packages if they are not already installed.
    #>

    param (
        [string[]]$Packages
    )

    Write-Log "Installing missing winget dependencies..."

    $installedWingetPackages = winget list | Out-String
    foreach ($package in $Packages) {
        if ($installedWingetPackages -notmatch $package) {
            Write-Log "Installing $package via winget..."
            try {
                winget install --id $package --scope user -e
            } catch {
                Write-Log "Failed to install $package via winget: $_" "ERROR"
            }
        } else {
            Write-Log "$package is already installed."
        }
    }
}

# Function to install Scoop if not installed
function Install-Scoop {
    <#
    .SYNOPSIS
    Installs Scoop if it is not already installed.

    .DESCRIPTION
    This function installs Scoop if it is not already installed on the system.

    .EXAMPLE
    Install-Scoop

    This command installs Scoop if it is not already installed.
    #>

    if (-not (Test-CommandExists "scoop")) {
        Write-Log "Installing Scoop..."
        try {
            Invoke-RestMethod get.scoop.sh | Invoke-Expression
        } catch {
            Write-Log "Failed to install Scoop: $_" "ERROR"
        }
    } else {
        Write-Log "Scoop is already installed."
    }
}

# Function to check if a Scoop package is installed
function Test-ScoopPackageInstalled {
    <#
    .SYNOPSIS
    Checks if a Scoop package is installed.

    .DESCRIPTION
    This function checks if a specified Scoop package is installed on the system.

    .PARAMETER PackageName
    The name of the Scoop package to check.

    .EXAMPLE
    Test-ScoopPackageInstalled -PackageName "neovim"

    This command checks if the "neovim" package is installed via Scoop.
    #>

    param (
        [string]$PackageName
    )

    $installedPackages = scoop list
    return $installedPackages -like "*$PackageName*"
}

# Function to check if a Scoop bucket is added
function Test-ScoopBucketAdded {
    <#
    .SYNOPSIS
    Checks if a Scoop bucket is added.

    .DESCRIPTION
    This function checks if a specified Scoop bucket is added to the system.

    .PARAMETER BucketName
    The name of the Scoop bucket to check.

    .EXAMPLE
    Test-ScoopBucketAdded -BucketName "extras"

    This command checks if the "extras" bucket is added to Scoop.
    #>

    param (
        [string]$BucketName
    )

    $addedBuckets = scoop bucket list | Out-String
    return $addedBuckets -match "^\s*$BucketName\s"
}

# Function to install Scoop buckets
function Install-ScoopBuckets {
    <#
    .SYNOPSIS
    Installs specified Scoop buckets if they are not already added.

    .DESCRIPTION
    This function installs specified Scoop buckets if they are not already added to the system.

    .PARAMETER BucketNames
    An array of names of the Scoop buckets to install.

    .EXAMPLE
    Install-ScoopBuckets -BucketNames @("extras", "nerd-fonts")

    This command installs the "extras" and "nerd-fonts" Scoop buckets if they are not already added.
    #>

    param (
        [string[]]$BucketNames
    )

    foreach ($bucket in $BucketNames) {
        if (-not (Test-ScoopBucketAdded $bucket)) {
            Write-Log "Adding Scoop bucket $bucket..."
            try {
                scoop bucket add $bucket
            } catch {
                Write-Log "Failed to add Scoop bucket $($bucket): $_" "ERROR"
            }
        } else {
            Write-Log "Scoop bucket $bucket is already added."
        }
    }
}

# Function to install Scoop packages
function Install-ScoopPackages {
    <#
    .SYNOPSIS
    Installs specified Scoop packages if they are not already installed.

    .DESCRIPTION
    This function installs specified Scoop packages if they are not already installed on the system.

    .PARAMETER Packages
    An array of names of the Scoop packages to install.

    .EXAMPLE
    Install-ScoopPackages -Packages @("Cascadia-Code", "neovim")

    This command installs the "Cascadia-Code" and "neovim" Scoop packages if they are not already installed.
    #>

    param (
        [string[]]$Packages
    )

    foreach ($package in $Packages) {
        if (-not (Test-ScoopPackageInstalled $package)) {
            Write-Log "Installing $package via Scoop..."
            try {
                scoop install $package
            } catch {
                Write-Log "Failed to install $package via Scoop: $_" "ERROR"
            }
        } else {
            Write-Log "$package is already installed."
        }
    }
}

# Function to install PowerShell modules
function Install-PSModules {
    <#
    .SYNOPSIS
    Installs specified PowerShell modules if they are not already installed.

    .DESCRIPTION
    This function installs specified PowerShell modules if they are not already installed on the system.

    .PARAMETER Modules
    An array of names of the PowerShell modules to install.

    .EXAMPLE
    Install-PSModules -Modules @("PSScriptAnalyzer", "CompletionPredictor")

    This command installs the "PSScriptAnalyzer" and "CompletionPredictor" PowerShell modules if they are not already installed.
    #>

    param (
        [string[]]$Modules
    )

    foreach ($module in $Modules) {
        if (!(Get-Module -ListAvailable -Name $module)) {
            Write-Log "Installing PowerShell module $module..."
            try {
                Install-Module -Name $module -Force -AcceptLicense -Scope CurrentUser
            } catch {
                Write-Log "Failed to install PowerShell module $($module): $_" "ERROR"
            }
        } else {
            Write-Log "PowerShell module $module is already installed."
        }
    }
}

# Function to create symbolic links
function New-SymbolicLinks {
    <#
    .SYNOPSIS
    Creates symbolic links for specified files.

    .DESCRIPTION
    This function creates symbolic links for specified files.

    .PARAMETER Symlinks
    A hashtable of destination and source paths for the symbolic links.

    .EXAMPLE
    New-SymbolicLinks -Symlinks $symlinks

    This command creates symbolic links for the specified files.
    #>

    param (
        [hashtable]$Symlinks
    )

    Write-Log "Creating Symbolic Links..."
    foreach ($symlink in $Symlinks.GetEnumerator()) {
        try {
            Get-Item -Path $symlink.Key -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            New-Item -ItemType SymbolicLink -Path $symlink.Key -Target (Resolve-Path $symlink.Value) -Force | Out-Null
            Write-Log "Created symbolic link: $symlink.Key -> $symlink.Value"
        } catch {
            Write-Log "Failed to create symbolic link: $symlink.Key -> $symlink.Value: $_" "ERROR"
        }
    }
}

# Linked Files (Destination => Source)
$symlinks = @{
    $PROFILE.CurrentUserAllHosts = ".\powershell\profile.ps1"
    "$HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" = ".\windowsterminal\settings.json"
    "$HOME\.gitconfig" = ".\git\.gitconfig"
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
    "Microsoft.WindowsTerminal",
    "Microsoft.WindowsApp"
)

$scoopPackages = @(
    "Cascadia-Code",
    "psreadline",
    "neovim",
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

# Install winget packages
Install-WingetPackages -Packages $wingetPackages

# Install Scoop
Install-Scoop

# Install Scoop buckets
Install-ScoopBuckets -BucketNames $scoopBuckets

# Install Scoop packages
Install-ScoopPackages -Packages $scoopPackages

# Install PowerShell modules
Install-PSModules -Modules $psModules

# Create symbolic links
New-SymbolicLinks -Symlinks $symlinks

# Git configurations
Write-Log "Running Git configuration script..."
try {
    & ".\script\gituser.ps1"
} catch {
    Write-Log "Failed to run Git configuration script: $_" "ERROR"
}
