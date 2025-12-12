# 🔄 Reusable Workflow - Next Version (PowerShell Module)

**Vollständige Dokumentation analog zu [K.Actions.NextActionVersion](../K.Actions.NextActionVersion/.github/workflows/reusable/REUSABLE-WORKFLOW.md)**

## 📋 Schnellstart

### Integration

```yaml
jobs:
  version:
    uses: GrexyLoco/K.Actions.NextVersion/.github/workflows/reusable/next-version.yml@v1
    with:
      manifest-path: './MyModule.psd1'
      force-version-release: false
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

## 🎯 Zweck

Semantic Versioning für **PowerShell Module** (`.psd1` Manifest-basiert):
- Analysiert Git History seit letztem Release
- Erkennt Alpha/Beta Pre-Releases
- PSD1 Manifest Version Detection
- Force-Release Recovery-Mode

## 📥 Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `manifest-path` | `''` (auto) | Path to .psd1 manifest |
| `branch-name` | `github.ref_name` | Current branch |
| `target-branch` | `''` (auto) | Target for release (main/master) |
| `force-version-release` | `false` | Recovery mode für fehlgeschlagene Releases |
| `runs-on` | `'ubuntu-latest'` | Runner |

## 📤 Outputs

| Output | Description |
|--------|-------------|
| `current-version` | Version from .psd1 manifest |
| `new-version` | Calculated semantic version |
| `bump-type` | major/minor/patch/none |
| `suffix` | alpha/beta/empty |
| `warning` | Unusual version warnings |
| `action-required` | Manual action needed? |

## 🔍 Unterschied zu NextActionVersion

| Feature | NextVersion (PowerShell) | NextActionVersion (Actions) |
|---------|------------------------|----------------------------|
| **Zielformat** | .psd1 Manifest | action.yml |
| **Pre-Release** | Alpha/Beta via Branch | Alpha/Beta/RC/Pre Pattern |
| **Version Source** | ModuleVersion in .psd1 | Git Tags only |
| **Recovery Mode** | `force-version-release` | `force-first-release` |

## 🚀 Beispiel: Module Release Pipeline

```yaml
name: PowerShell Module Release

on:
  push:
    branches: [master, main, develop]

jobs:
  calculate-version:
    uses: GrexyLoco/K.Actions.NextVersion/.github/workflows/reusable/next-version.yml@v1
    with:
      force-version-release: ${{ github.event.inputs.force || false }}
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}

  update-manifest:
    needs: calculate-version
    if: needs.calculate-version.outputs.bump-type != 'none'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      
      - name: Update PSD1 Version
        shell: pwsh
        run: |
          $newVersion = '${{ needs.calculate-version.outputs.new-version }}'
          Update-ModuleManifest -Path './MyModule.psd1' -ModuleVersion $newVersion
      
      - name: Commit & Tag
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add *.psd1
          git commit -m "chore: bump version to ${{ needs.calculate-version.outputs.new-version }}"
          git tag "v${{ needs.calculate-version.outputs.new-version }}"
          git push --tags
          git push
```

## 📚 Details

Siehe Hauptdokumentation in [K.Actions.NextActionVersion REUSABLE-WORKFLOW.md](../K.Actions.NextActionVersion/.github/workflows/reusable/REUSABLE-WORKFLOW.md) - alle Konzepte (Caller-Context, Private Repos, Migration) gelten identisch.

