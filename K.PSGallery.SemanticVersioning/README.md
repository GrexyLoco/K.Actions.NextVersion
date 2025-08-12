# K.PSGallery.SemanticVersioning

> 🎯 **Intelligent Git-based Semantic Versioning for PowerShell Modules**

A comprehensive PowerShell module that automatically calculates the next semantic version for your PowerShell projects by analyzing Git repository history, branch naming patterns, and commit message conventions. Perfect for beginners and experts alike!

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/K.PSGallery.SemanticVersioning)](https://www.powershellgallery.com/packages/K.PSGallery.SemanticVersioning)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/K.PSGallery.SemanticVersioning)](https://www.powershellgallery.com/packages/K.PSGallery.SemanticVersioning)
[![License](https://img.shields.io/github/license/GrexyLoco/K.Actions.NextVersion)](https://github.com/GrexyLoco/K.Actions.NextVersion/blob/main/LICENSE)

## 🚀 What This Module Does

This module takes the guesswork out of versioning! Instead of manually deciding whether your next release should be `1.2.3` or `1.3.0`, it analyzes your Git repository and automatically suggests the correct semantic version based on:

- **🔍 Git History Analysis**: Looks at merged branches and commit messages since your last release
- **🏷️ Branch Pattern Detection**: Understands that `feature/` branches add new functionality (minor bump)
- **💬 Commit Message Keywords**: Recognizes keywords like `BREAKING`, `FEATURE`, `FIX` in your commits
- **🎭 Pre-release Support**: Creates alpha/beta versions when you're testing new features
- **🔄 Smart First Release**: Handles brand-new projects intelligently
- **⚠️ Error Prevention**: Gives clear guidance when something looks unusual
- **🎯 GitHub Actions Ready**: Works perfectly in automated CI/CD pipelines
- **🖥️ Local Development**: Great for checking versions before you commit

## 📦 Installation

### Quick Install from PowerShell Gallery (Recommended)
```powershell
Install-Module -Name K.PSGallery.SemanticVersioning -Scope CurrentUser
```

### Manual Installation for Development
```powershell
# Clone the repository and import locally
git clone https://github.com/GrexyLoco/K.Actions.NextVersion.git
Import-Module .\K.Actions.NextVersion\K.PSGallery.SemanticVersioning
```

## ⚠️ What You Need

### 📋 **Repository Requirements**
- **One PowerShell module per repository** - The module expects to find a single `.psd1` manifest file
- **Git repository** - Your project must be a Git repository with some commit history
- **Optional Git tags** - If you have existing releases tagged like `v1.2.3`, the module will use them as reference points

### 🛠️ **System Requirements**
- **PowerShell 5.1+** or **PowerShell Core 6.0+**
- **Git CLI** - Must be available in your system PATH
- **Internet connection** - For automatic dependency installation from PowerShell Gallery

## 🎯 Quick Start Guide

### 🆕 First Time Use - Just Get Your Next Version
```powershell
# Navigate to your PowerShell module directory
cd C:\YourModule

# Import the module
Import-Module K.PSGallery.SemanticVersioning

# Get your next version (that's it!)
$result = Get-NextSemanticVersion

# See the results
Write-Host "Your current version: $($result.CurrentVersion)"
Write-Host "Suggested next version: $($result.NewVersion)"
Write-Host "Type of change detected: $($result.BumpType)"
```

### 🎯 If You Have a Specific Manifest File
```powershell
# If your .psd1 file isn't in the current directory or has a specific name
$result = Get-NextSemanticVersion -ManifestPath ".\MySpecialModule.psd1"
```

## 🔧 Main Functions Explained

### `Get-NextSemanticVersion` - The Main Function

This is the primary function that does all the work. It analyzes your Git repository and calculates what your next version should be.

**Parameters you can use:**
- `ManifestPath` - Path to your .psd1 file (finds it automatically if not specified)
- `BranchName` - Your current branch (gets it from Git if not specified)
- `TargetBranch` - Main branch to compare against (usually main/master)

**What you get back:**
```powershell
# Example result object
[PSCustomObject]@{
    CurrentVersion = "1.2.3"           # Version from your .psd1 file
    BumpType = "minor"                 # What type of change was detected
    NewVersion = "1.3.0"               # Suggested next version
    LastReleaseTag = "v1.2.3"          # Your last Git release tag
    TargetBranch = "main"              # Branch that was analyzed
    Suffix = ""                        # Alpha/beta suffix if any
    Warning = ""                       # Any warnings about your version
    ActionRequired = $false            # Whether you need to fix something
    ActionInstructions = ""            # What to do if action is required
}
```

### `Get-FirstSemanticVersion` - For Brand New Projects

This function is automatically called when your repository has no Git tags yet (first release). It analyzes your entire Git history to suggest an appropriate starting version.

## 📋 Branch Naming Conventions

The way you name your Git branches influences what type of version bump is suggested. This follows common Git workflow patterns that many developers already use.

| Branch Pattern | Version Bump | Why? | Example |
|---|---|---|---|
| `feature/*`, `feat/*` | **Minor** | New functionality added | `feature/user-login` → 1.2.0 → 1.3.0 |
| `bugfix/*`, `fix/*`, `hotfix/*` | **Patch** | Bug fixes or small improvements | `bugfix/memory-leak` → 1.2.3 → 1.2.4 |
| `major/*` | **Major** | Breaking changes or major overhauls | `major/new-api` → 1.2.3 → 2.0.0 |
| `refactor/*` | **Patch** | Code cleanup without new features | `refactor/cleanup` → 1.2.3 → 1.2.4 |
| `main`, `master`, `develop` | **Patch** | Default safe increment | `main` → 1.2.3 → 1.2.4 |
| Other patterns | **Patch** | When in doubt, safest option | `my-special-branch` → 1.2.3 → 1.2.4 |

**💡 Pro Tip:** Even if your branch suggests a patch, commit message keywords can override this to suggest a higher bump!

## 💬 Commit Message Keywords

Your commit messages can override branch-based suggestions. The module looks for specific keywords in your commit history to understand what kind of changes you've made.

**High Priority Keywords (override branch patterns):**

| Keywords | Version Bump | When to Use | Example |
|---|---|---|---|
| `BREAKING`, `MAJOR` | **Major (x.y.z → x+1.0.0)** | When you break backward compatibility | "BREAKING: Remove deprecated API methods" |
| `FEATURE`, `MINOR`, `FEAT` | **Minor (x.y.z → x.y+1.0)** | When adding new features | "FEATURE: Add OAuth2 authentication" |
| `PATCH`, `FIX`, `BUGFIX`, `HOTFIX` | **Patch (x.y.z → x.y.z+1)** | When fixing bugs | "FIX: Resolve memory leak in parser" |

**🧪 Alpha/Beta Pre-release Suffixes:**

When you're testing new features, you can add `-ALPHA` or `-BETA` to your keywords:

- `BREAKING-ALPHA` → Creates `2.0.0-alpha.1` instead of `2.0.0`
- `FEATURE-BETA` → Creates `1.3.0-beta.1` instead of `1.3.0`
- `FIX-ALPHA`, `PATCH-BETA`, etc. - All work the same way

**🏆 Priority Rules for Multiple Keywords:**
- If commits contain both `alpha` and `beta` keywords, `beta` wins (beta is considered more stable)
- Example: `feat-alpha` + `fix-beta` in same release → Results in `1.3.0-beta.1`
- Priority order: `beta` > `alpha`

## 🔄 First Release Logic

The module uses **hybrid first release logic** for repositories without existing Git tags:

## 🆕 Repository ohne Tags (Erste Nutzung)

Wenn noch keine Git-Tags existieren, analysiert das Modul die **komplette Repository-Historie**:

### 1. **PSD1 Version Validation**
- **Standard Versionen** (`0.0.0`, `1.0.0`): ✅ Automatisch verarbeitet
- **Ungewöhnliche Versionen** (`3.5.2`, etc.): ⚠️ Benötigt Bestätigung oder `-ForceFirstRelease`

### 2. **Komplette Git-History Analyse**
```powershell
# Analysiert ALLE Commits im Repository (nicht nur seit letztem Tag)
$commits = git log --oneline --all

# Sucht nach Keywords in Commit-Messages:
# "BREAKING|MAJOR|breaking change" → major bump
# "FEATURE|MINOR|feat:|feature:"   → minor bump
# Default                          → patch bump
```

### 3. **Branch Pattern Detection**
```powershell
# Parallel zur Commit-Analyse:
# feature/ oder feat/    → minor bump
# major/                → major bump  
# bugfix/ oder fix/     → patch bump
# main/master           → patch bump (default)
```

### 4. **Höchste Priorität gewinnt**
Das Modul kombiniert beide Analysen und wählt den **höheren Bump-Type**:
```powershell
$finalBumpType = Get-HigherBumpType -BumpType1 $gitBumpType -BumpType2 $branchBumpType
# major > minor > patch
```

### Standard Versions (Automatic)
- `0.0.0` → Uses as base, applies full Git history analysis
- `1.0.0` → Uses as base, applies full Git history analysis

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

### 🎯 Beispiele für Repository ohne Tags

#### **Beispiel 1: Neues Projekt**
```yaml
Repository: Frisches Projekt, keine Tags
PSD1: ModuleVersion = '1.0.0'
Branch: feature/authentication
Commits: "Add OAuth2 support", "Implement JWT tokens"
→ Result: 1.0.0 + minor bump = 1.1.0
```

#### **Beispiel 2: Branch + Commit Keywords**
```yaml
Repository: Keine Tags vorhanden
PSD1: ModuleVersion = '0.0.0'  
Branch: bugfix/security-fix
Commits: "BREAKING: Remove deprecated API"
→ Result: 0.0.0 + major bump = 1.0.0 (BREAKING gewinnt über bugfix/)
```

#### **Beispiel 3: Migration mit Force**
```yaml
Repository: Bestehender Code, keine Tags
PSD1: ModuleVersion = '2.3.1'
Branch: main
Flag: -ForceFirstRelease
→ Result: 2.3.1 + patch bump = 2.3.2
```

## 🎯 GitHub Actions Integration

This module is designed to work seamlessly with the **K.Actions.NextVersion** GitHub Action:

```yaml
- name: Calculate Next Version
  id: version
  uses: GrexyLoco/K.Actions.NextVersion@v1
  with:
    manifestPath: './MyModule.psd1'

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
