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
    - ActionRequired: Whether manual action is required (true/false)
    - ActionInstructions: Detailed instructions for required manual action

.EXAMPLE
    Get-NextSemanticVersion
    
    Uses default parameters to find manifest and determine version from current environment.

.EXAMPLE
    Get-NextSemanticVersion -ManifestPath "C:\MyModule\MyModule.psd1" -BranchName "feature/new-logging"
    
    Explicitly specifies manifest path and branch for a feature branch.

.EXAMPLE
    Get-NextSemanticVersion -ForceFirstRelease
    
    Forces first release even if PSD1 has unusual version (e.g., when migrating existing project).

.NOTES
    Module: K.PSGallery.SemanticVersioning
    Author: K.PSGallery
    Version: 1.0.0
    
    This function follows semantic versioning principles as defined at https://semver.org/
    
    The function assumes the current version in the manifest follows the format "X.Y.Z"
    where X, Y, and Z are non-negative integers.

.LINK
    https://semver.org/
    
.LINK
    https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-output-parameter
#>
function Get-NextSemanticVersion {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
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

    try {
        # Auto-discover target branch if not specified
        if ([string]::IsNullOrWhiteSpace($TargetBranch)) {
            $TargetBranch = Get-TargetBranch
            Write-Verbose "Auto-discovered target branch: '$TargetBranch'"
        }
        
        # Verify we're analyzing the target branch
        if ($BranchName -ne $TargetBranch) {
            Write-Verbose "Current branch '$BranchName' is not the target branch '$TargetBranch'"
            Write-SafeInfoLog -Message "Not on target branch '$TargetBranch', no version bump needed"
            
            return [PSCustomObject]@{
                CurrentVersion = "0.0.0"
                BumpType = "none"
                NewVersion = "0.0.0"
                LastReleaseTag = ""
                TargetBranch = $TargetBranch
                Suffix = ""
                Warning = "Not on target branch for release"
                ActionRequired = $false
                ActionInstructions = ""
                Error = ""
            }
        }

        # Auto-discover manifest file if not provided
        if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
            Write-Verbose "No manifest path provided, attempting auto-discovery..."
            $manifestFiles = Get-ChildItem -Recurse -Filter "*.psd1" -ErrorAction SilentlyContinue
            
            if ($manifestFiles.Count -eq 0) {
                Write-SafeWarningLog -Message "No PowerShell manifest files (.psd1) found in current directory or subdirectories. Please specify -ManifestPath parameter."
                return [PSCustomObject]@{
                    CurrentVersion = ""
                    BumpType = "none"
                    NewVersion = ""
                    LastReleaseTag = ""
                    TargetBranch = $TargetBranch
                    Suffix = ""
                    Warning = ""
                    ActionRequired = $false
                    ActionInstructions = ""
                    Error = "No PowerShell manifest files (.psd1) found in current directory or subdirectories. Please specify -ManifestPath parameter."
                }
            }
            
            if ($manifestFiles.Count -gt 1) {
                Write-SafeWarningLog -Message "Multiple .psd1 files found. Using first one: $($manifestFiles[0].FullName)" -Context "Available manifests: $($manifestFiles.FullName -join ', ')"
            }
            
            $ManifestPath = $manifestFiles[0].FullName
            Write-Verbose "Auto-discovered manifest: $ManifestPath"
        }
        
        # Validate that the manifest file exists and is accessible
        if (-not (Test-Path -Path $ManifestPath -PathType Leaf)) {
            Write-SafeWarningLog -Message "PowerShell manifest file not found at path: $ManifestPath"
            return [PSCustomObject]@{
                CurrentVersion = ""
                BumpType = "none"
                NewVersion = ""
                LastReleaseTag = ""
                TargetBranch = $TargetBranch
                Suffix = ""
                Warning = ""
                ActionRequired = $false
                ActionInstructions = ""
                Error = "PowerShell manifest file not found at path: $ManifestPath"
            }
        }
        
        Write-Verbose "Loading PowerShell manifest from: $ManifestPath"
        
        # Import the module manifest to extract current version information
        $manifest = Import-PowerShellDataFile -Path $ManifestPath
        
        if (-not $manifest.ModuleVersion) {
            Write-SafeWarningLog -Message "ModuleVersion not found in manifest file: $ManifestPath"
            return [PSCustomObject]@{
                CurrentVersion = ""
                BumpType = "none"
                NewVersion = ""
                LastReleaseTag = ""
                TargetBranch = $TargetBranch
                Suffix = ""
                Warning = ""
                ActionRequired = $false
                ActionInstructions = ""
                Error = "ModuleVersion not found in manifest file: $ManifestPath"
            }
        }
        
        $currentVersion = $manifest.ModuleVersion
        Write-Verbose "Current module version: $currentVersion"
        
        # Find the latest release tag
        $latestReleaseTag = Get-LatestReleaseTag
        $warningMessage = ""
        
        if ([string]::IsNullOrWhiteSpace($latestReleaseTag)) {
            Write-Verbose "No previous release tags found, implementing hybrid first release logic"
            Write-SafeTaskSuccessLog -Message "No previous releases found - implementing first release logic!"
            
            # Validate first release version (Hybrid Approach with Structured Error Handling)
            $firstReleaseValidation = Test-FirstReleaseVersion -currentVersion $currentVersion -forceFirstRelease $ForceFirstRelease.IsPresent
            $baseVersion = $firstReleaseValidation.baseVersion
            $warningMessage = $firstReleaseValidation.warning
            $actionRequired = $firstReleaseValidation.actionRequired
            $actionInstructions = $firstReleaseValidation.actionInstructions
            
            # If action is required (unusual version without force flag), return structured error
            if ($actionRequired) {
                Write-SafeWarningLog -Message "Action Required: Unusual first release version detected" -Context $actionInstructions
                
                return [PSCustomObject]@{
                    CurrentVersion = $currentVersion
                    BumpType = "none"
                    NewVersion = ""
                    LastReleaseTag = ""
                    TargetBranch = $TargetBranch
                    Suffix = ""
                    Warning = $warningMessage
                    ActionRequired = $true
                    ActionInstructions = $actionInstructions
                    Error = ""
                }
            }
            
            # Proceed with normal first release logic
            # Analyze git history to determine bump type
            $bumpResult = Get-ReleaseVersionBumpType -lastReleaseTag "" -targetBranch $TargetBranch
            $bumpType = $bumpResult.bumpType
            $suffix = $bumpResult.suffix
            
            # Calculate new version using PSD1 version as base (HYBRID APPROACH)
            $newVersion = Step-Version -currentVersion $baseVersion -bumpType $bumpType -suffix $suffix
            
            Write-SafeInfoLog -Message "First release calculated from PSD1 base version: $baseVersion -> $newVersion"
            
        } else {
            Write-Verbose "Latest release tag found: '$latestReleaseTag'"
            Write-SafeInfoLog -Message "Analyzing changes since last release: $latestReleaseTag"
            
            # Analyze changes since last release (normal behavior)
            $bumpResult = Get-ReleaseVersionBumpType -lastReleaseTag $latestReleaseTag -targetBranch $TargetBranch
            $bumpType = $bumpResult.bumpType
            $suffix = $bumpResult.suffix
            
            # Calculate new version from current version
            $newVersion = Step-Version -currentVersion $currentVersion -bumpType $bumpType -suffix $suffix
        }
        
        # Output results for debugging
        $contextLines = @(
            "Current version: $currentVersion",
            "Bump type: $bumpType"
        )
        
        if ($suffix) {
            $contextLines += "Suffix: $suffix"
        }
        
        $contextLines += "New version: $newVersion"
        
        if ($latestReleaseTag) {
            $contextLines += "Since release: $latestReleaseTag"
        } else {
            $contextLines += "Since: Repository start (first release using hybrid logic)"
        }
        
        if ($warningMessage) {
            $contextLines += "Warning: $warningMessage"
        }
        
        Write-SafeInfoLog -Message "Version Analysis Results:" -Context ($contextLines -join "`n")
        
        # Return structured object for GitHub Actions consumption
        return [PSCustomObject]@{
            CurrentVersion = $currentVersion
            BumpType = $bumpType
            NewVersion = $newVersion
            LastReleaseTag = $latestReleaseTag
            TargetBranch = $TargetBranch
            Suffix = $suffix
            Warning = $warningMessage
            ActionRequired = $false
            ActionInstructions = ""
            Error = ""
        }
    }
    catch {
        Write-SafeErrorLog -Message "Failed to determine next semantic version: $($_.Exception.Message)"
        # Return object with error information
        return [PSCustomObject]@{
            CurrentVersion = ""
            BumpType = "none"
            NewVersion = ""
            LastReleaseTag = ""
            TargetBranch = $TargetBranch
            Suffix = ""
            Warning = ""
            ActionRequired = $false
            ActionInstructions = ""
            Error = $_.Exception.Message
        }
    }
}
