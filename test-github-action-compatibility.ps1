#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests GitHub Action compatibility for K.PSGallery.SemanticVersioning

.DESCRIPTION
    Validates that Get-NextSemanticVersion returns all properties expected by action.yml
#>

Write-Host "🚀 Testing GitHub Action Compatibility..." -ForegroundColor Green

# Import module
$ModuleRoot = Join-Path $PSScriptRoot "K.PSGallery.SemanticVersioning"
$ModulePath = Join-Path $ModuleRoot "K.PSGallery.SemanticVersioning.psd1"

if (-not (Test-Path $ModulePath)) {
    Write-Host "❌ Module not found at: $ModulePath" -ForegroundColor Red
    exit 1
}

Import-Module $ModulePath -Force
Write-Host "✅ Module imported successfully" -ForegroundColor Green

# Test function execution
try {
    $result = Get-NextSemanticVersion -ManifestPath $ModulePath -BranchName "main"
    Write-Host "✅ Function executed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Function execution failed: $_" -ForegroundColor Red
    exit 1
}

# Check for required GitHub Action properties
$requiredProperties = @(
    'CurrentVersion',
    'BumpType', 
    'NewVersion',
    'LastReleaseTag',
    'TargetBranch',      # ← MISSING
    'Suffix',            # ← MISSING
    'Warning',           # ← MISSING
    'ActionRequired',    # ← MISSING
    'ActionInstructions' # ← MISSING
)

Write-Host "`n📋 Checking required properties..." -ForegroundColor Cyan

$missingProperties = @()
$foundProperties = @()

foreach ($prop in $requiredProperties) {
    if ($result.PSObject.Properties.Name -contains $prop) {
        $foundProperties += $prop
        $value = $result.$prop
        $valueStr = if ($null -eq $value) { "(null)" } elseif ($value -eq "") { "(empty)" } else { "'$value'" }
        Write-Host "  ✅ $prop = $valueStr" -ForegroundColor Green
    } else {
        $missingProperties += $prop
        Write-Host "  ❌ $prop = MISSING!" -ForegroundColor Red
    }
}

# Summary
Write-Host "`n📊 Summary:" -ForegroundColor Yellow
Write-Host "  Found properties: $($foundProperties.Count)/$($requiredProperties.Count)" -ForegroundColor White
Write-Host "  Found: $($foundProperties -join ', ')" -ForegroundColor Green

if ($missingProperties.Count -gt 0) {
    Write-Host "  Missing: $($missingProperties -join ', ')" -ForegroundColor Red
    Write-Host "`n❌ GitHub Action compatibility: FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✅ GitHub Action compatibility: PASSED" -ForegroundColor Green
    
    # Show the actual output format that action.yml expects
    Write-Host "`n🎯 GitHub Action Output Format:" -ForegroundColor Cyan
    Write-Host "currentVersion=$($result.CurrentVersion)"
    Write-Host "bumpType=$($result.BumpType)"
    Write-Host "newVersion=$($result.NewVersion)"
    Write-Host "lastReleaseTag=$($result.LastReleaseTag)"
    Write-Host "targetBranch=$($result.TargetBranch)"
    Write-Host "suffix=$($result.Suffix)"
    Write-Host "warning=$($result.Warning)"
    Write-Host "actionRequired=$($result.ActionRequired)"
    Write-Host "actionInstructions=$($result.ActionInstructions)"
    
    exit 0
}
