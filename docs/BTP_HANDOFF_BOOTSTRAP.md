# Isolierter DEV-Handoff-Bootstrap

## Integration in die modulare Landing Zone

Der Bootstrap aus `main` / `ebb1ab7` wurde separat angewendet. Lesend geprüft:
BTP-State Serial 2 (`sv-7anyoe92t2HPpWLm`) veröffentlicht den nicht sensitiven
DEV-Handoff mit dem unten dokumentierten Fingerabdruck. Endpoint und Org-ID
stimmen mit den bisherigen DEV-Outputs überein. HCP `additional_subaccounts`
bleibt `{}`; diese Integration verändert keine HCP-Variablen oder States.

Die Integration in `feature/modular-btp-landing-zone` erhält einen einzigen
`landing_zone_config`-Modulaufruf, eine Pfadvariable und einen
`cloud_foundry_environments`-Output. DEV verwendet weiterhin dieselben
Environment-Labels und denselben unveränderten Hash-Vertrag. Der modulare
Output ergänzt nur weitere in YAML aktivierte CF-Umgebungen.

Die Bootstrap-Regressionen bleiben in `BTP/tests/handoff_bootstrap.tftest.hcl`.
Ihre negativen Tests prüfen jetzt die entsprechenden modularen Ressourcen-
Preconditions. Zusätzlich sichern sie den unveränderten DEV-Handoff im
Compatibility- und YAML-Modus. Im modularen Root ist bei leerem Legacy-Input
weiterhin der aktivierte TEST-Subaccount aus `BTP/landing-zone.yaml` zu erwarten;
TEST-CF bleibt deaktiviert. Der reine Output-only-Bootstrap war ein separater,
bereits abgeschlossener Einführungsschritt.

Die CF-Prüfung auf veröffentlichten Endpoint, Org-ID und Fingerabdruck bleibt
unverändert aktiv. Ein erfolgreicher aktueller CF-Speculative-Plan muss den
tatsächlichen Output-Lesezugang zusätzlich bestätigen. Kein Apply oder Merge
nach `main` ist Teil dieser Integration.

Die lokale Integrationsprüfung mit Terraform 1.15.5 besteht vollständig:
99 Terraform-Testläufe einschließlich der acht erhaltenen/angepassten Bootstrap-
Regressionen, 12 Validierungen und 34 Python-Tests. Formatierung, Adressvertrag,
Schema-Reexport, Workflow-Lint sowie Datei-/Provider-Lock- und Secret-Prüfungen
bleiben erfolgreich. Keine produktiven Provider werden in den Tests ausgeführt.

## Historischer Bootstrap-Umfang und seine Prüfungen

Branch: `feature/btp-handoff-bootstrap`, Basis `main` / `6462e56`.
Die Veröffentlichung erfolgt als Draft-PR gegen `main`. Automatische HCP-PR-Plans
werden nur geprüft; es erfolgt kein Merge oder Apply und keine HCP-Variablenänderung.
Solange `additional_subaccounts` den bisherigen TEST-Eintrag enthält, ist im
automatischen BTP-Plan 1 Add für TEST erwartbar. Das ist keine Bootstrap-Freigabe.

## Umfang und Vertrag

Aus PR #2 (`ab884aa7481c76fd3bae86fcd44b1111d01de9a5`) sind ausschließlich
die kanonische `BTP/landing-zone.yaml`, das providerfreie Modul
`BTP/modules/landing-zone-config/main.tf` und dessen Konfigurationstests
bytegleich übernommen. Keine Infrastrukturmodule, Provideränderungen oder
CF-Änderungen werden übernommen.

`BTP/configuration.tf` verwendet dieselbe Pfadvariable und denselben Modulaufruf
wie PR #2. Als einziger zusätzlicher Root-Output wird veröffentlicht:

```text
cloud_foundry_environments.DEV
  api_url              <- bestehende CF-Environment-Labels["API Endpoint"]
  org_id               <- bestehende CF-Environment-Labels["Org ID"]
  contract_fingerprint <- landing_zone_config.handoff_fingerprints["DEV"]
```

Der Fingerabdruck entsteht im unveränderten Konfigurationsmodul durch
`sha256(jsonencode(contract))`. Vertrag Version 1 umfasst Accountprofil,
Projekt/Stage, Subaccount-Identität und CF-Environment-Identität. Spaces,
Mitgliedschaften und Services gehören nicht zum Hash. Kein Fingerabdruck ist
in der Laufzeitkonfiguration hartcodiert. Der erwartete Test-Vergleichswert ist:

```text
444d0f16abd3373a17cdd4159c596f4ae06e585e60844cad15d4bf39bccbe879
```

Die neuen Output-Preconditions prüfen Legacy-Inputs, Accountprofil und
Subaccount-/CF-Identität gegen die kanonische Konfiguration. Abweichende
Projekt-/Stage-/Regions-/Landscape-Werte werden abgelehnt. Der Bootstrap
migriert keine Identitäten und unterstützt keine neuen Runtime-Parameter-Maps.
Die CF-Sicherheitsprüfung aus PR #2 bleibt vollständig bestehen.

Alle bisherigen versionierten Dateien bleiben bytegleich, insbesondere
`BTP/main.tf`, `BTP/landing_zone.tf`, das Baseline-Modul und die Provider-Locks.
Die YAML steuert während des Bootstraps keine Ressourcen: Ihre aktivierte
TEST-Vorlage aktiviert keinen Subaccount. Dafür bleibt ausschließlich die
bisherige Variable `additional_subaccounts` zuständig. Die Adresse
`btp_subaccount.additional["TEST"]` und sämtliche DEV-Adressen bleiben erhalten.

## Voraussetzung für einen später separat autorisierten echten Plan

In Organisation `sap-ai-landing-zone`, Workspace `sap-btp-core`, muss die
vorhandene Terraform-Variable **`additional_subaccounts`** vor einem neuen echten
Bootstrap-Plan temporär auf **`{}`** gesetzt werden; HCL-Auswertung bleibt aktiv.
Der gegenwärtige Wert enthält TEST mit `region = "us10"` und
`costcenter = "12345"`. Den bisherigen Wert für die spätere Wiederherstellung
im Rahmen der separat freizugebenden TEST-Einführung festhalten.

Diese Anpassung wurde hier **nicht durchgeführt**. Sie betrifft keine
Cloud-Foundry-Variable und schaltet keine Sicherheitsprüfung ab. Ohne sie plant
die unveränderte Legacy-Konfiguration weiterhin die Erstellung von TEST.

Die Variablenänderung wirkt nur auf neue Runs. Der alte wartende TEST-Run
`run-VJfp2u19AvLKhMzq` wird dadurch nicht zu einem Output-Bootstrap. Er bleibt
unbestätigt; auch seine bestehende Workspace-Sperre wurde nicht verändert.
Die spätere Behandlung dieses Runs benötigt einen eigenen autorisierten Schritt.

Bei unverändertem DEV-State ohne Drift und ohne bereits vorhandenen TEST ist
mit `{}` ausschließlich der neue Output zu erwarten: **0 Add / 0 Change /
0 Destroy / 0 Replace**. Ein später separat autorisierter Apply würde den
Handoff im BTP-State veröffentlichen, ohne SAP-/CF-Ressourcen anzulegen oder
umzubauen. Die tatsächlichen Zahlen müssen vor Freigabe am echten Plan geprüft
werden; die lokalen Mock-Tests ersetzen diesen Nachweis nicht.

PR #2 bleibt unverändert. Bei seiner späteren Integration muss die dortige
vollständige `BTP/configuration.tf` mit dieser Bootstrap-Datei zusammengeführt
werden; Modul, Pfadvariable und Output dürfen nicht doppelt definiert werden.
Der dortige Handoff erweitert denselben Vertrag auf zusätzlich aktivierte
CF-Umgebungen.

## Lokale Validierung

Geprüft mit Terraform **1.15.5** in separaten temporären Quellkopien und frischen
`TF_DATA_DIR`-Verzeichnissen. Initialisierung jeweils mit
`-backend=false -lockfile=readonly -input=false`; danach `terraform validate`
und ausschließlich `terraform test` mit `command = plan`. Alle verwendeten
BTP-/Random-/CF-/TFE-Provider sind in den Tests gemockt. Kein HCP-Zugriff und
kein Apply oder Destroy durch die Prüfungen.

- Bootstrap-Root: 7 Tests erfolgreich; exakter Output-Vertrag, leere zusätzliche
  Subaccounts, erhaltene TEST-Adresse sowie Ablehnung widersprüchlicher Inputs.
- Unverändertes Konfigurationsmodul: 21 Tests erfolgreich, einschließlich
  Hash-Stabilität bei Space-/Serviceänderungen und Hash-Änderung bei neuer Identität.
- Vergleich mit einem zusätzlichen Mock-Plan des unveränderten `main`:
  dieselben 10 verwalteten Ressourcenadressen, dieselben konfigurierbaren
  Ressourcenwerte und dieselben bisherigen Root-Outputs. Ausschließlich der neue
  Root-Output `cloud_foundry_environments` kommt hinzu. Zufällige, rein berechnete
  Mock-Attribute wurden anhand der Provider-Schemata aus dem Vergleich entfernt.
- Der berechnete Bootstrap-Output wurde in einer temporären Kopie als
  `tfe_outputs` an die unveränderte CF-Konfiguration aus PR #2 übergeben:
  `dev_handoff_valid` besteht, ohne eine CF-Sicherheitsprüfung zu ändern.
- Neue Terraform-Dateien: `terraform fmt -check` erfolgreich.
- Vollständiger BTP-Formatcheck meldet ausschließlich die bereits auf `main`
  bestehenden Abweichungen in `BTP/main.tf` und
  `BTP/modules/srvc-baseline/srvc_baseline.tf`. Sie bleiben absichtlich unverändert.

Die A/B-Mock-Plans starten mit leerem lokalem Test-State. Ihre identischen
Create-Aktionen sind keine Aussage über Änderungen an realen Ressourcen.
Die Kombination aus bytegleichen Ressourcendefinitionen, verglichenen Plans und
Vertragstests belegt die technische Vorbereitung für einen Output-only-Plan.

Zur Wiederholung den BTP-Quellbaum ohne `.terraform`, States, Runtime-tfvars und
Credentials in ein temporäres Verzeichnis kopieren. Dort beispielsweise:

```sh
TF_DATA_DIR="$BTP_BOOTSTRAP_CHECK/data/root" terraform -chdir="$BTP_BOOTSTRAP_CHECK/BTP" init -backend=false -lockfile=readonly -input=false
TF_DATA_DIR="$BTP_BOOTSTRAP_CHECK/data/root" terraform -chdir="$BTP_BOOTSTRAP_CHECK/BTP" validate
TF_DATA_DIR="$BTP_BOOTSTRAP_CHECK/data/root" terraform -chdir="$BTP_BOOTSTRAP_CHECK/BTP" test
TF_DATA_DIR="$BTP_BOOTSTRAP_CHECK/data/config" terraform -chdir="$BTP_BOOTSTRAP_CHECK/BTP/modules/landing-zone-config" init -backend=false -lockfile=readonly -input=false
TF_DATA_DIR="$BTP_BOOTSTRAP_CHECK/data/config" terraform -chdir="$BTP_BOOTSTRAP_CHECK/BTP/modules/landing-zone-config" validate
TF_DATA_DIR="$BTP_BOOTSTRAP_CHECK/data/config" terraform -chdir="$BTP_BOOTSTRAP_CHECK/BTP/modules/landing-zone-config" test
```
