# K.PSGallery.SemanticVersioning.Core.ps1
# Unified Versioning Logic for all K.Actions.Next*Version Actions
#
# This module implements the standardized versioning rules:
# - Release-Branches: release, main, master, staging, dev, development
# - BumpType: Commit-based only (no branch-based bumping)
# - PreRelease-Lifecycle: Stable → Alpha → Beta → Stable (one-way street)
#
# Version: 1.0.0
# Author: K.Actions Team

#region Configuration

# Release branch configuration - only these branches can create new versions
$script:ReleaseBranches = @{
    # Branch name (exact match) → PreRelease type ($null = stable)
    'release'     = $null      # Stable release
    'main'        = 'beta'     # Beta pre-release
    'master'      = 'beta'     # Beta pre-release
    'staging'     = 'beta'     # Beta pre-release
    'dev'         = 'alpha'    # Alpha pre-release
    'development' = 'alpha'    # Alpha pre-release
}

# Commit patterns for BumpType detection (case-insensitive where noted)
$script:BumpTypePatterns = @{
    Major = @(
        'BREAKING'           # BREAKING: or BREAKING CHANGE
        'MAJOR'              # MAJOR: explicit major bump
        '!:'                 # feat!: breaking feature (conventional commits)
        'breaking change'    # breaking change in message (case-insensitive)
    )
    Minor = @(
        'FEATURE'            # FEATURE: new feature
        'MINOR'              # MINOR: explicit minor bump
        'feat:'              # feat: conventional commit
        'feat('              # feat(scope): conventional commit
        'feature:'           # feature: new feature
        'add:'               # add: new addition
        'new:'               # new: new functionality
    )
    # Everything else defaults to Patch
}

# PreRelease phase priority (higher = later in lifecycle)
# Note: Use empty string '' for stable instead of $null (PowerShell limitation)
$script:PreReleasePriority = @{
    'alpha'  = 1
    'beta'   = 2
    ''       = 3  # Stable (empty string) has highest priority (end of lifecycle)
    'stable' = 3  # Alias for clarity
}

#endregion

#region Public Functions

function Get-ReleaseBranchInfo {
    <#
    .SYNOPSIS
        Determines if a branch is a release branch and its PreRelease type.
    
    .DESCRIPTION
        Checks if the given branch name is allowed to create releases.
        Returns the PreRelease type (alpha, beta, or $null for stable).
    
    .PARAMETER BranchName
        The exact branch name to check.
    
    .OUTPUTS
        PSCustomObject with:
        - IsReleaseBranch: Boolean
        - PreReleaseType: 'alpha', 'beta', or $null (stable)
        - BranchName: The input branch name
    
    .EXAMPLE
        Get-ReleaseBranchInfo -BranchName 'dev'
        # Returns: IsReleaseBranch=$true, PreReleaseType='alpha'
    
    .EXAMPLE
        Get-ReleaseBranchInfo -BranchName 'feature/xyz'
        # Returns: IsReleaseBranch=$false, PreReleaseType=$null
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName
    )
    
    $isReleaseBranch = $script:ReleaseBranches.ContainsKey($BranchName)
    $preReleaseType = if ($isReleaseBranch) { $script:ReleaseBranches[$BranchName] } else { $null }
    
    [PSCustomObject]@{
        IsReleaseBranch = $isReleaseBranch
        PreReleaseType  = $preReleaseType
        BranchName      = $BranchName
    }
}

function Get-BumpTypeFromCommits {
    <#
    .SYNOPSIS
        Analyzes commit messages to determine semantic version bump type.
    
    .DESCRIPTION
        Scans commit messages for keywords that indicate version bump type.
        Returns the highest priority bump type found (major > minor > patch).
        
        This function implements COMMIT-BASED bumping only.
        Branch-based bumping has been intentionally removed for consistency.
    
    .PARAMETER Commits
        Array of commit message strings to analyze.
    
    .OUTPUTS
        String: 'major', 'minor', or 'patch'
    
    .EXAMPLE
        Get-BumpTypeFromCommits -Commits @('feat: new login', 'fix: typo')
        # Returns: 'minor' (feat: triggers minor)
    
    .EXAMPLE
        Get-BumpTypeFromCommits -Commits @('BREAKING: removed API', 'feat: new endpoint')
        # Returns: 'major' (BREAKING takes priority)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Commits
    )
    
    $highestBump = 'patch'  # Default
    
    foreach ($commit in $Commits) {
        if ([string]::IsNullOrWhiteSpace($commit)) { continue }
        
        $commitLower = $commit.ToLower()
        
        # Check for MAJOR indicators (case-sensitive for uppercase keywords)
        foreach ($pattern in $script:BumpTypePatterns.Major) {
            $patternLower = $pattern.ToLower()
            if ($commit -match [regex]::Escape($pattern) -or $commitLower -match [regex]::Escape($patternLower)) {
                return 'major'  # Major is highest, return immediately
            }
        }
        
        # Check for MINOR indicators
        foreach ($pattern in $script:BumpTypePatterns.Minor) {
            $patternLower = $pattern.ToLower()
            if ($commit -match [regex]::Escape($pattern) -or $commitLower -match [regex]::Escape($patternLower)) {
                $highestBump = 'minor'  # Continue checking for major
                break
            }
        }
    }
    
    return $highestBump
}

function Get-PreReleaseTransition {
    <#
    .SYNOPSIS
        Validates and calculates PreRelease transitions.
    
    .DESCRIPTION
        Implements the PreRelease lifecycle rules:
        - Stable → Alpha → Beta → Stable (one-way street)
        - Alpha can be skipped (Stable → Beta is allowed)
        - Going backwards (Beta → Alpha) is forbidden
    
    .PARAMETER CurrentPreRelease
        Current PreRelease type from last tag ('alpha', 'beta', or $null)
    
    .PARAMETER TargetPreRelease
        Target PreRelease type based on branch ('alpha', 'beta', or $null)
    
    .PARAMETER CurrentVersion
        Current semantic version string (without PreRelease suffix)
    
    .OUTPUTS
        PSCustomObject with:
        - IsValid: Boolean - whether transition is allowed
        - ErrorMessage: String - error description if invalid
        - Action: String - 'continue', 'start', 'end', or 'error'
    
    .EXAMPLE
        Get-PreReleaseTransition -CurrentPreRelease 'alpha' -TargetPreRelease 'beta' -CurrentVersion '1.0.1'
        # Returns: IsValid=$true, Action='end' (ends alpha, starts beta)
    
    .EXAMPLE
        Get-PreReleaseTransition -CurrentPreRelease 'beta' -TargetPreRelease 'alpha' -CurrentVersion '1.0.1'
        # Returns: IsValid=$false, ErrorMessage='Alpha nach Beta nicht erlaubt für Version 1.0.1'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$CurrentPreRelease,
        
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$TargetPreRelease,
        
        [Parameter(Mandatory = $true)]
        [string]$CurrentVersion
    )
    
    # Normalize null/empty values to empty string for hashtable lookup
    $currentKey = if ([string]::IsNullOrWhiteSpace($CurrentPreRelease)) { '' } else { $CurrentPreRelease }
    $targetKey = if ([string]::IsNullOrWhiteSpace($TargetPreRelease)) { '' } else { $TargetPreRelease }
    
    # Normalize the actual values for comparison
    if ([string]::IsNullOrWhiteSpace($CurrentPreRelease)) { $CurrentPreRelease = $null }
    if ([string]::IsNullOrWhiteSpace($TargetPreRelease)) { $TargetPreRelease = $null }
    
    $currentPriority = $script:PreReleasePriority[$currentKey]
    $targetPriority = $script:PreReleasePriority[$targetKey]
    
    # Default to stable (3) if not found
    if ($null -eq $currentPriority) { $currentPriority = 3 }
    if ($null -eq $targetPriority) { $targetPriority = 3 }
    
    # Determine action type FIRST to check for valid/invalid transitions
    # NOTE: Use IsNullOrWhiteSpace because [string] parameters convert $null to empty string!
    $curIsEmpty = [string]::IsNullOrWhiteSpace($CurrentPreRelease)
    $tarIsEmpty = [string]::IsNullOrWhiteSpace($TargetPreRelease)
    
    $action = if ($curIsEmpty -eq $tarIsEmpty -and $CurrentPreRelease -eq $TargetPreRelease) {
        'continue'  # Same phase, increment build number
    }
    elseif ($curIsEmpty -and -not $tarIsEmpty) {
        'start'  # Starting new PreRelease series from stable - ALWAYS VALID
    }
    elseif (-not $curIsEmpty -and $tarIsEmpty) {
        'end'  # Ending PreRelease, going to stable - ALWAYS VALID
    }
    else {
        'transition'  # Moving between PreRelease types (alpha → beta or INVALID beta → alpha)
    }
    
    # Validate transitions ONLY for 'transition' action (not for start/end)
    # - 'start' (Stable → Alpha/Beta) is ALWAYS valid (new lifecycle)
    # - 'end' (Alpha/Beta → Stable) is ALWAYS valid (release)
    # - 'transition' within PreRelease must move FORWARD (alpha→beta, not beta→alpha)
    if ($action -eq 'transition' -and $targetPriority -lt $currentPriority) {
        # Trying to go backwards WITHIN PreRelease lifecycle (e.g., beta → alpha)
        $currentName = if ($CurrentPreRelease) { $CurrentPreRelease } else { 'stable' }
        $targetName = if ($TargetPreRelease) { $TargetPreRelease } else { 'stable' }
        
        return [PSCustomObject]@{
            IsValid      = $false
            ErrorMessage = "$($targetName.ToUpper()) nach $($currentName.ToUpper()) nicht erlaubt für Version $CurrentVersion"
            Action       = 'error'
        }
    }
    
    return [PSCustomObject]@{
        IsValid      = $true
        ErrorMessage = $null
        Action       = $action
    }
}

function Get-NextBuildNumber {
    <#
    .SYNOPSIS
        Determines the next build number for a PreRelease version.
    
    .DESCRIPTION
        Searches existing Git tags to find the highest build number
        for a given version and PreRelease type, then returns the next number.
    
    .PARAMETER BaseVersion
        The semantic version without PreRelease (e.g., '1.2.3')
    
    .PARAMETER PreReleaseType
        The PreRelease type ('alpha' or 'beta')
    
    .PARAMETER ExistingTags
        Array of existing Git tags to search
    
    .OUTPUTS
        Int32: The next build number (1 if no existing tags found)
    
    .EXAMPLE
        Get-NextBuildNumber -BaseVersion '1.2.0' -PreReleaseType 'alpha' -ExistingTags @('v1.2.0-alpha.1', 'v1.2.0-alpha.2')
        # Returns: 3
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$PreReleaseType,
        
        [Parameter(Mandatory = $false)]
        [string[]]$ExistingTags = @()
    )
    
    $maxBuildNumber = 0
    $pattern = "^v?$([regex]::Escape($BaseVersion))-$([regex]::Escape($PreReleaseType))\.(\d+)$"
    
    foreach ($tag in $ExistingTags) {
        if ($tag -match $pattern) {
            $buildNum = [int]$matches[1]
            if ($buildNum -gt $maxBuildNumber) {
                $maxBuildNumber = $buildNum
            }
        }
    }
    
    return $maxBuildNumber + 1
}

function Step-SemanticVersion {
    <#
    .SYNOPSIS
        Increments a semantic version by the specified bump type.
    
    .DESCRIPTION
        Takes a semantic version string and increments the appropriate part
        based on the bump type. Resets lower parts to zero as per SemVer spec.
    
    .PARAMETER Version
        The current semantic version string (e.g., '1.2.3')
    
    .PARAMETER BumpType
        The type of bump: 'major', 'minor', or 'patch'
    
    .OUTPUTS
        String: The new version string
    
    .EXAMPLE
        Step-SemanticVersion -Version '1.2.3' -BumpType 'minor'
        # Returns: '1.3.0'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('major', 'minor', 'patch')]
        [string]$BumpType
    )
    
    # Remove any 'v' prefix and PreRelease suffix for parsing
    $cleanVersion = $Version -replace '^v', '' -replace '-.*$', ''
    
    try {
        $semVer = [Version]$cleanVersion
    }
    catch {
        throw "Invalid version format: $Version"
    }
    
    $major = $semVer.Major
    $minor = $semVer.Minor
    $patch = if ($semVer.Build -ge 0) { $semVer.Build } else { 0 }
    
    switch ($BumpType) {
        'major' {
            $major++
            $minor = 0
            $patch = 0
        }
        'minor' {
            $minor++
            $patch = 0
        }
        'patch' {
            $patch++
        }
    }
    
    return "$major.$minor.$patch"
}

function Get-NextVersion {
    <#
    .SYNOPSIS
        Calculates the next semantic version based on all rules.
    
    .DESCRIPTION
        Main entry point for version calculation. Combines all rules:
        - Release branch validation
        - Commit-based BumpType detection
        - PreRelease lifecycle management
        - Build number calculation
    
    .PARAMETER BranchName
        Current Git branch name
    
    .PARAMETER LastTag
        Last release tag from Git (can be $null for first release)
    
    .PARAMETER Commits
        Array of commit messages since last tag
    
    .PARAMETER ExistingTags
        Array of all existing Git tags (for build number calculation)
    
    .OUTPUTS
        PSCustomObject with comprehensive version information
    
    .EXAMPLE
        Get-NextVersion -BranchName 'dev' -LastTag 'v1.0.0' -Commits @('feat: new feature') -ExistingTags @('v1.0.0')
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName,
        
        [Parameter(Mandatory = $false)]
        [string]$LastTag,
        
        [Parameter(Mandatory = $false)]
        [string[]]$Commits = @(),
        
        [Parameter(Mandatory = $false)]
        [string[]]$ExistingTags = @()
    )
    
    # Step 1: Check if branch is allowed to release
    $branchInfo = Get-ReleaseBranchInfo -BranchName $BranchName
    
    if (-not $branchInfo.IsReleaseBranch) {
        return [PSCustomObject]@{
            Success           = $false
            BumpType          = 'none'
            CurrentVersion    = $null
            NewVersion        = $null
            PreReleaseType    = $null
            BuildNumber       = $null
            IsFirstRelease    = $false
            LastTag           = $LastTag
            BranchName        = $BranchName
            ErrorMessage      = "Branch '$BranchName' ist kein Release-Branch. Erlaubt: $($script:ReleaseBranches.Keys -join ', ')"
            ActionRequired    = $false
        }
    }
    
    # Step 2: Handle first release
    $isFirstRelease = [string]::IsNullOrWhiteSpace($LastTag)
    
    if ($isFirstRelease) {
        $bumpType = 'major'  # First release is always 1.0.0
        $baseVersion = '1.0.0'
        $currentPreRelease = $null
    }
    else {
        # Parse last tag
        $cleanLastTag = $LastTag -replace '^v', ''
        
        # Extract base version and PreRelease info
        if ($cleanLastTag -match '^(\d+\.\d+\.\d+)(?:-([a-zA-Z]+)\.(\d+))?$') {
            $lastBaseVersion = $matches[1]
            $currentPreRelease = $matches[2]
            $currentBuildNumber = if ($matches[3]) { [int]$matches[3] } else { $null }
        }
        else {
            $lastBaseVersion = $cleanLastTag -replace '-.*$', ''
            $currentPreRelease = $null
            $currentBuildNumber = $null
        }
        
        # Step 3: Determine BumpType from commits
        $bumpType = Get-BumpTypeFromCommits -Commits $Commits
        Write-Verbose "Detected BumpType: $bumpType"
        
        # Step 4: Validate PreRelease transition
        $targetPreRelease = $branchInfo.PreReleaseType
        $transition = Get-PreReleaseTransition -CurrentPreRelease $currentPreRelease -TargetPreRelease $targetPreRelease -CurrentVersion $lastBaseVersion
        Write-Verbose "PreRelease transition: $($transition.Action) (IsValid: $($transition.IsValid))"
        
        if (-not $transition.IsValid) {
            Write-Verbose "PreRelease lifecycle violation: $($transition.ErrorMessage)"
            return [PSCustomObject]@{
                Success           = $false
                BumpType          = 'none'
                CurrentVersion    = $lastBaseVersion
                NewVersion        = $null
                PreReleaseType    = $targetPreRelease
                BuildNumber       = $null
                IsFirstRelease    = $false
                LastTag           = $LastTag
                BranchName        = $BranchName
                ErrorMessage      = $transition.ErrorMessage
                ActionRequired    = $true
            }
        }
        
        # Step 5: Calculate new version based on transition type
        switch ($transition.Action) {
            'continue' {
                # Same PreRelease phase - check if we need to bump or just increment build
                if ($Commits.Count -eq 0) {
                    # No commits, no change needed
                    Write-Verbose "No commits since last tag - no new version required"
                    return [PSCustomObject]@{
                        Success           = $false
                        BumpType          = 'none'
                        CurrentVersion    = $lastBaseVersion
                        NewVersion        = $null
                        PreReleaseType    = $targetPreRelease
                        BuildNumber       = $null
                        IsFirstRelease    = $false
                        LastTag           = $LastTag
                        BranchName        = $BranchName
                        ErrorMessage      = 'No commits since last tag - no new version required'
                        ActionRequired    = $false
                    }
                }
                
                # For stable releases (no PreRelease), always apply the bump
                # For PreRelease "continue", we keep the same base version and just increment build number
                if ([string]::IsNullOrWhiteSpace($targetPreRelease)) {
                    # Stable branch - always bump version
                    Write-Verbose "Stable branch: Applying bump $bumpType to $lastBaseVersion"
                    $baseVersion = Step-SemanticVersion -Version $lastBaseVersion -BumpType $bumpType
                }
                else {
                    # PreRelease branch with "continue" action - keep base version, increment build number
                    # The bump type is tracked but only affects the NEXT stable release
                    Write-Verbose "PreRelease 'continue': Keeping base version $lastBaseVersion, incrementing build number"
                    $baseVersion = $lastBaseVersion
                }
            }
            'start' {
                # Starting new PreRelease from stable
                Write-Verbose "PreRelease 'start': Starting new PreRelease from stable with bump $bumpType"
                $baseVersion = Step-SemanticVersion -Version $lastBaseVersion -BumpType $bumpType
            }
            'transition' {
                # Moving from alpha to beta - same base version, reset build number
                Write-Verbose "PreRelease 'transition': Moving from $currentPreRelease to $targetPreRelease, keeping base version $lastBaseVersion"
                $baseVersion = $lastBaseVersion
            }
            'end' {
                # Going from PreRelease to stable - SemVer says: may release same version without PreRelease
                # But if there are bump indicators, apply them
                if ($bumpType -eq 'patch' -and $Commits.Count -gt 0) {
                    # No explicit bump indicator but there are commits - release current version as stable
                    Write-Verbose "PreRelease 'end': No explicit bump indicator, releasing $lastBaseVersion as stable"
                    $baseVersion = $lastBaseVersion
                }
                else {
                    # Explicit bump indicator - apply it
                    Write-Verbose "PreRelease 'end': Explicit bump $bumpType, applying to $lastBaseVersion"
                    $baseVersion = Step-SemanticVersion -Version $lastBaseVersion -BumpType $bumpType
                }
            }
        }
    }
    
    # Step 6: Calculate build number if PreRelease
    $targetPreRelease = $branchInfo.PreReleaseType
    $buildNumber = $null
    $newVersion = $baseVersion
    
    if ($null -ne $targetPreRelease) {
        # Determine if this is a new series or continuation
        $lastTagBase = if ($LastTag) { ($LastTag -replace '^v', '') -replace '-.*$', '' } else { $null }
        
        if ($baseVersion -eq $lastTagBase -and $currentPreRelease -eq $targetPreRelease) {
            # Continuing same version and same PreRelease type - increment build number
            $buildNumber = Get-NextBuildNumber -BaseVersion $baseVersion -PreReleaseType $targetPreRelease -ExistingTags $ExistingTags
        }
        else {
            # New version or new PreRelease type - start at 1
            $buildNumber = 1
        }
        
        $newVersion = "$baseVersion-$targetPreRelease.$buildNumber"
    }
    
    return [PSCustomObject]@{
        Success           = $true
        BumpType          = $bumpType
        CurrentVersion    = if ($LastTag) { $LastTag -replace '^v', '' } else { '0.0.0' }
        NewVersion        = $newVersion
        PreReleaseType    = $targetPreRelease
        BuildNumber       = $buildNumber
        IsFirstRelease    = $isFirstRelease
        LastTag           = $LastTag
        BranchName        = $BranchName
        ErrorMessage      = $null
        ActionRequired    = $false
    }
}

#endregion

#region Exports

# Export all public functions (only when loaded as module)
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function @(
        'Get-ReleaseBranchInfo'
        'Get-BumpTypeFromCommits'
        'Get-PreReleaseTransition'
        'Get-NextBuildNumber'
        'Step-SemanticVersion'
        'Get-NextVersion'
    )
}

#endregion
