mock_provider "tfe" {}
run "rollout_disabled_by_default" {
  command = plan
  assert {
    condition     = length(output.project_workspaces) == 0
    error_message = "No live bootstrap without separately enabled platform setup."
  }
}
run "explicit_bootstrap_prepares_only_registered_test_neu" {
  command = plan
  variables {
    operator_teams    = { plan = "team-3333333333333333", core_apply = "team-4444444444444444", cf_apply = "team-5555555555555555" }
    bootstrap_enabled = true
    vcs_auth          = { oauth_token_id = "ot-1111111111111111" }
    account_bindings  = { trial = { btp_variable_set_ids = ["varset-1111111111111111"], cf_variable_set_ids = ["varset-2222222222222222"], directory_reader_team_id = "team-1111111111111111", output_reader_team_id = "team-2222222222222222" } }
  }
  assert {
    condition     = toset(values(output.project_workspaces)) == toset(["sap-btp-test-neu-core", "sap-btp-test-neu-cf-dev", "sap-btp-test-neu-cf-test"])
    error_message = "Registry/root wiring may prepare only the three requested test-neu workspaces, never legacy workspaces or PROD."
  }
}
