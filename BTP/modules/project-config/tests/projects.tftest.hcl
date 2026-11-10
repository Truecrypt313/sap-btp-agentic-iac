variables {
  document     = yamldecode(file("../../../examples/project.test-neu.mock.yaml"))
  raw_document = yamldecode(file("../../../examples/project.test-neu.mock.yaml"))
}
run "project_configuration_and_scoped_handoffs" {
  command = plan
  assert {
    condition     = toset(keys(output.handoff_fingerprints)) == toset(["DEV", "TEST"]) && output.configuration.environments.DEV.subdomain == "test-neu-dev" && jsonencode(output.handoff_fingerprints) == jsonencode(jsondecode(file("../../../scripts/fixtures/project-handoff-fingerprints.json")))
    error_message = "Both project stages must have isolated identity contracts."
  }
}
run "reject_project_id_aliasing" {
  command = plan
  variables { document = merge(yamldecode(file("../../../examples/project.test-neu.mock.yaml")), { project_id = "foreign" }) }
  expect_failures = [output.configuration]
}
run "reject_reserved_legacy_id" {
  command = plan
  variables { document = merge(yamldecode(file("../../../examples/project.test-neu.mock.yaml")), { project_id = "project-abc" }) }
  expect_failures = [var.document]
}
run "reject_inline_policies" {
  command = plan
  variables { raw_document = merge(yamldecode(file("../../../examples/project.test-neu.mock.yaml")), { policies = {} }) }
  expect_failures = [var.raw_document]
}
run "disabled_project_publishes_no_handoff" {
  command = plan
  variables { document = merge(yamldecode(file("../../../examples/project.test-neu.mock.yaml")), { deployment_enabled = false }) }
  assert {
    condition     = length(output.handoff_fingerprints) == 0
    error_message = "Project switch must gate contracts even when stage flags are true."
  }
}
