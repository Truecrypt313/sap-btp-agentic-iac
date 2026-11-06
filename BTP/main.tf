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
resource "random_uuid" "uuid" {}


# 'locals' berechnet interne Hilfswerte; anders als variable-Blöcke sind
# sie keine Eingabeparameter. Zugriff innerhalb der Datei über local.NAME.
locals {
  # Sichtbarer Anzeigename, z. B. 'DEV Project ABC'.
  subaccount_name = "${var.subaccount_stage} ${var.project_name}"

  # Technischer Basisname: ersetzt Leerzeichen durch '-' und erzeugt
  # Kleinbuchstaben. Der UUID-Anteil wird erst weiter unten angehängt.
  subaccount_subdomain_base = lower(
    replace("${var.subaccount_stage}-${var.project_name}", " ", "-")
  )

  # join('-', LISTE) verbindet Basisname und UUID mit Bindestrich.
  # Dieser Wert wird sowohl für den BTP-Subaccount als auch für den
  # Cloud-Foundry-Organisationsnamen genutzt.
  subaccount_subdomain = join("-", [
    local.subaccount_subdomain_base,
    random_uuid.uuid.result
  ])

  # Zusätzlicher Hinweis zum bestehenden Kommentar: Dieser ternäre Ausdruck
  # setzt beta_enabled nur in der Umgebung PROD auf false; DEV/TEST auf true.
  # Das ist eine projektspezifische Regel, keine generelle SAP-Vorschrift.
  beta_enabled = var.subaccount_stage == "PROD" ? false : true #Das nennt man einen bedingten Ausdruck (ternary expression). Terraform prüft, ob die Umgebung PROD ist. Falls ja, wird false verwendet. Andernfalls wird true verwendet.

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
  project_name  = var.project_name
  # Die Root-Variable 'subaccount_stage' heißt im Modul 'project_stage'.
  # Dieses Mapping verbindet die zwei getrennten Variablen-Namensräume.
  project_stage = var.subaccount_stage
}


# Erstellt/verwaltet den eigentlichen SAP-BTP-Subaccount.
# Anzeigename, technische Subdomain und Region kommen aus Variablen/locals.
# Beispiel: Der Anzeigename kann 'DEV Project ABC' lauten, die technische
# Subdomain besitzt wegen random_uuid zusätzlich eine eindeutige Kennung.
resource "btp_subaccount" "project_subaccount" {
  name         = local.subaccount_name
  subdomain    = local.subaccount_subdomain
  region       = var.subaccount_region
  beta_enabled = local.beta_enabled

  # Labels sind benutzerdefinierte Metadaten am Subaccount.
  # Der Provider erwartet pro Label eine Liste von String-Werten.
  # Sie helfen beim Filtern/Governance, steuern aber keine SAP-Kosten direkt.
  labels = {
    "stage"      = [var.subaccount_stage]
    "costcenter" = [var.project_costcenter]
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
  name             = local.subaccount_cf_org
  environment_type = "cloudfoundry"
  service_name     = "cloudfoundry"
  plan_name        = "trial"
  # Das Landscape kann über eine Variable vorgegeben oder aus den
  # verfügbaren Environments ermittelt werden (siehe weiter unten).
  # terraform_data.output liefert den vorher ermittelten Wert.
  landscape_label  = terraform_data.cf_landscape_label.output

  # Die Provider-API erwartet für 'parameters' JSON.
  # jsonencode() konvertiert das HCL-Objekt zuverlässig in JSON-Text.
  parameters = jsonencode({
    instance_name = local.subaccount_cf_org
  })
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
  input = length(var.cf_landscape_label) > 0 ? var.cf_landscape_label : [
    for env in data.btp_subaccount_environments.all.values :
    env if env.service_name == "cloudfoundry" && env.environment_type == "cloudfoundry"
  ][0].landscape_label
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
  for_each = toset(var.subaccount_emergency_admins)

  subaccount_id        = btp_subaccount.project_subaccount.id
  role_collection_name = "Subaccount Administrator"
  # Bei einem Set aus Strings gilt each.key == each.value.
  # each.value ist hier der Benutzer, der die Admin-Rolle erhält.
  user_name            = each.value
}
