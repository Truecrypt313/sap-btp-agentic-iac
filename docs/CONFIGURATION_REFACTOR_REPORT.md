# Nachweis: Modular Configuration Architecture

## Ausgangsbasis und Grenzen

`main` wurde am 10.11.2026 mit GitHub per Fast-Forward synchronisiert.
PR [#8](https://github.com/Truecrypt313/sap-btp-agentic-iac/pull/8) ist seit
10.11.2026, 09:05:08 Uhr MEZ integriert; Basis ist
`987d93504bc9752078f2ebc4950ed5046567a49d`. Der Feature-Branch heißt
`refactor/modular-landing-zone-config`.

Dieses Refactoring ändert ausschließlich Konfigurationsquellen, deren Build,
Regressionstests und Dokumentation. Keine Terraform-Implementierungsdatei,
Provider-Version, Lockdatei, Workspace-Einstellung, Variable oder State-Adresse
wird geändert. Es gibt keine Migration, neuen `moved`-Block, `ignore_changes`,
Imports oder Applies. PROD bleibt deaktiviert. IAM-Governance ist reserviert
und nicht aktiv.

Die letzten erfolgreichen Applies wurden vor der Aufteilung lesend über HCP
geprüft (Zeitangaben MEZ):

| Workspace | Letzter erfolgreicher Apply-Run | Abschluss | Ressourcenänderungen im damaligen Apply | Aktueller State |
|---|---|---|---|---|
| `sap-btp-core` | [run-hcw9MSi7re1nvmjk](https://app.terraform.io/app/sap-ai-landing-zone/workspaces/sap-btp-core/runs/run-hcw9MSi7re1nvmjk) | 10.11.2026 09:06:44 | 2 Add, 0 Change, 0 Destroy (TEST-Collections aus PR #8) | Serial 7, `sv-rTqLx5tCyA5oswuz` |
| `sap-cloudfoundry` | [run-LduNJFpb47teiHBV](https://app.terraform.io/app/sap-ai-landing-zone/workspaces/sap-cloudfoundry/runs/run-LduNJFpb47teiHBV) | 08.11.2026 01:31:09 | 0 Add, 0 Change, 0 Destroy | Serial 3, `sv-H1Av6nV81npfnH6m` |
| `sap-cloudfoundry-test` | [run-RkXYSUK54jHKSMgh](https://app.terraform.io/app/sap-ai-landing-zone/workspaces/sap-cloudfoundry-test/runs/run-RkXYSUK54jHKSMgh) | 09.11.2026 18:57:49 | 1 Add, 0 Change, 0 Destroy (TEST-Space) | Serial 1, `sv-CRa1zHYqQNdKgdUC` |

Alle drei Workspaces verwenden Terraform 1.15.5, Remote-Ausführung, bestehende
VCS-Anbindung an `main`, deaktiviertes Auto-Apply und aktivierte Speculative Plans.
Working Directories bleiben `BTP`, `CloudFoundry` und `CloudFoundry/environments`.
Die tatsächlich gelesenen HCP-Trigger waren bei BTP/DEV-CF leere Pattern-/Prefix-
Listen mit `file-triggers-enabled=true`, bei TEST-CF `false`. Die ältere Datei
`schemas/hcp-vcs-triggers.json` beschreibt Vorschläge, keinen live synchronisierten
Bestand. Keine HCP-Trigger werden in diesem PR angepasst.

## Verbraucher und Prüfverträge

| Verbraucher | Verwendung |
|---|---|
| `BTP/configuration.tf` | `yamldecode(file(...))` für typisierte und rohe Konfiguration; Module, BTP-IAM, Diagnosehash und CF-Handoff |
| `CloudFoundry/configuration.tf` | dieselbe Gesamtkonfiguration; DEV-Space, Rollen und Handoff-Validierung |
| `CloudFoundry/environments/main.tf` | dieselbe Gesamtkonfiguration; isoliertes TEST/PROD-Routing und Spaces |
| `BTP/modules/landing-zone-config` | unveränderte Typen, Defaults, Validierung und CF-Contract v1 |
| `scripts/schema_model.py`, `build_landing_zone_schema.py` | bestehendes Modell und daraus erzeugtes Terraform-/JSON-Schema |
| `scripts/validate_landing_zone.py` | Schema-, IAM-, Profil-, Parameter- und Kombinationsprüfungen |
| `scripts/test_landing_zone_schema.py` | bisherige Schema-Regressionsfälle |
| `BTP/modules/{landing-zone-config,srvc-baseline,service-selection,role-collections}/tests` | Tests lesen die kanonische YAML direkt |
| `CloudFoundry/tests/legacy_dev.tftest.hcl` | bestehender DEV-Vertrag und Rollen |
| `BTP/tests`, `CloudFoundry/environments/tests` | Root-/Handoff-Tests; Enterprise-Tests ersetzen YAML nur in temporärer Kopie |
| `scripts/check_landing_zone.py` | Gesamtprüfung; ergänzt um Build-Konsistenz und Snapshot-Kopie für Terraform-Tests |
| `.github/workflows/landing-zone-ci.yml` | alle PRs ohne Pfadfilter; zusätzliche explizite Build-Konsistenzprüfung |
| `scripts/export_provider_schema.py`, `check_repository.py`, `check_state_addresses.py` | unveränderte Schema-, Lock-, Datei- und Adressverträge |

HCP liest ausschließlich die generierte und versionierte Datei. Der Builder ist
keine Laufzeitabhängigkeit von Terraform. Relative Pfade, lokale Modulquellen,
Remote-State-Grenzen und `tfe_outputs` bleiben erhalten.

## Werte, Typen und Gleichheit

Der Snapshot `scripts/fixtures/landing-zone.pre-modular.json` wurde vor Änderung
der ursprünglichen YAML erstellt. `raw` erfasst alle tatsächlich gesetzten Werte,
deren Typen und fehlende Felder. `normalized` wurde unabhängig mit dem bisherigen
Terraform-Modul und Terraform 1.15.5 über eine providerfreie Console ermittelt.
`provenance.source_sha256` dokumentiert zusätzlich die ursprünglichen YAML-Bytes.
Keine HCP-Variablen oder State-Inhalte sind in den Snapshot kopiert worden.

Erfasst sind alle globalen Parameter, vier Katalogdefinitionen, DEV/TEST/PROD,
Aktivierungen, Administratoren, Collections, Bindings, Space-Rollen und Legacy-
Optionen. `schema_version` bleibt die Ganzzahl 2, Flags bleiben Booleans,
`costcenter` bleibt String, `null` bleibt explizit erhalten. Fehlende Felder
werden nicht ergänzt. Maps werden nur für die Ausgabe sortiert, Listen nicht.

Python vergleicht die kompletten Strukturen typensensitiv; nur Modell-Sets
werden beim Vergleich mit dem Terraform-Snapshot entsprechend kanonisiert.
Der neue Terraform-Test `modular_build.tftest.hcl` vergleicht rohe und
normalisierte Strukturen sowie die echten `sha256(jsonencode(...))`-Ergebnisse.

Unveränderte Hashes; der Gesamt- und die Handoff-Hashes wurden außerdem gegen
die geplanten Outputs des letzten erfolgreichen BTP-Applies geprüft:

```text
Gesamtkonfiguration:
7ad88f9a3047420366c17fe07eb5ce702a71227747de1f9a58c0704aa35564a8
CF DEV:
444d0f16abd3373a17cdd4159c596f4ae06e585e60844cad15d4bf39bccbe879
CF TEST:
9d6c14dd0ff81edfcaa25e00dcaed301930770872bcbe88630cb0b2398d62ce0
```

PROD hat wie bisher keinen aktiven CF-Handoff. TEST-Collections behalten die
Rollen-Tripel und `feature-flags!b1765`; DEV behält alle externen HCP-Referenzen.

## Dateien und Build

Neu: die sechs kommentierten YAML-Quelldateien unter `BTP/config/`,
`scripts/build_landing_zone_config.py`, dessen Python-Tests, der unabhängige
JSON-Snapshot, der Terraform-Regressionsfall und diese beiden neuen
Konfigurationsdokumente. Geändert: die generierte `BTP/landing-zone.yaml`,
CI-Workflow, Test-Runner, CI-Vertragstest, README sowie ein Hinweis im bisherigen
Architekturdokument.

Der Builder liest fünf aktive Quellen, prüft deren eindeutige Zuständigkeit,
setzt die vollständige Map zusammen, validiert sie mit den bestehenden Regeln
und schreibt deterministisches UTF-8-YAML mit Warnheader. Die Ausgabe wird erst
nach erfolgreicher Validierung atomar ersetzt. `--check` vergleicht die Bytes
mit dem erwarteten Build und schreibt nichts. `iam/policies.yaml` wird ignoriert.
Details und ausführbare Befehle: [CONFIGURATION.md](CONFIGURATION.md).

## Lokale Validierung

Mit Python 3.12.3, den unveränderten gepinnten Python-Abhängigkeiten,
Terraform 1.15.5 wie HCP und Gitleaks 8.24.3:

| Prüfung | Ergebnis |
|---|---|
| Python-Unittest-Suite | 62 bestanden, einschließlich 20 neuer Build-Tests |
| Terraform-Tests über alle bisherigen Roots/Module und Enterprise-Layout | 141 bestanden, 0 fehlgeschlagen |
| Terraform validate | alle 14 geprüften Roots/Module bestanden |
| `terraform fmt -check -recursive BTP CloudFoundry` | bestanden |
| Build und `--check` | bestanden |
| YAML-/Schema-/Kombinationsvalidierung, einschließlich Beispiele | bestanden |
| generiertes Terraform-/JSON-Schema und Provider-Coverage | bestanden |
| vollständige rohe/normalisierte Gleichheit, IAM, CF und Fingerprints | bestanden |
| bestehender State-Adressvertrag | 17 Basisadressen erhalten |
| Repository-Dateien, Git-Whitespace, Provider-Lockblöcke | bestanden |
| Gitleaks-Verzeichnisprüfung | keine Funde |

Die Tests prüfen insbesondere fehlende Dateien/Pflichtfelder, YAML-Syntax,
falsche Typen, doppelte Schlüssel, unzulässige Environment-Wrapper/-Dateien,
Determinismus über mehrere Prozesse, veraltete/ungültige generierte Dateien,
unveränderte IAM-/Legacy-Werte und die Nichtaktivierung von Policies.

Die abschließenden GitHub-CI-Ergebnisse, drei HCP-Speculative-Plans samt
Commit-Zuordnung, Output-Vergleich und Secret-Scan des Commit-Bereichs werden
im Pull Request und Abschlussbericht festgehalten. Maßstab pro Workspace:
0 Add / 0 Change / 0 Destroy / 0 Replace; keine Output-/Hash-Änderungen.
Ein lokaler Mock-Test ersetzt diesen Vergleich mit dem realen Bestand nicht.

## Bestehende Ressourcenadressen

Aus den Plan-JSONs der oben genannten erfolgreichen Applies lesend erfasst;
mit den aktuellen State-Metadaten abgeglichen. Der persönliche Admin-Schlüssel
ist hier redigiert und bleibt im tatsächlichen State unverändert. Die anderen
Stage-/Service-/Collection-/Space-Schlüssel sind vollständig angegeben.

### sap-btp-core

```text
btp_subaccount.additional["TEST"]
btp_subaccount.project_subaccount
btp_subaccount_environment_instance.cloudfoundry
btp_subaccount_role_collection_assignment.emergency_administrators["<bestehender Benutzer>"]
module.environment["TEST"].module.cloud_foundry["primary"].btp_subaccount_environment_instance.this
module.environment["TEST"].module.role_collections.btp_subaccount_role_collection.this["feature_flags_administrator"]
module.environment["TEST"].module.role_collections.btp_subaccount_role_collection.this["feature_flags_auditor"]
module.environment["TEST"].module.services.btp_subaccount_entitlement.this["alert_notification"]
module.environment["TEST"].module.services.btp_subaccount_entitlement.this["feature_flags"]
module.environment["TEST"].module.services.btp_subaccount_entitlement.this["feature_flags_dashboard"]
module.environment["TEST"].module.services.btp_subaccount_service_instance.this["alert_notification"]
module.environment["TEST"].module.services.btp_subaccount_subscription.this["feature_flags_dashboard"]
module.srvc_baseline.btp_subaccount_entitlement.alert_notification_service_standard
module.srvc_baseline.btp_subaccount_entitlement.feature_flags_dashboard_app
module.srvc_baseline.btp_subaccount_entitlement.feature_flags_service_lite
module.srvc_baseline.btp_subaccount_service_instance.alert_notification_service_standard
module.srvc_baseline.btp_subaccount_subscription.feature_flags_dashboard_app
random_uuid.uuid
terraform_data.cf_landscape_label
```

### sap-cloudfoundry

```text
cloudfoundry_space.project_space
cloudfoundry_space_role.space_developer
cloudfoundry_space_role.space_manager
```

### sap-cloudfoundry-test

```text
module.spaces.cloudfoundry_space.this["project"]
```
