# Own state. Never use a Project ABC workspace or provider credentials here.
terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  cloud {
    organization = "sap-ai-landing-zone"
    workspaces { name = "sap-btp-project-bootstrap" }
  }
  required_providers {
    tfe = { source = "hashicorp/tfe", version = "0.83.0" }
  }
}
provider "tfe" {}
variable "bootstrap_enabled" {
  type        = bool
  default     = false
  description = "Enable only after the one-time platform setup and explicit bootstrap approval."
}
variable "account_bindings" {
  type    = map(object({ btp_variable_set_ids = set(string), cf_variable_set_ids = set(string) }))
  default = {}
}
locals {
  registry = jsondecode(file("${path.module}/../generated/projects.json"))
}
module "workspaces" {
  source           = "../modules/project-workspaces"
  enabled          = local.bootstrap_active && local.vcs_valid
  projects         = local.registry.projects
  vcs_auth         = local.detected_vcs
  account_bindings = var.account_bindings
}
output "project_workspaces" {
  value = module.workspaces.workspace_names
  precondition {
    condition     = terraform.workspace == "sap-btp-project-bootstrap" && local.registry.schema_version == 1
    error_message = "Use only the dedicated bootstrap workspace and a validated generated registry."
  }
}
output "project_workspace_ids" {
  description = "Public routing IDs, directly from managed resources; no secret values."
  value       = module.workspaces.workspace_ids
}
