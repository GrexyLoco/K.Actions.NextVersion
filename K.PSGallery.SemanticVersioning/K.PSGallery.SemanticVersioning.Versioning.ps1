function Handle-FirstRelease {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentVersion,
        [Parameter(Mandatory = $true)]
        [string]$BranchName
    )
    $firstReleaseResult = Get-FirstSemanticVersion -CurrentVersion $CurrentVersion -BranchName $BranchName
    if ($firstReleaseResult.Error) {
        Write-SafeErrorLog -Message "First release error: $($firstReleaseResult.Error)"
        return New-VersionResultObject -CurrentVersion $CurrentVersion -BumpType "none" -NewVersion $CurrentVersion -IsFirstRelease $true -Error $firstReleaseResult.Error -Instructions $firstReleaseResult.Instructions
    }
    return New-VersionResultObject -CurrentVersion $CurrentVersion -BumpType $firstReleaseResult.BumpType -NewVersion $firstReleaseResult.NewVersion -IsFirstRelease $true -GitContext $firstReleaseResult.GitContext
}

function New-VersionResultObject {
    param(
        [Parameter(Mandatory = $false)]
        [string]$CurrentVersion = $null,

        [Parameter(Mandatory = $false)]
        [ValidateSet("major", "minor", "patch", "none")]
        [string]$BumpType = "none",

        [Parameter(Mandatory = $false)]
        [string]$NewVersion = $null,

        [Parameter(Mandatory = $false)]
        [string]$LastReleaseTag = $null,

        [Parameter(Mandatory = $false)]
        [object]$IsFirstRelease = $null,

        [Parameter(Mandatory = $false)]
        [string]$Error = $null,

        [Parameter(Mandatory = $false)]
        $Instructions = $null,

        [Parameter(Mandatory = $false)]
        $GitContext = @{},

        # GitHub Action compatibility properties
        [Parameter(Mandatory = $false)]
        [string]$TargetBranch = $null,

        [Parameter(Mandatory = $false)]
        [string]$Suffix = "",

        [Parameter(Mandatory = $false)]
        [string]$Warning = "",

        [Parameter(Mandatory = $false)]
        [bool]$ActionRequired = $false,

        [Parameter(Mandatory = $false)]
        [string]$ActionInstructions = ""
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
        # GitHub Action compatibility properties
        TargetBranch = $TargetBranch
        Suffix = $Suffix
        Warning = $Warning
        ActionRequired = $ActionRequired
        ActionInstructions = $ActionInstructions
    }
}

function New-SemVerErrorResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage,
        
        [Parameter(Mandatory = $false)]
        [string]$CurrentVersion = $null,
        
        [Parameter(Mandatory = $false)]
        $Instructions = $null,
        
        [Parameter(Mandatory = $false)]
        $GitContext = @{},
        
        [Parameter(Mandatory = $false)]
        [string]$TargetBranch = "main"
    )
    
    $actionInstructions = if ($Instructions -and $Instructions.Message) { 
        $Instructions.Message 
    } elseif ($Instructions -is [string]) { 
        $Instructions 
    } else { 
        "" 
    }
    
    return New-VersionResultObject -CurrentVersion $CurrentVersion -BumpType "none" -NewVersion $CurrentVersion -Error $ErrorMessage -Instructions $Instructions -GitContext $GitContext -TargetBranch $TargetBranch -Suffix "" -Warning $ErrorMessage -ActionRequired $true -ActionInstructions $actionInstructions
}

function New-SemVerSuccessResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$NewVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$BumpType,
        
        [Parameter(Mandatory = $false)]
        [string]$LastReleaseTag = $null,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsFirstRelease = $false,
        
        [Parameter(Mandatory = $false)]
        $GitContext = @{}
    )
    return New-VersionResultObject -CurrentVersion $CurrentVersion -BumpType $BumpType -NewVersion $NewVersion -LastReleaseTag $LastReleaseTag -IsFirstRelease $IsFirstRelease -GitContext $GitContext
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

function Test-PSD1TagConsistency {
    param (
        [string]$PSD1Version,
        [string]$LatestTag
    )
    if ([string]::IsNullOrEmpty($LatestTag)) {
        return New-VersionResultObject -CurrentVersion $PSD1Version -LastReleaseTag $LatestTag -Error $null -Instructions $null -GitContext @{ Consistency = "No tag found" }
    }
    try {
        $psd1Ver = [Version]::Parse($PSD1Version)
        $tagVer = [Version]::Parse(($LatestTag -replace '^v', ''))
    }
    catch {
        return New-VersionResultObject -CurrentVersion $PSD1Version -LastReleaseTag $LatestTag -Error "Invalid version format in PSD1 or tag." -Instructions "Check ModuleVersion and tag format." -GitContext @{ PSD1Version = $PSD1Version; LatestTag = $LatestTag }
    }
    if ($psd1Ver -lt $tagVer) {
        return New-VersionResultObject -CurrentVersion $PSD1Version -LastReleaseTag $LatestTag -Error "PSD1 version ($PSD1Version) is older than the latest tag ($LatestTag)." -Instructions @{
            Message  = "Please synchronize the versions."
            Options = @(
                "Option 1: Set ModuleVersion in PSD1 to $LatestTag",
                "Option 2: Delete/modify tags if intended"
            )
        } -GitContext @{ PSD1Version = $PSD1Version; LatestTag = $LatestTag }
    }
    if ($psd1Ver -gt $tagVer) {
        return New-VersionResultObject -CurrentVersion $PSD1Version -LastReleaseTag $LatestTag -Error "PSD1 version ($PSD1Version) is higher than the latest tag ($LatestTag)." -Instructions @{
            Message  = "Large version jump detected. Check if this is intended."
            Options = @(
                "Option 1: Set ModuleVersion to $LatestTag for sequential releases"
            )
        } -GitContext @{ PSD1Version = $PSD1Version; LatestTag = $LatestTag }
    }
    if ($psd1Ver -eq $tagVer) {
        # Warning if PSD1 version identical to tag (avoid duplicate releases)
        return New-VersionResultObject -CurrentVersion $PSD1Version -LastReleaseTag $LatestTag -Error $null -Instructions $null -GitContext @{ Consistency = "PSD1 version and tag identical" }
    }
    return New-VersionResultObject -CurrentVersion $PSD1Version -LastReleaseTag $LatestTag -Error $null -Instructions $null -GitContext @{ Consistency = "No action required" }
}

function Get-NextSemanticVersion {
    <#
    .SYNOPSIS
        Calculates the next semantic version for a PowerShell module based on Git analysis.
    
    .DESCRIPTION
        This is the main function that analyzes Git repository history, branch patterns, 
        commit messages, and PowerShell module manifest to determine the next semantic version.
        
        The function supports:
        - First release detection and validation
        - Branch-based version bumping (feature/, bugfix/, major/)
        - Commit message keyword analysis (BREAKING, FEATURE, PATCH, etc.)
        - Prerelease version generation (alpha, beta) from commit keywords
        - PSD1 manifest auto-discovery and validation
        - Version consistency checking between manifest and Git tags
    
    .PARAMETER ManifestPath
        Path to the PowerShell module manifest (.psd1) file.
        If not specified, the function will auto-discover the manifest in the current directory.
        
    .PARAMETER BranchName
        Current Git branch name for branch-based version analysis.
        If not specified, uses $env:GITHUB_REF_NAME from GitHub Actions environment.
        
    .PARAMETER TargetBranch
        Target branch for analyzing commits (usually main/master).
        If not specified, auto-discovers from Git remote branches.
    
    .OUTPUTS
        PSCustomObject with the following properties:
        - CurrentVersion: Version from the manifest file
        - BumpType: Type of version bump (major, minor, patch, none)
        - NewVersion: Calculated new version (may include prerelease suffix)
        - LastReleaseTag: Latest Git release tag found
        - IsFirstRelease: Boolean indicating if this is a first release
        - Error: Error message if calculation fails
        - Instructions: Detailed guidance for resolving issues
        - GitContext: Analysis details and metadata
        - TargetBranch: Branch used for analysis
        - Suffix: Prerelease suffix (alpha, beta) if applicable
        - Warning: Warning message if issues detected
        - ActionRequired: Boolean indicating if user action is needed
        - ActionInstructions: Human-readable instructions for next steps
    
    .EXAMPLE
        $result = Get-NextSemanticVersion
        Write-Host "Next version: $($result.NewVersion)"
        
        Analyzes the current repository and calculates the next semantic version.
    
    .EXAMPLE
        $result = Get-NextSemanticVersion -ManifestPath ".\MyModule.psd1" -BranchName "feature/new-api"
        
        Analyzes a specific manifest and branch for version calculation.
    
    .NOTES
        This function requires:
        - Git CLI available in PATH
        - PowerShell module manifest (.psd1) file
        - K.PSGallery.LoggingModule for enhanced logging
        
        Prerelease versions are detected from commit messages with keywords like:
        FEAT-ALPHA, FIX-BETA, BREAKING-ALPHA, etc.
        
        Version bumping priority: Commit keywords > Branch patterns > Default (patch)
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$ManifestPath,
        
        [Parameter(Mandatory = $false)]
        [string]$BranchName = $env:GITHUB_REF_NAME,
        
        [Parameter(Mandatory = $false)]
        [string]$TargetBranch
    )
    
    try {
        Write-SafeTaskSuccessLog -Message "Starting semantic version calculation"

        # Manifest-Handling ausgelagert
        $manifestResult = Get-ValidManifestPath -ManifestPath $ManifestPath
        if (-not $manifestResult.Success) {
            $targetBranchForError = if ([string]::IsNullOrEmpty($TargetBranch)) { "main" } else { $TargetBranch }
            return New-SemVerErrorResult -ErrorMessage $manifestResult.Error -Instructions "Please ensure that a valid manifest exists." -TargetBranch $targetBranchForError
        }
        $ManifestPath = $manifestResult.Value
        $manifestContent = Get-Content $ManifestPath -Raw
        if ($manifestContent -match 'ModuleVersion\s*=\s*[''`"]([^''`"]+)[''`"]') {
            $currentVersionString = $matches[1]
        }
        else {
            throw "Could not find ModuleVersion in manifest file"
        }

        # Initialize result object
        $result = New-VersionResultObject -CurrentVersion $currentVersionString -LastReleaseTag $null -IsFirstRelease $false

        # Get latest release tag
        $latestTag = Get-LatestReleaseTag
        $isFirstRelease = $null -eq $latestTag

        # NEU: Validierung bei existierenden Tags
        if (-not $isFirstRelease) {
            $consistencyResult = Test-PSD1TagConsistency -PSD1Version $currentVersionString -LatestTag $latestTag
            if ($consistencyResult.Error) {
                return New-VersionResultObject -CurrentVersion $currentVersionString -BumpType "none" -NewVersion $currentVersionString -LastReleaseTag $latestTag -IsFirstRelease $false -Error $consistencyResult.Error -Instructions $consistencyResult.Instructions -GitContext $consistencyResult.GitContext
            }
        }

        if ($isFirstRelease) {
            Write-SafeInfoLog -Message "No existing release tags found - this is a first release"

            $firstReleaseResult = Get-FirstSemanticVersion -CurrentVersion $currentVersionString -BranchName $BranchName
            if ($firstReleaseResult.Error) {
                $targetBranchForError = if ([string]::IsNullOrEmpty($TargetBranch)) { "main" } else { $TargetBranch }
                return New-SemVerErrorResult -ErrorMessage $firstReleaseResult.Error -CurrentVersion $currentVersionString -Instructions $firstReleaseResult.Instructions -TargetBranch $targetBranchForError
            }
            $result.BumpType = $firstReleaseResult.BumpType
            $result.NewVersion = $firstReleaseResult.NewVersion
            $result.IsFirstRelease = $true
            $result.GitContext = $firstReleaseResult.GitContext
        }
        else {
            Write-SafeInfoLog -Message "Found existing release tag: $latestTag"
            $bumpType = Get-ReleaseVersionBumpType -LastReleaseTag $latestTag -TargetBranch $TargetBranch
            $branchBumpType = Get-VersionBumpType -BranchName $BranchName
            $finalBumpType = Get-HigherBumpType -BumpType1 $bumpType -BumpType2 $branchBumpType
            Write-SafeInfoLog -Message "Release-based bump: $bumpType, Branch-based bump: $branchBumpType, Final: $finalBumpType"
            
            # Calculate base version without suffix
            $baseNewVersion = Step-Version -Version $currentVersionString -BumpType $finalBumpType
            
            # Check for pre-release suffix requirements from commit messages
            $suffixType = Get-PreReleaseSuffixFromCommits -LastReleaseTag $latestTag -TargetBranch $TargetBranch
            if ($suffixType) {
                Write-SafeInfoLog -Message "Pre-release suffix detected from commits: $suffixType"
                $buildNumber = Get-NextBuildNumber -SuffixType $suffixType -BaseVersion $baseNewVersion.ToString()
                $finalVersion = Add-PreReleaseSuffix -Version $baseNewVersion.ToString() -SuffixType $suffixType -BuildNumber $buildNumber
                
                $result.BumpType = $finalBumpType
                $result.NewVersion = $finalVersion
                $result.LastReleaseTag = $latestTag
                $result.GitContext = @{
                    ReleaseBumpType = $bumpType
                    BranchBumpType  = $branchBumpType
                    PreReleaseSuffix = $suffixType
                    BuildNumber = $buildNumber
                    BaseVersion = $baseNewVersion.ToString()
                }
            }
            else {
                # Standard release without suffix
                $result.BumpType = $finalBumpType
                $result.NewVersion = $baseNewVersion.ToString()
                $result.LastReleaseTag = $latestTag
                $result.GitContext = @{
                    ReleaseBumpType = $bumpType
                    BranchBumpType  = $branchBumpType
                }
            }
        }
        
        # Set GitHub Action compatibility properties
        $result.TargetBranch = if ([string]::IsNullOrEmpty($TargetBranch)) { 
            if ($BranchName -eq "main" -or $BranchName -eq "master") { $BranchName } else { "main" }
        } else { $TargetBranch }
        
        $result.Suffix = if ($result.GitContext.PreReleaseSuffix) { $result.GitContext.PreReleaseSuffix } else { "" }
        
        $result.Warning = if ($result.Error) { $result.Error } else { "" }
        
        $result.ActionRequired = if ($result.Error -and $result.Instructions) { $true } else { $false }
        
        $result.ActionInstructions = if ($result.Instructions -and $result.Instructions.Message) { 
            $result.Instructions.Message 
        } elseif ($result.Instructions -is [string]) { 
            $result.Instructions 
        } else { 
            "" 
        }
        
        Write-SafeTaskSuccessLog -Message "Version calculation completed successfully" -Context "Current: $($result.CurrentVersion) → New: $($result.NewVersion) (Bump: $($result.BumpType))"
        return $result
    }
    catch {
        Write-SafeErrorLog -Message "Failed to calculate next semantic version" -Context $_.Exception.Message
        
        $targetBranchForError = if ([string]::IsNullOrEmpty($TargetBranch)) { "main" } else { $TargetBranch }
        return New-SemVerErrorResult -ErrorMessage $_.Exception.Message -CurrentVersion $currentVersionString -TargetBranch $targetBranchForError
    }
}
    
function Get-FirstSemanticVersion {
    <#
    .SYNOPSIS
        Calculates the first semantic version for a repository without existing Git tags.
    
    .DESCRIPTION
        This function is used when a repository has no Git tags yet (first release scenario).
        It analyzes the entire Git history and PSD1 manifest version to determine the 
        appropriate first release version. It validates standard starting versions 
        (0.0.0, 1.0.0) and provides guidance for unusual versions.
    
    .PARAMETER CurrentVersion
        The current version from the PowerShell module manifest (.psd1 file).
        Should typically be 0.0.0 or 1.0.0 for new projects.
    
    .PARAMETER BranchName
        The current Git branch name used for branch-based version bump analysis.
        Supports patterns like feature/, bugfix/, major/, etc.
    
    .OUTPUTS
        PSCustomObject with properties:
        - CurrentVersion: Original version from manifest
        - BumpType: Calculated version bump (major, minor, patch)
        - NewVersion: Calculated first release version
        - IsFirstRelease: Always $true for this function
        - Error: Error message if validation fails
        - Instructions: Detailed guidance for resolving issues
        - GitContext: Analysis details (git bump type, branch bump type, etc.)
    
    .EXAMPLE
        Get-FirstSemanticVersion -CurrentVersion "1.0.0" -BranchName "main"
        
        Analyzes a standard first release starting from version 1.0.0.
    
    .EXAMPLE
        Get-FirstSemanticVersion -CurrentVersion "0.0.0" -BranchName "feature/new-api"
        
        Analyzes a first release with feature branch patterns.
    
    .NOTES
        This function is automatically called by Get-NextSemanticVersion when no Git tags exist.
        It performs complete repository history analysis to determine the appropriate bump type.
        
        Standard starting versions (0.0.0, 1.0.0) are processed automatically.
        Unusual versions will trigger validation warnings with guidance.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentVersion,

        [Parameter(Mandatory = $true)]
        [string]$BranchName
    )

    Write-SafeInfoLog -Message "Analyzing first release version: $CurrentVersion"

    try {
        $version = [Version]::Parse($CurrentVersion)
    }
    catch {
        Write-SafeErrorLog -Message "Invalid version format in first release: $CurrentVersion"
        $rv = @{
            CurrentVersion = $CurrentVersion
            BumpType       = "none"
            NewVersion     = $CurrentVersion
            IsFirstRelease = $true
            Error          = "Invalid version format: $CurrentVersion"
        }
        return New-VersionResultObject @rv
    }

    # Standard-Versionen 0.0.0 oder 1.0.0 erlauben
    $isStandardStart = ($version.ToString() -eq "0.0.0") -or ($version.ToString() -eq "1.0.0")
    if (-not $isStandardStart) {
        Write-SafeWarningLog -Message "Unusual PSD1 version detected for first release: $CurrentVersion"
        
        # Create mismatch record for potential force-release
        try {
            $mismatchRecord = Set-MismatchRecord -Version $CurrentVersion -BranchName $BranchName
            Write-SafeInfoLog -Message "Mismatch record created: $($mismatchRecord.RecordId)"
            
            # Send notifications
            $mismatchInfo = [PSCustomObject]@{
                Version = $CurrentVersion
                BranchName = $BranchName
                Reason = "Unusual version for first release"
                RecordId = $mismatchRecord.RecordId
                ExpiresAt = $mismatchRecord.ExpiresAt
            }
            
            $notificationResult = Send-MismatchNotification -MismatchInfo $mismatchInfo -NotificationChannels @("console", "summary")
            Write-SafeDebugLog -Message "Notifications sent: $($notificationResult.SuccessfulChannels) successful, $($notificationResult.FailedChannels) failed"
        }
        catch {
            Write-SafeErrorLog -Message "Failed to create mismatch record" -Context $_.Exception.Message
        }
        
        $rv = @{
            CurrentVersion = $CurrentVersion
            BumpType       = "none"
            NewVersion     = $CurrentVersion
            IsFirstRelease = $true
            Error          = "Unusual version for first release"
            Instructions   = @{
                Message         = "The PSD1 file contains an unusual version ($CurrentVersion) for a first release."
                Recommendations = @(
                    "For new projects: Update PSD1 to ModuleVersion = '0.0.0' or '1.0.0'",
                    "For existing projects: Consider if this version is correct for first release",
                    "For migrations: Consider if this should be tagged as v$CurrentVersion first"
                )
                NextSteps       = @(
                    "Option 1: Set ModuleVersion = '0.0.0' in PSD1, then re-run",
                    "Option 2: Set ModuleVersion = '1.0.0' in PSD1, then re-run",
                    "Option 3: Use 'Force Version Release' workflow in GitHub Actions"
                )
            }
        }
        return New-VersionResultObject @rv
    }

    Write-SafeInfoLog -Message "Analyzing git history for version bump determination"

    # Default to patch bump
    $gitBumpType = "patch"
    try {
        # Alle Commits holen
        $commits = & git log --oneline --all 2>$null
        if ($LASTEXITCODE -eq 0 -and $commits) {
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

    # Branchname berücksichtigen
    $branchBumpType = Get-VersionBumpType -BranchName $BranchName
    $finalBumpType = Get-HigherBumpType -BumpType1 $gitBumpType -BumpType2 $branchBumpType

    Write-SafeInfoLog -Message "First release bump determination: Git=$gitBumpType, Branch=$branchBumpType, Final=$finalBumpType"

    # Calculate new version
    try {
        $baseNewVersion = Step-Version -Version $CurrentVersion -BumpType $finalBumpType
        
        # Check for pre-release suffix requirements from commit messages in first release
        $suffixType = Get-PreReleaseSuffixFromCommits -LastReleaseTag $null -TargetBranch "main"
        if ($suffixType) {
            Write-SafeInfoLog -Message "First release with pre-release suffix from commits: $suffixType"
            $buildNumber = 1  # First release always starts with build 1
            $finalVersion = Add-PreReleaseSuffix -Version $baseNewVersion.ToString() -SuffixType $suffixType -BuildNumber $buildNumber
            
            # Erfolgreiches Ergebnis mit Suffix zurückgeben
            $rv = @{
                CurrentVersion = $CurrentVersion
                BumpType       = $finalBumpType
                NewVersion     = $finalVersion
                IsFirstRelease = $true
                Error          = $null
                Instructions   = $null
                GitContext     = @{
                    GitBumpType     = $gitBumpType
                    BranchBumpType  = $branchBumpType
                    IsStandardStart = $isStandardStart
                    PreReleaseSuffix = $suffixType
                    BuildNumber = $buildNumber
                    BaseVersion = $baseNewVersion.ToString()
                }
            }
        }
        else {
            # Standard first release without suffix
            $rv = @{
                CurrentVersion = $CurrentVersion
                BumpType       = $finalBumpType
                NewVersion     = $baseNewVersion.ToString()
                IsFirstRelease = $true
                Error          = $null
                Instructions   = $null
                GitContext     = @{
                    GitBumpType     = $gitBumpType
                    BranchBumpType  = $branchBumpType
                    IsStandardStart = $isStandardStart
                }
            }
        }
    }
    catch {
        Write-SafeErrorLog -Message "Failed to step version in first release: $CurrentVersion"
        $rv = @{
            CurrentVersion = $CurrentVersion
            BumpType       = "none"
            NewVersion     = $CurrentVersion
            IsFirstRelease = $true
            Error          = "Failed to step version: $CurrentVersion"
        }
        return New-VersionResultObject @rv
    }

    return New-VersionResultObject @rv
}

function Get-ReleaseVersionBumpType {
    <#
    .SYNOPSIS
        Analyzes Git commits since the last release to determine version bump type.
    
    .DESCRIPTION
        This function examines Git commit history between the last release tag and the current
        branch to determine what type of semantic version bump is required. It analyzes
        commit messages and merge commit branch names for version bump indicators.
        
        The function looks for keywords like:
        - Major: "breaking", "major" (without prerelease suffixes)
        - Minor: "feature", "feat:", "minor" (without prerelease suffixes)
        - Patch: Default for all other commits
    
    .PARAMETER LastReleaseTag
        The Git tag representing the last release (e.g., "v1.2.3").
        Used as the starting point for commit analysis.
    
    .PARAMETER TargetBranch
        The target branch to analyze commits against (usually main/master).
        If empty, the function auto-discovers the appropriate branch.
    
    .OUTPUTS
        String representing the version bump type: "major", "minor", or "patch"
    
    .EXAMPLE
        $bumpType = Get-ReleaseVersionBumpType -LastReleaseTag "v1.2.3" -TargetBranch "main"
        
        Analyzes commits between v1.2.3 and main branch.
    
    .NOTES
        This function excludes commits with prerelease suffixes (-alpha, -beta) from
        normal version bump analysis, as those are handled separately.
        
        Requires Git CLI and appropriate repository access.
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
            
            # Check for major version indicators (without prerelease suffixes)
            if ($commitMessage -match "(major/|breaking|major)(?!-alpha|!-beta)") {
                $foundMajor = $true
                Write-SafeInfoLog -Message "Found major version indicator in: $commit"
                break
            }
            
            # Check for minor version indicators (without prerelease suffixes)
            if ($commitMessage -match "(feature/|feat:|feature:|minor)(?!-alpha|!-beta)") {
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
        Determines version bump type based on Git branch naming patterns.
    
    .DESCRIPTION
        Analyzes the current Git branch name to suggest an appropriate semantic version bump.
        This function supports common Git flow branch naming conventions and provides
        fallback logic for unknown patterns.
        
        Supported branch patterns:
        - major/*: Major version bump (breaking changes)
        - feature/*, feat/*: Minor version bump (new features)
        - bugfix/*, fix/*, hotfix/*, refactor/*: Patch version bump
        - main, master, develop: Patch version bump (default)
    
    .PARAMETER BranchName
        The Git branch name to analyze for version bump patterns.
        Should follow standard Git flow naming conventions.
    
    .OUTPUTS
        String representing the suggested version bump: "major", "minor", or "patch"
    
    .EXAMPLE
        $bumpType = Get-VersionBumpType -BranchName "feature/user-authentication"
        # Returns: "minor"
        
    .EXAMPLE
        $bumpType = Get-VersionBumpType -BranchName "bugfix/login-error"
        # Returns: "patch"
    
    .NOTES
        This function provides branch-based suggestions that can be overridden by
        commit message keywords or other analysis methods.
        
        Unknown branch patterns default to "patch" bump for safety.
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

#region PreRelease Suffix Management

function Get-PreReleaseSuffixFromCommits {
    <#
    .SYNOPSIS
        Analyzes commit messages for prerelease keywords (e.g., feat-alpha, fix-beta)
    
    .DESCRIPTION
        Scans commit history for keywords like BREAKING-ALPHA, FEATURE-BETA, etc.
        and returns the prerelease suffix type if found.
    
    .PARAMETER LastReleaseTag
        The last release tag to analyze commits from (optional for first releases)
    
    .PARAMETER TargetBranch
        The target branch to analyze (defaults to main/master)
    
    .OUTPUTS
        String representing the prerelease suffix type ("alpha", "beta") or $null
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $false)]
        [string]$LastReleaseTag = $null,
        
        [Parameter(Mandatory = $false)]
        [string]$TargetBranch = "main"
    )
    
    try {
        Write-SafeDebugLog -Message "Analyzing commits for prerelease keywords"
        
        # Get commits to analyze
        if ([string]::IsNullOrEmpty($LastReleaseTag)) {
            # First release - analyze all commits
            $commits = & git log --oneline --all 2>$null
            Write-SafeInfoLog -Message "Analyzing all commits for first release prerelease detection"
        } else {
            # Subsequent release - analyze commits since last tag
            $commits = & git log "$LastReleaseTag..HEAD" --oneline 2>$null
            Write-SafeInfoLog -Message "Analyzing commits since $LastReleaseTag for prerelease detection"
        }
        
        if ($LASTEXITCODE -ne 0 -or -not $commits) {
            Write-SafeInfoLog -Message "No commits found for prerelease analysis"
            return $null
        }
        
        Write-SafeInfoLog -Message "Analyzing $($commits.Count) commits for prerelease keywords"
        
        # Look for prerelease keywords in commit messages
        $prereleasePattern = '(BREAKING|MAJOR|FEATURE|MINOR|FEAT|PATCH|FIX|BUGFIX|HOTFIX)-(ALPHA|BETA)'
        
        $foundSuffixes = @()
        foreach ($commit in $commits) {
            $commitMessage = $commit.ToUpper()
            
            if ($commitMessage -match $prereleasePattern) {
                $suffixType = $matches[2].ToLower()
                Write-SafeInfoLog -Message "Found prerelease keyword '$($matches[1])-$($matches[2])' in commit: $commit"
                $foundSuffixes += $suffixType
            }
        }
        
        # Priority logic: beta > alpha (beta is more mature)
        if ($foundSuffixes -contains "beta") {
            Write-SafeInfoLog -Message "Multiple prerelease suffixes found, selecting 'beta' (higher priority)"
            return "beta"
        } elseif ($foundSuffixes -contains "alpha") {
            Write-SafeInfoLog -Message "Alpha prerelease suffix selected"
            return "alpha"
        }
        
        Write-SafeDebugLog -Message "No prerelease keywords found in commit messages"
        return $null
    }
    catch {
        Write-SafeErrorLog -Message "Failed to analyze commits for prerelease keywords" -Context $_.Exception.Message
        return $null
    }
}

function Get-NextBuildNumber {
    <#
    .SYNOPSIS
        Determines the next build number for a prerelease version
    
    .DESCRIPTION
        Analyzes existing Git tags to find the highest build number for a specific
        prerelease suffix type and base version, then returns the next number.
    
    .PARAMETER SuffixType
        The prerelease suffix type (alpha, beta)
    
    .PARAMETER BaseVersion
        The base version to search for existing prerelease tags
    
    .OUTPUTS
        Integer representing the next build number
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SuffixType,
        
        [Parameter(Mandatory = $false)]
        [string]$BaseVersion = $null
    )
    
    Write-SafeDebugLog -Message "Determining next build number for suffix type: $SuffixType"
    
    try {
        # Get existing tags with this suffix type and base version
        $tagPattern = if ($BaseVersion) {
            "v?$BaseVersion-$SuffixType\.\d+"
        } else {
            "-$SuffixType\.\d+"
        }
        
        $tags = & git tag -l 2>$null | Where-Object { 
            $_ -match $tagPattern
        }
        
        if (-not $tags) {
            Write-SafeInfoLog -Message "No existing tags found for suffix '$SuffixType', starting with build 1"
            return [int]1
        }
        
        # Extract build numbers and find the highest
        $buildNumbers = $tags | ForEach-Object {
            if ($_ -match "$SuffixType\.(\d+)") {
                [int]$matches[1]
            }
        } | Where-Object { $_ -ne $null }
        
        if ($buildNumbers) {
            $maxBuild = ($buildNumbers | Measure-Object -Maximum).Maximum
            $nextBuild = [int]($maxBuild + 1)
            Write-SafeInfoLog -Message "Found existing builds for '$SuffixType': max=$maxBuild, next=$nextBuild"
            return [int]$nextBuild
        }
        
        return [int]1
    }
    catch {
        Write-SafeWarningLog -Message "Could not determine build number, defaulting to 1: $($_.Exception.Message)"
        return [int]1
    }
}

function Add-PreReleaseSuffix {
    <#
    .SYNOPSIS
        Adds a prerelease suffix to a semantic version
    
    .DESCRIPTION
        Takes a base semantic version and adds a prerelease suffix with build number
        following the pattern: version-suffix.buildnumber (e.g., 1.2.3-alpha.1)
    
    .PARAMETER Version
        The base semantic version string
    
    .PARAMETER SuffixType
        The prerelease suffix type (alpha, beta)
    
    .PARAMETER BuildNumber
        The build number for the prerelease
    
    .OUTPUTS
        String representing the prerelease version
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("alpha", "beta")]
        [string]$SuffixType,
        
        [Parameter(Mandatory = $false)]
        [int]$BuildNumber = 1
    )
    
    Write-SafeDebugLog -Message "Adding pre-release suffix '$SuffixType' to version '$Version'"
    
    try {
        # Validate base version format
        $baseVersion = [Version]::Parse($Version)
        
        # Create prerelease version string
        $newVersionString = "$($baseVersion.ToString())-$SuffixType.$BuildNumber"
        
        Write-SafeInfoLog -Message "Applied pre-release suffix: $Version → $newVersionString"
        return $newVersionString
    }
    catch {
        Write-SafeErrorLog -Message "Failed to add pre-release suffix" -Context $_.Exception.Message
        throw
    }
}

#endregion
