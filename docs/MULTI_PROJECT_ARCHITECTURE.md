# SAP BTP: mehrere Projekte mit optionalen Directories

Project ABC bleibt in seinen bisherigen Quellen, Roots und States. Neue Projekte
werden separat beschrieben und durch zwei wiederverwendbare generische Roots
verwaltet. Dieser PR bereitet `test-neu` (Anzeigename `Test Neu`, Directory-Name
`Test_Neu`) vor: Projekt, Directory und alle Umgebungen sind deaktiviert.
Es werden keine Workspaces angelegt oder verbunden und keine SAP-Ressourcen
bereitgestellt.

## Struktur und Identität

```text
BTP/
├── config/
│   ├── project.yaml                         Project ABC, unverändert
│   ├── service-catalog.yaml                 gemeinsame Definitionen
│   ├── environments/{dev,test,prod}.yaml     Project ABC, unverändert
│   ├── iam/policies.yaml                    inaktiv
│   └── projects/
│       └── test-neu/
│           ├── project.yaml
│           ├── directory.yaml
│           ├── environments/
│           │   ├── dev.yaml
│           │   ├── test.yaml
│           │   └── prod.yaml
│           └── iam/policies.yaml            ebenfalls inaktiv
├── generated/test-neu/landing-zone.yaml      separates Projektartefakt
├── landing-zone.yaml                        unveränderter Project-ABC-Vertrag
├── configuration.tf                         unveränderter Project-ABC-Einstieg
├── projects/                               generischer neuer BTP-Root
└── modules/
    ├── directory/                          neuer Directory-Baustein
    ├── directory-rules/                    providerfreie Inventar-/Kollisionsprüfung
    ├── project-config/                     Projektidentität und Handoffs
    └── ...                                 bestehende Bausteine wiederverwendet
CloudFoundry/
├── main.tf                                 historischer DEV-Root, unverändert
├── environments/                           TEST/PROD-Root, unverändert
├── modules/spaces/                          vorhandene Space-/Rollenverwaltung
└── projects/                               generischer neuer Projekt-/Stage-Root
schemas/project.schema.json                 separater Envelope um Schema v2
```

Der Projektordner ist eine lokale Konfigurationsgrenze. Ein SAP-BTP-Directory ist
eine echte Cloud-Ressource innerhalb eines Global Accounts. Die technische
`project_id` ist keine Directory-UUID. Sie muss dem Ordnernamen entsprechen,
bleibt dauerhaft stabil und enthält höchstens 40 Kleinbuchstaben, Ziffern und
Bindestriche. `project-abc` ist reserviert; die bisherigen Dateien werden nicht
verschoben oder um neue Metadaten ergänzt.

Die Projekt-ID bestimmt neue Workspace-Namen, Subdomains, CF-Org-Namen und
Service-Namenspräfixe. Beispielsweise werden für `test-neu`/DEV die Subdomain
und der CF-Name `test-neu-dev` verwendet. Der Anzeigename ist davon getrennt.
Der Builder materialisiert diese Namen nur für neue Projekte. Änderungen an
bereits verwendeten IDs oder Subdomains können Ressourcen ersetzen; sie sind
keine harmlose Umbenennung.

## Konfigurationsvertrag und Builder

Neue `project.yaml`-Dateien enthalten `schema_version: 2`, `project_id`,
`project_name`, `account_type` und das explizite Boolean `deployment_enabled`.
Jede der drei Environment-Dateien enthält genau ihre Map `DEV`, `TEST` oder
`PROD` und ein explizites Boolean `enabled`. Projekt- und Umgebungsschalter
müssen beide aktiv sein. CF besitzt zusätzlich ein eigenes `enabled`.

Der Default-Befehl baut Project ABC und alle registrierten Projekte. Sämtliche
Projekte werden vor dem ersten Schreiben auf Schema, eindeutige Identität und
Kollisionen geprüft. Auch deaktivierte Projekte reservieren ihre Namen.

```bash
python scripts/build_landing_zone_config.py
python scripts/build_landing_zone_config.py --check
python scripts/build_landing_zone_config.py --project test-neu
python scripts/build_landing_zone_config.py --project test-neu --check
python scripts/build_project_schema.py
```

`--project` schreibt ausschließlich das ausgewählte Projektartefakt und prüft
trotzdem die gesamte Registrierung. Die alten Befehle bleiben gültig.
Project ABC erhält weiterhin exakt sein bisheriges YAML-Format und denselben
Warnheader. Ein neues Projektartefakt besitzt einen separaten Envelope:

```yaml
project_id: test-neu
deployment_enabled: false
directory:
  enabled: false
  name: Test_Neu
  features: [DEFAULT]
configuration:
  # Bestehende Landing-Zone-v2-Struktur:
  schema_version: 2
  account_type: trial
  project_name: Test Neu
  service_catalog: {}
  environments: {}
```

Der Ausschnitt zeigt die Struktur, keine vollständige deploybare Konfiguration.
Die generierte Datei enthält den vollständigen zentralen Katalog und alle drei
Umgebungen. Keine unkontrollierten Merges, Cross-Project-Imports oder Policy-
Imports werden durchgeführt. Doppelte YAML-Schlüssel, Symlinks, unbekannte Felder,
falsche Datentypen und Credential-Schlüssel werden abgewiesen; Fehler geben keine
ungültigen Werte aus. Quell- und Artefaktänderungen werden zusammen versioniert.
HCP führt kein Build-Skript aus und liest nur diese eingecheckten Dateien.

`schemas/project.schema.json` umschließt das bestehende Schema v2, dessen Modell
wiederverwendet wird. `project-config` verwendet für Normalisierung und sämtliche
bestehenden IAM-/Service-/Trial-Regeln weiterhin `landing-zone-config`.
Die Project-ABC-Schema-Version und das alte generierte Schema ändern sich nicht.

## Ein neues Projekt vorbereiten

```bash
cp -R BTP/config/projects/test-neu BTP/config/projects/neues-projekt
${EDITOR:-vi} BTP/config/projects/neues-projekt/project.yaml
${EDITOR:-vi} BTP/config/projects/neues-projekt/directory.yaml
${EDITOR:-vi} BTP/config/projects/neues-projekt/environments/dev.yaml
python scripts/build_landing_zone_config.py --project neues-projekt
python scripts/build_landing_zone_config.py --check
```

`project_id`, Anzeigename und Directory-Name anpassen; Schalter zunächst aus
lassen. DEV/TEST/PROD erhalten unabhängige Kostenstellen, Metadaten, BTP-IAM,
Service-Aktivierungen und CF-Spaces. Bei Labeln sind `stage`, `costcenter` und
`project_id` reserviert, höchstens sieben weitere Schlüssel möglich.
Subaccount-Parents oder Legacy-Administratorquellen dürfen neue Environment-
Dateien nicht setzen. Die generische Implementierung enthält keine besondere
Behandlung eines DEV-Subaccounts.

## Directory und Subaccount-Parent

Der neue Baustein nutzt `btp_directory` aus dem unverändert gepinnten SAP/btp
1.27.0. Geprüfte Primärquelle:
[Provider-Code v1.27.0](https://github.com/SAP/terraform-provider-btp/blob/v1.27.0/btp/provider/resource_directory.go).

- `DEFAULT` ist in diesem Konfigurationsvertrag erforderlich.
- `ENTITLEMENTS` schafft einen eigenen Quotenbereich.
- `AUTHORIZATIONS` benötigt zusätzlich `ENTITLEMENTS` und verwendet eine aus der
  Projekt-ID abgeleitete Directory-Subdomain.
- Maximal fünf Directory-Ebenen; pro Pfad höchstens ein Directory mit erweiterten
  Features. Der vorhandene Parent-Pfad muss im konfigurierten Global Account enden.

Die ausgeschriebenen Feature-Namen sind vorgeschrieben; Provider-Kurzformen
werden bewusst nicht als zusätzlicher Konfigurationsdialekt eingeführt.
Der Baustein prüft vor Erstellung das aktuelle Directory-Inventar und verhindert
eine zweite Erstellung bei gleichem Namen oder bereits zugeordneter Projekt-ID.
Für Inventar und Parent-Prüfung werden geeignete Lese-/Administrationsrechte
im Global Account benötigt. Die API bleibt für Account-Fähigkeiten maßgeblich.

Optionaler Parent: späterer HCP-Terraform-Input `directory_parent_id`, ohne feste
UUID im Terraform-Code oder im YAML. Verschachtelung wird live über maximal fünf
vorhandene Vorfahren geprüft. Directories mit fremdem `project_id`-Label werden
als Parent zurückgewiesen; ein explizit gewählter gemeinsamer Parent ohne
Projektzuordnung ist möglich. Keine bestehenden Subaccounts werden verschoben.

Vorhandenes eigenes Directory: `directory.enabled: false` und später ausdrücklich
`existing_directory_id` als Laufzeitinput setzen. Der Baustein liest dieses
Directory und verlangt passendes `project_id`-Label, Name und Features. Er
erstellt oder importiert es nicht und verändert dessen Parent nicht.
Eine gleichzeitige neue Erstellung wird abgewiesen. Ohne Directory wird ein
neuer Subaccount direkt unter dem Global Account erstellt.

Neue Subaccounts erhalten ihren Parent direkt aus
`module.directory.directory_id`, also der tatsächlich erzeugten oder geprüften
Ressource. Es gibt keine aus YAML konstruierte Directory-ID. `prevent_destroy`
schützt neue Directories und Subaccounts; spätere Deaktivierung bleibt dennoch
ein potenzieller Löschversuch und muss geplant werden.

## Services und Quoten

Alle Projekte nutzen `BTP/config/service-catalog.yaml`. Definition und
Aktivierung bleiben getrennt. Pro Umgebung können `services.catalog`, die
vorhandenen Komfortfelder oder explizite Entitlements/Instanzen/Subscriptions
verwendet werden. Eine gleichwertige Aktivierung nicht doppelt konfigurieren.
Explizite Instanznamen benötigen das jeweilige Projekt-/Stage-Präfix.

Wiederverwendet werden `service-selection`, `service-catalog`,
`service-catalog-rules`, `environment-services` und die Planprüfungen. Region,
IaaS-Provider, tatsächliche Account-Profile, regionale Verfügbarkeit, eindeutige
Pläne, Quoten und bereits zugewiesene Kontingente werden weiterhin geprüft.
`DEFAULT`-Directories erben den Quotenbereich des Global Accounts oder des
nächsten erweiterten Vorfahren. Für neue Directory-IDs verwendet der Katalog
stabile Lookup-Schlüssel; bestehende Aufrufer behalten ihre bisherigen ID-Schlüssel.

Directory-Features allein vergeben keine Quoten. Die automatische Erstellung von
Directory-Entitlements ist in diesem PR nicht implementiert. Vor späterer
Aktivierung unter `ENTITLEMENTS` müssen erforderliche Kontingente in einem eigenen
geprüften Schritt vorhanden sein; fehlende Quoten werden nicht umgangen.
`test-neu` hat ausschließlich leere Service-Auswahlen.

## Cloud Foundry und Handoffs

`btp-environment` und `cloudfoundry-environment` erzeugen später pro aktivem
Subaccount eine eigene CF-Umgebung/Org. `CloudFoundry/projects` verwendet das
vorhandene `spaces`-Modul für beliebig viele Spaces und deren Rollen.
Beispiel einer späteren Topologie: DEV mit backend/frontend, TEST mit testing,
PROD mit production. Die entsprechenden Space-Maps bleiben im vorbereiteten
Projekt leer. Organisationserstellung ist von Space-/Mitgliedschaftsverwaltung
getrennt.

Der BTP-Root veröffentlicht ausschließlich den nicht geheimen Output
`project_contract`: Projekt-ID, BTP-Workspace, Aktivierung, Konfigurationshash,
Directory-/Subaccount-IDs und projekt-/stagegebundene CF-Handoffs mit API-URL,
Org-ID, erwartetem CF-Workspace und Fingerprint. Keine Credentials.

Der CF-Root liest diesen einzelnen Output über `tfe_outputs`, niemals vollständige
Remote States. Er verlangt das passende Projekt, die Stage, beide Workspace-
Namen und den identischen Fingerprint. Es gibt keinen Fallback zu Project ABC
oder einer fremden Org. Der tatsächliche Terraform-Workspace muss dem erwarteten
Namen entsprechen. Ein deaktiviertes Projekt liest keine HCP-Outputs.

Die neuen Handoff-Hashes umfassen zusätzlich Projekt und Workspace-Kontext.
Die bisherigen Project-ABC-Handoff-Verträge und Hashes bleiben unverändert.
Space-Änderungen nutzen weiterhin den bestehenden eng gefassten Org-Vertrag;
der vollständige Projektfingerprint erfasst die gesamte Projektkonfiguration.

## IAM-Kontexte

| Kontext | Implementiert | Vorbereitung/Grenze |
|---|---|---|
| Directory | Feature-Prüfung und getrennte Directory-Identität | Directory-Admins, Collections und Directory-Entitlement-Zuweisungen benötigen eigene Module/Review |
| BTP-Subaccount | `role-collections`, `role-assignments`, Administratoren je Projekt/Stage | Exakte Application-Rollen; IdP-Origin für verwaltete Collections/Gruppen/Attribute explizit |
| CF-Space | vorhandene Space-Rollen und Benutzer-Mitgliedschaften je Projekt/Stage | Benutzer müssen die erforderliche Org-Mitgliedschaft bereits besitzen |
| CF-Org/Benutzerlebenszyklus | eindeutiger Org-/API-Handoff | Org-Rollen, Benutzererstellung und Gruppenverwaltung werden noch nicht automatisiert |
| KI-Governance | dokumentierte Kontexte und inaktive Policy-Einstiege | keine Policy-Engine, Discovery oder automatischen Berechtigungsentscheidungen |

Directory-Administrator, Subaccount-Administrator und CF-Space-Manager sind
unterschiedliche Berechtigungen. IAM-Daten werden niemals zwischen Projekten
zusammengeführt. Globale und projektbezogene `policies.yaml`-Dateien werden nicht
eingelesen. Keine IdPs, Benutzer oder Berechtigungen werden dadurch implizit erzeugt.
Secrets bleiben in den bestehenden sensitiven Laufzeitmaps und Provider-Variablen.

## Workspace- und State-Strategie

Organisation weiterhin `sap-ai-landing-zone`:

| Projekt | Workspace | Root / Working Directory | Einrichtung |
|---|---|---|---|
| Project ABC | `sap-btp-core` | `BTP` | unverändert vorhanden |
| Project ABC DEV | `sap-cloudfoundry` | `CloudFoundry` | unverändert vorhanden |
| Project ABC TEST | `sap-cloudfoundry-test` | `CloudFoundry/environments` | unverändert vorhanden |
| Test Neu | `sap-btp-test-neu-core` | `BTP/projects` | nur vorbereitet |
| Test Neu DEV | `sap-btp-test-neu-cf-dev` | `CloudFoundry/projects` | nur vorbereitet |
| Test Neu TEST | `sap-btp-test-neu-cf-test` | `CloudFoundry/projects` | nur vorbereitet |
| Test Neu PROD | `sap-btp-test-neu-cf-prod` | `CloudFoundry/projects` | nur vorbereitet, im Trial aus |

Jedes neue Projekt erhält einen eigenen Core-State; jede CF-Stage einen eigenen
State und API-Endpunkt. `project_id` und bei CF `environment` sind erforderliche
Terraform-Inputs. Neue Roots wählen später nur ausdrücklich eingerichtete
Workspaces mit `landing-zone-project-btp` beziehungsweise `landing-zone-project-cf`
als Tag. Tags, Workspaces, Output-Leserechte oder VCS-Trigger werden hier nicht
angelegt oder verändert. Die neuen Lockfiles übernehmen exakt die bereits
gepinnten Provider und Prüfsummen; es gibt kein Upgrade.

## Zukünftiger Provisioning-Ablauf – eigener freizugebender Schritt

1. Projekt-ID, Account-Profil, verfügbaren Trial-/Enterprise-Funktionsumfang,
   Regionen und Quoten prüfen. PROD bleibt im Trial aus. Ein YAML-Profilwechsel
   ändert nicht den SAP-Vertrag; Directories/Services sind keine garantierte
   Trial-Verfügbarkeit.
2. Quellen mit weiterhin deaktiviertem Projekt vorbereiten, bauen und prüfen.
   Vorhandene gleichnamige Directories klären und gegebenenfalls ausschließlich
   deren geprüfte projektgebundene Referenz vorsehen.
3. In einem gesonderten Deployment-Vorhaben Workspaces samt Working Directories,
   Tags, minimalen Provider-Credentials, Eingaben und gezieltem Output-Leserecht
   einrichten. Auto-Apply deaktiviert lassen. VCS-Trigger müssen das ausgewählte
   generierte Projektartefakt, gemeinsame Module und den Service-Katalog abdecken.
4. Projekt und gewünschte BTP-Stages bewusst aktivieren, neu generieren und einen
   echten BTP-Plan prüfen: Directory, Parent-Referenzen, Subaccounts, Quoten,
   Services und IAM. Directory-Quoten gegebenenfalls separat bereitstellen.
5. Erst nach eigener Freigabe BTP anwenden und den Output `project_contract`
   prüfen. Dieser PR erteilt dafür keine Apply-Freigabe.
6. CF-Workspace pro Stage auf dieselbe Projektkonfiguration und den zugehörigen
   Core-Output ausrichten; bestehende Org-Mitgliedschaften sicherstellen.
7. CF-Pläne einzeln prüfen und erst separat freigegeben anwenden. Abschließend
   State-Isolation, Benutzerrollen und Handoff-Verträge prüfen.

## Tests, CI und historische Nachweise

```bash
python3 -m venv /tmp/btp-multi-project-venv
source /tmp/btp-multi-project-venv/bin/activate
python -m pip install -r scripts/requirements.txt
python scripts/install_gitleaks.py /tmp/btp-multi-project-tools
export GITLEAKS_BINARY=/tmp/btp-multi-project-tools/gitleaks
python scripts/build_landing_zone_config.py --check
python scripts/build_project_schema.py
python scripts/check_landing_zone.py
python scripts/check_repository.py --base main
python scripts/run_secret_scan.py --gitleaks "$GITLEAKS_BINARY" --base main
```

Terraform 1.15.5 wie HCP verwenden. Der Runner kopiert nur Quellen und Fixtures
in ein temporäres Verzeichnis, deaktiviert die Backends und verwendet Mock-
Provider mit `command = plan`. Das explizit als synthetisch markierte Beispiel
`examples/project.test-neu.mock.yaml` aktiviert nur in dieser temporären Kopie
die Architektur für Tests; das versionierte Artefakt bleibt deaktiviert.
Neue, noch nicht eingerichtete Workspaces haben keine Remote-Pläne.

Die CI prüft sämtliche Artefakte, beide Schema-Verträge, Python, neue und
bestehende Terraform-Roots/Module, Locks, Provider-Coverage, Secrets und den
State-Adressvertrag. Speculative Plans für die drei bestehenden HCP-Workspaces
müssen weiterhin 0 Add / 0 Change / 0 Destroy / 0 Replace und unveränderte Outputs
zeigen. Ihre konkrete Commit-Zuordnung wird im PR dokumentiert.

Der Snapshot aus PR #9 bleibt unverändert. Historische Python-/Terraform-Tests
verwenden dessen eingefrorene Eingaben, um den damaligen Normalisierungs- und
Hash-Vertrag zu erhalten. Aktuelle Quellen werden dauerhaft gegen ihre generierten
Artefakte sowie gegen gezielte Legacy-/IAM-/Workspace-Invarianten geprüft.
Ein absichtlich geänderter gültiger Sollzustand wird dadurch nicht pauschal
gegen den kompletten alten Snapshot eingefroren.

Für dieses Refactoring wird zusätzlich ausdrücklich geprüft:

```bash
python scripts/check_project_abc_compatibility.py --base b24317535c74b3208ef977f18bf9bcac48490cec
```

Der Befehl vergleicht Project-ABC-Werte inklusive Typen/fehlenden Feldern,
generierte Bytes sowie sämtliche bestehenden Root-Dateien und Lockfiles mit
dem integrierten PR #9. Er ist ein gezielter Migrationsnachweis und keine
dauerhafte Sperre für spätere bewusst konfigurierte Infrastrukturänderungen.

## Ausgangsbasis und lokale Abnahme dieses PRs

`main` wurde mit GitHub synchronisiert. PR #9 ist in
`b24317535c74b3208ef977f18bf9bcac48490cec` integriert. Vor der Implementierung
wurden die Workspace-Einstellungen, aktuellen State-Metadaten und letzten
erfolgreichen Apply-Pläne der drei bestehenden Workspaces lesend geprüft:

| Workspace | State-Version / Serial | Letzter erfolgreicher Apply-Run | Verwaltete Adressen |
|---|---|---|---:|
| `sap-btp-core` | `sv-rTqLx5tCyA5oswuz` / 7 | `run-hcw9MSi7re1nvmjk` | 19 |
| `sap-cloudfoundry` | `sv-H1Av6nV81npfnH6m` / 3 | `run-LduNJFpb47teiHBV` | 3 |
| `sap-cloudfoundry-test` | `sv-CRa1zHYqQNdKgdUC` / 1 | `run-RkXYSUK54jHKSMgh` | 1 |

Die vollständigen Adressen einschließlich der historischen DEV-Ressourcen und
beiden TEST-Collections stehen im
[vorherigen Bestandsnachweis](CONFIGURATION_REFACTOR_REPORT.md). Persönliche
Schlüssel werden dort redigiert; der automatisierte Planvergleich verwendet
die vollständigen tatsächlichen Adressen, ohne diese Identitäten zu publizieren.
Es wurden keine State-Inhalte oder HCP-Variablen in neue Fixtures kopiert.

Die Referenz-Hashes aus dem letzten erfolgreichen BTP-Apply bleiben:

```text
Gesamt:  7ad88f9a3047420366c17fe07eb5ce702a71227747de1f9a58c0704aa35564a8
CF DEV:  444d0f16abd3373a17cdd4159c596f4ae06e585e60844cad15d4bf39bccbe879
CF TEST: 9d6c14dd0ff81edfcaa25e00dcaed301930770872bcbe88630cb0b2398d62ce0
```

Lokale Abnahme mit Python 3.12.3, Terraform 1.15.5 und Gitleaks 8.24.3:

| Prüfung | Ergebnis |
|---|---|
| Python-Unittest-Suite | 84 bestanden |
| Terraform-Tests, einschließlich aktivierter Architektur nur in Mock-Kopien | 187 bestanden, 0 fehlgeschlagen |
| Terraform validate | alle 20 Roots/Module valide |
| YAML-/Projekt-/Landing-Zone-Schema und deterministische Artefakte | bestanden |
| Format, Provider-Schema-Refresh, Coverage und gepinnte Locks | bestanden; 10 Ressourcentypen / 64 konfigurierbare Providerattribute erfasst |
| Expliziter Project-ABC-Kompatibilitätscheck gegen PR #9 | identische Werte/Typen/Feldauslassungen, YAML-Bytes, bestehende Roots und Locks |
| State-Adressvertrag | historische Basisadressen erhalten |
| Redigierter Secret-Scan | keine Funde |

GitHub-CI und die realen Speculative Plans werden anschließend am finalen
PR-Commit geprüft und mit Run-Links im Pull Request dokumentiert. Für die
vorbereiteten neuen Workspaces werden ausschließlich lokale Mock-Prüfungen
berichtet. Kein Merge, Apply oder Workspace-Setup ist Teil dieser Abnahme.
