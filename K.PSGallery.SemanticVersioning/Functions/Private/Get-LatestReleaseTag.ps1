<#
.SYNOPSIS
    Finds the latest semantic version release tag in the repository.

.DESCRIPTION
    Searches for git tags that follow semantic versioning format (X.Y.Z) with optional 'v' prefix.
    Returns the highest version tag found, or empty string if no valid release tags exist.

.OUTPUTS
    System.String
    Returns the latest release tag (e.g., "v1.2.3") or empty string if none found.

.EXAMPLE
    Get-LatestReleaseTag
    Returns: "v1.2.3" (if this is the highest semantic version tag)

.EXAMPLE
    Get-LatestReleaseTag  
    Returns: "" (if no semantic version tags exist)
#>
function Get-LatestReleaseTag {
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    Write-Verbose "Searching for latest semantic version release tag"
    
    try {
        # Get all tags and filter for semantic versioning pattern
        $allTags = git tag -l 2>$null
        if (-not $allTags) {
            Write-Verbose "No git tags found in repository"
            return ""
        }
        
        # Filter tags that match semantic versioning (with optional 'v' prefix)
        $semverTags = $allTags | Where-Object { 
            $_ -match '^v?\d+\.\d+\.\d+$' 
        }
        
        if (-not $semverTags) {
            Write-Verbose "No semantic version tags found"
            return ""
        }
        
        Write-Verbose "Found semantic version tags: $($semverTags -join ', ')"
        
        # Parse versions and find the highest one
        $latestTag = ""
        $latestVersion = [Version]"0.0.0"
        
        foreach ($tag in $semverTags) {
            # Remove 'v' prefix if present for version parsing
            $versionString = $tag -replace '^v', ''
            
            try {
                $version = [Version]$versionString
                if ($version -gt $latestVersion) {
                    $latestVersion = $version
                    $latestTag = $tag
                }
            }
            catch {
                Write-Verbose "Failed to parse version from tag '$tag': $($_.Exception.Message)"
                continue
            }
        }
        
        if ($latestTag) {
            Write-Verbose "Latest release tag determined: '$latestTag' (version: $latestVersion)"
        } else {
            Write-Verbose "No valid semantic version tags could be parsed"
        }
        
        return $latestTag
    }
    catch {
        Write-Warning "Failed to retrieve git tags: $($_.Exception.Message)"
        return ""
    }
}
