# 🧪 Invoke-PesterTests.ps1
# Executes Pester tests and generates detailed reports

[CmdletBinding()]
param(
    [string]$TestPath = './K.PSGallery.SemanticVersioning/Tests',
    [string]$OutputPath = './TestResults.xml',
    [switch]$EnableCodeCoverage = $false
)

# Import Pester
Import-Module Pester -Force

# Configure Pester
Write-Host "⚙️ Configuring Pester..." -ForegroundColor Yellow
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = $TestPath
$pesterConfig.Run.PassThru = $true
$pesterConfig.Output.Verbosity = 'Detailed'
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputFormat = 'JUnitXml'  # JUnit XML format - compatible with test-reporter
$pesterConfig.TestResult.OutputPath = $OutputPath
$pesterConfig.CodeCoverage.Enabled = $EnableCodeCoverage.IsPresent

# Run tests
Write-Host "🚀 Starting Pester Tests..." -ForegroundColor Yellow
$testResults = Invoke-Pester -Configuration $pesterConfig

# Generate summary
Write-Host "📊 Test Summary:" -ForegroundColor Cyan
Write-Host "  Total Tests: $($testResults.TotalCount)" -ForegroundColor White
Write-Host "  Passed: $($testResults.PassedCount)" -ForegroundColor Green
Write-Host "  Failed: $($testResults.FailedCount)" -ForegroundColor Red
Write-Host "  Skipped: $($testResults.SkippedCount)" -ForegroundColor Yellow

# Set GitHub outputs for workflow consumption
if ($env:GITHUB_OUTPUT) {
    "total-tests=$($testResults.TotalCount)" >> $env:GITHUB_OUTPUT
    "passed-tests=$($testResults.PassedCount)" >> $env:GITHUB_OUTPUT
    "failed-tests=$($testResults.FailedCount)" >> $env:GITHUB_OUTPUT
    "skipped-tests=$($testResults.SkippedCount)" >> $env:GITHUB_OUTPUT
    "test-success=$($testResults.FailedCount -eq 0)" >> $env:GITHUB_OUTPUT
}

# Fail if tests failed
if ($testResults.FailedCount -gt 0) {
    Write-Host "❌ PESTER TESTS FAILED!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ ALL PESTER TESTS PASSED!" -ForegroundColor Green
    exit 0
}
