mock_provider "cloudfoundry" {}

variables {
  org_id = "22222222-2222-4222-8222-222222222222"
  spaces = {
    app = {
      name       = "test-app"
      managers   = ["manager@example.invalid"]
      developers = []
    }
    integration = {
      name       = "test-integration"
      managers   = []
      developers = ["developer@example.invalid"]
    }
  }
}

run "multiple_spaces_optional_memberships" {
  command = plan
  assert {
    condition     = length(cloudfoundry_space.this) == 2 && length(cloudfoundry_space_role.this) == 2
    error_message = "Create one instance per space and only explicitly configured role assignments."
  }
}

run "reject_duplicate_names" {
  command = plan
  variables {
    spaces = {
      one = { name = "same", managers = [], developers = [] }
      two = { name = "same", managers = [], developers = [] }
    }
  }
  expect_failures = [cloudfoundry_space.this]
}

run "extend_existing_space_without_managing_it" {
  command = plan
  variables {
    existing_space_ids = { project = "33333333-3333-4333-8333-333333333333" }
    spaces             = { project = { name = "existing", managers = [], developers = [], roles = { audit = { type = "space_auditor", username = "auditor@example.invalid" } } } }
  }
  assert {
    condition     = length(cloudfoundry_space.this) == 0 && length(cloudfoundry_space_role.this) == 1 && output.space_ids.project == "33333333-3333-4333-8333-333333333333"
    error_message = "Role-only extension must not create or re-own the existing space."
  }
}

run "reject_duplicate_legacy_role" {
  command = plan
  variables {
    existing_space_ids = { project = "33333333-3333-4333-8333-333333333333" }
    spaces             = { project = { name = "existing", managers = [], developers = [], roles = { one = { type = "space_manager", username = "manager@example.invalid" } } } }
    reserved_roles     = { old = { space_key = "project", type = "space_manager", username = "manager@example.invalid", user = null, origin = null } }
  }
  expect_failures = [cloudfoundry_space_role.this]
}

run "reject_unsupported_legacy_manager" {
  command = plan
  variables { spaces = { one = { name = "test", legacy_manager = { username = "admin@example.invalid" } } } }
  expect_failures = [var.spaces]
}
run "reject_unsupported_legacy_developer" {
  command = plan
  variables { spaces = { one = { name = "test", legacy_developer = { username = "admin@example.invalid" } } } }
  expect_failures = [var.spaces]
}
