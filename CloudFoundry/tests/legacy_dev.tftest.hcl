mock_provider "cloudfoundry" {}
mock_provider "tfe" {}

variables {
  cf_api_url         = "https://api.example.invalid"
  cf_org_id          = "22222222-2222-4222-8222-222222222222"
  cf_space_manager   = "manager@example.invalid"
  cf_space_developer = "developer@example.invalid"
  subaccount_url     = "https://cockpit.example.invalid"
}

override_data {
  target = data.tfe_outputs.btp
  values = { nonsensitive_values = { cloud_foundry_environments = { DEV = {
    api_url              = "https://api.example.invalid"
    org_id               = "22222222-2222-4222-8222-222222222222"
    contract_fingerprint = "444d0f16abd3373a17cdd4159c596f4ae06e585e60844cad15d4bf39bccbe879"
  } } } }
}

run "preserve_existing_dev_addresses" {
  command = plan
  assert {
    condition = (
      cloudfoundry_space.project_space.name == "dev-project-abc" &&
      cloudfoundry_space_role.space_manager.type == "space_manager" &&
      cloudfoundry_space_role.space_developer.type == "space_developer"
    )
    error_message = "Legacy space and both legacy role resources must retain their original addresses and names."
  }
}

run "reject_test_in_legacy_dev_workspace" {
  command = plan
  variables {
    subaccount_stage = "TEST"
  }
  expect_failures = [cloudfoundry_space.project_space]
}

run "reject_missing_handoff" {
  command = plan
  override_data {
    target = data.tfe_outputs.btp
    values = { nonsensitive_values = {} }
  }
  expect_failures = [output.dev_handoff_valid]
}

run "reject_wrong_org_handoff" {
  command = plan
  override_data {
    target = data.tfe_outputs.btp
    values = { nonsensitive_values = { cloud_foundry_environments = { DEV = { api_url = "https://api.example.invalid", org_id = "wrong", contract_fingerprint = "444d0f16abd3373a17cdd4159c596f4ae06e585e60844cad15d4bf39bccbe879" } } } }
  }
  expect_failures = [output.dev_handoff_valid]
}

run "reject_stale_handoff" {
  command = plan
  override_data {
    target = data.tfe_outputs.btp
    values = { nonsensitive_values = { cloud_foundry_environments = { DEV = { api_url = "https://api.example.invalid", org_id = "22222222-2222-4222-8222-222222222222", contract_fingerprint = "stale" } } } }
  }
  expect_failures = [output.dev_handoff_valid]
}

run "reject_wrong_endpoint_handoff" {
  command = plan
  override_data {
    target = data.tfe_outputs.btp
    values = { nonsensitive_values = { cloud_foundry_environments = { DEV = { api_url = "https://other.example.invalid", org_id = "22222222-2222-4222-8222-222222222222", contract_fingerprint = "444d0f16abd3373a17cdd4159c596f4ae06e585e60844cad15d4bf39bccbe879" } } } }
  }
  expect_failures = [output.dev_handoff_valid]
}

run "reject_noncanonical_configuration_path" {
  command = plan
  variables { landing_zone_config_file = "../examples/landing-zone.enterprise.yaml" }
  expect_failures = [var.landing_zone_config_file]
}

run "legacy_roles_are_forwarded_to_existing_addresses" {
  command = plan
  override_module {
    target = module.landing_zone_config
    outputs = {
      configuration = merge(yamldecode(file("../BTP/landing-zone.yaml")), { environments = { DEV = { enabled = true, cloud_foundry = { enabled = true, spaces = { project = merge(yamldecode(file("../BTP/landing-zone.yaml")).environments.DEV.cloud_foundry.spaces.project, {
        legacy_manager   = { username = "custom@example.invalid", user = null, origin = "custom-idp" }
        legacy_developer = { username = null, user = "11111111-1111-4111-8111-111111111111", origin = null }
      }) } } } } })
      handoff_fingerprints = { DEV = "444d0f16abd3373a17cdd4159c596f4ae06e585e60844cad15d4bf39bccbe879" }
    }
  }
  assert {
    condition     = cloudfoundry_space_role.space_manager.username == "custom@example.invalid" && cloudfoundry_space_role.space_manager.origin == "custom-idp" && cloudfoundry_space_role.space_developer.user == "11111111-1111-4111-8111-111111111111"
    error_message = "Legacy options must configure the two original resource addresses."
  }
}
