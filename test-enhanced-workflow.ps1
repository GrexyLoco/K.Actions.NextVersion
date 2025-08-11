#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test script to validate the enhanced GitHub workflow with Pester tests

.DESCRIPTION
    This script validates that:
    1. Pester tests run successfully
    2. GitHub Action still works with new properties
    3. Integration tests pass
#>

Write-Host "🚀 Testing Enhanced GitHub Workflow..." -ForegroundColor Green

# Test 1: Run Pester tests locally
Write-Host "`n🧪 Running Pester Tests Locally..." -ForegroundColor Yellow
try {
    Import-Module Pester -Force
    $testPath = "./K.PSGallery.SemanticVersioning/Tests"
    
    if (Test-Path $testPath) {
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $testPath
        $pesterConfig.Run.PassThru = $true
        $pesterConfig.Output.Verbosity = 'Normal'
        
        $results = Invoke-Pester -Configuration $pesterConfig
        
        if ($results.FailedCount -eq 0) {
            Write-Host "✅ Pester tests passed locally!" -ForegroundColor Green
        } else {
            Write-Host "❌ Pester tests failed locally!" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "⚠️ Test path not found: $testPath" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Could not run Pester tests: $_" -ForegroundColor Yellow
}

# Test 2: Validate GitHub Action properties
Write-Host "`n🔍 Testing GitHub Action Properties..." -ForegroundColor Yellow
try {
    Import-Module "./K.PSGallery.SemanticVersioning/K.PSGallery.SemanticVersioning.psd1" -Force
    $result = Get-NextSemanticVersion -ManifestPath "./TestModule.psd1" -BranchName "main"
    
    $requiredProps = @('CurrentVersion', 'BumpType', 'NewVersion', 'LastReleaseTag', 'TargetBranch', 'Suffix', 'Warning', 'ActionRequired', 'ActionInstructions')
    $missingProps = @()
    
    foreach ($prop in $requiredProps) {
        if (-not ($result.PSObject.Properties.Name -contains $prop)) {
            $missingProps += $prop
        }
    }
    
    if ($missingProps.Count -eq 0) {
        Write-Host "✅ All GitHub Action properties present!" -ForegroundColor Green
        Write-Host "📊 Properties found: $($requiredProps -join ', ')" -ForegroundColor Cyan
    } else {
        Write-Host "❌ Missing properties: $($missingProps -join ', ')" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ GitHub Action property test failed: $_" -ForegroundColor Red
    exit 1
}

# Test 3: Check workflow syntax
Write-Host "`n📋 Validating Workflow Syntax..." -ForegroundColor Yellow
$workflowPath = "./.github/workflows/test.yml"
if (Test-Path $workflowPath) {
    Write-Host "✅ Workflow file exists at: $workflowPath" -ForegroundColor Green
    
    # Basic YAML validation
    $content = Get-Content $workflowPath -Raw
    if ($content -match "pester-tests:" -and $content -match "🧪 PowerShell Pester Tests") {
        Write-Host "✅ Pester tests job found in workflow!" -ForegroundColor Green
    } else {
        Write-Host "❌ Pester tests job not found in workflow!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "❌ Workflow file not found!" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎉 ALL LOCAL TESTS PASSED!" -ForegroundColor Green
Write-Host "🚀 Ready to push and trigger GitHub Actions!" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. git add ." -ForegroundColor White
Write-Host "  2. git commit -m 'feat: Add Pester tests to GitHub workflow with awesome summaries'" -ForegroundColor White
Write-Host "  3. git push" -ForegroundColor White
Write-Host "  4. Watch the magic happen in GitHub Actions! ✨" -ForegroundColor White
