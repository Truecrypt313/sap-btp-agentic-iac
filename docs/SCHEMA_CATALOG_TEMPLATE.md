# Schema- und kataloggesteuertes Template v2

## Umfang und Quelle

Die Implementierung deckt die acht bereits verwendeten Ressourcentypen aus
SAP/btp 1.27.0 und cloudfoundry/cloudfoundry 1.18.0 ab: Subaccount,
Environment Instance, Entitlement, Service Instance, Subscription, BTP Role
Collection Assignment, CF Space und CF Space Role. 54 beschreibbare
Top-Level-Attribute sind direkt oder aus ihrer Umgebung abgeleitet angebunden;
verschachtelte create/update/delete-Timeouts sind ebenfalls verfügbar.

Das ist kein Anspruch, sämtliche weiteren Ressourcen beider Provider zu
implementieren. Getrennte IDs und Ressourcenzuständigkeiten bleiben erhalten.
Berechnete Felder werden dokumentiert, aber nicht als schreibbar angeboten.
Insbesondere sind Space.quota und CF-Environment.custom_labels nur Ausgaben.

Die tatsächlichen Binaries wurden mit terraform providers schema -json
ausgelesen, initialisiert aus den vorhandenen Lockfiles. Die Cloud-Konfiguration
wurde ausschließlich in temporären Kopien entfernt. Es gab keine HCP-
Initialisierung, keine Provider-Upgrades und keinen State-Download/-Upload.

- [Provider-Snapshot](../schemas/provider-resources.json): Pflicht/Optional/Computed,
  Datentypen, Sensitivität, Nested Types und Beschreibungen.
- [Vollständige Attributreferenz](ATTRIBUTE_REFERENCE.md): jedes Provider- und
  YAML-Attribut mit Typ, Pflichtstatus, Defaults, Grenzen, Abhängigkeiten und Risiken.
- [Abdeckungsmanifest](../schemas/coverage.json): alle 54 konfigurierbaren Felder.
- [Unabhängiger Adressvertrag](../schemas/state-address-contract.json): 16
  bestehende Basisadressen plus die bisher geplante TEST-Adresse, ohne Identitäten.

Das Schema-JSON enthält technisch keine Validatoren oder RequiresReplace-
Planmodifier. Dafür wurden die versionierten Go-Implementierungen derselben
Provider-Tags geprüft; die Referenz verlinkt die Primärquellen. Zum Beispiel
erzwingen Region, Subdomain, Parent und skip_auto_entitlement einen Ersatz.
skip_auto_entitlement bleibt für DEV null; aus einem bisher ausgelassenen
Creation-only-Feld darf nicht versehentlich ein explizites false werden.

## Dateien und Generierung

~~~text
scripts/schema_model.py                zentrale Definition der YAML-Felder
scripts/build_landing_zone_schema.py   erzeugt/prueft TF-Typen und JSON Schema
scripts/export_provider_schema.py      aktualisiert Snapshot und Attributreferenz
scripts/validate_landing_zone.py       striktes YAML + sichere Kombinationen
schemas/landing-zone.schema.json       Draft 2020-12, unbekannte Inputs verboten
BTP/modules/landing-zone-config/       normalisierte Typen, Defaults, TF-Validierung
BTP/modules/region-catalog/            echte btp_regions-Abfrage
BTP/modules/region-rules/              reine, separat getestete Auswahlregeln
BTP/modules/service-selection/         Presets/Custom/shared aliases normalisieren
BTP/modules/service-catalog/           echte globale/Directory/Subaccount-Kataloge
BTP/modules/service-catalog-rules/     regionale Angebote und gemeinsame Quoten
BTP/modules/environment-services/      tatsächliche Instanzen/Subscriptions
BTP/modules/role-assignments/          User-, Gruppen- und Attributzuweisungen
~~~

Schema v2 ist aktiv; bestehende v1-Dokumente werden weiter normalisiert.
Templates nutzen weiterhin eine einzige gewünschte Konfigurationsdatei.
Der Servicekatalog ist darin enthalten und keine zweite konkurrierende Sollquelle.

~~~sh
python3 scripts/build_landing_zone_schema.py --write
python3 scripts/export_provider_schema.py
# Ausschließlich bei bewusstem Neu-Audit der unveränderten Locks:
python3 scripts/export_provider_schema.py --refresh
~~~

Ohne --write/--refresh werden keine Terraform-Provider aktualisiert.
export_provider_schema.py --check und build_landing_zone_schema.py prüfen
generierte Artefakte ohne Dateien zu schreiben. Typen nicht von Hand ändern:
schema_model.py ändern, neu generieren und Tests ausführen.

Unbekannte und ausschließlich berechnete Felder werden auch in den Terraform-
Roots über raw_configuration abgewiesen. Damit verschwinden Tippfehler nicht
stillschweigend bei der HCL-Objektkonvertierung. Die lokale JSON-Schema-Prüfung
ist zusätzlich strikt bezüglich ursprünglicher YAML-Typen, etwa numerischer
statt als String angegebener Kostenstellen.

## Subaccounts, Regionen und Profile

Alle unterstützten schreibbaren Subaccount-Felder sind verfügbar:
name, subdomain, description, region, parent_id, labels, usage, beta_enabled
und skip_auto_entitlement. Ausgelassene Namen/Subdomains erhalten die bisherigen
Namensformeln und denselben UUID-Suffix. Vorhandene State-Adressen bleiben gleich.

iaas_provider und runtime sind Auswahlbedingungen, keine erfundenen
Subaccount-API-Argumente. btp_regions liefert die tatsächlichen Kombinationen
aus Region, IaaS, Runtime und supports_trial. region=null erlaubt automatische
Auswahl ausschließlich bei genau einem passenden Kandidaten. Fehlende oder
mehrdeutige Treffer sind Fehler, keine Auswahl des ersten Treffers.

~~~yaml
# Auszug AWS: nur soweit im konkreten Global Account verfügbar.
region: us10
iaas_provider: AWS
runtime: cloudfoundry

# Alternative Azure, getrenntes Beispielprofil:
# region: eu20
# iaas_provider: AZURE
~~~

AWS us10 und Azure eu20 sind in der
[offiziellen SAP-Regionstabelle](https://help.sap.com/docs/btp/sap-business-technology-platform/regions-and-api-endpoints-available-for-cloud-foundry-environment)
dokumentiert. Die Beispiele sind keine Zusage eines konkreten Vertragsangebots.
[AWS](../examples/landing-zone.aws.yaml) und
[Azure](../examples/landing-zone.azure.yaml) sind nicht aktive Enterprise-Templates.
Sie nicht über den bestehenden Trial-State legen; neue Account-/Workspace-Bindungen
benötigen eine eigene Freigabe. Daten aus einem Trial-State werden nicht übernommen.

Trial prüft supports_trial und die tatsächliche license_type=TRIAL des
Global Accounts. Enterprise darf nicht gegen eine TRIAL-Lizenz laufen.
Aktives PROD und USED_FOR_PRODUCTION außerhalb von Enterprise-PROD werden
abgewiesen. Die YAML ändert weder Lizenz noch Vertrag; Standard-Pläne können
Kosten verursachen. Eine Quote ist kein Budgetlimit.

DEV ist auf cf-us10-001 gepinnt. Der bestehende gespeicherte BTP-Plan zeigte
sowohl die CF-Ressource als no-op als auch diesen unveränderten Helper-Input.
Auch für DEV wird die Plan-/Service-/Runtime-Kompatibilität dieses Landscapes
geprüft. Automatische Auswahl ist nur bei einem eindeutigen Kandidaten erlaubt.
Ein leerer alter cf_landscape_label-Input bedeutet weiterhin „nicht explizit
vorgegeben“ und widerspricht diesem YAML-Pin nicht.

## Gemeinsamer Servicekatalog

Beispiel aus der aktiven Datei, zunächst ohne zusätzliche Aktivierung:

~~~yaml
service_catalog:
  alert_standard:
    service_name: alert-notification
    plan_name: standard
    profiles: [trial, enterprise]
    instance: {}

environments:
  TEST:
    # ... Subaccount-Konfiguration ...
    services:
      catalog: [alert_standard]
      # catalog_amounts: {alert_standard: 1}  # Nur bei numerischer Kategorie.
~~~

service_catalog definiert Aliase; services.catalog aktiviert sie je Umgebung.
Preset-, Custom- und Alias-Einträge werden gemeinsam auf doppelte Entitlements,
Instanznamen und Subscriptions geprüft. Vorhandene DEV-Baseline-Ressourcen
bleiben bei module.srvc_baseline; das neue Services-Modul darf sie nicht erneut
übernehmen. Die aktuelle TEST-Konfiguration bleibt subaccount-only.

Prüfkette bei einem später freigegebenen echten Deployment:

1. btp_globalaccount_entitlements_with_data_centers bestätigt Service/Plan,
   Preisvarianten-ID, regionale/IaaS-Verfügbarkeit und Kategorie.
2. Ein expliziter Parent wird gegen btp_directory_entitlements geprüft.
   Verzeichnisse und deren Entitlements werden nicht erstellt oder umverteilt.
   Der Provider benötigt für diese Abfrage ein entitlement-verwaltendes Directory.
3. btp_subaccount_entitlements liest bereits vergebene Quoten. Es wird nur der
   positive Mehrbedarf berechnet, nicht dieselbe vorhandene Quote nochmals.
4. Alle Anforderungen derselben Parent-/Service-/Plan-/Preisvarianten-Grenze
   werden addiert. Dies verhindert, dass zwei Umgebungen dieselbe freie Quote
   jeweils vollständig verplanen. ELASTIC_LIMITED wird ebenfalls berücksichtigt.
5. Numerische amount-Werte sind nur für die vier dokumentierten numerischen
   Kategorien erlaubt. APPLICATION/ELASTIC_SERVICE erhalten kein amount.
   Bei mehreren Preisvarianten ist plan_unique_identifier nötig.
6. btp_subaccount_service_plan bestätigt tatsächliche ID bzw. Namenspaar,
   ready, shareable und optional required_platform. Keine erfundenen IDs und
   kein automatischer Wechsel auf einen anderen Plan.
7. btp_subaccount_subscriptions bestätigt angebotene App/Plan-Kombinationen
   nach Entitlement-Zuweisung. Plan-/Parameterupdates bleiben API-abhängig.

Leere regionale Katalogmetadaten gelten nicht als Beweis weltweiter
Verfügbarkeit; die Auswahl wird konservativ abgewiesen. Nicht verfügbare
Dienste deaktivieren. Ein Alias ist eine Definition, keine Verfügbarkeitsbehauptung.
Work Zone ist weiterhin deaktiviert und benötigt den tatsächlich angebotenen
SAPLaunchpad-APPLICATION-Plan sowie IAS/Trust-Voraussetzungen.

Grenze der Prüfung: Für erst neu angelegte Subaccounts sind deren Broker- und
Subscription-Kataloge noch nicht lesbar. Solche Abfragen können im ersten Plan
bis zum Apply aufgeschoben werden. Ein späterer Fehler könnte dann nach der
Subaccount-Erstellung auftreten. Lokale Mocks sind kein vollständiger Live-
Verfügbarkeitsbeweis. Quotenprüfungen reservieren außerdem keine Quoten gegen
konkurrierende Deployments anderer Workspaces.

## Erweiterte Ressourcenoptionen

- CF-Environment: name, service_name, environment_type, plan, landscape_label,
  JSON-Parameter und create/update/delete-Timeouts. Das Modul unterstützt CF,
  keine versteckte Kyma-Provisionierung über einen anderen service_name.
- Serviceinstanz: Name, Labels, shared, JSON-Parameter, Runtime-Parameterreferenz,
  Timeouts und beide vom Provider unterstützten Plan-Auswahlmodi. serviceplan_id
  ist alternativ zum Paar service_offering_name/serviceplan_name. Der Schalter
  use_plan_names steuert das tatsächlich geschriebene Argumentpaar.
- Subscription: App/Plan, JSON-Parameter, Runtime-Referenz und Timeouts.
  BTP-Serviceinstanzen sind Service-Manager-Instanzen, keine CF-Service-Bindings.
- BTP-Rolle: genau ein User-, Gruppen- oder Attributsubjekt. Gruppen brauchen
  origin, Attributzuweisungen zusätzlich attribute_value. Die Role Collection
  muss bereits existieren. Identitäten sind keine geheimen for_each-Schlüssel.
- Space: allow_ssh, Labels, Annotations, vorhandenes Isolation Segment.
  Quota bleibt ein berechneter Output; eine schreibbare Quota braucht eine
  eigene Ressource und ist nicht Bestandteil dieses Moduls.
- CF-Rolle: Manager, Developer, Auditor, Supporter; genau User-GUID oder Username.
  origin nur zusammen mit Username; organization_user muss bereits existieren.
  Eine gleiche Identität unter GUID und Username wird nicht automatisch aufgelöst.

Zusätzliche Rollen am bestehenden DEV-Projektspace werden über ein rollen-
beschränktes Modul mit abgeleiteter existing_space_ids-Übergabe verwaltet.
Dieses Modul erstellt oder importiert den vorhandenen Space nicht nochmals.
Bekannte, bereits separat verwaltete Legacy-Rollen werden als Duplikate abgewiesen.
Die alten beiden Rollenzuweisungen und deren Adressen bleiben bestehen.

## Geheimnisse, Zustände und HCP-Overrides

YAML enthält keine Credentials. Nicht geheime JSON-Objekte dürfen in parameters
stehen. Vertrauliche Konfiguration nutzt stattdessen parameters_key und sensitive
Runtime-Maps instance_parameters, subscription_parameters, environment_parameters.
Die Schlüssel sind STAGE/Referenz, beispielsweise TEST/alert-runtime.
Fehlende Referenzen führen zum Fehler; Werte werden nicht in Meldungen ausgegeben.
Sensitiv bedeutet keine zusätzliche Verschlüsselung innerhalb des Terraform-
States: Zugriff auf State und HCP-Variablen bleibt zu schützen.

Der aktuelle lesende HCP-Befund bestätigt BTP-State Serial 1, CF-State Serial 2
und additional_subaccounts mit TEST/us10, passend zur zentralen Konfiguration.
Der Kompatibilitätsmodus, die Prüfung widersprüchlicher Overrides und die
Migration auf configuration_mode=yaml bleiben erhalten. Es wurden keine
HCP-Variablen geändert. Keine aktiven State-Migrationen oder Imports eingeführt.

Die bestehenden 16 Basisadressen plus TEST werden aus einem unabhängigen,
nicht geheimen Adressvertrag geprüft. Baseline-Modul und Legacy-Ressourcen
dürfen nicht durch count/for_each neu indiziert werden. Neue Katalog-Datenquellen
sind zusätzliche Leseobjekte, keine verschobenen bestehenden Ressourcen.

## Prüfungen

Python-Abhängigkeiten in einer eigenen Umgebung installieren:

~~~sh
python3 -m venv /tmp/btp-lz-check
/tmp/btp-lz-check/bin/python -m pip install -r scripts/requirements.txt
/tmp/btp-lz-check/bin/python scripts/install_gitleaks.py /tmp/btp-lz-tools
GITLEAKS_BINARY=/tmp/btp-lz-tools/gitleaks /tmp/btp-lz-check/bin/python scripts/check_landing_zone.py
~~~

Alle Terraform-Prüfungen laufen in temporären Kopien, mit frischer TF_DATA_DIR,
backend=false und den ursprünglichen Provider-Versionen/Checksummen. Auch die
separaten providerabhängigen Modulprüfungen übernehmen nur die passende
Provider-Locksektion in ihre temporäre Kopie und nutzen lockfile=readonly.

Historischer Stand vor den Audit-Korrekturen mit Terraform CLI 1.17.1;
aktuelle Ergebnisse und Integrationsvoraussetzungen siehe
[AUDIT_REMEDIATION.md](AUDIT_REMEDIATION.md):

| Prüfung | Ergebnis |
|---|---|
| Typ-/JSON-Schema-Generierung und Provider-Abdeckung | erfolgreich, 8 Typen / 54 Attribute |
| Aktive YAML sowie Enterprise-/AWS-/Azure-Beispiele | gültig |
| Terraform fmt/validate | erfolgreich |
| Terraform-Tests | 53 bestanden, ausschließlich lokale Mock-/providerfreie Plans |
| Python-Schema-/Kombinationstests | 17 bestanden |
| State-Adressvertrag | 17 bestehende/geplante Basisadressen erhalten |

Die Tests unterscheiden reale Schema-/Quotenregeln von I/O-Mocks. Reine Regeln
bekommen mehrzeilige Katalog-Fixtures, während Root-Tests die tatsächlichen
Providerzugriffe durch Modul-/Provider-Mocks ersetzen. Es wird keine echte
Infrastruktur aufgebaut oder am Ende eines Tests zerstört.

Keine neuen HCP-Runs, keine Bestätigung bestehender Runs, kein Apply/Destroy,
keine HCP-Variablen-/State-Änderung, kein Commit/Push/PR. Ein neuer echter
Plan gegen die aktuellen States steht weiterhin aus.
