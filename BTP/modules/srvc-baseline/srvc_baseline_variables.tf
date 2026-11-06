# ============================================================================
# BTP | modules/srvc-baseline/srvc_baseline_variables.tf
# Eingabeschnittstelle des wiederverwendbaren Service-Baseline-Moduls
# ============================================================================
# Child-Module besitzen einen EIGENEN Variablen-Namensraum: var.project_stage
# im Modul ist nicht automatisch dieselbe Variable wie var.subaccount_stage
# im BTP-Root-Modul. Die Werte werden beim Modulaufruf explizit übergeben.
# Ein solches Modul lässt sich dadurch prinzipiell für andere Subaccounts
# mit anderen Projekt- und Stage-Werten wiederverwenden.

# Ziel-Subaccount für Entitlements, Service Instance und Subscription.
# Kein Default: JEDER Aufrufer muss die konkrete Subaccount-ID liefern.
# Der Modulaufruf in BTP/main.tf übergibt die ID der dort erstellten Ressource.
variable "subaccount_id" {
  description = "The subaccount ID"
  type        = string
}

# Wird zusammen mit project_stage verwendet, um einen standardisierten
# Service-Instanznamen zu bilden. Der Default vereinfacht lokale Tests.
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "Project ABC"
}

# Umgebungskürzel für Ressourcennamen, z. B. DEV.
# Die Validierung beschränkt den Wert hier auf DEV, TEST und PROD.
# In BTP/main.tf kommt dieser Wert aus var.subaccount_stage.
variable "project_stage" {
  description = "Stage of the project"
  type        = string
  default     = "DEV"

  validation {
    condition     = contains(["DEV", "TEST", "PROD"], var.project_stage)
    error_message = "Stage must be one of DEV, TEST or PROD"
  }
}
