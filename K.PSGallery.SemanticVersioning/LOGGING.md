# Logging Integration - K.PSGallery.SemanticVersioning

## Überblick

Das K.PSGallery.SemanticVersioning Modul integriert nahtlos mit dem K.PSGallery.LoggingModule für erweiterte Logging-Funktionalität. Falls das LoggingModule nicht verfügbar ist, wird automatisch auf Standard PowerShell Logging-Methoden zurückgegriffen.

## Safe Logging Funktionen

### Write-SafeLog
Die Hauptfunktion, die das LoggingModule erkennt und entsprechend agiert:

```powershell
Write-SafeLog -Level "Info" -Message "Nachricht" -Context "Zusätzlicher Kontext"
```

### Wrapper-Funktionen
- `Write-SafeInfoLog` - Informative Nachrichten
- `Write-SafeWarningLog` - Warnungen 
- `Write-SafeErrorLog` - Fehler
- `Write-SafeDebugLog` - Debug-Informationen
- `Write-SafeTaskSuccessLog` - Erfolgreiche Task-Abschlüsse
- `Write-SafeTaskFailLog` - Fehlgeschlagene Tasks

## Verhalten

### Mit K.PSGallery.LoggingModule
Wenn das LoggingModule verfügbar ist:
- Verwendet farbige, strukturierte Ausgabe
- Unterstützt Timestamps und Log-Level
- Erweiterte Formatierung für TaskSuccess/TaskFailed

### Ohne LoggingModule (Fallback)
Wenn das LoggingModule nicht verfügbar ist:
- Fällt zurück auf Write-Host mit entsprechenden Farben
- Behält grundlegende Strukturierung bei
- Stellt sicher, dass alle Logging-Aufrufe funktionieren

## Integration in Get-NextSemanticVersion

Alle vorherigen `Write-Host` und `Write-Warning` Aufrufe wurden durch entsprechende Safe-Logging-Funktionen ersetzt:

```powershell
# Vorher:
Write-Host "Version Analysis Results:"

# Nachher:
Write-SafeInfoLog -Message "Version Analysis Results:" -Context $detailsContext
```

## Vorteile

1. **Konsistente Logging-Ausgabe**: Verwendet das etablierte LoggingModule wenn verfügbar
2. **Robustheit**: Funktioniert auch ohne LoggingModule
3. **Erweiterte Formatierung**: Nutzt die erweiterten Features des LoggingModules
4. **Strukturierter Context**: Kann zusätzliche Kontextinformationen elegant darstellen
5. **Farbcodierung**: Bessere Lesbarkeit durch farbige Ausgabe

## Verwendung

Das Modul erkennt automatisch, ob das LoggingModule verfügbar ist:

```powershell
# LoggingModule laden (optional)
Import-Module "K.PSGallery.LoggingModule"

# SemanticVersioning Modul laden
Import-Module "K.PSGallery.SemanticVersioning"

# Funktionen verwenden - Logging wird automatisch entsprechend angepasst
$result = Get-NextSemanticVersion -ManifestPath "MyModule.psd1"
```
