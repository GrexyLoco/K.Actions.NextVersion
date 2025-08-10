<#
.SYNOPSIS
    Auto-discovers the main/master/release branch name.

.DESCRIPTION
    Attempts to find the primary branch name by checking common patterns
    and git repository configuration.

.OUTPUTS
    System.String
    Returns the discovered target branch name (e.g., "main", "master", "release")

.EXAMPLE
    Get-TargetBranch
    Returns: "main" (if main branch exists and is the default)
#>
function Get-TargetBranch {
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    Write-Verbose "Auto-discovering target branch name"
    
    try {
        # Try to get default branch from git
        $defaultBranch = git symbolic-ref refs/remotes/origin/HEAD 2>$null
        if ($defaultBranch) {
            $branchName = ($defaultBranch -split '/')[-1]
            Write-Verbose "Found default branch from origin/HEAD: '$branchName'"
            return $branchName
        }
        
        # Fallback: check for common branch names
        $commonBranches = @('main', 'master', 'release', 'develop')
        $availableBranches = git branch -r 2>$null | ForEach-Object { ($_ -replace '^\s*origin/', '').Trim() }
        
        foreach ($branch in $commonBranches) {
            if ($availableBranches -contains $branch) {
                Write-Verbose "Found target branch by common name: '$branch'"
                return $branch
            }
        }
        
        # Ultimate fallback: use current branch if we're on main/master
        $currentBranch = git branch --show-current 2>$null
        if ($currentBranch -and $currentBranch -in @('main', 'master', 'release')) {
            Write-Verbose "Using current branch as target: '$currentBranch'"
            return $currentBranch
        }
        
        # Default fallback
        Write-Verbose "Could not auto-discover target branch, defaulting to 'main'"
        return 'main'
    }
    catch {
        Write-Warning "Failed to auto-discover target branch: $($_.Exception.Message)"
        return 'main'
    }
}
