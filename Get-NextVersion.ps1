<#
.SYNOPSIS
    Calculates the next semantic version number based on branch naming conventions and commit messages.

.DESCRIPTION
    This script implements semantic versioning (SemVer) logic for PowerShell modules by analyzing
    branch names and commit messages to determine the appropriate version bump type (major, minor, or patch).
    
    The script follows these conventions:
    - Major version bump: Triggered by 'major/' branch prefix or 'BREAKING'/'MAJOR' in commit message
    - Minor version bump: Triggered by 'feature/' branch prefix
    - Patch version bump: Triggered by 'bugfix/' or 'refactor/' branch prefixes, or as default fallback
    
    This is typically used in CI/CD pipelines to automatically determine version numbers for releases.

.PARAMETER ManifestPath
    The absolute path to the PowerShell module manifest file (.psd1).
    If not specified, automatically discovers the first .psd1 file in the current directory tree.
    
    Example: "C:\MyModule\MyModule.psd1"

.PARAMETER BranchName
    The name of the Git branch being processed.
    Defaults to the GITHUB_REF_NAME environment variable when running in GitHub Actions.
    
    Supported branch naming conventions:
    - major/feature-name    → Major version bump (X.0.0)
    - feature/feature-name  → Minor version bump (X.Y.0)
    - bugfix/fix-name      → Patch version bump (X.Y.Z)
    - refactor/refactor-name → Patch version bump (X.Y.Z)
    - Any other pattern    → Patch version bump (X.Y.Z)

.PARAMETER CommitMessage
    The commit message to analyze for version bump keywords.
    If the message contains 'BREAKING' or 'MAJOR' (case-insensitive), it will trigger a major version bump
    regardless of the branch naming convention.

.OUTPUTS
    System.String
    Outputs GitHub Actions compatible set-output commands:
    - ::set-output name=version::<new-version>
    - ::set-output name=bumpType::<major|minor|patch>

.EXAMPLE
    .\Get-NextVersion.ps1
    
    Uses default parameters to find manifest and determine version from current environment.
    Output: ::set-output name=version::1.2.4
            ::set-output name=bumpType::patch

.EXAMPLE
    .\Get-NextVersion.ps1 -ManifestPath "C:\MyModule\MyModule.psd1" -BranchName "feature/new-logging" -CommitMessage "Add new logging functionality"
    
    Explicitly specifies all parameters for a feature branch.
    Output: ::set-output name=version::1.3.0
            ::set-output name=bumpType::minor

.EXAMPLE
    .\Get-NextVersion.ps1 -BranchName "bugfix/critical-fix" -CommitMessage "BREAKING: Remove deprecated API"
    
    Even though it's a bugfix branch, the BREAKING keyword in commit message triggers major bump.
    Output: ::set-output name=version::2.0.0
            ::set-output name=bumpType::major

.NOTES
    Author: Generated for K.PSGallery.LoggingModule
    Version: 1.0
    Created: 2025
    
    This script is designed to work seamlessly with GitHub Actions workflows and follows
    semantic versioning principles as defined at https://semver.org/
    
    The script assumes the current version in the manifest follows the format "X.Y.Z"
    where X, Y, and Z are non-negative integers.

.LINK
    https://semver.org/
    
.LINK
    https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-output-parameter
#>

[CmdletBinding()]
param (
    [Parameter(HelpMessage = "Path to the PowerShell module manifest file (.psd1)")]
    [string]$ManifestPath = (Get-ChildItem -Recurse -Filter *.psd1 | Select-Object -First 1).FullName,
    
    [Parameter(HelpMessage = "Git branch name to analyze for version bump type")]
    [string]$BranchName = $env:GITHUB_REF_NAME,
    
    [Parameter(HelpMessage = "Commit message to scan for version bump keywords")]
    [string]$CommitMessage = ""
)

<#
.SYNOPSIS
    Determines the type of version bump based on branch naming conventions and commit messages.

.DESCRIPTION
    Analyzes the Git branch name and commit message to determine whether a major, minor, or patch
    version bump should be applied according to semantic versioning principles.

.PARAMETER branch
    The Git branch name to analyze for version bump patterns.

.PARAMETER message
    The commit message to scan for breaking change indicators.

.OUTPUTS
    System.String
    Returns one of: 'major', 'minor', or 'patch'

.EXAMPLE
    Get-VersionBumpType -branch "feature/new-api" -message "Add new logging methods"
    Returns: "minor"

.EXAMPLE
    Get-VersionBumpType -branch "bugfix/memory-leak" -message "BREAKING: Change API signature"
    Returns: "major" (due to BREAKING keyword overriding branch type)
#>
function Get-VersionBumpType {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Git branch name to analyze")]
        [string]$branch,
        
        [Parameter(Mandatory = $true, HelpMessage = "Commit message to scan for keywords")]
        [string]$message
    )

    # Check commit message for breaking changes first (highest priority)
    if ($message -match 'BREAKING|MAJOR') { 
        Write-Verbose "Detected breaking change keyword in commit message: '$message'"
        return 'major' 
    }

    # Analyze branch name patterns using regex matching
    switch -regex ($branch) {
        '^major/' { 
            Write-Verbose "Detected major branch pattern: '$branch'"
            return 'major' 
        }
        '^feature/' { 
            Write-Verbose "Detected feature branch pattern: '$branch'"
            return 'minor' 
        }
        '^bugfix/' { 
            Write-Verbose "Detected bugfix branch pattern: '$branch'"
            return 'patch' 
        }
        '^refactor/' { 
            Write-Verbose "Detected refactor branch pattern: '$branch'"
            return 'patch' 
        }
        default { 
            Write-Verbose "No specific branch pattern matched for '$branch', defaulting to patch"
            return 'patch' 
        }
    }
}

<#
.SYNOPSIS
    Increments a semantic version number based on the specified bump type.

.DESCRIPTION
    Takes a current version string in the format "X.Y.Z" and increments it according to
    semantic versioning rules based on the bump type:
    - Major: X+1.0.0 (breaking changes)
    - Minor: X.Y+1.0 (new features, backward compatible)
    - Patch: X.Y.Z+1 (bug fixes, backward compatible)

.PARAMETER currentVersion
    The current version string in semantic version format (e.g., "1.2.3").
    Must contain exactly three dot-separated numeric components.

.PARAMETER bumpType
    The type of version increment to perform.
    Valid values: 'major', 'minor', 'patch'

.OUTPUTS
    System.String
    Returns the new version string in semantic version format.

.EXAMPLE
    Bump-Version -currentVersion "1.2.3" -bumpType "major"
    Returns: "2.0.0"

.EXAMPLE
    Bump-Version -currentVersion "1.2.3" -bumpType "minor"
    Returns: "1.3.0"

.EXAMPLE
    Bump-Version -currentVersion "1.2.3" -bumpType "patch"
    Returns: "1.2.4"

.NOTES
    This function assumes the input version follows semantic versioning format.
    Invalid version formats may produce unexpected results.
#>
function Bump-Version {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Current semantic version (e.g., '1.2.3')")]
        [ValidatePattern('^\d+\.\d+\.\d+$')]
        [string]$currentVersion,
        
        [Parameter(Mandatory = $true, HelpMessage = "Type of version bump to perform")]
        [ValidateSet('major', 'minor', 'patch')]
        [string]$bumpType
    )
    
    Write-Verbose "Bumping version '$currentVersion' with type '$bumpType'"
    
    # Split version into components and convert to integers for arithmetic
    $versionParts = $currentVersion -split '\.'
    $major = [int]$versionParts[0]
    $minor = [int]$versionParts[1]
    $patch = [int]$versionParts[2]
    
    # Apply semantic versioning rules based on bump type
    switch ($bumpType) {
        'major' {
            $newVersion = "$($major + 1).0.0"
            Write-Verbose "Major bump: $currentVersion → $newVersion"
            return $newVersion
        }
        'minor' {
            $newVersion = "$major.$($minor + 1).0"
            Write-Verbose "Minor bump: $currentVersion → $newVersion"
            return $newVersion
        }
        'patch' {
            $newVersion = "$major.$minor.$($patch + 1)"
            Write-Verbose "Patch bump: $currentVersion → $newVersion"
            return $newVersion
        }
        default {
            throw "Invalid bump type: $bumpType. Must be 'major', 'minor', or 'patch'."
        }
    }
}

#region Main Script Execution
# =============================================================================
# MAIN SCRIPT LOGIC
# =============================================================================

try {
    # Validate that the manifest file exists and is accessible
    if (-not (Test-Path -Path $ManifestPath -PathType Leaf)) {
        throw "PowerShell manifest file not found at path: $ManifestPath"
    }
    
    Write-Verbose "Loading PowerShell manifest from: $ManifestPath"
    
    # Import the module manifest to extract current version information
    $manifest = Import-PowerShellDataFile -Path $ManifestPath
    
    if (-not $manifest.ModuleVersion) {
        throw "ModuleVersion not found in manifest file: $ManifestPath"
    }
    
    $currentVersion = $manifest.ModuleVersion
    Write-Verbose "Current module version: $currentVersion"
    
    # Determine the type of version bump required
    Write-Verbose "Analyzing branch '$BranchName' and commit message for version bump type"
    $bumpType = Get-VersionBumpType -branch $BranchName -message $CommitMessage
    
    # Calculate the new version number
    Write-Verbose "Calculating new version with bump type: $bumpType"
    $newVersion = Bump-Version -currentVersion $currentVersion -bumpType $bumpType
    
    # Output results in GitHub Actions format for workflow consumption
    Write-Host "Current version: $currentVersion"
    Write-Host "Bump type: $bumpType"
    Write-Host "New version: $newVersion"
    Write-Host ""
    Write-Host "GitHub Actions Output:"
    Write-Host "::set-output name=version::$newVersion"
    Write-Host "::set-output name=bumpType::$bumpType"
    
    # Also output as environment variables for potential use in subsequent steps
    Write-Host "::set-env name=NEW_VERSION::$newVersion"
    Write-Host "::set-env name=BUMP_TYPE::$bumpType"
}
catch {
    Write-Error "Failed to determine next version: $($_.Exception.Message)"
    Write-Host "::set-output name=version::"
    Write-Host "::set-output name=bumpType::"
    exit 1
}

#endregion Main Script Execution
