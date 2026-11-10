mock_provider "btp" {
  override_during = plan
  mock_resource "btp_directory" { defaults = { id = "11111111-1111-4111-8111-111111111111" } }
  mock_data "btp_directory" {
    defaults = { name = "Test_Neu", parent_id = "00000000-0000-4000-8000-000000000001", features = ["DEFAULT"], labels = { project_id = ["test-neu"] } }
  }
  mock_data "btp_directories" { defaults = { values = { name = "Unrelated Directory", labels = {} } } }
}
variables {
  project_id       = "test-neu"
  globalaccount_id = "00000000-0000-4000-8000-000000000001"
  create           = true
  name             = "Test_Neu"
}
run "create_directory_publishes_real_resource_id" {
  command = plan
  assert {
    condition     = output.directory_id == btp_directory.this["project"].id && !output.quota_managed && output.quota_parent_id == var.globalaccount_id
    error_message = "DEFAULT directory must expose resource identity and inherit global quotas."
  }
}
run "disabled_directory_has_no_resource_or_reads" {
  command = plan
  variables { create = false }
  assert {
    condition     = length(btp_directory.this) == 0 && length(data.btp_directory.ancestor_0) == 0 && output.directory_id == null
    error_message = "Disabled directory must not create or look up resources."
  }
}
run "parent_reference_is_used" {
  command = plan
  variables { parent_id = "22222222-2222-4222-8222-222222222222" }
  assert {
    condition     = btp_directory.this["project"].parent_id == data.btp_directory.ancestor_0[0].id
    error_message = "Validate and use the actual parent."
  }
}
run "enhanced_directory_is_quota_authority" {
  command = plan
  variables { features = ["DEFAULT", "ENTITLEMENTS", "AUTHORIZATIONS"] }
  assert {
    condition     = output.quota_managed && output.quota_parent_id == output.directory_id && btp_directory.this["project"].subdomain == "test-neu-directory"
    error_message = "Enhanced directory owns its quota scope and authorization subdomain."
  }
}
run "reject_authorizations_without_entitlements" {
  command = plan
  variables { features = ["DEFAULT", "AUTHORIZATIONS"] }
  expect_failures = [var.features]
}
run "reject_unknown_feature" {
  command = plan
  variables { features = ["DEFAULT", "OTHER"] }
  expect_failures = [var.features]
}
run "existing_directory_is_read_not_recreated" {
  command = plan
  variables {
    create      = false
    existing_id = "22222222-2222-4222-8222-222222222222"
  }
  assert {
    condition     = length(btp_directory.this) == 0 && output.directory_id == var.existing_id
    error_message = "Referencing an owned directory must not create/import another one."
  }
}
run "reject_existing_directory_from_other_project" {
  command = plan
  variables {
    create      = false
    existing_id = "22222222-2222-4222-8222-222222222222"
  }
  override_data {
    target = data.btp_directory.ancestor_0[0]
    values = { name = "Test_Neu", features = ["DEFAULT"], parent_id = "00000000-0000-4000-8000-000000000001", labels = { project_id = ["foreign"] } }
  }
  expect_failures = [output.directory_id]
}
run "reject_create_and_existing_together" {
  command = plan
  variables { existing_id = "22222222-2222-4222-8222-222222222222" }
  expect_failures = [var.existing_id]
}
run "reject_enhanced_child_under_enhanced_parent" {
  command = plan
  variables {
    features  = ["DEFAULT", "ENTITLEMENTS"]
    parent_id = "22222222-2222-4222-8222-222222222222"
  }
  override_data {
    target = data.btp_directory.ancestor_0[0]
    values = { features = ["DEFAULT", "ENTITLEMENTS"], parent_id = "00000000-0000-4000-8000-000000000001" }
  }
  expect_failures = [btp_directory.this]
}
run "default_child_inherits_enhanced_parent_quota" {
  command = plan
  variables { parent_id = "22222222-2222-4222-8222-222222222222" }
  override_data {
    target = data.btp_directory.ancestor_0[0]
    values = { features = ["DEFAULT", "ENTITLEMENTS"], parent_id = "00000000-0000-4000-8000-000000000001" }
  }
  assert {
    condition     = output.quota_managed && output.quota_parent_id == var.parent_id
    error_message = "Structural directories inherit the nearest enhanced quota scope."
  }
}
run "reject_cycle_or_excessive_depth" {
  command = plan
  variables { parent_id = "22222222-2222-4222-8222-222222222222" }
  override_data {
    target = data.btp_directory.ancestor_0[0]
    values = { id = "22222222-2222-4222-8222-222222222222", features = ["DEFAULT"], parent_id = "22222222-2222-4222-8222-222222222222" }
  }
  override_data {
    target = data.btp_directory.ancestor_1[0]
    values = { id = "22222222-2222-4222-8222-222222222222", features = ["DEFAULT"], parent_id = "22222222-2222-4222-8222-222222222222" }
  }
  expect_failures = [btp_directory.this]
}

run "reject_recreation_of_existing_directory" {
  command = plan
  # Full/multiple inventory rows are tested in the provider-free rules module.
  override_module {
    target  = module.inventory_rules
    outputs = { unique = false }
  }
  expect_failures = [btp_directory.this]
}

run "reject_foreign_project_parent" {
  command = plan
  variables { parent_id = "22222222-2222-4222-8222-222222222222" }
  override_data {
    target = data.btp_directory.ancestor_0[0]
    values = { features = ["DEFAULT"], parent_id = "00000000-0000-4000-8000-000000000001", labels = { project_id = ["foreign"] } }
  }
  expect_failures = [btp_directory.this]
}

run "reject_sixth_directory_level" {
  command = plan
  variables { parent_id = "22222222-2222-4222-8222-222222222222" }
  override_data {
    target = data.btp_directory.ancestor_0[0]
    values = { "id" : "22222222-2222-4222-8222-222222222222", "parent_id" : "33333333-3333-4333-8333-333333333333", "features" : ["DEFAULT"], "labels" : {} }
  }
  override_data {
    target = data.btp_directory.ancestor_1[0]
    values = { "id" : "33333333-3333-4333-8333-333333333333", "parent_id" : "44444444-4444-4444-8444-444444444444", "features" : ["DEFAULT"], "labels" : {} }
  }
  override_data {
    target = data.btp_directory.ancestor_2[0]
    values = { "id" : "44444444-4444-4444-8444-444444444444", "parent_id" : "55555555-5555-4555-8555-555555555555", "features" : ["DEFAULT"], "labels" : {} }
  }
  override_data {
    target = data.btp_directory.ancestor_3[0]
    values = { "id" : "55555555-5555-4555-8555-555555555555", "parent_id" : "66666666-6666-4666-8666-666666666666", "features" : ["DEFAULT"], "labels" : {} }
  }
  override_data {
    target = data.btp_directory.ancestor_4[0]
    values = { "id" : "66666666-6666-4666-8666-666666666666", "parent_id" : "00000000-0000-4000-8000-000000000001", "features" : ["DEFAULT"], "labels" : {} }
  }
  expect_failures = [btp_directory.this]
}
