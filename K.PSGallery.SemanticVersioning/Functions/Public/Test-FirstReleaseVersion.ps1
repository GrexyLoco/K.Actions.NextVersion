<#
.SYNOPSIS
    Validates first release version based on PSD1 content and provides structured guidance for unusual versions.

.DESCRIPTION
    Implements hybrid first release logic with structured error handling:
    - Standard versions (0.0.0, 1.0.0): Use as base for bump
    - Unusual versions (e.g., 3.5.2): Return structured error with actionable guidance
    - Force flag: Skip validation and use PSD1 version

.PARAMETER currentVersion
    The current version from PSD1 manifest

.PARAMETER forceFirstRelease
    Force flag to skip validation

.OUTPUTS
    Hashtable
    Returns validation result with baseVersion, warning, actionRequired, and actionInstructions

.EXAMPLE
    Test-FirstReleaseVersion -currentVersion "1.0.0" -forceFirstRelease:$false
    Returns: @{ baseVersion = "1.0.0"; warning = ""; actionRequired = $false; actionInstructions = "" }

.EXAMPLE
    Test-FirstReleaseVersion -currentVersion "3.5.2" -forceFirstRelease:$false
    Returns structured error with actionRequired = $true and detailed actionInstructions
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
            actionRequired = $false
            actionInstructions = ""
        }
    }
    
    if ($forceFirstRelease) {
        Write-Verbose "Force flag enabled, using PSD1 version: $currentVersion"
        return @{ 
            baseVersion = $currentVersion
            warning = "First release forced with version $currentVersion (migration mode)"
            actionRequired = $false
            actionInstructions = ""
        }
    }
    
    # Unusual version detected - return structured error guidance
    $warningMessage = "Unusual first release version '$currentVersion' detected in PSD1 manifest"
    
    $actionInstructions = @"
🔍 UNUSUAL FIRST RELEASE VERSION DETECTED

Current PSD1 version: $currentVersion

⚠️  ISSUE: First releases typically start with 0.0.0 or 1.0.0, but your manifest contains '$currentVersion'.

📋 CHOOSE YOUR APPROACH:

Option 1 - Fresh Start (Recommended for new projects):
   • Update your .psd1 file: ModuleVersion = '0.0.0' or '1.0.0'
   • Commit the change and re-run the workflow
   • This follows standard semantic versioning practices

Option 2 - Project Migration (For existing projects):
   • Use -ForceFirstRelease flag to proceed with current version
   • This treats '$currentVersion' as your starting point for future releases
   • Add 'forceFirstRelease: true' to your workflow inputs

Option 3 - Reset to Standard Version:
   • Consider if you want to start fresh with standard versioning
   • Update .psd1 to ModuleVersion = '1.0.0'
   • This gives you a clean semantic versioning foundation

🎯 NEXT STEPS:
1. Review your project requirements
2. Choose the appropriate option above
3. Update your manifest or workflow configuration
4. Re-run the workflow

For migration scenarios, use: forceFirstRelease: true
For fresh projects, update PSD1 to: 0.0.0 or 1.0.0
"@

    Write-SafeWarningLog -Message $warningMessage
    
    return @{ 
        baseVersion = $currentVersion
        warning = $warningMessage
        actionRequired = $true
        actionInstructions = $actionInstructions
    }
}
