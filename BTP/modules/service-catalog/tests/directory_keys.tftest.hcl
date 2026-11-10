mock_provider "btp" { override_during = plan }
variables {
  globalaccount_id = "00000000-0000-4000-8000-000000000001"
  environments     = { DEV = { parent_id = "11111111-1111-4111-8111-111111111111", iaas_provider = "AWS" } }
  regions          = { DEV = "us10" }
  subaccount_ids   = { DEV = "22222222-2222-4222-8222-222222222222" }
  entitlements     = { DEV = { alert = { service_name = "alert-notification", plan_name = "standard", amount = 1, plan_unique_identifier = null } } }
}
override_module {
  target  = module.rules
  outputs = { valid = true }
}
run "legacy_directory_state_keys_remain_ids" {
  command = plan
  assert {
    condition     = toset(keys(data.btp_directory_entitlements.available)) == toset(["11111111-1111-4111-8111-111111111111"])
    error_message = "Default lookup keys must remain byte-identical for existing callers."
  }
}
run "project_directory_uses_known_keys_and_resource_backed_values" {
  command = plan
  variables { directory_ids = { authority = "11111111-1111-4111-8111-111111111111" } }
  assert {
    condition     = toset(keys(data.btp_directory_entitlements.available)) == toset(["authority"]) && data.btp_directory_entitlements.available["authority"].directory_id == "11111111-1111-4111-8111-111111111111"
    error_message = "Project lookup addresses must use stable known keys, not a new directory's unknown resource ID."
  }
}
