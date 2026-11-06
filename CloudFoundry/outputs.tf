# ============================================================================
# CloudFoundry | outputs.tf – Link für die Übergabe an das Entwicklerteam
# ============================================================================
# Der Output liefert eine direkt verwendbare Cockpit-URL zum CF-Space.
# Nützlich für Tickets oder eine Übergabe an ein Entwicklungsteam.
# Aufruf: 'terraform output -raw cf_space_url' im Ordner CloudFoundry.

# URL setzt sich zusammen aus:
#   - subaccount_url: vorher aus dem BTP-Projekt übernommen
#   - cf_org_id: ID der CF-Organisation
#   - project_space.id: von Terraform verwaltete Space-ID
# '/applications' öffnet die Anwendungsübersicht innerhalb des Spaces.
# Der Pfad entspricht der Trial-Cockpit-URL aus diesem SAP-Tutorial.
# Weder die URL noch der Output gewähren zusätzliche Zugriffsrechte.
output "cf_space_url" {
  value       = "${var.subaccount_url}/org/${var.cf_org_id}/space/${cloudfoundry_space.project_space.id}/applications"
  description = "The Cloud Foundry space URL"
}
