# Konsistenzprüfung auslagern
function Handle-ConsistencyCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentVersion,
        [Parameter(Mandatory = $true)]
        [string]$LatestTag,
        [Parameter(Mandatory = $false)]
        [switch]$ForceVersionMismatch
    )
    $consistencyResult = Test-PSD1TagConsistency -PSD1Version $CurrentVersion -LatestTag $LatestTag -ForceVersionMismatch:$ForceVersionMismatch
    if ($consistencyResult.RequiresAction) {
        return New-VersionResultObject -CurrentVersion $CurrentVersion -BumpType "none" -NewVersion $CurrentVersion -LastReleaseTag $LatestTag -IsFirstRelease $false -Error $consistencyResult.Error -Instructions $consistencyResult.Instructions -GitContext $consistencyResult.Context
    }
    return $null
}
# Hilfsfunktion: Manifest-Handling

# Generische Ergebnisobjekt-Fabrik für Versioning
function New-VersionResultObject {
    param(
        [Parameter(Mandatory = $false)]
        [ValidatePattern('^\d+\.\d+\.\d+$')]
        [string]$CurrentVersion = $null,

        [Parameter(Mandatory = $false)]
        [ValidateSet("major", "minor", "patch", "none")]
        [string]$BumpType = "none",

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^\d+\.\d+\.\d+$')]
        [string]$NewVersion = $null,

        [Parameter(Mandatory = $false)]
        [string]$LastReleaseTag = $null,

        [Parameter(Mandatory = $false)]
        [bool]$IsFirstRelease = $null,

        [Parameter(Mandatory = $false)]
        [string]$Error = $null,

        [Parameter(Mandatory = $false)]
        $Instructions = $null,

        [Parameter(Mandatory = $false)]
        [ValidateScript({ $_ -is [hashtable] })]
        $GitContext = @{}
    )
    return [PSCustomObject]@{
        CurrentVersion = $CurrentVersion
        BumpType       = $BumpType
        NewVersion     = $NewVersion
        LastReleaseTag = $LastReleaseTag
        IsFirstRelease = $IsFirstRelease
        Error          = $Error
        Instructions   = $Instructions
        GitContext     = $GitContext
    }
}
function Get-ValidManifestPath {
    param (
        [string]$ManifestPath
    )
    if ([string]::IsNullOrEmpty($ManifestPath)) {
        $psd1Files = Get-ChildItem -Path . -Filter "*.psd1" -Recurse | Where-Object { $_.Name -notlike "*Tests*" }
        if ($psd1Files.Count -eq 0) {
            return @{ Success = $false; Value = $null; Error = "No .psd1 manifest file found by auto discover" }
        }
        $ManifestPath = $psd1Files[0].FullName
        Write-SafeInfoLog -Message "Auto-discovered manifest: $ManifestPath"
    }
    if (-not (Test-Path $ManifestPath)) {
        return @{ Success = $false; Value = $null; Error = "No .psd1 manifest file found for path $ManifestPath" }
    }
    return @{ Success = $true; Value = $ManifestPath; Error = $null }
}

# Semantic Versioning Functions for K.PSGallery.SemanticVersioning
# Core versioning logic, manifest processing, and version calculation

function Test-PSD1TagConsistency {
    param (
        [string]$PSD1Version,
        [string]$LatestTag,
        [switch]$ForceVersionMismatch
    )
    if ([string]::IsNullOrEmpty($LatestTag)) {
        return New-VersionResultObject -CurrentVersion $PSD1Version -LastReleaseTag $LatestTag -Error $null -Instructions $null -GitContext @{ Consistency = "No tag found" }
    }
    try {
        $psd1Ver = [Version]::Parse($PSD1Version)
        $tagVer = [Version]::Parse(($LatestTag -replace '^v', ''))
    } catch {
        return New-VersionResultObject -CurrentVersion $PSD1Version -LastReleaseTag $LatestTag -Error "Invalid version format in PSD1 or tag." -Instructions "Check ModuleVersion and tag format." -GitContext @{ PSD1Version = $PSD1Version; LatestTag = $LatestTag }
    }
    if ($psd1Ver -lt $tagVer -and -not $ForceVersionMismatch) {
        return New-VersionResultObject -CurrentVersion $PSD1Version -LastReleaseTag $LatestTag -Error "PSD1-Version ($PSD1Version) ist älter als der neueste Tag ($LatestTag)." -Instructions @{
            Message  = "Bitte gleiche die Versionen ab."
            Optionen = @(
                "Option 1: Setze ModuleVersion in der PSD1 auf $LatestTag",
                "Option 2: Lösche/ändere die Tags falls gewollt",
                "Option 3: Nutze -ForceVersionMismatch, um absichtlich rückwärts zu gehen (nicht empfohlen)"
            )
        } -GitContext @{ PSD1Version = $PSD1Version; LatestTag = $LatestTag }
    }
    if ($psd1Ver -gt $tagVer -and -not $ForceVersionMismatch) {
        return New-VersionResultObject -CurrentVersion $PSD1Version -LastReleaseTag $LatestTag -Error "PSD1-Version ($PSD1Version) ist höher als der neueste Tag ($LatestTag)." -Instructions @{
            Message  = "Großer Versionssprung erkannt. Prüfe, ob dies gewollt ist."
            Optionen = @(
                "Option 1: Setze ModuleVersion auf $LatestTag für sequenzielle Releases",
                "Option 2: Nutze -ForceVersionMismatch für absichtlichen Sprung"
            )
        } -GitContext @{ PSD1Version = $PSD1Version; LatestTag = $LatestTag }
    }
    if ($psd1Ver -eq $tagVer) {
        # Warnung, falls PSD1-Version identisch mit Tag (doppelte Releases vermeiden)
        return New-VersionResultObject -CurrentVersion $PSD1Version -LastReleaseTag $LatestTag -Error $null -Instructions $null -GitContext @{ Consistency = "PSD1-Version und Tag identisch" }
    }
    return New-VersionResultObject -CurrentVersion $PSD1Version -LastReleaseTag $LatestTag -Error $null -Instructions $null -GitContext @{ Consistency = "No action required" }
}

function Get-NextSemanticVersion {
    <#
    .SYNOPSIS
        Calculates the next semantic version number based on branch naming conventions and git history analysis.

    .DESCRIPTION
        This function implements semantic versioning (SemVer) logic for PowerShell modules by analyzing
        merged branches since the last release to determine the appropriate version bump type (major, minor, or patch).
        
        For first releases (no existing tags), the function uses a hybrid approach:
        - If PSD1 version is 0.0.0 or 1.0.0: Uses as base for version bump
        - If PSD1 version is unusual (e.g., 3.5.2): Returns structured guidance with actionable instructions
        - Analyzes git history since repository start to determine appropriate bump type
        
        The function follows these conventions:
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

    try {
        Write-SafeTaskSuccessLog -Message "Starting semantic version calculation"

        # Manifest-Handling ausgelagert
        $manifestResult = Get-ValidManifestPath -ManifestPath $ManifestPath
        if (-not $manifestResult.Success) {
            return New-VersionResultObject -Error $manifestResult.Error -Instructions "Please ensure that a valid manifest exists."
        }
        $ManifestPath = $manifestResult.Value
        $manifestContent = Get-Content $ManifestPath -Raw
        if ($manifestContent -match "ModuleVersion\s*=\s*['\`"]([^'\"]+)['\`"]") {
            $currentVersionString = $matches[1]
        }
        else {
            Write-SafeErrorLog -Message "Could not find ModuleVersion in manifest file"
            return New-VersionResultObject -Error "Could not find ModuleVersion in manifest file" -Instructions "Please check your manifest."
        }

        # Get latest release tag
        $latestTag = Get-LatestReleaseTag
        $isFirstRelease = $null -eq $latestTag

        # Konsistenzprüfung ausgelagert
        if (-not $isFirstRelease) {
            $consistencyResult = Test-PSD1TagConsistency -PSD1Version $currentVersionString -LatestTag $latestTag -ForceVersionMismatch:$ForceFirstRelease
            if ($consistencyResult.Error) {
                return $consistencyResult
            }
        }

        if ($isFirstRelease) {
            Write-SafeInfoLog -Message "No existing release tags found - this is a first release"
            $firstReleaseResult = Test-FirstReleaseVersion -CurrentVersion $currentVersionString -BranchName $BranchName -ForceFirstRelease:$ForceFirstRelease
            if ($firstReleaseResult.Error) {
                Write-SafeErrorLog -Message "First release error: $($firstReleaseResult.Error)"
                return New-VersionResultObject -CurrentVersion $currentVersionString -BumpType "none" -NewVersion $currentVersionString -IsFirstRelease $true -Error $firstReleaseResult.Error -Instructions $firstReleaseResult.Instructions
            }
            return New-VersionResultObject -CurrentVersion $currentVersionString -BumpType $firstReleaseResult.BumpType -NewVersion $firstReleaseResult.NewVersion -IsFirstRelease $true -GitContext $firstReleaseResult.GitContext
        }
        else {
            Write-SafeInfoLog -Message "Found existing release tag: $latestTag"
            $bumpType = Get-ReleaseVersionBumpType -LastReleaseTag $latestTag -TargetBranch $TargetBranch
            $branchBumpType = Get-VersionBumpType -BranchName $BranchName
            $finalBumpType = Get-HigherBumpType -BumpType1 $bumpType -BumpType2 $branchBumpType
            Write-SafeInfoLog -Message "Release-based bump: $bumpType, Branch-based bump: $branchBumpType, Final: $finalBumpType"
            $newVersion = Step-Version -Version $currentVersionString -BumpType $finalBumpType
            return New-VersionResultObject -CurrentVersion $currentVersionString -BumpType $finalBumpType -NewVersion $newVersion.ToString() -LastReleaseTag $latestTag -IsFirstRelease $false -GitContext @{ ReleaseBumpType = $bumpType; BranchBumpType = $branchBumpType }
        }
        # ...kein separates $result mehr, immer direkt return
    }
    catch {
        Write-SafeErrorLog -Message "Failed to calculate next semantic version" -Context $_.Exception.Message
        return New-VersionResultObject -Error $_.Exception.Message
    }
    try {
        Write-SafeTaskSuccessLog -Message "Starting semantic version calculation"

        # Manifest-Handling ausgelagert
        $manifestResult = Get-ValidManifestPath -ManifestPath $ManifestPath
        if (-not $manifestResult.Success) {
            return New-VersionResultObject -Error $manifestResult.Error -Instructions "Please ensure that a valid manifest exists."
        }
        $ManifestPath = $manifestResult.Value
        $manifestContent = Get-Content $ManifestPath -Raw
        if ($manifestContent -match "ModuleVersion\s*=\s*['\`"]([^'\`"]+)['\`"]") {
            $currentVersionString = $matches[1]
        }
        else {
            throw "Could not find ModuleVersion in manifest file"
        }

        # Get latest release tag
        $latestTag = Get-LatestReleaseTag
        $isFirstRelease = $null -eq $latestTag

        # NEU: Validierung bei existierenden Tags
        if (-not $isFirstRelease) {
            $consistencyResult = Test-PSD1TagConsistency -PSD1Version $currentVersionString -LatestTag $latestTag -ForceVersionMismatch:$ForceFirstRelease
            if ($consistencyResult.RequiresAction) {
                return New-VersionResultObject -CurrentVersion $currentVersionString -BumpType "none" -NewVersion $currentVersionString -LastReleaseTag $latestTag -IsFirstRelease $false -Error $consistencyResult.Error -Instructions $consistencyResult.Instructions -GitContext $consistencyResult.Context
            }
        }

        if ($isFirstRelease) {
            Write-SafeInfoLog -Message "No existing release tags found - this is a first release"

            $firstReleaseResult = Test-FirstReleaseVersion -CurrentVersion $currentVersionString -BranchName $BranchName -ForceFirstRelease:$ForceFirstRelease
            if ($firstReleaseResult.Error) {
                $result.Error = $firstReleaseResult.Error
                $result.Instructions = $firstReleaseResult.Instructions
                return $result
            }
            $result.BumpType = $firstReleaseResult.BumpType
            $result.NewVersion = $firstReleaseResult.NewVersion
            $result.GitContext = $firstReleaseResult.GitContext
        }
        else {
            Write-SafeInfoLog -Message "Found existing release tag: $latestTag"
            $bumpType = Get-ReleaseVersionBumpType -LastReleaseTag $latestTag -TargetBranch $TargetBranch
            $branchBumpType = Get-VersionBumpType -BranchName $BranchName
            $finalBumpType = Get-HigherBumpType -BumpType1 $bumpType -BumpType2 $branchBumpType
            Write-SafeInfoLog -Message "Release-based bump: $bumpType, Branch-based bump: $branchBumpType, Final: $finalBumpType"
            $newVersion = Step-Version -Version $currentVersionString -BumpType $finalBumpType
            $result.BumpType = $finalBumpType
            $result.NewVersion = $newVersion.ToString()
            $result.GitContext = @{
                ReleaseBumpType = $bumpType
                BranchBumpType  = $branchBumpType
            }
        }
        Write-SafeTaskSuccessLog -Message "Version calculation completed successfully" -Context "Current: $($result.CurrentVersion) → New: $($result.NewVersion) (Bump: $($result.BumpType))"
        return $result
    }
    catch {
        Write-SafeErrorLog -Message "Failed to calculate next semantic version" -Context $_.Exception.Message
        
    return New-VersionResultObject -CurrentVersion $currentVersionString -BumpType "none" -NewVersion $currentVersionString -LastReleaseTag $latestTag -IsFirstRelease $false -Error $_.Exception.Message
    }
}

function Test-FirstReleaseVersion {
    <#
    .SYNOPSIS
        Validates and calculates version for first releases with hybrid logic.
    
    .DESCRIPTION
        Handles first release scenarios by analyzing PSD1 version and git history.
        Provides structured guidance for unusual version numbers.
    
    .PARAMETER CurrentVersion
        The current version from the PSD1 manifest.
    
    .PARAMETER BranchName
        The current branch name for version bump calculation.
    
    .PARAMETER ForceFirstRelease
        Force first release even with unusual PSD1 version.
    
    .OUTPUTS
        PSCustomObject with BumpType, NewVersion, Error, Instructions, and GitContext.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        try {
            Write-SafeInfoLog -Message "Analyzing first release version: $CurrentVersion"
            # Parse version
            try {
                $version = [Version]::Parse($CurrentVersion)
            } catch {
                Write-SafeErrorLog -Message "Invalid version format in first release: $CurrentVersion"
                return New-VersionResultObject -BumpType "none" -NewVersion $CurrentVersion -Error "Invalid version format: $CurrentVersion"
            }
            # Check for standard starting versions
            $isStandardStart = ($version.ToString() -eq "0.0.0") -or ($version.ToString() -eq "1.0.0")
            if (-not $isStandardStart -and -not $ForceFirstRelease) {
                Write-SafeWarningLog -Message "Unusual PSD1 version detected for first release: $CurrentVersion"
                return New-VersionResultObject -BumpType "none" -NewVersion $CurrentVersion -Error "Unusual version for first release" -Instructions @{
                    Message         = "The PSD1 file contains an unusual version ($CurrentVersion) for a first release."
                    Recommendations = @(
                        "For new projects: Update PSD1 to ModuleVersion = '0.0.0' or '1.0.0'",
                        "For existing projects: Use -ForceFirstRelease to proceed with current version",
                        "For migrations: Consider if this should be tagged as v$CurrentVersion first"
                    )
                    NextSteps       = @(
                        "Option 1: Set ModuleVersion = '0.0.0' in PSD1, then re-run",
                        "Option 2: Use Get-NextSemanticVersion -ForceFirstRelease",
                        "Option 3: Manually tag current state: git tag v$CurrentVersion"
                    )
                }
            }
            # Analyze git history for appropriate bump type
            Write-SafeInfoLog -Message "Analyzing git history for version bump determination"
            $gitBumpType = "patch"  # Default
            try {
                # Get all commits in repository
                $commits = & git log --oneline --all 2>$null
                if ($LASTEXITCODE -eq 0 -and $commits) {
                    # Analyze commit messages for keywords
                    $commitText = $commits -join " "
                    if ($commitText -match "BREAKING|MAJOR|breaking change") {
                        $gitBumpType = "major"
                        Write-SafeInfoLog -Message "Found BREAKING/MAJOR indicators in git history"
                    }
                    elseif ($commitText -match "FEATURE|MINOR|feat:|feature:") {
                        $gitBumpType = "minor"
                        Write-SafeInfoLog -Message "Found FEATURE/MINOR indicators in git history"
                    }
                }
            }
            catch {
                Write-SafeWarningLog -Message "Could not analyze git history, using default patch bump"
            }
            # Also consider branch name
            $branchBumpType = Get-VersionBumpType -BranchName $BranchName
            $finalBumpType = Get-HigherBumpType -BumpType1 $gitBumpType -BumpType2 $branchBumpType
            Write-SafeInfoLog -Message "First release bump determination: Git=$gitBumpType, Branch=$branchBumpType, Final=$finalBumpType"
            # Calculate new version
            try {
                $newVersion = Step-Version -Version $CurrentVersion -BumpType $finalBumpType
            } catch {
                Write-SafeErrorLog -Message "Failed to step version in first release: $CurrentVersion"
                return New-VersionResultObject -BumpType "none" -NewVersion $CurrentVersion -Error "Failed to step version: $CurrentVersion"
            }
            return New-VersionResultObject -BumpType $finalBumpType -NewVersion $newVersion.ToString() -GitContext @{
                GitBumpType     = $gitBumpType
                BranchBumpType  = $branchBumpType
                IsStandardStart = $isStandardStart
                ForceUsed       = $ForceFirstRelease.IsPresent
            }
        }
        catch {
            Write-SafeErrorLog -Message "Failed to test first release version" -Context $_.Exception.Message
            return New-VersionResultObject -BumpType "none" -NewVersion $CurrentVersion -Error $_.Exception.Message
        }
        # Calculate new version
        $newVersion = Step-Version -Version $CurrentVersion -BumpType $finalBumpType
        
        return [PSCustomObject]@{
            BumpType     = $finalBumpType
            NewVersion   = $newVersion.ToString()
            Error        = $null
            Instructions = $null
            GitContext   = @{
                GitBumpType     = $gitBumpType
                BranchBumpType  = $branchBumpType
                IsStandardStart = $isStandardStart
                ForceUsed       = $ForceFirstRelease.IsPresent
            }
        }
    }
    catch {
        Write-SafeErrorLog -Message "Failed to test first release version" -Context $_.Exception.Message
        
    return New-VersionResultObject -BumpType "none" -NewVersion $CurrentVersion -Error $_.Exception.Message
    }
}

function Get-ReleaseVersionBumpType {
    <#
    .SYNOPSIS
        Determines version bump type by analyzing merged branches since last release.
    
    .DESCRIPTION
        Analyzes git commit history since the last release tag to determine the appropriate
        semantic version bump type based on branch names and commit messages.
    
    .PARAMETER LastReleaseTag
        The git tag of the last release.
    
    .PARAMETER TargetBranch
        The target branch to analyze (main/master). Auto-discovery if empty.
    
    .OUTPUTS
        String indicating the bump type: "major", "minor", or "patch".
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LastReleaseTag,
        
        [Parameter(Mandatory = $false)]
        [string]$TargetBranch = ""
    )
    
    try {
        Write-SafeDebugLog -Message "Analyzing changes since last release: $LastReleaseTag"
        
        # Auto-discover target branch if not provided
        if ([string]::IsNullOrEmpty($TargetBranch)) {
            $branches = & git branch -r 2>$null | Where-Object { $_ -match "(origin/main|origin/master)" }
            if ($branches) {
                $TargetBranch = ($branches[0] -replace ".*origin/", "").Trim()
            }
            else {
                $TargetBranch = "main"
            }
            Write-SafeInfoLog -Message "Auto-discovered target branch: $TargetBranch"
        }
        
        # Get commits since last release
        $commits = & git log "$LastReleaseTag..origin/$TargetBranch" --oneline --merges 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-SafeWarningLog -Message "Could not get commits since $LastReleaseTag, using branch analysis instead"
            return "patch"
        }
        
        if (-not $commits) {
            Write-SafeInfoLog -Message "No commits found since last release"
            return "patch"
        }
        
        Write-SafeInfoLog -Message "Analyzing $($commits.Count) commits since $LastReleaseTag"
        
        # Analyze commit messages and merge commit branch names
        $foundMajor = $false
        $foundMinor = $false
        
        foreach ($commit in $commits) {
            $commitMessage = $commit.ToLower()
            
            # Check for major version indicators
            if ($commitMessage -match "major/|breaking|major") {
                $foundMajor = $true
                Write-SafeInfoLog -Message "Found major version indicator in: $commit"
                break
            }
            
            # Check for minor version indicators
            if ($commitMessage -match "feature/|feat:|feature:|minor") {
                $foundMinor = $true
                Write-SafeInfoLog -Message "Found minor version indicator in: $commit"
            }
        }
        
        if ($foundMajor) {
            return "major"
        }
        elseif ($foundMinor) {
            return "minor"
        }
        else {
            return "patch"
        }
    }
    catch {
        Write-SafeErrorLog -Message "Failed to determine release version bump type" -Context $_.Exception.Message
        return "patch"
    }
}

function Get-VersionBumpType {
    <#
    .SYNOPSIS
        Determines version bump type based on branch naming conventions.
    
    .DESCRIPTION
        Analyzes branch name patterns to suggest appropriate semantic version bump type.
        Follows common Git branching conventions for determining version increments.
    
    .PARAMETER BranchName
        The name of the Git branch to analyze.
    
    .OUTPUTS
        String indicating the bump type: "major", "minor", or "patch".
    
    .EXAMPLE
        $bumpType = Get-VersionBumpType -BranchName "feature/new-api"
        # Returns: "minor"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$BranchName
    )
    
    Write-SafeDebugLog -Message "Analyzing branch name for version bump: $BranchName"
    
    switch -Regex ($BranchName.ToLower()) {
        '^major/.*' { 
            Write-SafeInfoLog -Message "Major branch pattern detected"
            return "major" 
        }
        '^feature/.*|^feat/.*' { 
            Write-SafeInfoLog -Message "Feature branch pattern detected"
            return "minor" 
        }
        '^bugfix/.*|^fix/.*|^hotfix/.*|^refactor/.*' { 
            Write-SafeInfoLog -Message "Bugfix/refactor branch pattern detected"
            return "patch" 
        }
        '^(main|master|develop)$' { 
            Write-SafeInfoLog -Message "Main branch detected - using patch as default"
            return "patch" 
        }
        default { 
            Write-SafeInfoLog -Message "Unknown branch pattern - defaulting to patch"
            return "patch" 
        }
    }
}

function Step-Version {
    <#
    .SYNOPSIS
        Increments a semantic version based on the specified bump type.
    
    .DESCRIPTION
        Takes a semantic version string and increments it according to the bump type.
        Follows semantic versioning rules for major, minor, and patch increments.
    
    .PARAMETER Version
        The current version string (e.g., "1.2.3").
    
    .PARAMETER BumpType
        The type of version bump: "major", "minor", or "patch".
    
    .OUTPUTS
        Version object representing the new version.
    
    .EXAMPLE
        $newVersion = Step-Version -Version "1.2.3" -BumpType "minor"
        # Returns: Version object for "1.3.0"
    #>
    [CmdletBinding()]
    [OutputType([Version])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("major", "minor", "patch")]
        [string]$BumpType
    )
    
    try {
        $currentVersion = [Version]::Parse($Version)
        Write-SafeDebugLog -Message "Stepping version $Version with $BumpType bump"
        
        switch ($BumpType) {
            "major" {
                $newVersion = [Version]::new($currentVersion.Major + 1, 0, 0)
                Write-SafeInfoLog -Message "Major version bump: $Version → $($newVersion.ToString())"
            }
            "minor" {
                $newVersion = [Version]::new($currentVersion.Major, $currentVersion.Minor + 1, 0)
                Write-SafeInfoLog -Message "Minor version bump: $Version → $($newVersion.ToString())"
            }
            "patch" {
                $newVersion = [Version]::new($currentVersion.Major, $currentVersion.Minor, $currentVersion.Build + 1)
                Write-SafeInfoLog -Message "Patch version bump: $Version → $($newVersion.ToString())"
            }
        }
        
        return $newVersion
    }
    catch {
        Write-SafeErrorLog -Message "Failed to step version" -Context $_.Exception.Message
        throw
    }
}

function Get-HigherBumpType {
    <#
    .SYNOPSIS
        Compares two bump types and returns the more significant one.
    
    .DESCRIPTION
        Helper function to determine which of two version bump types takes precedence.
        Major > Minor > Patch in terms of significance.
    
    .PARAMETER BumpType1
        First bump type to compare.
    
    .PARAMETER BumpType2
        Second bump type to compare.
    
    .OUTPUTS
        String indicating the higher priority bump type.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$BumpType1,
        
        [Parameter(Mandatory = $true)]
        [string]$BumpType2
    )
    
    $priority = @{
        "major" = 3
        "minor" = 2
        "patch" = 1
    }
    
    if ($priority[$BumpType1] -ge $priority[$BumpType2]) {
        return $BumpType1
    }
    else {
        return $BumpType2
    }
}
