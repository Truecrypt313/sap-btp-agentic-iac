# Generic future project root. Never initialize against a Project ABC workspace.
terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  cloud {
    organization = "sap-ai-landing-zone"
    workspaces { tags = ["landing-zone-project-btp"] }
  }
  required_providers {
    btp      = { source = "SAP/btp", version = "~> 1.27.0" }
    external = { source = "hashicorp/external", version = "= 2.3.5" }
  }
}
variable "project_id" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]*(-[a-z0-9]+)*$", var.project_id)) && length(var.project_id) <= 40 && var.project_id != "project-abc"
    error_message = "Use a registered, non-legacy project ID, never a path or Project ABC."
  }
}
variable "globalaccount" { type = string }
variable "directory_parent_id" {
  type    = string
  default = null
}
variable "existing_directory_id" {
  type    = string
  default = null
}
variable "instance_parameters" {
  type      = map(string)
  sensitive = true
  default   = {}
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
provider "btp" { globalaccount = var.globalaccount }
locals {
  document = yamldecode(file("${path.module}/../generated/${var.project_id}/landing-zone.yaml"))
}
module "project_config" {
  source       = "../modules/project-config"
  document     = local.document
  raw_document = local.document
}
locals {
  configuration = module.project_config.configuration
  active        = local.document.deployment_enabled
  environments  = { for stage, env in local.configuration.environments : stage => env if local.active && env.enabled }
}
data "btp_globalaccount" "current" { count = local.active ? 1 : 0 }
module "directory" {
  source           = "../modules/directory"
  project_id       = var.project_id
  globalaccount_id = try(data.btp_globalaccount.current[0].id, null)
  create           = local.active && local.document.directory.enabled
  name             = local.document.directory.name
  description      = try(local.document.directory.description, null)
  features         = local.document.directory.features
  parent_id        = local.active ? var.directory_parent_id : null
  existing_id      = local.active ? var.existing_directory_id : null
}
module "region_catalog" {
  for_each     = local.active ? { project = true } : {}
  source       = "../modules/region-catalog"
  environments = local.environments
  account_type = local.configuration.account_type
}
resource "btp_subaccount" "environment" {
  for_each  = local.environments
  name      = each.value.name
  subdomain = each.value.subdomain
  region    = module.region_catalog["project"].regions[each.key]
  # Direct reference to the resource-backed module output, not a YAML UUID.
  parent_id             = module.directory.directory_id
  description           = each.value.description
  usage                 = each.value.usage
  skip_auto_entitlement = each.value.skip_auto_entitlement
  beta_enabled          = each.value.beta_enabled
  labels                = merge(each.value.labels, { stage = [each.key], costcenter = [each.value.costcenter], project_id = [var.project_id] })
  lifecycle { prevent_destroy = true }
}
module "service_selection" {
  for_each              = local.environments
  source                = "../modules/service-selection"
  services              = each.value.services
  catalog               = local.configuration.service_catalog
  name_prefix           = "${var.project_id}-${lower(each.key)}"
  existing_dev_baseline = false
}
module "service_catalog" {
  for_each = local.active ? { project = true } : {}
  source   = "../modules/service-catalog"
  # Quotas inherit from the nearest ENTITLEMENTS ancestor; DEFAULT is structural.
  environments     = { for stage, env in local.environments : stage => merge(env, { parent_id = module.directory.quota_parent_id }) }
  regions          = module.region_catalog["project"].regions
  globalaccount_id = data.btp_globalaccount.current[0].id
  subaccount_ids   = { for stage, subaccount in btp_subaccount.environment : stage => subaccount.id }
  entitlements     = { for stage, selection in module.service_selection : stage => selection.selection.entitlements }
  directory_ids    = module.directory.quota_managed ? { authority = module.directory.quota_parent_id } : {}
}
module "environment" {
  for_each                = local.environments
  source                  = "../modules/btp-environment"
  subaccount_id           = btp_subaccount.environment[each.key].id
  name_prefix             = "${var.project_id}-${lower(each.key)}"
  cf_org_name             = each.value.cloud_foundry.name
  configuration           = each.value
  selection               = module.service_selection[each.key].selection
  catalog_valid           = module.service_catalog["project"].valid
  instance_parameters     = { for key, value in var.instance_parameters : trimprefix(key, "${each.key}/") => value if startswith(key, "${each.key}/") }
  subscription_parameters = { for key, value in var.subscription_parameters : trimprefix(key, "${each.key}/") => value if startswith(key, "${each.key}/") }
  environment_parameters  = { for key, value in var.environment_parameters : trimprefix(key, "${each.key}/") => value if startswith(key, "${each.key}/") }
}
output "project_contract" {
  value = {
    project_id                = var.project_id
    deployment_enabled        = local.active
    btp_workspace             = "sap-btp-${var.project_id}-core"
    configuration_fingerprint = module.project_config.fingerprint
    directory_id              = module.directory.directory_id
    subaccounts               = { for stage, subaccount in btp_subaccount.environment : stage => subaccount.id }
    cloud_foundry_environments = { for stage, environment in module.environment : stage => merge(environment.cloud_foundry, {
      project_id           = var.project_id
      environment          = stage
      btp_workspace        = "sap-btp-${var.project_id}-core"
      cf_workspace         = "sap-btp-${var.project_id}-cf-${lower(stage)}"
      contract_fingerprint = module.project_config.handoff_fingerprints[stage]
    }) if local.environments[stage].cloud_foundry.enabled }
  }
  precondition {
    condition     = local.document.project_id == var.project_id && terraform.workspace == "sap-btp-${var.project_id}-core"
    error_message = "Project ID, generated configuration and actual HCP core workspace must match."
  }
  precondition {
    condition     = !local.active || var.directory_parent_id == null || local.document.directory.enabled
    error_message = "directory_parent_id is only valid when creating a project directory; never move an existing directory."
  }
  precondition {
    condition = !local.active ? true : (
      (local.configuration.account_type == "trial") == (upper(data.btp_globalaccount.current[0].license_type) == "TRIAL")
    )
    error_message = "Project profile must match the authenticated global account."
  }
}
