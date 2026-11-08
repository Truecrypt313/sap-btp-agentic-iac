variables {
  account_type = "trial"
  environments = {
    TEST = { enabled = true, region = "us10", iaas_provider = "AWS", runtime = "cloudfoundry" }
  }
  catalog = [
    { region = "us10", iaas_provider = "AWS", environment = "cloudfoundry", supports_trial = true },
    { region = "eu10", iaas_provider = "AWS", environment = "cloudfoundry", supports_trial = false },
    { region = "eu20", iaas_provider = "AZURE", environment = "cloudfoundry", supports_trial = false },
    { region = "us20", iaas_provider = "AZURE", environment = "cloudfoundry", supports_trial = false }
  ]
}
run "aws_trial" {
  command = plan
  assert {
    condition     = output.regions.TEST == "us10"
    error_message = "The requested AWS Trial region must match the actual catalog."
  }
}
run "azure_enterprise" {
  command = plan
  variables {
    account_type = "enterprise"
    environments = { TEST = { enabled = true, region = "eu20", iaas_provider = "AZURE", runtime = "cloudfoundry" } }
  }
  assert {
    condition     = output.regions.TEST == "eu20"
    error_message = "Azure region selection must be supported."
  }
}
run "reject_region_iaas_mismatch" {
  command = plan
  variables {
    environments = { TEST = { enabled = true, region = "us10", iaas_provider = "AZURE", runtime = "cloudfoundry" } }
  }
  expect_failures = [output.regions]
}
run "reject_runtime_mismatch" {
  command = plan
  variables {
    environments = { TEST = { enabled = true, region = "us10", iaas_provider = "AWS", runtime = "kubernetes" } }
  }
  expect_failures = [output.regions]
}
run "reject_trial_unsupported_region" {
  command = plan
  variables {
    environments = { TEST = { enabled = true, region = "eu20", iaas_provider = "AZURE", runtime = "cloudfoundry" } }
  }
  expect_failures = [output.regions]
}
run "reject_ambiguous_discovery" {
  command = plan
  variables {
    account_type = "enterprise"
    environments = { TEST = { enabled = true, region = null, iaas_provider = "AWS", runtime = "cloudfoundry" } }
  }
  expect_failures = [output.regions]
}
run "discover_unique_trial_region" {
  command = plan
  variables {
    environments = { TEST = { enabled = true, region = null, iaas_provider = "AWS", runtime = "cloudfoundry" } }
  }
  assert {
    condition     = output.regions.TEST == "us10"
    error_message = "Automatic discovery must have exactly one candidate."
  }
}
