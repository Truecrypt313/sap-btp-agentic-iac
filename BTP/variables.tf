# ============================================================================
# BTP | variables.tf – Eingabeparameter des BTP-Root-Moduls
# ============================================================================
# 'variable' definiert die Eingabeschnittstelle der gesamten BTP-Konfiguration.
# Die konkreten Werte können z. B. aus terraform.tfvars oder -var kommen.
# Bei Variablen mit 'default' ist die Angabe optional; ohne default ist sie
# verpflichtend. 'validation' prüft Werte, bevor Terraform sie verwendet.
#
# Achtung: Änderungen an Namen, Region oder Subdomain können – abhängig von
# den Provider-Eigenschaften – den Ersatz bestehender Ressourcen auslösen.
# Solche Änderungen immer zunächst mit 'terraform plan' prüfen.

# Global-Account-Subdomain, die der SAP-BTP-Provider zur Verbindung benötigt.
# Sie wird in provider.tf über var.globalaccount gelesen.
# Kein Default: Der Aufrufer muss einen Wert liefern.
variable "globalaccount" {
  description = "Subdomain of the SAP BTP Global Account"
  type        = string
}

# Region, in der der BTP-Subaccount bereitgestellt wird.
# 'us10' ist hier der voreingestellte Wert aus dem Tutorial.
# Die nachfolgende Validierung erlaubt in DIESER Konfiguration nur us10/ap21;
# das ist keine abschließende Liste sämtlicher SAP-BTP-Regionen.
variable "subaccount_region" {
  description = "Region of the SAP BTP Subaccount"
  type        = string
  default     = "us10"

  # contains(LISTE, WERT) liefert true, wenn der Wert in der Liste steht.
  # Ist die Bedingung false, stoppt Terraform mit error_message.
  validation {
    condition     = contains(["us10", "ap21"], var.subaccount_region)
    error_message = "Region must be one of us10 or ap21"
  }
}

#Mit der Funktion contains() erlauben wir ausschließlich drei Werte: DEV, TEST oder PROD
# Fachliche Umgebung des Subaccounts: DEV, TEST oder PROD.
# Wird für Anzeigenamen, Subdomain, Labels und die Beta-Einstellung genutzt.
# Die Variable beschreibt die Umgebung, sie erstellt nicht automatisch
# mehrere Subaccounts; dafür müsste die Konfiguration mehrfach aufgerufen werden.
variable "subaccount_stage" {
  description = "Stage of the SAP BTP Subaccount"
  type        = string
  default     = "DEV"

  validation {
    condition     = contains(["DEV", "TEST", "PROD"], var.subaccount_stage)
    error_message = "Stage must be DEV, TEST or PROD"
  }
}

# Kostenstelle als String (nicht als Zahl), damit auch führende Nullen
# erhalten bleiben könnten. Die zulässige Form wird durch Regex kontrolliert.
# Das Label ist Metadatum; es erzeugt keine automatische Kostenabrechnung.
variable "project_costcenter" {
  description = "Cost center of the project"
  type        = string
  default     = "12345"

  validation {
    condition     = can(regex("^[0-9]{5}$", var.project_costcenter)) #Hier verwenden wir einen regulären Ausdruck (Regex).Dieser bedeutet, dass die Kostenstelle aus exakt fünf Ziffern bestehen muss.
    error_message = "Cost center must be a 5-digit number"
  }
}

# Menschenlesbarer Projektname. Zusammen mit dem Stage-Wert wird er z. B.
# in der Subaccount-Bezeichnung und im Service-Instanznamen verwendet.
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "Project ABC"
}


# Optionales Cloud-Foundry-Landscape-Label, z. B. 'cf-us10-001'.
# Leer ('') bedeutet: Die Konfiguration ermittelt später automatisch das
# erste passende CF-Landscape über die Data Source in main.tf.
# Die Auswahl wird dann in terraform_data.cf_landscape_label verwendet.
variable "cf_landscape_label" {
  type        = string
  description = "The Cloud Foundry landscape (format example us10-001)."
  default     = ""
}

# Liste der Benutzer, denen die Role Collection 'Subaccount Administrator'
# direkt zugewiesen werden soll (siehe for_each in main.tf).
# [] = keine Zuweisungen; jeder zusätzliche eindeutige Name = eine Instanz.
# Achtung: Das sind weitreichende Rechte. In produktiven Setups besser ein
# geregeltes Berechtigungs- und Offboarding-Verfahren vorsehen.
# Nicht 'sensitive = true' setzen, solange die Werte als for_each-Schlüssel
# verwendet werden: Die Schlüssel erscheinen in Plan und Terraform State.
variable "subaccount_emergency_admins" {
  type        = list(string)
  description = "List of emergency admins for the SAP BTP subaccount"
  default     = []
}
