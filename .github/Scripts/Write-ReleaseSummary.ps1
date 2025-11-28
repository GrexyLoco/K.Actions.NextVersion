<#
.SYNOPSIS
    Generates a detailed summary for the GitHub Release job.

.DESCRIPTION
    Creates a comprehensive GitHub Step Summary showing:
    - Release version and status
    - Tags created/updated (pinned, minor, major, latest)
    - Usage examples for the action
    - Quick reference for different version pinning strategies

.PARAMETER Version
    The version that was released (e.g., '1.2.3').

.PARAMETER ReleaseUrl
    The URL to the GitHub release.

.PARAMETER ReleaseCreated
    Whether the release was successfully created ('true'/'false').

.PARAMETER TagsCreated
    Comma-separated list of tags that were created.

.PARAMETER ActionName
    The name of the GitHub Action.

.PARAMETER Repository
    The full repository name (owner/repo).

.OUTPUTS
    Writes to GITHUB_STEP_SUMMARY.

.EXAMPLE
    ./Write-ReleaseSummary.ps1 -Version '1.2.3' -ReleaseUrl 'https://...' -ReleaseCreated 'true' -ActionName 'MyAction' -Repository 'owner/repo'

.NOTES
    Platform-independent PowerShell script for GitHub Actions workflows.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Version = '',
    
    [Parameter(Mandatory = $false)]
    [string]$ReleaseUrl = '',
    
    [Parameter(Mandatory = $false)]
    [string]$ReleaseCreated = 'false',
    
    [Parameter(Mandatory = $false)]
    [string]$TagsCreated = '',
    
    [Parameter(Mandatory = $false)]
    [string]$ActionName = 'Unknown',
    
    [Parameter(Mandatory = $false)]
    [string]$Repository = ''
)

Set-StrictMode -Version Latest

# Handle empty/null values gracefully
if ([string]::IsNullOrWhiteSpace($Version)) { $Version = 'N/A' }
if ([string]::IsNullOrWhiteSpace($ReleaseCreated)) { $ReleaseCreated = 'false' }
if ([string]::IsNullOrWhiteSpace($ActionName)) { $ActionName = 'Unknown' }
if ([string]::IsNullOrWhiteSpace($Repository)) { $Repository = 'unknown/unknown' }
$ErrorActionPreference = 'Stop'

$statusIcon = if ($ReleaseCreated -eq 'true') { '✅ Published' } else { '❌ Failed' }
$headerStatus = if ($ReleaseCreated -eq 'true') { '✅ Published' } else { '❌ Failed' }
$majorVersion = $Version.Split('.')[0]
$minorVersion = "$($Version.Split('.')[0]).$($Version.Split('.')[1])"

# Parse tags created
$tagsList = if ($TagsCreated) { $TagsCreated -split ',' } else { @("v$Version", "v$majorVersion", "v$minorVersion", 'latest') }
$tagsDisplay = ($tagsList | ForEach-Object { "``$_``" }) -join ', '

$summary = @"
<details open>
<summary>🚀 GitHub Release - $headerStatus</summary>

| Property | Value |
|----------|-------|
| **Version** | ``v$Version`` |
| **Release Tag** | ``v$Version`` |
| **Status** | $statusIcon |
| **Release** | [$ReleaseUrl]($ReleaseUrl) |

### 🏷️ Tags Created/Updated

| Tag | Target | Description |
|-----|--------|-------------|
| ``v$Version`` | HEAD | 📌 Pinned version (immutable) |
| ``v$minorVersion`` | → ``v$Version`` | 🔄 Minor version (moves with patches) |
| ``v$majorVersion`` | → ``v$Version`` | 🔄 Major version (moves with minor/patches) |
| ``latest`` | → ``v$Version`` | 🔄 Always points to newest release |

### 📖 Usage Example

``````yaml
- name: $ActionName
  uses: $Repository@v$Version
  with:
    # Add your inputs here
``````

### 🔗 Quick Reference

| Reference | Usage | Description |
|-----------|-------|-------------|
| **Latest** | ``$Repository@latest`` | Always newest version |
| **Pinned** | ``$Repository@v$Version`` | Exact version |
| **Major** | ``$Repository@v$majorVersion`` | Auto-update within major |

</details>

---
**🎉 Release pipeline complete!**
"@

Write-Output $summary >> $env:GITHUB_STEP_SUMMARY
