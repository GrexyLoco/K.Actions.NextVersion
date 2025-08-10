<#
.SYNOPSIS
    Determines the type of version bump based on merged branches and commit history since last release.

.DESCRIPTION
    Analyzes merged branches and commit messages since the last release tag to determine 
    the appropriate semantic version bump (major, minor, or patch).
    
    The analysis follows this priority system:
    1. Commit message keywords (highest priority): BREAKING/MAJOR → MINOR/FEATURE/FEAT → PATCH/FIX/BUGFIX/HOTFIX
    2. Branch naming patterns: major/* → feature/* → bugfix/*|refactor/* → other (patch)
    3. Highest priority wins: major > minor > patch
    
    Only analyzes merge commits since the last release tag for accurate version determination.

.PARAMETER lastReleaseTag
    The last release tag to analyze changes since. If empty, analyzes from repository start.

.PARAMETER targetBranch
    The target branch to analyze (e.g., 'main', 'master', 'release'). 
    Auto-discovered if not specified.

.OUTPUTS
    Hashtable
    Returns hashtable with keys: bumpType, suffix

.EXAMPLE
    Get-ReleaseVersionBumpType -lastReleaseTag "v1.2.3" -targetBranch "main"
    Returns: @{ bumpType = "minor"; suffix = "" }

.EXAMPLE
    Get-ReleaseVersionBumpType -lastReleaseTag "" -targetBranch "master"  
    Returns: @{ bumpType = "patch"; suffix = "" }
#>
function Get-ReleaseVersionBumpType {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $false, HelpMessage = "Last release tag to analyze changes since")]
        [string]$lastReleaseTag = "",
        
        [Parameter(Mandatory = $true, HelpMessage = "Target branch to analyze")]
        [string]$targetBranch
    )

    Write-Verbose "Analyzing version bump for target branch '$targetBranch' since release '$lastReleaseTag'"
    
    # Determine git log command based on whether we have a last release
    if ([string]::IsNullOrWhiteSpace($lastReleaseTag)) {
        $gitLogCmd = "git log --merges --oneline --format='%H|%s' $targetBranch"
        Write-Verbose "No last release tag specified, analyzing all merge commits from repository start"
    } else {
        $gitLogCmd = "git log --merges --oneline --format='%H|%s' ${lastReleaseTag}..$targetBranch"
        Write-Verbose "Analyzing merge commits since release tag '$lastReleaseTag'"
    }
    
    # Get merge commits
    try {
        $mergeCommits = Invoke-Expression $gitLogCmd 2>$null
        if (-not $mergeCommits) {
            Write-Verbose "No merge commits found since last release, defaulting to patch"
            return @{ bumpType = 'patch'; suffix = '' }
        }
    }
    catch {
        Write-SafeWarningLog -Message "Failed to execute git log command: $($_.Exception.Message)"
        Write-Verbose "Defaulting to patch version bump due to git error"
        return @{ bumpType = 'patch'; suffix = '' }
    }
    
    # Track highest priority bump type found and any suffix
    $highestBump = 'none'  # none < patch < minor < major
    $bumpPriority = @{ 'none' = 0; 'patch' = 1; 'minor' = 2; 'major' = 3 }
    $finalSuffix = ''
    
    foreach ($commit in $mergeCommits) {
        if ([string]::IsNullOrWhiteSpace($commit)) { continue }
        
        $parts = $commit -split '\|', 2
        if ($parts.Count -lt 2) { continue }
        
        $commitHash = $parts[0]
        $commitMessage = $parts[1]
        
        Write-Verbose "Analyzing merge commit: $commitHash - $commitMessage"
        
        # Extract branch name from merge commit message
        $branchName = ""
        if ($commitMessage -match "Merge (pull request #\d+ from |branch ')([^']+)") {
            $branchName = $matches[2]
            Write-Verbose "Extracted branch name: '$branchName'"
        } elseif ($commitMessage -match "Merge branch '([^']+)'") {
            $branchName = $matches[1]
            Write-Verbose "Extracted branch name: '$branchName'"
        } else {
            Write-Verbose "Could not extract branch name from merge commit, analyzing commit message only"
        }
        
        # Analyze this merge for bump type and suffix
        $mergeBumpResult = Get-VersionBumpType -branch $branchName -message $commitMessage
        $mergeBumpType = $mergeBumpResult.bumpType
        $mergeSuffix = $mergeBumpResult.suffix
        
        # Update highest priority bump type if this one is higher
        if ($bumpPriority[$mergeBumpType] -gt $bumpPriority[$highestBump]) {
            $highestBump = $mergeBumpType
            $finalSuffix = $mergeSuffix
            Write-Verbose "Updated highest bump type to '$mergeBumpType' with suffix '$mergeSuffix' from commit: $commitMessage"
        } elseif ($bumpPriority[$mergeBumpType] -eq $bumpPriority[$highestBump] -and $mergeSuffix) {
            # Same priority but this one has a suffix - keep the suffix
            $finalSuffix = $mergeSuffix
            Write-Verbose "Same priority but updated suffix to '$mergeSuffix' from commit: $commitMessage"
        }
    }
    
    # If no specific bump type was found, default to patch
    if ($highestBump -eq 'none') {
        Write-Verbose "No specific version bump indicators found, defaulting to patch"
        return @{ bumpType = 'patch'; suffix = '' }
    }
    
    Write-Verbose "Final version bump type determined: '$highestBump' with suffix: '$finalSuffix'"
    return @{ bumpType = $highestBump; suffix = $finalSuffix }
}
