# Local mock plans only. No real providers, state writes or HCP runs.
mock_provider "btp" {
  override_during = plan
  mock_data "btp_globalaccount" {
    defaults = { subdomain = "mock-globalaccount", license_type = "TRIAL", id = "00000000-0000-4000-8000-000000000001" }
  }
  mock_data "btp_subaccount_environments" {
    defaults = { values = { service_name = "cloudfoundry", environment_type = "cloudfoundry", plan_name = "trial", landscape_label = "cf-us10-001" } }
  }
  mock_resource "btp_subaccount_environment_instance" {
    defaults = { labels = "{\"API Endpoint\":\"https://api.example.invalid\",\"Org ID\":\"22222222-2222-4222-8222-222222222222\"}" }
  }
}
mock_provider "random" {}
override_resource {
  target          = random_uuid.uuid
  override_during = plan
  values          = { result = "11111111-1111-4111-8111-111111111111" }
}
override_resource {
  target          = terraform_data.cf_landscape_label
  override_during = plan
  values          = { output = "cf-us10-001" }
}

variables {
  globalaccount               = "mock-globalaccount"
  subaccount_emergency_admins = ["admin@example.invalid"]
  additional_subaccounts      = {}
}

run "dev_handoff_matches_pr2" {
  command = plan
  assert {
    condition = output.cloud_foundry_environments == {
      DEV = {
        api_url              = "https://api.example.invalid"
        org_id               = "22222222-2222-4222-8222-222222222222"
        contract_fingerprint = "444d0f16abd3373a17cdd4159c596f4ae06e585e60844cad15d4bf39bccbe879"
      }
    }
    error_message = "Publish exactly the endpoint, org and computed identity fingerprint expected by PR #2."
  }
  assert {
    condition = (
      length(btp_subaccount.additional) == 0 &&
      btp_subaccount.project_subaccount.name == "DEV Project ABC" &&
      btp_subaccount.project_subaccount.subdomain == "dev-project-abc-11111111-1111-4111-8111-111111111111" &&
      btp_subaccount_environment_instance.cloudfoundry.plan_name == "trial" &&
      length(btp_subaccount_role_collection_assignment.emergency_administrators) == 1
    )
    error_message = "Bootstrap must preserve DEV and must not activate YAML-defined TEST resources."
  }
}

run "legacy_test_address_is_preserved" {
  command = plan
  variables {
    additional_subaccounts = { TEST = { region = "us10", costcenter = "12345" } }
  }
  assert {
    condition = (
      length(btp_subaccount.additional) == 1 &&
      btp_subaccount.additional["TEST"].name == "TEST Project ABC" &&
      btp_subaccount.additional["TEST"].region == "us10" &&
      btp_subaccount.additional["TEST"].subdomain == "test-project-abc-11111111-1111-4111-8111-111111111111"
    )
    error_message = "The legacy TEST input/address must retain its original semantics."
  }
}

run "reject_conflicting_legacy_project" {
  command = plan
  variables { project_name = "Another Project" }
  expect_failures = [output.cloud_foundry_environments]
}

run "reject_non_dev_legacy_stage" {
  command = plan
  variables { subaccount_stage = "TEST" }
  expect_failures = [output.cloud_foundry_environments]
}

run "reject_conflicting_legacy_region" {
  command = plan
  variables { subaccount_region = "ap21" }
  expect_failures = [output.cloud_foundry_environments]
}

run "reject_conflicting_legacy_landscape" {
  command = plan
  variables { cf_landscape_label = "different-landscape" }
  override_resource {
    target          = terraform_data.cf_landscape_label
    override_during = plan
    values          = { output = "different-landscape" }
  }
  expect_failures = [output.cloud_foundry_environments]
}

run "reject_noncanonical_yaml_path" {
  command = plan
  variables { landing_zone_config_file = "./landing-zone.yaml" }
  expect_failures = [var.landing_zone_config_file]
}
