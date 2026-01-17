#region Unified Versioning Logic
# ============================================================================
# UNIFIED VERSIONING LOGIC
# ============================================================================
# This module implements a consistent versioning strategy across all K.Actions:
# - NextVersion (PowerShell modules)
# - NextNetVersion (.NET projects)
# - NextActionVersion (GitHub Actions)
#
# Key Design Decisions:
# 1. Release branches are explicitly defined (no pattern matching)
# 2. BumpType is ONLY determined by commit messages (not branch names)
# 3. PreRelease follows a strict lifecycle: Stable → Alpha → Beta → Stable
# 4. Alpha can be skipped (Stable → Beta is allowed)
# 5. Going backwards (Beta → Alpha) is forbidden
# ============================================================================

#region Configuration

# Branches that are allowed to create releases
$script:ReleaseBranches = @{
    # Branch name (exact match) => PreRelease type ($null = stable release)
    'release'     = $null      # Stable release (no prerelease tag)
    'main'        = 'beta'     # Beta prerelease
    'master'      = 'beta'     # Beta prerelease
    'staging'     = 'beta'     # Beta prerelease
    'dev'         = 'alpha'    # Alpha prerelease
    'development' = 'alpha'    # Alpha prerelease
}

# Commit patterns for BumpType detection (order matters: first match wins)
$script:MajorPatterns = @(
    'BREAKING',
    'MAJOR',
    'breaking change',
    '!:'
)

$script:MinorPatterns = @(
    'FEATURE',
    'MINOR',
    'feat:',
    'feat(',
    'feature:',
    'add:',
    'new:'
)

#endregion

#region Branch Analysis

function Test-IsReleaseBranch {
    <#
    .SYNOPSIS
        Tests if a branch is allowed to create releases.
    
    .DESCRIPTION
        Only specific branches can create version tags. This prevents
        accidental releases from feature branches or other work branches.
    
    .PARAMETER BranchName
        The exact branch name to test.
    
    .OUTPUTS
        Boolean indicating if the branch can create releases.
    
    .EXAMPLE
        Test-IsReleaseBranch -BranchName "main"
        # Returns: $true
    
    .EXAMPLE
        Test-IsReleaseBranch -BranchName "feature/new-api"
        # Returns: $false
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName
    )
    
    return $script:ReleaseBranches.ContainsKey($BranchName.ToLower())
}

function Get-PreReleaseTypeFromBranch {
    <#
    .SYNOPSIS
        Gets the prerelease type (alpha/beta/null) for a branch.
    
    .DESCRIPTION
        Determines what prerelease suffix should be applied based on the branch:
        - dev/development → alpha (early development)
        - main/master/staging → beta (testing phase)
        - release → null (stable release)
    
    .PARAMETER BranchName
        The exact branch name.
    
    .OUTPUTS
        String: 'alpha', 'beta', or $null (for stable releases)
    
    .EXAMPLE
        Get-PreReleaseTypeFromBranch -BranchName "dev"
        # Returns: "alpha"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName
    )
    
    $branchLower = $BranchName.ToLower()
    
    if ($script:ReleaseBranches.ContainsKey($branchLower)) {
        return $script:ReleaseBranches[$branchLower]
    }
    
    return $null
}

#endregion

#region BumpType Detection (Commit-based only)

function Get-BumpTypeFromCommits {
    <#
    .SYNOPSIS
        Determines version bump type by analyzing commit messages.
    
    .DESCRIPTION
        Analyzes commit messages to determine the appropriate semantic version bump:
        - major: Breaking changes (BREAKING, MAJOR, !:)
        - minor: New features (feat:, FEATURE, add:, new:)
        - patch: Everything else (default)
        
        Branch names are NOT considered - this is intentional to allow
        patch releases from any branch type.
    
    .PARAMETER Commits
        Array of commit message strings to analyze.
    
    .OUTPUTS
        String: "major", "minor", or "patch"
    
    .EXAMPLE
        Get-BumpTypeFromCommits -Commits @("feat: add new API", "fix: typo")
        # Returns: "minor"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Commits
    )
    
    # Default to patch - most common case
    $highestBump = "patch"
    
    if (-not $Commits -or $Commits.Count -eq 0) {
        Write-SafeDebugLog -Message "No commits to analyze, defaulting to patch"
        return $highestBump
    }
    
    Write-SafeDebugLog -Message "Analyzing $($Commits.Count) commits for bump type"
    
    foreach ($commit in $Commits) {
        # Check for MAJOR indicators (highest priority)
        foreach ($pattern in $script:MajorPatterns) {
            if ($commit -match [regex]::Escape($pattern)) {
                Write-SafeInfoLog -Message "Major bump indicator found: '$pattern' in commit"
                return "major"  # Early exit - can't get higher
            }
        }
        
        # Check for MINOR indicators
        foreach ($pattern in $script:MinorPatterns) {
            if ($commit -match [regex]::Escape($pattern)) {
                Write-SafeDebugLog -Message "Minor bump indicator found: '$pattern'"
                $highestBump = "minor"
                break  # Found minor in this commit, check next commit for potential major
            }
        }
    }
    
    Write-SafeInfoLog -Message "Final bump type determined: $highestBump"
    return $highestBump
}

#endregion

#region PreRelease Lifecycle Management

function Get-PreReleaseInfo {
    <#
    .SYNOPSIS
        Parses prerelease information from a semantic version string.
    
    .DESCRIPTION
        Extracts the prerelease type (alpha/beta) and build number from
        a semantic version string like "1.2.3-beta.5".
    
    .PARAMETER Version
        The semantic version string to parse.
    
    .OUTPUTS
        PSCustomObject with Type (alpha/beta/null) and BuildNumber properties.
    
    .EXAMPLE
        Get-PreReleaseInfo -Version "1.2.3-beta.5"
        # Returns: @{ Type = "beta"; BuildNumber = 5 }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )
    
    $result = [PSCustomObject]@{
        Type        = $null
        BuildNumber = 0
        BaseVersion = $Version
    }
    
    # Match prerelease pattern: X.Y.Z-type.number
    if ($Version -match '^(\d+\.\d+\.\d+)-(alpha|beta)\.(\d+)$') {
        $result.BaseVersion = $matches[1]
        $result.Type = $matches[2].ToLower()
        $result.BuildNumber = [int]$matches[3]
    }
    elseif ($Version -match '^(\d+\.\d+\.\d+)$') {
        $result.BaseVersion = $matches[1]
        # Type and BuildNumber stay at defaults (null, 0)
    }
    
    return $result
}

function Test-PreReleaseTransitionAllowed {
    <#
    .SYNOPSIS
        Tests if a prerelease type transition is allowed.
    
    .DESCRIPTION
        Enforces the prerelease lifecycle rules:
        - Stable → Alpha: ✅ Allowed (start new development)
        - Stable → Beta: ✅ Allowed (skip alpha phase)
        - Stable → Stable: ✅ Allowed (normal release)
        - Alpha → Alpha: ✅ Allowed (continue development)
        - Alpha → Beta: ✅ Allowed (promote to testing)
        - Alpha → Stable: ✅ Allowed (skip beta, direct release)
        - Beta → Beta: ✅ Allowed (continue testing)
        - Beta → Stable: ✅ Allowed (final release)
        - Beta → Alpha: ❌ FORBIDDEN (can't go backwards)
    
    .PARAMETER CurrentPreReleaseType
        Current prerelease type (alpha/beta/null)
    
    .PARAMETER TargetPreReleaseType
        Target prerelease type (alpha/beta/null)
    
    .PARAMETER BaseVersion
        The base version (X.Y.Z) being worked on.
    
    .OUTPUTS
        PSCustomObject with IsAllowed and ErrorMessage properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$CurrentPreReleaseType,
        
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$TargetPreReleaseType,
        
        [Parameter(Mandatory = $true)]
        [string]$BaseVersion
    )
    
    $result = [PSCustomObject]@{
        IsAllowed    = $true
        ErrorMessage = $null
    }
    
    # The only forbidden transition: Beta → Alpha
    if ($CurrentPreReleaseType -eq 'beta' -and $TargetPreReleaseType -eq 'alpha') {
        $result.IsAllowed = $false
        $result.ErrorMessage = "Cannot create alpha release after beta for version $BaseVersion. " +
            "The alpha phase ended when beta began. " +
            "Options: Continue with beta releases on staging/main/master, or create a stable release on 'release' branch."
    }
    
    return $result
}

function Get-NextPreReleaseBuildNumber {
    <#
    .SYNOPSIS
        Calculates the next build number for a prerelease.
    
    .DESCRIPTION
        Determines the correct build number based on the version transition:
        - New prerelease series (different base version or type): Start at 1
        - Continue same series: Increment by 1
    
    .PARAMETER CurrentVersion
        The current/last version tag.
    
    .PARAMETER NewBaseVersion
        The new base version (X.Y.Z) being created.
    
    .PARAMETER TargetPreReleaseType
        The target prerelease type (alpha/beta).
    
    .PARAMETER AllTags
        All existing version tags for finding the highest build number.
    
    .OUTPUTS
        Integer: The next build number to use.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$NewBaseVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetPreReleaseType,
        
        [Parameter(Mandatory = $false)]
        [string[]]$AllTags = @()
    )
    
    $currentInfo = Get-PreReleaseInfo -Version $CurrentVersion
    
    # If base version changed or prerelease type changed, start new series at 1
    if ($currentInfo.BaseVersion -ne $NewBaseVersion -or $currentInfo.Type -ne $TargetPreReleaseType) {
        Write-SafeDebugLog -Message "New prerelease series: $NewBaseVersion-$TargetPreReleaseType starting at .1"
        
        # But first check if there are existing tags for this series
        $pattern = "^v?$([regex]::Escape($NewBaseVersion))-$TargetPreReleaseType\.(\d+)$"
        $existingBuildNumbers = $AllTags | ForEach-Object {
            if ($_ -match $pattern) { [int]$matches[1] }
        } | Sort-Object -Descending
        
        if ($existingBuildNumbers) {
            $nextBuild = $existingBuildNumbers[0] + 1
            Write-SafeDebugLog -Message "Found existing tags, continuing at .$nextBuild"
            return $nextBuild
        }
        
        return 1
    }
    
    # Same series, increment build number
    $nextBuild = $currentInfo.BuildNumber + 1
    Write-SafeDebugLog -Message "Continuing prerelease series at .$nextBuild"
    return $nextBuild
}

#endregion

#region Main Version Calculation

function Get-UnifiedNextVersion {
    <#
    .SYNOPSIS
        Calculates the next semantic version using unified logic.
    
    .DESCRIPTION
        Main entry point for version calculation. Implements:
        1. Branch validation (only release branches allowed)
        2. Commit-based bump type detection (no branch-based bumping)
        3. PreRelease lifecycle enforcement
        4. Proper build number calculation
    
    .PARAMETER BranchName
        The current Git branch name.
    
    .PARAMETER LastReleaseTag
        The last release tag (e.g., "v1.2.3" or "1.2.3-beta.1")
    
    .PARAMETER Commits
        Array of commit messages since last release.
    
    .PARAMETER AllTags
        All version tags in the repository (for build number calculation).
    
    .OUTPUTS
        PSCustomObject with version calculation results.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName,
        
        [Parameter(Mandatory = $false)]
        [string]$LastReleaseTag = $null,
        
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$Commits = @(),
        
        [Parameter(Mandatory = $false)]
        [string[]]$AllTags = @()
    )
    
    Write-SafeInfoLog -Message "=== Unified Version Calculation ==="
    Write-SafeInfoLog -Message "Branch: $BranchName"
    Write-SafeInfoLog -Message "Last Tag: $($LastReleaseTag ?? '(none - first release)')"
    Write-SafeInfoLog -Message "Commits to analyze: $($Commits.Count)"
    
    # ===== Step 1: Validate Branch =====
    if (-not (Test-IsReleaseBranch -BranchName $BranchName)) {
        Write-SafeWarningLog -Message "Branch '$BranchName' is not a release branch"
        return [PSCustomObject]@{
            Success        = $false
            BumpType       = "none"
            CurrentVersion = $null
            NewVersion     = $null
            PreReleaseType = $null
            IsFirstRelease = $false
            Error          = "Branch '$BranchName' is not configured for releases. Allowed branches: $($script:ReleaseBranches.Keys -join ', ')"
        }
    }
    
    $targetPreReleaseType = Get-PreReleaseTypeFromBranch -BranchName $BranchName
    Write-SafeInfoLog -Message "Target PreRelease Type: $($targetPreReleaseType ?? 'stable')"
    
    # ===== Step 2: Handle First Release =====
    if (-not $LastReleaseTag) {
        Write-SafeInfoLog -Message "First release detected"
        
        $newVersion = "1.0.0"
        if ($targetPreReleaseType) {
            $newVersion = "1.0.0-$targetPreReleaseType.1"
        }
        
        return [PSCustomObject]@{
            Success        = $true
            BumpType       = "major"
            CurrentVersion = "0.0.0"
            NewVersion     = $newVersion
            PreReleaseType = $targetPreReleaseType
            BuildNumber    = if ($targetPreReleaseType) { 1 } else { $null }
            IsFirstRelease = $true
            Error          = $null
        }
    }
    
    # ===== Step 3: Parse Current Version =====
    $currentVersionClean = $LastReleaseTag -replace '^v', ''
    $currentInfo = Get-PreReleaseInfo -Version $currentVersionClean
    
    Write-SafeDebugLog -Message "Current version parsed: Base=$($currentInfo.BaseVersion), Type=$($currentInfo.Type), Build=$($currentInfo.BuildNumber)"
    
    # ===== Step 4: Validate PreRelease Transition =====
    $transitionCheck = Test-PreReleaseTransitionAllowed `
        -CurrentPreReleaseType $currentInfo.Type `
        -TargetPreReleaseType $targetPreReleaseType `
        -BaseVersion $currentInfo.BaseVersion
    
    if (-not $transitionCheck.IsAllowed) {
        Write-SafeErrorLog -Message $transitionCheck.ErrorMessage
        return [PSCustomObject]@{
            Success        = $false
            BumpType       = "none"
            CurrentVersion = $currentVersionClean
            NewVersion     = $null
            PreReleaseType = $targetPreReleaseType
            IsFirstRelease = $false
            Error          = $transitionCheck.ErrorMessage
        }
    }
    
    # ===== Step 5: Determine BumpType from Commits =====
    $bumpType = Get-BumpTypeFromCommits -Commits $Commits
    
    # ===== Step 6: Calculate New Version =====
    $newBaseVersion = $currentInfo.BaseVersion
    
    # Apply bump to base version
    $versionParts = $newBaseVersion -split '\.'
    $major = [int]$versionParts[0]
    $minor = [int]$versionParts[1]
    $patch = [int]$versionParts[2]
    
    # Special case: If going from prerelease to stable with same base, don't bump
    # Per SemVer: "1.0.0-alpha.1 < 1.0.0" - the stable release uses same number
    $isPromotingToStable = ($currentInfo.Type -and -not $targetPreReleaseType)
    
    if ($isPromotingToStable -and $bumpType -eq "patch") {
        # Promoting prerelease to stable without new features - keep same version
        Write-SafeInfoLog -Message "Promoting $($currentInfo.Type) to stable release (same base version)"
        # $newBaseVersion stays the same
    }
    else {
        # Normal version bump
        switch ($bumpType) {
            "major" {
                $major++
                $minor = 0
                $patch = 0
            }
            "minor" {
                $minor++
                $patch = 0
            }
            "patch" {
                # Only bump patch if not continuing same prerelease series
                $isSamePreReleaseSeries = ($currentInfo.Type -eq $targetPreReleaseType) -and 
                                          ($currentInfo.Type -ne $null)
                if (-not $isSamePreReleaseSeries) {
                    $patch++
                }
            }
        }
        $newBaseVersion = "$major.$minor.$patch"
    }
    
    # ===== Step 7: Apply PreRelease Suffix =====
    $newVersion = $newBaseVersion
    $buildNumber = $null
    
    if ($targetPreReleaseType) {
        $buildNumber = Get-NextPreReleaseBuildNumber `
            -CurrentVersion $currentVersionClean `
            -NewBaseVersion $newBaseVersion `
            -TargetPreReleaseType $targetPreReleaseType `
            -AllTags $AllTags
        
        $newVersion = "$newBaseVersion-$targetPreReleaseType.$buildNumber"
    }
    
    Write-SafeInfoLog -Message "=== Version Calculation Complete ==="
    Write-SafeInfoLog -Message "Result: $currentVersionClean → $newVersion (bump: $bumpType)"
    
    return [PSCustomObject]@{
        Success        = $true
        BumpType       = $bumpType
        CurrentVersion = $currentVersionClean
        NewVersion     = $newVersion
        BaseVersion    = $newBaseVersion
        PreReleaseType = $targetPreReleaseType
        BuildNumber    = $buildNumber
        IsFirstRelease = $false
        Error          = $null
    }
}

#endregion

#region Safe Logging Stubs (for standalone testing)

# These are stubs that will be overridden when the full module is loaded
if (-not (Get-Command Write-SafeInfoLog -ErrorAction SilentlyContinue)) {
    function script:Write-SafeInfoLog { param([string]$Message) Write-Verbose "[INFO] $Message" }
}
if (-not (Get-Command Write-SafeDebugLog -ErrorAction SilentlyContinue)) {
    function script:Write-SafeDebugLog { param([string]$Message) Write-Debug "[DEBUG] $Message" }
}
if (-not (Get-Command Write-SafeWarningLog -ErrorAction SilentlyContinue)) {
    function script:Write-SafeWarningLog { param([string]$Message) Write-Warning "[WARN] $Message" }
}
if (-not (Get-Command Write-SafeErrorLog -ErrorAction SilentlyContinue)) {
    function script:Write-SafeErrorLog { param([string]$Message) Write-Error "[ERROR] $Message" }
}

#endregion

#endregion
