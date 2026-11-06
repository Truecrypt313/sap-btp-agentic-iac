# ============================================================================
# BTP | outputs.tf – Rückgabewerte des Infrastruktur-Projekts
# ============================================================================
# 'output' macht Werte aus Ressourcen/Data Sources nach einem Apply über
# 'terraform output' zugänglich. Sie werden zusätzlich im BTP-State geführt.
# Das separate Terraform-Projekt CloudFoundry nutzt cf_api_url und cf_org_id
# als Eingaben in CloudFoundry/terraform.tfvars. Die Projekte teilen sich
# ihren State NICHT automatisch: die Werte werden hier manuell übergeben.
# 'terraform output -raw OUTPUTNAME' gibt einzelne String-Werte direkt aus.

# API-Endpunkt der Cloud-Foundry-Umgebung, z. B. eine api.cf...-URL.
# Die BTP-API liefert Umgebungsdetails im Feld 'labels' als JSON-Text.
# jsondecode() wandelt JSON in ein Objekt; ["API Endpoint"] liest den
# passenden Schlüssel. Der Endpunkt allein enthält keine Zugangsdaten.
output "cf_api_url" {
  value       = jsondecode(btp_subaccount_environment_instance.cloudfoundry.labels)["API Endpoint"]
  description = "The Cloud Foundry API URL"
}

# Technische ID der CF-Organisation aus denselben JSON-Labels.
# Diese ID wird im CloudFoundry-Projekt für das Anlegen des Spaces benötigt.
# Sie ist NICHT die ID des SAP-BTP-Global-Accounts oder Subaccounts.
output "cf_org_id" {
  value       = jsondecode(btp_subaccount_environment_instance.cloudfoundry.labels)["Org ID"]
  description = "The Cloud Foundry organization ID"
}

# Gibt die tatsächlich genutzte Cloud-Foundry-Landschaft zurück.
# Nützlich zur Dokumentation bzw. Kontrolle der Umgebungszuordnung.
output "cf_landscape_label" {
  value       = btp_subaccount_environment_instance.cloudfoundry.landscape_label
  description = "The Cloud Foundry landscape label"
}

# Direkter Cockpit-Link zum erzeugten BTP-Subaccount.
# Zusammengesetzt aus Global-Account-ID und Subaccount-ID.
# Dieser URL-Aufbau gilt für das hier verwendete SAP-BTP-Trial-Cockpit.
# Bei anderen Account-Typen/Cockpit-Varianten muss er ggf. angepasst werden.
# Der Link ist für die Übergabe an das Entwicklerteam gedacht.
output "subaccount_url" {
  value       = "https://account.hanatrial.ondemand.com/trial/#/globalaccount/${data.btp_globalaccount.current.id}/subaccount/${btp_subaccount.project_subaccount.id}"
  description = "The SAP BTP subaccount URL"
}
