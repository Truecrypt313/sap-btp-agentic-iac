mock_provider "cloudfoundry" {}
mock_provider "tfe" {}
variables {
  project_id  = "test-neu"
  environment = "DEV"
}
override_data {
  target = data.tfe_outputs.project[0]
  values = { nonsensitive_values = { project_contract = {
    project_id         = "test-neu"
    deployment_enabled = true
    btp_workspace      = "sap-btp-test-neu-core"
    cloud_foundry_environments = { DEV = {
      project_id           = "test-neu"
      environment          = "DEV"
      btp_workspace        = "sap-btp-test-neu-core"
      cf_workspace         = "sap-btp-test-neu-cf-dev"
      api_url              = "https://api.example.invalid"
      org_id               = "22222222-2222-4222-8222-222222222222"
      contract_fingerprint = "b8394c954fda22bf0045cabd23d8dbcd0adafccafcc6a9d49c54750d4831b84f"
    } }
  } } }
}
run "matching_project_handoff_owns_only_its_two_spaces" {
  command = plan
  assert {
    condition     = toset(keys(output.space_ids)) == toset(["backend", "frontend"]) && data.tfe_outputs.project[0].workspace == "sap-btp-test-neu-core"
    error_message = "Only DEV backend/frontend from this project's output-only handoff."
  }
}
run "reject_stale_or_foreign_handoff" {
  command = plan
  override_data {
    target = data.tfe_outputs.project[0]
    values = { nonsensitive_values = { project_contract = {
      project_id         = "foreign"
      deployment_enabled = true
      btp_workspace      = "sap-btp-foreign-core"
      cloud_foundry_environments = { DEV = {
        project_id = "foreign", environment = "DEV", btp_workspace = "sap-btp-foreign-core", cf_workspace = "sap-btp-foreign-cf-dev"
        api_url    = "https://api.example.invalid", org_id = "22222222-2222-4222-8222-222222222222", contract_fingerprint = "stale"
      } }
    } } }
  }
  expect_failures = [output.space_ids]
}

run "reject_mismatched_project_id" {
  command = plan
  override_data {
    target = data.tfe_outputs.project[0]
    values = { "nonsensitive_values" : { "project_contract" : { "project_id" : "test-neu", "deployment_enabled" : true, "btp_workspace" : "sap-btp-test-neu-core", "cloud_foundry_environments" : { "DEV" : { "project_id" : "foreign", "environment" : "DEV", "btp_workspace" : "sap-btp-test-neu-core", "cf_workspace" : "sap-btp-test-neu-cf-dev", "api_url" : "https://api.example.invalid", "org_id" : "22222222-2222-4222-8222-222222222222", "contract_fingerprint" : "b8394c954fda22bf0045cabd23d8dbcd0adafccafcc6a9d49c54750d4831b84f" } } } } }
  }
  expect_failures = [output.space_ids]
}

run "reject_mismatched_environment" {
  command = plan
  override_data {
    target = data.tfe_outputs.project[0]
    values = { "nonsensitive_values" : { "project_contract" : { "project_id" : "test-neu", "deployment_enabled" : true, "btp_workspace" : "sap-btp-test-neu-core", "cloud_foundry_environments" : { "DEV" : { "project_id" : "test-neu", "environment" : "TEST", "btp_workspace" : "sap-btp-test-neu-core", "cf_workspace" : "sap-btp-test-neu-cf-dev", "api_url" : "https://api.example.invalid", "org_id" : "22222222-2222-4222-8222-222222222222", "contract_fingerprint" : "b8394c954fda22bf0045cabd23d8dbcd0adafccafcc6a9d49c54750d4831b84f" } } } } }
  }
  expect_failures = [output.space_ids]
}

run "reject_mismatched_btp_workspace" {
  command = plan
  override_data {
    target = data.tfe_outputs.project[0]
    values = { "nonsensitive_values" : { "project_contract" : { "project_id" : "test-neu", "deployment_enabled" : true, "btp_workspace" : "sap-btp-test-neu-core", "cloud_foundry_environments" : { "DEV" : { "project_id" : "test-neu", "environment" : "DEV", "btp_workspace" : "sap-btp-foreign-core", "cf_workspace" : "sap-btp-test-neu-cf-dev", "api_url" : "https://api.example.invalid", "org_id" : "22222222-2222-4222-8222-222222222222", "contract_fingerprint" : "b8394c954fda22bf0045cabd23d8dbcd0adafccafcc6a9d49c54750d4831b84f" } } } } }
  }
  expect_failures = [output.space_ids]
}

run "reject_mismatched_cf_workspace" {
  command = plan
  override_data {
    target = data.tfe_outputs.project[0]
    values = { "nonsensitive_values" : { "project_contract" : { "project_id" : "test-neu", "deployment_enabled" : true, "btp_workspace" : "sap-btp-test-neu-core", "cloud_foundry_environments" : { "DEV" : { "project_id" : "test-neu", "environment" : "DEV", "btp_workspace" : "sap-btp-test-neu-core", "cf_workspace" : "sap-btp-test-neu-cf-test", "api_url" : "https://api.example.invalid", "org_id" : "22222222-2222-4222-8222-222222222222", "contract_fingerprint" : "b8394c954fda22bf0045cabd23d8dbcd0adafccafcc6a9d49c54750d4831b84f" } } } } }
  }
  expect_failures = [output.space_ids]
}

run "reject_mismatched_contract_fingerprint" {
  command = plan
  override_data {
    target = data.tfe_outputs.project[0]
    values = { "nonsensitive_values" : { "project_contract" : { "project_id" : "test-neu", "deployment_enabled" : true, "btp_workspace" : "sap-btp-test-neu-core", "cloud_foundry_environments" : { "DEV" : { "project_id" : "test-neu", "environment" : "DEV", "btp_workspace" : "sap-btp-test-neu-core", "cf_workspace" : "sap-btp-test-neu-cf-dev", "api_url" : "https://api.example.invalid", "org_id" : "22222222-2222-4222-8222-222222222222", "contract_fingerprint" : "stale" } } } } }
  }
  expect_failures = [output.space_ids]
}

run "reject_mismatched_org_id" {
  command = plan
  override_data {
    target = data.tfe_outputs.project[0]
    values = { "nonsensitive_values" : { "project_contract" : { "project_id" : "test-neu", "deployment_enabled" : true, "btp_workspace" : "sap-btp-test-neu-core", "cloud_foundry_environments" : { "DEV" : { "project_id" : "test-neu", "environment" : "DEV", "btp_workspace" : "sap-btp-test-neu-core", "cf_workspace" : "sap-btp-test-neu-cf-dev", "api_url" : "https://api.example.invalid", "org_id" : "invalid", "contract_fingerprint" : "b8394c954fda22bf0045cabd23d8dbcd0adafccafcc6a9d49c54750d4831b84f" } } } } }
  }
  expect_failures = [output.space_ids]
}

run "reject_mismatched_api_url" {
  command = plan
  override_data {
    target = data.tfe_outputs.project[0]
    values = { "nonsensitive_values" : { "project_contract" : { "project_id" : "test-neu", "deployment_enabled" : true, "btp_workspace" : "sap-btp-test-neu-core", "cloud_foundry_environments" : { "DEV" : { "project_id" : "test-neu", "environment" : "DEV", "btp_workspace" : "sap-btp-test-neu-core", "cf_workspace" : "sap-btp-test-neu-cf-dev", "api_url" : "http://api.example.invalid", "org_id" : "22222222-2222-4222-8222-222222222222", "contract_fingerprint" : "b8394c954fda22bf0045cabd23d8dbcd0adafccafcc6a9d49c54750d4831b84f" } } } } }
  }
  expect_failures = [output.space_ids]
}
