# One root, one selected environment, one independent HCP state and CF endpoint.
terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  cloud {
    organization = "sap-ai-landing-zone"
    workspaces {
      tags = ["landing-zone-cf"]
    }
  }
  required_providers {
    cloudfoundry = {
      source  = "cloudfoundry/cloudfoundry"
      version = "1.18.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "0.83.0"
    }
  }
}

variable "environment" {
  type        = string
  description = "Select TEST or PROD in its own HCP workspace; DEV remains in sap-cloudfoundry."
  validation {
    condition     = contains(["TEST", "PROD"], var.environment)
    error_message = "This root must never manage DEV; choose TEST or PROD."
  }
}

variable "landing_zone_config_file" {
  type        = string
  description = "Path relative to this root. Must describe exactly the same configuration as sap-btp-core."
  default     = "../../BTP/landing-zone.yaml"
  validation {
    condition     = var.landing_zone_config_file == "../../BTP/landing-zone.yaml"
    error_message = "All deployment roots must use the versioned BTP/landing-zone.yaml contract. Alternative paths are prohibited."
  }
}

variable "workspace_name" {
  type        = string
  description = "Explicit routing guard; set to the name of this isolated HCP workspace."
  validation {
    condition     = var.workspace_name == "sap-cloudfoundry-${lower(var.environment)}"
    error_message = "workspace_name must match sap-cloudfoundry-test/prod and the selected environment."
  }
}

module "landing_zone_config" {
  source            = "../../BTP/modules/landing-zone-config"
  configuration     = yamldecode(file("${path.module}/${var.landing_zone_config_file}"))
  raw_configuration = yamldecode(file("${path.module}/${var.landing_zone_config_file}"))
}

provider "tfe" {}

# Output-only access, no terraform_remote_state/full-state reader.
data "tfe_outputs" "btp" {
  organization = "sap-ai-landing-zone"
  workspace    = "sap-btp-core"
}

locals {
  configuration = module.landing_zone_config.configuration
  environment   = local.configuration.environments[var.environment]
  handoff       = try(data.tfe_outputs.btp.nonsensitive_values.cloud_foundry_environments[var.environment], null)
}

provider "cloudfoundry" {
  api_url = try(local.handoff.api_url, null)
}

module "spaces" {
  source = "../modules/spaces"
  org_id = try(local.handoff.org_id, null)
  spaces = local.environment.enabled && local.environment.cloud_foundry.enabled && local.handoff != null ? local.environment.cloud_foundry.spaces : {}
}

output "space_ids" {
  value = module.spaces.space_ids
  precondition {
    condition = (
      local.environment.enabled && local.environment.cloud_foundry.enabled &&
      local.handoff != null &&
      try(local.handoff.contract_fingerprint, "") == try(module.landing_zone_config.handoff_fingerprints[var.environment], "invalid") &&
      terraform.workspace == var.workspace_name
    )
    error_message = "Enable CF and publish matching BTP outputs/configuration fingerprint first; select the matching sap-cloudfoundry-test/prod workspace, never the existing DEV state."
  }
}
