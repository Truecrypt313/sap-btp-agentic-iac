# ============================================================================
# BTP | provider.tf – Terraform- und SAP-BTP-Provider-Konfiguration
# ============================================================================
# Diese Datei legt fest, welchen Provider Terraform für die Verwaltung der
# SAP Business Technology Platform verwendet und mit welchem Global Account
# sich dieser verbindet. Die eigentlichen Ressourcen stehen in main.tf und
# teilweise im wiederverwendbaren Modul modules/srvc-baseline.
#
# WICHTIG: Die Provider-Konfiguration gehört zum separaten Terraform-Projekt
# BTP. Der Ordner CloudFoundry besitzt einen eigenen Provider und State.
# Der Provider wird nicht von der BTP-CLI ersetzt; er spricht SAP-BTP-APIs an.
# Der terraform-Block beschreibt die technischen Provider-Anforderungen.
# Er erstellt selbst weder einen Account noch andere Cloud-Ressourcen.
terraform {
  required_providers {
    # Registry-Adresse des Providers: HashiCorp Registry / SAP/btp.
    # '~> 1.27.0' erlaubt kompatible 1.27.x-Versionen, aber keine 1.28.0.
    # Die tatsächlich ausgewählte Version wird zusätzlich in
    # .terraform.lock.hcl festgehalten. Dieses Lockfile nicht von Hand ändern.
    btp = {
      source  = "SAP/btp"
      version = "~> 1.27.0"
    }
  }
}

# Konfiguriert eine konkrete Provider-Instanz für dieses Root-Modul.
# Das Child-Modul srvc-baseline nutzt diese Instanz automatisch mit.
# Anmeldedaten werden in unserer Dev-Container-Umgebung bereitgestellt,
# nicht als Klartext in diesem Block. Credentials niemals einchecken.
provider "btp" {
  # Der Wert stammt aus BTP/terraform.tfvars bzw. einer anderen Variablenquelle.
  # Erwartet wird die SUBDOMAIN des Global Accounts, nicht die Account-ID.
  globalaccount = var.globalaccount
}