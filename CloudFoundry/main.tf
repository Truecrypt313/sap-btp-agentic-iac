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
  name = lower(replace("${var.subaccount_stage}-${var.project_name}", " ", "-"))
  # Ziel ist die vorhandene CF-ORG; Terraform erstellt hier KEINE neue Org.
  org  = var.cf_org_id
}

# Rollenzuweisung 1: Space Manager.
# Damit darf der genannte Benutzer Space-Mitgliedschaften verwalten.
# Die Rolle gilt nur für den referenzierten Space (nicht als BTP-Global-Admin).
resource "cloudfoundry_space_role" "space_manager" { #Benutzer und Rollen verwalten
  username = var.cf_space_manager
  type     = "space_manager"
  # Referenz auf die ID des eben verwalteten Spaces: implizite Abhängigkeit.
  # Terraform benötigt hier keinen manuell eingetragenen Space-Identifier.
  space    = cloudfoundry_space.project_space.id
}

# Rollenzuweisung 2: Space Developer.
# Erlaubt u. a. das Deployen und Verwalten von Anwendungen im Space.
# Beiden Rollen kann derselbe Benutzer zugeordnet sein.
resource "cloudfoundry_space_role" "space_developer" { #Anwendungen deployen
  username = var.cf_space_developer
  type     = "space_developer"
  # Auch diese Rolle hängt vom bestehenden cloudfoundry_space ab.
  space    = cloudfoundry_space.project_space.id
}
