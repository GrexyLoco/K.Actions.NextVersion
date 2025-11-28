<#
.SYNOPSIS
    Generates a detailed summary for the Quality Gate job.

.DESCRIPTION
    Creates a comprehensive GitHub Step Summary showing:
    - Security scan results (GitLeaks)
    - Action structure validation
    - Schema validation
    - PowerShell linting results
    - Action metadata (name, type)

.PARAMETER GitLeaksOutcome
    The outcome of the GitLeaks step ('success'/'failure').

.PARAMETER StructureSuccess
    Whether structure validation passed ('true'/'false').

.PARAMETER SchemaSuccess
    Whether schema validation passed ('true'/'false').

.PARAMETER LintSuccess
    Whether linting passed ('true'/'false').

.PARAMETER QualitySuccess
    Whether overall quality gate passed ('true'/'false').

.PARAMETER ActionName
    The name of the GitHub Action.

.PARAMETER ActionType
    The type of the action (composite/javascript/docker).

.PARAMETER ScriptsAnalyzed
    Number of PowerShell scripts analyzed.

.PARAMETER TotalErrors
    Total number of linting errors.

.PARAMETER TotalWarnings
    Total number of linting warnings.

.OUTPUTS
    Writes to GITHUB_STEP_SUMMARY.

.EXAMPLE
    ./Write-QualityGateSummary.ps1 -GitLeaksOutcome 'success' -StructureSuccess 'true' ...

.NOTES
    Platform-independent PowerShell script for GitHub Actions workflows.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$GitLeaksOutcome = 'skipped',
    
    [Parameter(Mandatory = $false)]
    [string]$StructureSuccess = 'false',
    
    [Parameter(Mandatory = $false)]
    [string]$SchemaSuccess = 'false',
    
    [Parameter(Mandatory = $false)]
    [string]$LintSuccess = 'false',
    
    [Parameter(Mandatory = $false)]
    [string]$QualitySuccess = 'false',
    
    [Parameter(Mandatory = $false)]
    [string]$ActionName = 'Unknown',
    
    [Parameter(Mandatory = $false)]
    [string]$ActionType = 'Unknown',
    
    [Parameter(Mandatory = $false)]
    [string]$ScriptsAnalyzed = '0',
    
    [Parameter(Mandatory = $false)]
    [string]$TotalErrors = '0',
    
    [Parameter(Mandatory = $false)]
    [string]$TotalWarnings = '0'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Handle empty/null values gracefully
if ([string]::IsNullOrWhiteSpace($GitLeaksOutcome)) { $GitLeaksOutcome = 'skipped' }
if ([string]::IsNullOrWhiteSpace($StructureSuccess)) { $StructureSuccess = 'false' }
if ([string]::IsNullOrWhiteSpace($SchemaSuccess)) { $SchemaSuccess = 'false' }
if ([string]::IsNullOrWhiteSpace($LintSuccess)) { $LintSuccess = 'false' }
if ([string]::IsNullOrWhiteSpace($QualitySuccess)) { $QualitySuccess = 'false' }
if ([string]::IsNullOrWhiteSpace($ActionName)) { $ActionName = 'Unknown' }
if ([string]::IsNullOrWhiteSpace($ActionType)) { $ActionType = 'Unknown' }
if ([string]::IsNullOrWhiteSpace($ScriptsAnalyzed)) { $ScriptsAnalyzed = '0' }
if ([string]::IsNullOrWhiteSpace($TotalErrors)) { $TotalErrors = '0' }
if ([string]::IsNullOrWhiteSpace($TotalWarnings)) { $TotalWarnings = '0' }

$gitleaksOk = $GitLeaksOutcome -eq 'success'
$structureOk = $StructureSuccess -eq 'true'
$schemaOk = $SchemaSuccess -eq 'true'
$lintOk = $LintSuccess -eq 'true'
$qualityOk = $QualitySuccess -eq 'true'

$scriptsCount = [int]$ScriptsAnalyzed

$overallStatus = if ($qualityOk) { '✅ **PASSED**' } else { '❌ **FAILED**' }

# Linting result with warning for 0 scripts
$lintResult = if ($lintOk) { '✅ Passed' } else { '⚠️ Issues' }
$lintDetails = "$scriptsCount scripts, $TotalErrors errors"

$summary = @"
<details>
<summary>🔐 Quality Gate Results - $overallStatus</summary>

| Check | Result | Details |
|-------|--------|---------|
| **🔒 Security** | $(if ($gitleaksOk) { '✅ Passed' } else { '⚠️ Issues' }) | GitLeaks secret scanning |
| **📋 Structure** | $(if ($structureOk) { '✅ Passed' } else { '❌ Failed' }) | action.yml validation |
| **📐 Schema** | $(if ($schemaOk) { '✅ Passed' } else { '⚠️ Skipped' }) | Action schema check |
| **🎨 Linting** | $lintResult | $lintDetails |

"@

# Add warning block if 0 scripts analyzed
if ($scriptsCount -eq 0) {
    $summary += @"

> ⚠️ **Note:** 0 scripts analyzed. This is valid if PowerShell code is embedded in ``action.yml`` (composite action).
> Excluded from discovery: ``.git/``, ``.github/scripts/``

"@
}

$summary += @"

### 🎯 Action Details
| Property | Value |
|----------|-------|
| **Name** | ``$ActionName`` |
| **Type** | ``$ActionType`` |
| **Warnings** | ``$TotalWarnings`` |
| **Overall** | $overallStatus |

</details>

---
"@

Write-Output $summary >> $env:GITHUB_STEP_SUMMARY
