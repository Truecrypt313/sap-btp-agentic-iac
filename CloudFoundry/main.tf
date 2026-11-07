# ============================================================================
# CloudFoundry | main.tf – Space anlegen und Space-Mitgliedschaften verwalten
# ============================================================================
# Voraussetzung: Das BTP-Projekt hat bereits ein Cloud-Foundry-Environment
# mit einer Organisation bereitgestellt. Die Organisations-ID wird als
# Variable cf_org_id übergeben. Dieser Root-Ordner hat einen eigenen State.
#
# Reihenfolge: Space erstellen -> Rollen für Benutzer in diesem Space anlegen.
# Die Abhängigkeit entsteht automatisch über die Space-ID-Referenzen.

# Cloud-Foundry-Space als Arbeitsbereich innerhalb einer CF-Organisation.
# Hierhin werden später Anwendungen und servicegebundene Ressourcen deployed.
# Die Benennung nutzt Stage + Projektname, vereinheitlicht in Kleinbuchstaben
# und mit Bindestrichen: DEV + Project ABC -> dev-project-abc.
resource "cloudfoundry_space" "project_space" {
  name = local.dev_configuration.cloud_foundry.spaces["project"].name
  # Ziel ist die vorhandene CF-ORG; Terraform erstellt hier KEINE neue Org.
  org               = var.cf_org_id
  allow_ssh         = local.dev_configuration.cloud_foundry.spaces["project"].allow_ssh
  isolation_segment = local.dev_configuration.cloud_foundry.spaces["project"].isolation_segment
  labels            = local.dev_configuration.cloud_foundry.spaces["project"].labels
  annotations       = local.dev_configuration.cloud_foundry.spaces["project"].annotations

  lifecycle {
    prevent_destroy = true
    precondition {
      condition = (
        var.subaccount_stage == "DEV" &&
        var.project_name == module.landing_zone_config.configuration.project_name &&
        local.dev_configuration.enabled && local.dev_configuration.cloud_foundry.enabled &&
        length(local.dev_configuration.cloud_foundry.spaces["project"].managers) == 0 &&
        length(local.dev_configuration.cloud_foundry.spaces["project"].developers) == 0
      )
      error_message = "This workspace owns legacy DEV only. Existing project-space roles remain in HCP variables; use separate workspaces for TEST/PROD."
    }
    precondition {
      condition     = local.dev_configuration.cloud_foundry.spaces["project"].name == lower(replace("DEV-${var.project_name}", " ", "-"))
      error_message = "Renaming the existing DEV space requires a separate reviewed plan."
    }
  }
}

# Rollenzuweisung 1: Space Manager.
# Damit darf der genannte Benutzer Space-Mitgliedschaften verwalten.
# Die Rolle gilt nur für den referenzierten Space (nicht als BTP-Global-Admin).
resource "cloudfoundry_space_role" "space_manager" { #Benutzer und Rollen verwalten
  username = local.dev_configuration.cloud_foundry.spaces["project"].legacy_manager == null ? var.cf_space_manager : local.dev_configuration.cloud_foundry.spaces["project"].legacy_manager.username
  user     = try(local.dev_configuration.cloud_foundry.spaces["project"].legacy_manager.user, null)
  origin   = try(local.dev_configuration.cloud_foundry.spaces["project"].legacy_manager.origin, null)
  type     = "space_manager"
  # Referenz auf die ID des eben verwalteten Spaces: implizite Abhängigkeit.
  # Terraform benötigt hier keinen manuell eingetragenen Space-Identifier.
  space = cloudfoundry_space.project_space.id
}

# Rollenzuweisung 2: Space Developer.
# Erlaubt u. a. das Deployen und Verwalten von Anwendungen im Space.
# Beiden Rollen kann derselbe Benutzer zugeordnet sein.
resource "cloudfoundry_space_role" "space_developer" { #Anwendungen deployen
  username = local.dev_configuration.cloud_foundry.spaces["project"].legacy_developer == null ? var.cf_space_developer : local.dev_configuration.cloud_foundry.spaces["project"].legacy_developer.username
  user     = try(local.dev_configuration.cloud_foundry.spaces["project"].legacy_developer.user, null)
  origin   = try(local.dev_configuration.cloud_foundry.spaces["project"].legacy_developer.origin, null)
  type     = "space_developer"
  # Auch diese Rolle hängt vom bestehenden cloudfoundry_space ab.
  space = cloudfoundry_space.project_space.id
}
