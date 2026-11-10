variables {
  project_id = "test-neu"
  name       = "Test_Neu"
  inventory  = []
}
run "empty_inventory_allows_new_directory" {
  command = plan
  assert {
    condition     = output.unique
    error_message = "Empty inventory has no collision."
  }
}
run "same_name_requires_existing_reference" {
  command = plan
  variables { inventory = [{ name = "test_neu", project_ids = [] }] }
  assert {
    condition     = !output.unique
    error_message = "Name collision is case insensitive, even without a project label."
  }
}
run "same_project_requires_existing_reference" {
  command = plan
  variables { inventory = [{ name = "Renamed Directory", project_ids = ["test-neu"] }] }
  assert {
    condition     = !output.unique
    error_message = "An already assigned project cannot receive a duplicate directory under another name."
  }
}
run "collision_in_later_inventory_row_is_detected" {
  command = plan
  variables { inventory = [{ name = "Other", project_ids = ["other"] }, { name = "Test_Neu", project_ids = [] }] }
  assert {
    condition     = !output.unique
    error_message = "Every directory inventory row must be checked."
  }
}
run "unrelated_directories_do_not_block_project" {
  command = plan
  variables { inventory = [{ name = "Other", project_ids = ["other"] }, { name = "Shared Parent", project_ids = [] }] }
  assert {
    condition     = output.unique
    error_message = "Unrelated project and shared parent directories remain allowed."
  }
}
