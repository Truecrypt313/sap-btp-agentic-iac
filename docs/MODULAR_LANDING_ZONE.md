# Modulare SAP-BTP-Landing-Zone

Der folgende Architektur-/Bestandsnachweis beschreibt die ursprüngliche
Modularisierung und deren damaligen Stand. Die aktuelle Quellenstruktur,
der inzwischen bereitgestellte TEST-Bestand und der tägliche Build-Workflow
stehen in [CONFIGURATION.md](CONFIGURATION.md). `BTP/landing-zone.yaml` wird
jetzt generiert; Änderungen ausschließlich in `BTP/config/` durchführen.

Die aktuelle Erweiterung auf Schema v2 und den dynamischen Katalog ist in
[SCHEMA_CATALOG_TEMPLATE.md](SCHEMA_CATALOG_TEMPLATE.md) beschrieben.
Die vollständigen Felder stehen in [ATTRIBUTE_REFERENCE.md](ATTRIBUTE_REFERENCE.md).

## Architektur und Modulstruktur

Eine gewünschte Konfiguration, mehrere ausdrücklich getrennte Deployment-States:

~~~text
BTP/
  landing-zone.yaml                   aktive Konfiguration, Schema v1/v2
  configuration.tf                    YAML und Legacy-Kompatibilität
  main.tf / landing_zone.tf            bestehende Subaccount-/DEV-Adressen
  modules/
    landing-zone-config/              typisiertes Schema, Defaults, Validierung
    btp-environment/                  Services, optionale CF-Org, Administratoren
    cloudfoundry-environment/         CF-Katalogabfrage und eindeutige Landschaft
    environment-services/            Entitlements, Instanzen, Subscriptions
    srvc-baseline/                    bestehende DEV-Baseline, Adressen erhalten
CloudFoundry/
  main.tf / configuration.tf          bestehender DEV-Space und zusätzliche DEV-Spaces
  modules/spaces/                     wiederverwendbare Spaces und optionale Rollen
  environments/                      neuer Root, ein ausgewähltes TEST/PROD pro State
examples/landing-zone.enterprise.yaml Beispiel, nicht automatisch geladen
scripts/check_landing_zone.py         Format, Init, Validate und lokale Mock-Tests
~~~

Zusätzliche BTP-Umgebungen verwenden for_each mit stabilen Stage-Schlüsseln.
Subaccounts bleiben bewusst im BTP-Root: Eine vollständige Verschiebung der
bestehenden DEV-Ressourcen in ein Modul würde deren State-Adressen ändern.
Der neue Baseline-Code bekommt bereits verwaltete Subaccount-IDs übergeben und
legt keinen zweiten Subaccount an.

Der BTP-Root kann mehrere Umgebungen gemeinsam verwalten. CF-Spaces verschiedener
Regionen verwenden dagegen getrennte Workspaces: Ein CF-Provider hat einen
konkreten API-Endpunkt; dynamische Provider-Instanzen pro for_each-Umgebung sind
kein Ersatz für diese State-Grenze. Die gemeinsame YAML ist keine Zusage eines
einzigen atomaren Deployments über alle States.

## Bestand und Adressgarantien

Lesender MCP-Befund vom 07.11.2026:

| Workspace | State | Bestand |
|---|---|---|
| sap-btp-core | Serial 1, sv-2yK9mFYCXGPtR6hk | 10 verwaltete Ressourcen, 3 Datenquellen |
| sap-cloudfoundry | Serial 2, sv-8YFojjdyYpPtmz6C | bestehender DEV-Space und zwei Rollen |

TEST fehlt im BTP-State. Der bisherige BTP-Run
run-VJfp2u19AvLKhMzq steht auf planned und will nur
btp_subaccount.additional["TEST"] erstellen. Er wird durch diese Änderung weder
bestätigt noch verworfen. Der CF-Run für den vorherigen Output-Test ist inzwischen
applied; daraus folgt keine Freigabe für BTP-Änderungen.

Insbesondere bleiben unverändert:

~~~text
btp_subaccount.project_subaccount
btp_subaccount_environment_instance.cloudfoundry
btp_subaccount_role_collection_assignment.emergency_administrators[<bisheriger Schlüssel>]
random_uuid.uuid
terraform_data.cf_landscape_label
module.srvc_baseline.btp_subaccount_entitlement.alert_notification_service_standard
module.srvc_baseline.btp_subaccount_entitlement.feature_flags_service_lite
module.srvc_baseline.btp_subaccount_entitlement.feature_flags_dashboard_app
module.srvc_baseline.btp_subaccount_service_instance.alert_notification_service_standard
module.srvc_baseline.btp_subaccount_subscription.feature_flags_dashboard_app

# Getrennter CF-State:
cloudfoundry_space.project_space
cloudfoundry_space_role.space_manager
cloudfoundry_space_role.space_developer
~~~

Auch die Adresse des bisher nur geplanten TEST-Subaccounts bleibt erhalten.
Die bestehende UUID bleibt der Suffix für DEV und zusätzliche Subaccounts.
Die vorhandenen fünf BTP-Outputs und zwei CF-Outputs bleiben erhalten; neu sind
landing_zone_subaccounts, cloud_foundry_environments und
dem pro Umgebung veröffentlichten contract_fingerprint; der vollständige
landing_zone_configuration_fingerprint bleibt nur diagnostisch.

Die aktive YAML bildet den bisherigen Sollzustand ab: DEV unverändert,
TEST nur als Subaccount in us10, PROD aus. Die DEV-Baseline bleibt obligatorisch:
Ihre Deaktivierung oder ein Planwechsel wird abgewiesen. DEV darf zusätzliche
Services erhalten, ohne dass das neue Modul die alten Entitlements oder die
vorhandene Alert-Notification-Instanz erneut verwaltet.

prevent_destroy schützt Subaccounts, CF-Environments, Service-Ressourcen und
Spaces vor versehentlichem Entfernen/Ersetzen, solange die entsprechenden
Konfigurationsblöcke vorhanden sind. Es ist keine vollständige Löschsperre:
Rollenentzug, In-place-Änderungen oder entfernte ganze Konfigurationsblöcke
erfordern weiterhin sorgfältige Planprüfung.

Es gibt keine neuen aktiven moved- oder import-Blöcke und keine State-Kommandos.
Eine spätere vollständige DEV-Modularisierung wäre ein eigenes Vorhaben:
zuerst eine explizite Alt-/Neu-Adressliste und einen reinen Migrationsplan
vorlegen, niemals jetzt Adressen oder State-Dateien ändern.

## Konfigurationsvertrag

Die aktive Datei ist BTP/landing-zone.yaml. Sie enthält:

- schema_version: 1; unbekannte Schema-Versionen führen zum Fehler.
- account_type: trial oder enterprise; dies muss zum tatsächlich authentifizierten
  Global Account passen und ändert dessen Vertragsmodell nicht.
- project_name und eine environments-Map mit DEV, TEST, PROD.
- Pro Umgebung enabled, region, als String angegebene fünfstellige costcenter,
  beta_enabled und optionale Labels als Listen von Strings.
- cloud_foundry mit enabled, ausdrücklich gewähltem trial/standard-Plan,
  optionalem landscape_label und einer spaces-Map mit stabilen Schlüsseln.
- services mit Alert Notification, Feature Flags, Work Zone und optionalen
  zusätzlichen Entitlements/Service-Manager-Instanzen.
- Optionale administrators: Benutzerkennungen, niemals Passwörter oder Tokens.

Beispiel für die bewusste Aktivierung von TEST-CF nach Quotenprüfung:

~~~yaml
TEST:
  enabled: true
  region: us10
  costcenter: "12345"
  administrators: []
  cloud_foundry:
    enabled: true
    plan: trial
    landscape_label: ""  # Nur bei genau einem passenden Katalogtreffer.
    spaces:
      app:
        name: test-project-abc
        managers: []
        developers: []
  services:
    alert_notification: { enabled: true, plan: standard, instance: true }
    feature_flags: { enabled: true, plan: lite, instance: true, dashboard: true }
    work_zone: { enabled: false }
~~~

Das Beispiel ist kein Nachweis freier Trial-Quoten. Ohne eindeutiges passendes
CF-Landscape bricht das neue CF-Environment-Modul ab. Es nimmt nicht einfach
den ersten Katalogtreffer. Explizite Labels müssen im Katalog vorhanden sein.
Die bestehende DEV-Landschaft cf-us10-001 ist zur Bestandserhaltung ausdrücklich gepinnt und wird gegen den tatsächlichen CF-Katalog geprüft.

Optionale zusätzliche Entitlements/Instanzen innerhalb von services:

~~~yaml
entitlements:
  approved_service:
    service_name: "<aus dem echten Entitlement-Katalog übernehmen>"
    plan_name: "<verifizierter Plan>"
    # amount nur für einen quotenbasierten Plan angeben.
instances:
  approved_instance:
    offering: "<aus dem Service-Manager-Katalog übernehmen>"
    plan: "<verifizierter Plan>"
    name: "<eindeutiger Instanzname>"
~~~

Diese Platzhalter sind keine erfundenen Service-Pläne und gehören nicht
unverändert in die aktive Konfiguration. Die Instanzabfrage löst echte Plan-IDs
über btp_subaccount_service_plan auf. Fehlende Angebote führen zum Fehler;
es wird nicht auf einen anderen oder kostenpflichtigen Plan ausgewichen.
Built-in-Schlüssel dürfen nicht überschrieben werden, doppelte Service/Plan-
Entitlements und doppelte Instanz-/Space-Namen werden abgefangen.

Die BTP-Serviceinstanzen laufen im Subaccount-/Service-Manager-Kontext. Das Modul
erstellt keine CF-Service-Bindings, Service-Keys, Anwendungen oder Work-Zone-Sites.
Ein nur im CF-Broker verfügbares Angebot darf nicht als verifiziertes
Service-Manager-Angebot behandelt werden; instance dann deaktivieren.

## Sichere Migration von additional_subaccounts

1. HCP-Workspace und vorhandenen State zunächst nur lesen. Den alten wartenden
   Run nicht bestätigen: Sein Plan enthält den neuen Code nicht.
   Ob er später verworfen werden soll, benötigt eine gesonderte Freigabe.
2. Zunächst configuration_mode=compatibility verwenden (Default).
   YAML ist bereits die aktive Sollquelle. Ein nicht leerer HCP-Wert von
   additional_subaccounts muss exakt mit den aktivierten zusätzlichen
   YAML-Subaccounts für Region/Kostenstelle übereinstimmen; sonst Planfehler.
   Die aktuelle TEST-Konfiguration ist dafür vorbelegt.
3. Auch die bisherigen DEV-Skalare werden in diesem Modus auf Widersprüche
   geprüft. Keine zweite abweichende Umgebungsdefinition pflegen.
4. Nach einer späteren separaten Code-Freigabe einen neuen Plan prüfen:
   sämtliche DEV-Ressourcen no-op, nur die beabsichtigte TEST-Erstellung,
   keine Replacements oder Löschungen. Output-Erweiterungen sind zu erwarten.
   Diesen Nachweis kann lokale Validierung nicht ersetzen.
5. Nach Prüfung den HCP-Override additional_subaccounts entfernen bzw. auf {}
   setzen und explizit configuration_mode=yaml wählen. TEST unbedingt in YAML
   behalten. yaml-Modus mit nicht leerem Legacy-Override führt zum Fehler.
   Ein erneuter geprüfter Plan darf wegen des Quellenwechsels nichts löschen.
6. Alte DEV-Skalar-Overrides entfernen; sie sind im yaml-Modus nicht die Sollquelle.
   globalaccount bleibt eine Laufzeitbindung des authentifizierten Workspaces.

DEV-administrators_source=legacy ist eine ausdrücklich getrennte
Kompatibilitätsschnittstelle für die bestehende HCP-Administratorliste und ihre
State-Schlüssel. Es werden keine zusätzlichen YAML-Administratoren hinzugemischt.
Für eine spätere Umstellung auf yaml die exakt gleichen bisherigen Benutzer
unter administrators übernehmen und erst danach die Legacy-Eingabe entfernen.
Die Rollen-Planänderung muss dabei leer sein. Benutzerkennungen stehen in
for_each-Adressen und sind keine geeigneten Geheimnisse.

Auch die beiden bestehenden DEV-Space-Rollen bleiben in den bisherigen
sensitiven HCP-Variablen. Die YAML-Listen für den bestehenden Space project
müssen leer bleiben, damit kein zweiter Rollenbesitzer entsteht. Neue DEV-Spaces
und TEST/PROD-Spaces können eigene optionale Mitglieder aus YAML verwenden.

## Deployment und State-Trennung für CF-Spaces

| Inhalt | HCP-Workspace | Working Directory |
|---|---|---|
| Subaccounts, CF-Orgs, Entitlements/Services | sap-btp-core | BTP |
| Bestehender DEV-Space und neue DEV-Spaces | sap-cloudfoundry | CloudFoundry |
| Neue TEST-Spaces | sap-cloudfoundry-test | CloudFoundry/environments |
| Neue PROD-Spaces, nur Enterprise | sap-cloudfoundry-prod | CloudFoundry/environments |

TEST/PROD-Workspaces sind nur vorgeschlagen und wurden nicht angelegt.
Sie benötigen das Tag landing-zone-cf und die Terraform-Variablen environment
(TEST bzw. PROD) sowie workspace_name (passender vollständiger Workspace-Name).
Der neue Root weist DEV und ein abweichendes State-Ziel zurück.
Das Enterprise-Beispiel ist für ein neues kommerzielles Ziel gedacht.
Die fest an den bestehenden Trial gebundenen cloud-Blöcke/Workspace-Namen und
die Konto-Bindung müssen dafür in einer getrennten Konfiguration ausdrücklich
auf neue Workspaces zeigen. Keine bestehenden Trial-States übernehmen.

Die Reihenfolge bleibt BTP vor CF:

1. Regionen, freie Global-Account-Quoten und tatsächliche Service-Pläne prüfen.
   Ein neuer Enterprise-Global-Account braucht eigene State-/Workspace-Bindungen.
   Das Enterprise-Template nicht auf den bestehenden Trial-State anwenden.
2. Einen neuen BTP-Plan separat prüfen und später ausdrücklich freigeben.
   Keine alten wartenden Pläne bestätigen. Keine automatischen Applies aktivieren.
3. Erst wenn die CF-Orgs existieren und der BTP-State die neuen
   cloud_foundry_environments-Ausgaben veröffentlicht, TEST/PROD-Spaces planen.
   Ein noch fehlender Output/Org ist ein harter Fehler, kein Anlass, DEV zu nehmen.
   Der pro Umgebung veröffentlichte Identitätsfingerabdruck muss mit dem
   lokalen BTP-/CF-Identitätsvertrag übereinstimmen. Reine Space-, Rollen- und
   Serviceänderungen erfordern keinen neuen Handoff. Siehe Audit-Korrekturen.
4. Für jeden neuen CF-Workspace passende CF-Laufzeit-Zugangsdaten bereitstellen.
   Die jeweiligen Mitglieder müssen bereits organization_user im Ziel-Org sein;
   das Space-Modul erstellt diese Org-Mitgliedschaft nicht.
5. HCP-Zugriff nur auf die benötigten BTP-Outputs freigeben. Der neue Root
   verwendet tfe_outputs.nonsensitive_values statt terraform_remote_state und
   benötigt einen passend eingeschränkten Laufzeitzugang für den TFE-Provider.
   Tokens nur sensitiv in HCP/Secret-Store, niemals in der YAML.
6. Pro CF-Workspace Plan und Ziel-Org prüfen, danach separat freigeben.
   Keine bestehenden DEV-Space-Ressourcen in einen neuen State importieren.

HCP muss das vollständige Repository auschecken; VCS-Source-Directory bleibt
der Repository-Root, nur Working Directory wird gesetzt. YAML und gemeinsam
verwendete Module liegen teilweise außerhalb des jeweiligen Working Directory.
Trigger-Patterns müssen diese Änderungen einschließen:

- BTP: BTP/**, schemas/**, scripts/**
- DEV-CF: CloudFoundry/**, BTP/landing-zone.yaml, BTP/modules/landing-zone-config/**, schemas/**, scripts/**
- TEST/PROD-CF: CloudFoundry/environments/**, CloudFoundry/modules/**,
  BTP/landing-zone.yaml, BTP/modules/landing-zone-config/**

Keine HCP-Variablen, Berechtigungen, Trigger oder Workspaces wurden hier verändert.
CLI-Uploads nur verwenden, wenn sie den vollständigen Repository-Kontext
enthalten; ein isolierter Upload allein des CF-Unterordners reicht nicht.
Alternative landing_zone_config_file-Werte werden in allen ausführbaren Roots
abgelehnt. Alle verwenden die versionierte BTP/landing-zone.yaml. Der
Identitäts-Handoff einschließlich DEV ist in AUDIT_REMEDIATION.md beschrieben.

## Service-Pläne, Trial und offene Voraussetzungen

Verifiziert wurden die offiziellen Provider-Schemas für SAP/btp 1.27.0,
cloudfoundry/cloudfoundry 1.18.0 und tfe_outputs 0.83.0. Bestehende Root-Lockfiles
bleiben unverändert; nur der neue CF-Root hat ein eigenes Lockfile.

| Funktion | Technischer Name / Plan | Aktivierungsbedingung |
|---|---|---|
| Cloud Foundry | cloudfoundry / trial oder standard | Passender Environment-Katalog und Quote |
| Alert Notification | alert-notification / standard oder free | Im konkreten Account verfügbar; DEV bleibt standard |
| Feature Flags | feature-flags / lite oder standard | Entitlement und bei Instanzen Service-Manager-Plan |
| Feature Flags Dashboard | feature-flags-dashboard / dashboard | Separates Entitlement und Subscription |
| Work Zone, standard edition | SAPLaunchpad / explizit standard oder free | Verifizierter APPLICATION-Plan, Quote, IAS/Trust; Default aus |

Provider-Dokumentation ist kein Verfügbarkeitsnachweis für jeden Account oder
jede Region. Bei deaktivierten Services entstehen keine neuen Lookup-/Service-
Ressourcen. Ein späteres Abschalten bereits verwalteter Dienste ist dagegen
eine Löschabsicht und wird nicht als harmlose Feature-Änderung behandelt.

SAP dokumentiert Work Zone im Trial inklusive IAS-Tenant und Trust-Vorbereitung.
Die aktuelle Verfügbarkeit im eigenen Trial wurde nicht nachgewiesen; deshalb
bleibt Work Zone deaktiviert. Der kostenlose Free-Tier-Plan ist nicht gleichbedeutend
mit einem Trial-Angebot und darf nicht als automatischer Ersatz verwendet werden.

Trial ist für persönliche, nicht produktive Evaluation bestimmt, zeitlich
begrenzt und ohne SLA. PROD bleibt daher aus. Zusätzliche Trial-Subaccounts
können vorhandene gemeinsame Entitlements/Quoten verbrauchen; Ressourcen werden
nicht automatisch von DEV abgezogen oder umverteilt. Rechte zur
Global-Account-/Subaccount-Verwaltung und verfügbare Quoten sind vor Deployment
offen zu prüfen. Authentifizierung erfolgt nur über HCP/Umgebungsvariablen.

Offizielle Quellen, geprüft am 07.11.2026:

- [SAP Provider: Subaccount](https://registry.terraform.io/providers/SAP/btp/1.27.0/docs/resources/subaccount)
- [SAP Provider: Environment Instance](https://registry.terraform.io/providers/SAP/btp/1.27.0/docs/resources/subaccount_environment_instance)
- [SAP Provider: Entitlement](https://registry.terraform.io/providers/SAP/btp/1.27.0/docs/resources/subaccount_entitlement)
- [SAP Provider: Service Instance](https://registry.terraform.io/providers/SAP/btp/1.27.0/docs/resources/subaccount_service_instance)
- [SAP Provider: Subscription, SAPLaunchpad-Beispiel](https://registry.terraform.io/providers/SAP/btp/1.27.0/docs/resources/subaccount_subscription)
- [CF Provider: Space Role und erforderliche Org-Mitgliedschaft](https://registry.terraform.io/providers/cloudfoundry/cloudfoundry/1.18.0/docs/resources/space_role)
- [TFE: Outputs-Datenquelle](https://registry.terraform.io/providers/hashicorp/tfe/0.83.0/docs/data-sources/outputs)
- [SAP Feature Flags: dokumentierte Pläne](https://help.sap.com/docs/FEATURE_FLAGS/2250efa12769480299a1acd282b615cf/what-is-sap-feature-flags-service)
- [SAP: Work Zone im Trial und IAS-Voraussetzungen](https://developers.sap.com/tutorials/cp-portal-cloud-foundry-getting-started)
- [SAP: Trial-Entitlements zwischen Subaccounts](https://developers.sap.com/tutorials/cp-trial-entitlements)
- [SAP: Trial Accounts and Free Tier](https://help.sap.com/docs/btp/sap-business-technology-platform/trial-accounts-and-free-tier)

## Lokale Prüfungen und Aussagegrenzen

~~~sh
# Python-Abhängigkeiten und Gitleaks zuerst installieren; siehe AUDIT_REMEDIATION.md.
# GITLEAKS_BINARY muss auf den dokumentierten Scanner zeigen.
python3 scripts/check_landing_zone.py
# Einzelne Teilprüfungen:
python3 scripts/check_landing_zone.py --only BTP/modules/landing-zone-config
~~~

Das Skript initialisiert Provider mit frischer temporärer TF_DATA_DIR und
backend=false. Root-Lockfiles werden readonly verwendet, ohne Provider-Upgrade.
Child-Module werden in temporären Kopien getestet. Alle Terraform-Testfälle
verwenden command=plan und ausschließlich Mock-Provider bzw. ein providerfreies
Schema. Keine Credentials, kein realer Plan/Apply, kein HCP-Run und keine
manuellen State-Änderungen.

Die Tests prüfen Legacy-Adressen/Namensbildung, unveränderte DEV-Service-
Zuständigkeit, den HCP-TEST-Konflikt, die sichere Quellenmigration, das
Enterprise-Beispiel und ungültige Schema-/Trial-/Space-/Service-Konfigurationen.
Weitere CF-Tests prüfen die Workspace-Bindung und fehlende/veraltete BTP-Ausgaben.
Sie bestätigen Syntax und Modellverhalten, aber keine SAP-Quoten, Live-Drift,
aktuellen Zugangsdaten oder fehlenden Replacements gegen den echten State.
Ein später freigegebener echter Plan bleibt vor jedem Deployment erforderlich.

Prüfergebnis der Implementierung am 07.11.2026: Terraform CLI 1.17.1;
fmt und validate erfolgreich für die drei Roots und die beiden separat
getesteten Module. Aktuelle Regressionen, Ergebnisse und lokale Aufrufvoraussetzungen siehe
[AUDIT_REMEDIATION.md](AUDIT_REMEDIATION.md).
Die vorhandenen Root-Lockfiles bleiben bytegleich; kein echter HCP-Plan wurde
für diesen Branch gestartet.
