# Attributreferenz: gelockte Provider und Landing-Zone-Schema

Generiert aus den installierten Provider-Binaries: SAP/btp 1.27.0 und CF 1.18.0.
Pflichtstatus bezieht sich auf das Provider-Schema; YAML darf Pflichtwerte ableiten.
JSON-Schema exportiert keine Validatoren oder RequiresReplace-Planmodifier. Die
folgenden Regeln/Risiken wurden zusätzlich im Quellcode derselben Tags geprüft.
API-/Broker-Regeln können darüber hinausgehen; keine Ersatzfreiheit wird zugesichert.

## btp_directory

[Versionierte Primärquelle](https://github.com/SAP/terraform-provider-btp/blob/v1.27.0/btp/provider/resource_directory.go)

| Attribut | Typ | Status | YAML/Quelle | Werte, Abhängigkeiten und Risiko |
|---|---|---|---|---|
| created_by | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The details of the user that created the directory. |
| created_date | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was created in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| description | "string" | Optional, computed | project.directory.description | Provider-/API-Plan prüfen. |
| features | ["set", "string"] | Optional, computed | project.directory.features | DEFAULT erforderlich; AUTHORIZATIONS benötigt ENTITLEMENTS. Pro Pfad höchstens ein erweitertes Directory, max. fünf Ebenen. |
| id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the directory. |
| labels | ["map", ["set", "string"]] | Optional | project_id aus der Projektidentität | Provider-/API-Plan prüfen. |
| last_modified | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was last modified in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| name | "string" | Pflicht | project.directory.name | Bestehende Directories nur als projektgebundene Data Source referenzieren, niemals doppelt erstellen. |
| parent_id | "string" | Optional, computed | geprüfter Laufzeitinput directory_parent_id | Live geprüfter Parent-Pfad im gleichen Global Account; bestehende Subaccounts werden nicht verschoben. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| state | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The current state of the directory. Possible values are:  |
| subdomain | "string" | Optional, computed | Projekt-ID + directory bei AUTHORIZATIONS | Provider-/API-Plan prüfen. RequiresReplaceIfConfigured; Löschschutz/State-Abhängigkeiten beachten. |

## btp_subaccount

[Versionierte Primärquelle](https://github.com/SAP/terraform-provider-btp/blob/v1.27.0/btp/provider/resource_subaccount.go)

| Attribut | Typ | Status | YAML/Quelle | Werte, Abhängigkeiten und Risiko |
|---|---|---|---|---|
| beta_enabled | "bool" | Optional, computed | environments.*.beta_enabled | Provider-/API-Plan prüfen. |
| contract_status | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. Shows the contract status of the subaccount. |
| created_by | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The details of the user that created the subaccount. |
| created_date | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was created in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| description | "string" | Optional, computed | environments.*.description | Maximal 300 Zeichen. |
| id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the subaccount. |
| labels | ["map", ["set", "string"]] | Optional | environments.*.labels + reservierte stage/costcenter | Provider: max. 10 Schlüssel, Werte max. 63 Zeichen. Template reserviert zwei Schlüssel. |
| last_modified | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was last modified in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| name | "string" | Pflicht | environments.*.name; sonst Stage + project_name | 1–255 Zeichen, kein /. |
| parent_features | ["set", "string"] | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The features of parent entity of the subaccount. |
| parent_id | "string" | Optional, computed | environments.*.parent_id | Provider-/API-Plan prüfen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| region | "string" | Pflicht | environments.*.region, aufgelöst durch region-catalog | Provider-/API-Plan prüfen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| skip_auto_entitlement | "bool" | Optional | environments.*.skip_auto_entitlement | Creation-only; null bewahrt bisherigen Zustand. Nach Import nicht rekonstruierbar. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| state | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The current state of the subaccount. Possible values are:  |
| subdomain | "string" | Pflicht | environments.*.subdomain; sonst bestehende UUID-Ableitung | Regional eindeutig; Template erzwingt Kleinbuchstaben/Ziffern/Bindestriche. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| usage | "string" | Optional, computed | environments.*.usage | UNSET, NOT_USED_FOR_PRODUCTION, USED_FOR_PRODUCTION; letzteres nur Enterprise-PROD. |

## btp_subaccount_entitlement

[Versionierte Primärquelle](https://github.com/SAP/terraform-provider-btp/blob/v1.27.0/btp/provider/resource_subaccount_entitlement.go)

| Attribut | Typ | Status | YAML/Quelle | Werte, Abhängigkeiten und Risiko |
|---|---|---|---|---|
| amount | "number" | Optional, computed | Definition.amount / services.catalog_amounts / Preset.amount; Katalog-Kategorie prüfen | Ganzzahl 1–2000000000, nur SERVICE/QUOTA_BASED_APPLICATION/PLATFORM/ENVIRONMENT. Positive Deltas werden gemeinsam geprüft. |
| category | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The current state of the entitlement. Possible values are:  |
| created_date | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was created in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the entitled service plan. |
| last_modified | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was last modified in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| plan_id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the entitled service plan. |
| plan_name | "string" | Pflicht | service_catalog.*.plan_name / services.entitlements.*.plan_name / Preset.plan | Provider-/API-Plan prüfen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| plan_unique_identifier | "string" | Optional, computed | Katalogdefinition, Custom-Entitlement oder Preset.plan_unique_identifier | Bei mehreren Preisvarianten zwingend explizit auswählen; keine erste Variante nehmen. |
| service_name | "string" | Pflicht | service_catalog.*.service_name / services.entitlements.*.service_name / dokumentiertes Preset | Provider-/API-Plan prüfen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| state | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The current state of the entitlement. Possible values are:  |
| subaccount_id | "string" | Pflicht | abgeleitete Umgebungs-ID | Provider-/API-Plan prüfen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |

## btp_subaccount_environment_instance

[Versionierte Primärquelle](https://github.com/SAP/terraform-provider-btp/blob/v1.27.0/btp/provider/resource_subaccount_environment_instance.go)

| Attribut | Typ | Status | YAML/Quelle | Werte, Abhängigkeiten und Risiko |
|---|---|---|---|---|
| broker_id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the associated environment broker. |
| created_date | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was created in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| custom_labels | ["map", ["set", "string"]] | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The set of words or phrases assigned to the environment instance. |
| dashboard_url | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The URL of the service dashboard, which is a web-based management user interface for the service instances. |
| description | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The description of the environment instance. |
| environment_type | "string" | Pflicht | environments.*.cloud_foundry.environment_type (CF-Vertrag) | Provider-/API-Plan prüfen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the environment instance. |
| labels | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The Broker-specified key-value pairs that specify attributes of an environment instance. |
| landscape_label | "string" | Optional, computed | environments.*.cloud_foundry.landscape_label; eindeutiger Katalogtreffer | Provider-/API-Plan prüfen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| last_modified | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was last modified in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| name | "string" | Pflicht | environments.*.cloud_foundry.name; sonst eindeutige Subdomain | Provider-/API-Plan prüfen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| operation | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. An identifier that represents the last operation. This ID is returned by the environment brokers. |
| parameters | "string" | Pflicht | environments.*.cloud_foundry.parameters / parameters_key; sonst instance_name | Provider-/API-Plan prüfen. |
| plan_id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the service plan for the environment instance in the corresponding service broker's catalog. |
| plan_name | "string" | Pflicht | environments.*.cloud_foundry.plan | Provider-/API-Plan prüfen. |
| platform_id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the platform for the environment instance in the corresponding service broker's catalog. |
| service_id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the service for the environment instance in the corresponding service broker's catalog. |
| service_name | "string" | Pflicht | environments.*.cloud_foundry.service_name (CF-Vertrag) | Provider-/API-Plan prüfen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| state | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The current state of the environment instance. Possible values are:  |
| subaccount_id | "string" | Pflicht | abgeleitet aus dem Subaccount derselben Umgebung | Provider-/API-Plan prüfen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| tenant_id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the tenant that owns the environment instance. |
| timeouts | {"object": {"create": "string", "delete": "string", "update": "string"}} | Optional | environments.*.cloud_foundry.timeouts | Provider-/API-Plan prüfen. Objekt mit create/update/delete, je optionaler Go-Duration-String; Template erlaubt positive Einheiten ns/us/ms/s/m/h. |
| timeouts.create | "string" | Optional | environments.*.cloud_foundry.timeouts.create | Zeitlimit; zu kleine Werte können Timeouts verursachen, ändern keine State-Adresse. |
| timeouts.delete | "string" | Optional | environments.*.cloud_foundry.timeouts.delete | Zeitlimit; zu kleine Werte können Timeouts verursachen, ändern keine State-Adresse. |
| timeouts.update | "string" | Optional | environments.*.cloud_foundry.timeouts.update | Zeitlimit; zu kleine Werte können Timeouts verursachen, ändern keine State-Adresse. |
| type | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The last provisioning operation on the environment instance. Possible values are:  |

## btp_subaccount_role_collection

[Versionierte Primärquelle](https://github.com/SAP/terraform-provider-btp/blob/v1.27.0/btp/provider/resource_subaccount_role_collection.go)

| Attribut | Typ | Status | YAML/Quelle | Werte, Abhängigkeiten und Risiko |
|---|---|---|---|---|
| description | "string" | Optional, computed | role_collections.*.description | Provider-/API-Plan prüfen. |
| id | "string" | Nur gelesen, computed, deprecated | Provider-Ausgabe | Nicht als Input erlaubt. The combined unique ID of the role collection as used for import operations. |
| name | "string" | Pflicht | role_collections.*.name | Eindeutig je Subaccount; stabile YAML-Schlüssel. Vorhandene Collections nicht doppelt anlegen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| roles | {"object": {"name": "string", "role_template_app_id": "string", "role_template_name": "string"}} | Pflicht | role_collections.*.roles.* | Mindestens eine Rolle; jedes Tripel muss im SAP-Katalog eindeutig existieren und erforderliche Attribute müssen belegt sein. |
| roles.name | "string" | Pflicht | role_collections.*.roles.*.name | Teil der exakten Rollenidentität; gegen den SAP-Rollenkatalog geprüft. |
| roles.role_template_app_id | "string" | Pflicht | role_collections.*.roles.*.role_template_app_id | Teil der exakten Rollenidentität; gegen den SAP-Rollenkatalog geprüft. |
| roles.role_template_name | "string" | Pflicht | role_collections.*.roles.*.role_template_name | Teil der exakten Rollenidentität; gegen den SAP-Rollenkatalog geprüft. |
| subaccount_id | "string" | Pflicht | abgeleitete Umgebungs-ID | Provider-/API-Plan prüfen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |

## btp_subaccount_role_collection_assignment

[Versionierte Primärquelle](https://github.com/SAP/terraform-provider-btp/blob/v1.27.0/btp/provider/resource_subaccount_role_collection_assignment.go)

| Attribut | Typ | Status | YAML/Quelle | Werte, Abhängigkeiten und Risiko |
|---|---|---|---|---|
| attribute_name | "string" | Optional | role_assignments.*.attribute_name | Benötigt attribute_value und origin. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| attribute_value | "string" | Optional | role_assignments.*.attribute_value | Benötigt attribute_name. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| group_name | "string" | Optional | role_assignments.*.group_name | Benötigt origin; externe Collection wird gelesen, verwaltete Collection per Schlüssel referenziert. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| id | "string" | Nur gelesen, computed, deprecated | Provider-Ausgabe | Nicht als Input erlaubt. The combined unique ID of the role collection. |
| origin | "string" | Optional, computed | administrator_options.origin / role_assignments.*.origin | Providerdefault ldap; null erhält Legacy-Verhalten. Custom-IdP nur ausdrücklich wählen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| role_collection_name | "string" | Pflicht | administrator_options.role_collection_name / role_assignments.*.role_collection_name / role_collection_key als Ressourcenreferenz | Externer Name oder role_collection_key einer verwalteten Collection; genau eine Quelle. Neue verwaltete Bindungen benötigen expliziten origin. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| subaccount_id | "string" | Pflicht | abgeleitete Umgebungs-ID | Provider-/API-Plan prüfen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| user_name | "string" | Optional | administrators / bestehender DEV-HCP-Input / role_assignments.*.user_name | Genau eines von user_name/group_name/attribute_name; 1–256 Zeichen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |

## btp_subaccount_service_instance

[Versionierte Primärquelle](https://github.com/SAP/terraform-provider-btp/blob/v1.27.0/btp/provider/resource_subaccount_service_instance.go)

| Attribut | Typ | Status | YAML/Quelle | Werte, Abhängigkeiten und Risiko |
|---|---|---|---|---|
| context | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. Contextual data for the resource. |
| created_date | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was created in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| dashboard_url | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The URL of the web-based management UI for the service instance. |
| id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the service instance. |
| labels | ["map", ["set", "string"]] | Optional, computed | Instanzoptionen.labels | Provider-/API-Plan prüfen. |
| last_modified | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was last modified in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| name | "string" | Pflicht | services.instances.*.name / instance_options.name / service_catalog.*.instance.name | Provider-/API-Plan prüfen. |
| parameters | "string" | Optional, sensitiv | Instanzoptionen.parameters oder parameters_key aus sensitivem Runtime-Input | JSON-Objekt; sensible Inhalte nur über Runtime-Referenz; State-Zugriff schützen. |
| platform_id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The platform ID. |
| ready | "bool" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt.  |
| referenced_instance_id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the instance to which the service instance refers. |
| service_offering_name | "string" | Optional, computed | bei use_plan_names: services.instances.*.offering / Preset / Katalogdefinition | Benötigt serviceplan_name, schließt serviceplan_id aus. RequiresReplaceIfConfigured; Löschschutz/State-Abhängigkeiten beachten. |
| serviceplan_id | "string" | Optional, computed | Instanzoptionen.serviceplan_id als geprüfter Lookup oder tatsächliche Katalog-ID | Alternativ zu serviceplan_name + service_offering_name; echter, bereiter Katalogplan. |
| serviceplan_name | "string" | Optional, computed | bei use_plan_names: offering + plan; kein gleichzeitiges ID-Argument | Benötigt service_offering_name, schließt serviceplan_id aus. |
| shared | "bool" | Optional, computed | Instanzoptionen.shared; tatsächlicher Plan muss shareable sein | Nur wenn der tatsächliche Plan shareable=true meldet. |
| state | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The current state of the service instance. |
| subaccount_id | "string" | Pflicht | abgeleitete Umgebungs-ID | Provider-/API-Plan prüfen. |
| timeouts | {"object": {"create": "string", "delete": "string", "update": "string"}} | Optional | Instanzoptionen.timeouts | Provider-/API-Plan prüfen. Objekt mit create/update/delete, je optionaler Go-Duration-String; Template erlaubt positive Einheiten ns/us/ms/s/m/h. |
| timeouts.create | "string" | Optional | Instanzoptionen.timeouts.create | Zeitlimit; zu kleine Werte können Timeouts verursachen, ändern keine State-Adresse. |
| timeouts.delete | "string" | Optional | Instanzoptionen.timeouts.delete | Zeitlimit; zu kleine Werte können Timeouts verursachen, ändern keine State-Adresse. |
| timeouts.update | "string" | Optional | Instanzoptionen.timeouts.update | Zeitlimit; zu kleine Werte können Timeouts verursachen, ändern keine State-Adresse. |
| usable | "bool" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. Shows whether the resource can be used. |

## btp_subaccount_subscription

[Versionierte Primärquelle](https://github.com/SAP/terraform-provider-btp/blob/v1.27.0/btp/provider/resource_subaccount_subscription.go)

| Attribut | Typ | Status | YAML/Quelle | Werte, Abhängigkeiten und Risiko |
|---|---|---|---|---|
| additional_plan_features | ["set", "string"] | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The list of features specific to this plan. |
| app_id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID returned by XSUAA after the app provider has performed a bind of the multitenant application to an XSUAA service instance. |
| app_name | "string" | Pflicht | services.subscriptions.*.app_name / Katalogdefinition.subscription.app_name / Preset | Provider-/API-Plan prüfen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| authentication_provider | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The authentication provider of the multitenant application. * XSUAA is the SAP Authorization and Trust Management service that defines scopes and permissions for users as tenants at the global account level. * IAS is Identity Authentication Service that defines scopes and permissions for users in zones (common data isolation systems across systems, SaaS tenants, and services). |
| category | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The technical name of the category defined by the app developer to which the multitenant application is grouped in customer-facing UIs. |
| commercial_app_name | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The commercial name of the deployed multitenant application as defined by the app developer. |
| created_date | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was created in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| customer_developed | "bool" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. Shows whether the application was developed by a customer. If not, then the application is developed by the cloud operator, such as SAP. |
| description | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The description of the multitenant application for customer-facing UIs. |
| display_name | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The display name of the application for customer-facing UIs. |
| formation_solution_name | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The name of the formations solution associated with the multitenant application. |
| globalaccount_id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the associated global account. |
| id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The technical ID generated by XSUAA for a multitenant application when a consumer subscribes to the application. |
| labels | ["map", ["set", "string"]] | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The set of words or phrases assigned to the multitenant application subscription. |
| last_modified | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was last modified in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| parameters | "string" | Optional, computed | Subscription-Optionen.parameters oder parameters_key | JSON-Objekt; API-Updates nur wenn supports_parameters_updates. Keine geheimen Werte in YAML. |
| plan_name | "string" | Pflicht | services.subscriptions.*.plan_name / Katalogdefinition.plan_name / Preset | Entitlement + Subaccount-Subscription-Katalog; Planupdates sind anbieterspezifisch. |
| platform_entity_id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the landscape-specific environment. |
| quota | "number" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The total amount the subscribed subaccount is entitled to consume. |
| state | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The subscription state of the subaccount regarding the multitenant application. |
| subaccount_id | "string" | Pflicht | abgeleitete Umgebungs-ID | Provider-/API-Plan prüfen. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| subscribed_subaccount_id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the subaccount, which is subscribed to the multitenant application. |
| subscribed_tenant_id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The ID of the tenant, which is subscribed to a multitenant application. |
| subscription_url | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The URL for app users to launch the subscribed application. |
| supports_parameters_updates | "bool" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. Specifies whether a consumer, whose subaccount is subscribed to the application, can change its subscriptions parameters. |
| supports_plan_updates | "bool" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. Specifies whether a consumer, whose subaccount is subscribed to the application, can change the subscription to a different plan that is available for this application and subaccount. |
| tenant_id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The tenant ID of the application provider. |
| timeouts | {"object": {"create": "string", "delete": "string", "update": "string"}} | Optional | Subscription-Optionen.timeouts | Provider-/API-Plan prüfen. Objekt mit create/update/delete, je optionaler Go-Duration-String; Template erlaubt positive Einheiten ns/us/ms/s/m/h. |
| timeouts.create | "string" | Optional | Subscription-Optionen.timeouts.create | Zeitlimit; zu kleine Werte können Timeouts verursachen, ändern keine State-Adresse. |
| timeouts.delete | "string" | Optional | Subscription-Optionen.timeouts.delete | Zeitlimit; zu kleine Werte können Timeouts verursachen, ändern keine State-Adresse. |
| timeouts.update | "string" | Optional | Subscription-Optionen.timeouts.update | Zeitlimit; zu kleine Werte können Timeouts verursachen, ändern keine State-Adresse. |

## cloudfoundry_space

[Versionierte Primärquelle](https://github.com/cloudfoundry/terraform-provider-cloudfoundry/blob/v1.18.0/cloudfoundry/provider/resource_space.go)

| Attribut | Typ | Status | YAML/Quelle | Werte, Abhängigkeiten und Risiko |
|---|---|---|---|---|
| allow_ssh | "bool" | Optional, computed | spaces.*.allow_ssh | Provider-/API-Plan prüfen. |
| annotations | ["map", "string"] | Optional | spaces.*.annotations | map(string), CF-Metadatenregeln gelten. |
| created_at | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was created in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The GUID of the object. |
| isolation_segment | "string" | Optional | spaces.*.isolation_segment | UUID; muss der Parent-Org bereits zugeteilt sein. |
| labels | ["map", "string"] | Optional | spaces.*.labels | map(string), CF-Metadatenregeln gelten; nicht BTP-map(set(string)). |
| name | "string" | Pflicht | environments.*.cloud_foundry.spaces.*.name | Provider-/API-Plan prüfen. |
| org | "string" | Pflicht | validierter BTP-Output; im bestehenden DEV-Root unveränderter cf_org_id-Input | UUID; aus dem zugehörigen Workspace-/BTP-Handoff, keine freie YAML-Umleitung. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| quota | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The space quota applied to the space. To assign a space quota, use the space quota resource instead. |
| updated_at | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was updated in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |

## cloudfoundry_space_role

[Versionierte Primärquelle](https://github.com/cloudfoundry/terraform-provider-cloudfoundry/blob/v1.18.0/cloudfoundry/provider/resource_space_role.go)

| Attribut | Typ | Status | YAML/Quelle | Werte, Abhängigkeiten und Risiko |
|---|---|---|---|---|
| created_at | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was created in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| id | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The GUID of the object. |
| origin | "string" | Optional | roles.*.origin / member_origin / legacy_manager.origin / legacy_developer.origin | Benötigt username; nicht zusammen mit user. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| space | "string" | Pflicht | abgeleitete ID des Space mit demselben Schlüssel | UUID; automatisch aus dem Space desselben States. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| type | "string" | Pflicht | spaces.*.roles.*.type / managers/developers / bestehende DEV-Rollen | space_manager, space_developer, space_auditor, space_supporter. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| updated_at | "string" | Nur gelesen, computed | Provider-Ausgabe | Nicht als Input erlaubt. The date and time when the resource was updated in [RFC3339](https://www.ietf.org/rfc/rfc3339.txt) format. |
| user | "string" | Optional, computed | roles.*.user / legacy_manager.user / legacy_developer.user | UUID; genau eines von user/username. Origin mit user verboten. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |
| username | "string" | Optional | roles.*.username / managers/developers / Legacy-HCP-Input | Genau eines von user/username; Benutzer braucht bestehende organization_user-Rolle. RequiresReplace; Löschschutz/State-Abhängigkeiten beachten. |

## Jedes YAML-Attribut

Die Tabelle beschreibt auch Template-Felder, die keine Provider-Argumente sind.
Objekte/Maps mit null erhalten keine erfundenen API-Defaults. Direkte und
Runtime-Parameterquellen sind gegenseitig ausgeschlossen. Alle Pfade sind
zusätzlich im maschinenlesbaren JSON Schema enthalten.

| Pfad | Terraform-Typ | YAML-Pflicht | Default | Einschränkungen und Änderungsrisiko |
|---|---|---|---|---|
| schema_version | number | ja | null | enum=[1, 2]; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| account_type | string | ja | null | enum=["trial", "enterprise"]; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| project_name | string | ja | null | pattern="^[A-Za-z0-9][A-Za-z0-9 -]*$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog | map | nein | {} | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| service_catalog.* | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| service_catalog.*.service_name | string | ja | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.plan_name | string | ja | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.amount | number | nein | null | minimum=1; maximum=2000000000; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.plan_unique_identifier | string | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.profiles | set(string) | nein | ["trial", "enterprise"] | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.instance | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| service_catalog.*.instance.name | string | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.instance.parameters | string | nein | null | Non-secret JSON object; secrets use parameters_key.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| service_catalog.*.instance.parameters_key | string | nein | null | Key into sensitive runtime instance_parameters, never a secret value.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| service_catalog.*.instance.labels | map | nein | null | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| service_catalog.*.instance.labels.* | set(string) | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.instance.shared | bool | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.instance.serviceplan_id | string | nein | null | Optional actual catalog ID; checked against the named catalog lookup.Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.instance.use_plan_names | bool | nein | false | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.instance.required_platform | string | nein | null | Required supported_platforms entry from the actual service plan.Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.instance.timeouts | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| service_catalog.*.instance.timeouts.create | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.instance.timeouts.update | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.instance.timeouts.delete | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.subscription | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| service_catalog.*.subscription.parameters | string | nein | null | Non-secret JSON object.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| service_catalog.*.subscription.parameters_key | string | nein | null | Key into sensitive runtime subscription_parameters.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| service_catalog.*.subscription.timeouts | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| service_catalog.*.subscription.timeouts.create | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.subscription.timeouts.update | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.subscription.timeouts.delete | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| service_catalog.*.subscription.app_name | string | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments | map | ja | null | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.* | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.enabled | bool | nein | true | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.name | string | nein | null | pattern="^[^/]+$"; minLength=1; maxLength=255; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.subdomain | string | nein | null | pattern="^[a-z0-9]+(-[a-z0-9]+)*$"; Regions-/Identitäts-/Ersetzungsrisiko; vorher Plan prüfen. |
| environments.*.description | string | nein | null | maxLength=300; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.region | string | nein | null | Actual region code, or null for an unambiguous catalog selection.minLength=1; Regions-/Identitäts-/Ersetzungsrisiko; vorher Plan prüfen. |
| environments.*.iaas_provider | string | nein | null | enum=["AWS", "AZURE", "GCP", "SAP", "ALI", "IBM"]; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.runtime | string | nein | "cloudfoundry" | btp_regions.environment predicate, not a subaccount API attribute.Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.parent_id | string | nein | null | format="uuid"; Regions-/Identitäts-/Ersetzungsrisiko; vorher Plan prüfen. |
| environments.*.usage | string | nein | null | enum=["UNSET", "NOT_USED_FOR_PRODUCTION", "USED_FOR_PRODUCTION"]; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.costcenter | string | ja | null | pattern="^[0-9]{5}$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.beta_enabled | bool | nein | false | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.skip_auto_entitlement | bool | nein | null | Regions-/Identitäts-/Ersetzungsrisiko; vorher Plan prüfen. |
| environments.*.labels | map | nein | {} | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.labels.* | set(string) | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.administrators_source | string | nein | "yaml" | enum=["yaml", "legacy"]; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.administrators | set(string) | nein | [] | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.administrator_options | object | nein | {} | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.administrator_options.role_collection_name | string | nein | "Subaccount Administrator" | minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.administrator_options.origin | string | nein | null | minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.role_assignments | map | nein | {} | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.role_assignments.* | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.role_assignments.*.role_collection_name | string | nein | null | minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.role_assignments.*.role_collection_key | string | nein | null | Key of a role collection managed in the same environment; requires explicit origin.minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.role_assignments.*.user_name | string | nein | null | minLength=1; maxLength=256; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.role_assignments.*.group_name | string | nein | null | minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.role_assignments.*.attribute_name | string | nein | null | minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.role_assignments.*.attribute_value | string | nein | null | minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.role_assignments.*.origin | string | nein | null | minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.role_collections | map | nein | {} | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.role_collections.* | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.role_collections.*.name | string | ja | null | minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.role_collections.*.description | string | nein | null | Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.role_collections.*.roles | map | ja | null | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.role_collections.*.roles.* | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.role_collections.*.roles.*.name | string | ja | null | minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.role_collections.*.roles.*.role_template_name | string | ja | null | minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.role_collections.*.roles.*.role_template_app_id | string | ja | null | minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.cloud_foundry | object | nein | {} | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.cloud_foundry.enabled | bool | nein | false | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.name | string | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.plan | string | nein | "trial" | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.environment_type | string | nein | "cloudfoundry" | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.service_name | string | nein | "cloudfoundry" | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.landscape_label | string | nein | "" | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.parameters | string | nein | null | Non-secret JSON; default preserves instance_name.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| environments.*.cloud_foundry.parameters_key | string | nein | null | Key into sensitive runtime environment_parameters.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| environments.*.cloud_foundry.timeouts | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.cloud_foundry.timeouts.create | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.timeouts.update | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.timeouts.delete | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.spaces | map | nein | {} | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.cloud_foundry.spaces.* | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.cloud_foundry.spaces.*.name | string | ja | null | minLength=1; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.spaces.*.allow_ssh | bool | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.spaces.*.isolation_segment | string | nein | null | format="uuid"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.spaces.*.labels | map | nein | null | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.cloud_foundry.spaces.*.labels.* | string | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.spaces.*.annotations | map | nein | null | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.cloud_foundry.spaces.*.annotations.* | string | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.spaces.*.managers | set(string) | nein | [] | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.spaces.*.developers | set(string) | nein | [] | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.spaces.*.member_origin | string | nein | null | Origin for simple managers/developers; rejected for DEV/project, whose legacy roles have individual origins.Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.cloud_foundry.spaces.*.roles | map | nein | {} | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.cloud_foundry.spaces.*.roles.* | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.cloud_foundry.spaces.*.roles.*.type | string | ja | null | enum=["space_manager", "space_developer", "space_auditor", "space_supporter"]; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.cloud_foundry.spaces.*.roles.*.user | string | nein | null | format="uuid"; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.cloud_foundry.spaces.*.roles.*.username | string | nein | null | minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.cloud_foundry.spaces.*.roles.*.origin | string | nein | null | Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.cloud_foundry.spaces.*.legacy_manager | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.cloud_foundry.spaces.*.legacy_manager.user | string | nein | null | format="uuid"; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.cloud_foundry.spaces.*.legacy_manager.username | string | nein | null | minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.cloud_foundry.spaces.*.legacy_manager.origin | string | nein | null | Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.cloud_foundry.spaces.*.legacy_developer | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.cloud_foundry.spaces.*.legacy_developer.user | string | nein | null | format="uuid"; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.cloud_foundry.spaces.*.legacy_developer.username | string | nein | null | minLength=1; Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.cloud_foundry.spaces.*.legacy_developer.origin | string | nein | null | Berechtigungsänderung; Subjekt-Kombination und vorhandene Mitgliedschaft prüfen. |
| environments.*.services | object | nein | {} | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.alert_notification | object | nein | {} | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.alert_notification.enabled | bool | nein | false | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.alert_notification.plan | string | nein | "standard" | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.alert_notification.instance | bool | nein | true | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.alert_notification.amount | number | nein | null | minimum=1; maximum=2000000000; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.alert_notification.plan_unique_identifier | string | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.alert_notification.instance_options | object | nein | {} | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.alert_notification.instance_options.name | string | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.alert_notification.instance_options.parameters | string | nein | null | Non-secret JSON object; secrets use parameters_key.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| environments.*.services.alert_notification.instance_options.parameters_key | string | nein | null | Key into sensitive runtime instance_parameters, never a secret value.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| environments.*.services.alert_notification.instance_options.labels | map | nein | null | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.services.alert_notification.instance_options.labels.* | set(string) | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.alert_notification.instance_options.shared | bool | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.alert_notification.instance_options.serviceplan_id | string | nein | null | Optional actual catalog ID; checked against the named catalog lookup.Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.alert_notification.instance_options.use_plan_names | bool | nein | false | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.alert_notification.instance_options.required_platform | string | nein | null | Required supported_platforms entry from the actual service plan.Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.alert_notification.instance_options.timeouts | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.alert_notification.instance_options.timeouts.create | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.alert_notification.instance_options.timeouts.update | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.alert_notification.instance_options.timeouts.delete | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags | object | nein | {} | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.feature_flags.enabled | bool | nein | false | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.plan | string | nein | "lite" | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.instance | bool | nein | true | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.amount | number | nein | null | minimum=1; maximum=2000000000; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.plan_unique_identifier | string | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.instance_options | object | nein | {} | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.feature_flags.instance_options.name | string | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.instance_options.parameters | string | nein | null | Non-secret JSON object; secrets use parameters_key.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| environments.*.services.feature_flags.instance_options.parameters_key | string | nein | null | Key into sensitive runtime instance_parameters, never a secret value.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| environments.*.services.feature_flags.instance_options.labels | map | nein | null | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.services.feature_flags.instance_options.labels.* | set(string) | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.instance_options.shared | bool | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.instance_options.serviceplan_id | string | nein | null | Optional actual catalog ID; checked against the named catalog lookup.Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.instance_options.use_plan_names | bool | nein | false | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.instance_options.required_platform | string | nein | null | Required supported_platforms entry from the actual service plan.Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.instance_options.timeouts | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.feature_flags.instance_options.timeouts.create | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.instance_options.timeouts.update | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.instance_options.timeouts.delete | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.dashboard | bool | nein | true | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.dashboard_amount | number | nein | null | minimum=1; maximum=2000000000; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.dashboard_plan_unique_identifier | string | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.subscription_options | object | nein | {} | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.feature_flags.subscription_options.parameters | string | nein | null | Non-secret JSON object.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| environments.*.services.feature_flags.subscription_options.parameters_key | string | nein | null | Key into sensitive runtime subscription_parameters.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| environments.*.services.feature_flags.subscription_options.timeouts | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.feature_flags.subscription_options.timeouts.create | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.subscription_options.timeouts.update | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.feature_flags.subscription_options.timeouts.delete | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.work_zone | object | nein | {} | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.work_zone.enabled | bool | nein | false | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.work_zone.plan | string | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.work_zone.amount | number | nein | null | minimum=1; maximum=2000000000; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.work_zone.plan_unique_identifier | string | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.work_zone.subscription_options | object | nein | {} | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.work_zone.subscription_options.parameters | string | nein | null | Non-secret JSON object.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| environments.*.services.work_zone.subscription_options.parameters_key | string | nein | null | Key into sensitive runtime subscription_parameters.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| environments.*.services.work_zone.subscription_options.timeouts | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.work_zone.subscription_options.timeouts.create | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.work_zone.subscription_options.timeouts.update | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.work_zone.subscription_options.timeouts.delete | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.entitlements | map | nein | {} | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.services.entitlements.* | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.entitlements.*.service_name | string | ja | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.entitlements.*.plan_name | string | ja | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.entitlements.*.amount | number | nein | null | minimum=1; maximum=2000000000; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.entitlements.*.plan_unique_identifier | string | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.instances | map | nein | {} | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.services.instances.* | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.instances.*.name | string | ja | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.instances.*.parameters | string | nein | null | Non-secret JSON object; secrets use parameters_key.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| environments.*.services.instances.*.parameters_key | string | nein | null | Key into sensitive runtime instance_parameters, never a secret value.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| environments.*.services.instances.*.labels | map | nein | null | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.services.instances.*.labels.* | set(string) | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.instances.*.shared | bool | nein | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.instances.*.serviceplan_id | string | nein | null | Optional actual catalog ID; checked against the named catalog lookup.Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.instances.*.use_plan_names | bool | nein | false | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.instances.*.required_platform | string | nein | null | Required supported_platforms entry from the actual service plan.Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.instances.*.timeouts | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.instances.*.timeouts.create | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.instances.*.timeouts.update | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.instances.*.timeouts.delete | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.instances.*.offering | string | ja | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.instances.*.plan | string | ja | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.subscriptions | map | nein | {} | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.services.subscriptions.* | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.subscriptions.*.parameters | string | nein | null | Non-secret JSON object.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| environments.*.services.subscriptions.*.parameters_key | string | nein | null | Key into sensitive runtime subscription_parameters.Nur nicht geheime JSON-Objekte oder getrennte sensitive Runtime-Referenz; Broker-Schema zusätzlich maßgeblich. |
| environments.*.services.subscriptions.*.timeouts | object | nein | null | Optionales Konfigurationsobjekt; Pflichtfelder/Abhängigkeiten siehe untergeordnete Pfade. |
| environments.*.services.subscriptions.*.timeouts.create | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.subscriptions.*.timeouts.update | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.subscriptions.*.timeouts.delete | string | nein | null | pattern="^([0-9]+(\\.[0-9]+)?(ns\|us\|ms\|s\|m\|h))+$"; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.subscriptions.*.app_name | string | ja | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.subscriptions.*.plan_name | string | ja | null | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.catalog | set(string) | nein | [] | Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |
| environments.*.services.catalog_amounts | map | nein | {} | Stabile Schlüssel; Entfernen bereits verwalteter Schlüssel kann Löschungen planen. |
| environments.*.services.catalog_amounts.* | number | nein | null | minimum=1; maximum=2000000000; Nach Katalog-/Schema-Prüfung gilt der konkrete Provider-/API-Plan. |

## Grenzen der Abdeckung

- Alle beschreibbaren Attribute der implementierten Ressourcentypen sind direkt oder abgeleitet verbunden.
- Berechnete Felder wie CF-Environment-custom_labels, Space.quota, IDs, Zeitstempel und Status sind keine YAML-Eingaben.
- Eine CF-Space-Quota braucht eine eigene Ressource; hier wird keine Schreibfähigkeit erfunden.
- Broker-Parameterschemas werden nicht vollständig lokal ausgeführt. Die API prüft dienstspezifische Semantik.
- Role Collections werden explizit über YAML verwaltet; Zuweisungen sind davon getrennt und standardmäßig leer.
- Org-Mitgliedschaften, Isolation-Segment-Entitlements, Service-Bindings und Apps werden nicht erstellt.
- Diese Momentaufnahme ist kein Live-Verfügbarkeits- oder Quotenbeweis. Neue Subaccount-Kataloge sind erst nach deren Existenz lesbar.
- Alle Schema-Beschreibungen stammen aus den jeweiligen SAP-/Cloud-Foundry-Providern (Apache-2.0); Quellen siehe oben.
