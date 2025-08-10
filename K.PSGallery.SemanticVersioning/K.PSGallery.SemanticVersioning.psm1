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

# Get public and private function definition files
$Public = @(Get-ChildItem -Path $PSScriptRoot\Functions\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Functions\Private\*.ps1 -ErrorAction SilentlyContinue)

# Import all functions
foreach ($import in @($Public + $Private)) {
    try {
        Write-Verbose "Importing function from: $($import.FullName)"
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $($_.Exception.Message)"
    }
}

# Export only the public functions
Export-ModuleMember -Function $Public.BaseName

# Module initialization
Write-Verbose "K.PSGallery.SemanticVersioning module loaded successfully"
Write-Verbose "Available functions: $($Public.BaseName -join ', ')"
