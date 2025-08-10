<#
.SYNOPSIS
    Analyzes branch names and commit messages to determine version bump type.

.DESCRIPTION
    Determines the appropriate semantic version bump type by analyzing:
    1. Commit message keywords (highest priority)
    2. Branch naming patterns
    3. Alpha/Beta suffix detection
    
    Priority system: major > minor > patch
    Commit message keywords override branch patterns.

.PARAMETER branch
    Git branch name to analyze for patterns

.PARAMETER message
    Commit message to scan for version bump keywords

.OUTPUTS
    Hashtable
    Returns hashtable with keys: bumpType, suffix

.EXAMPLE
    Get-VersionBumpType -branch "feature/new-logging" -message "Add new logging feature"
    Returns: @{ bumpType = "minor"; suffix = "" }

.EXAMPLE
    Get-VersionBumpType -branch "main" -message "BREAKING: Remove deprecated API"
    Returns: @{ bumpType = "major"; suffix = "" }
#>
function Get-VersionBumpType {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Git branch name to analyze")]
        [string]$branch,
        
        [Parameter(Mandatory = $true, HelpMessage = "Commit message to scan for keywords")]
        [string]$message
    )

    # Check commit message for version bump keywords first (highest priority)
    # Commit conventions override branch patterns completely
    
    # Major version triggers (breaking changes)
    if ($message -match '(?i)BREAKING|MAJOR') { 
        Write-Verbose "Detected major version keyword in commit message: '$message'"
        
        # Check for alpha/beta suffix
        if ($message -match '(?i)BREAKING-ALPHA|MAJOR-ALPHA') {
            return @{ bumpType = 'major'; suffix = 'alpha' }
        } elseif ($message -match '(?i)BREAKING-BETA|MAJOR-BETA') {
            return @{ bumpType = 'major'; suffix = 'beta' }
        } else {
            return @{ bumpType = 'major'; suffix = '' }
        }
    }
    
    # Minor version triggers (new features)
    if ($message -match '(?i)MINOR|FEATURE|FEAT') { 
        Write-Verbose "Detected minor version keyword in commit message: '$message'"
        
        # Check for alpha/beta suffix
        if ($message -match '(?i)MINOR-ALPHA|FEATURE-ALPHA|FEAT-ALPHA') {
            return @{ bumpType = 'minor'; suffix = 'alpha' }
        } elseif ($message -match '(?i)MINOR-BETA|FEATURE-BETA|FEAT-BETA') {
            return @{ bumpType = 'minor'; suffix = 'beta' }
        } else {
            return @{ bumpType = 'minor'; suffix = '' }
        }
    }
    
    # Patch version triggers (bug fixes, patches)
    if ($message -match '(?i)PATCH|FIX|BUGFIX|HOTFIX') { 
        Write-Verbose "Detected patch version keyword in commit message: '$message'"
        
        # Check for alpha/beta suffix
        if ($message -match '(?i)PATCH-ALPHA|FIX-ALPHA|BUGFIX-ALPHA|HOTFIX-ALPHA') {
            return @{ bumpType = 'patch'; suffix = 'alpha' }
        } elseif ($message -match '(?i)PATCH-BETA|FIX-BETA|BUGFIX-BETA|HOTFIX-BETA') {
            return @{ bumpType = 'patch'; suffix = 'beta' }
        } else {
            return @{ bumpType = 'patch'; suffix = '' }
        }
    }

    # Analyze branch name patterns using case-insensitive regex matching
    # Note: Branch patterns never have alpha/beta suffixes
    switch -regex ($branch) {
        '(?i)^feature/' { 
            Write-Verbose "Detected feature branch pattern: '$branch'"
            return @{ bumpType = 'minor'; suffix = '' }
        }
        '(?i)^bugfix/' { 
            Write-Verbose "Detected bugfix branch pattern: '$branch'"
            return @{ bumpType = 'patch'; suffix = '' }
        }
        '(?i)^refactor/' { 
            Write-Verbose "Detected refactor branch pattern: '$branch'"
            return @{ bumpType = 'patch'; suffix = '' }
        }
        default { 
            Write-Verbose "No specific branch pattern matched for '$branch', defaulting to patch"
            return @{ bumpType = 'patch'; suffix = '' }
        }
    }
}
