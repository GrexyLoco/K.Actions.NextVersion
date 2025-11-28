<#
.SYNOPSIS
    Validates GitHub Action structure and schema.

.DESCRIPTION
    Validates that the action.yml file exists, has required fields,
    and follows GitHub Action schema conventions.

.OUTPUTS
    Sets GITHUB_OUTPUT variables: structure-success, schema-success

.EXAMPLE
    ./Test-ActionStructure.ps1

.NOTES
    Platform-independent PowerShell script for GitHub Actions workflows.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Information "Validating GitHub Action structure"

$structureSuccess = $true
$schemaSuccess = $true
$errors = @()

# Find action.yml
$actionYml = Get-ChildItem -Path . -Filter 'action.yml' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $actionYml) {
    $actionYml = Get-ChildItem -Path . -Filter 'action.yaml' -ErrorAction SilentlyContinue | Select-Object -First 1
}

if (-not $actionYml) {
    $structureSuccess = $false
    $errors += "action.yml not found in repository root"
} else {
    Write-Information "Found: $($actionYml.Name)"
    
    $content = Get-Content -Path $actionYml.FullName -Raw
    
    # Required fields check
    $requiredFields = @('name', 'description', 'runs')
    foreach ($field in $requiredFields) {
        $patternStart = '^' + $field + '\s*:'
        $patternNewline = '\n' + $field + '\s*:'
        if ($content -notmatch $patternStart -and $content -notmatch $patternNewline) {
            $structureSuccess = $false
            $errors += "Missing required field: $field"
        }
    }
    
    # Validate 'runs' section has 'using'
    if ($content -match 'runs:') {
        if ($content -notmatch 'using:') {
            $schemaSuccess = $false
            $errors += "runs section missing 'using' field"
        }
    }
    
    # Check for valid 'using' value
    $validUsing = @('composite', 'docker', 'node12', 'node16', 'node20')
    $usingMatch = $false
    foreach ($using in $validUsing) {
        $pattern = 'using:\s*[''"]?' + $using
        if ($content -match $pattern) {
            $usingMatch = $true
            break
        }
    }
    
    if (-not $usingMatch -and $content -match 'using:') {
        $schemaSuccess = $false
        $errors += "Invalid 'using' value. Must be one of: $($validUsing -join ', ')"
    }
}

# Report results
if ($errors.Count -gt 0) {
    Write-Warning "Validation issues found:"
    foreach ($error in $errors) {
        Write-Warning "  - $error"
    }
}

# Set outputs
"structure-success=$($structureSuccess.ToString().ToLower())" >> $env:GITHUB_OUTPUT
"schema-success=$($schemaSuccess.ToString().ToLower())" >> $env:GITHUB_OUTPUT

if ($structureSuccess -and $schemaSuccess) {
    Write-Information "✅ Action structure validation passed"
} else {
    Write-Warning "⚠️ Action structure validation completed with issues"
}
