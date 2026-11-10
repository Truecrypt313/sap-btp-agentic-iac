terraform { required_version = ">= 1.9.0, < 2.0.0" }

# Pure catalog rules allow full multi-role regression fixtures: Terraform's
# provider mock cannot supply distinct instances of computed nested attributes.
variable "requested" {
  type = map(list(object({
    name                 = string
    role_template_name   = string
    role_template_app_id = string
  })))
}

variable "actual" {
  type = list(object({
    name               = string
    role_template_name = string
    app_id             = string
    attribute_list = optional(list(object({
      value_required   = bool
      attribute_values = optional(set(string), [])
    })), [])
  }))
}

locals {
  matches = {
    for key, roles in var.requested : key => [for requested in roles : [
      for role in var.actual : role if
      role.name == requested.name && role.role_template_name == requested.role_template_name && role.app_id == requested.role_template_app_id
    ]]
  }
}

output "valid" {
  value = { for key, roles in local.matches : key => length(roles) > 0 && alltrue([
    for matches in roles : length(matches) == 1 && alltrue(flatten([for role in matches : [
      for attribute in role.attribute_list : !attribute.value_required || length(attribute.attribute_values) > 0
    ]]))
  ]) }
}
