# Plan-only mocks: the assigned Alert entitlement has a known ID, while newly
# selected Feature Flags entitlements keep their IDs unknown until apply.
mock_provider "btp" {
  override_during = apply
  mock_data "btp_subaccount_service_plan" {
    defaults = {
      id                  = "22222222-2222-4222-8222-222222222222", name = "standard", offering_name = "alert-notification",
      ready               = true, shareable = true,
      supported_platforms = ["sapbtp"]
    }
  }
}

variables {
  subaccount_id = "11111111-1111-4111-8111-111111111111"
  name_prefix   = "test"
  catalog_valid = true
  selection = {
    entitlements = {
      # Deliberately different from the instance key, as with custom YAML entries.
      catalog_alert = { service_name = "alert-notification", plan_name = "standard", amount = null, plan_unique_identifier = null }
      flags         = { service_name = "feature-flags", plan_name = "lite", amount = null, plan_unique_identifier = null }
      dashboard     = { service_name = "feature-flags-dashboard", plan_name = "dashboard", amount = null, plan_unique_identifier = null }
    }
    subscriptions = {}
    instances = {
      alert_notification = {
        name           = "test-project-abc-alert-notification", offering = "alert-notification", plan = "standard",
        serviceplan_id = null, use_plan_names = false, parameters = null, parameters_key = null,
        labels         = null, shared = true, required_platform = "sapbtp", timeouts = null
      }
    }
  }
}

override_resource {
  target          = btp_subaccount_entitlement.this["catalog_alert"]
  override_during = plan
  values          = { id = "mock-assigned-alert-entitlement" }
}

run "feature_flags_do_not_defer_existing_alert_plan" {
  command = plan
  assert {
    condition = (
      data.btp_subaccount_service_plan.this["alert_notification"].id == "22222222-2222-4222-8222-222222222222" &&
      btp_subaccount_service_instance.this["alert_notification"].serviceplan_id == "22222222-2222-4222-8222-222222222222" &&
      module.plan_validation["alert_notification"].valid
    )
    error_message = "Unrelated pending Feature Flags entitlements must not make the existing Alert broker plan ID unknown or bypass its validation."
  }
}

run "new_matching_entitlement_still_defers_lookup" {
  command = plan
  override_resource {
    target          = btp_subaccount_entitlement.this["catalog_alert"]
    override_during = apply
    values          = { id = "mock-new-alert-entitlement" }
  }
  # An early read would fail the unchanged service-instance identity precondition.
  override_data {
    target = data.btp_subaccount_service_plan.this["alert_notification"]
    values = { offering_name = "not-entitled-yet" }
  }
}

run "explicit_id_uses_only_matching_entitlement" {
  command = plan
  variables {
    selection = {
      entitlements = {
        catalog_alert = { service_name = "alert-notification", plan_name = "standard", amount = null, plan_unique_identifier = null }
        flags         = { service_name = "feature-flags", plan_name = "lite", amount = null, plan_unique_identifier = null }
        dashboard     = { service_name = "feature-flags-dashboard", plan_name = "dashboard", amount = null, plan_unique_identifier = null }
      }
      subscriptions = {}
      instances = {
        alert_notification = {
          name           = "test-project-abc-alert-notification", offering = "alert-notification", plan = "standard",
          serviceplan_id = "22222222-2222-4222-8222-222222222222", use_plan_names = false, parameters = null, parameters_key = null,
          labels         = null, shared = true, required_platform = "sapbtp", timeouts = null
        }
      }
    }
  }
  assert {
    condition = (
      data.btp_subaccount_service_plan.this["alert_notification"].offering_name == "alert-notification" &&
      btp_subaccount_service_instance.this["alert_notification"].serviceplan_id == "22222222-2222-4222-8222-222222222222" &&
      module.plan_validation["alert_notification"].valid
    )
    error_message = "An explicit broker ID must still be read and validated without depending on unrelated Feature Flags assignments."
  }
}
