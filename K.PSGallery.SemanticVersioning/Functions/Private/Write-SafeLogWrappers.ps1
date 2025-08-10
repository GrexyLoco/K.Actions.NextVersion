function Write-SafeInfoLog {
    <#
    .SYNOPSIS
        Safe info logging wrapper
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Context = ""
    )
    
    Write-SafeLog -Level "Info" -Message $Message -Context $Context
}

function Write-SafeWarningLog {
    <#
    .SYNOPSIS
        Safe warning logging wrapper
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Context = ""
    )
    
    Write-SafeLog -Level "Warning" -Message $Message -Context $Context
}

function Write-SafeErrorLog {
    <#
    .SYNOPSIS
        Safe error logging wrapper
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Context = ""
    )
    
    Write-SafeLog -Level "Error" -Message $Message -Context $Context
}

function Write-SafeDebugLog {
    <#
    .SYNOPSIS
        Safe debug logging wrapper
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Context = ""
    )
    
    Write-SafeLog -Level "Debug" -Message $Message -Context $Context
}

function Write-SafeTaskSuccessLog {
    <#
    .SYNOPSIS
        Safe task success logging wrapper
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Context = ""
    )
    
    Write-SafeLog -Level "TaskSuccess" -Message $Message -Context $Context
}

function Write-SafeTaskFailLog {
    <#
    .SYNOPSIS
        Safe task failure logging wrapper
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Context = ""
    )
    
    Write-SafeLog -Level "TaskFailed" -Message $Message -Context $Context
}
