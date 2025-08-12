# 🧪 Setup-PesterEnvironment.ps1
# Configures Pester testing environment for GitHub Actions

[CmdletBinding()]
param(
    [string]$TestPath = './K.PSGallery.SemanticVersioning/Tests',
    [string]$OutputPath = './TestResults.xml'
)

Write-Host "🔧 Setting up Pester Environment..." -ForegroundColor Cyan

# Install Pester module if not available
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host "📦 Installing Pester module..." -ForegroundColor Yellow
    Install-Module -Name Pester -Scope CurrentUser -Force -SkipPublisherCheck
} else {
    Write-Host "✅ Pester module already available" -ForegroundColor Green
}

# Show environment information
Write-Host "💡 Environment Information:" -ForegroundColor Cyan
Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor White
Write-Host "  Pester Version: $((Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1).Version)" -ForegroundColor White
Write-Host "  Test Path: $TestPath" -ForegroundColor White
Write-Host "  Output Path: $OutputPath" -ForegroundColor White

Write-Host "✅ Pester Environment Ready!" -ForegroundColor Green
