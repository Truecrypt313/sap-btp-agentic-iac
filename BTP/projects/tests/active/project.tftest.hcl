# Only the disposable test checkout receives examples/project.test-neu.mock.yaml.
mock_provider "btp" {
  override_during = plan
  mock_data "btp_globalaccount" {
    defaults = { id = "00000000-0000-4000-8000-000000000001", license_type = "TRIAL" }
  }
  mock_resource "btp_directory" { defaults = { id = "11111111-1111-4111-8111-111111111111" } }
  mock_data "btp_directories" { defaults = { values = { name = "Unrelated Directory", labels = {} } } }
  mock_data "btp_subaccount_service_plan" {
    defaults = { offering_name = "alert-notification", name = "standard", ready = true }
  }
  mock_data "btp_subaccount_environments" {
    defaults = { values = { service_name = "cloudfoundry", environment_type = "cloudfoundry", plan_name = "trial", landscape_label = "cf-us10-001" } }
  }
  mock_resource "btp_subaccount_environment_instance" {
    defaults = { labels = "{\"API Endpoint\":\"https://api.example.invalid\",\"Org ID\":\"22222222-2222-4222-8222-222222222222\"}" }
  }
}
variables {
  project_id    = "test-neu"
  globalaccount = "mock-global"
}
override_module {
  target  = module.region_catalog["project"]
  outputs = { regions = { DEV = "us10", TEST = "us10" } }
}
override_module {
  target  = module.service_catalog["project"]
  outputs = { valid = true }
}
override_module {
  target  = module.environment["DEV"].module.role_collections.module.catalog_validation
  outputs = { valid = { reader = true } }
}
run "generic_dev_and_test_reference_actual_project_directory" {
  command = plan
  assert {
    condition     = toset(keys(btp_subaccount.environment)) == toset(["DEV", "TEST"]) && alltrue([for env in btp_subaccount.environment : env.parent_id == module.directory.directory_id])
    error_message = "All new subaccounts must reference the actual directory output; no Legacy DEV or PROD."
  }
  assert {
    condition     = btp_subaccount.environment["DEV"].subdomain == "test-neu-dev" && btp_subaccount.environment["TEST"].subdomain == "test-neu-test" && length(module.environment["DEV"].service_instance_ids) == 1 && length(module.environment["TEST"].service_instance_ids) == 0
    error_message = "Subaccounts and services must be project/stage isolated."
  }
  assert {
    condition     = length(module.environment["DEV"].role_collection_names) == 1 && length(module.environment["TEST"].role_collection_names) == 0 && toset(keys(output.project_contract.cloud_foundry_environments)) == toset(["DEV", "TEST"]) && output.project_contract.cloud_foundry_environments.DEV.project_id == "test-neu"
    error_message = "IAM and CF handoffs must remain isolated by project and stage."
  }
}
run "reject_wrong_authenticated_profile" {
  command = plan
  override_data {
    target = data.btp_globalaccount.current[0]
    values = { id = "00000000-0000-4000-8000-000000000001", license_type = "CUSTOMER" }
  }
  expect_failures = [output.project_contract]
}
