# ============================================================================
# BTP | moved.tf – Historie der bereits durchgeführten Modul-Migration
# ============================================================================
# Diese Datei dokumentiert, wie bestehende Terraform-State-Adressen von den
# früheren Root-Ressourcen nach module.srvc_baseline.* verschoben wurden.
#
# WICHTIG: Der gesamte moved-Code steht derzeit innerhalb von /* ... */
# und wird deshalb von Terraform NICHT ausgeführt. Die Migration wurde
# bereits durchgeführt und die neuen Adressen stehen im bestehenden State.
# Würde man einen alten State erneut migrieren, wären aktive moved-Blöcke
# oder eine andere gezielte Migrationsstrategie erforderlich.
# Die folgenden ursprünglichen Blockkommentare bleiben bewusst unverändert.

/* Die moved-Blöcke haben Terraform einmalig erklärt, wie die bisherigen Ressourcenadressen auf die neuen Modulpfade übertragen werden sollen.
*/

/*
moved {
  from = btp_subaccount_entitlement.alert_notification_service_standard
  to   = module.srvc_baseline.btp_subaccount_entitlement.alert_notification_service_standard
}

moved {
  from = btp_subaccount_entitlement.feature_flags_service_lite
  to   = module.srvc_baseline.btp_subaccount_entitlement.feature_flags_service_lite
}

moved {
  from = btp_subaccount_entitlement.feature_flags_dashboard_app
  to   = module.srvc_baseline.btp_subaccount_entitlement.feature_flags_dashboard_app
}

moved {
  from = btp_subaccount_service_instance.alert_notification_service_standard
  to   = module.srvc_baseline.btp_subaccount_service_instance.alert_notification_service_standard
}

moved {
  from = btp_subaccount_subscription.feature_flags_dashboard_app
  to   = module.srvc_baseline.btp_subaccount_subscription.feature_flags_dashboard_app
}
*/