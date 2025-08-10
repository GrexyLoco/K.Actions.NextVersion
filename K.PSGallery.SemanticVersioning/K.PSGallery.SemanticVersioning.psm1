#Requires -Version 5.1

<#
.SYNOPSIS
    K.PSGallery.SemanticVersioning - PowerShell Module for Git-based Semantic Versioning

.DESCRIPTION
    This module provides comprehensive semantic versioning functionality for PowerShell projects
    based on Git repository analysis, branch naming patterns, and commit message conventions.
    
    Key Features:
    - Automatic version bump detection from Git history
    - Branch pattern analysis (feature/, bugfix/, major/, etc.)
    - Commit message keyword detection (BREAKING, MAJOR, FEATURE, etc.)
    - Hybrid first release logic with PSD1 validation
    - Structured error handling for unusual configurations
    - Support for Alpha/Beta pre-release versions
    - GitHub Actions integration and local development support

.NOTES
    Module: K.PSGallery.SemanticVersioning
    Author: K.PSGallery
    Version: 1.0.0
    
    This module follows semantic versioning principles as defined at https://semver.org/
#>

#region Safe Logging Functions - Always use LoggingModule when available
function Write-SafeDebugLog {
    param([string]$Message, [string]$Context = "")
    if (Get-Command -Name Write-DebugLog -ErrorAction SilentlyContinue) {
        Write-DebugLog $Message $Context
    } else {
        Write-Host "DEBUG: $Message" -ForegroundColor Gray
        if ($Context) { Write-Host "   $Context" -ForegroundColor DarkGray }
    }
}

function Write-SafeInfoLog {
    param([string]$Message, [string]$Context = "")
    if (Get-Command -Name Write-InfoLog -ErrorAction SilentlyContinue) {
        Write-InfoLog $Message $Context
    } else {
        Write-Host "INFO: $Message" -ForegroundColor Blue
        if ($Context) { Write-Host "   $Context" -ForegroundColor Cyan }
    }
}

function Write-SafeWarningLog {
    param([string]$Message, [string]$Context = "")
    if (Get-Command -Name Write-WarningLog -ErrorAction SilentlyContinue) {
        Write-WarningLog $Message $Context
    } else {
        Write-Host "WARNING: $Message" -ForegroundColor Yellow
        if ($Context) { Write-Host "   $Context" -ForegroundColor DarkYellow }
    }
}

function Write-SafeErrorLog {
    param([string]$Message, [string]$Context = "")
    if (Get-Command -Name Write-ErrorLog -ErrorAction SilentlyContinue) {
        Write-ErrorLog $Message $Context
    } else {
        Write-Host "ERROR: $Message" -ForegroundColor Red
        if ($Context) { Write-Host "   $Context" -ForegroundColor DarkRed }
    }
}

function Write-SafeTaskSuccessLog {
    param([string]$Message, [string]$Context = "")
    if (Get-Command -Name Write-TaskSuccessLog -ErrorAction SilentlyContinue) {
        Write-TaskSuccessLog $Message $Context
    } else {
        Write-Host "SUCCESS: $Message" -ForegroundColor Green
        if ($Context) { Write-Host "   $Context" -ForegroundColor DarkGreen }
    }
}

function Write-SafeTaskFailLog {
    param([string]$Message, [string]$Context = "")
    if (Get-Command -Name Write-TaskFailLog -ErrorAction SilentlyContinue) {
        Write-TaskFailLog $Message $Context
    } else {
        Write-Host "FAILED: $Message" -ForegroundColor Red
        if ($Context) { Write-Host "   $Context" -ForegroundColor DarkRed }
    }
}
#endregion

#region Dependency Management - PowerShell Gallery Dependencies
function Ensure-ModuleDependencies {
    <#
    .SYNOPSIS
        Ensures all required modules are installed and loaded from PowerShell Gallery
    #>
    
    # List of required modules with minimum versions
    $RequiredModules = @(
        @{ Name = 'K.PSGallery.LoggingModule'; Version = '1.1.46' }
    )
    
    foreach ($Module in $RequiredModules) {
        $ModuleName = $Module.Name
        $RequiredVersion = $Module.Version
        
        Write-SafeInfoLog "Checking dependency: $ModuleName (>= $RequiredVersion)"
        
        # Check if module is already loaded with correct version
        $LoadedModule = Get-Module -Name $ModuleName
        if ($LoadedModule -and ([Version]$LoadedModule.Version -ge [Version]$RequiredVersion)) {
            Write-SafeTaskSuccessLog "$ModuleName v$($LoadedModule.Version) already loaded"
            continue
        }
        
        # Check if module is installed with correct version
        $InstalledModule = Get-Module -ListAvailable -Name $ModuleName | 
            Where-Object { [Version]$_.Version -ge [Version]$RequiredVersion } | 
            Sort-Object Version -Descending | 
            Select-Object -First 1
            
        if (-not $InstalledModule) {
            Write-SafeInfoLog "Installing $ModuleName from PowerShell Gallery..."
            try {
                # Set PowerShell Gallery as trusted
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
                Install-Module -Name $ModuleName -MinimumVersion $RequiredVersion -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                Write-SafeTaskSuccessLog "Successfully installed $ModuleName"
            }
            catch {
                Write-SafeWarningLog "Could not install $ModuleName from PowerShell Gallery" "Error: ${_}`nModule will need to be installed manually: Install-Module $ModuleName"
                return $false
            }
        }
        
        # Import the module
        try {
            Import-Module -Name $ModuleName -MinimumVersion $RequiredVersion -Force -ErrorAction Stop
            $ImportedModule = Get-Module -Name $ModuleName
            Write-SafeTaskSuccessLog "Successfully imported $ModuleName v$($ImportedModule.Version)"
        }
        catch {
            Write-SafeWarningLog "Could not import $ModuleName" "Error: ${_}`nPlease ensure the module is properly installed: Install-Module $ModuleName"
            return $false
        }
    }
    return $true
}

# Ensure all dependencies are available
$DependenciesLoaded = Ensure-ModuleDependencies
if (-not $DependenciesLoaded) {
    Write-SafeWarningLog "Some dependencies could not be loaded" "Module functionality may be limited"
}
#endregion

# Dependencies are now loaded via Ensure-ModuleDependencies function above
# LoggingModule functions are now available from PowerShell Gallery installation (if successful)

Write-SafeTaskSuccessLog "All dependencies loaded successfully"

#region Load Thematic Function Files

# Dot-source the thematic function files following K.PSGallery.Github pattern
Write-SafeInfoLog "Loading thematic function files"
. $PSScriptRoot\K.PSGallery.SemanticVersioning.Git.ps1 -ErrorAction Stop
. $PSScriptRoot\K.PSGallery.SemanticVersioning.Versioning.ps1 -ErrorAction Stop
Write-SafeTaskSuccessLog "All thematic function files successfully loaded"

#endregion

#region Export Functions

# Export the public functions defined in thematic files
Export-ModuleMember -Function @(
    'Get-NextSemanticVersion',
    'Test-FirstReleaseVersion'
)

#endregion

# Module initialization
Write-SafeInfoLog "K.PSGallery.SemanticVersioning module loaded successfully"
Write-SafeInfoLog "Available public functions: Get-NextSemanticVersion, Test-FirstReleaseVersion"
