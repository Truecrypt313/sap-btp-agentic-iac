# One project/environment per state. No resources from the legacy CF roots.
terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  cloud {
    organization = "sap-ai-landing-zone"
    workspaces { tags = ["landing-zone-project-cf"] }
  }
  required_providers {
    cloudfoundry = { source = "cloudfoundry/cloudfoundry", version = "1.18.0" }
    tfe          = { source = "hashicorp/tfe", version = "0.83.0" }
  }
}
variable "project_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]*(-[a-z0-9]+)*$", var.project_id)) && length(var.project_id) <= 40 && var.project_id != "project-abc"
    error_message = "Only a registered, non-legacy project ID is allowed."
  }
}
variable "environment" {
  type = string
  validation {
    condition     = contains(["DEV", "TEST", "PROD"], var.environment)
    error_message = "Choose exactly DEV, TEST or PROD in its own project workspace."
  }
}
locals {
  document = yamldecode(file("${path.module}/../../BTP/generated/${var.project_id}/landing-zone.yaml"))
}
module "project_config" {
  source       = "../../BTP/modules/project-config"
  document     = local.document
  raw_document = local.document
}
locals {
  configuration = module.project_config.configuration
  environment   = local.configuration.environments[var.environment]
  active        = local.document.deployment_enabled && local.environment.enabled && local.environment.cloud_foundry.enabled
  btp_workspace = "sap-btp-${var.project_id}-core"
  cf_workspace  = "sap-btp-${var.project_id}-cf-${lower(var.environment)}"
}
provider "tfe" {}
data "tfe_outputs" "project" {
  count        = local.active ? 1 : 0
  organization = "sap-ai-landing-zone"
  workspace    = local.btp_workspace
}
locals {
  contract = try(data.tfe_outputs.project[0].nonsensitive_values.project_contract, null)
  handoff  = try(local.contract.cloud_foundry_environments[var.environment], null)
  handoff_valid = try(
    local.contract.project_id == var.project_id && local.contract.deployment_enabled &&
    local.contract.btp_workspace == local.btp_workspace &&
    local.handoff.project_id == var.project_id && local.handoff.environment == var.environment &&
    local.handoff.btp_workspace == local.btp_workspace && local.handoff.cf_workspace == local.cf_workspace &&
    local.handoff.contract_fingerprint == module.project_config.handoff_fingerprints[var.environment] &&
    can(regex("^https://[^/]+", local.handoff.api_url)) &&
    can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", local.handoff.org_id)), false
  )
}
provider "cloudfoundry" {
  api_url = local.active && local.handoff_valid ? local.handoff.api_url : "https://api.example.invalid"
}
module "spaces" {
  source = "../modules/spaces"
  # Reject the plan explicitly below; never pass an unverified target to CF.
  org_id = local.active && local.handoff_valid ? local.handoff.org_id : null
  spaces = local.active && local.handoff_valid ? local.environment.cloud_foundry.spaces : {}
}
output "space_ids" {
  value = module.spaces.space_ids
  precondition {
    condition     = local.document.project_id == var.project_id && terraform.workspace == local.cf_workspace
    error_message = "Project, environment and actual HCP workspace must match; never use a legacy/other-project state."
  }
  precondition {
    condition     = !local.active || local.handoff_valid
    error_message = "Require matching project/environment/workspace/fingerprint and published BTP org/API outputs; no cross-project fallback."
  }
}
