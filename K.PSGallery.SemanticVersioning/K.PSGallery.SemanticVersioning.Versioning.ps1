function Handle-FirstRelease {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentVersion,
        [Parameter(Mandatory = $true)]
        [string]$BranchName,
        [Parameter(Mandatory = $false)]
        [switch]$ForceFirstRelease
    )
    $firstReleaseResult = Test-FirstReleaseVersion -CurrentVersion $CurrentVersion -BranchName $BranchName -ForceFirstRelease:$ForceFirstRelease
    if ($firstReleaseResult.Error) {
        Write-SafeErrorLog -Message "First release error: $($firstReleaseResult.Error)"
        return New-VersionResultObject -CurrentVersion $CurrentVersion -BumpType "none" -NewVersion $CurrentVersion -IsFirstRelease $true -Error $firstReleaseResult.Error -Instructions $firstReleaseResult.Instructions
    }
    return New-VersionResultObject -CurrentVersion $CurrentVersion -BumpType $firstReleaseResult.BumpType -NewVersion $firstReleaseResult.NewVersion -IsFirstRelease $true -GitContext $firstReleaseResult.GitContext
}

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
        [string]$LatestTag,
        [switch]$ForceVersionMismatch
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
    param(
        [Parameter(Mandatory = $false)]
        [string]$ManifestPath,
        
        [Parameter(Mandatory = $false)]
        [string]$BranchName = $env:GITHUB_REF_NAME,
        
        [Parameter(Mandatory = $false)]
        [string]$TargetBranch,
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceFirstRelease
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
            $consistencyResult = Test-PSD1TagConsistency -PSD1Version $currentVersionString -LatestTag $latestTag -ForceVersionMismatch:$ForceFirstRelease
            if ($consistencyResult.Error) {
                return New-VersionResultObject -CurrentVersion $currentVersionString -BumpType "none" -NewVersion $currentVersionString -LastReleaseTag $latestTag -IsFirstRelease $false -Error $consistencyResult.Error -Instructions $consistencyResult.Instructions -GitContext $consistencyResult.GitContext
            }
        }

        if ($isFirstRelease) {
            Write-SafeInfoLog -Message "No existing release tags found - this is a first release"

            $firstReleaseResult = Test-FirstReleaseVersion -CurrentVersion $currentVersionString -BranchName $BranchName -ForceFirstRelease:$ForceFirstRelease
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
            
            # Check for pre-release suffix requirements
            $suffixType = Get-PreReleaseSuffixType -BranchName $BranchName
            if ($suffixType) {
                Write-SafeInfoLog -Message "Pre-release suffix detected: $suffixType"
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
    
function Test-FirstReleaseVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CurrentVersion,

        [Parameter(Mandatory = $true)]
        [string]$BranchName,

        [Parameter(Mandatory = $false)]
        [switch]$ForceFirstRelease
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
    if (-not $isStandardStart -and -not $ForceFirstRelease) {
        Write-SafeWarningLog -Message "Unusual PSD1 version detected for first release: $CurrentVersion"
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
        return New-VersionResultObject @rv
    }

    Write-SafeInfoLog -Message "Analyzing git history for version bump determination"

    # Standardmäßig Patch-Bump annehmen
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

    # Neue Version berechnen
    try {
        $baseNewVersion = Step-Version -Version $CurrentVersion -BumpType $finalBumpType
        
        # Check for pre-release suffix requirements in first release
        $suffixType = Get-PreReleaseSuffixType -BranchName $BranchName
        if ($suffixType) {
            Write-SafeInfoLog -Message "First release with pre-release suffix: $suffixType"
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
                    ForceUsed       = $ForceFirstRelease.IsPresent
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
                    ForceUsed       = $ForceFirstRelease.IsPresent
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

function Get-PreReleaseSuffixConfig {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    
    return @{
        "alpha" = @{
            BranchPatterns = @("^alpha/.*", "^experimental/.*", "^poc/.*")
            Priority = 1
            Format = "alpha.{0}"
            Description = "Experimental or proof-of-concept features"
        }
        "beta" = @{
            BranchPatterns = @("^beta/.*", "^preview/.*", "^staging/.*")
            Priority = 2
            Format = "beta.{0}"
            Description = "Feature-complete but not production-ready"
        }
        "rc" = @{
            BranchPatterns = @("^rc/.*", "^release/.*", "^candidate/.*")
            Priority = 3
            Format = "rc.{0}"
            Description = "Release candidate - final testing phase"
        }
    }
}

function Get-PreReleaseSuffixType {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$BranchName
    )
    
    Write-SafeDebugLog -Message "Analyzing branch for pre-release suffix: $BranchName"
    
    $suffixConfig = Get-PreReleaseSuffixConfig
    $branchLower = $BranchName.ToLower()
    
    # Check each suffix type in priority order (lowest to highest)
    $matchedSuffix = $null
    $highestPriority = 0
    
    foreach ($suffixType in $suffixConfig.Keys) {
        $config = $suffixConfig[$suffixType]
        
        foreach ($pattern in $config.BranchPatterns) {
            if ($branchLower -match $pattern.ToLower()) {
                if ($config.Priority -gt $highestPriority) {
                    $matchedSuffix = $suffixType
                    $highestPriority = $config.Priority
                    Write-SafeInfoLog -Message "Found pre-release suffix '$suffixType' for pattern '$pattern'"
                }
            }
        }
    }
    
    if ($matchedSuffix) {
        Write-SafeInfoLog -Message "Selected pre-release suffix: $matchedSuffix (priority: $highestPriority)"
        return $matchedSuffix
    }
    
    Write-SafeDebugLog -Message "No pre-release suffix pattern matched for branch: $BranchName"
    return $null
}

function Add-PreReleaseSuffix {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $true)]
        [string]$SuffixType,
        
        [Parameter(Mandatory = $false)]
        [int]$BuildNumber = 1
    )
    
    Write-SafeDebugLog -Message "Adding pre-release suffix '$SuffixType' to version '$Version'"
    
    try {
        # Validate base version format
        $baseVersion = [Version]::Parse($Version)
        
        # Get suffix configuration
        $suffixConfig = Get-PreReleaseSuffixConfig
        if (-not $suffixConfig.ContainsKey($SuffixType)) {
            throw "Unknown suffix type: $SuffixType. Valid types: $($suffixConfig.Keys -join ', ')"
        }
        
        $config = $suffixConfig[$SuffixType]
        $suffixString = $config.Format -f $BuildNumber
        
        $newVersionString = "$($baseVersion.ToString())-$suffixString"
        
        Write-SafeInfoLog -Message "Applied pre-release suffix: $Version → $newVersionString"
        return $newVersionString
    }
    catch {
        Write-SafeErrorLog -Message "Failed to add pre-release suffix" -Context $_.Exception.Message
        throw
    }
}

function Test-PreReleaseSuffixFormat {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version
    )
    
    Write-SafeDebugLog -Message "Validating pre-release version format: $Version"
    
    # Pattern für SemVer Pre-Release: X.Y.Z-prerelease
    $semVerPreReleasePattern = '^(\d+)\.(\d+)\.(\d+)-([a-zA-Z0-9\-\.]+)$'
    
    if ($Version -match $semVerPreReleasePattern) {
        $baseVersion = "$($matches[1]).$($matches[2]).$($matches[3])"
        $preReleaseTag = $matches[4]
        
        try {
            # Validate base version part
            $null = [Version]::Parse($baseVersion)
            
            # Check if pre-release tag matches our supported formats
            $suffixConfig = Get-PreReleaseSuffixConfig
            $validSuffix = $false
            
            foreach ($suffixType in $suffixConfig.Keys) {
                $config = $suffixConfig[$suffixType]
                $expectedPattern = $config.Format -f '\d+'
                if ($preReleaseTag -match "^$($expectedPattern.Replace('{0}', '\d+'))$") {
                    $validSuffix = $true
                    break
                }
            }
            
            if ($validSuffix) {
                Write-SafeInfoLog -Message "Valid pre-release version format: $Version"
                return $true
            }
        }
        catch {
            Write-SafeWarningLog -Message "Invalid base version in pre-release: $baseVersion"
        }
    }
    
    Write-SafeWarningLog -Message "Invalid pre-release version format: $Version"
    return $false
}

function Get-NextBuildNumber {
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
        # Get existing tags with this suffix type
        $tags = & git tag -l 2>$null | Where-Object { 
            $_ -match "v?$BaseVersion.*-$SuffixType\.\d+" 
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

#endregion
