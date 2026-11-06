
# Zusätzliche Subaccounts neben unserem bestehenden DEV
variable "additional_subaccounts" {
  description = "Additional TEST and PROD subaccounts"

  type = map(object({
    region     = string
    costcenter = string
  }))

  # Zunächst keine zusätzlichen Ressourcen erstellen
  default = {}

  validation {
    condition = alltrue([
      for stage, config in var.additional_subaccounts :
      contains(["TEST", "PROD"], stage) &&
      contains(["us10", "ap21"], config.region) &&
      can(regex("^[0-9]{5}$", config.costcenter))
    ])
    error_message = "Only TEST/PROD, supported regions and 5-digit cost centers are allowed."
  }
}

resource "btp_subaccount" "additional" {
  for_each = var.additional_subaccounts

  name = "${each.key} ${var.project_name}"

  subdomain = lower(
    replace(
      "${each.key}-${var.project_name}-${random_uuid.uuid.result}",
      " ",
      "-"
    )
  )

  region       = each.value.region
  beta_enabled = each.key != "PROD"

  labels = {
    stage      = [each.key]
    costcenter = [each.value.costcenter]
  }
}
