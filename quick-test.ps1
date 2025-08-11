# Quick PowerShell test to validate GitHub Action properties
$ModulePath = "c:\Users\gkump\source\repos\1d70f\K.Actions\K.Actions.NextVersion\K.PSGallery.SemanticVersioning\K.PSGallery.SemanticVersioning.psd1"

Write-Host "Importing module..." -ForegroundColor Yellow
Import-Module $ModulePath -Force

Write-Host "Testing Get-NextSemanticVersion..." -ForegroundColor Yellow
$result = Get-NextSemanticVersion -ManifestPath $ModulePath -BranchName "main"

Write-Host "`nResult properties:" -ForegroundColor Green
$result.PSObject.Properties | ForEach-Object {
    $value = if ($null -eq $_.Value) { "(null)" } elseif ($_.Value -eq "") { "(empty)" } else { $_.Value }
    Write-Host "  $($_.Name) = $value"
}

Write-Host "`nGitHub Action format:" -ForegroundColor Cyan
Write-Host "currentVersion=$($result.CurrentVersion)"
Write-Host "bumpType=$($result.BumpType)"  
Write-Host "newVersion=$($result.NewVersion)"
Write-Host "lastReleaseTag=$($result.LastReleaseTag)"
Write-Host "targetBranch=$($result.TargetBranch)"
Write-Host "suffix=$($result.Suffix)"
Write-Host "warning=$($result.Warning)"
Write-Host "actionRequired=$($result.ActionRequired)"
Write-Host "actionInstructions=$($result.ActionInstructions)"
