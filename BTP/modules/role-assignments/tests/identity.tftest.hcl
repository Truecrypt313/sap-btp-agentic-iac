mock_provider "btp" {}
variables {
  subaccount_id        = "11111111-1111-4111-8111-111111111111"
  reserved_assignments = [{ role_collection_name = "Custom Administrator", user_name = "admin@example.invalid", origin = "custom-idp" }]
  assignments          = { one = { role_collection_name = "Custom Administrator", user_name = "admin@example.invalid", group_name = null, attribute_name = null, attribute_value = null, origin = "custom-idp" } }
}
run "reject_reserved_custom_admin" {
  command         = plan
  expect_failures = [btp_subaccount_role_collection_assignment.this]
}
run "accept_different_origin" {
  command = plan
  variables { reserved_assignments = [{ role_collection_name = "Custom Administrator", user_name = "admin@example.invalid", origin = "other-idp" }] }
}
run "accept_different_role" {
  command = plan
  variables { reserved_assignments = [{ role_collection_name = "Viewer", user_name = "admin@example.invalid", origin = "custom-idp" }] }
}
run "reject_default_origin_duplicate" {
  command = plan
  variables {
    reserved_assignments = [{ role_collection_name = "Custom Administrator", user_name = "admin@example.invalid", origin = null }]
    assignments          = { one = { role_collection_name = "Custom Administrator", user_name = "admin@example.invalid", group_name = null, attribute_name = null, attribute_value = null, origin = "ldap" } }
  }
  expect_failures = [btp_subaccount_role_collection_assignment.this]
}
run "reject_duplicate_explicit_groups" {
  command = plan
  variables {
    assignments = {
      one = { role_collection_name = "Viewer", user_name = null, group_name = "team", attribute_name = null, attribute_value = null, origin = "idp" }
      two = { role_collection_name = "Viewer", user_name = null, group_name = "team", attribute_name = null, attribute_value = null, origin = "idp" }
    }
  }
  expect_failures = [btp_subaccount_role_collection_assignment.this]
}

run "managed_collection_uses_resource_name_without_lookup" {
  command = plan
  variables {
    managed_collections  = { auditor = "TEST_FeatureFlags_Auditor" }
    reserved_assignments = []
    assignments          = { auditor_user = { role_collection_key = "auditor", user_name = "reader@example.invalid", origin = "sap.default" } }
  }
  assert {
    condition = (
      length(data.btp_subaccount_role_collection.available) == 0 &&
      btp_subaccount_role_collection_assignment.this["auditor_user"].role_collection_name == "TEST_FeatureFlags_Auditor" &&
      btp_subaccount_role_collection_assignment.this["auditor_user"].origin == "sap.default"
    )
    error_message = "Managed bindings must retain their YAML address and use the resource output without an early external lookup."
  }
}
run "managed_collection_still_protects_reserved_admin" {
  command = plan
  variables {
    managed_collections = { administrator = "Custom Administrator" }
    assignments         = { one = { role_collection_key = "administrator", user_name = "admin@example.invalid", origin = "custom-idp" } }
  }
  expect_failures = [btp_subaccount_role_collection_assignment.this]
}
run "mixed_managed_and_external_collections" {
  command = plan
  variables {
    managed_collections  = { auditor = "TEST_FeatureFlags_Auditor" }
    reserved_assignments = []
    assignments = {
      managed  = { role_collection_key = "auditor", user_name = "reader@example.invalid", origin = "sap.default" }
      external = { role_collection_name = "Existing Viewer", group_name = "viewers", origin = "sap.default" }
    }
  }
  assert {
    condition = (
      toset(keys(data.btp_subaccount_role_collection.available)) == toset(["external"]) &&
      btp_subaccount_role_collection_assignment.this["external"].role_collection_name == "Existing Viewer" &&
      length(btp_subaccount_role_collection_assignment.this) == 2
    )
    error_message = "Only the external binding needs a lookup; existing assignment keys must remain unchanged."
  }
}
run "reject_unknown_managed_key" {
  command = plan
  variables {
    managed_collections  = { auditor = "TEST_FeatureFlags_Auditor" }
    reserved_assignments = []
    assignments          = { one = { role_collection_key = "missing", user_name = "reader@example.invalid", origin = "sap.default" } }
  }
  expect_failures = [var.assignments]
}
run "reject_managed_key_without_origin" {
  command = plan
  variables {
    managed_collections  = { auditor = "TEST_FeatureFlags_Auditor" }
    reserved_assignments = []
    assignments          = { one = { role_collection_key = "auditor", user_name = "reader@example.invalid" } }
  }
  expect_failures = [var.assignments]
}
run "reject_managed_collection_by_external_name" {
  command = plan
  variables {
    managed_collections  = { auditor = "TEST_FeatureFlags_Auditor" }
    reserved_assignments = []
    assignments          = { one = { role_collection_name = "TEST_FeatureFlags_Auditor", user_name = "reader@example.invalid", origin = "sap.default" } }
  }
  expect_failures = [var.assignments]
}
run "reject_both_collection_selectors" {
  command = plan
  variables {
    managed_collections  = { auditor = "TEST_FeatureFlags_Auditor" }
    reserved_assignments = []
    assignments          = { one = { role_collection_key = "auditor", role_collection_name = "Viewer", user_name = "reader@example.invalid", origin = "sap.default" } }
  }
  expect_failures = [var.assignments]
}
run "reject_neither_collection_selector" {
  command = plan
  variables {
    managed_collections  = { auditor = "TEST_FeatureFlags_Auditor" }
    reserved_assignments = []
    assignments          = { one = { user_name = "reader@example.invalid", origin = "sap.default" } }
  }
  expect_failures = [var.assignments]
}
