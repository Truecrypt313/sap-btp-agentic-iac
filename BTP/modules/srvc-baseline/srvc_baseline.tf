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
  subaccount_id = var.subaccount_id
  service_name  = "alert-notification"
  plan_name     = "standard"
}

# ENTITLEMENT 2: Feature Flags – Plan 'lite'.
# Dasselbe Terraform-Ressourcenschema, aber ein anderes Serviceangebot.
resource "btp_subaccount_entitlement" "feature_flags_service_lite" {
  subaccount_id = var.subaccount_id
  service_name  = "feature-flags"
  plan_name     = "lite"
}

# ENTITLEMENT 3: Feature Flags Dashboard – Plan 'dashboard'.
# Ermöglicht die spätere App Subscription weiter unten.
resource "btp_subaccount_entitlement" "feature_flags_dashboard_app" {
  subaccount_id = var.subaccount_id
  service_name  = "feature-flags-dashboard"
  plan_name     = "dashboard"
}


# Data Source: liest die technische Service-Plan-ID für Alert Notification.
# 'name' bezeichnet den Plan, 'offering_name' das Serviceangebot.
# Der API-Lookup erfolgt erst NACH Aktivierung des passenden Entitlements,
# weil dieses über depends_on ausdrücklich als Voraussetzung genannt wird.
data "btp_subaccount_service_plan" "alert_notification_service_standard" {
  subaccount_id = var.subaccount_id
  name          = "standard"
  offering_name = "alert-notification"

  depends_on = [
    btp_subaccount_entitlement.alert_notification_service_standard
  ]
}

# Erstellt eine echte Alert-Notification-Service-Instanz im Subaccount.
# Anders als die Entitlement-Ressource stellt diese Ressource den Service
# tatsächlich bereit. Die technische serviceplan_id stammt vom Lookup oben.
# Durch die Referenz entsteht zusätzlich eine implizite Abhängigkeit.
resource "btp_subaccount_service_instance" "alert_notification_service_standard" {
  subaccount_id  = var.subaccount_id
  serviceplan_id = data.btp_subaccount_service_plan.alert_notification_service_standard.id
  # Beispielhafter Instanzname: dev-project-abc-alert-notification.
  # Änderungen an Projektname/Stage können den verwalteten Namen ändern.
  name           = "${local.service_name_prefix}-alert-notification"
}

# Aktiviert die Feature Flags Dashboard-Anwendung als Subscription.
# Eine App Subscription ist nicht dasselbe wie eine Service Instance.
# depends_on sorgt dafür, dass das Dashboard-Entitlement vorher existiert.
resource "btp_subaccount_subscription" "feature_flags_dashboard_app" {
  subaccount_id = var.subaccount_id
  app_name      = "feature-flags-dashboard"
  plan_name     = "dashboard"

  depends_on = [
    btp_subaccount_entitlement.feature_flags_dashboard_app
  ]
}