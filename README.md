# 🚀 K.Actions.NextVersion

## 🌟 Release-basierte Semantic Versioning für PowerShell Module

[![GitHub Release](https://img.shields.io/github/v/release/GrexyLoco/K.Actions.NextVersion)](https://github.com/GrexyLoco/K.Actions.NextVersion/releases)
[![License](https://img.shields.io/github/license/GrexyLoco/K.Actions.NextVersion)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Pester Tests](https://img.shields.io/badge/Tests-Pester-green.svg)](Tests/)

**Die intelligenteste GitHub Action für automatisches Semantic Versioning von PowerShell-Modulen!** 

Vergiss manuell verwaltete Versionsnummern - diese Action analysiert **nur bei Releases** (Push/Merge in den Hauptbranch) alle seit dem letzten Release eingegangenen Branches und bestimmt die perfekte nächste Version.

---

## 🎯 Das Problem, das wir lösen

**Ohne diese Action:**
- ❌ Manuelles Versionieren bei jedem Release
- ❌ Vergessene Version-Bumps führen zu Chaos
- ❌ Inkonsistente Versioning-Strategien im Team  
- ❌ Aufwändige Code-Reviews für Versionsnummern
- ❌ Per-Commit-Versioning führt zu Versions-Inflation

**Mit K.Actions.NextVersion:**
- ✅ **Release-basierte Analyse** - Nur bei tatsächlichen Releases
- ✅ **Intelligente Merge-Commit-Analyse** seit letztem Git-Tag
- ✅ **Vollautomatisch** - Kein manueller Eingriff nötig
- ✅ **Team-freundlich** - Jeder kann nach bekannten Konventionen arbeiten
- ✅ **Semantic Versioning konform** - Professionelle Versionierung

---

## 📋 Wie es funktioniert

### 🔍 **Release-basierte Analyse (Das Geheimnis)**

Anstatt jeden Commit zu analysieren, wartet diese Action auf **echte Releases**:

1. **Trigger:** Push oder Merge in den Hauptbranch (main/master)
2. **Git-Tag-Discovery:** Findet automatisch den höchsten Semantic Version Tag
3. **Merge-Analyse:** `git log --merges --since="v1.2.3"` analysiert alle Merge-Commits seit letztem Release
4. **Intelligente Bewertung:** Extrahiert Branch-Namen und Commit-Messages aus Merges
5. **Version-Bump:** Bestimmt den höchsten gefundenen Bump-Typ (major > minor > patch)

**Warum Merge-basiert?** 
- ✅ Analysiert nur abgeschlossene Features (keine Work-in-Progress-Commits)
- ✅ Berücksichtigt alle eingegangenen Branches seit letztem Release
- ✅ Vermeidet Versions-Inflation durch Zwischenstände
- ✅ Cherry-Picks werden automatisch erfasst (sind auch Merges)

### 🏷️ **Semantic Versioning in Aktion**

```
v1.2.3 → Letztes Release (Git Tag)
   ↓
[Merge] feature/user-auth     → Minor (Neue Funktion)
[Merge] bugfix/login-fix      → Patch (Bugfix)  
[Merge] major/api-rewrite     → Major (Breaking Change)
   ↓
v2.0.0 → Neues Release (Major gewinnt!)
```

---

## 🎨 Branch-Naming-Konventionen

Diese Action versteht deine Branching-Strategie automatisch:

###  **Minor Version (X.Y.0) - Neue Features**
```bash
feature/user-authentication  # Neue Login-Funktion
feature/advanced-logging     # Erweiterte Logging-Capabilities
feature/export-pdf          # PDF-Export hinzufügen
```

### 🟢 **Patch Version (X.Y.Z) - Bugfixes & Refactoring**
```bash
bugfix/memory-leak          # Speicher-Leck beheben
bugfix/validation-error     # Validierungsfehler fixen
refactor/code-cleanup       # Code-Bereinigung
refactor/performance        # Performance-Optimierung
hotfix/security-patch       # Kritischer Security-Fix
```

**Case-Insensitive:** `FEATURE/`, `Feature/`, `feature/` funktionieren alle gleich!

---

## 💬 Commit-Message-Override

**Commit-Messages haben IMMER Vorrang!** Perfekt für Ausnahmen und spezielle Releases:

### 🔥 **Breaking Changes forcieren**
```bash
git commit -m "BREAKING: Remove deprecated login API"
git commit -m "MAJOR: Change configuration file format"

# Mit Alpha/Beta-Kennzeichnung:
git commit -m "BREAKING-ALPHA: New API structure (testing phase)"
git commit -m "MAJOR-BETA: Complete rewrite (beta release)"
```

### ⭐ **Features explizit markieren**  
```bash
git commit -m "FEAT: Add OAuth2 authentication support"
git commit -m "FEATURE: Implement advanced search filters"
git commit -m "MINOR: Add configuration validation"

# Mit Alpha/Beta-Kennzeichnung:
git commit -m "FEAT-ALPHA: Experimental search feature"
git commit -m "FEATURE-BETA: Advanced logging (beta)"
```

### 🛠️ **Patches und Fixes**
```bash
git commit -m "FIX: Resolve null reference exception"
git commit -m "BUGFIX: Handle empty input gracefully"  
git commit -m "HOTFIX: Critical security vulnerability"
git commit -m "PATCH: Update documentation links"

# Mit Alpha/Beta-Kennzeichnung:
git commit -m "FIX-ALPHA: Experimental memory optimization"
git commit -m "HOTFIX-BETA: Security patch (testing)"
```

**Priorität-System:** `MAJOR/BREAKING > MINOR/FEAT > PATCH/FIX`

**Alpha/Beta-Releases:**
- 📦 **-ALPHA:** Wird zu `1.3.0-alpha` (experimentelle Features)
- 🧪 **-BETA:** Wird zu `1.3.0-beta` (testing phase)
- ✅ **Normal:** Wird zu `1.3.0` (stable release)

---

## 🔧 Eingaben (Inputs)

| Parameter | Beschreibung | Erforderlich | Standard | Beispiel |
|-----------|--------------|--------------|----------|----------|
| `manifestPath` | Pfad zur PowerShell-Manifest-Datei (`.psd1`) | ❌ | Auto-Discovery | `"./MyModule/MyModule.psd1"` |
| `branchName` | Git-Branch-Name für Analyse | ❌ | `${{ github.ref_name }}` | `"main"` |
| `commitMessage` | Commit-Message für Keyword-Analyse (Legacy) | ❌ | `""` | `"FEAT: Add new feature"` |
| `targetBranch` | Ziel-Branch für Release-Analyse | ❌ | Auto-Discovery | `"main"` |

### 🔍 **Auto-Discovery Features**

**Manifest-Discovery:**
```powershell
# Sucht automatisch nach *.psd1 Dateien:
MyProject/
├── src/MyModule/MyModule.psd1  ✅ Gefunden!
├── tests/TestModule.psd1       ⚠️  Warnung bei mehreren
└── docs/                       
```

**Target-Branch-Discovery:**
```powershell
# Intelligent Branch Detection:
1. git symbolic-ref refs/remotes/origin/HEAD  # GitHub Default
2. Verfügbare Branches: main, master, release, develop
3. Fallback: 'main'
```

---

## 📤 Ausgaben (Outputs)

| Output | Beschreibung | Beispiel | Verwendung |
|--------|--------------|----------|------------|
| `currentVersion` | Aktuelle Version aus Manifest | `"1.2.3"` | Logging, Release Notes |
| `bumpType` | Art des Version-Bumps | `"minor"` | Conditional Steps |
| `newVersion` | Berechnete neue Version | `"1.3.0"` | **Hauptoutput für Updates** |
| `lastReleaseTag` | Letzter Git Release-Tag | `"v1.2.3"` | Release Notes, Changelogs |
| `targetBranch` | Verwendeter Ziel-Branch | `"main"` | Debugging, Validation |

---

## 🚀 Schnellstart - In 5 Minuten einsatzbereit

### 1️⃣ **Einfachste Verwendung (Zero Config)**

```yaml
name: Auto Version
on:
  push:
    branches: [ main, master ]

jobs:
  version:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # ⚠️ Wichtig für Git-Tag-Analyse!
          
      - name: Calculate Next Version
        id: version
        uses: GrexyLoco/K.Actions.NextVersion@v1
        
      - name: Show Result  
        run: |
          echo "Current: ${{ steps.version.outputs.currentVersion }}"
          echo "Bump Type: ${{ steps.version.outputs.bumpType }}"
          echo "New Version: ${{ steps.version.outputs.newVersion }}"
```

### 2️⃣ **Erweiterte Konfiguration**

```yaml
- name: Calculate Next Version
  id: version
  uses: GrexyLoco/K.Actions.NextVersion@v1
  with:
    manifestPath: './src/MyModule/MyModule.psd1'
    targetBranch: 'main'
```

### 3️⃣ **Vollständiger Release-Workflow**

```yaml
name: PowerShell Module Release
on:
  push:
    branches: [ main ]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          
      - name: Calculate Next Version
        id: version
        uses: GrexyLoco/K.Actions.NextVersion@v1
        
      - name: Update Module Manifest
        run: |
          $manifestPath = "${{ steps.version.outputs.manifestPath }}"
          $newVersion = "${{ steps.version.outputs.newVersion }}"
          
          # Update PowerShell Module Version
          Update-ModuleManifest -Path $manifestPath -ModuleVersion $newVersion
        shell: pwsh
        
      - name: Create Git Tag
        if: steps.version.outputs.bumpType != 'none'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git tag "v${{ steps.version.outputs.newVersion }}"
          git push origin "v${{ steps.version.outputs.newVersion }}"
          
      - name: Create GitHub Release
        if: steps.version.outputs.bumpType != 'none'
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: "v${{ steps.version.outputs.newVersion }}"
          release_name: "Release v${{ steps.version.outputs.newVersion }}"
          body: |
            ## Changes since ${{ steps.version.outputs.lastReleaseTag }}
            
            **Version Bump:** ${{ steps.version.outputs.bumpType }}
            **Previous Version:** ${{ steps.version.outputs.currentVersion }}
            **New Version:** ${{ steps.version.outputs.newVersion }}
```

---

## 🎮 Anwendungsbeispiele

### 🌟 **Szenario 1: Feature-Entwicklung**

**Entwickler-Workflow:**
```bash
# Feature Branch erstellen
git checkout -b feature/user-authentication
git commit -m "Implement OAuth2 login system"
git commit -m "Add user role management"
git push origin feature/user-authentication

# Pull Request erstellen und mergen in main
# → Action erkennt: feature/* = Minor Version Bump
```

**Ergebnis:** `1.2.3` → `1.3.0` ✅

### 🔥 **Szenario 2: Breaking Change Override**

**Entwickler-Workflow:**
```bash
# Breaking Change per Commit-Message forcieren
git checkout -b bugfix/api-signature
git commit -m "BREAKING: Change login API signature for security"
git push origin bugfix/api-signature

# Pull Request mergen
# → Action erkennt: BREAKING übersteuert bugfix/* 
```

**Ergebnis:** `1.2.3` → `2.0.0` ✅

### 🧪 **Szenario 3: Alpha-Release für Testing**

**Entwickler-Workflow:**
```bash
# Experimentelles Feature als Alpha markieren
git checkout -b feature/experimental-search
git commit -m "FEAT-ALPHA: New search algorithm (experimental)"
git push origin feature/experimental-search

# Pull Request mergen
# → Action erkennt: FEAT-ALPHA = Minor + Alpha Suffix
```

**Ergebnis:** `1.2.3` → `1.3.0-alpha` ✅

### 🛠️ **Szenario 4: Hotfix-Release**

**Entwickler-Workflow:**
```bash
git checkout -b hotfix/critical-security
git commit -m "HOTFIX: Resolve critical security vulnerability CVE-2024-xxxx"
git push origin hotfix/critical-security

# Emergency Merge in main
# → Action erkennt: HOTFIX = Patch Bump
```

**Ergebnis:** `1.2.3` → `1.2.4` ✅

### 🔄 **Szenario 5: Erstes Release (Keine Tags)**

**Repository-Zustand:**
```bash
# Neues Repository ohne Git-Tags
git log --oneline
abc123 Add initial module structure
def456 Implement core functionality  
```

**Action-Verhalten:**
- ✅ Erkennt: "Erstes Release"
- ✅ Analysiert alle Commits seit Repository-Start  
- ✅ Beginnt bei Version `0.0.1` statt `0.0.0`

**Ergebnis:** `1.0.0` → `0.0.1` (erste Release) ✅

---

## 🔧 Erweiterte Konfiguration

### 🎛️ **Conditional Steps basierend auf Bump-Type**

```yaml
- name: Major Release Actions
  if: steps.version.outputs.bumpType == 'major'
  run: |
    echo "🚨 Major Release detected!"
    echo "→ Notify breaking changes to users"
    echo "→ Update documentation"
    echo "→ Send breaking change notifications"
    
- name: Minor Release Actions  
  if: steps.version.outputs.bumpType == 'minor'
  run: |
    echo "⭐ New features added!"
    echo "→ Update feature documentation"
    echo "→ Generate changelog"
    
- name: Patch Release Actions
  if: steps.version.outputs.bumpType == 'patch'  
  run: |
    echo "🛠️ Bug fixes applied!"
    echo "→ Notify bug resolution"
```

### 🏷️ **Multi-Environment Releases**

```yaml
- name: Development Release
  if: github.ref == 'refs/heads/develop'
  uses: GrexyLoco/K.Actions.NextVersion@v1
  with:
    targetBranch: 'develop'
    
- name: Production Release
  if: github.ref == 'refs/heads/main'  
  uses: GrexyLoco/K.Actions.NextVersion@v1
  with:
    targetBranch: 'main'
```

### 📊 **Release Notes Generierung**

```yaml
- name: Generate Detailed Release Notes
  run: |
    $lastTag = "${{ steps.version.outputs.lastReleaseTag }}"
    $newVersion = "${{ steps.version.outputs.newVersion }}"
    $targetBranch = "${{ steps.version.outputs.targetBranch }}"
    
    # Alle Merge-Commits seit letztem Release
    if ($lastTag) {
      $merges = git log --merges --oneline --format="%s" "$lastTag..$targetBranch"
    } else {
      $merges = git log --merges --oneline --format="%s" $targetBranch
    }
    
    echo "## Release Notes v$newVersion" > RELEASE_NOTES.md
    echo "" >> RELEASE_NOTES.md
    echo "### Merged Features & Fixes:" >> RELEASE_NOTES.md
    $merges | ForEach-Object { echo "- $_" >> RELEASE_NOTES.md }
  shell: pwsh
```

---

## 🛠️ Troubleshooting & FAQ

### ❓ **Häufige Probleme**

#### 🚫 **"No git tags found" - Erstes Release**
**Problem:** Repository hat noch keine Git-Tags
```
🎉 No previous releases found - this will be the first release!
```

**Lösung:** Normal! Die Action:
- ✅ Analysiert alle Commits seit Repository-Start
- ✅ Beginnt bei Version `0.0.1`  
- ✅ Wendet erkannte Bump-Types an

#### 🚫 **"Not on target branch" - Falsche Branch**
**Problem:** Action läuft auf Feature-Branch statt main/master
```
ℹ️ Not on target branch 'main', no version bump needed
```

**Lösung:** Workflow nur auf Haupt-Branches ausführen:
```yaml
on:
  push:
    branches: [ main, master ]  # ✅ Nur auf Release-Branches
```

#### 🚫 **"Multiple .psd1 files found" - Mehrere Manifeste**
**Problem:** Auto-Discovery findet mehrere PowerShell-Manifeste
```
⚠️ Multiple .psd1 files found. Using first one: ./src/Module.psd1
Available manifests: ./src/Module.psd1, ./tests/TestModule.psd1
```

**Lösung:** Expliziten Pfad angeben:
```yaml
with:
  manifestPath: './src/MyModule/MyModule.psd1'  # ✅ Eindeutig
```

#### 🚫 **Git History Probleme**
**Problem:** Shallow Clone verhindert Tag-Analyse
```
⚠️ Failed to retrieve git tags: fatal: not a git repository
```

**Lösung:** Full Git History abrufen:
```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0  # ✅ Komplette Git-History
```

### 💡 **Pro-Tips**

#### 🎯 **Branch Protection Rules**
```bash
# Verhindert direkte Commits in main (empfohlen):
# GitHub → Settings → Branches → Add rule
# ✅ Require pull request reviews before merging
# ✅ Dismiss stale PR approvals when new commits are pushed
```

#### 🏷️ **Tag-Naming-Convention**
```bash
# Empfohlene Git-Tag-Formate (alle unterstützt):
git tag v1.2.3      # ✅ Mit 'v' Prefix (empfohlen)
git tag 1.2.3       # ✅ Ohne Prefix  
git tag V1.2.3      # ❌ Groß-V wird nicht erkannt
```

#### 📝 **Commit-Message-Best-Practices**
```bash
# ✅ Empfohlene Formate:
git commit -m "FEAT: Add user authentication system"
git commit -m "FIX: Resolve memory leak in logger"
git commit -m "BREAKING: Remove deprecated API endpoints"

# ❌ Vermeiden:
git commit -m "Fixed stuff"
git commit -m "Updates"
```

---

## 🧪 Testen der Action

### 🔬 **Lokaler Test mit PowerShell**

```powershell
# Direkte Ausführung zum Testen
.\Get-NextVersion.ps1 -ManifestPath ".\MyModule.psd1" -BranchName "feature/test" -TargetBranch "main"

# Mit Verbose Output für Debugging
.\Get-NextVersion.ps1 -Verbose
```

### 🎭 **Mock-Szenarien für Tests**

```powershell
# Test verschiedener Branch-Patterns
.\Get-NextVersion.ps1 -BranchName "major/rewrite" -TargetBranch "master"     # → major
.\Get-NextVersion.ps1 -BranchName "feature/new-api" -TargetBranch "master"   # → minor  
.\Get-NextVersion.ps1 -BranchName "bugfix/critical" -TargetBranch "master"   # → patch

# Test Commit-Message-Override
.\Get-NextVersion.ps1 -BranchName "bugfix/small" -CommitMessage "BREAKING: API Change"  # → major
```

### 🧪 **Pester Tests ausführen**

```powershell
# Vollständige Test-Suite ausführen
Invoke-Pester .\Tests\Get-NextVersion.Tests.ps1 -Output Detailed

# Bestimmte Test-Kategorien
Invoke-Pester .\Tests\Get-NextVersion.Tests.ps1 -Tag "BranchPatterns"
Invoke-Pester .\Tests\Get-NextVersion.Tests.ps1 -Tag "CommitMessages"
```

---

## 🤝 Contributing & Support

### 🐛 **Bug Reports**
Gefunden einen Fehler? [Erstelle ein Issue](https://github.com/GrexyLoco/K.Actions.NextVersion/issues) mit:
- ✅ PowerShell-Version (`$PSVersionTable.PSVersion`)
- ✅ Workflow-Konfiguration
- ✅ Erwartetes vs. tatsächliches Verhalten
- ✅ Relevante Logs aus der Action

### 💡 **Feature Requests**  
Neue Ideen? [Feature Request erstellen](https://github.com/GrexyLoco/K.Actions.NextVersion/issues) mit:
- ✅ Beschreibung des gewünschten Features
- ✅ Anwendungsfall / Use Case
- ✅ Beispiel-Konfiguration (falls möglich)

### 🔧 **Pull Requests**
Verbesserungen willkommen! Bitte:
- ✅ Fork das Repository
- ✅ Erstelle Feature-Branch (`feature/amazing-feature`)
- ✅ Füge Tests hinzu (`Tests/Get-NextVersion.Tests.ps1`)
- ✅ Dokumentation aktualisieren
- ✅ Pull Request erstellen

---

## 📝 Lizenz

Dieses Projekt ist unter der [MIT License](LICENSE) lizenziert.

---

## ⭐ Gefällt dir diese Action?

Wenn dir K.Actions.NextVersion geholfen hat:
- ⭐ **Star** das Repository  
- 🍴 **Fork** für eigene Anpassungen
- 📢 **Teile** mit deinem Team
- 🐛 **Melde Bugs** oder **Verbesserungsvorschläge**

**Happy Versioning! 🚀**

---

<div align="center">

**Made with ❤️ for the PowerShell Community**

[![PowerShell Gallery](https://img.shields.io/badge/PowerShell-Gallery-blue.svg)](https://www.powershellgallery.com/)
[![GitHub](https://img.shields.io/badge/GitHub-Actions-black.svg)](https://github.com/features/actions)

</div>

### ✨ Minor Version Keywords  
| Keyword | Beschreibung | Beispiel |
|---------|--------------|----------|
| `MINOR` | Minor Version Bump | `MINOR: Add user authentication feature` |
| `FEATURE` | New Feature | `FEATURE: Implement advanced logging` |
| `FEAT` | New Feature (short) | `FEAT: Add configuration validation` |

### 🔧 Patch Version Keywords
| Keyword | Beschreibung | Beispiel |
|---------|--------------|----------|
| `PATCH` | Patch Version Bump | `PATCH: Update documentation links` |
| `FIX` | Bug Fix | `FIX: Resolve memory leak in data processing` |
| `BUGFIX` | Bug Fix (explicit) | `BUGFIX: Handle null reference exceptions` |
| `HOTFIX` | Critical Fix | `HOTFIX: Emergency security vulnerability patch` |

> 🎯 **Wichtig:** Alle Keywords sind **case-insensitive** und können überall in der Commit-Message stehen!

**Praktisches Beispiel der Priorität:**
```bash
# Branch: feature/new-api (würde normalerweise minor geben)
# Commit: "BREAKING: Change all function signatures"  
# Ergebnis: MAJOR bump (2.0.0) - Commit override gewinnt!

# Branch: bugfix/memory-leak (würde normalerweise patch geben)
# Commit: "FEAT: Add memory optimization feature"
# Ergebnis: MINOR bump (1.3.0) - Commit override gewinnt!
```

## 🚀 Verwendung

### Basis-Setup

```yaml
name: Version Management
on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  version:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Get Next Version
        id: version
        uses: GrexyLoco/K.Actions.NextVersion@v1
        with:
          manifestPath: './MyModule/MyModule.psd1'
          branchName: ${{ github.ref_name }}
          commitMessage: ${{ github.event.head_commit.message }}

      - name: Display Version Info
        run: |
          echo "Current Version: ${{ steps.version.outputs.currentVersion }}"
          echo "Bump Type: ${{ steps.version.outputs.bumpType }}"
          echo "New Version: ${{ steps.version.outputs.newVersion }}"
```

### Erweiterte Verwendung mit Auto-Discovery

```yaml
- name: Auto-Discover and Version
  id: auto-version
  uses: GrexyLoco/K.Actions.NextVersion@v1
  # Keine Inputs erforderlich - Auto-Discovery aktiviert

- name: Create Release
  if: github.ref == 'refs/heads/main'
  uses: actions/create-release@v1
  with:
    tag_name: v${{ steps.auto-version.outputs.newVersion }}
    release_name: Release ${{ steps.auto-version.outputs.newVersion }}
    body: |
      ## Version ${{ steps.auto-version.outputs.newVersion }}
      
      **Bump Type:** ${{ steps.auto-version.outputs.bumpType }}
      **Previous Version:** ${{ steps.auto-version.outputs.currentVersion }}
      
      Auto-generated release based on semantic versioning.
```

### Conditional Versioning Workflow

```yaml
- name: Determine Version Strategy
  id: versioning
  uses: GrexyLoco/K.Actions.NextVersion@v1

- name: Major Version Actions
  if: steps.versioning.outputs.bumpType == 'major'
  run: |
    echo "🚨 Major version detected - running breaking change validations"
    # Zusätzliche Tests für breaking changes

- name: Feature Release Actions  
  if: steps.versioning.outputs.bumpType == 'minor'
  run: |
    echo "✨ New feature detected - updating feature documentation"
    # Feature-spezifische Aktionen

- name: Patch Release Actions
  if: steps.versioning.outputs.bumpType == 'patch'
  run: |
    echo "🔧 Patch release - running regression tests"
    # Patch-spezifische Validierungen
```

## 🔍 Beispiele

### Feature Branch
```yaml
# Branch: feature/enhanced-logging
# Manifest: ModuleVersion = '1.2.3'
# Output: 
#   currentVersion: '1.2.3'
#   bumpType: 'minor'
#   newVersion: '1.3.0'
```

### Bugfix mit Breaking Change
```yaml
# Branch: bugfix/api-fix
# Commit: "BREAKING: Change parameter order in Get-Data function"
# Manifest: ModuleVersion = '1.2.3'
# Output:
#   currentVersion: '1.2.3'
#   bumpType: 'major'
#   newVersion: '2.0.0'
```

### Major Branch
```yaml
# Branch: major/v2-rewrite
# Manifest: ModuleVersion = '1.9.5'
# Output:
#   currentVersion: '1.9.5'
#   bumpType: 'major'
#   newVersion: '2.0.0'
```

## 🛠️ Lokale Entwicklung

### PowerShell-Skript testen

```powershell
# Basis-Test
.\Get-NextVersion.ps1 -ManifestPath ".\MyModule.psd1" -BranchName "feature/test" -CommitMessage "Add new feature"

# Mit Verbose-Ausgabe
.\Get-NextVersion.ps1 -ManifestPath ".\MyModule.psd1" -BranchName "major/rewrite" -Verbose

# Breaking Change Test
.\Get-NextVersion.ps1 -BranchName "bugfix/fix" -CommitMessage "BREAKING: Remove old API"
```

### Action lokal testen

```bash
# Mit act (GitHub Actions local runner)
act -j version-test --secret GITHUB_TOKEN=your_token

# Oder mit Docker
docker run --rm -v "${PWD}:/workspace" -w /workspace \
  nektos/act:latest -j version-test
```

## 📋 Anforderungen

- **PowerShell 5.1+** oder **PowerShell Core 6.0+**
- **Gültiges PowerShell-Manifest** (`.psd1`) mit `ModuleVersion`
- **Git-Repository** mit strukturierten Branch-Namen

## 🐛 Troubleshooting

### Häufige Probleme

**Problem:** `PowerShell manifest file not found`
```yaml
# Lösung: Expliziten Pfad angeben
- uses: GrexyLoco/K.Actions.NextVersion@v1
  with:
    manifestPath: './src/MyModule/MyModule.psd1'
```

**Problem:** `ModuleVersion not found in manifest`
```powershell
# Lösung: Manifest-Datei validieren
@{
    ModuleVersion = '1.0.0'  # ← Erforderlich!
    # ... andere Eigenschaften
}
```

**Problem:** Unerwarteter Bump-Type
```yaml
# Lösung: Branch-Pattern überprüfen oder Commit-Message
# Branch: fix/bug      → patch (erwartet)
# Branch: feature/fix  → minor (erwartet)  
# Branch: FEATURE/fix  → minor (case-insensitive!)
# Commit: "BREAKING"   → major (override)
```

## 🧪 Tests ausführen

```powershell
# Pester-Tests lokal ausführen
cd Tests
Invoke-Pester .\Get-NextVersion.Tests.ps1

# Einfacher Test
.\Test-Action.ps1

# Mit spezifischen Parametern testen
.\Get-NextVersion.ps1 -ManifestPath ".\TestModule.psd1" -BranchName "Feature/NEW-API" -Verbose
```

## 🤝 Beitragen

1. **Fork** das Repository
2. **Branch** erstellen (`git checkout -b feature/amazing-feature`)
3. **Commit** Änderungen (`git commit -m 'Add amazing feature'`)
4. **Push** zum Branch (`git push origin feature/amazing-feature`)
5. **Pull Request** öffnen

## 📄 Lizenz

Dieses Projekt ist unter der [MIT License](LICENSE) lizenziert.

## 🙏 Danksagungen

- [Semantic Versioning](https://semver.org/) für die Versionierungsstandards
- [GitHub Actions](https://github.com/features/actions) für die CI/CD-Platform
- PowerShell-Community für die großartigen Tools und Inspiration

---

**Erstellt mit ❤️ für die PowerShell- und DevOps-Community**