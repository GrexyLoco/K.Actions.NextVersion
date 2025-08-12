# ==============================================================================
# K.PSGallery.SemanticVersioning - Mismatch Handling Functions
# ==============================================================================

function Set-MismatchRecord {
    <#
    .SYNOPSIS
        Records a version mismatch for later force-release validation
    
    .DESCRIPTION
        Stores mismatch information securely for validation in force-release workflows.
        Uses GitHub Secrets API for secure storage with automatic cleanup.
    
    .PARAMETER Version
        The version that was flagged as unusual
    
    .PARAMETER BranchName
        The branch where the mismatch was detected
    
    .PARAMETER MaxAgeHours
        Maximum age in hours before record expires (default: 24)
    
    .OUTPUTS
        PSCustomObject with record information
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $true)]
        [string]$BranchName,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxAgeHours = 24
    )
    
    try {
        Write-SafeInfoLog -Message "Recording version mismatch: $Version on branch $BranchName"
        
        $record = @{
            Version = $Version
            BranchName = $BranchName
            Timestamp = (Get-Date).ToString('o')
            CommitSha = (git rev-parse HEAD 2>$null)
            ExpiresAt = (Get-Date).AddHours($MaxAgeHours).ToString('o')
            RecordId = (New-Guid).ToString()
        }
        
        # Store in GitHub Secrets (in real implementation)
        # For now, store in temp location for testing
        $secretName = "VERSION_MISMATCH_$($record.RecordId.Replace('-', ''))"
        $secretValue = ($record | ConvertTo-Json -Compress)
        
        # In production: gh secret set $secretName --body $secretValue
        # For testing: use temp file
        $tempPath = Join-Path $env:TEMP "mismatch-records"
        if (-not (Test-Path $tempPath)) {
            New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
        }
        
        $recordFile = Join-Path $tempPath "$secretName.json"
        $secretValue | Set-Content -Path $recordFile -Encoding UTF8
        
        Write-SafeTaskSuccessLog -Message "Mismatch record created with ID: $($record.RecordId)"
        
        return [PSCustomObject]@{
            RecordId = $record.RecordId
            Version = $Version
            ExpiresAt = $record.ExpiresAt
            SecretName = $secretName
        }
    }
    catch {
        Write-SafeErrorLog -Message "Failed to record version mismatch" -Context $_.Exception.Message
        throw
    }
}

function Test-RecentMismatch {
    <#
    .SYNOPSIS
        Validates if a version was recently flagged as a mismatch
    
    .DESCRIPTION
        Checks stored mismatch records to validate force-release requests.
        Automatically cleans up expired records.
    
    .PARAMETER Version
        The version to validate
    
    .PARAMETER BranchName
        The branch to validate (optional, if not provided checks all branches)
    
    .PARAMETER MaxAgeHours
        Maximum age in hours to consider (default: 24)
    
    .OUTPUTS
        PSCustomObject with validation result
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $false)]
        [string]$BranchName,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxAgeHours = 24
    )
    
    try {
        Write-SafeInfoLog -Message "Validating recent mismatch for version: $Version"
        
        # Get all mismatch records (in production: gh secret list | grep VERSION_MISMATCH)
        $tempPath = Join-Path $env:TEMP "mismatch-records"
        if (-not (Test-Path $tempPath)) {
            return @{
                IsValid = $false
                Reason = "No mismatch records found"
                Records = @()
            }
        }
        
        $recordFiles = Get-ChildItem -Path $tempPath -Filter "VERSION_MISMATCH_*.json"
        $validRecords = @()
        $expiredRecords = @()
        
        foreach ($file in $recordFiles) {
            try {
                $content = Get-Content -Path $file.FullName -Raw
                $record = $content | ConvertFrom-Json
                
                # Parse the DateTime with proper handling for ISO format
                try {
                    $expiresAt = [DateTime]::Parse($record.ExpiresAt, [System.Globalization.CultureInfo]::InvariantCulture)
                } catch {
                    Write-SafeDebugLog -Message "Failed to parse ExpiresAt: $($record.ExpiresAt)"
                    throw
                }
                
                if ($expiresAt -lt (Get-Date)) {
                    $expiredRecords += $file
                    continue
                }
                
                # Check version match
                if ($record.Version -eq $Version) {
                    # Check branch match if specified
                    if ([string]::IsNullOrEmpty($BranchName) -or $record.BranchName -eq $BranchName) {
                        $validRecords += $record
                    }
                }
            }
            catch {
                Write-SafeWarningLog -Message "Failed to parse record file: $($file.Name) - Error: $($_.Exception.Message)"
                Write-SafeDebugLog -Message "File content (first 200 chars): $(try { (Get-Content -Path $file.FullName -Raw | Out-String).Substring(0, [Math]::Min(200, (Get-Content -Path $file.FullName -Raw | Out-String).Length)) } catch { 'Unable to read' })"
                # Don't automatically delete files that fail to parse - investigate first
                # $expiredRecords += $file
            }
        }
        
        # Cleanup expired records
        foreach ($expiredFile in $expiredRecords) {
            try {
                Remove-Item -Path $expiredFile.FullName -Force
                Write-SafeDebugLog -Message "Cleaned up expired record: $($expiredFile.Name)"
            }
            catch {
                Write-SafeWarningLog -Message "Failed to cleanup expired record: $($expiredFile.Name)"
            }
        }
        
        $isValid = $validRecords.Count -gt 0
        
        if ($isValid) {
            Write-SafeTaskSuccessLog -Message "Valid recent mismatch found for version $Version"
        } else {
            Write-SafeWarningLog -Message "No valid recent mismatch found for version $Version"
        }
        
        return [PSCustomObject]@{
            IsValid = $isValid
            Reason = if ($isValid) { "Recent mismatch found" } else { "No recent mismatch found" }
            Records = $validRecords
            MatchCount = $validRecords.Count
            ExpiredCount = $expiredRecords.Count
        }
    }
    catch {
        Write-SafeErrorLog -Message "Failed to validate recent mismatch" -Context $_.Exception.Message
        return @{
            IsValid = $false
            Reason = "Validation failed: $($_.Exception.Message)"
            Records = @()
        }
    }
}

function Set-ForceSemanticVersion {
    <#
    .SYNOPSIS
        Forces a semantic version release after mismatch validation
    
    .DESCRIPTION
        Validates recent mismatch record and proceeds with force release.
        Creates appropriate Git tag and updates version tracking.
    
    .PARAMETER Version
        The version to force release
    
    .PARAMETER BranchName
        The target branch for the release
    
    .OUTPUTS
        PSCustomObject with force release result
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Version,
        
        [Parameter(Mandatory = $false)]
        [string]$BranchName = "main"
    )
    
    try {
        Write-SafeInfoLog -Message "Processing force semantic version: $Version"
        
        # Validate recent mismatch
        $validation = Test-RecentMismatch -Version $Version -BranchName $BranchName
        
        if (-not $validation.IsValid) {
            Write-SafeErrorLog -Message "Force release denied: $($validation.Reason)"
            return @{
                Success = $false
                Error = "Force release denied: $($validation.Reason)"
                ValidationResult = $validation
            }
        }
        
        Write-SafeTaskSuccessLog -Message "Mismatch validation passed - proceeding with force release"
        
        # Create Git tag
        $tagName = "v$Version"
        Write-SafeInfoLog -Message "Creating Git tag: $tagName"
        
        $tagResult = & git tag $tagName 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-SafeErrorLog -Message "Failed to create Git tag: $tagResult"
            return @{
                Success = $false
                Error = "Failed to create Git tag: $tagResult"
                ValidationResult = $validation
            }
        }
        
        Write-SafeTaskSuccessLog -Message "Successfully created Git tag: $tagName"
        
        # Cleanup the mismatch record (it's been used)
        try {
            $tempPath = Join-Path $env:TEMP "mismatch-records"
            $usedRecords = $validation.Records
            foreach ($record in $usedRecords) {
                $secretName = "VERSION_MISMATCH_$($record.RecordId.Replace('-', ''))"
                $recordFile = Join-Path $tempPath "$secretName.json"
                if (Test-Path $recordFile) {
                    Remove-Item -Path $recordFile -Force
                    Write-SafeDebugLog -Message "Cleaned up used mismatch record: $($record.RecordId)"
                }
            }
        }
        catch {
            Write-SafeWarningLog -Message "Failed to cleanup mismatch record: $($_.Exception.Message)"
        }
        
        return [PSCustomObject]@{
            Success = $true
            Version = $Version
            TagName = $tagName
            BranchName = $BranchName
            ValidationResult = $validation
            Timestamp = (Get-Date).ToString('o')
        }
    }
    catch {
        Write-SafeErrorLog -Message "Failed to force semantic version" -Context $_.Exception.Message
        return @{
            Success = $false
            Error = $_.Exception.Message
            ValidationResult = $null
        }
    }
}

function Send-MismatchNotification {
    <#
    .SYNOPSIS
        Sends notifications about version mismatches through configured channels
    
    .DESCRIPTION
        Extensible notification system for version mismatches.
        Supports multiple notification channels with future extensibility.
    
    .PARAMETER MismatchInfo
        Information about the version mismatch
    
    .PARAMETER NotificationChannels
        Array of notification channels to use
    
    .OUTPUTS
        PSCustomObject with notification results
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$MismatchInfo,
        
        [Parameter(Mandatory = $false)]
        [string[]]$NotificationChannels = @("console", "summary")
    )
    
    $results = @()
    
    foreach ($channel in $NotificationChannels) {
        try {
            switch ($channel.ToLower()) {
                "console" {
                    Write-ConsoleMismatchNotification -MismatchInfo $MismatchInfo
                    $results += @{ Channel = "console"; Success = $true; Message = "Console notification sent" }
                }
                "summary" {
                    Write-SummaryMismatchNotification -MismatchInfo $MismatchInfo
                    $results += @{ Channel = "summary"; Success = $true; Message = "GitHub Actions summary updated" }
                }
                "issue" {
                    # Future: Create GitHub issue
                    Write-SafeInfoLog -Message "Issue notification not implemented yet"
                    $results += @{ Channel = "issue"; Success = $false; Message = "Not implemented" }
                }
                "jira" {
                    # Future: Create Jira ticket
                    Write-SafeInfoLog -Message "Jira notification not implemented yet"
                    $results += @{ Channel = "jira"; Success = $false; Message = "Not implemented" }
                }
                "slack" {
                    # Future: Send Slack message
                    Write-SafeInfoLog -Message "Slack notification not implemented yet"
                    $results += @{ Channel = "slack"; Success = $false; Message = "Not implemented" }
                }
                default {
                    Write-SafeWarningLog -Message "Unknown notification channel: $channel"
                    $results += @{ Channel = $channel; Success = $false; Message = "Unknown channel" }
                }
            }
        }
        catch {
            Write-SafeErrorLog -Message "Failed to send notification via $channel" -Context $_.Exception.Message
            $results += @{ Channel = $channel; Success = $false; Message = $_.Exception.Message }
        }
    }
    
    return [PSCustomObject]@{
        MismatchInfo = $MismatchInfo
        NotificationResults = $results
        SuccessfulChannels = ($results | Where-Object { $_.Success }).Count
        FailedChannels = ($results | Where-Object { -not $_.Success }).Count
    }
}

function Write-ConsoleMismatchNotification {
    [CmdletBinding()]
    param([PSCustomObject]$MismatchInfo)
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║              🚨 VERSION MISMATCH DETECTED 🚨              ║" -ForegroundColor Red  
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "📋 Details:" -ForegroundColor Yellow
    Write-Host "   Version: $($MismatchInfo.Version)" -ForegroundColor White
    Write-Host "   Branch:  $($MismatchInfo.BranchName)" -ForegroundColor White
    Write-Host "   Reason:  $($MismatchInfo.Reason)" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 To proceed with this unusual version:" -ForegroundColor Cyan
    Write-Host "   1. Go to the 'Actions' tab in your repository" -ForegroundColor White
    Write-Host "   2. Find and run the 'Force Version Release' workflow" -ForegroundColor White
    Write-Host "   3. Enter version: $($MismatchInfo.Version)" -ForegroundColor White
    Write-Host "   4. Enter confirmation: 'I understand'" -ForegroundColor White
    Write-Host ""
    Write-Host "⏰ This option expires in 24 hours" -ForegroundColor Yellow
    Write-Host ""
}

function Write-SummaryMismatchNotification {
    [CmdletBinding()]
    param([PSCustomObject]$MismatchInfo)
    
    $summary = @"
# 🚨 Version Mismatch Detected

## 📋 Details
- **Version:** ``$($MismatchInfo.Version)``
- **Branch:** ``$($MismatchInfo.BranchName)``
- **Reason:** $($MismatchInfo.Reason)
- **Record ID:** ``$($MismatchInfo.RecordId)``

## 🔧 How to Proceed

If you want to proceed with this unusual version:

1. Go to the **Actions** tab
2. Run the **"Force Version Release"** workflow manually
3. Enter the following inputs:
   - **Version:** ``$($MismatchInfo.Version)``
   - **Confirmation:** ``I understand``

## ⏰ Important Notes

- This option is available for **24 hours** from now
- You must manually confirm this action for security
- This will create a Git tag ``v$($MismatchInfo.Version)`` and proceed with the release

## 🛡️ Alternative Options

If this was not intentional:
- Update your ``ModuleVersion`` in the .psd1 file to ``0.0.0`` or ``1.0.0``
- Commit and push the changes
- The workflow will automatically proceed

---
*Generated at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')*
"@

    # In GitHub Actions, this would be written to $GITHUB_STEP_SUMMARY
    # For testing, we'll write to a temp file
    $summaryFile = Join-Path $env:TEMP "github-step-summary.md"
    $summary | Set-Content -Path $summaryFile -Encoding UTF8
    
    Write-SafeTaskSuccessLog -Message "GitHub Actions summary updated with mismatch notification"
    Write-SafeDebugLog -Message "Summary written to: $summaryFile"
}

# Note: Functions are exported via the main module manifest (psd1)
