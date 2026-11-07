terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    cloudfoundry = {
      source  = "cloudfoundry/cloudfoundry"
      version = "1.18.0"
    }
  }
}

variable "org_id" {
  type = string
}
variable "existing_space_ids" {
  description = "Internal handoff for role-only extension of already-owned spaces; never import or create those spaces here."
  type        = map(string)
  default     = {}
}
variable "reserved_roles" {
  description = "Existing role identities owned by the caller; used only for duplicate checks, never as for_each keys."
  type        = any
  sensitive   = true
  default     = {}
}
variable "spaces" {
  type = map(object({
    name              = string
    allow_ssh         = optional(bool)
    isolation_segment = optional(string)
    labels            = optional(map(string))
    annotations       = optional(map(string))
    managers          = optional(set(string), [])
    developers        = optional(set(string), [])
    member_origin     = optional(string)
    roles = optional(map(object({
      type     = string
      user     = optional(string)
      username = optional(string)
      origin   = optional(string)
    })), {})
    legacy_manager = optional(object({
      user     = optional(string)
      username = optional(string)
      origin   = optional(string)
    }))
    legacy_developer = optional(object({
      user     = optional(string)
      username = optional(string)
      origin   = optional(string)
    }))
  }))
  validation {
    condition     = alltrue([for space in values(var.spaces) : space.legacy_manager == null && space.legacy_developer == null])
    error_message = "legacy_manager/legacy_developer are supported only by the original DEV/project root resources. Use managers, developers or roles here."
  }
}

locals {
  roles = merge({}, [
    for key, space in var.spaces : merge(
      { for user in space.managers : "${key}/manager/${user}" => { space_key = key, username = user, type = "space_manager", user = null, origin = space.member_origin } },
      { for user in space.developers : "${key}/developer/${user}" => { space_key = key, username = user, type = "space_developer", user = null, origin = space.member_origin } },
      { for role_key, role in space.roles : "${key}/role/${role_key}" => merge(role, { space_key = key }) }
    )
  ]...)
}

resource "cloudfoundry_space" "this" {
  for_each = { for key, space in var.spaces : key => space if !contains(keys(var.existing_space_ids), key) }

  name              = each.value.name
  org               = var.org_id
  allow_ssh         = each.value.allow_ssh
  isolation_segment = each.value.isolation_segment
  labels            = each.value.labels
  annotations       = each.value.annotations

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = length(distinct([for space in values(var.spaces) : space.name])) == length(var.spaces)
      error_message = "Space names must be unique within the target organization."
    }
  }
}

resource "cloudfoundry_space_role" "this" {
  for_each = local.roles

  username = each.value.username
  user     = each.value.user
  origin   = each.value.origin
  type     = each.value.type
  space    = merge(var.existing_space_ids, { for key, space in cloudfoundry_space.this : key => space.id })[each.value.space_key]
  lifecycle {
    precondition {
      condition = length([for role in values(var.reserved_roles) : role if
        role.space_key == each.value.space_key && role.type == each.value.type &&
        role.user == each.value.user && role.username == each.value.username && role.origin == each.value.origin
      ]) == 0
      error_message = "This role is already owned by the calling legacy configuration."
    }
    precondition {
      condition     = length(compact([each.value.user, each.value.username])) == 1 && (each.value.origin == null || each.value.username != null)
      error_message = "Exactly one of user/username is required; origin is allowed only with username."
    }
    precondition {
      condition     = length([for role in values(local.roles) : role if role.space_key == each.value.space_key && role.type == each.value.type && role.user == each.value.user && role.username == each.value.username && role.origin == each.value.origin]) == 1
      error_message = "Simple memberships and explicit roles must not assign the same subject/type/origin twice."
    }
  }
}

output "space_ids" {
  value = merge(var.existing_space_ids, { for key, space in cloudfoundry_space.this : key => space.id })
}
