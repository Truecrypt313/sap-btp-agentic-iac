# ============================================================================
# BTP | modules/srvc-baseline/srvc_baseline.tf
# Wiederverwendbare Grundausstattung für einen SAP-BTP-Subaccount
# ============================================================================
# Das Modul enthält die Bereitstellungslogik für:
#   - Alert Notification Entitlement (standard)
#   - Feature Flags Entitlement (lite)
#   - Feature Flags Dashboard Entitlement (dashboard)
#   - Service-Plan-Abfrage für Alert Notification
#   - Alert Notification Service Instance
#   - Feature Flags Dashboard App Subscription
#
# Wichtig: Ein Entitlement erlaubt zunächst nur, einen Plan zu verwenden.
# Die tatsächliche Service Instance bzw. App Subscription entsteht erst durch
# die weiter unten ausdrücklich definierten Ressourcen.
# Alle Ressourcen beziehen sich über var.subaccount_id auf denselben Account.

# Provider-Anforderung des Moduls – OHNE eigene Anmeldung.
# Der aufrufende BTP-Root-Ordner liefert die konfigurierte Provider-Instanz.
# So ist das Modul von einem konkreten Global-Account-Login unabhängig.
terraform {
  required_providers {
    btp = {
      source = "SAP/btp"
    }
  }
}

# Namenskonvention für die später erstellte Alert-Notification-Instanz.
# replace() ersetzt Leerzeichen durch '-', lower() vereinheitlicht die
# Schreibweise. Beispiel DEV + Project ABC -> dev-project-abc.
locals {
  service_name_prefix = lower(
    replace("${var.project_stage}-${var.project_name}", " ", "-")
  )
}


# ---------------------------------------------------------------------------
# ENTITLEMENT 1: Alert Notification – Plan 'standard'
# Ein Entitlement schaltet die Nutzbarkeit des Plans im Subaccount frei.
# Es ist noch KEINE laufende Service Instance.
# ---------------------------------------------------------------------------
#SAP Alert Notification Service
resource "btp_subaccount_entitlement" "alert_notification_service_standard" {
  subaccount_id          = var.subaccount_id
  service_name           = "alert-notification"
  plan_name              = "standard"
  amount                 = var.configuration.alert_notification.amount
  plan_unique_identifier = var.configuration.alert_notification.plan_unique_identifier
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = var.catalog_valid
      error_message = "DEV baseline is not compatible with the actual entitlement catalog."
    }
  }
}

# ENTITLEMENT 2: Feature Flags – Plan 'lite'.
# Dasselbe Terraform-Ressourcenschema, aber ein anderes Serviceangebot.
resource "btp_subaccount_entitlement" "feature_flags_service_lite" {
  subaccount_id          = var.subaccount_id
  service_name           = "feature-flags"
  plan_name              = "lite"
  amount                 = var.configuration.feature_flags.amount
  plan_unique_identifier = var.configuration.feature_flags.plan_unique_identifier
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = var.catalog_valid
      error_message = "DEV baseline is not compatible with the actual entitlement catalog."
    }
  }
}

# ENTITLEMENT 3: Feature Flags Dashboard – Plan 'dashboard'.
# Ermöglicht die spätere App Subscription weiter unten.
resource "btp_subaccount_entitlement" "feature_flags_dashboard_app" {
  subaccount_id          = var.subaccount_id
  service_name           = "feature-flags-dashboard"
  plan_name              = "dashboard"
  amount                 = var.configuration.feature_flags.dashboard_amount
  plan_unique_identifier = var.configuration.feature_flags.dashboard_plan_unique_identifier
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = var.catalog_valid
      error_message = "DEV baseline is not compatible with the actual entitlement catalog."
    }
  }
}


# Data Source: liest die technische Service-Plan-ID für Alert Notification.
# 'name' bezeichnet den Plan, 'offering_name' das Serviceangebot.
# Der API-Lookup erfolgt erst NACH Aktivierung des passenden Entitlements,
# weil dieses über depends_on ausdrücklich als Voraussetzung genannt wird.
data "btp_subaccount_service_plan" "alert_notification_service_standard" {
  subaccount_id = var.subaccount_id
  id            = var.configuration.alert_notification.instance_options.serviceplan_id
  name          = var.configuration.alert_notification.instance_options.serviceplan_id == null ? "standard" : null
  offering_name = var.configuration.alert_notification.instance_options.serviceplan_id == null ? "alert-notification" : null

  depends_on = [
    btp_subaccount_entitlement.alert_notification_service_standard
  ]
}

# Erstellt eine echte Alert-Notification-Service-Instanz im Subaccount.
# Anders als die Entitlement-Ressource stellt diese Ressource den Service
# tatsächlich bereit. Die technische serviceplan_id stammt vom Lookup oben.
# Durch die Referenz entsteht zusätzlich eine implizite Abhängigkeit.
resource "btp_subaccount_service_instance" "alert_notification_service_standard" {
  subaccount_id         = var.subaccount_id
  serviceplan_id        = var.configuration.alert_notification.instance_options.use_plan_names ? null : data.btp_subaccount_service_plan.alert_notification_service_standard.id
  serviceplan_name      = var.configuration.alert_notification.instance_options.use_plan_names ? "standard" : null
  service_offering_name = var.configuration.alert_notification.instance_options.use_plan_names ? "alert-notification" : null
  labels                = var.configuration.alert_notification.instance_options.labels
  shared                = var.configuration.alert_notification.instance_options.shared
  timeouts              = var.configuration.alert_notification.instance_options.timeouts
  parameters            = var.configuration.alert_notification.instance_options.parameters_key == null ? var.configuration.alert_notification.instance_options.parameters : lookup(var.instance_parameters, var.configuration.alert_notification.instance_options.parameters_key, null)
  # Beispielhafter Instanzname: dev-project-abc-alert-notification.
  # Änderungen an Projektname/Stage können den verwalteten Namen ändern.
  name = coalesce(var.configuration.alert_notification.instance_options.name, "${local.service_name_prefix}-alert-notification")
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = module.alert_plan_validation.valid
      error_message = "DEV Alert Notification requires the actual alert-notification/standard plan, ready and compatible with sharing/platform."
    }
    precondition {
      condition     = var.configuration.alert_notification.instance_options.parameters_key == null ? true : contains(keys(var.instance_parameters), var.configuration.alert_notification.instance_options.parameters_key)
      error_message = "Missing sensitive runtime parameter reference for DEV Alert Notification."
    }
  }
}

module "alert_plan_validation" {
  source            = "../service-plan-rules"
  actual            = data.btp_subaccount_service_plan.alert_notification_service_standard
  offering          = "alert-notification"
  plan              = "standard"
  shared            = var.configuration.alert_notification.instance_options.shared
  required_platform = var.configuration.alert_notification.instance_options.required_platform
}

# Aktiviert die Feature Flags Dashboard-Anwendung als Subscription.
# Eine App Subscription ist nicht dasselbe wie eine Service Instance.
# depends_on sorgt dafür, dass das Dashboard-Entitlement vorher existiert.
data "btp_subaccount_subscriptions" "available" {
  subaccount_id = var.subaccount_id
  depends_on    = [btp_subaccount_entitlement.feature_flags_dashboard_app]
}

resource "btp_subaccount_subscription" "feature_flags_dashboard_app" {
  subaccount_id = var.subaccount_id
  app_name      = "feature-flags-dashboard"
  plan_name     = "dashboard"
  parameters    = var.configuration.feature_flags.subscription_options.parameters_key == null ? var.configuration.feature_flags.subscription_options.parameters : lookup(var.subscription_parameters, var.configuration.feature_flags.subscription_options.parameters_key, null)
  timeouts      = var.configuration.feature_flags.subscription_options.timeouts

  depends_on = [
    btp_subaccount_entitlement.feature_flags_dashboard_app
  ]
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = var.catalog_valid && length([for app in data.btp_subaccount_subscriptions.available.values : app if app.app_name == "feature-flags-dashboard" && app.plan_name == "dashboard"]) == 1
      error_message = "DEV Feature Flags Dashboard must remain available in the actual subscription catalog."
    }
    precondition {
      condition     = var.configuration.feature_flags.subscription_options.parameters_key == null ? true : contains(keys(var.subscription_parameters), var.configuration.feature_flags.subscription_options.parameters_key)
      error_message = "Missing sensitive runtime subscription parameter reference."
    }
  }
}
