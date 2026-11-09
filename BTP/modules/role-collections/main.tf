terraform {
  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "~> 1.27.0"
    }
  }
}

variable "subaccount_id" { type = string }

variable "role_collections" {
  type = map(object({
    name        = string
    description = optional(string)
    roles = map(object({
      name                 = string
      role_template_name   = string
      role_template_app_id = string
    }))
  }))
  default = {}

  validation {
    condition = (
      length(distinct([for collection in values(var.role_collections) : collection.name])) == length(var.role_collections) &&
      alltrue([for collection in values(var.role_collections) :
        trimspace(collection.name) != "" && length(collection.roles) > 0 &&
        length(distinct([for role in values(collection.roles) : jsonencode(role)])) == length(collection.roles) &&
        alltrue([for role in values(collection.roles) : alltrue([
          for value in [role.name, role.role_template_name, role.role_template_app_id] : trimspace(value) != ""
        ])])
      ])
    )
    error_message = "Role collections need unique nonempty names and at least one unique, fully identified role."
  }
}

# Roles must already be exposed by the subscribed application. Read during plan;
# never defer this check behind unrelated entitlement/service changes.
data "btp_subaccount_roles" "available" {
  count         = length(var.role_collections) > 0 ? 1 : 0
  subaccount_id = var.subaccount_id
}

module "catalog_validation" {
  source    = "../role-catalog-rules"
  requested = { for key, collection in var.role_collections : key => values(collection.roles) }
  actual    = length(var.role_collections) > 0 ? data.btp_subaccount_roles.available[0].values : []
}

resource "btp_subaccount_role_collection" "this" {
  for_each = var.role_collections

  subaccount_id = var.subaccount_id
  name          = each.value.name
  description   = each.value.description
  roles         = values(each.value.roles)

  lifecycle {
    precondition {
      condition     = module.catalog_validation.valid[each.key]
      error_message = "Every role must uniquely match the SAP subaccount catalog by name, template and application ID, with required attribute values present. Subscribe the application first."
    }
  }
}

output "collection_names" {
  description = "Resource-backed names for assignments; callers must retain this dependency."
  value       = { for key, collection in btp_subaccount_role_collection.this : key => collection.name }
}
