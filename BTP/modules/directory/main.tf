terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    btp = { source = "SAP/btp", version = "~> 1.27.0" }
  }
}
variable "project_id" { type = string }
variable "globalaccount_id" { type = string }
variable "create" { type = bool }
variable "name" {
  type = string
  validation {
    condition     = can(regex("^[^/]{1,255}$", var.name))
    error_message = "Directory name must contain 1–255 characters without slash."
  }
}
variable "description" {
  type    = string
  default = null
}
variable "features" {
  type    = set(string)
  default = ["DEFAULT"]
  validation {
    condition     = contains(var.features, "DEFAULT") && length(setsubtract(var.features, toset(["DEFAULT", "ENTITLEMENTS", "AUTHORIZATIONS"]))) == 0 && (!contains(var.features, "AUTHORIZATIONS") || contains(var.features, "ENTITLEMENTS"))
    error_message = "DEFAULT is required; AUTHORIZATIONS requires ENTITLEMENTS; unknown features are forbidden."
  }
}
# IDs come from explicitly configured runtime inputs, never embedded Terraform UUIDs.
variable "parent_id" {
  type    = string
  default = null
  validation {
    condition     = var.parent_id == null ? true : can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.parent_id))
    error_message = "Optional directory parent must be a UUID from the runtime input."
  }
}
variable "existing_id" {
  type    = string
  default = null
  validation {
    condition     = !(var.create && var.existing_id != null)
    error_message = "Create a new directory OR reference an existing project-owned directory."
  }
  validation {
    condition = var.existing_id == null ? true : (
      var.existing_id != var.globalaccount_id && can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.existing_id))
    )
    error_message = "Existing directory ID must be a UUID distinct from the global account."
  }
}
locals {
  lookup_id = var.existing_id != null ? var.existing_id : (var.create ? var.parent_id : null)
}
data "btp_directories" "existing" {
  count = var.create ? 1 : 0
}
module "inventory_rules" {
  source     = "../directory-rules"
  project_id = var.project_id
  name       = var.name
  inventory = [for directory in try(data.btp_directories.existing[0].values, []) : {
    name        = directory.name
    project_ids = try(directory.labels["project_id"], [])
  }]
}
data "btp_directory" "ancestor_0" {
  count = local.lookup_id != null && local.lookup_id != var.globalaccount_id ? 1 : 0
  id    = local.lookup_id
}
data "btp_directory" "ancestor_1" {
  count = try(data.btp_directory.ancestor_0[0].parent_id, null) != null && try(data.btp_directory.ancestor_0[0].parent_id, null) != var.globalaccount_id ? 1 : 0
  id    = try(data.btp_directory.ancestor_0[0].parent_id, null)
}
data "btp_directory" "ancestor_2" {
  count = try(data.btp_directory.ancestor_1[0].parent_id, null) != null && try(data.btp_directory.ancestor_1[0].parent_id, null) != var.globalaccount_id ? 1 : 0
  id    = try(data.btp_directory.ancestor_1[0].parent_id, null)
}
data "btp_directory" "ancestor_3" {
  count = try(data.btp_directory.ancestor_2[0].parent_id, null) != null && try(data.btp_directory.ancestor_2[0].parent_id, null) != var.globalaccount_id ? 1 : 0
  id    = try(data.btp_directory.ancestor_2[0].parent_id, null)
}
data "btp_directory" "ancestor_4" {
  count = try(data.btp_directory.ancestor_3[0].parent_id, null) != null && try(data.btp_directory.ancestor_3[0].parent_id, null) != var.globalaccount_id ? 1 : 0
  id    = try(data.btp_directory.ancestor_3[0].parent_id, null)
}
locals {
  ancestors       = concat(data.btp_directory.ancestor_0, data.btp_directory.ancestor_1, data.btp_directory.ancestor_2, data.btp_directory.ancestor_3, data.btp_directory.ancestor_4)
  enhanced        = [for entry in local.ancestors : entry if contains(entry.features, "ENTITLEMENTS") || contains(entry.features, "AUTHORIZATIONS")]
  create_enhanced = var.create && contains(var.features, "ENTITLEMENTS")
  hierarchy_valid = (
    length(local.ancestors) + (var.create ? 1 : 0) <= 5 &&
    length(distinct([for entry in local.ancestors : entry.id])) == length(local.ancestors) &&
    alltrue([for entry in local.ancestors : length(try(entry.labels["project_id"], [])) == 0 || contains(try(entry.labels["project_id"], []), var.project_id)]) &&
    (length(local.ancestors) == 0 ? true : local.ancestors[length(local.ancestors) - 1].parent_id == var.globalaccount_id) &&
    length(local.enhanced) + (local.create_enhanced ? 1 : 0) <= 1
  )
}
resource "btp_directory" "this" {
  for_each    = var.create ? { project = true } : {}
  name        = var.name
  description = var.description
  features    = var.features
  parent_id   = var.parent_id
  subdomain   = contains(var.features, "AUTHORIZATIONS") ? "${var.project_id}-directory" : null
  labels      = { project_id = [var.project_id] }
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = module.inventory_rules.unique
      error_message = "Directory name/project already exists. Reference its verified existing ID; do not create a duplicate."
    }
    precondition {
      condition     = local.hierarchy_valid
      error_message = "SAP directory paths allow max five levels and only one ENTITLEMENTS/AUTHORIZATIONS directory; parent chain must reach this global account."
    }
  }
}
output "directory_id" {
  value = var.create ? btp_directory.this["project"].id : var.existing_id
  precondition {
    condition = local.hierarchy_valid && (var.existing_id == null ? true : (
      contains(try(data.btp_directory.ancestor_0[0].labels["project_id"], []), var.project_id) &&
      data.btp_directory.ancestor_0[0].name == var.name &&
      data.btp_directory.ancestor_0[0].features == var.features && var.parent_id == null
    ))
    error_message = "Existing directory must belong to this project with matching features/name; never create/import it twice or override its parent."
  }
}
output "quota_managed" { value = local.create_enhanced || length(local.enhanced) > 0 }
output "quota_parent_id" {
  value = local.create_enhanced ? btp_directory.this["project"].id : try(one(local.enhanced).id, var.globalaccount_id)
}
