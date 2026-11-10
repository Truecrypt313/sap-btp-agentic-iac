# Every data read and resource operation is mocked; no new credentials or API calls.
mock_provider "tfe" {
  mock_data "tfe_workspace" {
    defaults = { vcs_repo = [{ identifier = "Truecrypt313/sap-btp-agentic-iac", github_app_installation_id = "ghain-1111111111111111", oauth_token_id = "" }] }
  }
  mock_data "tfe_github_app_installation" {
    defaults = { id = "ghain-1111111111111111", installation_id = 12345678 }
  }
  mock_data "tfe_oauth_client" {
    defaults = { oauth_token_id = "ot-1111111111111111", http_url = "https://github.com" }
  }
  mock_resource "tfe_workspace" { defaults = { id = "ws-1111111111111111" } }
}
variables {
  bootstrap_enabled = true
  account_bindings = { trial = {
    btp_variable_set_ids = ["varset-1111111111111111"]
    cf_variable_set_ids  = ["varset-2222222222222222"]
  } }
}
run "native_github_app_uses_internal_id_and_repository_anchor" {
  command = plan
  assert {
    condition     = local.vcs_valid && local.detected_vcs.github_app_installation_id == "ghain-1111111111111111" && local.detected_vcs.oauth_token_id == null && data.tfe_github_app_installation.repository[0].name == "Truecrypt313" && length(data.tfe_oauth_client.repository) == 0 && length(output.project_workspaces) == 3
    error_message = "Discover the internal ghain-ID, never the numeric GitHub installation ID or an OAuth fallback."
  }
}
run "disabled_bootstrap_needs_no_connection" {
  command = plan
  variables { bootstrap_enabled = false }
  assert {
    condition     = length(data.tfe_workspace.vcs_reference) == 0 && length(data.tfe_github_app_installation.repository) == 0 && length(data.tfe_oauth_client.repository) == 0 && length(output.project_workspaces) == 0
    error_message = "Disabled means no reference-workspace, GitHub App or OAuth reads."
  }
}
run "reject_foreign_repository" {
  command = plan
  override_data {
    target = data.tfe_workspace.vcs_reference[0]
    values = { vcs_repo = [{ identifier = "Truecrypt313/foreign", github_app_installation_id = "ghain-1111111111111111", oauth_token_id = "" }] }
  }
  expect_failures = [data.tfe_workspace.vcs_reference]
}
run "reject_missing_vcs_binding" {
  command = plan
  override_data {
    target = data.tfe_workspace.vcs_reference[0]
    values = { vcs_repo = [] }
  }
  expect_failures = [data.tfe_workspace.vcs_reference]
}
run "reject_ambiguous_authentication" {
  command = plan
  override_data {
    target = data.tfe_workspace.vcs_reference[0]
    values = { vcs_repo = [{ identifier = "Truecrypt313/sap-btp-agentic-iac", github_app_installation_id = "ghain-1111111111111111", oauth_token_id = "ot-1111111111111111" }] }
  }
  expect_failures = [data.tfe_workspace.vcs_reference]
}
run "reject_multiple_reference_bindings" {
  command = plan
  override_data {
    target = data.tfe_workspace.vcs_reference[0]
    values = { vcs_repo = [
      { identifier = "Truecrypt313/sap-btp-agentic-iac", github_app_installation_id = "ghain-1111111111111111", oauth_token_id = "" },
      { identifier = "Truecrypt313/sap-btp-agentic-iac", github_app_installation_id = "ghain-2222222222222222", oauth_token_id = "" }
    ] }
  }
  expect_failures = [data.tfe_workspace.vcs_reference]
}
run "reject_invalid_reference_id" {
  command = plan
  override_data {
    target = data.tfe_workspace.vcs_reference[0]
    values = { vcs_repo = [{ identifier = "Truecrypt313/sap-btp-agentic-iac", github_app_installation_id = "12345678", oauth_token_id = "" }] }
  }
  expect_failures = [data.tfe_workspace.vcs_reference]
}
run "reject_another_installation_from_name_lookup" {
  command = plan
  override_data {
    target = data.tfe_github_app_installation.repository[0]
    values = { id = "ghain-2222222222222222" }
  }
  expect_failures = [data.tfe_github_app_installation.repository]
}
run "reject_empty_installation_result" {
  command = plan
  override_data {
    target = data.tfe_github_app_installation.repository[0]
    values = { id = "" }
  }
  expect_failures = [data.tfe_github_app_installation.repository]
}
run "keep_oauth_only_when_really_used_by_reference" {
  command = plan
  override_data {
    target = data.tfe_workspace.vcs_reference[0]
    values = { vcs_repo = [{ identifier = "Truecrypt313/sap-btp-agentic-iac", github_app_installation_id = "", oauth_token_id = "ot-1111111111111111" }] }
  }
  assert {
    condition     = local.vcs_valid && local.detected_vcs.oauth_token_id == "ot-1111111111111111" && local.detected_vcs.github_app_installation_id == null && length(data.tfe_github_app_installation.repository) == 0
    error_message = "Retain a verified existing GitHub OAuth connection; never require an App on this path."
  }
}
run "reject_unrelated_oauth_client" {
  command = plan
  override_data {
    target = data.tfe_workspace.vcs_reference[0]
    values = { vcs_repo = [{ identifier = "Truecrypt313/sap-btp-agentic-iac", github_app_installation_id = "", oauth_token_id = "ot-2222222222222222" }] }
  }
  expect_failures = [data.tfe_oauth_client.repository]
}
run "existing_oauth_accepts_null_unused_app_field" {
  command = plan
  override_data {
    target = data.tfe_workspace.vcs_reference[0]
    values = { vcs_repo = [{ identifier = "Truecrypt313/sap-btp-agentic-iac", github_app_installation_id = null, oauth_token_id = "ot-1111111111111111" }] }
  }
  assert {
    condition     = local.vcs_valid && local.detected_vcs.oauth_token_id == "ot-1111111111111111"
    error_message = "Both null and empty unused App fields must preserve the genuine OAuth connection."
  }
}
run "existing_oauth_http_url_may_have_trailing_slash" {
  command = plan
  override_data {
    target = data.tfe_workspace.vcs_reference[0]
    values = { vcs_repo = [{ identifier = "Truecrypt313/sap-btp-agentic-iac", github_app_installation_id = "", oauth_token_id = "ot-1111111111111111" }] }
  }
  override_data {
    target = data.tfe_oauth_client.repository[0]
    values = { oauth_token_id = "ot-1111111111111111", http_url = "https://github.com/" }
  }
  assert {
    condition     = local.vcs_valid && local.detected_vcs.oauth_token_id == "ot-1111111111111111"
    error_message = "A canonical trailing slash must not invalidate the existing verified GitHub OAuth connection."
  }
}
run "reject_non_github_oauth_host" {
  command = plan
  override_data {
    target = data.tfe_workspace.vcs_reference[0]
    values = { vcs_repo = [{ identifier = "Truecrypt313/sap-btp-agentic-iac", github_app_installation_id = "", oauth_token_id = "ot-1111111111111111" }] }
  }
  override_data {
    target = data.tfe_oauth_client.repository[0]
    values = { oauth_token_id = "ot-1111111111111111", http_url = "https://gitlab.com" }
  }
  expect_failures = [data.tfe_oauth_client.repository]
}
# The only apply/cleanup is a local mock operation, never an HCP apply.
run "first_bootstrap_with_discovered_connection" { command = apply }
run "repeat_plan_with_same_discovered_connection" {
  command = plan
  assert {
    condition     = output.project_workspace_ids == run.first_bootstrap_with_discovered_connection.project_workspace_ids && local.vcs_valid
    error_message = "Repeated discovery must preserve managed workspace identities."
  }
}
