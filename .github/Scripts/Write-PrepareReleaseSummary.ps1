<#
.SYNOPSIS
    Generates a detailed summary for the Prepare Release job.

.DESCRIPTION
    Creates a comprehensive GitHub Step Summary explaining:
    - Current and new version information
    - Why a release is or isn't being created
    - Available version detection keywords
    - Branch influence patterns
    - How to force a release when needed

.PARAMETER ShouldRelease
    Whether a release should be created ('true'/'false').

.PARAMETER FinalVersion
    The final version that will be released.

.PARAMETER BumpType
    The final bump type (manual/major/minor/patch/force/none).

.PARAMETER CurrentVersion
    The current version from the latest Git tag.

.PARAMETER AutoBumpType
    The auto-detected bump type from K.Actions.NextActionVersion.

.OUTPUTS
    Writes to GITHUB_STEP_SUMMARY.

.EXAMPLE
    ./Write-PrepareReleaseSummary.ps1 -ShouldRelease 'false' -FinalVersion '1.2.3' -BumpType 'none' -CurrentVersion '1.2.3' -AutoBumpType 'none'

.NOTES
    Platform-independent PowerShell script for GitHub Actions workflows.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ShouldRelease = 'false',
    
    [Parameter(Mandatory = $false)]
    [string]$FinalVersion = '',
    
    [Parameter(Mandatory = $false)]
    [string]$BumpType = 'none',
    
    [Parameter(Mandatory = $false)]
    [string]$CurrentVersion = '',
    
    [Parameter(Mandatory = $false)]
    [string]$AutoBumpType = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Handle empty/null values gracefully
if ([string]::IsNullOrWhiteSpace($ShouldRelease)) { $ShouldRelease = 'false' }
if ([string]::IsNullOrWhiteSpace($FinalVersion)) { $FinalVersion = 'N/A' }
if ([string]::IsNullOrWhiteSpace($BumpType)) { $BumpType = 'none' }
if ([string]::IsNullOrWhiteSpace($CurrentVersion)) { $CurrentVersion = 'N/A' }

$statusIcon = if ($ShouldRelease -eq 'true') { '✅ Ready' } else { 'ℹ️ No Release' }
$headerStatus = if ($ShouldRelease -eq 'true') { '✅ Ready for Release' } else { 'ℹ️ No Release Required' }

$summary = @"
<details>
<summary>📦 Prepare Release - $headerStatus</summary>

| Property | Value |
|----------|-------|
| **Current Version** | ``$CurrentVersion`` |
| **New Version** | ``$FinalVersion`` |
| **Bump Type** | ``$BumpType`` |
| **Status** | $statusIcon |

"@

if ($ShouldRelease -ne 'true') {
    # Determine reason for no release based on auto-detected bump type
    # bumpType = 'none' means no commits since last tag (tag points to HEAD)
    $noCommits = $AutoBumpType -eq 'none'
    
    if ($noCommits) {
        $reasonTitle = '🔍 **Why No Release?** No commits since last tag'
        $reasonExplanation = @"

The last tag (``$CurrentVersion``) points directly to HEAD - there are **no new commits** to release.

**This happens when:**
- You just created a release (tag is on HEAD)
- Workflow was re-triggered without new code changes
- Only non-code files changed (``**.md``, ``docs/**`` are ignored)
"@
    } else {
        $reasonTitle = '🔍 **Why No Release?** No semantic version keywords detected'
        $reasonExplanation = @"

Commits were found but none triggered a version bump. This can happen if commits don't follow
the expected keyword patterns.
"@
    }
    
    $summary += @"

> $reasonTitle
> $reasonExplanation

### 📖 Version Detection Keywords

Commits are analyzed for version bump keywords. **Default: PATCH** (commits without keywords).

| Bump Type | Commit Keywords | Examples |
|-----------|-----------------|----------|
| **🔴 MAJOR** | ``BREAKING``, ``BREAKING CHANGE``, ``MAJOR`` (uppercase) | ``BREAKING: API change`` |
| **🟡 MINOR** | ``feat:``, ``feature:`` (prefix) or ``FEATURE``, ``FEAT``, ``MINOR`` (uppercase) | ``feat: add new endpoint`` |
| **🟢 PATCH** | ``fix:``, ``bugfix:``, ``docs:``, ``chore:``, ``refactor:``, ``perf:``, ``test:``, ``ci:`` | ``fix: null reference`` |
| **⚪ NONE** | No commits since last tag | Tag points to HEAD |

### 🌿 Branch Influence

Branch names can **upgrade** (never downgrade) the detected bump type:

| Branch Pattern | Effect |
|----------------|--------|
| ``feature/*``, ``feat/*`` | Upgrades to **MINOR** minimum |
| ``major/*``, ``breaking/*`` | Upgrades to **MAJOR** minimum |
| Others (``main``, ``master``, ``fix/*``) | No override |

### 🔄 How to Force a Release

| Method | How |
|--------|-----|
| **Manual Dispatch** | Workflow → Run workflow → Check ``force-release`` |
| **Version Override** | Workflow → Run workflow → Enter version (e.g., ``1.2.3``) |
| **Empty Commit** | ``git commit --allow-empty -m "fix: trigger release"`` |

"@
}

$summary += @"

</details>

---
"@

Write-Output $summary >> $env:GITHUB_STEP_SUMMARY
