# ============================================================================
# CloudFoundry | variables.tf – Eingaben für Space und Rollenzuweisungen
# ============================================================================
# Die Cloud-Foundry-Konfiguration läuft separat von BTP/main.tf und kann
# daher dessen Variablen/Outputs nicht direkt als lokale Werte lesen.
# Die benötigten BTP-Outputs werden als Eingabe über terraform.tfvars
# übergeben (z. B. cf_api_url, cf_org_id und subaccount_url).

# API-Endpunkt der bereitgestellten Cloud-Foundry-Umgebung.
# Dient dem CF-Provider in provider.tf zum Verbindungsaufbau.
# Im BTP-Projekt als Output cf_api_url verfügbar.
variable "cf_api_url" {
  description = "The Cloud Foundry API URL"
  type        = string
}

# Technische Cloud-Foundry-Organisations-ID (NICHT der Global-Account-ID).
# Wird sowohl beim Space-Anlegen als auch beim Erstellen der URL benötigt.
# Stammt aus dem BTP-Output cf_org_id.
variable "cf_org_id" {
  description = "The Cloud Foundry organization ID"
  type        = string
}

# Teil des lesbaren Space-Namens, hier standardmäßig 'Project ABC'.
# CloudFoundry/main.tf setzt Stage und Projektname zu einem Namen zusammen.
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "Project ABC"
}

# Das Umgebungskürzel bestimmt die Namenskonvention des Spaces.
# Nur DEV, TEST und PROD sind durch diese konkrete Validation erlaubt.
# Änderungen nach dem Anlegen unbedingt zuerst im Plan kontrollieren.
variable "subaccount_stage" {
  description = "Stage of the subaccount"
  type        = string
  default     = "DEV"

  validation {
    condition     = contains(["DEV", "TEST", "PROD"], var.subaccount_stage)
    error_message = "Stage must be one of DEV, TEST or PROD"
  }
}

# Benutzerkennung für die Cloud-Foundry-Space-Manager-Rolle.
# Space Manager verwalten z. B. Space-Mitgliedschaften und Rollen.
# sensitive = true blendet den Variablenwert in gewöhnlichen Ausgaben aus,
# verschlüsselt ihn aber NICHT automatisch im Terraform State.
variable "cf_space_manager" {
  description = "The Cloud Foundry space manager"
  type        = string
  sensitive   = true
}

# Benutzerkennung für die Space-Developer-Rolle.
# Space Developer können Anwendungen und Services innerhalb des Spaces
# bereitstellen/verwalten. Die konkrete Berechtigung hängt vom CF-RBAC ab.
# Auch dieser sensitive-Wert kann im State vorhanden sein.
variable "cf_space_developer" {
  description = "The Cloud Foundry space developer"
  type        = string
  sensitive   = true
}

# URL des übergeordneten SAP-BTP-Subaccounts.
# Wird NICHT zum Provisionieren genutzt, sondern nur für den praktischen
# Output-Link zum Cloud-Foundry-Space (CloudFoundry/outputs.tf).
variable "subaccount_url" {
  description = "The SAP BTP subaccount URL"
  type        = string
}
