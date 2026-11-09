# Terraform generates an empty computed nested list for this provider mock.
# Verify that this actual data-source result blocks collection creation. Positive
# multi-role fixtures and identity/attribute negatives are tested in the rules.
mock_provider "btp" { override_during = plan }
variables {
  subaccount_id = "11111111-1111-4111-8111-111111111111"
  role_collections = { feature_flags_auditor = {
    name = "TEST_FeatureFlags_Auditor"
    roles = { dashboard = {
      name                 = "Feature Flags Service dashboard Auditor"
      role_template_name   = "FeatureFlags_Dashboard_Auditor"
      role_template_app_id = "feature-flags!b1765"
    } }
  } }
}
run "empty_catalog_read_blocks_collection" {
  command = plan
  assert {
    condition     = length(data.btp_subaccount_roles.available[0].values) == 0 && !module.catalog_validation.valid.feature_flags_auditor
    error_message = "An empty actual catalog must reach the validator and reject the collection."
  }
  expect_failures = [btp_subaccount_role_collection.this["feature_flags_auditor"]]
}
