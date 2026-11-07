variable "landing_zone_config_file" {
  type    = string
  default = "../BTP/landing-zone.yaml"
  validation {
    condition     = var.landing_zone_config_file == "../BTP/landing-zone.yaml"
    error_message = "DEV CF must use the canonical versioned BTP/landing-zone.yaml contract."
  }
}

# Output-only access. No credentials are embedded in the configuration.
data "tfe_outputs" "btp" {
  organization = "sap-ai-landing-zone"
  workspace    = "sap-btp-core"
}

# DEV compatibility root: do not move its three existing resources into a module.
module "landing_zone_config" {
  source            = "../BTP/modules/landing-zone-config"
  configuration     = yamldecode(file("${path.module}/${var.landing_zone_config_file}"))
  raw_configuration = yamldecode(file("${path.module}/${var.landing_zone_config_file}"))
}

locals {
  dev_configuration = module.landing_zone_config.configuration.environments["DEV"]
  dev_handoff       = try(data.tfe_outputs.btp.nonsensitive_values.cloud_foundry_environments.DEV, null)
}

module "additional_dev_spaces" {
  source = "./modules/spaces"
  org_id = var.cf_org_id
  spaces = {
    for key, space in local.dev_configuration.cloud_foundry.spaces : key => space
    if key != "project"
  }
}

module "project_space_roles" {
  source             = "./modules/spaces"
  org_id             = var.cf_org_id
  existing_space_ids = { project = cloudfoundry_space.project_space.id }
  # These two options are implemented only by the two original root resources.
  # Do not pass them into the generic module, which rejects them.
  spaces = { project = merge(local.dev_configuration.cloud_foundry.spaces["project"], {
    legacy_manager = null, legacy_developer = null
  }) }
  reserved_roles = {
    manager = {
      space_key = "project", type = "space_manager"
      username  = local.dev_configuration.cloud_foundry.spaces["project"].legacy_manager == null ? var.cf_space_manager : local.dev_configuration.cloud_foundry.spaces["project"].legacy_manager.username
      user      = try(local.dev_configuration.cloud_foundry.spaces["project"].legacy_manager.user, null)
      origin    = try(local.dev_configuration.cloud_foundry.spaces["project"].legacy_manager.origin, null)
    }
    developer = {
      space_key = "project", type = "space_developer"
      username  = local.dev_configuration.cloud_foundry.spaces["project"].legacy_developer == null ? var.cf_space_developer : local.dev_configuration.cloud_foundry.spaces["project"].legacy_developer.username
      user      = try(local.dev_configuration.cloud_foundry.spaces["project"].legacy_developer.user, null)
      origin    = try(local.dev_configuration.cloud_foundry.spaces["project"].legacy_developer.origin, null)
    }
  }
}

output "dev_handoff_valid" {
  description = "DEV CF refuses an unverified endpoint, organization or BTP identity contract."
  value       = true
  precondition {
    condition = (
      try(local.dev_handoff.org_id, "") == var.cf_org_id &&
      try(local.dev_handoff.api_url, "") == var.cf_api_url &&
      try(local.dev_handoff.contract_fingerprint, "") == module.landing_zone_config.handoff_fingerprints["DEV"]
    )
    error_message = "DEV CF requires published matching BTP handoff outputs: endpoint, organization and identity fingerprint. No fallback to an unverified DEV target."
  }
}
