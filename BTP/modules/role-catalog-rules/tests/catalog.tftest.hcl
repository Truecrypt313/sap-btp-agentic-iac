# Provider-free, full catalog fixtures; no network or infrastructure.
variables {
  requested = {
    administrator = [{ name = "Feature Flags Service dashboard Administrator", role_template_name = "FeatureFlags_Dashboard_Administrator", role_template_app_id = "feature-flags!b1765" }]
    auditor       = [{ name = "Feature Flags Service dashboard Auditor", role_template_name = "FeatureFlags_Dashboard_Auditor", role_template_app_id = "feature-flags!b1765" }]
  }
  actual = [{ "name" : "Feature Flags Service dashboard Administrator", "role_template_name" : "FeatureFlags_Dashboard_Administrator", "app_id" : "feature-flags!b1765", "attribute_list" : [] }, { "name" : "Feature Flags Service dashboard Auditor", "role_template_name" : "FeatureFlags_Dashboard_Auditor", "app_id" : "feature-flags!b1765", "attribute_list" : [] }]
}
run "accept_exact_test_catalog" {
  command = plan
  assert {
    condition     = output.valid.administrator && output.valid.auditor
    error_message = "Both verified role identities must be accepted."
  }
}
run "wrong_name" {
  command = plan
  variables { actual = [{ "name" : "Feature Flags Service dashboard Administrator", "role_template_name" : "FeatureFlags_Dashboard_Administrator", "app_id" : "feature-flags!b1765", "attribute_list" : [] }, { "name" : "Feature Flags Service Dashboard Auditor", "role_template_name" : "FeatureFlags_Dashboard_Auditor", "app_id" : "feature-flags!b1765", "attribute_list" : [] }] }
  assert {
    condition     = output.valid.administrator == true && output.valid.auditor == false
    error_message = "Catalog identity and attribute validation must fail only the affected role collection."
  }
}
run "wrong_role_template_name" {
  command = plan
  variables { actual = [{ "name" : "Feature Flags Service dashboard Administrator", "role_template_name" : "FeatureFlags_Dashboard_Administrator", "app_id" : "feature-flags!b1765", "attribute_list" : [] }, { "name" : "Feature Flags Service dashboard Auditor", "role_template_name" : "wrong-template", "app_id" : "feature-flags!b1765", "attribute_list" : [] }] }
  assert {
    condition     = output.valid.administrator == true && output.valid.auditor == false
    error_message = "Catalog identity and attribute validation must fail only the affected role collection."
  }
}
run "wrong_app_id" {
  command = plan
  variables { actual = [{ "name" : "Feature Flags Service dashboard Administrator", "role_template_name" : "FeatureFlags_Dashboard_Administrator", "app_id" : "feature-flags!b1765", "attribute_list" : [] }, { "name" : "Feature Flags Service dashboard Auditor", "role_template_name" : "FeatureFlags_Dashboard_Auditor", "app_id" : "wrong-application", "attribute_list" : [] }] }
  assert {
    condition     = output.valid.administrator == true && output.valid.auditor == false
    error_message = "Catalog identity and attribute validation must fail only the affected role collection."
  }
}
run "missing_catalog" {
  command = plan
  variables { actual = [] }
  assert {
    condition     = output.valid.administrator == false && output.valid.auditor == false
    error_message = "Catalog identity and attribute validation must fail only the affected role collection."
  }
}
run "ambiguous_catalog" {
  command = plan
  variables { actual = [{ "name" : "Feature Flags Service dashboard Administrator", "role_template_name" : "FeatureFlags_Dashboard_Administrator", "app_id" : "feature-flags!b1765", "attribute_list" : [] }, { "name" : "Feature Flags Service dashboard Auditor", "role_template_name" : "FeatureFlags_Dashboard_Auditor", "app_id" : "feature-flags!b1765", "attribute_list" : [] }, { "name" : "Feature Flags Service dashboard Auditor", "role_template_name" : "FeatureFlags_Dashboard_Auditor", "app_id" : "feature-flags!b1765", "attribute_list" : [] }] }
  assert {
    condition     = output.valid.administrator == true && output.valid.auditor == false
    error_message = "Catalog identity and attribute validation must fail only the affected role collection."
  }
}
run "unbound_required_attribute" {
  command = plan
  variables { actual = [{ "name" : "Feature Flags Service dashboard Administrator", "role_template_name" : "FeatureFlags_Dashboard_Administrator", "app_id" : "feature-flags!b1765", "attribute_list" : [] }, { "name" : "Feature Flags Service dashboard Auditor", "role_template_name" : "FeatureFlags_Dashboard_Auditor", "app_id" : "feature-flags!b1765", "attribute_list" : [{ "value_required" : true, "attribute_values" : [] }] }] }
  assert {
    condition     = output.valid.administrator == true && output.valid.auditor == false
    error_message = "Catalog identity and attribute validation must fail only the affected role collection."
  }
}
run "bound_required_attribute" {
  command = plan
  variables { actual = [{ "name" : "Feature Flags Service dashboard Administrator", "role_template_name" : "FeatureFlags_Dashboard_Administrator", "app_id" : "feature-flags!b1765", "attribute_list" : [] }, { "name" : "Feature Flags Service dashboard Auditor", "role_template_name" : "FeatureFlags_Dashboard_Auditor", "app_id" : "feature-flags!b1765", "attribute_list" : [{ "value_required" : true, "attribute_values" : ["restricted"] }] }] }
  assert {
    condition     = output.valid.administrator == true && output.valid.auditor == true
    error_message = "Catalog identity and attribute validation must fail only the affected role collection."
  }
}
