mock_provider "cloudfoundry" {}
mock_provider "tfe" {}
variables {
  project_id  = "test-neu"
  environment = "DEV"
}
run "inactive_project_reads_no_hcp_outputs_and_creates_no_spaces" {
  command = plan
  assert {
    condition     = length(data.tfe_outputs.project) == 0 && length(output.space_ids) == 0
    error_message = "No remote outputs, spaces or roles for the disabled project."
  }
}
run "reject_test_environment_in_dev_workspace" {
  command = plan
  variables { environment = "TEST" }
  expect_failures = [output.space_ids]
}
run "reject_prod_environment_in_dev_workspace" {
  command = plan
  variables { environment = "PROD" }
  expect_failures = [output.space_ids]
}
run "reject_unknown_environment" {
  command = plan
  variables { environment = "QA" }
  expect_failures = [var.environment]
}
run "reject_legacy_project" {
  command = plan
  variables { project_id = "project-abc" }
  expect_failures = [var.project_id]
}
