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

.PARAMETER suffix
    Optional suffix to append (alpha, beta)

.OUTPUTS
    System.String
    Returns the new version string in semantic version format.

.EXAMPLE
    Step-Version -currentVersion "1.2.3" -bumpType "major"
    Returns: "2.0.0"

.EXAMPLE
    Step-Version -currentVersion "1.2.3" -bumpType "minor"
    Returns: "1.3.0"

.EXAMPLE
    Step-Version -currentVersion "1.2.3" -bumpType "patch"
    Returns: "1.2.4"

.NOTES
    This function assumes the input version follows semantic versioning format.
    Invalid version formats may produce unexpected results.
#>
function Step-Version {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Current semantic version (e.g., '1.2.3')")]
        [ValidatePattern('^\d+\.\d+\.\d+$')]
        [string]$currentVersion,
        
        [Parameter(Mandatory = $true, HelpMessage = "Type of version bump to perform")]
        [ValidateSet('major', 'minor', 'patch')]
        [string]$bumpType,
        
        [Parameter(Mandatory = $false, HelpMessage = "Optional suffix to append (alpha, beta)")]
        [ValidateSet('', 'alpha', 'beta')]
        [string]$suffix = ''
    )
    
    Write-Verbose "Bumping version '$currentVersion' with type '$bumpType' and suffix '$suffix'"
    
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
        }
        'minor' {
            $newVersion = "$major.$($minor + 1).0"
            Write-Verbose "Minor bump: $currentVersion → $newVersion"
        }
        'patch' {
            $newVersion = "$major.$minor.$($patch + 1)"
            Write-Verbose "Patch bump: $currentVersion → $newVersion"
        }
        default {
            throw "Invalid bump type: $bumpType. Must be 'major', 'minor', or 'patch'."
        }
    }
    
    # Add suffix if specified
    if ($suffix) {
        $newVersion = "$newVersion-$suffix"
        Write-Verbose "Added suffix: $newVersion"
    }
    
    return $newVersion
}
