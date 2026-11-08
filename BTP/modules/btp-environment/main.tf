terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "~> 1.27.0"
    }
  }
}

variable "subaccount_id" {
  type = string
}
variable "name_prefix" {
  type = string
}
variable "cf_org_name" {
  description = "Use the unique subaccount subdomain for the CF organization."
  type        = string
}
variable "configuration" {
  description = "One normalized environment from landing-zone-config."
  type        = any
}
variable "selection" { type = any }
variable "catalog_valid" { type = bool }
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

module "services" {
  source                  = "../environment-services"
  subaccount_id           = var.subaccount_id
  name_prefix             = var.name_prefix
  selection               = var.selection
  catalog_valid           = var.catalog_valid
  instance_parameters     = var.instance_parameters
  subscription_parameters = var.subscription_parameters
}

module "cloud_foundry" {
  for_each = var.configuration.cloud_foundry.enabled ? { primary = var.configuration.cloud_foundry } : {}
  source   = "../cloudfoundry-environment"

  subaccount_id          = var.subaccount_id
  name                   = coalesce(each.value.name, var.cf_org_name)
  configuration          = each.value
  environment_parameters = var.environment_parameters
}

resource "btp_subaccount_role_collection_assignment" "administrators" {
  for_each = var.configuration.administrators

  subaccount_id        = var.subaccount_id
  role_collection_name = var.configuration.administrator_options.role_collection_name
  origin               = var.configuration.administrator_options.origin
  user_name            = each.value
}

module "role_assignments" {
  source        = "../role-assignments"
  subaccount_id = var.subaccount_id
  assignments   = var.configuration.role_assignments
  reserved_assignments = [for user in var.configuration.administrators : {
    role_collection_name = var.configuration.administrator_options.role_collection_name
    user_name            = user
    origin               = var.configuration.administrator_options.origin
  }]
}

output "cloud_foundry" {
  value = try(module.cloud_foundry["primary"].handoff, null)
}

output "service_instance_ids" {
  value = module.services.instance_ids
}
