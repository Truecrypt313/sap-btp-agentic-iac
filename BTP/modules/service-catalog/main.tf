terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "~> 1.27.0"
    }
  }
}
variable "environments" { type = any }
variable "regions" { type = map(string) }
variable "subaccount_ids" { type = map(string) }
variable "entitlements" { type = any }
variable "globalaccount_id" { type = string }
variable "directory_ids" {
  description = "Optional stable lookup keys for newly created project directories; null preserves legacy ID keys."
  type        = map(string)
  default     = null
}

data "btp_globalaccount_entitlements_with_data_centers" "available" {}

locals {
  stages = { for stage, entries in var.entitlements : stage => entries if length(entries) > 0 }
  directories = toset([
    for stage in keys(local.stages) : var.environments[stage].parent_id
    if var.environments[stage].parent_id != null && var.environments[stage].parent_id != var.globalaccount_id
  ])
}

data "btp_directory_entitlements" "available" {
  for_each     = var.directory_ids == null ? { for id in local.directories : id => id } : var.directory_ids
  directory_id = each.value
}
data "btp_subaccount_entitlements" "current" {
  for_each      = local.stages
  subaccount_id = var.subaccount_ids[each.key]
}

module "rules" {
  source              = "../service-catalog-rules"
  environments        = var.environments
  regions             = var.regions
  entitlements        = var.entitlements
  globalaccount_id    = var.globalaccount_id
  global_catalog      = data.btp_globalaccount_entitlements_with_data_centers.available.values
  directory_catalog   = { for key, directory in data.btp_directory_entitlements.available : (var.directory_ids == null ? key : var.directory_ids[key]) => directory.values }
  current_allocations = { for stage, subaccount in data.btp_subaccount_entitlements.current : stage => subaccount.values }
}
output "valid" { value = module.rules.valid }
