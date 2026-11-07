variable "landing_zone_config_file" {
  description = "Versioned YAML relative to this BTP root; never a credentials file."
  type        = string
  default     = "landing-zone.yaml"
  validation {
    condition     = var.landing_zone_config_file == "landing-zone.yaml"
    error_message = "All deployment roots must use the versioned BTP/landing-zone.yaml contract. Alternative paths are prohibited."
  }
}

# Identical provider-free configuration module and canonical YAML to PR #2.
# It only normalizes/validates configuration; it does not create resources.
module "landing_zone_config" {
  source            = "./modules/landing-zone-config"
  configuration     = yamldecode(file("${path.module}/${var.landing_zone_config_file}"))
  raw_configuration = yamldecode(file("${path.module}/${var.landing_zone_config_file}"))
}

# Only DEV is published during bootstrap. YAML does not drive any resources yet;
# additional_subaccounts remains owned by the unchanged legacy configuration.
output "cloud_foundry_environments" {
  description = "Output-only DEV handoff compatible with the isolated Cloud Foundry root in PR #2."
  value = {
    DEV = {
      api_url              = jsondecode(btp_subaccount_environment_instance.cloudfoundry.labels)["API Endpoint"]
      org_id               = jsondecode(btp_subaccount_environment_instance.cloudfoundry.labels)["Org ID"]
      contract_fingerprint = module.landing_zone_config.handoff_fingerprints["DEV"]
    }
  }

  precondition {
    condition = (
      var.subaccount_stage == "DEV" &&
      var.project_name == module.landing_zone_config.configuration.project_name &&
      var.subaccount_region == module.landing_zone_config.configuration.environments.DEV.region &&
      module.landing_zone_config.configuration.environments.DEV.enabled &&
      module.landing_zone_config.configuration.environments.DEV.cloud_foundry.enabled &&
      (module.landing_zone_config.configuration.account_type == "trial") == (data.btp_globalaccount.current.license_type == "TRIAL")
    )
    error_message = "Bootstrap requires legacy DEV inputs and the actual account profile to match the canonical YAML."
  }

  precondition {
    condition = (
      btp_subaccount.project_subaccount.name == coalesce(module.landing_zone_config.configuration.environments.DEV.name, "DEV ${module.landing_zone_config.configuration.project_name}") &&
      btp_subaccount.project_subaccount.subdomain == coalesce(module.landing_zone_config.configuration.environments.DEV.subdomain, local.subaccount_subdomain) &&
      (module.landing_zone_config.configuration.environments.DEV.parent_id == null ? true : btp_subaccount.project_subaccount.parent_id == module.landing_zone_config.configuration.environments.DEV.parent_id) &&
      btp_subaccount_environment_instance.cloudfoundry.name == coalesce(module.landing_zone_config.configuration.environments.DEV.cloud_foundry.name, local.subaccount_cf_org) &&
      btp_subaccount_environment_instance.cloudfoundry.service_name == module.landing_zone_config.configuration.environments.DEV.cloud_foundry.service_name &&
      btp_subaccount_environment_instance.cloudfoundry.environment_type == module.landing_zone_config.configuration.environments.DEV.cloud_foundry.environment_type &&
      btp_subaccount_environment_instance.cloudfoundry.plan_name == module.landing_zone_config.configuration.environments.DEV.cloud_foundry.plan &&
      btp_subaccount_environment_instance.cloudfoundry.landscape_label == module.landing_zone_config.configuration.environments.DEV.cloud_foundry.landscape_label &&
      module.landing_zone_config.configuration.environments.DEV.cloud_foundry.parameters_key == null &&
      jsondecode(btp_subaccount_environment_instance.cloudfoundry.parameters) == jsondecode(coalesce(module.landing_zone_config.configuration.environments.DEV.cloud_foundry.parameters, jsonencode({ instance_name = local.subaccount_cf_org })))
    )
    error_message = "The canonical DEV identity must describe the unchanged legacy subaccount/CF environment. Bootstrap cannot migrate identities or resolve runtime parameter references."
  }
}
