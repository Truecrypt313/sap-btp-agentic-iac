# Explicit broker IDs still require a real plan lookup and all identity checks.
mock_provider "btp" {
  mock_data "btp_subaccount_service_plan" {
    defaults = {
      name      = "standard", offering_name = "alert-notification", ready = true,
      shareable = true, supported_platforms = ["sapbtp"]
    }
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
      by_id = {
        name              = "test-explicit-plan", offering = "alert-notification", plan = "standard",
        serviceplan_id    = "22222222-2222-4222-8222-222222222222", use_plan_names = false,
        parameters        = null, parameters_key = null, labels = null, shared = true,
        required_platform = "sapbtp", timeouts = null
      }
    }
  }
}
run "accept_verified_explicit_id" {
  command = plan
  assert {
    condition = (
      data.btp_subaccount_service_plan.this["by_id"].id == "22222222-2222-4222-8222-222222222222" &&
      btp_subaccount_service_instance.this["by_id"].serviceplan_id == data.btp_subaccount_service_plan.this["by_id"].id &&
      module.plan_validation["by_id"].valid
    )
    error_message = "Use the explicitly requested broker ID only after checking its actual identity and capabilities."
  }
}
run "reject_explicit_id_wrong_offering" {
  command = plan
  override_data {
    target = data.btp_subaccount_service_plan.this["by_id"]
    values = { offering_name = "other-offering" }
  }
  expect_failures = [btp_subaccount_service_instance.this]
}
run "reject_explicit_id_wrong_plan" {
  command = plan
  override_data {
    target = data.btp_subaccount_service_plan.this["by_id"]
    values = { name = "other-plan" }
  }
  expect_failures = [btp_subaccount_service_instance.this]
}
run "reject_explicit_id_not_ready" {
  command = plan
  override_data {
    target = data.btp_subaccount_service_plan.this["by_id"]
    values = { ready = false }
  }
  expect_failures = [btp_subaccount_service_instance.this]
}
run "reject_explicit_id_not_shareable" {
  command = plan
  override_data {
    target = data.btp_subaccount_service_plan.this["by_id"]
    values = { shareable = false }
  }
  expect_failures = [btp_subaccount_service_instance.this]
}
run "reject_explicit_id_wrong_platform" {
  command = plan
  override_data {
    target = data.btp_subaccount_service_plan.this["by_id"]
    values = { supported_platforms = ["other-platform"] }
  }
  expect_failures = [btp_subaccount_service_instance.this]
}
