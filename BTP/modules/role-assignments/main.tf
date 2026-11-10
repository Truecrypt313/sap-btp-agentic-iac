terraform {
  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "~> 1.27.0"
    }
  }
}
variable "subaccount_id" { type = string }
variable "assignments" {
  type = map(object({
    role_collection_name = optional(string)
    role_collection_key  = optional(string)
    user_name            = optional(string)
    group_name           = optional(string)
    attribute_name       = optional(string)
    attribute_value      = optional(string)
    origin               = optional(string)
  }))
  validation {
    condition = alltrue([for assignment in values(var.assignments) :
      (assignment.role_collection_name != null) != (assignment.role_collection_key != null) &&
      (assignment.role_collection_key == null ?
        !contains(values(var.managed_collections), assignment.role_collection_name == null ? "" : assignment.role_collection_name) :
        contains(keys(var.managed_collections), assignment.role_collection_key) && assignment.origin != null
      ) &&
      length(compact([assignment.user_name, assignment.group_name, assignment.attribute_name])) == 1 &&
      (assignment.group_name == null || assignment.origin != null) &&
      (assignment.attribute_name == null || (assignment.attribute_value != null && assignment.origin != null)) &&
      (assignment.attribute_value == null || assignment.attribute_name != null)
    ])
    error_message = "Use one external collection name or an existing managed collection key with explicit origin, and exactly one valid user/group/attribute subject. Managed collections must be referenced by key."
  }
}

variable "managed_collections" {
  description = "Names passed directly from role-collection resource outputs, never reconstructed from YAML."
  type        = map(string)
  default     = {}
}
variable "reserved_assignments" {
  type = list(object({
    role_collection_name = string
    user_name            = optional(string)
    group_name           = optional(string)
    attribute_name       = optional(string)
    attribute_value      = optional(string)
    origin               = optional(string)
  }))
  default = []
}

data "btp_subaccount_role_collection" "available" {
  for_each      = { for key, assignment in var.assignments : key => assignment if assignment.role_collection_key == null }
  subaccount_id = var.subaccount_id
  name          = each.value.role_collection_name
}

locals {
  collection_names = {
    for key, assignment in var.assignments : key => assignment.role_collection_key == null ?
    data.btp_subaccount_role_collection.available[key].name :
    lookup(var.managed_collections, assignment.role_collection_key, "invalid-managed-reference")
  }
}

resource "btp_subaccount_role_collection_assignment" "this" {
  for_each = var.assignments

  subaccount_id        = var.subaccount_id
  role_collection_name = local.collection_names[each.key]
  user_name            = each.value.user_name
  group_name           = each.value.group_name
  attribute_name       = each.value.attribute_name
  attribute_value      = each.value.attribute_value
  origin               = each.value.origin

  lifecycle {
    precondition {
      condition = length([
        for other_key, other in var.assignments : other if
        local.collection_names[other_key] == local.collection_names[each.key] &&
        other.user_name == each.value.user_name && other.group_name == each.value.group_name &&
        other.attribute_name == each.value.attribute_name && other.attribute_value == each.value.attribute_value &&
        coalesce(other.origin, "ldap") == coalesce(each.value.origin, "ldap")
        ]) == 1 && length([for reserved in var.reserved_assignments : reserved if
        reserved.role_collection_name == local.collection_names[each.key] &&
        reserved.user_name == each.value.user_name && reserved.group_name == each.value.group_name &&
        reserved.attribute_name == each.value.attribute_name && reserved.attribute_value == each.value.attribute_value &&
        coalesce(reserved.origin, "ldap") == coalesce(each.value.origin, "ldap")
      ]) == 0
      error_message = "Duplicate role assignment, including an administrator already owned by the legacy resource."
    }
  }
}
