@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'K.PSGallery.SemanticVersioning.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.1'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-1234-567890abcdef'

    # Author of this module
    Author = 'K.PSGallery'

    # Company or vendor of this module
    CompanyName = 'K.PSGallery'

    # Copyright statement for this module
    Copyright = '(c) 2025 K.PSGallery. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Semantic Versioning module for PowerShell projects with Git-based release analysis, branch pattern detection, and first release hybrid logic.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Get-NextSemanticVersion',
        'Get-FirstSemanticVersion'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('SemanticVersioning', 'SemVer', 'Git', 'Release', 'Versioning', 'PowerShell', 'CI', 'CD', 'GitHub', 'Actions')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/GrexyLoco/K.Actions.NextVersion/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/GrexyLoco/K.Actions.NextVersion'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
## Version 1.0.0
- Initial release of K.PSGallery.SemanticVersioning module
- Git-based semantic version analysis
- Branch pattern detection (feature/, bugfix/, major/, etc.)
- Commit message keyword analysis (BREAKING, MAJOR, FEATURE, etc.)
- Hybrid first release logic with PSD1 validation
- Structured error handling for unusual first release versions
- Support for Alpha/Beta versioning suffixes
- Compatible with GitHub Actions and local development
'@

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}
