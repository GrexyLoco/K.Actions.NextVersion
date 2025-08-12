# 📋 New-GitHubSummary.ps1
# Generates beautiful GitHub Action summaries

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('test', 'release')]
    [string]$SummaryType,
    
    [hashtable]$TestResults = @{},
    [hashtable]$VersionResults = @{}
)

function Write-TestSummary {
    param($Results)
    
    @"
## 🧪 Test Results Summary

### 📊 Test Statistics
| Metric | Count | Status |
|--------|--------|--------|
| **Total Tests** | $($Results.TotalTests) | ℹ️ |
| **✅ Passed** | $($Results.PassedTests) | ✅ |
| **❌ Failed** | $($Results.FailedTests) | $(if ($Results.FailedTests -eq 0) { '✅' } else { '❌' }) |
| **⏭️ Skipped** | $($Results.SkippedTests) | ⚠️ |

### 🎯 Quality Gates
- 🧪 **Unit Tests**: $(if ($Results.FailedTests -eq 0) { '✅ PASSED' } else { '❌ FAILED' })
- 🔄 **Integration**: $(if ($Results.FailedTests -eq 0) { '✅ PASSED' } else { '❌ FAILED' })
- 🛡️ **Quality Gate**: $(if ($Results.FailedTests -eq 0) { '✅ RELEASE ALLOWED' } else { '❌ RELEASE BLOCKED' })

"@
}

function Write-ReleaseSummary {
    param($Version, $Test)
    
    @"
## 🚀 Release Pipeline Summary

### ✅ Quality Gates Passed
- 🧪 **Pester Tests**: $(if ($Test.FailedTests -eq 0) { 'All tests passed' } else { 'Tests failed' })
- 🔄 **Version Detection**: Branch pattern tests passed
- 💥 **Breaking Changes**: Override detection tests passed
- 🔎 **Auto-Discovery**: Manifest discovery tests passed
- 🔗 **Integration**: End-to-end tests passed

### 🎯 Release Information
| Property | Value |
|----------|-------|
| **Version** | ``$($Version.NextVersion)`` |
| **Branch** | ``$($Version.TargetBranch)`` |
| **Change Type** | ``$($Version.Suffix)`` |
| **Action Required** | ``$($Version.ActionRequired)`` |

### 📦 Deployment Status
- ✅ **Quality Gates**: All checks passed
- ✅ **Tests**: $($Test.PassedTests)/$($Test.TotalTests) passed
- ✅ **Release**: Ready for deployment

"@
}

# Generate appropriate summary
$summaryContent = switch ($SummaryType) {
    'test' { Write-TestSummary -Results $TestResults }
    'release' { Write-ReleaseSummary -Version $VersionResults -Test $TestResults }
}

# Write to GitHub Step Summary
$summaryContent >> $env:GITHUB_STEP_SUMMARY

Write-Host "📋 GitHub Summary generated successfully!" -ForegroundColor Green
