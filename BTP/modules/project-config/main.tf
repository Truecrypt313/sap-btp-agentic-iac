terraform { required_version = ">= 1.9.0, < 2.0.0" }

variable "document" {
  type = object({
    project_id         = string
    deployment_enabled = bool
    directory = object({
      enabled     = bool
      name        = string
      description = optional(string)
      features    = set(string)
    })
    configuration = any
  })
  validation {
    condition = (
      can(regex("^[a-z][a-z0-9]*(-[a-z0-9]+)*$", var.document.project_id)) &&
      length(var.document.project_id) <= 40 && var.document.project_id != "project-abc"
    )
    error_message = "Use a stable project ID (max 40 lowercase characters/digits/hyphens); project-abc is reserved."
  }
  validation {
    condition = (
      contains(var.document.directory.features, "DEFAULT") &&
      length(setsubtract(var.document.directory.features, toset(["DEFAULT", "ENTITLEMENTS", "AUTHORIZATIONS"]))) == 0 &&
      (!contains(var.document.directory.features, "AUTHORIZATIONS") || contains(var.document.directory.features, "ENTITLEMENTS"))
    )
    error_message = "Directory features require DEFAULT; AUTHORIZATIONS requires ENTITLEMENTS."
  }
}

variable "raw_document" {
  type = any
  validation {
    condition = try(
      toset(keys(var.raw_document)) == toset(["project_id", "deployment_enabled", "directory", "configuration"]) &&
      length(setsubtract(toset(keys(var.raw_document.directory)), toset(["enabled", "name", "description", "features"]))) == 0,
      false
    )
    error_message = "Unknown project envelope fields; IAM policies are never part of this contract."
  }
}

module "configuration" {
  source            = "../landing-zone-config"
  configuration     = var.document.configuration
  raw_configuration = var.raw_document.configuration
}

locals {
  project_id    = var.document.project_id
  configuration = module.configuration.configuration
  names_valid = alltrue([for stage, env in local.configuration.environments :
    env.name != null && env.subdomain == "${local.project_id}-${lower(stage)}" &&
    env.cloud_foundry.name == "${local.project_id}-${lower(stage)}" &&
    alltrue([for instance in values(env.services.instances) : startswith(instance.name, "${local.project_id}-${lower(stage)}-")]) &&
    alltrue([for options in [env.services.alert_notification.instance_options, env.services.feature_flags.instance_options] :
      options.name == null ? true : startswith(options.name, "${local.project_id}-${lower(stage)}-")
    ]) &&
    alltrue([for alias in env.services.catalog :
      try(local.configuration.service_catalog[alias].instance.name, null) == null ? true : startswith(local.configuration.service_catalog[alias].instance.name, "${local.project_id}-${lower(stage)}-")
    ])
  ])
  no_legacy = alltrue([for env in values(local.configuration.environments) :
    env.parent_id == null && env.administrators_source == "yaml" &&
    !contains(keys(env.labels), "project_id") && length(env.labels) <= 7 &&
    alltrue([for space in values(env.cloud_foundry.spaces) : space.legacy_manager == null && space.legacy_developer == null])
  ])
}

output "configuration" {
  value = local.configuration
  precondition {
    condition     = local.names_valid && local.no_legacy
    error_message = "Project subdomains/CF names/instance prefixes must be scoped; no external subaccount parents or legacy IAM sources."
  }
}
output "handoff_fingerprints" {
  value = { for stage, fingerprint in module.configuration.handoff_fingerprints : stage => sha256(jsonencode({
    contract_version       = 1
    project_id             = local.project_id
    environment            = stage
    btp_workspace          = "sap-btp-${local.project_id}-core"
    cf_workspace           = "sap-btp-${local.project_id}-cf-${lower(stage)}"
    directory              = var.document.directory
    configuration_contract = fingerprint
  })) if var.document.deployment_enabled }
}
output "fingerprint" { value = sha256(jsonencode(var.document)) }
