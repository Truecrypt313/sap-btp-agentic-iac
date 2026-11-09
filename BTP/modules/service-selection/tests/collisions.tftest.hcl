run "fixture" {
  command = plan
  module { source = "../landing-zone-config" }
  variables { configuration = yamldecode(file("../../landing-zone.yaml")) }
}
run "accept_distinct_keys" {
  command = plan
  variables {
    services = merge(run.fixture.configuration.environments.TEST.services, {
      alert_notification = merge(run.fixture.configuration.environments.TEST.services.alert_notification, { enabled = false })
    })
    catalog               = run.fixture.configuration.service_catalog
    name_prefix           = "test"
    existing_dev_baseline = false
  }
  assert {
    condition     = length(output.selection.entitlements) == 0
    error_message = "Disabled services must remain empty."
  }
}
run "test_alert_notification_standard" {
  command = plan
  variables {
    services              = run.fixture.configuration.environments.TEST.services
    catalog               = run.fixture.configuration.service_catalog
    name_prefix           = "test-project-abc"
    existing_dev_baseline = false
  }
  assert {
    condition = (
      toset(keys(output.selection.entitlements)) == toset(["alert_notification"]) &&
      output.selection.entitlements.alert_notification.service_name == "alert-notification" &&
      output.selection.entitlements.alert_notification.plan_name == "standard" &&
      output.selection.entitlements.alert_notification.amount == null &&
      output.selection.entitlements.alert_notification.plan_unique_identifier == null
    )
    error_message = "TEST must select exactly the standard Alert Notification entitlement without an invented numeric quota or plan identifier."
  }
  assert {
    condition = (
      toset(keys(output.selection.instances)) == toset(["alert_notification"]) &&
      output.selection.instances.alert_notification.offering == "alert-notification" &&
      output.selection.instances.alert_notification.plan == "standard" &&
      output.selection.instances.alert_notification.name == "test-project-abc-alert-notification" &&
      length(output.selection.subscriptions) == 0
    )
    error_message = "TEST must select exactly one standard Alert Notification instance and no subscriptions."
  }
}
run "reject_entitlement_catalog_collision" {
  command = plan
  variables {
    services              = merge(run.fixture.configuration.environments.TEST.services, { catalog = ["alert_standard"], entitlements = { catalog_alert_standard = { service_name = "other", plan_name = "other", amount = null, plan_unique_identifier = null } } })
    catalog               = run.fixture.configuration.service_catalog
    name_prefix           = "test"
    existing_dev_baseline = false
  }
  expect_failures = [output.selection]
}
run "reject_instance_catalog_collision" {
  command = plan
  variables {
    services              = merge(run.fixture.configuration.environments.TEST.services, { catalog = ["alert_standard"], instances = { catalog_alert_standard = merge(run.fixture.configuration.environments.DEV.services.alert_notification.instance_options, { name = "other", offering = "other", plan = "other" }) } })
    catalog               = run.fixture.configuration.service_catalog
    name_prefix           = "test"
    existing_dev_baseline = false
  }
  expect_failures = [output.selection]
}
run "reject_subscription_catalog_collision" {
  command = plan
  variables {
    services              = merge(run.fixture.configuration.environments.TEST.services, { catalog = ["feature_flags_dashboard"], subscriptions = { catalog_feature_flags_dashboard = { app_name = "other", plan_name = "other", parameters = null, parameters_key = null, timeouts = null } } })
    catalog               = run.fixture.configuration.service_catalog
    name_prefix           = "test"
    existing_dev_baseline = false
  }
  expect_failures = [output.selection]
}
run "reject_entitlement_preset_collision" {
  command = plan
  variables {
    services              = merge(run.fixture.configuration.environments.TEST.services, { alert_notification = merge(run.fixture.configuration.environments.DEV.services.alert_notification, { enabled = true }), entitlements = { alert_notification = { service_name = "other", plan_name = "other", amount = null, plan_unique_identifier = null } } })
    catalog               = run.fixture.configuration.service_catalog
    name_prefix           = "test"
    existing_dev_baseline = false
  }
  expect_failures = [output.selection]
}
run "reject_instance_preset_collision" {
  command = plan
  variables {
    services              = merge(run.fixture.configuration.environments.TEST.services, { alert_notification = merge(run.fixture.configuration.environments.DEV.services.alert_notification, { enabled = true }), instances = { alert_notification = merge(run.fixture.configuration.environments.DEV.services.alert_notification.instance_options, { name = "other", offering = "other", plan = "other" }) } })
    catalog               = run.fixture.configuration.service_catalog
    name_prefix           = "test"
    existing_dev_baseline = false
  }
  expect_failures = [output.selection]
}
run "reject_subscription_preset_collision" {
  command = plan
  variables {
    services              = merge(run.fixture.configuration.environments.TEST.services, { feature_flags = run.fixture.configuration.environments.DEV.services.feature_flags, subscriptions = { feature_flags_dashboard = { app_name = "other", plan_name = "other", parameters = null, parameters_key = null, timeouts = null } } })
    catalog               = run.fixture.configuration.service_catalog
    name_prefix           = "test"
    existing_dev_baseline = false
  }
  expect_failures = [output.selection]
}
