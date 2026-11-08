# Audit-Korrekturen und PR-Prüfvertrag

Aktualisierung nach dem separaten Bootstrap: Der DEV-Handoff ist inzwischen im
BTP-State Serial 2 veröffentlicht. Die folgenden Audit-Ergebnisse beschreiben
den Stand vor seiner Einführung. Den aktuellen Integrationsstand dokumentiert
[Bootstrap und Integration](BTP_HANDOFF_BOOTSTRAP.md).

Stand: 07.11.2026. Branch: `feature/modular-btp-landing-zone`.
Keine HCP-Einstellungen, Variablen oder States wurden verändert. Kein Commit,
Push, PR, HCP-Run, Apply oder Destroy wurde ausgeführt.

## Sieben Befunde und Korrekturen

| Audit-Befund | Korrektur | Regression |
|---|---|---|
| P1 HCP-/CI-Abdeckung | Ungefilterter PR-/Merge-Queue-Workflow; maschinenlesbare HCP-Triggervorschläge; Prüfung tatsächlicher lokaler Modulabhängigkeiten | `test_ci_contract.py` prüft fehlende Pfade, überspringbare Checks und Berechtigungen |
| P1 stille Serviceüberschreibung | Getrennte Quelllisten; eindeutige Schlüssel vor Auswertung des Merge-Ergebnisses für Entitlements, Instances und Subscriptions | `service-selection/tests/collisions.tftest.hcl`, Katalog- und Preset-Kollisionen aller drei Arten |
| P1 ungeprüfte explizite DEV-Plan-ID | Baseline und generische Instanzen verwenden dieselbe tatsächliche Offering-/Plan-/Ready-/Sharing-/Plattform-Prüfung | `service-plan-rules/tests/identity.tftest.hcl`; Baseline-Test erzwingt die Ablehnung eines negativen Prüfergebnisses bei expliziter ID |
| P2 ignorierte CF-Legacy-Rollen | Nur DEV/project erlaubt; alle anderen Kontexte und direkte generische Modulaufrufe lehnen sie ab | Schema-, Python-, Spaces-Tests; DEV-Root-Test prüft Weiterleitung an beide bisherigen Rollenadressen |
| P2 Administrator-Dubletten | Vergleich vollständiger Rolle/Subjekt/Origin-Tupel einschließlich konfigurierter Administratorrolle und Providerdefault `ldap` | Custom-Admin-Dublette, andere Rolle/Origin, null/ldap und doppelte Gruppen |
| P2 abweichende Konfiguration/Handoff | Alle ausführbaren Roots erlauben ausschließlich die kanonische YAML; DEV prüft Org-ID, Endpoint und BTP-Identitätsfingerabdruck | Pfadablehnung in allen Roots; fehlende/falsche/veraltete Handoffs; unveränderte Hashes bei Space-/Serviceänderungen |
| P2 unvollständige Secret-Prüfung | Gemeinsame Schlüsselrichtlinie in Python/generierten TF-Validierungen; Gitleaks-Datei- und Commit-Scan mit Redigierung | Verschachtelte token/secret/API-Key-Felder; echter Scanner mit synthetischem Token und unterdrücktem Inline-Allow |

Die Snapshot-Abdeckung umfasst weiterhin acht implementierte Ressourcentypen
mit 54 beschreibbaren Provider-Attributen. Das Manifest allein ist kein
Datenflussbeweis; Kontexte und tatsächliche Modulweiterleitung sind zusätzlich
geprüft und durch die gezielten Regressionen abgesichert.

## YAML-Attribute und Eigentümerschaft

| Attributgruppe | Umsetzung / ausdrückliche Grenze |
|---|---|
| schema_version, account_type, project_name | Version, Profil-/Lizenzprüfung, Namensableitung; keine Credentials |
| Subaccount-Attribute | DEV bleibt im Root, TEST/PROD unter `btp_subaccount.additional[stage]`; Name, Subdomain, Region, Beschreibung, Parent, Labels, usage, beta_enabled und skip_auto_entitlement werden weitergereicht |
| iaas_provider und runtime | Auswahl-/Validierungsbedingungen über `btp_regions`, keine erfundenen API-Argumente |
| enabled | Steuert zusätzliche Umgebungen; bestehendes DEV/CF darf nicht deaktiviert werden |
| administrators_source, administrators, administrator_options | YAML oder ausdrücklich bestehender DEV-HCP-Input; Rolle und Origin werden bei Ressourcen und Dubletten gleichermaßen verwendet |
| role_assignments | User-, Gruppen- und Attributsubjekte mit vorhandener Role Collection; Mehrdeutigkeiten werden abgelehnt |
| cloud_foundry | BTP besitzt Environment/Org und alle dessen beschreibbaren Attribute; API/Org kommen aus tatsächlichen Provider-Ausgaben |
| spaces | Nur im zugehörigen CF-State; Name, SSH, Isolation, Labels und Annotations werden weitergereicht |
| managers, developers, member_origin, roles | Generisches Space-Modul; für DEV/project bleiben einfache Mitgliederlisten leer, member_origin wird ausdrücklich abgelehnt; zusätzliche explizite Rollen sind möglich |
| legacy_manager/developer | Ausschließlich bestehendes DEV/project; GUID/Username und Origin werden an die ursprünglichen zwei Root-Ressourcen weitergereicht |
| Service-Presets, Custom-Einträge, Katalog-Aliase | Eindeutige Schlüssel, tatsächliche Entitlement-/Plan-/Quoten-/Subscription-Kataloge; Baseline-Adressschutz |
| amount, plan_unique_identifier, catalog_amounts, profiles | Quoten-/Preisvarianten-/Profilprüfungen; Katalogdefinitionen werden erst bei Auswahl aktiviert |
| Instanz-/Subscription-Optionen | Namen, IDs/Plannamen, Labels, Sharing, Plattform, Parameter und Timeouts über Baseline oder generische Module |
| parameters / parameters_key | Nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Maps; Credential-Schlüssel in direktem JSON werden abgelehnt |

Optionen deaktivierter Umgebungen/Dienste sowie nicht ausgewählte Katalogeinträge
sind bewusst inaktive Vorlagen, keine Ressourcenanforderungen. Unbekannte oder
nur gelesene Provider-Attribute werden durch das rohe YAML-Schema abgelehnt.
Broker-spezifische Semantik und die Auflösung gleicher Benutzeridentitäten unter
verschiedenen GUID-/Username-Darstellungen bleiben API-/Betriebsbedingungen.

## Ein Konfigurationspfad und ein enger Handoff

Die ausführbaren Roots akzeptieren nur diese äquivalenten relativen Pfade:

- BTP: `landing-zone.yaml`
- DEV-CF: `../BTP/landing-zone.yaml`
- TEST/PROD-CF: `../../BTP/landing-zone.yaml`

Alternative Werte für `landing_zone_config_file` werden ausdrücklich abgelehnt.
Ein Enterprise-Ziel benötigt weiterhin eigene Account-/Workspace-Bindungen.
Dort wird die bewusst geprüfte Vorlage als kanonische `BTP/landing-zone.yaml`
versioniert; ein HCP-Pfad-Override ist kein Umschaltmechanismus.

`cloud_foundry_environments[stage]` veröffentlicht `api_url`, `org_id` und
`contract_fingerprint`. Der Hash-Vertrag Version 1 umfasst pro Umgebung nur
Accountprofil, Projekt/Stage, Subaccount-Identität und CF-Environment-Identität.
Spaces, Mitgliedschaften, Services, Kostenstelle, Labels, Beschreibungen und
Timeouts sind ausgeschlossen. Änderungen anderer Umgebungen beeinflussen den
Hash nicht. Beide CF-Roots prüfen den passenden Fingerabdruck; DEV prüft
zusätzlich die bisherigen HCP-Inputs gegen die veröffentlichten Org-/API-Werte.
Der vollständige `landing_zone_configuration_fingerprint` bleibt diagnostisch
und wird nicht mehr als CF-Deployment-Sperre verwendet.

**Übergangsvoraussetzung:** Der bisherige BTP-State veröffentlicht diesen neuen
Handoff noch nicht. DEV-CF lehnt den fehlenden Vertrag bewusst ab. Vor einem
echten erfolgreichen DEV-CF-Plan müssen die BTP-Ausgaben in einem separat
geprüften, später ausdrücklich autorisierten BTP-Schritt veröffentlicht werden.
Der vorhandene wartende TEST-Plan darf dafür nicht ungeprüft bestätigt werden.
Es gibt keinen Rückfall auf ungeprüfte IDs und keinen automatischen Apply.
Der zusätzlich benötigte TFE-Runtime-Zugang muss auf die erforderlichen Outputs
beschränkt werden; dafür wurden jetzt keine HCP-Variablen angelegt.

## CI-Pipeline

Workflow: `.github/workflows/landing-zone-ci.yml`, Checkname
`Landing zone checks`. Er läuft ohne Pfad-/Branchfilter auf `pull_request`,
`merge_group` und bei ausdrücklich manueller Workflow-Ausführung.

- Nur `contents: read`, keine produktiven Secrets, kein `pull_request_target`.
- Checkout ohne persistierte Credentials; Actions auf vollständige Commit-SHAs festgelegt.
- Terraform 1.15.5 passend zu HCP; gepinnte Python-Abhängigkeiten.
- Git-Diff-/Dateisicherheit, Adressvertrag, YAML/JSON-Schema und Generator-Drift.
- Reale Provider-Schemata aus gelockten Binaries via `--refresh --check`.
- Terraform fmt, backendfreies Init, Validate und ausschließlich lokale Mock-/providerfreie Plan-Tests.
- Gitleaks 8.24.3 mit festem SHA256; Dateisatz einschließlich ungetrackter lokaler Quellen und zusätzlich die PR-Commits. Ausgabe wird redigiert; Inline-Allow und Repository-Ignoredateien können den Scan nicht abschalten.
- Kein Apply, HCP-Run, Upload von States/Plänen oder automatischer Merge.

In GitHub muss `Landing zone checks` später als erforderlicher Check im
Branchschutz eingerichtet werden. Dies ist eine externe Einstellung und wurde
nicht verändert. Fork-PRs können weiterhin die übliche GitHub-Freigabe für das
Ausführen fremden Codes erfordern; es gibt keine selbstgebaute Skip-Bedingung.

Die Enterprise-Integrationstests ersetzen die kanonische YAML ausschließlich in
einer temporären Prüfkopie durch die versionierte Beispielvorlage. Test-Mocks
verwenden keine alternativen Deployment-Pfade und schreiben keine echten States.

## Konkrete HCP-VCS-Einstellungen – nur Vorschlag

Lesender MCP-Befund am 07.11.2026 für beide Workspaces: Dateifilter aktiv,
`trigger-patterns=[]`, `trigger-prefixes=[]`, Branch `main`, Terraform 1.15.5.
Die bisherigen Working Directories bleiben `BTP` und `CloudFoundry`.

Autoritative maschinenlesbare Vorschläge: `schemas/hcp-vcs-triggers.json`.
Für beide: `file-triggers-enabled=true`, `trigger-prefixes=[]`. Explizite
`trigger-patterns`:

| Workspace | Muster relativ zur Repository-Wurzel |
|---|---|
| sap-btp-core | `/BTP/**`, `/schemas/**`, `/scripts/**` |
| sap-cloudfoundry | `/CloudFoundry/**`, `/BTP/landing-zone.yaml`, `/BTP/modules/landing-zone-config/**`, `/schemas/**`, `/scripts/**` |

Das sind vollständige eigene Root-Unterbäume plus die tatsächlich gemeinsamen
Abhängigkeiten. BTP benötigt keinen Trigger auf den unabhängigen CF-Root; CF
benötigt nicht sämtliche ausschließlich BTP-internen Module. Schema/Scripts
werden für beide zusätzlich berücksichtigt. Änderungen an Workflow und anderen
Dateien erhalten unabhängig davon immer den ungefilterten GitHub-CI-Check.
Die CI prüft rekursiv, dass sämtliche lokalen Modulquellen von diesen Vorschlägen
erfasst werden; neue gemeinsame Abhängigkeiten können nicht still hinzukommen.
Für neue TEST/PROD-CF-Workspaces sind Root und Module unter CloudFoundry sowie die
gemeinsame YAML, Konfigurationsmodul, Schemas und Scripts entsprechend zu erfassen.

VCS-Source-Directory bleibt Repository-Wurzel, automatische Speculative-Plans
bleiben aktiviert, Auto-Apply bleibt aus. **Keine dieser Einstellungen wurde
übernommen.** HCP-Patterns filtern auch PR-Plans; ihre spätere Umsetzung benötigt
einen separat autorisierten Einstellungsschritt.

Primärquelle: [HCP-Workspace-API](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/workspaces).

## Lokale Wiederholung

Linux x86_64, Python 3.12 und Terraform 1.15.5:

```sh
python3 -m venv /tmp/btp-lz-check
/tmp/btp-lz-check/bin/python -m pip install -r scripts/requirements.txt
/tmp/btp-lz-check/bin/python scripts/install_gitleaks.py /tmp/btp-lz-tools
GITLEAKS_BINARY=/tmp/btp-lz-tools/gitleaks /tmp/btp-lz-check/bin/python scripts/check_landing_zone.py
/tmp/btp-lz-check/bin/python scripts/export_provider_schema.py --refresh --check
/tmp/btp-lz-check/bin/python scripts/check_repository.py --base main
/tmp/btp-lz-check/bin/python scripts/run_secret_scan.py --gitleaks /tmp/btp-lz-tools/gitleaks --base main
```

Die bestehenden Lockblöcke bleiben unverändert. Der DEV-CF-Root erhält lediglich
zusätzlich den bereits für den neuen CF-Root gelockten TFE-Provider 0.83.0 samt
identischen Prüfsummen. Es erfolgt kein Provider-Upgrade.

## Freigabegrenzen

Die lokalen Prüfungen belegen die Regeln und erhaltenen Adressen. Sie beweisen
keine Ersatzfreiheit gegen den echten aktuellen State. Vor einem Merge sind
zusätzlich die tatsächlichen Speculative-Plans und die oben beschriebene
Handoff-Einführung zu berücksichtigen. HCP-Trigger, Output-Zugang und GitHub-
Branchschutz sind noch externe Voraussetzungen, keine lokal ungelösten
Funktionsfehler. Sie wurden im Rahmen dieser Aufgabe bewusst nicht verändert.

## Abschließende lokale Prüfergebnisse

In einer frisch installierten Python-3.12-Umgebung mit den gepinnten
Abhängigkeiten sowie Terraform 1.15.5 und zusätzlich 1.17.1 bestanden jeweils:

- 91 Terraform-Testläufe in 13 Suiten, ausschließlich Mock-/providerfreie Plans.
- 12 Terraform-Validierungen mit frischen temporären TF_DATA_DIR-Verzeichnissen.
- 34 Python-Tests einschließlich CI-/Dateisicherheits- und realer Scanner-Regressionsfälle.
- Terraform fmt, YAML-Beispiele, JSON-Schema, Schema-Generator und 17 bestehende/geplante Basisadressen.

Provider-Reexport mit `--refresh --check`, Workflow-Prüfung mit actionlint 1.7.7,
Repository-/Lockblock-Prüfung und redigierter Secret-Scan waren erfolgreich.
Der lokale Commit-Scan umfasst derzeit null neue Commits, da nichts committet
wurde; die Dateiprüfung erfasst dennoch alle lokalen Änderungen und ungetrackten
Dateien. GitHub-Ausführung selbst wurde nicht gestartet und bleibt zu bestätigen.

Erneut gelesene HCP-States: BTP Serial 1, CF Serial 2, unverändert. Aktive YAML,
Provider-Snapshot und Adressvertrag bleiben bytegleich zum Auftragsbeginn.
Keine vorhandene Provider-Version oder deren Lockblock wurde verändert.

Bewertung: für einen Code-Review vorbereitet; keine Merge-/Deployment-Freigabe.
Vor einer erfolgreichen echten CF-Integration fehlen der veröffentlichte
BTP-Handoff, dessen Output-Lesezugang und die separat vorzunehmenden externen
Trigger-/Branchschutz-Einstellungen. Es wurde kein echter Plan zum Nachweis
fehlender Replacements erstellt, da dies nicht autorisiert war.

## Dateiumfang dieses Auftrags

45 Dateien wurden gegenüber dem lokalen Zustand bei Auftragsbeginn verändert
oder ergänzt, davon 15 neu. Die zwei bereits vorhandenen ungetrackten
Nachweis-/Cheatsheet-Dokumente erhielten ausschließlich eine Bereinigung
abschließender Leerzeichen für die angeforderte Git-Diff-Prüfung.

- `.github/workflows/landing-zone-ci.yml`
- `BTP/configuration.tf`
- `BTP/modules/btp-environment/main.tf`
- `BTP/modules/environment-services/main.tf`
- `BTP/modules/landing-zone-config/main.tf`
- `BTP/modules/landing-zone-config/tests/schema.tftest.hcl`
- `BTP/modules/role-assignments/main.tf`
- `BTP/modules/role-assignments/tests/identity.tftest.hcl`
- `BTP/modules/service-plan-rules/main.tf`
- `BTP/modules/service-plan-rules/tests/identity.tftest.hcl`
- `BTP/modules/service-selection/main.tf`
- `BTP/modules/service-selection/tests/collisions.tftest.hcl`
- `BTP/modules/srvc-baseline/srvc_baseline.tf`
- `BTP/modules/srvc-baseline/tests/identity.tftest.hcl`
- `BTP/tests/enterprise/layout.tftest.hcl`
- `BTP/tests/landing_zone.tftest.hcl`
- `CloudFoundry/.terraform.lock.hcl`
- `CloudFoundry/configuration.tf`
- `CloudFoundry/environments/main.tf`
- `CloudFoundry/environments/tests/handoff.tftest.hcl`
- `CloudFoundry/modules/spaces/main.tf`
- `CloudFoundry/modules/spaces/tests/spaces.tftest.hcl`
- `CloudFoundry/provider.tf`
- `CloudFoundry/tests/legacy_dev.tftest.hcl`
- `README.md`
- `docs/ATTRIBUTE_REFERENCE.md`
- `docs/AUDIT_REMEDIATION.md`
- `docs/GITOPS_INTEGRATION_NACHWEIS.md`
- `docs/MODULAR_LANDING_ZONE.md`
- `docs/SCHEMA_CATALOG_TEMPLATE.md`
- `docs/TERRAFORM_MCP_CHEATSHEET.md`
- `schemas/hcp-vcs-triggers.json`
- `schemas/landing-zone.schema.json`
- `scripts/build_landing_zone_schema.py`
- `scripts/check_landing_zone.py`
- `scripts/check_repository.py`
- `scripts/install_gitleaks.py`
- `scripts/requirements.txt`
- `scripts/run_secret_scan.py`
- `scripts/schema_model.py`
- `scripts/security_policy.py`
- `scripts/test_ci_contract.py`
- `scripts/test_landing_zone_schema.py`
- `scripts/test_secret_scanner.py`
- `scripts/validate_landing_zone.py`
