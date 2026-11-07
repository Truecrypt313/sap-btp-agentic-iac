
# Zusätzliche Subaccounts neben unserem bestehenden DEV
variable "additional_subaccounts" {
  description = "Additional TEST and PROD subaccounts"

  type = map(object({
    region     = string
    costcenter = string
  }))

  # Deprecated migration input: YAML owns the desired subaccounts.
  # A nonempty HCP override must match YAML in compatibility mode.
  default = {}

  validation {
    condition = alltrue([
      for stage, config in var.additional_subaccounts :
      contains(["TEST", "PROD"], stage) &&
      can(regex("^[a-z][a-z0-9-]+$", config.region)) &&
      can(regex("^[0-9]{5}$", config.costcenter))
    ])
    error_message = "Only TEST/PROD, region codes and 5-digit cost centers are allowed; actual compatibility comes from btp_regions."
  }
}

resource "btp_subaccount" "additional" {
  for_each = local.additional_environments

  name = coalesce(each.value.name, "${each.key} ${local.project_name}")

  subdomain = each.value.subdomain != null ? each.value.subdomain : lower(
    replace(
      "${each.key}-${local.project_name}-${random_uuid.uuid.result}",
      " ",
      "-"
    )
  )

  region                = module.region_catalog.regions[each.key]
  description           = each.value.description
  parent_id             = each.value.parent_id
  usage                 = each.value.usage
  skip_auto_entitlement = each.value.skip_auto_entitlement
  beta_enabled          = each.value.beta_enabled

  labels = merge(each.value.labels, {
    stage      = [each.key]
    costcenter = [each.value.costcenter]
  })

  lifecycle {
    prevent_destroy = true
  }
}
