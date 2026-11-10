terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    tfe = { source = "hashicorp/tfe", version = "0.83.0" }
  }
}
variable "enabled" { type = bool }
variable "projects" {
  type = map(object({ account_profile = string, environments = set(string), cf_environments = set(string) }))
  validation {
    condition = alltrue([for id, p in var.projects :
      can(regex("^[a-z][a-z0-9]*(-[a-z0-9]+)*$", id)) && length(id) <= 40 && id != "project-abc" &&
      p.account_profile == "trial" && length(p.environments) > 0 &&
      length(setsubtract(p.environments, toset(["DEV", "TEST"]))) == 0 && length(setsubtract(p.cf_environments, p.environments)) == 0
    ])
    error_message = "Only registered non-legacy Trial projects and DEV/TEST (CF subset) are supported."
  }
}
variable "vcs_auth" {
  type = object({ oauth_token_id = optional(string), github_app_installation_id = optional(string) })
  validation {
    condition     = !var.enabled || ((var.vcs_auth.oauth_token_id != null) != (var.vcs_auth.github_app_installation_id != null))
    error_message = "Platform setup must supply exactly one existing VCS authorization reference."
  }
}
variable "account_bindings" {
  # References only. Secret values are never read or written by this state.
  type = map(object({
    btp_variable_set_ids = set(string)
    cf_variable_set_ids  = set(string)
  }))
  validation {
    condition = !var.enabled || alltrue([for p in values(var.projects) : try(
      length(var.account_bindings[p.account_profile].btp_variable_set_ids) > 0 &&
      (length(p.cf_environments) == 0 || length(var.account_bindings[p.account_profile].cf_variable_set_ids) > 0) &&
      alltrue([for id in setunion(var.account_bindings[p.account_profile].btp_variable_set_ids, var.account_bindings[p.account_profile].cf_variable_set_ids) : can(regex("^varset-[A-Za-z0-9]+$", id))]), false)
    ])
    error_message = "Each used profile requires existing credential-set IDs; HCP Free needs no additional teams or custom RBAC."
  }
}
locals {
  projects = var.enabled ? var.projects : {}
  workspaces = merge(
    { for id, p in local.projects : "${id}/core" => { project = id, profile = p.account_profile, kind = "core", stage = "", name = "sap-btp-${id}-core" } },
    { for item in flatten([for id, p in local.projects : [for stage in p.cf_environments : {
      key = "${id}/cf/${stage}", project = id, profile = p.account_profile, kind = "cf", stage = stage, name = "sap-btp-${id}-cf-${lower(stage)}"
    }]]) : item.key => { project = item.project, profile = item.profile, kind = item.kind, stage = item.stage, name = item.name } }
  )
  bindings = { for pair in flatten([for key, w in local.workspaces : [
    for id in(w.kind == "core" ? var.account_bindings[w.profile].btp_variable_set_ids : var.account_bindings[w.profile].cf_variable_set_ids) : {
      key = "${key}/${id}", workspace = key, variable_set = id
    }
  ]]) : pair.key => pair }
  variables = merge(
    { for key, w in local.workspaces : "${key}/project_id" => { workspace = key, key = "project_id", value = w.project } },
    { for key, w in local.workspaces : "${key}/environment" => { workspace = key, key = "environment", value = w.stage } if w.kind == "cf" }
  )
}
resource "tfe_workspace" "project" {
  for_each               = local.workspaces
  organization           = "sap-ai-landing-zone"
  name                   = each.value.name
  working_directory      = each.value.kind == "core" ? "BTP/projects" : "CloudFoundry/projects"
  terraform_version      = "1.15.5"
  auto_apply             = false
  auto_apply_run_trigger = false
  allow_destroy_plan     = false
  force_delete           = false
  # No webhook run before inputs and credential attachments exist.
  queue_all_runs        = false
  speculative_enabled   = true
  file_triggers_enabled = true
  tag_names             = [each.value.kind == "core" ? "landing-zone-project-btp" : "landing-zone-project-cf", "project:${each.value.project}"]
  trigger_patterns = each.value.kind == "core" ? [
    "/BTP/generated/${each.value.project}/**", "/BTP/config/service-catalog.yaml", "/BTP/modules/**", "/BTP/projects/**", "/scripts/directory_ownership_preflight.py"
  ] : ["/BTP/generated/${each.value.project}/**", "/BTP/modules/project-config/**", "/BTP/modules/landing-zone-config/**", "/CloudFoundry/projects/**", "/CloudFoundry/modules/**"]
  vcs_repo {
    identifier                 = "Truecrypt313/sap-btp-agentic-iac"
    branch                     = "main"
    oauth_token_id             = var.vcs_auth.oauth_token_id
    github_app_installation_id = var.vcs_auth.github_app_installation_id
  }
  lifecycle { prevent_destroy = true }
}
resource "tfe_workspace_settings" "project" {
  for_each             = local.workspaces
  workspace_id         = tfe_workspace.project[each.key].id
  execution_mode       = "remote"
  global_remote_state  = false
  project_remote_state = false
  # tfe_outputs uses the Outputs API with a user token. No workspace needs
  # another workspace's complete state for the BTP/CF handoff.
  remote_state_consumer_ids = []
  lifecycle { prevent_destroy = true }
}
resource "tfe_variable" "routing" {
  for_each     = local.variables
  workspace_id = tfe_workspace.project[each.value.workspace].id
  key          = each.value.key
  value        = each.value.value
  category     = "terraform"
  hcl          = false
  sensitive    = false
  lifecycle { prevent_destroy = true }
}
resource "tfe_workspace_variable_set" "credentials" {
  for_each        = local.bindings
  workspace_id    = tfe_workspace.project[each.value.workspace].id
  variable_set_id = each.value.variable_set
  lifecycle { prevent_destroy = true }
}
output "workspace_ids" { value = { for key, w in tfe_workspace.project : key => w.id } }
output "workspace_names" { value = { for key, w in local.workspaces : key => w.name } }
