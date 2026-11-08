terraform {
  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "~> 1.27.0"
    }
  }
}
variable "subaccount_id" { type = string }
variable "assignments" { type = any }
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
  for_each      = var.assignments
  subaccount_id = var.subaccount_id
  name          = each.value.role_collection_name
}

resource "btp_subaccount_role_collection_assignment" "this" {
  for_each = var.assignments

  subaccount_id        = var.subaccount_id
  role_collection_name = each.value.role_collection_name
  user_name            = each.value.user_name
  group_name           = each.value.group_name
  attribute_name       = each.value.attribute_name
  attribute_value      = each.value.attribute_value
  origin               = each.value.origin
  depends_on           = [data.btp_subaccount_role_collection.available]

  lifecycle {
    precondition {
      condition = length([
        for other in values(var.assignments) : other if
        other.role_collection_name == each.value.role_collection_name &&
        other.user_name == each.value.user_name && other.group_name == each.value.group_name &&
        other.attribute_name == each.value.attribute_name && other.attribute_value == each.value.attribute_value &&
        coalesce(other.origin, "ldap") == coalesce(each.value.origin, "ldap")
        ]) == 1 && length([for reserved in var.reserved_assignments : reserved if
        reserved.role_collection_name == each.value.role_collection_name &&
        reserved.user_name == each.value.user_name && reserved.group_name == each.value.group_name &&
        reserved.attribute_name == each.value.attribute_name && reserved.attribute_value == each.value.attribute_value &&
        coalesce(reserved.origin, "ldap") == coalesce(each.value.origin, "ldap")
      ]) == 0
      error_message = "Duplicate role assignment, including an administrator already owned by the legacy resource."
    }
  }
}
