# Pure local plans of a provider-free module: no backend, credentials or infrastructure.
variables {
  configuration = yamldecode(file("../../landing-zone.yaml"))
}

run "current_trial_configuration" {
  command = plan
  assert {
    condition = (
      output.configuration.environments.TEST.enabled &&
      output.configuration.environments.TEST.cloud_foundry.enabled &&
      output.configuration.environments.TEST.cloud_foundry.plan == "trial" &&
      toset(keys(output.configuration.environments.TEST.cloud_foundry.spaces)) == toset(["project"]) &&
      output.configuration.environments.TEST.cloud_foundry.spaces.project.name == "test-space-project-abc" &&
      toset(keys(output.handoff_fingerprints)) == toset(["DEV", "TEST"])
    )
    error_message = "The current rollout must publish DEV and TEST identities, with TEST trial Cloud Foundry and exactly the project space named test-space-project-abc."
  }
  assert {
    condition     = !output.configuration.environments.PROD.enabled && !output.configuration.environments.DEV.services.work_zone.enabled
    error_message = "Unverified Trial services and PROD must remain disabled."
  }
}

run "reject_schema_version" {
  command = plan
  variables {
    configuration = merge(run.current_trial_configuration.configuration, { schema_version = 99 })
  }
  expect_failures = [var.configuration]
}

run "reject_invalid_costcenter" {
  command = plan
  variables {
    configuration = merge(run.current_trial_configuration.configuration, {
      environments = merge(run.current_trial_configuration.configuration.environments, {
        TEST = merge(run.current_trial_configuration.configuration.environments.TEST, { costcenter = "1234" })
      })
    })
  }
  expect_failures = [var.configuration]
}

run "reject_trial_production" {
  command = plan
  variables {
    configuration = merge(run.current_trial_configuration.configuration, {
      environments = merge(run.current_trial_configuration.configuration.environments, {
        PROD = merge(run.current_trial_configuration.configuration.environments.PROD, { enabled = true })
      })
    })
  }
  expect_failures = [var.configuration]
}

run "reject_spaces_without_cf" {
  command = plan
  variables {
    configuration = merge(run.current_trial_configuration.configuration, {
      environments = merge(run.current_trial_configuration.configuration.environments, {
        TEST = merge(run.current_trial_configuration.configuration.environments.TEST, {
          cloud_foundry = { enabled = false, spaces = { app = { name = "test-app" } } }
        })
      })
    })
  }
  expect_failures = [var.configuration]
}

run "reject_unverified_work_zone_plan" {
  command = plan
  variables {
    configuration = merge(run.current_trial_configuration.configuration, {
      environments = merge(run.current_trial_configuration.configuration.environments, {
        TEST = merge(run.current_trial_configuration.configuration.environments.TEST, {
          services = { work_zone = { enabled = true } }
        })
      })
    })
  }
  expect_failures = [var.configuration]
}

run "reject_duplicate_space_names" {
  command = plan
  variables {
    configuration = merge(run.current_trial_configuration.configuration, {
      environments = merge(run.current_trial_configuration.configuration.environments, {
        TEST = merge(run.current_trial_configuration.configuration.environments.TEST, {
          cloud_foundry = { enabled = true, spaces = { one = { name = "same" }, two = { name = "same" } } }
        })
      })
    })
  }
  expect_failures = [var.configuration]
}

run "enterprise_three_environments" {
  command = plan
  variables {
    configuration = merge(run.current_trial_configuration.configuration, {
      account_type = "enterprise"
      environments = {
        for stage, env in run.current_trial_configuration.configuration.environments : stage => merge(env, {
          enabled       = true
          beta_enabled  = stage != "PROD"
          cloud_foundry = merge(env.cloud_foundry, { enabled = true, plan = "standard" })
        })
      }
    })
  }
  assert {
    condition     = alltrue([for env in values(output.configuration.environments) : env.enabled && env.cloud_foundry.enabled])
    error_message = "Schema must support three simultaneous environments in an enterprise account."
  }
}

run "reject_readonly_raw_attribute" {
  command = plan
  variables {
    raw_configuration = { unsupported_provider_output = "not an input" }
  }
  expect_failures = [var.raw_configuration]
}

run "reject_subaccount_description_length" {
  command = plan
  variables {
    configuration = merge(run.current_trial_configuration.configuration, {
      environments = merge(run.current_trial_configuration.configuration.environments, {
        TEST = merge(run.current_trial_configuration.configuration.environments.TEST, { description = join("", [for i in range(301) : "x"]) })
      })
    })
  }
  expect_failures = [var.configuration]
}

run "reject_group_without_origin" {
  command = plan
  variables {
    configuration = merge(run.current_trial_configuration.configuration, {
      environments = merge(run.current_trial_configuration.configuration.environments, {
        TEST = merge(run.current_trial_configuration.configuration.environments.TEST, { role_assignments = { one = { role_collection_name = "Viewer", group_name = "group" } } })
      })
    })
  }
  expect_failures = [var.configuration]
}

run "reject_cf_two_subjects" {
  command = plan
  variables {
    configuration = merge(run.current_trial_configuration.configuration, {
      environments = merge(run.current_trial_configuration.configuration.environments, {
        DEV = merge(run.current_trial_configuration.configuration.environments.DEV, {
          cloud_foundry = merge(run.current_trial_configuration.configuration.environments.DEV.cloud_foundry, {
            spaces = { project = { name = "dev-project-abc", roles = { one = { type = "space_auditor", username = "example", user = "11111111-1111-4111-8111-111111111111" } } } }
          })
        })
      })
    })
  }
  expect_failures = [var.configuration]
}

run "reject_nonobject_parameters" {
  command = plan
  variables {
    configuration = merge(run.current_trial_configuration.configuration, {
      environments = merge(run.current_trial_configuration.configuration.environments, {
        DEV = merge(run.current_trial_configuration.configuration.environments.DEV, {
          cloud_foundry = merge(run.current_trial_configuration.configuration.environments.DEV.cloud_foundry, { parameters = "[]" })
        })
      })
    })
  }
  expect_failures = [var.configuration]
}

run "reject_unknown_catalog_profile" {
  command = plan
  variables {
    configuration = merge(run.current_trial_configuration.configuration, {
      service_catalog = { one = { service_name = "test-only", plan_name = "fixture-only", profiles = ["unknown"] } }
    })
  }
  expect_failures = [var.configuration]
}

run "handoff_space_change" {
  command = plan
  variables { configuration = merge(run.current_trial_configuration.configuration, {
    environments = merge(run.current_trial_configuration.configuration.environments, { DEV = merge(run.current_trial_configuration.configuration.environments.DEV, { cloud_foundry = merge(run.current_trial_configuration.configuration.environments.DEV.cloud_foundry, { spaces = { project = { name = "dev-project-abc", roles = { reader = { type = "space_auditor", username = "reader@example.invalid" } } } } }) }) })
  }) }
  assert {
    condition     = output.handoff_fingerprints.DEV == run.current_trial_configuration.handoff_fingerprints.DEV
    error_message = "Only BTP/CF identity changes may invalidate the handoff contract."
  }
}

run "handoff_service_change" {
  command = plan
  variables { configuration = merge(run.current_trial_configuration.configuration, {
    environments = merge(run.current_trial_configuration.configuration.environments, { DEV = merge(run.current_trial_configuration.configuration.environments.DEV, { services = merge(run.current_trial_configuration.configuration.environments.DEV.services, { work_zone = { enabled = true, plan = "standard" } }) }) })
  }) }
  assert {
    condition     = output.handoff_fingerprints.DEV == run.current_trial_configuration.handoff_fingerprints.DEV
    error_message = "Only BTP/CF identity changes may invalidate the handoff contract."
  }
}

run "handoff_identity_change" {
  command = plan
  variables { configuration = merge(run.current_trial_configuration.configuration, {
    environments = merge(run.current_trial_configuration.configuration.environments, { DEV = merge(run.current_trial_configuration.configuration.environments.DEV, { region = "ap21" }) })
  }) }
  assert {
    condition     = output.handoff_fingerprints.DEV != run.current_trial_configuration.handoff_fingerprints.DEV
    error_message = "Only BTP/CF identity changes may invalidate the handoff contract."
  }
}

run "reject_test_legacy" {
  command = plan
  variables { configuration = merge(run.current_trial_configuration.configuration, {
    environments = merge(run.current_trial_configuration.configuration.environments, { TEST = merge(run.current_trial_configuration.configuration.environments.TEST, {
      cloud_foundry = merge(run.current_trial_configuration.configuration.environments.TEST.cloud_foundry, { enabled = true, spaces = { app = { name = "test", legacy_manager = { username = "admin@example.invalid" } } } })
    }) })
  }) }
  expect_failures = [var.configuration]
}

run "reject_dev_other_legacy" {
  command = plan
  variables { configuration = merge(run.current_trial_configuration.configuration, {
    environments = merge(run.current_trial_configuration.configuration.environments, { DEV = merge(run.current_trial_configuration.configuration.environments.DEV, {
      cloud_foundry = merge(run.current_trial_configuration.configuration.environments.DEV.cloud_foundry, { enabled = true, spaces = { other = { name = "test", legacy_manager = { username = "admin@example.invalid" } } } })
    }) })
  }) }
  expect_failures = [var.configuration]
}

run "reject_direct_token_parameter" {
  command = plan
  variables { configuration = merge(run.current_trial_configuration.configuration, {
    environments = merge(run.current_trial_configuration.configuration.environments, { DEV = merge(run.current_trial_configuration.configuration.environments.DEV, {
      cloud_foundry = merge(run.current_trial_configuration.configuration.environments.DEV.cloud_foundry, { parameters = jsonencode({ nested = [{ token = "synthetic-placeholder" }] }) })
    }) })
  }) }
  expect_failures = [var.configuration]
}

run "reviewed_dev_handoff_contract" {
  command = plan
  assert {
    condition     = output.handoff_fingerprints.DEV == "444d0f16abd3373a17cdd4159c596f4ae06e585e60844cad15d4bf39bccbe879"
    error_message = "Review the cross-workspace protocol fixture whenever BTP-owned identity changes."
  }
}

run "reviewed_test_handoff_contract" {
  command = plan
  assert {
    condition     = output.handoff_fingerprints.TEST == "9d6c14dd0ff81edfcaa25e00dcaed301930770872bcbe88630cb0b2398d62ce0"
    error_message = "Review the TEST identity fixture when its subaccount or Cloud Foundry identity changes; keep the separate DEV fixture unchanged."
  }
}

run "test_identity_change_preserves_dev_handoff" {
  command = plan
  variables {
    configuration = merge(run.current_trial_configuration.configuration, {
      environments = merge(run.current_trial_configuration.configuration.environments, {
        TEST = merge(run.current_trial_configuration.configuration.environments.TEST, { name = "Renamed TEST" })
      })
    })
  }
  assert {
    condition = (
      output.handoff_fingerprints.TEST != run.current_trial_configuration.handoff_fingerprints.TEST &&
      output.handoff_fingerprints.DEV == run.current_trial_configuration.handoff_fingerprints.DEV
    )
    error_message = "A TEST identity change must invalidate only the TEST handoff, preserving the published DEV identity."
  }
}
