mock_provider "btp" {
  mock_data "btp_subaccount_service_plan" {
    defaults = { ready = true, shareable = true, supported_platforms = ["sapbtp"] }
  }
}
variables {
  subaccount_id = "11111111-1111-4111-8111-111111111111"
  name_prefix   = "test"
  catalog_valid = true
  selection = {
    entitlements  = {}
    subscriptions = {}
    instances = {
      one = {
        name       = "test-only-instance", offering = "mock-offering", plan = "mock-plan", serviceplan_id = null, use_plan_names = false,
        parameters = null, parameters_key = null, labels = null, shared = true, required_platform = null, timeouts = null
      }
    }
  }
}
run "ready_shareable_plan" {
  command = plan
}
run "reject_not_ready" {
  command = plan
  override_data {
    target = data.btp_subaccount_service_plan.this["one"]
    values = { ready = false, shareable = true }
  }
  expect_failures = [btp_subaccount_service_instance.this]
}
run "reject_not_shareable" {
  command = plan
  override_data {
    target = data.btp_subaccount_service_plan.this["one"]
    values = { ready = true, shareable = false }
  }
  expect_failures = [btp_subaccount_service_instance.this]
}
run "reject_missing_runtime_parameter" {
  command = plan
  variables {
    selection = {
      entitlements = {}, subscriptions = {}
      instances    = { one = { name = "test-only-instance", offering = "mock-offering", plan = "mock-plan", serviceplan_id = null, use_plan_names = false, parameters = null, parameters_key = "absent", labels = null, shared = true, required_platform = null, timeouts = null } }
    }
  }
  expect_failures = [btp_subaccount_service_instance.this]
}

run "reject_unsupported_platform" {
  command = plan
  variables {
    selection = {
      entitlements = {}, subscriptions = {}
      instances    = { one = { name = "test-only-instance", offering = "mock-offering", plan = "mock-plan", serviceplan_id = null, use_plan_names = false, parameters = null, parameters_key = null, labels = null, shared = true, required_platform = "cloudfoundry", timeouts = null } }
    }
  }
  expect_failures = [btp_subaccount_service_instance.this]
}
