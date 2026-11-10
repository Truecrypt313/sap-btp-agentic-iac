# No HCP calls. Stateful create/no-op only through a fully mocked TFE provider.
mock_provider "tfe" {
  mock_resource "tfe_workspace" { defaults = { id = "ws-1111111111111111" } }
}
override_resource {
  target = tfe_workspace.project["alpha/core"]
  values = { id = "ws-1111111111111111" }
}
override_resource {
  target = tfe_workspace.project["alpha/cf/DEV"]
  values = { id = "ws-2222222222222222" }
}
variables {
  enabled          = true
  projects         = { alpha = { account_profile = "trial", environments = ["DEV"], cf_environments = ["DEV"] } }
  vcs_auth         = { oauth_token_id = "ot-1111111111111111" }
  account_bindings = { trial = { btp_variable_set_ids = ["varset-1111111111111111"], cf_variable_set_ids = ["varset-2222222222222222"] } }
}
run "first_bootstrap_in_mock_state" { command = apply }
run "repeat_bootstrap_in_same_mock_state" {
  command = plan
  assert {
    condition     = output.workspace_ids == run.first_bootstrap_in_mock_state.workspace_ids
    error_message = "Repeated bootstrap must keep actual managed workspace IDs, never create duplicates."
  }
}
