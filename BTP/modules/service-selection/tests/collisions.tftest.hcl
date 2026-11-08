run "fixture" {
  command = plan
  module { source = "../landing-zone-config" }
  variables { configuration = yamldecode(file("../../landing-zone.yaml")) }
}
run "accept_distinct_keys" {
  command = plan
  variables {
    services              = merge(run.fixture.configuration.environments.TEST.services, {})
    catalog               = run.fixture.configuration.service_catalog
    name_prefix           = "test"
    existing_dev_baseline = false
  }
  assert {
    condition     = length(output.selection.entitlements) == 0
    error_message = "Disabled services must remain empty."
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
