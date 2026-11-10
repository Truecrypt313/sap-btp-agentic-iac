# Directory-Lebenszyklus vor dem ersten Deployment

PR #10 (`0700336925032f69bebf75eb5d59dfe0b8251bb8`) ist die synchronisierte
Ausgangsbasis. Die bisherige Prüfung lehnte jedes Directory mit gleichem Namen
oder `project_id` ab. Nach der ersten Erstellung trifft das auch auf das eigene
Directory zu. `directory.enabled` nachträglich abzuschalten würde die Ressource
aus `for_each` entfernen; das ist keine Lösung.

## Verbindlicher Ownership-Preflight

Eine Ressource kann ihre eigene tatsächliche ID nicht als Eingang ihrer
Precondition verwenden: Die Rückreferenz über das Prüfmodul erzeugt einen
Dependency-Cycle. Eine Postcondition allein würde eine fremde Kollision erst
nach der Erstellung erkennen. Deshalb wird der State unabhängig und lesend
vor der Ressourcenplanung geprüft:

1. `btp_directories.existing` liest das Inventar mit dem BTP-Provider. An den
   Helfer gehen ausschließlich ID, Name und die Werte des Labels `project_id`.
2. `data.external.ownership` führt automatisch
   `scripts/directory_ownership_preflight.py` aus. Der Helfer bindet den
   aktuellen `TFC_RUN_ID` über die HCP-API an die tatsächliche Workspace-ID.
   Erwartet werden `sap-ai-landing-zone/sap-btp-<project_id>-core`, Working
   Directory `BTP/projects`, Remote-/Agent-Ausführung, deaktiviertes Auto-Apply
   und ein Plan mit Refresh. Project ABC wird ausdrücklich abgelehnt.
3. Die API muss entweder eine ausdrücklich leere `current-state-version`
   liefern oder eine lesbare State-Version. HTTP 401/403/404, fehlende Felder,
   ein Versionswechsel während der Abfrage oder eine abweichende Serial sind
   Fehler. Ein fehlgeschlagener State-Zugriff gilt niemals als leerer State.
4. Aus dem State wird ausschließlich die verwaltete Instanz an
   `module.directory.btp_directory.this["project"]` mit dem Provider
   `registry.terraform.io/sap/btp` gelesen. Maßgeblich ist ihr `attributes.id`.
   Outputs, Namen und Projekt-Labels sind kein Eigentumsnachweis. Andere
   Directory-Adressen, mehrere Instanzen sowie tainted/deposed State blockieren.
5. Ohne verwaltete ID darf kein Inventareintrag den gewünschten Namen
   (Groß-/Kleinschreibung ignoriert) oder die Projekt-ID besitzen. Mit verwalteter
   ID wird ausschließlich genau dieser Inventareintrag ausgenommen; jede
   fremde Namens-/Projekt-Kollision blockiert weiterhin. Fehlt die eigene ID
   im Inventar, wird eine automatische Neuerstellung wegen Drift verhindert.
6. Der Helfer gibt die geprüfte minimale Inventarsicht und den Nachweis aus
   State-Version, Lineage, Serial, Ressourcenadresse und tatsächlicher ID zurück.
   `directory-rules` prüft diese Sicht zusätzlich. Die Ressourcen-Precondition
   hängt davon ab. Es gibt keinen Abschaltschalter und keinen vom Benutzer
   gesetzten `managed_directory_id`-Input.

Abhängigkeitsrichtung: Inventar und HCP-State → Preflight → Inventory-Regeln →
Directory-Ressource. Keine Kante führt von der Ressource zurück zur Prüfung.
Der erste Plan braucht keinen leeren Bootstrap-Apply. Nach der Erstellung muss
`directory.enabled: true` erhalten bleiben; derselbe Ressourcenkey wird mit der
im selben Workspace-State gespeicherten ID beim nächsten Plan wiedererkannt.
Eine Referenz über `existing_directory_id` bleibt ein expliziter, read-only
Lookup und importiert keine Ressource. Sie ist kein Umgehungsweg für die
Ownership-Prüfung einer von diesem Root erstellten Ressource.

## Voraussetzungen vor einer gesondert freigegebenen Aktivierung

Der neue Root ergänzt ausschließlich für diese Prüfung
`hashicorp/external = 2.3.5` mit signiert geprüften Checksummen. SAP/btp bleibt
1.27.0; kein bestehender Provider-Lockblock oder Legacy-Root wird verändert.
Die bisherigen drei Workspaces verwenden das Directory-Modul nicht.

Im zukünftigen Core-Workspace sind erforderlich:

- Python 3 im ausführenden Worker/Agent und der vollständige Repository-Inhalt
  einschließlich `scripts/directory_ownership_preflight.py`. Der Helfer benötigt
  nur die Standardbibliothek, weder PyYAML noch eine lokale State-Datei.
- Die von HCP gelieferten Umgebungsvariablen `TFC_RUN_ID`, `TFC_WORKSPACE_ID`
  und `TFC_WORKSPACE_NAME`.
- Eine **sensitive Environment-Variable** `DIRECTORY_PREFLIGHT_HCP_TOKEN`.
  Der Helfer verwendet ausschließlich Leseoperationen auf Runs, Metadaten und
  den tatsächlichen State desselben Workspaces. In unserer HCP-Free-Umgebung
  wird dafür ein geschützter User-Token verwendet; dessen Owner-Rechte können
  weiter reichen und sind nicht technisch auf Lesen begrenzt. Details und
  einmalige Ablage stehen im [Free-Bootstrap-Setup](PROJECT_BOOTSTRAP.md).
  State kann sensible Werte enthalten. Kein Token in Terraform-/YAML-Variablen,
  Query, Logs oder Git ablegen.
- Netzwerkzugriff auf `https://app.terraform.io/api/v2` und die von HCP
  gelieferte HTTPS-State-Download-Adresse. Nur GET; kein Token am Download,
  keine Weiterleitung von Authentifizierung, keine Redirects. Der State bleibt
  ausschließlich im Prozessspeicher; seine Inhalte werden weder ausgegeben
  noch geschrieben. Größenlimit 32 MiB, HTTP-Timeout 30 Sekunden.
- BTP-Anmeldedaten mit vollständigem Global-Account-Directory-Inventar und den
  separat zu prüfenden Rechten für die spätere Erstellung.

Ohne diese Voraussetzungen scheitert ein aktiver Directory-Plan vor dem
Ressourcen-Apply. Auch lokale aktive Plans ohne HCP-Run-Kontext scheitern;
lokale Regressionstests verwenden ausdrücklich Mock-Provider. Ein deaktiviertes
Projekt fragt weder SAP-Inventar noch HCP-State über diesen Helfer ab.
Das Setup und ein Live-Test dieses zukünftigen Workspaces sind nicht Bestandteil
dieses PRs; es wird kein Workspace und keine Variable angelegt oder geändert.

HCP übernimmt die gewöhnliche Workspace-Sperre und die Aktualitätsprüfung eines
gespeicherten Plans. Die Prüfung ist eine Momentaufnahme und keine globale
SAP-Namenssperre gegen gleichzeitig ausgeführte fremde Deployments. Vor einer
Freigabe stets einen aktuellen Plan prüfen und parallele Directory-Erstellungen
für dasselbe Projekt organisatorisch ausschließen. Bei fehlendem/verändertem
State keine IDs erfinden, keinen fremden State importieren und keine Ressource
adoptieren; die Ursache gesondert untersuchen. Unbekannte Raw-State-Formate
werden abgelehnt; unterstützt wird Terraform-State-Version 4.

## Entitlements im DEV-Minimaltest

`BTP/config/projects/test-neu/environments/dev.yaml` setzt jetzt
`skip_auto_entitlement: true`. SAP/btp 1.27.0 übergibt diesen Wert bei der
Subaccount-Erstellung an `SkipAutoEntitlement`; fehlend/null/false überspringt
automatisch zugewiesene Standardpläne nicht. Eine spätere Wertänderung ist laut
`RequiresReplace` ein Ersatz des Subaccounts und wird durch `prevent_destroy`
blockiert. Deshalb erfolgt die Vorbereitung vor der ersten Erstellung.

Das Flag verhindert die automatische Zuweisung bei der Erstellung. Es beschafft
keine Quoten, entzieht keine bestehenden Entitlements und unterdrückt keine
später explizit konfigurierten Entitlements. `services.catalog: []` bleibt leer,
das Directory behält `DEFAULT`, alle Administrator-/IAM-Listen bleiben leer.
Projekt, Directory, DEV/TEST/PROD und sämtliche CF-Schalter bleiben deaktiviert.
Project ABC wird weder konfiguriert noch angetastet. Vor CF bleibt eine separate
Live-Prüfung von Entitlements und Quoten erforderlich.

## Automatisierte Abnahme

```bash
python scripts/build_landing_zone_config.py --check
python scripts/check_landing_zone.py
python scripts/check_repository.py --base origin/main
python scripts/check_project_abc_compatibility.py --base 0700336925032f69bebf75eb5d59dfe0b8251bb8
python scripts/export_provider_schema.py --refresh --check
python scripts/run_secret_scan.py --gitleaks /pfad/zu/gitleaks --base origin/main
```

Die bestehende GitHub-CI ruft die erweiterten Prüfungen automatisch auf:

| Regression | Nachweis |
|---|---|
| Erstmalige Erstellung | Preflight mit ausdrücklich leerem State; Directory-Mock-Erstellung |
| Eigenes Directory im Inventar | Tatsächliche ID aus synthetischem API-State; Terraform Inventory-Regeln |
| Zweiter Plan nach Erstellung | Zustandsbehafteter Terraform-Test; JSON-Plan enthält exakt `no-op` |
| Fremder gleicher Name | Case-insensitive Kollision beim ersten und beim wiederholten Plan |
| Fremde ID, gleiche Projekt-ID | Kollision auch neben einem korrekt verwalteten eigenen Directory |
| Metadatenänderung/Drift | Ownership bleibt an ID gebunden; JSON-Plan zeigt `update`, keinen Ersatz |
| Unzulässiger Parent/Features | Bestehende und ergänzte UUID-, Hierarchie-, Fremdprojekt- und Feature-Tests |
| Kein Dependency-Cycle | Validate plus erste und wiederholte ausführbare Mock-Plans |
| Fehlende Belege/Zugriff | Laufzeit-/Workspace-/State-/HTTP-Fehler blockieren, Diagnosen redigiert |
| Minimaler DEV-Plan | Ausschließlich zwei Creates: Directory und DEV-Subaccount; kein CF/IAM/Entitlement |

Der Lifecycle-Test verwendet einmal `command = apply` ausschließlich mit
`mock_provider "btp"` und `mock_provider "external"` in temporärem lokalem
Test-State. Auch der automatische Test-Cleanup benutzt Mocks. Dies ist kein
SAP-/HCP-Apply. Die CI wertet Plan-Aktionen aus und verlässt sich nicht allein
auf unveränderte Outputs. Produktionsdaten oder Zugangsdaten werden nicht in
Test-Fixtures übernommen. Vollständige Testzahlen und commitbezogene CI-/HCP-
Ergebnisse stehen in der PR-Beschreibung.

Quellen: [SAP/btp 1.27.0 Subaccount-Implementierung](https://github.com/SAP/terraform-provider-btp/blob/v1.27.0/btp/provider/resource_subaccount.go),
[External-Protokoll 2.3.5](https://github.com/hashicorp/terraform-provider-external/blob/v2.3.5/docs/data-sources/external.md),
[HCP-Run-Umgebung](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/run/run-environment),
[HCP-State-API](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/state-versions).
