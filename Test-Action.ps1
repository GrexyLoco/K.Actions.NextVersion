# 🧪 Test Script für K.Actions.NextVersion

Write-Host "🚀 Testing K.Actions.NextVersion..." -ForegroundColor Cyan

# Test verschiedene Szenarien
$testCases = @(
    @{
        Name = "Feature Branch Test"
        BranchName = "feature/new-logging"
        CommitMessage = "Add enhanced logging functionality"
        ExpectedBump = "minor"
    },
    @{
        Name = "Bugfix Branch Test"
        BranchName = "bugfix/memory-leak"
        CommitMessage = "Fix memory leak in data processing"
        ExpectedBump = "patch"
    },
    @{
        Name = "Major Branch Test"
        BranchName = "major/api-rewrite"
        CommitMessage = "Complete API redesign"
        ExpectedBump = "major"
    },
    @{
        Name = "Breaking Change Override Test"
        BranchName = "bugfix/api-change"
        CommitMessage = "BREAKING: Change function signatures"
        ExpectedBump = "major"
    },
    @{
        Name = "Refactor Branch Test"
        BranchName = "refactor/code-cleanup"
        CommitMessage = "Refactor code structure"
        ExpectedBump = "patch"
    }
)

foreach ($test in $testCases) {
    Write-Host "`n📋 Running: $($test.Name)" -ForegroundColor Yellow
    Write-Host "   Branch: $($test.BranchName)" -ForegroundColor Gray
    Write-Host "   Commit: $($test.CommitMessage)" -ForegroundColor Gray
    Write-Host "   Expected: $($test.ExpectedBump)" -ForegroundColor Gray
    
    try {
        $result = & ".\Get-NextVersion.ps1" `
            -ManifestPath ".\TestModule.psd1" `
            -BranchName $test.BranchName `
            -CommitMessage $test.CommitMessage
        
        if ($result.BumpType -eq $test.ExpectedBump) {
            Write-Host "   ✅ PASS - Got: $($result.BumpType)" -ForegroundColor Green
        } else {
            Write-Host "   ❌ FAIL - Got: $($result.BumpType), Expected: $($test.ExpectedBump)" -ForegroundColor Red
        }
        
        Write-Host "   📊 Result: $($result.CurrentVersion) → $($result.NewVersion)" -ForegroundColor Cyan
    }
    catch {
        Write-Host "   💥 ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n🎉 Testing completed!" -ForegroundColor Green
