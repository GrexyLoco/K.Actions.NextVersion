<#
.SYNOPSIS
    Creates a complete GitHub release for a GitHub Action.

.DESCRIPTION
    Creates a GitHub release with smart tags using the proven
    Draft → Smart Tags → Publish strategy.

.PARAMETER Version
    Semantic version without 'v' prefix (e.g., "1.2.3").

.PARAMETER BumpType
    Type of version bump (major/minor/patch/manual).

.PARAMETER ActionName
    Name of the GitHub Action.

.PARAMETER Repository
    GitHub repository in format "owner/repo".

.OUTPUTS
    Sets GITHUB_OUTPUT variables: release-created, release-tag, release-url, tags-created

.EXAMPLE
    ./Create-GitHubRelease.ps1 -Version "1.2.3" -BumpType "patch" -ActionName "MyAction" -Repository "owner/repo"

.NOTES
    Platform-independent PowerShell script for GitHub Actions workflows.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [Parameter(Mandatory = $true)]
    [string]$BumpType,
    
    [Parameter(Mandatory = $true)]
    [string]$ActionName,
    
    [Parameter(Mandatory = $false)]
    [string]$Repository = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Auto-detect repository if not provided
if (-not $Repository -and $env:GITHUB_REPOSITORY) {
    $Repository = $env:GITHUB_REPOSITORY
}

$releaseTag = "v$Version"

Write-Host "Creating release $releaseTag for $ActionName"

# ─────────────────────────────────────────────────────────────────────────────
# Try Smartagr first (if available)
# ─────────────────────────────────────────────────────────────────────────────
$smartagrAvailable = $null -ne (Get-Command -Name 'New-SmartRelease' -ErrorAction SilentlyContinue)

if ($smartagrAvailable) {
    Write-Host "Using K.PSGallery.Smartagr for release creation"
    
    $timestamp = (Get-Date).ToUniversalTime().ToString('MMMM dd, yyyy \a\t HH:mm UTC')
    $releaseNotes = @"
## 🎉 Release $releaseTag

> **$BumpType** release • Released on $timestamp

### 📦 Quick Access
- 📁 [Source Code](https://github.com/$Repository)
- 🏷️ [This Release](https://github.com/$Repository/releases/tag/$releaseTag)

### 🚀 Usage
``````yaml
- name: $ActionName
  uses: $Repository@$releaseTag
  with:
    # Add your inputs here
``````

---
*Auto-generated release*
"@

    $result = New-SmartRelease -TargetVersion $releaseTag -ReleaseNotes $releaseNotes -PushToRemote -Force
    
    if ($result.Success) {
        "release-created=true" >> $env:GITHUB_OUTPUT
        "release-tag=$releaseTag" >> $env:GITHUB_OUTPUT
        "release-url=$($result.ReleaseUrl)" >> $env:GITHUB_OUTPUT
        "tags-created=$($result.TagsCreated -join ',')" >> $env:GITHUB_OUTPUT
        
        Write-Host "✅ Release created via Smartagr"
        Write-Host "   Tags: $($result.TagsCreated -join ', ')"
    } else {
        throw "Smartagr release failed: $($result.GitHubReleaseResult.ErrorMessage)"
    }
} else {
    # ─────────────────────────────────────────────────────────────────────────
    # Fallback: gh CLI
    # ─────────────────────────────────────────────────────────────────────────
    Write-Host "Using gh CLI for release creation"
    
    $timestamp = (Get-Date).ToUniversalTime().ToString('MMMM dd, yyyy \a\t HH:mm UTC')
    $releaseNotes = @"
## 🎉 Release $releaseTag

> **$BumpType** release • Released on $timestamp

### 🚀 Usage
``````yaml
- name: $ActionName
  uses: $Repository@$releaseTag
  with:
    # Add your inputs here
``````

---
*Auto-generated release*
"@

    Set-Content -Path 'release_notes.md' -Value $releaseNotes -Encoding UTF8

    # Delete existing release if exists
    $null = gh release view $releaseTag 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "⚠️ Deleting existing release"
        gh release delete $releaseTag --yes 2>$null
        git tag -d $releaseTag 2>$null
        git push origin --delete $releaseTag 2>$null
        Start-Sleep -Seconds 2
    }

    $isPrerelease = $Version -match '(alpha|beta|rc|preview|pre)'
    $title = if ($isPrerelease) { "🧪 Prerelease $releaseTag" } else { "🚀 $ActionName $releaseTag" }

    # Step 1: Create base tag
    Write-Host "Creating base tag $releaseTag"
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
    git tag -a $releaseTag -m "Release $releaseTag"
    git push origin $releaseTag
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create base tag"
    }

    # Step 2: Create draft release
    Write-Host "Creating draft release"
    $ghArgs = @('release', 'create', $releaseTag, '--title', $title, '--notes-file', 'release_notes.md', '--generate-notes', '--draft')
    if ($isPrerelease) { $ghArgs += '--prerelease' }
    
    & gh @ghArgs
    if ($LASTEXITCODE -ne 0) { throw "Failed to create draft release" }

    # Step 3: Create smart tags
    Write-Host "Creating smart tags"
    $versionParts = $Version -split '\.'
    $major = "v$($versionParts[0])"
    $minor = "v$($versionParts[0]).$($versionParts[1])"
    $tagsCreated = @($releaseTag)
    
    foreach ($smartTag in @($major, $minor, 'latest')) {
        git tag -d $smartTag 2>$null
        git push origin --delete $smartTag 2>$null
        git tag -f $smartTag $releaseTag
        git push origin $smartTag --force
        Write-Host "  Created: $smartTag → $releaseTag"
        $tagsCreated += $smartTag
    }

    # Step 4: Publish release
    Write-Host "Publishing release"
    if ($isPrerelease) {
        gh release edit $releaseTag --draft=false
    } else {
        gh release edit $releaseTag --draft=false --latest
    }
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to publish release" }

    $releaseUrl = "https://github.com/$Repository/releases/tag/$releaseTag"
    
    "release-created=true" >> $env:GITHUB_OUTPUT
    "release-tag=$releaseTag" >> $env:GITHUB_OUTPUT
    "release-url=$releaseUrl" >> $env:GITHUB_OUTPUT
    "tags-created=$($tagsCreated -join ',')" >> $env:GITHUB_OUTPUT
    
    Write-Host "✅ Release created via gh CLI"
    Write-Host "   Smart tags: $major, $minor, latest"
}
