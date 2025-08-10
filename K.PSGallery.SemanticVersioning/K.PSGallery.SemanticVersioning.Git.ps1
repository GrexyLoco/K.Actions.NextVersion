# Git Operations for K.PSGallery.SemanticVersioning
# Functions for Git repository analysis and tag management

function Get-LatestReleaseTag {
    <#
    .SYNOPSIS
        Gets the latest release tag from the Git repository.
    
    .DESCRIPTION
        Retrieves the most recent Git tag that follows semantic versioning format.
        Returns null if no valid semantic version tags are found.
    
    .PARAMETER WorkingDirectory
        The path to the Git repository. Defaults to current directory.
    
    .OUTPUTS
        String representing the latest semantic version tag, or $null if none found.
    
    .EXAMPLE
        $latestTag = Get-LatestReleaseTag
        # Returns: "v1.2.3" or $null
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory = (Get-Location).Path
    )
    
    try {
        Write-SafeDebugLog -Message "Getting latest release tag from Git repository" -Context "WorkingDirectory: $WorkingDirectory"
        
        Push-Location $WorkingDirectory
        
        # Get all tags and sort them by version
        $tags = & git tag -l 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $tags) {
            Write-SafeInfoLog -Message "No Git tags found in repository"
            return $null
        }
        
        # Filter for semantic version tags and sort
        $semanticTags = $tags | Where-Object { 
            $_ -match '^v?\d+\.\d+\.\d+(-[a-zA-Z0-9\-\.]+)?(\+[a-zA-Z0-9\-\.]+)?$' 
        } | Sort-Object {
            # Extract version for sorting
            if ($_ -match '^v?(\d+)\.(\d+)\.(\d+)') {
                [Version]"$($matches[1]).$($matches[2]).$($matches[3])"
            }
        } -Descending
        
        $latestTag = $semanticTags | Select-Object -First 1
        
        if ($latestTag) {
            Write-SafeInfoLog -Message "Found latest release tag: $latestTag"
        } else {
            Write-SafeInfoLog -Message "No semantic version tags found"
        }
        
        return $latestTag
    }
    catch {
        Write-SafeErrorLog -Message "Failed to get latest release tag" -Context $_.Exception.Message
        return $null
    }
    finally {
        Pop-Location
    }
}

function Get-TargetBranch {
    <#
    .SYNOPSIS
        Determines the target branch for version bumping based on current branch and patterns.
    
    .DESCRIPTION
        Analyzes the current Git branch and determines appropriate version bump strategy.
        Supports main/master, develop, release/*, hotfix/*, and feature/* patterns.
    
    .PARAMETER WorkingDirectory
        The path to the Git repository. Defaults to current directory.
    
    .OUTPUTS
        Hashtable with BranchName, BranchType, and suggested VersionBump properties.
    
    .EXAMPLE
        $target = Get-TargetBranch
        # Returns: @{ BranchName = "main"; BranchType = "main"; VersionBump = "patch" }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory = (Get-Location).Path
    )
    
    try {
        Write-SafeDebugLog -Message "Determining target branch and version bump strategy"
        
        Push-Location $WorkingDirectory
        
        # Get current branch name
        $currentBranch = & git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get current branch name"
        }
        
        Write-SafeInfoLog -Message "Current branch: $currentBranch"
        
        # Determine branch type and suggested version bump
        $result = @{
            BranchName = $currentBranch
            BranchType = "unknown"
            VersionBump = "patch"
        }
        
        switch -Regex ($currentBranch) {
            '^(main|master)$' {
                $result.BranchType = "main"
                $result.VersionBump = "patch"
                Write-SafeInfoLog -Message "Main/Master branch detected - suggesting patch bump"
            }
            '^develop$' {
                $result.BranchType = "develop"
                $result.VersionBump = "minor"
                Write-SafeInfoLog -Message "Develop branch detected - suggesting minor bump"
            }
            '^release/.*' {
                $result.BranchType = "release"
                $result.VersionBump = "minor"
                Write-SafeInfoLog -Message "Release branch detected - suggesting minor bump"
            }
            '^hotfix/.*' {
                $result.BranchType = "hotfix"
                $result.VersionBump = "patch"
                Write-SafeInfoLog -Message "Hotfix branch detected - suggesting patch bump"
            }
            '^feature/.*' {
                $result.BranchType = "feature"
                $result.VersionBump = "minor"
                Write-SafeInfoLog -Message "Feature branch detected - suggesting minor bump"
            }
            default {
                $result.BranchType = "other"
                $result.VersionBump = "patch"
                Write-SafeWarningLog -Message "Unknown branch pattern - defaulting to patch bump"
            }
        }
        
        return $result
    }
    catch {
        Write-SafeErrorLog -Message "Failed to determine target branch" -Context $_.Exception.Message
        return @{
            BranchName = "unknown"
            BranchType = "unknown"
            VersionBump = "patch"
        }
    }
    finally {
        Pop-Location
    }
}
