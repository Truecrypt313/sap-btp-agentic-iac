# The offline runner copies the enterprise YAML to the canonical path ONLY in its temporary checkout.
# Every provider is mocked; all runs use command=plan. No real SAP/HCP calls.
mock_provider "btp" {
  override_during = plan
  mock_data "btp_globalaccount" {
    defaults = { subdomain = "mock-globalaccount", license_type = "TRIAL", id = "00000000-0000-4000-8000-000000000001" }
  }


  mock_data "btp_subaccount_entitlements" { defaults = { values = {} } }
  mock_data "btp_subaccount_service_plan" {
    defaults = { ready = true, shareable = true, supported_platforms = ["sapbtp", "cloudfoundry"] }
  }


  mock_data "btp_subaccount_subscriptions" {
    defaults = { values = { app_name = "feature-flags-dashboard", plan_name = "dashboard" } }
  }
  mock_data "btp_subaccount_environments" {
    defaults = { values = { service_name = "cloudfoundry", environment_type = "cloudfoundry", plan_name = "standard", landscape_label = "cf-us10-001" } }
  }
  mock_resource "btp_subaccount_environment_instance" {
    defaults = { labels = "{\"API Endpoint\":\"https://api.example.invalid\",\"Org ID\":\"mock-org\"}" }
  }
}
mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = { result = "11111111-1111-4111-8111-111111111111" }
  }
}

override_resource {
  target          = random_uuid.uuid
  override_during = plan
  values          = { result = "11111111-1111-4111-8111-111111111111" }
}

variables {
  globalaccount               = "mock-globalaccount"
  subaccount_emergency_admins = ["admin@example.invalid"]
  additional_subaccounts = {
    TEST = { region = "us10", costcenter = "12345" }
  }
}

run "enterprise_template_expands_optional_services" {
  command = plan
  override_data {
    target = data.btp_subaccount_environments.all
    values = { values = { service_name = "cloudfoundry", environment_type = "cloudfoundry", plan_name = "standard", landscape_label = "cf-us10-001" } }
  }

  override_module {
    target  = module.region_catalog
    outputs = { regions = { DEV = "us10", TEST = "ap21", PROD = "eu10" } }
  }
  override_data {
    target = data.btp_globalaccount.current
    values = { license_type = "CUSTOMER", subdomain = "mock-globalaccount", id = "00000000-0000-4000-8000-000000000001" }
  }
  variables {
    configuration_mode     = "yaml"
    additional_subaccounts = {}
  }
  assert {
    condition = (
      length(btp_subaccount.additional) == 2 &&
      length(output.cloud_foundry_environments) == 3 &&
      length(module.environment["TEST"].service_instance_ids) == 2 &&
      length(module.environment["PROD"].service_instance_ids) == 2
    )
    error_message = "The enterprise template must expand TEST/PROD services and all three CF environments."
  }
}


override_module {
  target  = module.region_catalog
  outputs = { regions = { DEV = "us10", TEST = "us10", PROD = "eu10" } }
}
override_module {
  target  = module.service_catalog
  outputs = { valid = true }
}

override_data {
  target = data.btp_subaccount_environments.all
  values = { values = { service_name = "cloudfoundry", environment_type = "cloudfoundry", plan_name = "trial", landscape_label = "cf-us10-001" } }
}
