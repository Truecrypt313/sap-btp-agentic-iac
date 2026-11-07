# ============================================================================
# BTP | main.tf – SAP-BTP-Subaccount und Cloud-Foundry-Umgebung bereitstellen
# ============================================================================
# Diese Root-Konfiguration übernimmt die übergreifende Infrastruktur:
#   1. Global Account über eine Data Source lesen
#   2. Eindeutige Subaccount-Namen/-Subdomain berechnen
#   3. Subaccount mit Labels anlegen
#   4. Cloud-Foundry-Environment im Subaccount aktivieren
#   5. Service-/Entitlement-Baseline über ein Child-Modul verwalten
#   6. Optionale Emergency-Admin-Rollenzuweisungen aus einer Liste erzeugen
#
# Die Cloud-Foundry-SPACES und deren Space-Rollen liegen dagegen im getrennten
# Terraform-Projekt CloudFoundry/ mit EIGENEM State.
# HINWEIS: 'terraform plan' vor jeder Übernahme von Änderungen prüfen;
# insbesondere Subdomain-/Regionswechsel können ressourcenersetzend sein.
# Data Source: bestehende Informationen des angemeldeten Global Accounts
# LESEN, nicht einen neuen Global Account erstellen.
# Der Name 'current' ist nur der Terraform-interne Referenzbezeichner.
data "btp_globalaccount" "current" {}

# Kontroll-Output: Zeigt nach einem Apply die gelesene Global-Account-
# Subdomain. Abrufbar mit 'terraform output connected_globalaccount'.
# Outputs definieren keine SAP-Ressourcen, sondern veröffentlichen Werte.
output "connected_globalaccount" {
  value = data.btp_globalaccount.current.subdomain
}

# Die random_uuid-Ressource erzeugt eine UUID und verwaltet sie im State.
# Solange die Ressource/der State bestehen bleibt, bleibt die UUID stabil.
# Sie macht die Subdomain projektübergreifend eindeutig; sie wird NICHT
# bei jedem 'terraform apply' neu erzeugt.
# Vorsicht beim Löschen/Neuerstellen dieser State-Ressource: Ein neuer
# Subdomain-Name könnte den Ersatz des BTP-Subaccounts erfordern.
resource "random_uuid" "uuid" {
  lifecycle {
    prevent_destroy = true
  }
}


# 'locals' berechnet interne Hilfswerte; anders als variable-Blöcke sind
# sie keine Eingabeparameter. Zugriff innerhalb der Datei über local.NAME.
locals {
  # Sichtbarer Anzeigename, z. B. 'DEV Project ABC'.
  subaccount_name = coalesce(local.dev.name, "DEV ${local.project_name}")

  # Technischer Basisname: ersetzt Leerzeichen durch '-' und erzeugt
  # Kleinbuchstaben. Der UUID-Anteil wird erst weiter unten angehängt.
  subaccount_subdomain_base = lower(
    replace("DEV-${local.project_name}", " ", "-")
  )

  # join('-', LISTE) verbindet Basisname und UUID mit Bindestrich.
  # Dieser Wert wird sowohl für den BTP-Subaccount als auch für den
  # Cloud-Foundry-Organisationsnamen genutzt.
  subaccount_subdomain = local.dev.subdomain != null ? local.dev.subdomain : join("-", [
    local.subaccount_subdomain_base,
    random_uuid.uuid.result
  ])

  # Der bestehende DEV-Wert kommt jetzt aus der zentralen YAML.
  beta_enabled = local.dev.beta_enabled

  # Der technische CF-Organisationsname orientiert sich in diesem Projekt
  # an der berechneten Subdomain des BTP-Subaccounts.
  subaccount_cf_org = local.subaccount_subdomain
}


# Aufruf des lokalen wiederverwendbaren Child-Moduls.
# Das Modul verwaltet drei Entitlements, eine Service Instance und eine
# App Subscription. Die Ressourcen stehen NICHT nochmals in dieser main.tf.
# Durch die Referenz auf die Subaccount-Ressource entsteht automatisch eine
# Abhängigkeit: Die ID muss existieren, bevor die Services erstellt werden.
# Modulpfad: BTP/modules/srvc-baseline/
module "srvc_baseline" {
  # Lokaler relativer Pfad zum Modul; kein Registry-Download.
  source        = "./modules/srvc-baseline"
  subaccount_id = btp_subaccount.project_subaccount.id
  project_name  = local.project_name
  # Dieses Modul bleibt zur Adresserhaltung ausschließlich für DEV zuständig.
  project_stage           = "DEV"
  configuration           = local.dev.services
  catalog_valid           = module.service_catalog.valid
  instance_parameters     = { for key, value in var.instance_parameters : trimprefix(key, "DEV/") => value if startswith(key, "DEV/") }
  subscription_parameters = { for key, value in var.subscription_parameters : trimprefix(key, "DEV/") => value if startswith(key, "DEV/") }
}


# Erstellt/verwaltet den eigentlichen SAP-BTP-Subaccount.
# Anzeigename, technische Subdomain und Region kommen aus Variablen/locals.
# Beispiel: Der Anzeigename kann 'DEV Project ABC' lauten, die technische
# Subdomain besitzt wegen random_uuid zusätzlich eine eindeutige Kennung.
resource "btp_subaccount" "project_subaccount" {
  name                  = local.subaccount_name
  subdomain             = local.subaccount_subdomain
  region                = module.region_catalog.regions["DEV"]
  description           = local.dev.description
  parent_id             = local.dev.parent_id
  usage                 = local.dev.usage
  skip_auto_entitlement = local.dev.skip_auto_entitlement
  beta_enabled          = local.beta_enabled

  # Labels sind benutzerdefinierte Metadaten am Subaccount.
  # Der Provider erwartet pro Label eine Liste von String-Werten.
  # Sie helfen beim Filtern/Governance, steuern aber keine SAP-Kosten direkt.
  labels = merge(local.dev.labels, {
    "stage"      = ["DEV"]
    "costcenter" = [local.dev.costcenter]
  })

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = local.configuration.account_type == "trial" ? data.btp_globalaccount.current.license_type == "TRIAL" : data.btp_globalaccount.current.license_type != "TRIAL"
      error_message = "The declared Trial/Enterprise profile conflicts with the authenticated global account license."
    }
    precondition {
      condition     = local.dev.enabled && local.dev.cloud_foundry.enabled
      error_message = "Existing DEV and its Cloud Foundry environment must remain enabled."
    }
    precondition {
      condition = (
        local.dev.services.alert_notification.enabled &&
        local.dev.services.alert_notification.plan == "standard" &&
        local.dev.services.alert_notification.instance &&
        local.dev.services.feature_flags.enabled &&
        local.dev.services.feature_flags.plan == "lite" &&
        local.dev.services.feature_flags.dashboard
      )
      error_message = "The existing DEV service baseline must remain enabled with its original plans; migration requires a separate reviewed plan."
    }
    precondition {
      condition     = var.configuration_mode == "yaml" || local.legacy_inputs_match
      error_message = "Legacy DEV inputs conflict with YAML. Reconcile them before switching explicitly to configuration_mode=yaml."
    }
    precondition {
      condition     = local.additional_inputs_match
      error_message = "additional_subaccounts conflicts with YAML or is still set in yaml mode. Reconcile/remove the HCP override; do not delete the TEST YAML entry."
    }
    precondition {
      condition     = var.configuration_mode == "yaml" || local.dev.cloud_foundry.plan == "trial"
      error_message = "Existing DEV uses the trial CF plan. Changing it requires a separate replacement/migration review."
    }
  }
}

#Terraform-Ressource an, mit der wir später eine Cloud-Foundry-Organisation in deinem SAP-BTP-Subaccount erstellen.
#Die Funktion jsonencode() wandelt ein Terraform-Objekt automatisch in JSON um. Diesen JSON-Wert übergibt der Provider an SAP BTP.
# Aktiviert die Cloud-Foundry-Umgebung innerhalb DES erstellten Subaccounts.
# Achtung: Dies ist die CF-ENVIRONMENT/ORG-Ebene. Den eigentlichen CF-Space
# erzeugt das separate Terraform-Projekt CloudFoundry/main.tf.
# 'trial' ist der Plan aus dem SAP-BTP-Trial-Tutorial.
resource "btp_subaccount_environment_instance" "cloudfoundry" {
  # Terraform liest die ID der oben definierten Subaccount-Ressource.
  # Solche direkten Referenzen erzeugen implizite Abhängigkeiten.
  subaccount_id    = btp_subaccount.project_subaccount.id
  name             = coalesce(local.dev.cloud_foundry.name, local.subaccount_cf_org)
  environment_type = local.dev.cloud_foundry.environment_type
  service_name     = local.dev.cloud_foundry.service_name
  plan_name        = local.dev.cloud_foundry.plan
  # Das Landscape kann über eine Variable vorgegeben oder aus den
  # verfügbaren Environments ermittelt werden (siehe weiter unten).
  # terraform_data.output liefert den vorher ermittelten Wert.
  landscape_label = terraform_data.cf_landscape_label.output

  # Die Provider-API erwartet für 'parameters' JSON.
  # jsonencode() konvertiert das HCL-Objekt zuverlässig in JSON-Text.
  parameters = local.dev.cloud_foundry.parameters_key != null ? lookup(var.environment_parameters, "DEV/${local.dev.cloud_foundry.parameters_key}", null) : (
    local.dev.cloud_foundry.parameters != null ? local.dev.cloud_foundry.parameters : jsonencode({ instance_name = coalesce(local.dev.cloud_foundry.name, local.subaccount_cf_org) })
  )
  timeouts = local.dev.cloud_foundry.timeouts

  lifecycle {
    prevent_destroy = true
    precondition {
      condition = contains([
        for env in data.btp_subaccount_environments.all.values : env.landscape_label
        if env.service_name == local.dev.cloud_foundry.service_name && env.environment_type == local.dev.cloud_foundry.environment_type && env.plan_name == local.dev.cloud_foundry.plan
      ], terraform_data.cf_landscape_label.output)
      error_message = "The existing DEV landscape must support the configured actual CF service/type/plan."
    }
    precondition {
      condition     = local.dev.cloud_foundry.parameters_key == null ? true : contains(keys(var.environment_parameters), "DEV/${local.dev.cloud_foundry.parameters_key}")
      error_message = "Missing runtime parameter reference for the existing DEV CF environment."
    }

  }
}

# Data Source: liest die für diesen Subaccount verfügbaren Environments.
# Im nächsten Block wird daraus nach einer passenden CF-Landschaft gesucht.
# Diese Data Source legt selbst keine Umgebung an.
data "btp_subaccount_environments" "all" {
  subaccount_id = btp_subaccount.project_subaccount.id
}

# Terraform-eigene Verwaltungsressource ohne externes SAP-BTP-Objekt.
# Dient hier dazu, den ausgewählten Landscape-Wert als Ressourcenergebnis
# verfügbar zu machen. Der Wert wird im State festgehalten und über
# terraform_data.cf_landscape_label.output an die CF-Umgebung übergeben.
resource "terraform_data" "cf_landscape_label" {
  # Falls eine Landschaft explizit angegeben wurde, nimm diesen Wert.
  # Ansonsten (Teil hinter ':') filtert die for-Expression verfügbare
  # Environments nach 'cloudfoundry' und übernimmt mit [0] den ERSTEN
  # Treffer. Gibt es keinen Treffer, schlägt dieser Ausdruck fehl.
  # Bei mehreren Treffern ist die Reihenfolge der Anbieterantwort wichtig.
  input = local.dev.cloud_foundry.landscape_label != "" ? local.dev.cloud_foundry.landscape_label : try(one(distinct([
    for env in data.btp_subaccount_environments.all.values : env.landscape_label
    if env.service_name == local.dev.cloud_foundry.service_name && env.environment_type == local.dev.cloud_foundry.environment_type && env.plan_name == local.dev.cloud_foundry.plan
  ])), null)
  lifecycle {
    precondition {
      condition = local.dev.cloud_foundry.landscape_label != "" || length(distinct([
        for env in data.btp_subaccount_environments.all.values : env.landscape_label
        if env.service_name == local.dev.cloud_foundry.service_name && env.environment_type == local.dev.cloud_foundry.environment_type && env.plan_name == local.dev.cloud_foundry.plan
      ])) == 1
      error_message = "DEV needs an explicit existing landscape or one unique actual CF plan/landscape candidate."
    }
  }
}

# Optionale direkte Zuweisung der Role Collection 'Subaccount Administrator'.
# Jede Instanz ist eine Berechtigungsänderung mit großen Auswirkungen.
# Die Konfiguration verwendet die Liste aus variables.tf / terraform.tfvars.
# Leere Liste = keine Instanzen; nur tatsächlich berechtigte Accounts angeben.
resource "btp_subaccount_role_collection_assignment" "emergency_administrators" {
  # toset() entfernt Dubletten und erzeugt ein Set eindeutiger Benutzernamen.
  # for_each erstellt pro Set-Eintrag eine Ressource mit stabilem Schlüssel.
  # Der Schlüssel ist im State sichtbar; Benutzernamen nicht als geheim
  # betrachten. Änderungen an der Liste werden im nächsten Plan abgebildet.
  for_each = local.dev_administrators

  subaccount_id        = btp_subaccount.project_subaccount.id
  role_collection_name = local.dev.administrator_options.role_collection_name
  origin               = local.dev.administrator_options.origin
  # Bei einem Set aus Strings gilt each.key == each.value.
  # each.value ist hier der Benutzer, der die Admin-Rolle erhält.
  user_name = each.value
}
