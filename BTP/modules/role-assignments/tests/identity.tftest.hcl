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
