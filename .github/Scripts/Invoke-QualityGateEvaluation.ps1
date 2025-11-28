<#
.SYNOPSIS
    Evaluates quality gate results and determines overall pass/fail.

.DESCRIPTION
    Aggregates results from security scan, structure validation, and linting
    to determine if the quality gate passes. Sets GitHub Action outputs.

.PARAMETER GitLeaksOutcome
    Outcome of the GitLeaks security scan step.

.PARAMETER StructureSuccess
    Whether structure validation passed.

.PARAMETER SchemaSuccess
    Whether schema validation passed.

.PARAMETER LintSuccess
    Whether linting passed.

.PARAMETER ActionName
    Name of the action being validated.

.PARAMETER ActionType
    Type of action (composite, docker, javascript).

.PARAMETER ScriptsAnalyzed
    Number of scripts analyzed.

.PARAMETER TotalErrors
    Total number of linting errors.

.PARAMETER TotalWarnings
    Total number of linting warnings.

.OUTPUTS
    Sets GITHUB_OUTPUT variable: quality-success

.EXAMPLE
    ./Invoke-QualityGateEvaluation.ps1 -GitLeaksOutcome 'success' -StructureSuccess 'true' ...

.NOTES
    Platform-independent PowerShell script for GitHub Actions workflows.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GitLeaksOutcome,
    
    [Parameter(Mandatory = $true)]
    [string]$StructureSuccess,
    
    [Parameter(Mandatory = $true)]
    [string]$SchemaSuccess,
    
    [Parameter(Mandatory = $true)]
    [string]$LintSuccess,
    
    [Parameter(Mandatory = $false)]
    [string]$ActionName = '',
    
    [Parameter(Mandatory = $false)]
    [string]$ActionType = '',
    
    [Parameter(Mandatory = $false)]
    [string]$ScriptsAnalyzed = '0',
    
    [Parameter(Mandatory = $false)]
    [string]$TotalErrors = '0',
    
    [Parameter(Mandatory = $false)]
    [string]$TotalWarnings = '0'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Information "Evaluating Quality Gate"

# Evaluate each check
$securityPassed = $GitLeaksOutcome -eq 'success'
$structurePassed = $StructureSuccess -eq 'true'
$schemaPassed = $SchemaSuccess -eq 'true'
$lintPassed = $LintSuccess -eq 'true'

# Quality gate rules:
# - Security: MUST pass (critical)
# - Structure: MUST pass (required for release)
# - Schema: Warning only (non-blocking)
# - Lint: MUST pass (no errors allowed)

$qualitySuccess = $securityPassed -and $structurePassed -and $lintPassed

Write-Information "Security:  $(if ($securityPassed) { '✅ PASS' } else { '❌ FAIL' })"
Write-Information "Structure: $(if ($structurePassed) { '✅ PASS' } else { '❌ FAIL' })"
Write-Information "Schema:    $(if ($schemaPassed) { '✅ PASS' } else { '⚠️ WARN' })"
Write-Information "Linting:   $(if ($lintPassed) { '✅ PASS' } else { '❌ FAIL' })"
Write-Information ""
Write-Information "Quality Gate: $(if ($qualitySuccess) { '✅ PASSED' } else { '❌ FAILED' })"

# Set output
"quality-success=$($qualitySuccess.ToString().ToLower())" >> $env:GITHUB_OUTPUT
