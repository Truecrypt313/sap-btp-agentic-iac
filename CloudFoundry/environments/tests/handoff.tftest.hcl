mock_provider "cloudfoundry" {}
mock_provider "tfe" {}

variables {
  environment    = "TEST"
  workspace_name = "sap-cloudfoundry-test"
}
override_data {
  target = data.tfe_outputs.btp
  values = { nonsensitive_values = { cloud_foundry_environments = { TEST = {
    api_url              = "https://api.example.invalid"
    org_id               = "22222222-2222-4222-8222-222222222222"
    contract_fingerprint = "f22889d4e67a89cf262721c45e61c2971a4d4bd0b0e4c86aa420d1733390fff6"
  } } } }
}
run "matching_outputs_and_workspace" {
  command = plan
  assert {
    condition     = length(output.space_ids) == 2
    error_message = "Only two TEST spaces may be planned."
  }
}
run "reject_stale_btp_configuration" {
  command = plan
  override_data {
    target = data.tfe_outputs.btp
    values = { nonsensitive_values = { cloud_foundry_environments = { TEST = {
      api_url              = "https://api.example.invalid"
      org_id               = "22222222-2222-4222-8222-222222222222"
      contract_fingerprint = "stale"
    } } } }
  }
  expect_failures = [output.space_ids]
}
run "reject_wrong_workspace_binding" {
  command = plan
  variables { workspace_name = "sap-cloudfoundry-prod" }
  expect_failures = [var.workspace_name]
}
run "reject_dev_in_new_root" {
  command = plan
  variables {
    environment    = "DEV"
    workspace_name = "sap-cloudfoundry-dev"
  }
  expect_failures = [var.environment]
}
run "reject_missing_btp_handoff" {
  command = plan
  override_data {
    target = data.tfe_outputs.btp
    values = { nonsensitive_values = {} }
  }
  expect_failures = [output.space_ids]
}
run "reject_noncanonical_configuration_path" {
  command = plan
  variables { landing_zone_config_file = "../../examples/landing-zone.enterprise.yaml" }
  expect_failures = [var.landing_zone_config_file]
}
