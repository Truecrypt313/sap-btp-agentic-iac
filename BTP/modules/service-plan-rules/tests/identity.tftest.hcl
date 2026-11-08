variables {
  actual            = { name = "standard", offering_name = "alert-notification", ready = true, shareable = true, supported_platforms = ["sapbtp"] }
  offering          = "alert-notification"
  plan              = "standard"
  shared            = true
  required_platform = "sapbtp"
}
run "accept_exact_identity" {
  command = plan
  assert {
    condition     = output.valid
    error_message = "Matching actual plan must be accepted."
  }
}
run "reject_wrong_offering" {
  command = plan
  variables { actual = merge({ name = "standard", offering_name = "alert-notification", ready = true, shareable = true, supported_platforms = ["sapbtp"] }, { offering_name = "other-service" }) }
  assert {
    condition     = !output.valid
    error_message = "Mismatched/unavailable actual plan must be rejected."
  }
}
run "reject_wrong_plan" {
  command = plan
  variables { actual = merge({ name = "standard", offering_name = "alert-notification", ready = true, shareable = true, supported_platforms = ["sapbtp"] }, { name = "other-plan" }) }
  assert {
    condition     = !output.valid
    error_message = "Mismatched/unavailable actual plan must be rejected."
  }
}
run "reject_not_ready" {
  command = plan
  variables { actual = merge({ name = "standard", offering_name = "alert-notification", ready = true, shareable = true, supported_platforms = ["sapbtp"] }, { ready = false }) }
  assert {
    condition     = !output.valid
    error_message = "Mismatched/unavailable actual plan must be rejected."
  }
}
run "reject_not_shareable" {
  command = plan
  variables { actual = merge({ name = "standard", offering_name = "alert-notification", ready = true, shareable = true, supported_platforms = ["sapbtp"] }, { shareable = false }) }
  assert {
    condition     = !output.valid
    error_message = "Mismatched/unavailable actual plan must be rejected."
  }
}
run "reject_wrong_platform" {
  command = plan
  variables { actual = merge({ name = "standard", offering_name = "alert-notification", ready = true, shareable = true, supported_platforms = ["sapbtp"] }, { supported_platforms = ["other-platform"] }) }
  assert {
    condition     = !output.valid
    error_message = "Mismatched/unavailable actual plan must be rejected."
  }
}
