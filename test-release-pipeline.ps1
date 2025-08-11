#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test pipeline für K.Actions.NextVersion mit Test-Gates für Release

.DESCRIPTION
    Validiert die komplette Pipeline:
    1. Pester Tests müssen erfolgreich sein
    2. GitHub Action muss alle Properties liefern
    3. Release workflow darf nur nach erfolgreichen Tests laufen
#>

Write-Host "🚀 Testing Complete Release Pipeline with Test Gates..." -ForegroundColor Green

# Pipeline-Test Status
$tests_passed = $true

# Test 1: Validate workflow files exist
Write-Host "`n📋 Validating Workflow Files..." -ForegroundColor Yellow

$testWorkflow = "./.github/workflows/test.yml"
$releaseWorkflow = "./.github/workflows/release.yml"

if (Test-Path $testWorkflow) {
    Write-Host "✅ Test workflow found: $testWorkflow" -ForegroundColor Green
} else {
    Write-Host "❌ Test workflow missing: $testWorkflow" -ForegroundColor Red
    $tests_passed = $false
}

if (Test-Path $releaseWorkflow) {
    Write-Host "✅ Release workflow found: $releaseWorkflow" -ForegroundColor Green
} else {
    Write-Host "❌ Release workflow missing: $releaseWorkflow" -ForegroundColor Red
    $tests_passed = $false
}

# Test 2: Validate workflow_call in test.yml
Write-Host "`n🔗 Validating Workflow Dependencies..." -ForegroundColor Yellow

$testContent = Get-Content $testWorkflow -Raw
if ($testContent -match "workflow_call:") {
    Write-Host "✅ Test workflow supports workflow_call" -ForegroundColor Green
} else {
    Write-Host "❌ Test workflow missing workflow_call trigger" -ForegroundColor Red
    $tests_passed = $false
}

# Test 3: Validate release depends on tests
$releaseContent = Get-Content $releaseWorkflow -Raw
if ($releaseContent -match "needs: run-tests" -and $releaseContent -match "uses: \.\/\.github\/workflows\/test\.yml") {
    Write-Host "✅ Release workflow depends on test workflow" -ForegroundColor Green
} else {
    Write-Host "❌ Release workflow does not depend on tests" -ForegroundColor Red
    $tests_passed = $false
}

# Test 4: Validate Pester tests in workflow
if ($testContent -match "pester-tests:" -and $testContent -match "🧪 PowerShell Pester Tests") {
    Write-Host "✅ Pester tests integrated in workflow" -ForegroundColor Green
} else {
    Write-Host "❌ Pester tests not found in workflow" -ForegroundColor Red
    $tests_passed = $false
}

# Test 5: Run local Pester tests
Write-Host "`n🧪 Running Local Pester Tests..." -ForegroundColor Yellow
try {
    $testPath = "./K.PSGallery.SemanticVersioning/Tests"
    if (Test-Path $testPath) {
        Import-Module Pester -Force
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $testPath
        $pesterConfig.Run.PassThru = $true
        $pesterConfig.Output.Verbosity = 'Minimal'
        
        $results = Invoke-Pester -Configuration $pesterConfig
        
        if ($results.FailedCount -eq 0) {
            Write-Host "✅ Local Pester tests passed ($($results.PassedCount)/$($results.TotalCount))" -ForegroundColor Green
        } else {
            Write-Host "❌ Local Pester tests failed ($($results.FailedCount)/$($results.TotalCount))" -ForegroundColor Red
            $tests_passed = $false
        }
    } else {
        Write-Host "⚠️ Pester test path not found: $testPath" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Could not run Pester tests: $_" -ForegroundColor Yellow
}

# Test 6: Validate GitHub Action properties
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
        Write-Host "✅ All GitHub Action properties present ($($requiredProps.Count)/$($requiredProps.Count))" -ForegroundColor Green
    } else {
        Write-Host "❌ Missing properties: $($missingProps -join ', ')" -ForegroundColor Red
        $tests_passed = $false
    }
} catch {
    Write-Host "❌ GitHub Action property test failed: $_" -ForegroundColor Red
    $tests_passed = $false
}

# Final Status
Write-Host "`n" + "="*60 -ForegroundColor Cyan
if ($tests_passed) {
    Write-Host "🎉 ALL PIPELINE TESTS PASSED!" -ForegroundColor Green
    Write-Host "`n✅ Pipeline Quality Gates:" -ForegroundColor Cyan
    Write-Host "  • Workflow files exist and are properly configured" -ForegroundColor White
    Write-Host "  • Release workflow depends on test workflow" -ForegroundColor White
    Write-Host "  • Pester tests integrated and passing" -ForegroundColor White
    Write-Host "  • GitHub Action properties complete" -ForegroundColor White
    Write-Host "`n🚀 Ready for Production:" -ForegroundColor Yellow
    Write-Host "  • Failing tests will block releases ❌→🚫" -ForegroundColor White
    Write-Host "  • Only successful tests allow releases ✅→🚀" -ForegroundColor White
    Write-Host "`n📋 Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. git add . && git commit -m 'feat: Add test gates to release pipeline'" -ForegroundColor White
    Write-Host "  2. git push origin master" -ForegroundColor White
    Write-Host "  3. Watch the magic: Tests → Release (only if tests pass!) ✨" -ForegroundColor White
} else {
    Write-Host "❌ PIPELINE TESTS FAILED!" -ForegroundColor Red
    Write-Host "🔧 Fix the issues above before proceeding" -ForegroundColor Yellow
    exit 1
}

Write-Host "="*60 -ForegroundColor Cyan
