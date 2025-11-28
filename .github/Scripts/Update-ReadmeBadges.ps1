#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Updates README.md badges based on workflow results

.DESCRIPTION
    Updates status badges in README.md to reflect current Quality Gate and Release status.
    Works on both successful and failed runs to keep badges accurate.
    
    Supported Badges (between markers):
    - Quality Gate: Overall quality status (passing/failing)
    - Release: Latest version from tag
    - Last Updated: Timestamp of last badge update

.PARAMETER QualitySuccess
    Whether the Quality Gate passed ('true'/'false')

.PARAMETER ReleaseSuccess
    Whether a release was created ('true'/'false')

.PARAMETER ReleaseVersion
    The version that was released (e.g., 'v1.2.3')

.PARAMETER ActionName
    Name of the GitHub Action

.PARAMETER Repository
    GitHub repository in format 'owner/repo'

.EXAMPLE
    & "./Update-ReadmeBadges.ps1" `
        -QualitySuccess 'true' `
        -ReleaseSuccess 'true' `
        -ReleaseVersion 'v1.2.3' `
        -ActionName 'MyAction' `
        -Repository 'owner/repo'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$QualitySuccess,
    
    [Parameter(Mandatory = $false)]
    [string]$ReleaseSuccess = 'false',
    
    [Parameter(Mandatory = $false)]
    [string]$ReleaseVersion = '',
    
    [Parameter(Mandatory = $true)]
    [string]$ActionName,
    
    [Parameter(Mandatory = $true)]
    [string]$Repository
)

# ═══════════════════════════════════════════════════════════════════════════
# 🔧 Configuration
# ═══════════════════════════════════════════════════════════════════════════

$readmePath = "README.md"
$startMarker = "<!-- AUTO-GENERATED BADGES - DO NOT EDIT MANUALLY -->"
$endMarker = "<!-- END AUTO-GENERATED BADGES -->"

# ═══════════════════════════════════════════════════════════════════════════
# 📋 Functions
# ═══════════════════════════════════════════════════════════════════════════

function Get-BadgeUrl {
    param(
        [string]$Label,
        [string]$Message,
        [string]$Color,
        [string]$Logo = ''
    )
    
    # URL-encode special characters
    $encodedLabel = $Label -replace '-', '--' -replace '_', '__' -replace ' ', '_'
    $encodedMessage = $Message -replace '-', '--' -replace '_', '__' -replace ' ', '_'
    
    $url = "https://img.shields.io/badge/$encodedLabel-$encodedMessage-$color"
    if ($Logo) {
        $url += "?logo=$Logo"
    }
    return $url
}

function New-BadgeSection {
    param(
        [bool]$QualityOk,
        [bool]$ReleaseOk,
        [string]$Version,
        [string]$RepoName,
        [string]$ActionDisplayName
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Quality Gate Badge
    $qualityColor = if ($QualityOk) { 'brightgreen' } else { 'red' }
    $qualityText = if ($QualityOk) { 'passing' } else { 'failing' }
    $qualityBadge = "![Quality Gate]($(Get-BadgeUrl -Label 'Quality Gate' -Message $qualityText -Color $qualityColor -Logo 'githubactions'))"
    
    # Release Badge (only if we have a version)
    $releaseBadge = ""
    if ($Version) {
        $releaseColor = if ($ReleaseOk) { 'blue' } else { 'orange' }
        $releaseBadge = "![Release]($(Get-BadgeUrl -Label 'Release' -Message $Version -Color $releaseColor -Logo 'github'))"
    } else {
        # Show "no release" badge
        $releaseBadge = "![Release]($(Get-BadgeUrl -Label 'Release' -Message 'none' -Color 'lightgrey' -Logo 'github'))"
    }
    
    # Workflow Status Badge (dynamic GitHub badge)
    $workflowBadge = "[![CI](https://github.com/$RepoName/actions/workflows/release.yml/badge.svg)](https://github.com/$RepoName/actions/workflows/release.yml)"
    
    # Build the section
    $section = @"
$startMarker
## 📊 Status

$qualityBadge $releaseBadge $workflowBadge

> 🕐 **Last Updated:** $timestamp UTC | **Action:** ``$ActionDisplayName``
$endMarker
"@
    
    return $section
}

# ═══════════════════════════════════════════════════════════════════════════
# 🚀 Main Logic
# ═══════════════════════════════════════════════════════════════════════════

Write-Host "🏷️ Updating README badges..." -ForegroundColor Cyan

# Check if README exists
if (-not (Test-Path $readmePath)) {
    Write-Host "⚠️ README.md not found, skipping badge update" -ForegroundColor Yellow
    exit 0
}

# Parse parameters
$qualityOk = $QualitySuccess -eq 'true'
$releaseOk = $ReleaseSuccess -eq 'true'

Write-Host "  Quality Gate: $(if ($qualityOk) { '✅ Passed' } else { '❌ Failed' })" -ForegroundColor $(if ($qualityOk) { 'Green' } else { 'Red' })
Write-Host "  Release: $(if ($releaseOk) { "✅ $ReleaseVersion" } else { '⏭️ Skipped' })" -ForegroundColor $(if ($releaseOk) { 'Green' } else { 'Yellow' })

# Read current README
$content = Get-Content $readmePath -Raw

# Generate new badge section
$newSection = New-BadgeSection `
    -QualityOk $qualityOk `
    -ReleaseOk $releaseOk `
    -Version $ReleaseVersion `
    -RepoName $Repository `
    -ActionDisplayName $ActionName

# Check if markers exist
if ($content -match [regex]::Escape($startMarker)) {
    # Replace existing section
    $pattern = [regex]::Escape($startMarker) + "[\s\S]*?" + [regex]::Escape($endMarker)
    $newContent = $content -replace $pattern, $newSection
    Write-Host "✅ Updated existing badge section" -ForegroundColor Green
} else {
    # Insert after first heading (# Title)
    if ($content -match '^(# .+\r?\n)') {
        $firstHeading = $Matches[1]
        $newContent = $content -replace [regex]::Escape($firstHeading), "$firstHeading`n$newSection`n"
        Write-Host "✅ Inserted new badge section after title" -ForegroundColor Green
    } else {
        # Prepend to file
        $newContent = "$newSection`n`n$content"
        Write-Host "✅ Prepended badge section to README" -ForegroundColor Green
    }
}

# Only update if content changed
if ($newContent -ne $content) {
    Set-Content $readmePath -Value $newContent -NoNewline -Encoding UTF8
    Write-Host "📝 README.md updated" -ForegroundColor Cyan
    
    # Set output for workflow
    Write-Output "badges-updated=true" >> $env:GITHUB_OUTPUT
} else {
    Write-Host "ℹ️ No changes needed" -ForegroundColor Gray
    Write-Output "badges-updated=false" >> $env:GITHUB_OUTPUT
}

Write-Host "🏷️ Badge update complete!" -ForegroundColor Green
