<#
.SYNOPSIS
    Determines the final version for release.

.DESCRIPTION
    Evaluates manual version override vs. auto-detected version.
    Handles force-release flag for creating releases without changes.

.PARAMETER ManualVersion
    Manually specified version (overrides auto-detection).

.PARAMETER AutoBumpType
    Auto-detected bump type from commit analysis.

.PARAMETER AutoNewVersion
    Auto-detected new version.

.PARAMETER ForceRelease
    Force release even if no changes detected.

.OUTPUTS
    Sets GITHUB_OUTPUT variables: final-version, bump-type, should-release

.EXAMPLE
    ./Determine-Version.ps1 -ManualVersion '' -AutoBumpType 'patch' -AutoNewVersion '1.2.3'

.NOTES
    Platform-independent PowerShell script for GitHub Actions workflows.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ManualVersion = '',
    
    [Parameter(Mandatory = $false)]
    [string]$AutoBumpType = '',
    
    [Parameter(Mandatory = $false)]
    [string]$AutoNewVersion = '',
    
    [Parameter(Mandatory = $false)]
    [string]$ForceRelease = 'false'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Information "Determining final version"

$finalVersion = ''
$bumpType = ''
$shouldRelease = $false

# Priority 1: Manual version override
if ($ManualVersion -and $ManualVersion -ne '') {
    $finalVersion = $ManualVersion.TrimStart('v')
    $bumpType = 'manual'
    $shouldRelease = $true
    Write-Information "Using manual version: $finalVersion"
}
# Priority 2: Auto-detected version
elseif ($AutoNewVersion -and $AutoNewVersion -ne '' -and $AutoBumpType -and $AutoBumpType -ne 'none') {
    $finalVersion = $AutoNewVersion.TrimStart('v')
    $bumpType = $AutoBumpType
    $shouldRelease = $true
    Write-Information "Using auto-detected version: $finalVersion ($bumpType)"
}
# Priority 3: Force release with existing version
elseif ($ForceRelease -eq 'true') {
    if ($AutoNewVersion -and $AutoNewVersion -ne '') {
        $finalVersion = $AutoNewVersion.TrimStart('v')
    } else {
        # Fallback: get latest tag
        $latestTag = git describe --tags --abbrev=0 2>$null
        if ($latestTag) {
            $finalVersion = $latestTag.TrimStart('v')
        } else {
            $finalVersion = '0.1.0'
        }
    }
    $bumpType = 'force'
    $shouldRelease = $true
    Write-Information "Force release: $finalVersion"
}
else {
    Write-Information "No release required - no version changes detected"
    $shouldRelease = $false
    $finalVersion = $AutoNewVersion.TrimStart('v')
    $bumpType = 'none'
}

Write-Information "Final version: $finalVersion"
Write-Information "Bump type: $bumpType"
Write-Information "Should release: $shouldRelease"

# Set outputs
"final-version=$finalVersion" >> $env:GITHUB_OUTPUT
"bump-type=$bumpType" >> $env:GITHUB_OUTPUT
"should-release=$($shouldRelease.ToString().ToLower())" >> $env:GITHUB_OUTPUT
