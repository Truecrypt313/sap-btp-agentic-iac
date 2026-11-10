mock_provider "btp" {}
variables {
  project_id    = "test-neu"
  globalaccount = "mock-global"
}
run "disabled_project_has_no_resources_or_catalog_reads" {
  command = plan
  assert {
    condition     = length(btp_subaccount.environment) == 0 && length(module.environment) == 0 && length(module.directory.directory_id == null ? [] : [module.directory.directory_id]) == 0 && length(data.btp_globalaccount.current) == 0 && length(module.region_catalog) == 0 && length(module.service_catalog) == 0
    error_message = "Disabled project must create nothing and read no SAP catalog."
  }
  assert {
    condition     = !output.project_contract.deployment_enabled && length(output.project_contract.cloud_foundry_environments) == 0
    error_message = "No CF handoff may be published for an inactive project."
  }
}
run "reject_legacy_project_in_generic_root" {
  command = plan
  variables { project_id = "project-abc" }
  expect_failures = [var.project_id]
}
run "workspace_binding_is_project_scoped" {
  command = plan
  assert {
    condition     = terraform.workspace == output.project_contract.btp_workspace && output.project_contract.project_id == "test-neu"
    error_message = "Local test must use the isolated future project workspace."
  }
}
