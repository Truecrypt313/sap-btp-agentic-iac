terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "~> 1.27.0"
    }
  }
}

variable "subaccount_id" {
  type = string
}
variable "name_prefix" {
  type = string
}
variable "selection" { type = any }
variable "catalog_valid" { type = bool }
variable "instance_parameters" {
  type      = map(string)
  sensitive = true
  default   = {}
}
variable "subscription_parameters" {
  type      = map(string)
  sensitive = true
  default   = {}
}
variable "existing_dev_baseline" {
  description = "Keep existing DEV entitlements/subscriptions in module.srvc_baseline, never manage them twice."
  type        = bool
  default     = false
}

locals {
  entitlements  = var.selection.entitlements
  instances     = var.selection.instances
  subscriptions = var.selection.subscriptions
}

resource "btp_subaccount_entitlement" "this" {
  for_each = local.entitlements

  subaccount_id          = var.subaccount_id
  service_name           = each.value.service_name
  plan_name              = each.value.plan_name
  amount                 = each.value.amount
  plan_unique_identifier = each.value.plan_unique_identifier

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = var.catalog_valid
      error_message = "The actual regional entitlement/quota catalog does not permit this selection."
    }
    precondition {
      condition     = length(distinct([for e in values(local.entitlements) : "${e.service_name}/${e.plan_name}"])) == length(local.entitlements)
      error_message = "The same service/plan must not be entitled twice in this module."
    }
    precondition {
      condition = !var.existing_dev_baseline || !contains([
        "alert-notification/standard", "feature-flags/lite", "feature-flags-dashboard/dashboard"
      ], "${each.value.service_name}/${each.value.plan_name}")
      error_message = "This entitlement is already owned by the legacy DEV baseline."
    }
  }
}

# Resolve actual broker plan IDs. No guessed IDs and no fallback to another plan.
data "btp_subaccount_service_plan" "this" {
  for_each = local.instances

  subaccount_id = var.subaccount_id
  id            = each.value.serviceplan_id
  offering_name = each.value.serviceplan_id == null ? each.value.offering : null
  name          = each.value.serviceplan_id == null ? each.value.plan : null
  depends_on    = [btp_subaccount_entitlement.this]
}

resource "btp_subaccount_service_instance" "this" {
  for_each = local.instances

  subaccount_id         = var.subaccount_id
  serviceplan_id        = each.value.use_plan_names ? null : data.btp_subaccount_service_plan.this[each.key].id
  serviceplan_name      = each.value.use_plan_names ? each.value.plan : null
  service_offering_name = each.value.use_plan_names ? each.value.offering : null
  labels                = each.value.labels
  shared                = each.value.shared
  timeouts              = each.value.timeouts
  parameters            = each.value.parameters_key == null ? each.value.parameters : lookup(var.instance_parameters, each.value.parameters_key, null)
  name                  = each.value.name

  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = module.plan_validation[each.key].valid
      error_message = "Actual service plan is not ready, mismatches offering/plan, is not shareable or does not support the required platform."
    }
    precondition {
      condition     = each.value.parameters_key == null ? true : contains(keys(var.instance_parameters), each.value.parameters_key)
      error_message = "Missing runtime instance parameter reference (values are never printed)."
    }
    precondition {
      condition     = length(distinct([for i in values(local.instances) : i.name])) == length(local.instances)
      error_message = "Service instance names must be unique within a subaccount."
    }
    precondition {
      condition     = !var.existing_dev_baseline || each.value.name != "${var.name_prefix}-alert-notification"
      error_message = "The existing DEV Alert Notification instance is already owned by module.srvc_baseline."
    }
  }
}

module "plan_validation" {
  for_each          = local.instances
  source            = "../service-plan-rules"
  actual            = data.btp_subaccount_service_plan.this[each.key]
  offering          = each.value.offering
  plan              = each.value.plan
  shared            = each.value.shared
  required_platform = each.value.required_platform
}

data "btp_subaccount_subscriptions" "available" {
  count         = length(local.subscriptions) > 0 ? 1 : 0
  subaccount_id = var.subaccount_id
  depends_on    = [btp_subaccount_entitlement.this]
}

resource "btp_subaccount_subscription" "this" {
  for_each = local.subscriptions

  subaccount_id = var.subaccount_id
  app_name      = each.value.app_name
  plan_name     = each.value.plan_name
  parameters    = each.value.parameters_key == null ? each.value.parameters : lookup(var.subscription_parameters, each.value.parameters_key, null)
  timeouts      = each.value.timeouts
  depends_on    = [btp_subaccount_entitlement.this]

  lifecycle {
    prevent_destroy = true
    precondition {
      condition = var.catalog_valid && length([
        for app in data.btp_subaccount_subscriptions.available[0].values : app
        if app.app_name == each.value.app_name && app.plan_name == each.value.plan_name
      ]) == 1
      error_message = "Subscription application/plan is not uniquely available in the actual subaccount catalog."
    }
    precondition {
      condition     = each.value.parameters_key == null ? true : contains(keys(var.subscription_parameters), each.value.parameters_key)
      error_message = "Missing runtime subscription parameter reference."
    }
  }
}

output "instance_ids" {
  value = { for key, instance in btp_subaccount_service_instance.this : key => instance.id }
}
