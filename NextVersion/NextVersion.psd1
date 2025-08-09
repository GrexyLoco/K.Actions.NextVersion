@{
    RootModule        = 'NextVersion.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '0c9b1b75-7f0a-4a8f-9c0b-1b6a0d9e3c6d'
    Author            = 'GrexyLoco'
    CompanyName       = ''
    Copyright        = '(c) GrexyLoco. All rights reserved.'
    Description       = 'Release-based semantic versioning utilities for CI/CD.'
    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Get-NextVersion'
        'Get-ReleaseVersionBumpType'
        'Get-LatestReleaseTag'
        'Get-TargetBranch'
        'Get-VersionBumpType'
    'Update-Version'
    )
    CmdletsToExport   = @()
    AliasesToExport   = @()
    VariablesToExport = @()

    PrivateData = @{ }
}
