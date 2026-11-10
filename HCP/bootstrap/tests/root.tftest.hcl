mock_provider "tfe" {
  mock_data "tfe_workspace" {
    defaults = { vcs_repo = [{ identifier = "Truecrypt313/sap-btp-agentic-iac", github_app_installation_id = "ghain-1111111111111111", oauth_token_id = "" }] }
  }
  mock_data "tfe_github_app_installation" { defaults = { id = "ghain-1111111111111111", installation_id = 12345678 } }
}
run "rollout_disabled_by_default" {
  command = plan
  assert {
    condition     = length(output.project_workspaces) == 0 && length(data.tfe_workspace.vcs_reference) == 0 && length(data.tfe_github_app_installation.repository) == 0 && length(data.tfe_oauth_client.repository) == 0
    error_message = "No live bootstrap without separately enabled platform setup."
  }
}
run "explicit_bootstrap_prepares_only_registered_test_neu" {
  command = plan
  variables {
    bootstrap_enabled = true
    account_bindings  = { trial = { btp_variable_set_ids = ["varset-1111111111111111"], cf_variable_set_ids = ["varset-2222222222222222"] } }
  }
  assert {
    condition     = toset(values(output.project_workspaces)) == toset(["sap-btp-test-neu-core", "sap-btp-test-neu-cf-dev", "sap-btp-test-neu-cf-test"])
    error_message = "Registry/root wiring may prepare only the three requested test-neu workspaces, never legacy workspaces or PROD."
  }
}
