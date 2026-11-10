# Independent Terraform normalization/jsonencode, not a Python hash imitation.
# Historical fixture tests the original migration without pinning future desired
# infrastructure. Active source/artifact consistency and legacy address/IAM guards
# remain separate. Use check_project_abc_compatibility.py for a specific refactor.
variables {
  configuration     = jsondecode(file("../../../scripts/fixtures/landing-zone.pre-modular.json")).raw
  raw_configuration = jsondecode(file("../../../scripts/fixtures/landing-zone.pre-modular.json")).raw
}

run "preserve_pre_modular_configuration_and_fingerprints" {
  command = plan

  assert {
    condition     = jsonencode(var.raw_configuration) == jsonencode(jsondecode(file("../../../scripts/fixtures/landing-zone.pre-modular.json")).raw)
    error_message = "The modular split changed values, data types or missing/explicit fields."
  }
  assert {
    condition     = jsonencode(output.configuration) == jsonencode(jsondecode(file("../../../scripts/fixtures/landing-zone.pre-modular.json")).normalized)
    error_message = "Terraform-normalized configuration must equal the independent pre-refactor snapshot."
  }
  assert {
    condition     = sha256(jsonencode(output.configuration)) == jsondecode(file("../../../scripts/fixtures/landing-zone.pre-modular.json")).configuration_fingerprint
    error_message = "The complete Terraform configuration fingerprint changed."
  }
  assert {
    condition     = jsonencode(output.handoff_fingerprints) == jsonencode(jsondecode(file("../../../scripts/fixtures/landing-zone.pre-modular.json")).handoff_fingerprints)
    error_message = "CF handoff fingerprints, including enabled environments, must remain identical."
  }
}
