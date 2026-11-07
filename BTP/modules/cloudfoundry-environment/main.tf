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
variable "name" {
  type = string
}
variable "configuration" {
  type = object({
    plan             = string
    landscape_label  = string
    environment_type = string
    service_name     = string
    parameters       = optional(string)
    parameters_key   = optional(string)
    timeouts = optional(object({
      create = optional(string)
      update = optional(string)
      delete = optional(string)
    }))
  })
}
variable "environment_parameters" {
  type      = map(string)
  sensitive = true
  default   = {}
}

data "btp_subaccount_environments" "available" {
  subaccount_id = var.subaccount_id
}

locals {
  candidates = [
    for env in data.btp_subaccount_environments.available.values : env.landscape_label
    if env.service_name == var.configuration.service_name && env.environment_type == var.configuration.environment_type &&
    env.plan_name == var.configuration.plan
  ]
  # Ambiguous catalogs require an explicit landscape; never silently select [0].
  landscape = var.configuration.landscape_label != "" ? var.configuration.landscape_label : try(one(local.candidates), null)
}

resource "btp_subaccount_environment_instance" "this" {
  subaccount_id    = var.subaccount_id
  name             = var.name
  environment_type = var.configuration.environment_type
  service_name     = var.configuration.service_name
  plan_name        = var.configuration.plan
  landscape_label  = local.landscape
  parameters = var.configuration.parameters_key != null ? lookup(var.environment_parameters, var.configuration.parameters_key, null) : (
    var.configuration.parameters != null ? var.configuration.parameters : jsonencode({ instance_name = var.name })
  )
  timeouts = var.configuration.timeouts

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = var.configuration.parameters_key == null ? true : contains(keys(var.environment_parameters), var.configuration.parameters_key)
      error_message = "Missing runtime Cloud Foundry broker parameter reference."
    }
    precondition {
      condition = var.configuration.landscape_label != "" ? (
        contains(local.candidates, var.configuration.landscape_label)
      ) : length(local.candidates) == 1
      error_message = "No unique Cloud Foundry landscape offers the requested plan. Select an available landscape_label explicitly."
    }
  }
}

output "handoff" {
  description = "Non-secret interface for a separate per-environment Cloud Foundry workspace."
  value = {
    api_url = jsondecode(btp_subaccount_environment_instance.this.labels)["API Endpoint"]
    org_id  = jsondecode(btp_subaccount_environment_instance.this.labels)["Org ID"]
  }
}
