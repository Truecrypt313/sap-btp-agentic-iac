mock_provider "btp" {
  mock_data "btp_subaccount_subscriptions" {
    defaults = { values = { app_name = "feature-flags-dashboard", plan_name = "dashboard" } }
  }
}
run "fixture" {
  command = plan
  module { source = "../landing-zone-config" }
  variables { configuration = yamldecode(file("../../landing-zone.yaml")) }
}
run "reject_mismatched_explicit_id" {
  command = plan
  variables {
    subaccount_id = "11111111-1111-4111-8111-111111111111"
    catalog_valid = true
    configuration = merge(run.fixture.configuration.environments.DEV.services, {
      alert_notification = merge(run.fixture.configuration.environments.DEV.services.alert_notification, {
        instance_options = merge(run.fixture.configuration.environments.DEV.services.alert_notification.instance_options, { serviceplan_id = "22222222-2222-4222-8222-222222222222" })
      })
    })
  }
  # The pure rules suite verifies actual offering/plan mismatches; this test
  # proves the address-preserving DEV resource enforces their false result.
  override_module {
    target  = module.alert_plan_validation
    outputs = { valid = false }
  }
  expect_failures = [btp_subaccount_service_instance.alert_notification_service_standard]
}
