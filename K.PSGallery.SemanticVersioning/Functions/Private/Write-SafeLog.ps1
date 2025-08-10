function Write-SafeLog {
    <#
    .SYNOPSIS
        Safe logging function that uses K.PSGallery.LoggingModule if available, otherwise falls back to Write-Host.
    
    .DESCRIPTION
        This function provides safe logging capabilities by first attempting to use the K.PSGallery.LoggingModule
        functions, and falling back to Write-Host with appropriate colors if the logging module is not available.
    
    .PARAMETER Level
        The logging level (Debug, Info, Warning, Error, Fatal, TaskSuccess, TaskFailed)
    
    .PARAMETER Message
        The message to log
    
    .PARAMETER Context
        Additional context information (optional)
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Debug", "Info", "Warning", "Error", "Fatal", "TaskSuccess", "TaskFailed")]
        [string]$Level,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Context = ""
    )

    # Check if K.PSGallery.LoggingModule is available
    $loggingModuleAvailable = $false
    try {
        $loggingCommands = Get-Command -Module K.PSGallery.LoggingModule -ErrorAction SilentlyContinue
        if ($loggingCommands) {
            $loggingModuleAvailable = $true
        }
    }
    catch {
        # Module not available, will use fallback
    }

    if ($loggingModuleAvailable) {
        # Use the logging module functions
        try {
            switch ($Level) {
                "Debug" { Write-DebugLog -Message $Message -Context $Context }
                "Info" { Write-InfoLog -Message $Message -Context $Context }
                "Warning" { Write-WarningLog -Message $Message -Context $Context }
                "Error" { Write-ErrorLog -Message $Message -Context $Context }
                "Fatal" { Write-FatalLog -Message $Message -Context $Context }
                "TaskSuccess" { Write-TaskSuccessLog -Message $Message -Context $Context }
                "TaskFailed" { Write-TaskFailLog -Message $Message -Context $Context }
            }
            return
        }
        catch {
            # If logging module fails, fall through to fallback
        }
    }

    # Fallback to Write-Host with appropriate colors
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = "[$timestamp] [$($Level.ToUpper())] - "
    $logEntry = "$prefix$Message"
    
    switch ($Level) {
        "Debug" { 
            Write-Host $logEntry -ForegroundColor Gray
        }
        "Info" { 
            Write-Host $logEntry -ForegroundColor Blue
        }
        "Warning" { 
            Write-Warning $Message
        }
        "Error" { 
            Write-Host $logEntry -ForegroundColor Red
        }
        "Fatal" { 
            Write-Host $logEntry -ForegroundColor DarkRed
        }
        "TaskSuccess" { 
            Write-Host "✅ SUCCESS: $logEntry" -ForegroundColor Green
            Write-Host " =================================================" -ForegroundColor Green
        }
        "TaskFailed" { 
            Write-Host "❌ ERROR: $logEntry" -ForegroundColor Red
            Write-Host " xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" -ForegroundColor Red
        }
        default { 
            Write-Host $logEntry -ForegroundColor White
        }
    }

    # Add context information if provided
    if ($Context -and $Context.Trim() -ne "") {
        $indent = " " * $prefix.Length
        foreach ($line in $Context -split "`n") {
            Write-Host "$indent▶ $line" -ForegroundColor Gray
        }
    }
}
