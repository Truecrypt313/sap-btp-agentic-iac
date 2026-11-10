# All operations, including apply and cleanup, use mocked providers only.
# Disposable local Terraform test state; no SAP or HCP credentials/API access.
mock_provider "btp" {
  mock_resource "btp_directory" {
    defaults = { id = "11111111-1111-4111-8111-111111111111" }
  }
  mock_data "btp_directories" {
    defaults = { values = { id = "11111111-1111-4111-8111-111111111111", name = "Test_Neu", labels = { project_id = ["test-neu"] } } }
  }
}
mock_provider "external" {
  mock_data "external" {
    defaults = { result = {
      managed_id = "11111111-1111-4111-8111-111111111111"
      inventory  = "[{\"id\":\"11111111-1111-4111-8111-111111111111\",\"name\":\"Test_Neu\",\"project_ids\":[\"test-neu\"]}]"
    } }
  }
}
variables {
  project_id       = "test-neu"
  globalaccount_id = "00000000-0000-4000-8000-000000000001"
  create           = true
  name             = "Test_Neu"
  description      = "Initial metadata"
}
run "first_creation_in_disposable_mock_state" {
  command = apply
  override_data {
    target = data.external.ownership[0]
    values = { result = { managed_id = "", inventory = "[]" } }
  }
  override_data {
    target = data.btp_directories.existing[0]
    values = { values = { id = "22222222-2222-4222-8222-222222222222", name = "Unrelated", labels = {} } }
  }
  assert {
    condition     = output.directory_id == "11111111-1111-4111-8111-111111111111"
    error_message = "First mocked creation must publish the actual managed identity."
  }
}
run "repeat_plan_uses_owned_id_without_cycle" {
  command = plan
  assert {
    condition     = output.directory_id == run.first_creation_in_disposable_mock_state.directory_id && module.inventory_rules.unique
    error_message = "An inventory entry with the actual state-owned ID must allow the next plan."
  }
}
run "repeat_plan_with_metadata_change_keeps_identity" {
  command = plan
  variables { description = "Reviewed new metadata" }
  assert {
    condition     = btp_directory.this["project"].description == "Reviewed new metadata" && output.directory_id == run.first_creation_in_disposable_mock_state.directory_id
    error_message = "Metadata changes must stay visible while retaining ownership by actual ID."
  }
}
run "reject_invalid_parent_uuid" {
  command = plan
  variables { parent_id = "not-a-uuid" }
  expect_failures = [var.parent_id]
}
