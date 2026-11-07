variable "landing_zone_config_file" {
  description = "Versioned YAML relative to this BTP root; never a credentials file."
  type        = string
  default     = "landing-zone.yaml"
  validation {
    condition     = var.landing_zone_config_file == "landing-zone.yaml"
    error_message = "All deployment roots must use the versioned BTP/landing-zone.yaml contract. Alternative paths are prohibited."
  }
}

variable "configuration_mode" {
  description = "compatibility checks old HCP inputs against YAML; yaml requires removal of additional_subaccounts."
  type        = string
  default     = "compatibility"
  validation {
    condition     = contains(["compatibility", "yaml"], var.configuration_mode)
    error_message = "configuration_mode must be compatibility or yaml."
  }
}

module "landing_zone_config" {
  source            = "./modules/landing-zone-config"
  configuration     = yamldecode(file("${path.module}/${var.landing_zone_config_file}"))
  raw_configuration = yamldecode(file("${path.module}/${var.landing_zone_config_file}"))
}

locals {
  configuration = module.landing_zone_config.configuration
  project_name  = local.configuration.project_name
  dev           = local.configuration.environments["DEV"]
  additional_environments = {
    for stage, env in local.configuration.environments : stage => env
    if stage != "DEV" && env.enabled
  }
  additional_subaccounts = {
    for stage, env in local.additional_environments : stage => {
      region     = coalesce(env.region, module.region_catalog.regions[stage])
      costcenter = env.costcenter
    }
  }
  dev_administrators = local.dev.administrators_source == "legacy" ? toset(var.subaccount_emergency_admins) : local.dev.administrators
  legacy_inputs_match = (
    var.project_name == local.project_name && var.subaccount_stage == "DEV" &&
    var.subaccount_region == module.region_catalog.regions["DEV"] && var.project_costcenter == local.dev.costcenter &&
    (var.cf_landscape_label == "" || var.cf_landscape_label == local.dev.cloud_foundry.landscape_label)
  )
  additional_inputs_match = var.configuration_mode == "yaml" ? length(var.additional_subaccounts) == 0 : (
    length(var.additional_subaccounts) == 0 || var.additional_subaccounts == tomap(local.additional_subaccounts)
  )
}

# The resource/subaccount stays at btp_subaccount.additional[stage].
# Only the newly added environment contents are modularized.
module "environment" {
  for_each = local.additional_environments
  source   = "./modules/btp-environment"

  subaccount_id           = btp_subaccount.additional[each.key].id
  name_prefix             = lower(replace("${each.key}-${local.project_name}", " ", "-"))
  cf_org_name             = btp_subaccount.additional[each.key].subdomain
  configuration           = each.value
  selection               = module.service_selection[each.key].selection
  catalog_valid           = module.service_catalog.valid
  instance_parameters     = { for key, value in var.instance_parameters : trimprefix(key, "${each.key}/") => value if startswith(key, "${each.key}/") }
  subscription_parameters = { for key, value in var.subscription_parameters : trimprefix(key, "${each.key}/") => value if startswith(key, "${each.key}/") }
  environment_parameters  = { for key, value in var.environment_parameters : trimprefix(key, "${each.key}/") => value if startswith(key, "${each.key}/") }
}

# Existing DEV baseline addresses are never wrapped in count/for_each.
# This module can add Work Zone or a Feature Flags instance without owning the legacy resources.
module "dev_optional_services" {
  source                  = "./modules/environment-services"
  subaccount_id           = btp_subaccount.project_subaccount.id
  name_prefix             = lower(replace("DEV-${local.project_name}", " ", "-"))
  selection               = module.service_selection["DEV"].selection
  catalog_valid           = module.service_catalog.valid
  instance_parameters     = { for key, value in var.instance_parameters : trimprefix(key, "DEV/") => value if startswith(key, "DEV/") }
  subscription_parameters = { for key, value in var.subscription_parameters : trimprefix(key, "DEV/") => value if startswith(key, "DEV/") }
  existing_dev_baseline   = true
  depends_on              = [module.srvc_baseline]
}

output "landing_zone_subaccounts" {
  description = "Non-secret IDs for all enabled environments; DEV retains its original resource."
  value = merge(
    { DEV = btp_subaccount.project_subaccount.id },
    { for stage, subaccount in btp_subaccount.additional : stage => subaccount.id }
  )
}

output "landing_zone_configuration_fingerprint" {
  description = "Diagnostic hash of all desired configuration; CF routing uses scoped per-environment handoff fingerprints."
  value       = sha256(jsonencode(local.configuration))
}

# Preserve the published bootstrap DEV contract; add only YAML-enabled CF environments.
output "cloud_foundry_environments" {
  description = "Output-only handoff to isolated CF workspaces. No credentials or whole-state sharing required."
  value = merge(
    {
      DEV = {
        api_url              = jsondecode(btp_subaccount_environment_instance.cloudfoundry.labels)["API Endpoint"]
        org_id               = jsondecode(btp_subaccount_environment_instance.cloudfoundry.labels)["Org ID"]
        contract_fingerprint = module.landing_zone_config.handoff_fingerprints["DEV"]
      }
    },
    { for stage, env in module.environment : stage => merge(env.cloud_foundry, { contract_fingerprint = module.landing_zone_config.handoff_fingerprints[stage] }) if local.additional_environments[stage].cloud_foundry.enabled }
  )
}

variable "instance_parameters" {
  type        = map(string)
  sensitive   = true
  default     = {}
  description = "Sensitive JSON strings by STAGE/key; never stored in YAML."
}
variable "subscription_parameters" {
  type      = map(string)
  sensitive = true
  default   = {}
}
variable "environment_parameters" {
  type      = map(string)
  sensitive = true
  default   = {}
}
module "region_catalog" {
  source       = "./modules/region-catalog"
  environments = local.configuration.environments
  account_type = local.configuration.account_type
}
module "service_selection" {
  for_each              = { for stage, env in local.configuration.environments : stage => env if env.enabled }
  source                = "./modules/service-selection"
  services              = each.value.services
  catalog               = local.configuration.service_catalog
  name_prefix           = lower(replace("${each.key}-${local.project_name}", " ", "-"))
  existing_dev_baseline = each.key == "DEV"
}
module "dev_full_selection" {
  source                = "./modules/service-selection"
  services              = local.dev.services
  catalog               = local.configuration.service_catalog
  name_prefix           = lower(replace("DEV-${local.project_name}", " ", "-"))
  existing_dev_baseline = false
}
module "service_catalog" {
  source           = "./modules/service-catalog"
  environments     = local.configuration.environments
  regions          = module.region_catalog.regions
  globalaccount_id = data.btp_globalaccount.current.id
  subaccount_ids   = merge({ DEV = btp_subaccount.project_subaccount.id }, { for stage, subaccount in btp_subaccount.additional : stage => subaccount.id })
  entitlements     = { for stage, selection in module.service_selection : stage => stage == "DEV" ? module.dev_full_selection.selection.entitlements : selection.selection.entitlements }
}

module "dev_role_assignments" {
  source        = "./modules/role-assignments"
  subaccount_id = btp_subaccount.project_subaccount.id
  assignments   = local.dev.role_assignments
  reserved_assignments = [for user in local.dev_administrators : {
    role_collection_name = local.dev.administrator_options.role_collection_name
    user_name            = user
    origin               = local.dev.administrator_options.origin
  }]
}
