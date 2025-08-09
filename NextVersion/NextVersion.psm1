<#
Composer module: dot-source .ps1 implementation files to compose the module surface.
This enables splitting logic across multiple .ps1 files for extensibility.
#>
$files = @(
    'NextVersion.ps1'
)
foreach ($f in $files) {
    $path = Join-Path $PSScriptRoot $f
    if (Test-Path $path) { . $path } else { Write-Warning "Missing component: $f" }
}
