<#
.SYNOPSIS
    Discovers action name and type from action.yml.

.DESCRIPTION
    Parses action.yml to extract the action name and determine the action type
    (composite, docker, javascript). Sets GitHub Action outputs for use in workflows.

.OUTPUTS
    Sets GITHUB_OUTPUT variables: action-name, action-type

.EXAMPLE
    ./Discover-ActionName.ps1

.NOTES
    Platform-independent PowerShell script for GitHub Actions workflows.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Information "Discovering action metadata from action.yml"

# Find action.yml
$actionYml = Get-ChildItem -Path . -Filter 'action.yml' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $actionYml) {
    $actionYml = Get-ChildItem -Path . -Filter 'action.yaml' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
}

if (-not $actionYml) {
    Write-Error "No action.yml or action.yaml found in repository"
    exit 1
}

Write-Information "Found: $($actionYml.FullName)"

# Parse action.yml
$content = Get-Content -Path $actionYml.FullName -Raw

# Extract action name
$actionName = ''
if ($content -match 'name:\s*[''"]?([^''"\r\n]+)[''"]?') {
    $actionName = $Matches[1].Trim()
}

if (-not $actionName) {
    # Fallback to repository name pattern
    $actionName = (Get-Item .).Name
}

# Determine action type
$actionType = 'unknown'
if ($content -match 'runs:\s*[\r\n]+\s*using:\s*[''"]?composite[''"]?') {
    $actionType = 'composite'
} elseif ($content -match 'runs:\s*[\r\n]+\s*using:\s*[''"]?docker[''"]?') {
    $actionType = 'docker'
} elseif ($content -match 'runs:\s*[\r\n]+\s*using:\s*[''"]?node') {
    $actionType = 'javascript'
}

Write-Information "Action Name: $actionName"
Write-Information "Action Type: $actionType"

# Set outputs
"action-name=$actionName" >> $env:GITHUB_OUTPUT
"action-type=$actionType" >> $env:GITHUB_OUTPUT

Write-Information "✅ Action metadata discovered successfully"
