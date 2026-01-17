# K.Actions.NextVersion

<!-- AUTO-GENERATED BADGES - DO NOT EDIT MANUALLY -->
## 📊 Status

![Quality Gate](https://img.shields.io/badge/Quality_Gate-passing-brightgreen?logo=githubactions) ![Release](https://img.shields.io/badge/Release-v1.4.0--beta.2-blue?logo=github) [![CI](https://github.com/GrexyLoco/K.Actions.NextVersion/actions/workflows/release.yml/badge.svg)](https://github.com/GrexyLoco/K.Actions.NextVersion/actions/workflows/release.yml)

> 🕐 **Last Updated:** 2026-01-17 23:48:51 UTC | **Action:** `K.Actions.NextVersion - Release-based Semantic Versioning`
<!-- END AUTO-GENERATED BADGES -->

🚀 **Release-based Semantic Versioning Action** für PowerShell Module mit intelligenter Hybrid-Logik für erste Releases.

## 🌟 Features

- **🔍 Release-basierte Analyse:** Analysiert Merge-Commits seit dem letzten Release-Tag
- **🎯 Hybrid First Release:** Nutzt PSD1-Version als Basis für ersten Release (statt 0.0.0)  
- **⚠️ Smart Validation:** Warnt bei ungewöhnlichen Startversionen mit Bestätigungsoption
- **🌿 Branch Pattern Recognition:** Automatische Bump-Type Erkennung via Branch-Namen
- **💬 Commit Keywords:** Commit-Message Keywords überschreiben Branch-Patterns
- **🏷️ Alpha/Beta Support:** Unterstützung für Pre-Release Suffixe
- **🔧 Auto-Discovery:** Automatische Erkennung von Manifest-Dateien und Target-Branch

## 📋 Inputs

| Parameter | Beschreibung | Required | Default |
|-----------|--------------|----------|---------|
| `manifestPath` | Pfad zur .psd1 Datei | ❌ | Auto-Discovery |
| `branchName` | Branch-Name für Analyse | ❌ | `github.ref_name` |
| `targetBranch` | Target-Branch für Release-Analyse | ❌ | Auto-Discovery |
| `forceFirstRelease` | Ersten Release mit ungewöhnlicher Version erzwingen | ❌ | `false` |

## 📊 Outputs

| Output | Beschreibung | Beispiel |
|--------|--------------|----------|
| `currentVersion` | Aktuelle Version aus PSD1 | `1.2.3` |
| `bumpType` | Erkannter Bump-Typ | `major/minor/patch/none` |
| `newVersion` | Berechnete neue Version | `1.3.0` |
| `lastReleaseTag` | Letzter gefundener Release-Tag | `v1.2.3` |
| `targetBranch` | Verwendeter Target-Branch | `main` |
| `suffix` | Alpha/Beta-Suffix | `alpha/beta/""` |
| `warning` | Warnung bei ungewöhnlichen Versionen | `"Unusual version detected..."` |

## 🎯 Hybrid First Release Logic

### **Standard-Versionen (Auto-Approved):**
```yaml
PSD1: ModuleVersion = '0.0.0'  # ✅ Standard Pre-Release Start
PSD1: ModuleVersion = '1.0.0'  # ✅ Standard Initial Release
→ Verwendet als Basis für Versionsbump
```

### **Ungewöhnliche Versionen (Warnung + Bestätigung):**
```yaml
PSD1: ModuleVersion = '3.5.2'  # ⚠️ Ungewöhnliche Startversion
→ Erfordert forceFirstRelease: true für Migration
```

### **Erste Release Berechnung:**
```
Basis: PSD1-Version (z.B. 1.0.0)
Git-Analyse: feature/new-logging → Minor Bump  
Ergebnis: 1.0.0 + minor = 1.1.0
```

### **Beispiel-Szenarien:**

#### **Szenario 1: Neues Projekt (Standard)**
```yaml
Situation: Keine Git-Tags, PSD1 = '1.0.0'
Merge: feature/authentication  
Action: 1.0.0 + minor bump = 1.1.0 ✅
```

#### **Szenario 2: Migration (Force-Flag)**
```yaml
Situation: Keine Git-Tags, PSD1 = '2.3.1'
Merge: bugfix/critical-fix
Force: forceFirstRelease: true
Action: 2.3.1 + patch bump = 2.3.2 ✅
```

#### **Szenario 3: Normale Releases**
```yaml
Situation: Tag v1.5.3 vorhanden, PSD1 = '1.5.3'
Merge: feature/new-api
Action: 1.5.3 + minor bump = 1.6.0 ✅
```

## 🌿 Release Branches (PreRelease-Quelle)

> **Wichtig:** PreRelease-Typ wird durch den **Branch-Namen** bestimmt, nicht durch Commit-Patterns!

| Branch | PreRelease-Typ | Beispiel-Version |
|--------|----------------|------------------|
| `release` | Stable (kein Suffix) | `1.2.0` |
| `main`, `master`, `staging` | **Beta** | `1.2.0-beta.1` |
| `dev`, `development` | **Alpha** | `1.2.0-alpha.1` |
| Andere (feature/*, etc.) | **Kein Release** | ❌ Build fehlschlägt |

## 🔄 PreRelease-Lifecycle (One-Way-Street)

```
      ┌───────────────────────────────────────────┐
      │          PreRelease Lifecycle             │
      │                                           │
      │  Stable ──► Alpha ──► Beta ──► Stable    │
      │    │          │         │                 │
      │    │          └────────►│   (Rückwärts    │
      │    └───────────────────►│    verboten!)   │
      │                                           │
      │  ✓ Stable → Alpha (Start neue Serie)     │
      │  ✓ Stable → Beta  (Alpha überspringen)   │
      │  ✓ Alpha  → Beta  (Transition)           │
      │  ✓ Alpha  → Stable (Release)             │
      │  ✓ Beta   → Stable (Release)             │
      │  ✗ Beta   → Alpha (VERBOTEN!)            │
      └───────────────────────────────────────────┘
```

## 💬 BumpType-Patterns (Commit-basiert)

> **Wichtig:** BumpType wird **nur** durch Commit-Messages bestimmt, nicht durch Branch-Namen!

| Keywords | Bump Type | Beispiel Commit |
|----------|-----------|-----------------|
| `BREAKING`, `MAJOR`, `!:`, `breaking change` | **Major** | `"BREAKING: Remove deprecated API"` |
| `FEATURE`, `MINOR`, `feat:`, `feat(`, `feature:`, `add:`, `new:` | **Minor** | `"feat: Add user authentication"` |
| Alles andere | **Patch** | `"fix: Memory leak in parser"` |

### Priorität: Major > Minor > Patch

```
Commits: ["feat: new API", "BREAKING: removed old method"]
→ BumpType = major (BREAKING hat Vorrang)
```

## 🏷️ Build-Number (PreRelease-Serie)

Bei PreRelease-Versionen wird automatisch eine Build-Number hochgezählt:

```
Existing tags: v1.2.0-alpha.1, v1.2.0-alpha.2
Next alpha:    v1.2.0-alpha.3
```

## 🚀 Usage Examples

### **Basic Usage (Auto-Discovery)**
```yaml
- name: Analyze Next Version
  id: version
  uses: GrexyLoco/K.Actions.NextVersion@latest
  with:
    branchName: ${{ github.ref_name }}
```

### **Migration Existing Project**
```yaml
- name: Analyze Next Version (Migration)
  id: version
  uses: GrexyLoco/K.Actions.NextVersion@latest
  with:
    manifestPath: "./MyModule/MyModule.psd1"
    forceFirstRelease: true  # ⚠️ Für Migration mit existierender Version
```

### **With Warning Handling**
```yaml
- name: Analyze Next Version
  id: version
  uses: GrexyLoco/K.Actions.NextVersion@latest

- name: Handle Warnings
  if: steps.version.outputs.warning != ''
  run: |
    echo "⚠️ Warning: ${{ steps.version.outputs.warning }}"
    echo "Use forceFirstRelease: true if this is intentional"
```

### **Complete Workflow Integration**
```yaml
name: Smart Release Pipeline

on:
  push:
    branches: [main]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Analyze Next Version  
        id: version
        uses: GrexyLoco/K.Actions.NextVersion@latest
        
      - name: Skip if no changes
        if: steps.version.outputs.bumpType == 'none'
        run: echo "No version changes detected"
        
      - name: Update PSD1 Version
        if: steps.version.outputs.bumpType != 'none'
        run: |
          # Update ModuleVersion in PSD1
          $newVersion = "${{ steps.version.outputs.newVersion }}"
          # ... PSD1 update logic
          
      - name: Create Release Tag
        if: steps.version.outputs.bumpType != 'none'
        run: |
          git tag "v${{ steps.version.outputs.newVersion }}"
          git push origin "v${{ steps.version.outputs.newVersion }}"
```

## 🔄 Migration Guide

### **Removing Legacy commitMessage:**
```yaml
# ❌ Alt (entfernt)
- uses: GrexyLoco/K.Actions.NextVersion@v1
  with:
    commitMessage: ${{ github.event.head_commit.message }}

# ✅ Neu (automatische Release-basierte Analyse)  
- uses: GrexyLoco/K.Actions.NextVersion@latest
  with:
    branchName: ${{ github.ref_name }}
```

### **Existing Projects mit Custom Versions:**
```yaml
# Für Migration bestehender Projekte mit Version ≠ 0.0.0 oder 1.0.0
- uses: GrexyLoco/K.Actions.NextVersion@latest
  with:
    forceFirstRelease: true
```

## 🧠 Algorithmus-Logik

### **Release-basierte Analyse:**
1. **Tag-Suche:** Findet letzten Semantic Version Tag (v1.2.3)
2. **Merge-Analyse:** Analysiert Merge-Commits seit letztem Tag
3. **Prioritäts-System:** Major > Minor > Patch (höchste Priorität gewinnt)
4. **Bump-Berechnung:** Aktuelle Version + ermittelter Bump-Type

### **Erste Release (Hybrid-Logik):**
1. **Keine Tags:** Erste Release erkannt
2. **PSD1-Validation:** Standard (0.0.0, 1.0.0) vs. Ungewöhnlich
3. **Git-Analyse:** Analysiert komplette Repository-Historie  
4. **Base-Berechnung:** PSD1-Version + ermittelter Bump-Type

### **Konflikt-Behandlung:**
- **Commit-Keywords** überschreiben **Branch-Patterns**
- **Multiple Merge-Commits:** Höchste Priorität gewinnt
- **Force-Flag:** Überschreibt Validierungs-Warnungen

## 📝 Semantic Versioning Compliance

Die Action folgt strikt [Semantic Versioning 2.0.0](https://semver.org/):

- **Major (X.Y.Z → X+1.0.0):** Breaking Changes
- **Minor (X.Y.Z → X.Y+1.0):** Neue Features (rückwärtskompatibel)  
- **Patch (X.Y.Z → X.Y.Z+1):** Bugfixes (rückwärtskompatibel)

## 🔧 Troubleshooting

### **"Unusual first release version detected"**
```yaml
# Problem: PSD1 hat Version wie 2.5.3 aber keine Git-Tags
# Lösung: Force-Flag verwenden
- uses: GrexyLoco/K.Actions.NextVersion@latest
  with:
    forceFirstRelease: true
```

### **"Not on target branch for release"**
```yaml
# Problem: Action läuft auf feature-branch
# Lösung: Nur auf main/master Branch ausführen
on:
  push:
    branches: [main, master]
```

### **"No merge commits found"**
```yaml
# Problem: Keine Merge-Commits seit letztem Release
# Ergebnis: bumpType = "none" (kein Release erforderlich)
```

## 🎯 Best Practices

1. **Branch-Namen:** Verwende Standard-Patterns (`feature/`, `bugfix/`, `major/`)
2. **Commit-Messages:** Nutze Keywords für explizite Bump-Kontrolle
3. **Force-Flag:** Nur für Migration verwenden, nicht für reguläre Releases
4. **Auto-Discovery:** Lass die Action Manifest und Target-Branch finden
5. **Warning-Handling:** Prüfe Warning-Output für ungewöhnliche Situationen

---

**🔗 Related:** [Semantic Versioning](https://semver.org/) | [GitHub Actions](https://docs.github.com/en/actions) | [PowerShell Gallery](https://www.powershellgallery.com/)