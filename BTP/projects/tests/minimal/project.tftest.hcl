# Only in the disposable checkout: enable directory and DEV, retain all other
# source values. No CF, services, quotas or IAM; all providers are mocks.
mock_provider "btp" {
  override_during = plan
  mock_data "btp_globalaccount" {
    defaults = { id = "00000000-0000-4000-8000-000000000001", license_type = "TRIAL" }
  }
  mock_resource "btp_directory" { defaults = { id = "11111111-1111-4111-8111-111111111111" } }
}
mock_provider "external" {
  mock_data "external" { defaults = { result = { managed_id = "", inventory = "[]" } } }
}
variables {
  project_id    = "test-neu"
  globalaccount = "mock-global"
}
override_module {
  target  = module.region_catalog["project"]
  outputs = { regions = { DEV = "us10" } }
}
run "minimal_dev_skips_auto_entitlements_and_requests_no_explicit_services" {
  command = plan
  assert {
    condition     = toset(keys(btp_subaccount.environment)) == toset(["DEV"]) && btp_subaccount.environment["DEV"].skip_auto_entitlement == true && btp_subaccount.environment["DEV"].parent_id == module.directory.directory_id
    error_message = "Only the new DEV subaccount, with auto-entitlements suppressed, may reference the new directory."
  }
  assert {
    condition     = !module.directory.quota_managed && length(module.service_selection["DEV"].selection.entitlements) == 0 && length(module.service_selection["DEV"].selection.instances) == 0 && length(module.service_selection["DEV"].selection.subscriptions) == 0 && module.environment["DEV"].cloud_foundry == null && length(module.environment["DEV"].role_collection_names) == 0
    error_message = "Minimal test must request no explicit entitlement, service, CF environment or role collection."
  }
}
