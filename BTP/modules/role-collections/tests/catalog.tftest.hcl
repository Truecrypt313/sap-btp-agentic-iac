# Catalog mocks use the exact TEST values verified by the operator.
mock_provider "btp" {
  override_during = plan
}
variables {
  subaccount_id    = "11111111-1111-4111-8111-111111111111"
  role_collections = yamldecode(file("../../landing-zone.yaml")).environments.TEST.role_collections
}
run "least_privilege_test_collections" {
  command = plan
  assert {
    condition = (
      toset(keys(btp_subaccount_role_collection.this)) == toset(["feature_flags_administrator", "feature_flags_auditor"]) &&
      btp_subaccount_role_collection.this["feature_flags_administrator"].name == "TEST_FeatureFlags_Administrator" &&
      btp_subaccount_role_collection.this["feature_flags_auditor"].name == "TEST_FeatureFlags_Auditor" &&
      length(btp_subaccount_role_collection.this["feature_flags_administrator"].roles) == 1 &&
      length(btp_subaccount_role_collection.this["feature_flags_auditor"].roles) == 1 &&
      one(btp_subaccount_role_collection.this["feature_flags_auditor"].roles).role_template_name == "FeatureFlags_Dashboard_Auditor" &&
      one(btp_subaccount_role_collection.this["feature_flags_administrator"].roles).role_template_name == "FeatureFlags_Dashboard_Administrator"
    )
    error_message = "Create exactly two dedicated TEST collections with one role each; auditor must never inherit administrator permissions."
  }
}
run "empty_configuration_has_no_catalog_read" {
  command = plan
  variables { role_collections = {} }
  assert {
    condition     = length(btp_subaccount_role_collection.this) == 0 && length(data.btp_subaccount_roles.available) == 0
    error_message = "Environments without managed collections must not acquire IAM resources or lookups."
  }
}

run "reject_duplicate_collection_names" {
  command = plan
  variables {
    role_collections = {
      one = { name = "Duplicate", roles = { viewer = { name = "Viewer", role_template_name = "Viewer", role_template_app_id = "app" } } }
      two = { name = "Duplicate", roles = { viewer = { name = "Viewer", role_template_name = "Viewer", role_template_app_id = "app" } } }
    }
  }
  expect_failures = [var.role_collections]
}
run "reject_empty_roles" {
  command = plan
  variables { role_collections = { empty = { name = "Empty", roles = {} } } }
  expect_failures = [var.role_collections]
}
run "reject_duplicate_roles" {
  command = plan
  variables {
    role_collections = { duplicate = { name = "Duplicate Roles", roles = {
      one = { name = "Viewer", role_template_name = "Viewer", role_template_app_id = "app" }
      two = { name = "Viewer", role_template_name = "Viewer", role_template_app_id = "app" }
    } } }
  }
  expect_failures = [var.role_collections]
}

# SAP API reads remain real in production. Full catalog semantics are exercised
# in role-catalog-rules/tests without provider-mock collection restrictions.
override_module {
  target  = module.catalog_validation
  outputs = { valid = { feature_flags_administrator = true, feature_flags_auditor = true } }
}
run "reject_invalid_catalog_result" {
  command = plan
  override_module {
    target  = module.catalog_validation
    outputs = { valid = { feature_flags_administrator = true, feature_flags_auditor = false } }
  }
  expect_failures = [btp_subaccount_role_collection.this["feature_flags_auditor"]]
}
