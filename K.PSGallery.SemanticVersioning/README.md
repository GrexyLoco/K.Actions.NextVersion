# K.PSGallery.SemanticVersioning

> 🎯 **Git-based Semantic Versioning for PowerShell Modules**

A comprehensive PowerShell module that provides intelligent semantic versioning based on Git repository analysis, branch naming patterns, and commit message conventions.

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/K.PSGallery.SemanticVersioning)](https://www.powershellgallery.com/packages/K.PSGallery.SemanticVersioning)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/K.PSGallery.SemanticVersioning)](https://www.powershellgallery.com/packages/K.PSGallery.SemanticVersioning)
[![License](https://img.shields.io/github/license/GrexyLoco/K.Actions.NextVersion)](https://github.com/GrexyLoco/K.Actions.NextVersion/blob/main/LICENSE)

## 🚀 Features

- **🔍 Git History Analysis**: Automatically analyzes merged branches and commit messages
- **🏷️ Branch Pattern Detection**: Supports `feature/`, `bugfix/`, `major/`, `refactor/` patterns
- **💬 Commit Message Keywords**: Detects `BREAKING`, `MAJOR`, `FEATURE`, `PATCH`, etc.
- **🎭 Alpha/Beta Support**: Handles pre-release versions with suffixes
- **🔄 Hybrid First Release Logic**: Smart handling of initial releases
- **⚠️ Structured Error Handling**: Actionable guidance for unusual scenarios
- **🎯 GitHub Actions Ready**: Perfect integration with CI/CD pipelines
- **🖥️ Local Development**: Works great for manual version planning

## 📦 Installation

### From PowerShell Gallery
```powershell
Install-Module -Name K.PSGallery.SemanticVersioning -Scope CurrentUser
```

### Manual Installation
```powershell
# Clone and import locally
git clone https://github.com/GrexyLoco/K.Actions.NextVersion.git
Import-Module .\K.Actions.NextVersion\K.PSGallery.SemanticVersioning
```

## 🎯 Quick Start

### Basic Usage
```powershell
# Analyze current repository for next version
$result = Get-NextSemanticVersion

Write-Host "Current: $($result.CurrentVersion)"
Write-Host "New Version: $($result.NewVersion)"
Write-Host "Bump Type: $($result.BumpType)"
```

### With Specific Manifest
```powershell
$result = Get-NextSemanticVersion -ManifestPath ".\MyModule.psd1"
```

### Force First Release (Migration Scenarios)
```powershell
$result = Get-NextSemanticVersion -ForceFirstRelease
```

## 🔧 Functions

### `Get-NextSemanticVersion`
Main function that analyzes Git history and determines the next semantic version.

**Parameters:**
- `ManifestPath` - Path to .psd1 file (auto-discovery if not specified)
- `BranchName` - Current branch name (uses `$env:GITHUB_REF_NAME` if available)
- `TargetBranch` - Target branch for analysis (auto-discovery if not specified)  
- `ForceFirstRelease` - Skip validation for unusual first release versions

**Returns:**
```powershell
[PSCustomObject]@{
    CurrentVersion = "1.2.3"
    BumpType = "minor"
    NewVersion = "1.3.0"
    LastReleaseTag = "v1.2.3"
    TargetBranch = "main"
    Suffix = ""
    Warning = ""
    ActionRequired = $false
    ActionInstructions = ""
}
```

### `Test-FirstReleaseVersion`
Validates first release versions and provides structured guidance.

**Parameters:**
- `currentVersion` - Version from PSD1 manifest
- `forceFirstRelease` - Skip validation flag

## 📋 Branch Naming Conventions

| Branch Pattern | Version Bump | Example |
|---|---|---|
| `feature/*` | Minor | `feature/new-logging` → 1.2.0 → 1.3.0 |
| `bugfix/*` | Patch | `bugfix/fix-typo` → 1.2.3 → 1.2.4 |
| `major/*` | Major | `major/breaking-change` → 1.2.3 → 2.0.0 |
| `refactor/*` | Patch | `refactor/cleanup` → 1.2.3 → 1.2.4 |
| Other patterns | Patch | `hotfix/urgent` → 1.2.3 → 1.2.4 |

## 💬 Commit Message Keywords

**High Priority (override branch patterns):**

| Keywords | Version Bump | Example |
|---|---|---|
| `BREAKING`, `MAJOR` | Major | "BREAKING: Remove deprecated API" |
| `FEATURE`, `MINOR`, `FEAT` | Minor | "FEATURE: Add new authentication" |
| `PATCH`, `FIX`, `BUGFIX`, `HOTFIX` | Patch | "FIX: Resolve memory leak" |

**Alpha/Beta Suffixes:**
- `BREAKING-ALPHA` → 2.0.0-alpha
- `FEATURE-BETA` → 1.3.0-beta

## 🔄 First Release Logic

The module uses **hybrid first release logic** for repositories without existing tags:

### Standard Versions (Automatic)
- `0.0.0` → Uses as base, applies Git history analysis
- `1.0.0` → Uses as base, applies Git history analysis

### Unusual Versions (Guidance Required)
For versions like `3.5.2`, the module provides structured guidance:

```
🔍 UNUSUAL FIRST RELEASE VERSION DETECTED

Current PSD1 version: 3.5.2

📋 CHOOSE YOUR APPROACH:

Option 1 - Fresh Start (Recommended for new projects):
   • Update your .psd1 file: ModuleVersion = '0.0.0' or '1.0.0'
   
Option 2 - Project Migration (For existing projects):
   • Use -ForceFirstRelease flag to proceed with current version
   
Option 3 - Reset to Standard Version:
   • Update .psd1 to ModuleVersion = '1.0.0'
```

## 🎯 GitHub Actions Integration

This module is designed to work seamlessly with the **K.Actions.NextVersion** GitHub Action:

```yaml
- name: Calculate Next Version
  id: version
  uses: GrexyLoco/K.Actions.NextVersion@v1
  with:
    manifestPath: './MyModule.psd1'
    forceFirstRelease: false

- name: Use Version
  run: |
    echo "New version: ${{ steps.version.outputs.newVersion }}"
    echo "Bump type: ${{ steps.version.outputs.bumpType }}"
```

## 🧪 Testing

Run the included Pester tests:

```powershell
# Run all tests
Invoke-Pester -Path .\Tests\

# Run specific test categories
Invoke-Pester -Path .\Tests\ -TagFilter "Unit"
```

## 📈 Examples

### Local Development Workflow
```powershell
# Check what the next version would be
$version = Get-NextSemanticVersion
Write-Host "Next release would be: $($version.NewVersion)"

# Analyze specific branch
$version = Get-NextSemanticVersion -BranchName "feature/new-api"
Write-Host "Feature branch would bump to: $($version.NewVersion)"
```

### Migration from Existing Project
```powershell
# For projects with existing version history
$version = Get-NextSemanticVersion -ForceFirstRelease
Write-Host "Migrated version: $($version.NewVersion)"
```

### CI/CD Pipeline Usage
```powershell
# In a build script
$version = Get-NextSemanticVersion

if ($version.ActionRequired) {
    Write-Error $version.ActionInstructions
    exit 1
}

# Update manifest with new version
$manifestPath = "MyModule.psd1"
(Get-Content $manifestPath) -replace "ModuleVersion = '.*'", "ModuleVersion = '$($version.NewVersion)'" | Set-Content $manifestPath
```

## 🔗 Related Projects

- **[K.Actions.NextVersion](https://github.com/GrexyLoco/K.Actions.NextVersion)** - GitHub Action wrapper
- **[K.PSGallery.LoggingModule](https://www.powershellgallery.com/packages/K.PSGallery.LoggingModule)** - Logging module for PowerShell

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/GrexyLoco/K.Actions.NextVersion/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/GrexyLoco/K.Actions.NextVersion/discussions)
- 📧 **Email**: Support via GitHub

---

**Made with ❤️ for the PowerShell community**
