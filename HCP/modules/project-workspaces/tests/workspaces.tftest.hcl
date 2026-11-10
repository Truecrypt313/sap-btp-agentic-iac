mock_provider "tfe" {
  override_during = plan
  mock_resource "tfe_workspace" { defaults = { id = "ws-1111111111111111" } }
}
variables {
  enabled = true
  projects = {
    alpha = { account_profile = "trial", environments = ["DEV", "TEST"], cf_environments = ["DEV", "TEST"] }
    beta  = { account_profile = "trial", environments = ["DEV"], cf_environments = [] }
  }
  vcs_auth = { oauth_token_id = "ot-1111111111111111" }
  account_bindings = {
    trial = { btp_variable_set_ids = ["varset-1111111111111111"], cf_variable_set_ids = ["varset-2222222222222222"] }
  }
}
run "project_scoped_workspaces_tags_vcs_and_routes" {
  command = plan
  assert {
    condition = toset(values(output.workspace_names)) == toset(["sap-btp-alpha-core", "sap-btp-alpha-cf-dev", "sap-btp-alpha-cf-test", "sap-btp-beta-core"]) && alltrue([
      for key, w in tfe_workspace.project : !w.auto_apply && !w.auto_apply_run_trigger && !w.allow_destroy_plan && !w.force_delete && !w.queue_all_runs && w.terraform_version == "1.15.5" && w.vcs_repo[0].branch == "main" && w.vcs_repo[0].identifier == "Truecrypt313/sap-btp-agentic-iac"
    ])
    error_message = "Create only isolated desired workspaces, pinned main/VCS/version, with all automatic apply/destroy/start paths off."
  }
  assert {
    condition     = tfe_workspace.project["alpha/core"].working_directory == "BTP/projects" && contains(tfe_workspace.project["alpha/core"].tag_names, "landing-zone-project-btp") && tfe_workspace.project["alpha/cf/DEV"].working_directory == "CloudFoundry/projects" && contains(tfe_workspace.project["alpha/cf/DEV"].tag_names, "landing-zone-project-cf")
    error_message = "Working directories and HCP cloud-block tags must match the existing generic roots."
  }
}
run "routing_and_credentials_are_references_only" {
  command = plan
  assert {
    condition     = length(tfe_variable.routing) == 6 && tfe_variable.routing["alpha/core/project_id"].value == "alpha" && tfe_variable.routing["alpha/cf/TEST/environment"].value == "TEST" && alltrue([for v in tfe_variable.routing : v.category == "terraform" && !v.hcl && !v.sensitive]) && length(tfe_workspace_variable_set.credentials) == 4 && tfe_workspace_variable_set.credentials["alpha/core/varset-1111111111111111"].variable_set_id == "varset-1111111111111111" && tfe_workspace_variable_set.credentials["alpha/cf/DEV/varset-2222222222222222"].variable_set_id == "varset-2222222222222222"
    error_message = "Only public project/environment inputs and existing variable-set attachments, never credential values."
  }
}
run "disabled_bootstrap_has_no_managed_objects" {
  command = plan
  variables { enabled = false }
  assert {
    condition     = length(tfe_workspace.project) == 0 && length(tfe_variable.routing) == 0 && length(tfe_workspace_variable_set.credentials) == 0
    error_message = "Default rollout-off mode must not touch HCP."
  }
}
run "reject_legacy_project" {
  command = plan
  variables { projects = { project-abc = { account_profile = "trial", environments = ["DEV"], cf_environments = [] } } }
  expect_failures = [var.projects]
}
run "reject_trial_prod" {
  command = plan
  variables { projects = { alpha = { account_profile = "trial", environments = ["PROD"], cf_environments = [] } } }
  expect_failures = [var.projects]
}
run "reject_unselected_cf_stage" {
  command = plan
  variables { projects = { alpha = { account_profile = "trial", environments = ["DEV"], cf_environments = ["TEST"] } } }
  expect_failures = [var.projects]
}
run "reject_ambiguous_vcs_authorization" {
  command = plan
  variables { vcs_auth = { oauth_token_id = "ot-1111111111111111", github_app_installation_id = "ghain-1111111111111111" } }
  expect_failures = [var.vcs_auth]
}
run "github_app_reference_is_supported" {
  command = plan
  variables { vcs_auth = { github_app_installation_id = "ghain-1111111111111111" } }
  assert {
    condition     = tfe_workspace.project["alpha/core"].vcs_repo[0].github_app_installation_id == "ghain-1111111111111111" && tfe_workspace.project["alpha/core"].vcs_repo[0].oauth_token_id == null
    error_message = "An existing GitHub App authorization must be usable without per-project OAuth."
  }
}
run "reject_missing_cf_credential_set" {
  command = plan
  variables {
    account_bindings = { trial = { btp_variable_set_ids = ["varset-1111111111111111"], cf_variable_set_ids = [] } }
  }
  expect_failures = [var.account_bindings]
}
run "outputs_handoff_does_not_grant_full_state_sharing" {
  command = plan
  assert {
    condition = alltrue([for s in tfe_workspace_settings.project :
      s.execution_mode == "remote" && !s.global_remote_state && !s.project_remote_state && length(s.remote_state_consumer_ids) == 0
    ])
    error_message = "Core and CF must use the Outputs API without any full-state consumer grants."
  }
}
