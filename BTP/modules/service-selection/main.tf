terraform {
  required_version = ">= 1.9.0, < 2.0.0"
}
variable "services" { type = any }
variable "catalog" { type = any }
variable "name_prefix" { type = string }
variable "existing_dev_baseline" { type = bool }

locals {
  selected = { for key in var.services.catalog : key => var.catalog[key] }
  entitlement_sources = [
    var.services.alert_notification.enabled && !var.existing_dev_baseline ? {
      alert_notification = {
        service_name           = "alert-notification"
        plan_name              = var.services.alert_notification.plan
        amount                 = var.services.alert_notification.amount
        plan_unique_identifier = var.services.alert_notification.plan_unique_identifier
      }
    } : {},
    var.services.feature_flags.enabled && !var.existing_dev_baseline ? {
      feature_flags = {
        service_name           = "feature-flags"
        plan_name              = var.services.feature_flags.plan
        amount                 = var.services.feature_flags.amount
        plan_unique_identifier = var.services.feature_flags.plan_unique_identifier
      }
    } : {},
    var.services.feature_flags.enabled && var.services.feature_flags.dashboard && !var.existing_dev_baseline ? {
      feature_flags_dashboard = {
        service_name           = "feature-flags-dashboard"
        plan_name              = "dashboard"
        amount                 = var.services.feature_flags.dashboard_amount
        plan_unique_identifier = var.services.feature_flags.dashboard_plan_unique_identifier
      }
    } : {},
    var.services.work_zone.enabled ? {
      work_zone = {
        service_name           = "SAPLaunchpad"
        plan_name              = var.services.work_zone.plan
        amount                 = var.services.work_zone.amount
        plan_unique_identifier = var.services.work_zone.plan_unique_identifier
      }
    } : {},
    var.services.entitlements,
    { for key, item in local.selected : "catalog_${key}" => {
      service_name           = item.service_name
      plan_name              = item.plan_name
      amount                 = lookup(var.services.catalog_amounts, key, item.amount)
      plan_unique_identifier = item.plan_unique_identifier
    } }
  ]
  entitlements = merge(local.entitlement_sources...)
  instance_sources = [
    var.services.alert_notification.enabled && var.services.alert_notification.instance && !var.existing_dev_baseline ? {
      alert_notification = merge(var.services.alert_notification.instance_options, {
        offering = "alert-notification"
        plan     = var.services.alert_notification.plan
        name     = coalesce(var.services.alert_notification.instance_options.name, "${var.name_prefix}-alert-notification")
      })
    } : {},
    var.services.feature_flags.enabled && var.services.feature_flags.instance ? {
      feature_flags = merge(var.services.feature_flags.instance_options, {
        offering = "feature-flags"
        plan     = var.services.feature_flags.plan
        name     = coalesce(var.services.feature_flags.instance_options.name, "${var.name_prefix}-feature-flags")
      })
    } : {},
    var.services.instances,
    { for key, item in local.selected : "catalog_${key}" => merge(item.instance, {
      offering = item.service_name
      plan     = item.plan_name
      name     = coalesce(try(item.instance.name, null), "${var.name_prefix}-${key}")
    }) if item.instance != null }
  ]
  instances = merge(local.instance_sources...)
  subscription_sources = [
    var.services.feature_flags.enabled && var.services.feature_flags.dashboard && !var.existing_dev_baseline ? {
      feature_flags_dashboard = merge(var.services.feature_flags.subscription_options, {
        app_name = "feature-flags-dashboard", plan_name = "dashboard"
      })
    } : {},
    var.services.work_zone.enabled ? {
      work_zone = merge(var.services.work_zone.subscription_options, {
        app_name = "SAPLaunchpad", plan_name = var.services.work_zone.plan
      })
    } : {},
    var.services.subscriptions,
    { for key, item in local.selected : "catalog_${key}" => merge(item.subscription, {
      app_name  = coalesce(try(item.subscription.app_name, null), item.service_name)
      plan_name = item.plan_name
    }) if item.subscription != null }
  ]
  subscriptions = merge(local.subscription_sources...)
}

output "selection" {
  value = {
    entitlements  = local.entitlements
    instances     = local.instances
    subscriptions = local.subscriptions
  }
  precondition {
    condition     = length(flatten([for source in local.entitlement_sources : keys(source)])) == length(distinct(flatten([for source in local.entitlement_sources : keys(source)])))
    error_message = "Conflicting entitlement keys across presets, custom entries and catalog aliases. Choose distinct keys; no source may overwrite another."
  }
  precondition {
    condition     = length(flatten([for source in local.instance_sources : keys(source)])) == length(distinct(flatten([for source in local.instance_sources : keys(source)])))
    error_message = "Conflicting instance keys across presets, custom entries and catalog aliases. Choose distinct keys; no source may overwrite another."
  }
  precondition {
    condition     = length(flatten([for source in local.subscription_sources : keys(source)])) == length(distinct(flatten([for source in local.subscription_sources : keys(source)])))
    error_message = "Conflicting subscription keys across presets, custom entries and catalog aliases. Choose distinct keys; no source may overwrite another."
  }
  precondition {
    condition = (
      length(distinct([for e in values(local.entitlements) : "${e.service_name}/${e.plan_name}/${coalesce(e.plan_unique_identifier, "auto")}"])) == length(local.entitlements) &&
      length(distinct([for i in values(local.instances) : i.name])) == length(local.instances) &&
      length(distinct([for s in values(local.subscriptions) : "${s.app_name}/${s.plan_name}"])) == length(local.subscriptions)
    )
    error_message = "Preset, custom and shared-catalog selections contain duplicate entitlements, instance names or subscriptions."
  }
}
