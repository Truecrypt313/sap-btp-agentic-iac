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
  variables { inventory = [{ id = "00000001-1111-4111-8111-111111111111", name = "test_neu", project_ids = [] }] }
  assert {
    condition     = !output.unique
    error_message = "Name collision is case insensitive, even without a project label."
  }
}
run "same_project_requires_existing_reference" {
  command = plan
  variables { inventory = [{ id = "00000002-1111-4111-8111-111111111111", name = "Renamed Directory", project_ids = ["test-neu"] }] }
  assert {
    condition     = !output.unique
    error_message = "An already assigned project cannot receive a duplicate directory under another name."
  }
}
run "collision_in_later_inventory_row_is_detected" {
  command = plan
  variables { inventory = [{ id = "00000003-1111-4111-8111-111111111111", name = "Other", project_ids = ["other"] }, { id = "00000004-1111-4111-8111-111111111111", name = "Test_Neu", project_ids = [] }] }
  assert {
    condition     = !output.unique
    error_message = "Every directory inventory row must be checked."
  }
}
run "unrelated_directories_do_not_block_project" {
  command = plan
  variables { inventory = [{ id = "00000005-1111-4111-8111-111111111111", name = "Other", project_ids = ["other"] }, { id = "00000006-1111-4111-8111-111111111111", name = "Shared Parent", project_ids = [] }] }
  assert {
    condition     = output.unique
    error_message = "Unrelated project and shared parent directories remain allowed."
  }
}

run "owned_id_is_accepted_with_same_name_and_project" {
  command = plan
  variables {
    managed_id = "11111111-1111-4111-8111-111111111111"
    inventory  = [{ id = "11111111-1111-4111-8111-111111111111", name = "Test_Neu", project_ids = ["test-neu"] }]
  }
  assert {
    condition     = output.unique
    error_message = "The state-owned actual ID must pass repeat plans."
  }
}
run "owned_id_remains_owned_after_metadata_drift" {
  command = plan
  variables {
    managed_id = "11111111-1111-4111-8111-111111111111"
    inventory  = [{ id = "11111111-1111-4111-8111-111111111111", name = "Changed", project_ids = ["changed"] }]
  }
  assert {
    condition     = output.unique
    error_message = "Names and labels must never determine ownership."
  }
}
run "foreign_id_with_same_project_is_rejected_even_alongside_owned_id" {
  command = plan
  variables {
    managed_id = "11111111-1111-4111-8111-111111111111"
    inventory = [
      { id = "11111111-1111-4111-8111-111111111111", name = "Test_Neu", project_ids = ["test-neu"] },
      { id = "22222222-2222-4222-8222-222222222222", name = "Other", project_ids = ["test-neu"] }
    ]
  }
  assert {
    condition     = !output.unique
    error_message = "Exempt only the actual owned ID, never another project-labelled ID."
  }
}
run "foreign_id_with_same_name_is_rejected_alongside_owned_id" {
  command = plan
  variables {
    managed_id = "11111111-1111-4111-8111-111111111111"
    inventory = [
      { id = "11111111-1111-4111-8111-111111111111", name = "Changed", project_ids = [] },
      { id = "22222222-2222-4222-8222-222222222222", name = "test_neu", project_ids = [] }
    ]
  }
  assert {
    condition     = !output.unique
    error_message = "An owned resource does not authorize any foreign name collision."
  }
}
run "owned_id_missing_from_inventory_blocks_recreation" {
  command = plan
  variables { managed_id = "11111111-1111-4111-8111-111111111111" }
  assert {
    condition     = !output.unique
    error_message = "A missing owned ID requires investigation, not recreation."
  }
}
