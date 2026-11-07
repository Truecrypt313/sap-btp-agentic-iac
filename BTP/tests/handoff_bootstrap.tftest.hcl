# Keep the bootstrap contract regressions after integrating YAML-owned resources.
# Local mock plans only. No real providers, state writes or HCP runs.
mock_provider "btp" {
  override_during = plan
  mock_data "btp_globalaccount" {
    defaults = { subdomain = "mock-globalaccount", license_type = "TRIAL", id = "00000000-0000-4000-8000-000000000001" }
  }
  mock_data "btp_subaccount_environments" {
    defaults = { values = { service_name = "cloudfoundry", environment_type = "cloudfoundry", plan_name = "trial", landscape_label = "cf-us10-001" } }
  }
  mock_data "btp_subaccount_service_plan" {
    defaults = { ready = true, shareable = true, supported_platforms = ["sapbtp", "cloudfoundry"] }
  }
  mock_data "btp_subaccount_subscriptions" {
    defaults = { values = { app_name = "feature-flags-dashboard", plan_name = "dashboard" } }
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
override_module {
  target  = module.region_catalog
  outputs = { regions = { DEV = "us10", TEST = "us10", PROD = "eu10" } }
}
override_module {
  target  = module.service_catalog
  outputs = { valid = true }
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
      length(btp_subaccount.additional) == 1 &&
      contains(keys(btp_subaccount.additional), "TEST") &&
      module.landing_zone_config.configuration.environments.TEST.enabled &&
      !module.landing_zone_config.configuration.environments.TEST.cloud_foundry.enabled &&
      btp_subaccount.project_subaccount.name == "DEV Project ABC" &&
      btp_subaccount.project_subaccount.subdomain == "dev-project-abc-11111111-1111-4111-8111-111111111111" &&
      btp_subaccount_environment_instance.cloudfoundry.plan_name == "trial" &&
      length(btp_subaccount_role_collection_assignment.emergency_administrators) == 1
    )
    error_message = "Preserve the published DEV handoff; only the YAML-defined TEST subaccount may be planned despite an empty legacy input."
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
  expect_failures = [btp_subaccount.project_subaccount]
}

run "reject_non_dev_legacy_stage" {
  command = plan
  variables { subaccount_stage = "TEST" }
  expect_failures = [btp_subaccount.project_subaccount]
}

run "reject_conflicting_legacy_region" {
  command = plan
  variables { subaccount_region = "ap21" }
  expect_failures = [btp_subaccount.project_subaccount]
}

run "reject_conflicting_legacy_landscape" {
  command = plan
  variables { cf_landscape_label = "different-landscape" }
  # YAML owns the actual landscape; reject a conflicting legacy input first.
  expect_failures = [btp_subaccount.project_subaccount]
}

run "yaml_mode_preserves_published_dev_handoff" {
  command = plan
  variables { configuration_mode = "yaml" }
  assert {
    condition = (
      output.cloud_foundry_environments == run.dev_handoff_matches_pr2.cloud_foundry_environments &&
      btp_subaccount.additional["TEST"].name == "TEST Project ABC"
    )
    error_message = "Switching to YAML mode must preserve the bootstrap DEV contract and the YAML-owned TEST address."
  }
}

run "reject_noncanonical_yaml_path" {
  command = plan
  variables { landing_zone_config_file = "./landing-zone.yaml" }
  expect_failures = [var.landing_zone_config_file]
}
