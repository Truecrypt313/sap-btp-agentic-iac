# Independent Terraform normalization/jsonencode, not a Python hash imitation.
# Fixture captured from unchanged main before the modular split, Terraform 1.15.5.
variables {
  configuration     = yamldecode(file("../../landing-zone.yaml"))
  raw_configuration = yamldecode(file("../../landing-zone.yaml"))
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
