<#
.SYNOPSIS
    Calculates the next semantic version number based on branch naming conventions and git history analysis.

.DESCRIPTION
    This script implements semantic versioning (SemVer) logic for PowerShell modules by analyzing
    merged branches since the last release to determine the appropriate version bump type (major, minor, or patch).
    
    For first releases (no existing tags), the script uses a hybrid approach:
    - If PSD1 version is 0.0.0 or 1.0.0: Uses as base for version bump
    - If PSD1 version is unusual (e.g., 3.5.2): Warns and requires confirmation
    - Analyzes git history since repository start to determine appropriate bump type
    
    The script follows these conventions:
    - Major version bump: Triggered by 'major/' branch prefix or 'BREAKING'/'MAJOR' in commit message
    - Minor version bump: Triggered by 'feature/' branch prefix or 'FEATURE'/'MINOR' in commit message
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

.PARAMETER TargetBranch
    Target branch for release analysis (main/master). Auto-discovery if empty.

.PARAMETER ForceFirstRelease
    Force first release even with unusual PSD1 version. Use when migrating existing projects.

.OUTPUTS
    PSCustomObject
    Returns object with properties:
    - CurrentVersion: The current version from the manifest file
    - BumpType: Detected version bump type (major/minor/patch/none)
    - NewVersion: The calculated new semantic version
    - LastReleaseTag: The latest release tag found
    - TargetBranch: The target branch used for analysis
    - Suffix: Alpha/Beta suffix if detected
    - Warning: Warning message if unusual version detected

.EXAMPLE
    .\Get-NextVersion.ps1
    
    Uses default parameters to find manifest and determine version from current environment.

.EXAMPLE
    .\Get-NextVersion.ps1 -ManifestPath "C:\MyModule\MyModule.psd1" -BranchName "feature/new-logging"
    
    Explicitly specifies manifest path and branch for a feature branch.

.EXAMPLE
    .\Get-NextVersion.ps1 -ForceFirstRelease:$true
    
    Forces first release even if PSD1 has unusual version (e.g., when migrating existing project).

.NOTES
    Author: K.Actions.NextVersion
    Version: 2.0
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
    [string]$ManifestPath = "",
    
    [Parameter(HelpMessage = "Git branch name to analyze for version bump type")]
    [string]$BranchName = $env:GITHUB_REF_NAME,
    
    [Parameter(HelpMessage = "Target branch for release analysis (auto-discovery if empty)")]
    [string]$TargetBranch = "",
    
    [Parameter(HelpMessage = "Force first release even with unusual PSD1 version")]
    [switch]$ForceFirstRelease
)

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
        Write-Warning "Failed to execute git log command: $($_.Exception.Message)"
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

<#
.SYNOPSIS
    Validates first release version based on PSD1 content and provides warnings for unusual versions.

.DESCRIPTION
    Implements hybrid first release logic:
    - Standard versions (0.0.0, 1.0.0): Use as base for bump
    - Unusual versions (e.g., 3.5.2): Warn and require confirmation
    - Force flag: Skip validation and use PSD1 version

.PARAMETER currentVersion
    The current version from PSD1 manifest

.PARAMETER forceFirstRelease
    Force flag to skip validation

.OUTPUTS
    Hashtable
    Returns validation result with baseVersion and warning message

.EXAMPLE
    Test-FirstReleaseVersion -currentVersion "1.0.0" -forceFirstRelease:$false
    Returns: @{ baseVersion = "1.0.0"; warning = "" }

.EXAMPLE
    Test-FirstReleaseVersion -currentVersion "3.5.2" -forceFirstRelease:$false
    Returns: @{ baseVersion = "3.5.2"; warning = "Unusual first release version detected..." }
#>
function Test-FirstReleaseVersion {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$currentVersion,
        
        [Parameter(Mandatory = $false)]
        [bool]$forceFirstRelease = $false
    )
    
    # Standard first release versions that don't require validation
    $standardVersions = @('0.0.0', '1.0.0')
    
    if ($currentVersion -in $standardVersions) {
        Write-Verbose "Standard first release version detected: $currentVersion"
        return @{ 
            baseVersion = $currentVersion
            warning = ""
        }
    }
    
    if ($forceFirstRelease) {
        Write-Verbose "Force flag enabled, using PSD1 version: $currentVersion"
        return @{ 
            baseVersion = $currentVersion
            warning = "First release forced with version $currentVersion (migration mode)"
        }
    }
    
    # Unusual version detected - generate warning
    $warningMessage = "Unusual first release version '$currentVersion' detected. Standard practice is to start with 0.0.0 or 1.0.0. Use -ForceFirstRelease to proceed anyway."
    Write-Warning $warningMessage
    
    return @{ 
        baseVersion = $currentVersion
        warning = $warningMessage
    }
}

#region Main Script Execution
# =============================================================================
# MAIN SCRIPT LOGIC - HYBRID FIRST RELEASE IMPLEMENTATION
# =============================================================================

try {
    # Auto-discover target branch if not specified
    if ([string]::IsNullOrWhiteSpace($TargetBranch)) {
        $TargetBranch = Get-TargetBranch
        Write-Verbose "Auto-discovered target branch: '$TargetBranch'"
    }
    
    # Verify we're analyzing the target branch
    if ($BranchName -ne $TargetBranch) {
        Write-Verbose "Current branch '$BranchName' is not the target branch '$TargetBranch'"
        Write-Host "ℹ️ Not on target branch '$TargetBranch', no version bump needed"
        
        return [PSCustomObject]@{
            CurrentVersion = "0.0.0"
            BumpType = "none"
            NewVersion = "0.0.0"
            LastReleaseTag = ""
            TargetBranch = $TargetBranch
            Suffix = ""
            Warning = "Not on target branch for release"
        }
    }

    # Auto-discover manifest file if not provided
    if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
        Write-Verbose "No manifest path provided, attempting auto-discovery..."
        $manifestFiles = Get-ChildItem -Recurse -Filter "*.psd1" -ErrorAction SilentlyContinue
        
        if ($manifestFiles.Count -eq 0) {
            throw "No PowerShell manifest files (.psd1) found in current directory or subdirectories. Please specify -ManifestPath parameter."
        }
        
        if ($manifestFiles.Count -gt 1) {
            Write-Warning "Multiple .psd1 files found. Using first one: $($manifestFiles[0].FullName)"
            Write-Verbose "Available manifests: $($manifestFiles.FullName -join ', ')"
        }
        
        $ManifestPath = $manifestFiles[0].FullName
        Write-Verbose "Auto-discovered manifest: $ManifestPath"
    }
    
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
    
    # Find the latest release tag
    $latestReleaseTag = Get-LatestReleaseTag
    $warningMessage = ""
    
    if ([string]::IsNullOrWhiteSpace($latestReleaseTag)) {
        Write-Verbose "No previous release tags found, implementing hybrid first release logic"
        Write-Host "🎉 No previous releases found - implementing first release logic!"
        
        # Validate first release version (Hybrid Approach)
        $firstReleaseValidation = Test-FirstReleaseVersion -currentVersion $currentVersion -forceFirstRelease $ForceFirstRelease.IsPresent
        $baseVersion = $firstReleaseValidation.baseVersion
        $warningMessage = $firstReleaseValidation.warning
        
        # If there's a warning and no force flag, we should fail unless confirmed
        if ($warningMessage -and -not $ForceFirstRelease) {
            throw $warningMessage
        }
        
        # Analyze git history to determine bump type
        $bumpResult = Get-ReleaseVersionBumpType -lastReleaseTag "" -targetBranch $TargetBranch
        $bumpType = $bumpResult.bumpType
        $suffix = $bumpResult.suffix
        
        # Calculate new version using PSD1 version as base (HYBRID APPROACH)
        $newVersion = Bump-Version -currentVersion $baseVersion -bumpType $bumpType -suffix $suffix
        
        Write-Host "📦 First release calculated from PSD1 base version: $baseVersion → $newVersion"
        
    } else {
        Write-Verbose "Latest release tag found: '$latestReleaseTag'"
        Write-Host "📋 Analyzing changes since last release: $latestReleaseTag"
        
        # Analyze changes since last release (normal behavior)
        $bumpResult = Get-ReleaseVersionBumpType -lastReleaseTag $latestReleaseTag -targetBranch $TargetBranch
        $bumpType = $bumpResult.bumpType
        $suffix = $bumpResult.suffix
        
        # Calculate new version from current version
        $newVersion = Bump-Version -currentVersion $currentVersion -bumpType $bumpType -suffix $suffix
    }
    
    # Output results for debugging
    Write-Host "📊 Version Analysis Results:"
    Write-Host "   Current version: $currentVersion"
    Write-Host "   Bump type: $bumpType"
    if ($suffix) {
        Write-Host "   Suffix: $suffix"
    }
    Write-Host "   New version: $newVersion"
    if ($latestReleaseTag) {
        Write-Host "   Since release: $latestReleaseTag"
    } else {
        Write-Host "   Since: Repository start (first release using hybrid logic)"
    }
    if ($warningMessage) {
        Write-Host "   ⚠️ Warning: $warningMessage"
    }
    
    # Return structured object for GitHub Actions consumption
    return [PSCustomObject]@{
        CurrentVersion = $currentVersion
        BumpType = $bumpType
        NewVersion = $newVersion
        LastReleaseTag = $latestReleaseTag
        TargetBranch = $TargetBranch
        Suffix = $suffix
        Warning = $warningMessage
    }
}
catch {
    Write-Error "Failed to determine next version: $($_.Exception.Message)"
    # Return object with error information
    return [PSCustomObject]@{
        CurrentVersion = ""
        BumpType = "none"
        NewVersion = ""
        LastReleaseTag = ""
        TargetBranch = $TargetBranch
        Suffix = ""
        Warning = ""
        Error = $_.Exception.Message
    }
    exit 1
}

#endregion Main Script Execution