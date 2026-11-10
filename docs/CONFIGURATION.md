# Modulare Landing-Zone-Konfiguration

Die bearbeitbaren Quellen liegen in `BTP/config/`. Der Python-Builder erzeugt
daraus die weiterhin versionierte `BTP/landing-zone.yaml`. Alle bestehenden
Terraform-Roots lesen ausschließlich dieses Artefakt über `yamldecode(file(...))`.
Ein HCP-Run benötigt weder Python noch einen vorgeschalteten Build.

Neue Projekte werden zusätzlich unter `BTP/config/projects/<project_id>/`
beschrieben und separat nach `BTP/generated/<project_id>/landing-zone.yaml`
gebaut. Die bestehenden Project-ABC-Pfade und ihr Format bleiben unverändert.
Details: [Multi-Project-Architektur](MULTI_PROJECT_ARCHITECTURE.md).

```text
BTP/
├── landing-zone.yaml                 generierter, versionierter Terraform-Eingang
├── config/
│   ├── project.yaml                  globale Projektparameter
│   ├── service-catalog.yaml          Definitionen, keine Aktivierungen
│   ├── environments/
│   │   ├── dev.yaml                  ausschließlich DEV, einschließlich Legacy
│   │   ├── test.yaml                 ausschließlich TEST, einschließlich IAM
│   │   └── prod.yaml                 ausschließlich PROD, deaktiviert im Trial
│   └── iam/
│       └── policies.yaml             reserviert, nicht eingelesen oder erzwungen
├── modules/                         bestehende Module unverändert
└── configuration.tf                 bestehender YAML-Einstieg unverändert
```

Weitere Dateien und Terraform-Roots bleiben an ihren bisherigen Orten.

## Verantwortung und Format

`project.yaml` enthält genau die Pflichtfelder `schema_version` (Ganzzahl,
weiterhin 2), `account_type` (`trial`/`enterprise`) und `project_name` (String).
Keine umgebungsspezifischen Werte dort ergänzen.

`service-catalog.yaml` enthält genau die Map `service_catalog`. Die vier
bisherigen Aliase, Service-/Plan-Namen, Account-Profile und optionalen Maps für
Instanzen und Subscriptions bleiben erhalten. Eine Alias-Definition erstellt
keine Ressource und garantiert keine Verfügbarkeit im konkreten Account.

Jede Environment-Datei enthält genau eine Map: `DEV:`, `TEST:` beziehungsweise
`PROD:`. Ihr Inhalt entspricht unverändert dem bisherigen
`environments.<STAGE>`-Objekt. Es gibt keine gemeinsame Environment-Basis, keine
Vererbung und kein tiefes Überschreiben. Explizite und ausgelassene Felder bleiben
dadurch sichtbar; Defaults werden nicht unbemerkt geändert.

Der Builder verlangt alle fünf aktiven Quelldateien und erlaubt nur die drei
bekannten Environment-Dateinamen. Doppelte YAML-Schlüssel, fremde Stage-Schlüssel,
unbekannte Attribute, falsche Typen, YAML-Aliase und nicht JSON-kompatible Typen
werden abgewiesen. Strings, endliche Zahlen, Booleans, `null`, Listen und Maps
bleiben erhalten. Die fünfstellige Kostenstelle bleibt beispielsweise ein
String. Weder Defaults noch HCP-Variablen werden in die Ausgabe eingesetzt.

`iam/policies.yaml` wird absichtlich überhaupt nicht vom Builder gelesen. Die
leere `policies`-Map hat noch keinen aktiven Schema-Vertrag und gelangt nicht
in Terraform. Eine Änderung dort hat derzeit keine Berechtigungswirkung.

## Täglicher Workflow

Im Repository-Root mit Python 3.12 und Terraform 1.15.5 wie in CI/HCP:

```bash
python3 -m venv /tmp/btp-config-venv
source /tmp/btp-config-venv/bin/activate
python -m pip install -r scripts/requirements.txt

# Gewünschte Umgebung bearbeiten, beispielsweise TEST:
${EDITOR:-vi} BTP/config/environments/test.yaml
python scripts/build_landing_zone_config.py
python scripts/build_landing_zone_config.py --check
python scripts/validate_landing_zone.py
git diff -- BTP/config BTP/landing-zone.yaml
```

Quellen und generierte Datei immer gemeinsam committen. `--check` schreibt
nichts und schlägt auch bei fehlendem Header, ungültiger, fehlender oder veralteter
Ausgabe fehl. Manuelle Änderungen an `landing-zone.yaml` würden beim nächsten
Build überschrieben und werden deshalb von CI zurückgewiesen.

Für die vollständigen lokalen Prüfungen:

```bash
python scripts/install_gitleaks.py /tmp/btp-config-tools
export GITLEAKS_BINARY=/tmp/btp-config-tools/gitleaks
python -m unittest discover -s scripts -p 'test_*.py'
python scripts/check_landing_zone.py
python scripts/check_repository.py --base main
python scripts/run_secret_scan.py --gitleaks "$GITLEAKS_BINARY" --base main
terraform fmt -check -recursive BTP CloudFoundry
```

`check_landing_zone.py` umfasst bereits Python-Tests, Build-/Schema-Prüfung,
State-Adressvertrag, Formatprüfung und sämtliche Terraform-Validierungen und
Mock-Tests einschließlich Enterprise-Beispiel. Terraform läuft in temporären
Kopien mit deaktivierten Backends und `command = plan`; keine echten Ressourcen
oder HCP-Workspaces werden geändert. Der Gitleaks-Scanner ist für die
Sicherheitstests erforderlich. Der Refresh-Vergleich des Provider-Schemas läuft
zusätzlich in GitHub-CI gegen die unveränderten Lockfiles.

## Änderungen an DEV, TEST und PROD

DEV behält `administrators_source: legacy`. Deshalb kommt die bestehende
Administratorliste weiterhin aus HCP `subaccount_emergency_admins`; die leere
YAML-Liste bedeutet hier keinen Rechteentzug. Die ursprünglichen
Kompatibilitätsprüfungen für Projekt, Stage, Region, Kostenstelle, CF-Landscape
und `additional_subaccounts` bleiben aktiv. HCP-Eingaben nicht im Zuge dieses
Refactorings entfernen, kopieren oder umstellen.

Der DEV-Space `project` behält `dev-project-abc`, leere `managers`/`developers`
und `legacy_manager: null`/`legacy_developer: null`. Die beiden historischen
CF-Root-Ressourcen beziehen ihre Identitäten weiterhin aus HCP
`cf_space_manager`/`cf_space_developer`. Neue explizite Space-Rollen sind eine
eigene Berechtigungsänderung; doppelte Bindings vermeiden.

TEST bleibt aktiviert mit `test-space-project-abc`, Alert Notification und
Feature-Flags-Dashboard. Die bereits bereitgestellten Collections
`TEST_FeatureFlags_Administrator` und `TEST_FeatureFlags_Auditor` behalten exakt
ihre Rollennamen, Role Templates und `feature-flags!b1765` als Application ID.
Es existieren weiterhin keine YAML-Nutzerzuweisungen zu diesen Collections.
Neue Bindings müssen die geprüfte Origin `sap.default` explizit angeben.

PROD bleibt ausdrücklich `enabled: false` und CF ebenfalls aus. Das bestehende
Trial-Verbot für aktives PROD gilt unverändert. Ausgelassene Felder erhalten
weiterhin ihre bisherigen Moduldefaults; insbesondere darf das PROD-Flag nicht
entfernt werden (`enabled` hat allgemein den Schema-Default `true`).

Umgebung, Subaccount, CF-Org, Service oder Rolle zu deaktivieren kann Ressourcen
entfernen beziehungsweise Berechtigungen entziehen. `prevent_destroy` schützt
nicht vor jeder Änderung. Tatsächliche Konfigurationswechsel anhand eines
eigenen Plans und fachlichen Reviews beurteilen.

## Services hinzufügen

Zuerst Service-/Plan-Namen und Account-Verfügbarkeit im tatsächlichen BTP-Katalog
prüfen. Eine neue Definition kommt unter einem stabilen Alias in
`service-catalog.yaml`, beispielsweise mit `service_name`, `plan_name`, `profiles`
und optional `instance` oder `subscription`. Danach den Alias in der gewünschten
Environment-Datei über `services.catalog` aktivieren. Beispiel für das Format
(nicht zusätzlich zu einer vorhandenen gleichwertigen Komfortaktivierung setzen):

```yaml
TEST:
  # Übrige bisherige TEST-Felder beibehalten.
  services:
    catalog: [alert_standard]
```

Die bereits existierenden Komfortfelder `alert_notification`, `feature_flags`
und `work_zone` bleiben unterstützt. Gleichwertige Entitlements, Instanznamen
oder Subscriptions dürfen nicht über beide Wege doppelt aktiviert werden.
Entitlements gewähren Planberechtigung/Quote, Instanzen erstellen Services,
Subscriptions abonnieren Anwendungen. Benutzerberechtigungen sind davon getrennt.
Bei Feature Flags ist `instance: false` bewusst explizit gesetzt: der bestehende
Schema-Default wäre `true`. Dashboard-Default ist ebenfalls `true`.

Parameter enthalten nur nicht geheime JSON-Objekt-Strings. Secrets bleiben in
den bestehenden sensitiven HCP-Maps `instance_parameters`,
`subscription_parameters` und `environment_parameters`, referenziert über
`parameters_key` und `STAGE/<key>`. Keine Credentials in Quellen, Ausgabe,
Snapshots oder Commit-Nachrichten schreiben. Der Builder unterdrückt ungültige
Eingabewerte in Fehlermeldungen und schreibt erst nach erfolgreicher Validierung;
CI ergänzt den Secret-Scan.

## IAM heute und später

BTP-IAM wird pro Umgebung in `administrators`, `administrator_options`,
`role_collections` und `role_assignments` gepflegt. Collections enthalten exakte
Rollen-Tripel und gewähren allein noch niemandem Rechte. Benutzer-, Gruppen- und
Attributzuweisungen referenzieren eine externe Collection per Name oder eine
verwaltete per stabilem Schlüssel. Gruppen/Attribute sowie verwaltete Collections
verlangen eine explizite IdP-Origin. `null` bedeutet Providerverhalten und ist
keine Zusage einer bestimmten Identitätsquelle. Origin-Wechsel können eine
andere Identität berechtigen. Origins referenzieren bestehende Identity Provider.

Cloud-Foundry-IAM ist ein eigenständiger Berechtigungsbereich. Die vorhandenen
Roots verwalten Space-Rollen und Mitgliedschaften; BTP erstellt CF-Environments
und veröffentlicht Org-/API-Handoffs. BTP-Administratorrechte verleihen nicht
automatisch CF-Space-Rechte. Eine zentrale Verwaltung von CF-Org-Rollen oder
Benutzern ist in diesem PR nicht implementiert.

Die reservierte `iam/policies.yaml` soll später alle drei Umgebungen in einer
Governance-Sicht erfassen: Rollen-Discovery, kritische Administratorrollen,
Least Privilege, zulässige Kombinationen, Separation of Duties sowie Prüf- und
Freigaberegeln. KI-Analysen sollen überprüfbare Änderungsvorschläge liefern.
Vor Aktivierung sind ein separates Schema, Validatoren, Module und Reviews nötig;
Policy-Felder dürfen nicht ungeprüft dem heutigen Terraform-Schema hinzugefügt
werden. Die pro Umgebung bestehenden IAM-/CF-Einstiegspunkte bleiben verwendbar.

## Terraform und HCP

Organisation: `sap-ai-landing-zone`; unveränderte Root-Zuordnung:

| HCP-Workspace | Working Directory | YAML-Pfad relativ zum Root |
|---|---|---|
| `sap-btp-core` | `BTP` | `landing-zone.yaml` |
| `sap-cloudfoundry` | `CloudFoundry` | `../BTP/landing-zone.yaml` |
| `sap-cloudfoundry-test` | `CloudFoundry/environments` | `../../BTP/landing-zone.yaml` |

Alle nutzen das bestehende `BTP/modules/landing-zone-config`. Remote States,
`tfe_outputs`-Zugriff auf BTP-Outputs, Workspace-Routing, Provider-Versionen und
Lockfiles ändern sich nicht. Ein normaler HCP-Plan verwendet die im Commit
enthaltene Ausgabe. Keine `local-exec`-/External-Data-Source oder Build-Abhängigkeit
wurde ergänzt. Der PR verändert keine HCP-Einstellungen oder Trigger.

Der vollständige Konfigurationshash wird weiterhin mit
`sha256(jsonencode(local.configuration))` berechnet. Die getrennten
CF-Handoff-Fingerprints verwenden weiterhin den bestehenden Contract v1 pro
aktivierter CF-Umgebung. Reine Kommentar-/Dateiaufteilungsänderungen dürfen
keinen dieser Hashes ändern. Die vollständige YAML bleibt für alle Roots gleich.

## Regression und CI

Der vor der Umstellung erstellte Snapshot
`scripts/fixtures/landing-zone.pre-modular.json` enthält die vollständige
ursprüngliche Struktur, unabhängig mit Terraform 1.15.5 normalisierte Daten,
Hashes und Herkunftscommit. Er enthält keine HCP-Variablen oder State-Inhalte.
Die historischen Tests verwenden seine eingefrorenen Eingaben. Python prüft
deren vollständige Struktur typensensitiv, einschließlich
fehlend/`null`, IAM und Legacy-Werten. Der neue providerfreie Terraform-Test
prüft dieselben Daten nach echter Modulnormalisierung und beide Hash-Verträge.
Terraform-Sets werden beim Python-Vergleich nur an im Modell deklarierten
Set-Feldern kanonisiert; Quelllisten bleiben unverändert.

Der Snapshot bleibt als historischer Migrationsnachweis unverändert und wird
nicht vom Builder aktualisiert. Aktuelle Artefakte werden gegen ihre Quellen
und gezielte Sicherheits-/Legacy-Invarianten geprüft. Für ein konkretes
Configuration-Refactoring kann zusätzlich
`check_project_abc_compatibility.py --base <Ausgangscommit>` vollständige
Unverändertheit nachweisen. So bleiben spätere beabsichtigte Sollzustandsänderungen
möglich. Einen unerwarteten Hash niemals nur durch Neugenerierung von
Erwartungen akzeptieren.

GitHub-CI läuft für jeden PR, prüft Quellen gegen das versionierte Artefakt,
Schema, Tests, State-Adressen, Provider-Locks, Secrets und unveränderte generierte
Schemas. Tests umfassen fehlende/ungültige Dateien, Typfehler, doppelte/fremde
Environment-Schlüssel, Determinismus, unveränderte IAM-Daten und Fingerprints
sowie veraltete oder ungültige Ausgaben. HCP-Speculative-Plans prüfen zusätzlich
den realen Bestand: erwartet sind je Workspace 0 Add, 0 Change, 0 Destroy,
0 Replace und keine Output-Änderungen. Kein Apply ist für diesen PR vorgesehen.

Ausgangslage, Verbraucher, Legacy-Adressen und konkrete Prüfergebnisse stehen im
[Refactoring-Nachweis](CONFIGURATION_REFACTOR_REPORT.md).
