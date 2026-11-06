# ============================================================================
# CloudFoundry | provider.tf – Cloud-Foundry-Provider
# ============================================================================
# Dieses Terraform-Projekt verwaltet den Cloud-Foundry-SPACE und seine Rollen.
# Der Cloud-Foundry-Provider ist unabhängig vom SAP-BTP-Provider im Ordner BTP.
# Auch die Terraform-State-Dateien der beiden Ordner sind getrennt.
# ZUERST muss der BTP-Subaccount mit CF-Environment/Org existieren.

# Legt Provider-Quelle und -Version fest; hier exakt Version 1.18.0.
# Die .terraform.lock.hcl hält die aufgelösten Provider-Prüfsummen fest.
terraform {
  required_providers {
    cloudfoundry = {
      source  = "cloudfoundry/cloudfoundry"
      version = "1.18.0"
    }
  }
}

# Verbindet Terraform mit dem API-Endpunkt der CF-Umgebung.
# Die URL kommt aus CloudFoundry/terraform.tfvars und wurde zuvor als
# BTP-Output 'cf_api_url' aus dem anderen Root-Modul ausgelesen.
# Zugangsdaten werden separat über CF_USER / CF_PASSWORD in der vorhandenen
# Dev-Container-Umgebung bereitgestellt – keine Passwörter hier speichern.
provider "cloudfoundry" {
  api_url = var.cf_api_url
}
