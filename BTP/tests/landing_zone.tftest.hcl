# Every provider is mocked; all runs use command=plan. No real SAP/HCP calls.
mock_provider "btp" {
  override_during = plan
  mock_data "btp_globalaccount" {
    defaults = { subdomain = "mock-globalaccount", license_type = "TRIAL", id = "00000000-0000-4000-8000-000000000001" }
  }


  mock_data "btp_subaccount_entitlements" { defaults = { values = {} } }
  mock_data "btp_subaccount_service_plan" {
    defaults = { ready = true, shareable = true, supported_platforms = ["sapbtp", "cloudfoundry"] }
  }


  mock_data "btp_subaccount_subscriptions" {
    defaults = { values = { app_name = "feature-flags-dashboard", plan_name = "dashboard" } }
  }
  mock_data "btp_subaccount_environments" {
    defaults = { values = { service_name = "cloudfoundry", environment_type = "cloudfoundry", plan_name = "standard", landscape_label = "cf-us10-001" } }
  }
  mock_resource "btp_subaccount_environment_instance" {
    defaults = { labels = "{\"API Endpoint\":\"https://api.example.invalid\",\"Org ID\":\"mock-org\"}" }
  }
}
mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = { result = "11111111-1111-4111-8111-111111111111" }
  }
}

override_resource {
  target          = random_uuid.uuid
  override_during = plan
  values          = { result = "11111111-1111-4111-8111-111111111111" }
}

variables {
  globalaccount               = "mock-globalaccount"
  subaccount_emergency_admins = ["admin@example.invalid"]
  additional_subaccounts = {
    TEST = { region = "us10", costcenter = "12345" }
  }
}

run "preserve_legacy_dev_and_test_addresses" {
  command = plan
  assert {
    condition = (
      btp_subaccount.project_subaccount.name == "DEV Project ABC" &&
      btp_subaccount.project_subaccount.region == "us10" &&
      btp_subaccount.project_subaccount.subdomain == "dev-project-abc-11111111-1111-4111-8111-111111111111" &&
      btp_subaccount.additional["TEST"].name == "TEST Project ABC" &&
      length(btp_subaccount.additional) == 1
    )
    error_message = "The DEV resource and pending TEST address/naming must remain stable."
  }
  assert {
    condition     = length(output.cloud_foundry_environments) == 1 && contains(keys(output.cloud_foundry_environments), "DEV")
    error_message = "No extra CF environments may be enabled by the migration defaults."
  }
  assert {
    condition     = length(module.dev_optional_services.instance_ids) == 0
    error_message = "Existing DEV instances must not be duplicated by the optional-services module."
  }
  assert {
    condition = (
      length(btp_subaccount_role_collection_assignment.emergency_administrators) == 1 &&
      contains(keys(btp_subaccount_role_collection_assignment.emergency_administrators), "admin@example.invalid")
    )
    error_message = "The explicit legacy administrator source must retain the existing for_each identity key."
  }
}

run "reject_conflicting_hcp_test_input" {
  command = plan
  variables {
    additional_subaccounts = { TEST = { region = "ap21", costcenter = "12345" } }
  }
  expect_failures = [btp_subaccount.project_subaccount]
}

run "reject_yaml_mode_with_legacy_override" {
  command = plan
  variables {
    configuration_mode = "yaml"
  }
  expect_failures = [btp_subaccount.project_subaccount]
}

run "yaml_mode_after_removing_override" {
  command = plan
  variables {
    configuration_mode     = "yaml"
    additional_subaccounts = {}
  }
  assert {
    condition     = btp_subaccount.additional["TEST"].region == "us10"
    error_message = "Removing the legacy input must retain TEST because YAML owns it."
  }
}

run "reject_profile_license_mismatch" {
  command = plan
  override_data {
    target = data.btp_globalaccount.current
    values = { license_type = "CUSTOMER", subdomain = "mock-globalaccount", id = "00000000-0000-4000-8000-000000000001" }
  }
  expect_failures = [btp_subaccount.project_subaccount]
}








override_module {
  target  = module.region_catalog
  outputs = { regions = { DEV = "us10", TEST = "us10", PROD = "eu10" } }
}
override_module {
  target  = module.service_catalog
  outputs = { valid = true }
}

override_data {
  target = data.btp_subaccount_environments.all
  values = { values = { service_name = "cloudfoundry", environment_type = "cloudfoundry", plan_name = "trial", landscape_label = "cf-us10-001" } }
}

run "reject_noncanonical_configuration_path" {
  command = plan
  variables { landing_zone_config_file = "../examples/landing-zone.enterprise.yaml" }
  expect_failures = [var.landing_zone_config_file]
}
