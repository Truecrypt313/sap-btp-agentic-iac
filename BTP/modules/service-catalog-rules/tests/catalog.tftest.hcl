# Synthetic catalog fixtures, never deployable service/plan recommendations.
variables {
  environments = {
    DEV  = { parent_id = null, iaas_provider = "AWS" }
    TEST = { parent_id = null, iaas_provider = "AWS" }
  }
  regions          = { DEV = "us10", TEST = "us10" }
  globalaccount_id = "global"
  entitlements = {
    DEV  = { one = { service_name = "mock-service", plan_name = "mock-plan", amount = 1, plan_unique_identifier = null } }
    TEST = { one = { service_name = "mock-service", plan_name = "mock-plan", amount = 1, plan_unique_identifier = null } }
  }
  global_catalog = {
    one = { service_name = "mock-service", plan_name = "mock-plan", plan_unique_identifier = "mock-id", category = "SERVICE", quota_remaining = 2,
    datacenter_information = { us10 = { dc_region = "us10", dc_iaas_provider = "AWS" } } }
  }
  directory_catalog   = {}
  current_allocations = { DEV = {}, TEST = {} }
}
run "aggregate_exact_quota" {
  command = plan
  assert {
    condition     = output.valid
    error_message = "Two environments may share exactly the available quota."
  }
}
run "reject_combined_overcommit" {
  command = plan
  variables {
    global_catalog = { one = { service_name = "mock-service", plan_name = "mock-plan", plan_unique_identifier = "mock-id", category = "SERVICE", quota_remaining = 1, datacenter_information = { us10 = { dc_region = "us10", dc_iaas_provider = "AWS" } } } }
  }
  expect_failures = [output.valid]
}
run "reject_unknown_plan" {
  command = plan
  variables { global_catalog = {} }
  expect_failures = [output.valid]
}
run "reject_unavailable_region" {
  command = plan
  variables { regions = { DEV = "eu20", TEST = "eu20" } }
  expect_failures = [output.valid]
}
run "reject_missing_regional_evidence" {
  command = plan
  variables {
    global_catalog = { one = { service_name = "mock-service", plan_name = "mock-plan", plan_unique_identifier = "mock-id", category = "SERVICE", quota_remaining = 2, datacenter_information = {} } }
  }
  expect_failures = [output.valid]
}
run "reject_ambiguous_pricing_plans" {
  command = plan
  variables {
    global_catalog = {
      one = { service_name = "mock-service", plan_name = "mock-plan", plan_unique_identifier = "mock-id", category = "SERVICE", quota_remaining = 2, datacenter_information = { us10 = { dc_region = "us10", dc_iaas_provider = "AWS" } } }
      two = { service_name = "mock-service", plan_name = "mock-plan", plan_unique_identifier = "other-id", category = "SERVICE", quota_remaining = 2, datacenter_information = { us10 = { dc_region = "us10", dc_iaas_provider = "AWS" } } }
    }
  }
  expect_failures = [output.valid]
}
run "retain_existing_allocations" {
  command = plan
  variables {
    global_catalog = { one = { service_name = "mock-service", plan_name = "mock-plan", plan_unique_identifier = "mock-id", category = "SERVICE", quota_remaining = 0, datacenter_information = { us10 = { dc_region = "us10", dc_iaas_provider = "AWS" } } } }
    current_allocations = {
      DEV  = { one = { service_name = "mock-service", plan_name = "mock-plan", plan_unique_identifier = "mock-id", quota_assigned = 1 } }
      TEST = { one = { service_name = "mock-service", plan_name = "mock-plan", plan_unique_identifier = "mock-id", quota_assigned = 1 } }
    }
  }
  assert {
    condition     = output.valid
    error_message = "Already assigned quota must not be charged twice."
  }
}
run "reject_amount_for_application" {
  command = plan
  variables {
    global_catalog = { one = { service_name = "mock-service", plan_name = "mock-plan", plan_unique_identifier = "mock-id", category = "APPLICATION", quota_remaining = 2, datacenter_information = { us10 = { dc_region = "us10", dc_iaas_provider = "AWS" } } } }
  }
  expect_failures = [output.valid]
}
run "reject_missing_numeric_quota" {
  command = plan
  variables {
    entitlements = {
      DEV  = { one = { service_name = "mock-service", plan_name = "mock-plan", amount = null, plan_unique_identifier = null } }
      TEST = { one = { service_name = "mock-service", plan_name = "mock-plan", amount = null, plan_unique_identifier = null } }
    }
  }
  expect_failures = [output.valid]
}
run "reject_directory_budget" {
  command = plan
  variables {
    environments      = { DEV = { parent_id = "directory", iaas_provider = "AWS" }, TEST = { parent_id = "directory", iaas_provider = "AWS" } }
    directory_catalog = { directory = { one = { service_name = "mock-service", plan_name = "mock-plan", plan_unique_identifier = "mock-id", category = "SERVICE", quota_remaining = 1 } } }
  }
  expect_failures = [output.valid]
}
