terraform {
  required_version = ">= 1.9.0, < 2.0.0"
}

variable "configuration" {
  description = "Schema v1/v2 of the non-secret landing-zone YAML. Defaults are resolved here for all roots."
  nullable    = false
  type = object({
    schema_version = number
    account_type   = string
    project_name   = string
    service_catalog = optional(map(object({
      service_name           = string
      plan_name              = string
      amount                 = optional(number)
      plan_unique_identifier = optional(string)
      profiles               = optional(set(string), ["trial", "enterprise"])
      instance = optional(object({
        name              = optional(string)
        parameters        = optional(string)
        parameters_key    = optional(string)
        labels            = optional(map(set(string)))
        shared            = optional(bool)
        serviceplan_id    = optional(string)
        use_plan_names    = optional(bool, false)
        required_platform = optional(string)
        timeouts = optional(object({
          create = optional(string)
          update = optional(string)
          delete = optional(string)
        }))
      }))
      subscription = optional(object({
        parameters     = optional(string)
        parameters_key = optional(string)
        timeouts = optional(object({
          create = optional(string)
          update = optional(string)
          delete = optional(string)
        }))
        app_name = optional(string)
      }))
    })), {})
    environments = map(object({
      enabled               = optional(bool, true)
      name                  = optional(string)
      subdomain             = optional(string)
      description           = optional(string)
      region                = optional(string)
      iaas_provider         = optional(string)
      runtime               = optional(string, "cloudfoundry")
      parent_id             = optional(string)
      usage                 = optional(string)
      costcenter            = string
      beta_enabled          = optional(bool, false)
      skip_auto_entitlement = optional(bool)
      labels                = optional(map(set(string)), {})
      administrators_source = optional(string, "yaml")
      administrators        = optional(set(string), [])
      administrator_options = optional(object({
        role_collection_name = optional(string, "Subaccount Administrator")
        origin               = optional(string)
      }), {})
      role_assignments = optional(map(object({
        role_collection_name = optional(string)
        role_collection_key  = optional(string)
        user_name            = optional(string)
        group_name           = optional(string)
        attribute_name       = optional(string)
        attribute_value      = optional(string)
        origin               = optional(string)
      })), {})
      role_collections = optional(map(object({
        name        = string
        description = optional(string)
        roles = map(object({
          name                 = string
          role_template_name   = string
          role_template_app_id = string
        }))
      })), {})
      cloud_foundry = optional(object({
        enabled          = optional(bool, false)
        name             = optional(string)
        plan             = optional(string, "trial")
        environment_type = optional(string, "cloudfoundry")
        service_name     = optional(string, "cloudfoundry")
        landscape_label  = optional(string, "")
        parameters       = optional(string)
        parameters_key   = optional(string)
        timeouts = optional(object({
          create = optional(string)
          update = optional(string)
          delete = optional(string)
        }))
        spaces = optional(map(object({
          name              = string
          allow_ssh         = optional(bool)
          isolation_segment = optional(string)
          labels            = optional(map(string))
          annotations       = optional(map(string))
          managers          = optional(set(string), [])
          developers        = optional(set(string), [])
          member_origin     = optional(string)
          roles = optional(map(object({
            type     = string
            user     = optional(string)
            username = optional(string)
            origin   = optional(string)
          })), {})
          legacy_manager = optional(object({
            user     = optional(string)
            username = optional(string)
            origin   = optional(string)
          }))
          legacy_developer = optional(object({
            user     = optional(string)
            username = optional(string)
            origin   = optional(string)
          }))
        })), {})
      }), {})
      services = optional(object({
        alert_notification = optional(object({
          enabled                = optional(bool, false)
          plan                   = optional(string, "standard")
          instance               = optional(bool, true)
          amount                 = optional(number)
          plan_unique_identifier = optional(string)
          instance_options = optional(object({
            name              = optional(string)
            parameters        = optional(string)
            parameters_key    = optional(string)
            labels            = optional(map(set(string)))
            shared            = optional(bool)
            serviceplan_id    = optional(string)
            use_plan_names    = optional(bool, false)
            required_platform = optional(string)
            timeouts = optional(object({
              create = optional(string)
              update = optional(string)
              delete = optional(string)
            }))
          }), {})
        }), {})
        feature_flags = optional(object({
          enabled                = optional(bool, false)
          plan                   = optional(string, "lite")
          instance               = optional(bool, true)
          amount                 = optional(number)
          plan_unique_identifier = optional(string)
          instance_options = optional(object({
            name              = optional(string)
            parameters        = optional(string)
            parameters_key    = optional(string)
            labels            = optional(map(set(string)))
            shared            = optional(bool)
            serviceplan_id    = optional(string)
            use_plan_names    = optional(bool, false)
            required_platform = optional(string)
            timeouts = optional(object({
              create = optional(string)
              update = optional(string)
              delete = optional(string)
            }))
          }), {})
          dashboard                        = optional(bool, true)
          dashboard_amount                 = optional(number)
          dashboard_plan_unique_identifier = optional(string)
          subscription_options = optional(object({
            parameters     = optional(string)
            parameters_key = optional(string)
            timeouts = optional(object({
              create = optional(string)
              update = optional(string)
              delete = optional(string)
            }))
          }), {})
        }), {})
        work_zone = optional(object({
          enabled                = optional(bool, false)
          plan                   = optional(string)
          amount                 = optional(number)
          plan_unique_identifier = optional(string)
          subscription_options = optional(object({
            parameters     = optional(string)
            parameters_key = optional(string)
            timeouts = optional(object({
              create = optional(string)
              update = optional(string)
              delete = optional(string)
            }))
          }), {})
        }), {})
        entitlements = optional(map(object({
          service_name           = string
          plan_name              = string
          amount                 = optional(number)
          plan_unique_identifier = optional(string)
        })), {})
        instances = optional(map(object({
          name              = string
          parameters        = optional(string)
          parameters_key    = optional(string)
          labels            = optional(map(set(string)))
          shared            = optional(bool)
          serviceplan_id    = optional(string)
          use_plan_names    = optional(bool, false)
          required_platform = optional(string)
          timeouts = optional(object({
            create = optional(string)
            update = optional(string)
            delete = optional(string)
          }))
          offering = string
          plan     = string
        })), {})
        subscriptions = optional(map(object({
          parameters     = optional(string)
          parameters_key = optional(string)
          timeouts = optional(object({
            create = optional(string)
            update = optional(string)
            delete = optional(string)
          }))
          app_name  = string
          plan_name = string
        })), {})
        catalog         = optional(set(string), [])
        catalog_amounts = optional(map(number), {})
      }), {})
    }))
  })

  validation {
    condition     = contains([1, 2], var.configuration.schema_version)
    error_message = "Only landing-zone schema_version 1 or 2 is supported."
  }
  validation {
    condition     = contains(["trial", "enterprise"], var.configuration.account_type)
    error_message = "account_type must be trial or enterprise."
  }
  validation {
    condition = can(regex("^[A-Za-z0-9][A-Za-z0-9 -]*$", var.configuration.project_name)) && alltrue([
      for stage, env in var.configuration.environments :
      contains(["DEV", "TEST", "PROD"], stage) &&
      (env.region == null || can(regex("^[a-z][a-z0-9-]+$", env.region))) &&
      can(regex("^[0-9]{5}$", env.costcenter)) &&
      !contains(keys(env.labels), "stage") && !contains(keys(env.labels), "costcenter") &&
      contains(["yaml", "legacy"], env.administrators_source) &&
      (stage == "DEV" || env.administrators_source == "yaml") &&
      (env.administrators_source == "yaml" || length(env.administrators) == 0)
    ])
    error_message = "Use DEV/TEST/PROD, a region code and a quoted 5-digit costcenter. stage/costcenter labels are reserved. Only DEV may explicitly retain legacy administrators."
  }
  validation {
    condition = var.configuration.account_type != "trial" || alltrue([
      for stage, env in var.configuration.environments : stage != "PROD" || !env.enabled
    ])
    error_message = "An enabled PROD environment is prohibited for a trial account."
  }
  validation {
    condition = alltrue([
      for stage, env in var.configuration.environments :
      (!env.enabled || !env.cloud_foundry.enabled || contains(["trial", "standard"], env.cloud_foundry.plan)) &&
      (!env.enabled || !env.cloud_foundry.enabled || var.configuration.account_type != "trial" || env.cloud_foundry.plan == "trial") &&
      (!env.enabled || !env.cloud_foundry.enabled || var.configuration.account_type != "enterprise" || env.cloud_foundry.plan == "standard") &&
      (env.cloud_foundry.enabled || length(env.cloud_foundry.spaces) == 0) &&
      length(distinct([for space in values(env.cloud_foundry.spaces) : space.name])) == length(env.cloud_foundry.spaces) &&
      alltrue([for key, space in env.cloud_foundry.spaces : can(regex("^[a-z0-9][a-z0-9_-]*$", key)) && length(trimspace(space.name)) > 0])
    ])
    error_message = "Cloud Foundry needs an explicit trial/standard plan matching the account type; spaces require CF, stable keys and unique nonempty names."
  }
  validation {
    condition = alltrue([
      for env in values(var.configuration.environments) :
      length(env.services.alert_notification.plan) > 0 &&
      length(env.services.feature_flags.plan) > 0 &&
      (!env.services.work_zone.enabled || try(length(env.services.work_zone.plan) > 0, false)) &&
      alltrue([for key in keys(env.services.entitlements) : !contains(["alert_notification", "feature_flags", "feature_flags_dashboard", "work_zone"], key)]) &&
      alltrue([for key in keys(env.services.instances) : !contains(["alert_notification", "feature_flags"], key)])
    ])
    error_message = "Use documented service plans. Work Zone needs an explicitly verified standard/free APPLICATION plan when enabled. Custom keys must not shadow built-ins."
  }
  validation {
    condition = alltrue([
      for stage, env in var.configuration.environments :
      (env.usage != "USED_FOR_PRODUCTION" || (stage == "PROD" && var.configuration.account_type == "enterprise")) &&
      (!env.cloud_foundry.enabled || (env.runtime == "cloudfoundry" && env.cloud_foundry.environment_type == "cloudfoundry" && env.cloud_foundry.service_name == "cloudfoundry")) &&
      length(env.labels) <= 8 && alltrue([for label in values(env.labels) : alltrue([for value in label : length(value) <= 63])]) &&
      alltrue([for key in env.services.catalog : try(contains(var.configuration.service_catalog[key].profiles, var.configuration.account_type), false)]) &&
      alltrue([for key in keys(env.services.catalog_amounts) : contains(env.services.catalog, key)])
    ])
    error_message = "Production usage requires enterprise PROD; CF requires a CF runtime; labels reserve two keys; catalog aliases/profile/amount overrides must be valid."
  }
  validation {
    condition = alltrue(flatten([
      for env in values(var.configuration.environments) : [for role in values(env.role_assignments) :
        (role.role_collection_name != null) != (role.role_collection_key != null) &&
        (role.role_collection_key == null ? true : contains(keys(env.role_collections), role.role_collection_key) && role.origin != null) &&
        !contains([for collection in values(env.role_collections) : collection.name], role.role_collection_name == null ? "" : role.role_collection_name) &&
        length(compact([role.user_name, role.group_name, role.attribute_name])) == 1 &&
        (role.group_name == null || role.origin != null) &&
        (role.attribute_name == null || (role.attribute_value != null && role.origin != null)) &&
        (role.attribute_value == null || role.attribute_name != null)
      ]
    ]))
    error_message = "BTP assignments need one external collection name or a managed key with explicit origin, and exactly one user/group/attribute subject. Group and attribute mappings require origin; attribute_name/value must be paired."
  }
  validation {
    condition = alltrue([for env in values(var.configuration.environments) :
      length(distinct([for collection in values(env.role_collections) : collection.name])) == length(env.role_collections) &&
      alltrue([for collection in values(env.role_collections) :
        trimspace(collection.name) != "" &&
        length(distinct([for role in values(collection.roles) : jsonencode(role)])) == length(collection.roles) &&
        alltrue([for role in values(collection.roles) : alltrue([
          for value in [role.name, role.role_template_name, role.role_template_app_id] : trimspace(value) != ""
        ])])
      ])
    ])
    error_message = "Role collection names must be unique and nonblank per environment; roles must be unique and fully identified."
  }
  validation {
    condition = alltrue(flatten([
      for env in values(var.configuration.environments) : [for space in values(env.cloud_foundry.spaces) : alltrue([
        for role in concat(values(space.roles), space.legacy_manager == null ? [] : [merge(space.legacy_manager, { type = "space_manager" })], space.legacy_developer == null ? [] : [merge(space.legacy_developer, { type = "space_developer" })]) :
        length(compact([role.user, role.username])) == 1 && (role.origin == null || role.username != null)
      ])]
    ]))
    error_message = "CF roles need exactly one user UUID or username; origin requires username."
  }

  validation {
    condition = alltrue(flatten([
      for stage, env in var.configuration.environments : [for key, space in env.cloud_foundry.spaces :
        ((stage == "DEV" && key == "project") || (space.legacy_manager == null && space.legacy_developer == null)) &&
        ((stage != "DEV" || key != "project") || space.member_origin == null)
      ]
    ]))
    error_message = "legacy_manager/legacy_developer are supported only for DEV/cloud_foundry/spaces/project; use explicit roles for all other spaces. DEV/project uses legacy role origins, never member_origin."
  }

  # BEGIN GENERATED CONSTRAINTS
  validation {
    condition = ((contains([1, 2], var.configuration.schema_version) &&
      floor(var.configuration.schema_version) == var.configuration.schema_version) &&
      (contains(["trial", "enterprise"], var.configuration.account_type)) &&
      (can(regex("^[A-Za-z0-9][A-Za-z0-9 -]*$", var.configuration.project_name))) &&
      (alltrue([for item1 in values(var.configuration.service_catalog) : (item1 != null && ((item1 == null ? true : ((item1.amount == null ? true : (item1.amount >= 1 &&
        item1.amount <= 2000000000 &&
        floor(item1.amount) == item1.amount)) &&
        (alltrue([for item3 in item1.profiles : (item3 != null && ((item3 == null ? true : (contains(["trial", "enterprise"], item3)))))])) &&
        (item1.instance == null ? true : (!(item1.instance.parameters != null && item1.instance.parameters_key != null) &&
          (item1.instance.parameters == null ? true : (can(keys(jsondecode(item1.instance.parameters))) &&
          alltrue([for key in try(regexall("\"([^\"\\\\]+)\"\\s*:", jsonencode(jsondecode(item1.instance.parameters))), []) : !can(regex("(?i)(password|passwd|secret|token|credentials|apikey|privatekey)$", replace(key[0], "/[^a-zA-Z0-9]/", "")))]))) &&
          (item1.instance.labels == null ? true : (alltrue([for item4 in values(item1.instance.labels) : (item4 != null && ((item4 == null ? true : (alltrue([for item5 in item4 : (item5 != null && (true))])))))]))) &&
          (item1.instance.timeouts == null ? true : ((item1.instance.timeouts.create == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.instance.timeouts.create)))) &&
            (item1.instance.timeouts.update == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.instance.timeouts.update)))) &&
        (item1.instance.timeouts.delete == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.instance.timeouts.delete)))))))) &&
        (item1.subscription == null ? true : (!(item1.subscription.parameters != null && item1.subscription.parameters_key != null) &&
          (item1.subscription.parameters == null ? true : (can(keys(jsondecode(item1.subscription.parameters))) &&
          alltrue([for key in try(regexall("\"([^\"\\\\]+)\"\\s*:", jsonencode(jsondecode(item1.subscription.parameters))), []) : !can(regex("(?i)(password|passwd|secret|token|credentials|apikey|privatekey)$", replace(key[0], "/[^a-zA-Z0-9]/", "")))]))) &&
          (item1.subscription.timeouts == null ? true : ((item1.subscription.timeouts.create == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.subscription.timeouts.create)))) &&
            (item1.subscription.timeouts.update == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.subscription.timeouts.update)))) &&
      (item1.subscription.timeouts.delete == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.subscription.timeouts.delete))))))))))))])) &&
      (alltrue([for item1 in values(var.configuration.environments) : (item1 != null && ((item1 == null ? true : ((item1.name == null ? true : (can(regex("^[^/]+$", item1.name)) &&
        length(item1.name) >= 1 &&
        length(item1.name) <= 255)) &&
        (item1.subdomain == null ? true : (can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", item1.subdomain)))) &&
        (item1.description == null ? true : (length(item1.description) <= 300)) &&
        (item1.region == null ? true : (length(item1.region) >= 1)) &&
        (item1.iaas_provider == null ? true : (contains(["AWS", "AZURE", "GCP", "SAP", "ALI", "IBM"], item1.iaas_provider))) &&
        (item1.parent_id == null ? true : (can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", item1.parent_id)))) &&
        (item1.usage == null ? true : (contains(["UNSET", "NOT_USED_FOR_PRODUCTION", "USED_FOR_PRODUCTION"], item1.usage))) &&
        (can(regex("^[0-9]{5}$", item1.costcenter))) &&
        (length(item1.labels) <= 8 &&
        alltrue([for item3 in values(item1.labels) : (item3 != null && ((item3 == null ? true : (alltrue([for item4 in item3 : (item4 != null && ((item4 == null ? true : (length(item4) <= 63))))])))))])) &&
        (contains(["yaml", "legacy"], item1.administrators_source)) &&
        (alltrue([for item3 in item1.administrators : (item3 != null && (true))])) &&
        ((length(item1.administrator_options.role_collection_name) >= 1) &&
        (item1.administrator_options.origin == null ? true : (length(item1.administrator_options.origin) >= 1))) &&
        (alltrue([for item3 in values(item1.role_assignments) : (item3 != null && ((item3 == null ? true : ((item3.role_collection_name == null ? true : (length(item3.role_collection_name) >= 1)) &&
          (item3.role_collection_key == null ? true : (length(item3.role_collection_key) >= 1)) &&
          (item3.user_name == null ? true : (length(item3.user_name) >= 1 &&
          length(item3.user_name) <= 256)) &&
          (item3.group_name == null ? true : (length(item3.group_name) >= 1)) &&
          (item3.attribute_name == null ? true : (length(item3.attribute_name) >= 1)) &&
          (item3.attribute_value == null ? true : (length(item3.attribute_value) >= 1)) &&
        (item3.origin == null ? true : (length(item3.origin) >= 1))))))])) &&
        (alltrue([for item3 in values(item1.role_collections) : (item3 != null && ((item3 == null ? true : ((length(item3.name) >= 1) &&
          (length(item3.roles) >= 1 &&
            alltrue([for item5 in values(item3.roles) : (item5 != null && ((item5 == null ? true : ((length(item5.name) >= 1) &&
              (length(item5.role_template_name) >= 1) &&
        (length(item5.role_template_app_id) >= 1)))))]))))))])) &&
        (!(item1.cloud_foundry.parameters != null && item1.cloud_foundry.parameters_key != null) &&
          (item1.cloud_foundry.parameters == null ? true : (can(keys(jsondecode(item1.cloud_foundry.parameters))) &&
          alltrue([for key in try(regexall("\"([^\"\\\\]+)\"\\s*:", jsonencode(jsondecode(item1.cloud_foundry.parameters))), []) : !can(regex("(?i)(password|passwd|secret|token|credentials|apikey|privatekey)$", replace(key[0], "/[^a-zA-Z0-9]/", "")))]))) &&
          (item1.cloud_foundry.timeouts == null ? true : ((item1.cloud_foundry.timeouts.create == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.cloud_foundry.timeouts.create)))) &&
            (item1.cloud_foundry.timeouts.update == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.cloud_foundry.timeouts.update)))) &&
          (item1.cloud_foundry.timeouts.delete == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.cloud_foundry.timeouts.delete)))))) &&
          (alltrue([for item4 in values(item1.cloud_foundry.spaces) : (item4 != null && ((item4 == null ? true : ((length(item4.name) >= 1) &&
            (item4.isolation_segment == null ? true : (can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", item4.isolation_segment)))) &&
            (item4.labels == null ? true : (alltrue([for item6 in values(item4.labels) : (item6 != null && (true))]))) &&
            (item4.annotations == null ? true : (alltrue([for item6 in values(item4.annotations) : (item6 != null && (true))]))) &&
            (alltrue([for item6 in item4.managers : (item6 != null && (true))])) &&
            (alltrue([for item6 in item4.developers : (item6 != null && (true))])) &&
            (alltrue([for item6 in values(item4.roles) : (item6 != null && ((item6 == null ? true : ((contains(["space_manager", "space_developer", "space_auditor", "space_supporter"], item6.type)) &&
              (item6.user == null ? true : (can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", item6.user)))) &&
            (item6.username == null ? true : (length(item6.username) >= 1))))))])) &&
            (item4.legacy_manager == null ? true : ((item4.legacy_manager.user == null ? true : (can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", item4.legacy_manager.user)))) &&
            (item4.legacy_manager.username == null ? true : (length(item4.legacy_manager.username) >= 1)))) &&
            (item4.legacy_developer == null ? true : ((item4.legacy_developer.user == null ? true : (can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", item4.legacy_developer.user)))) &&
        (item4.legacy_developer.username == null ? true : (length(item4.legacy_developer.username) >= 1))))))))]))) &&
        (((item1.services.alert_notification.amount == null ? true : (item1.services.alert_notification.amount >= 1 &&
          item1.services.alert_notification.amount <= 2000000000 &&
          floor(item1.services.alert_notification.amount) == item1.services.alert_notification.amount)) &&
          (!(item1.services.alert_notification.instance_options.parameters != null && item1.services.alert_notification.instance_options.parameters_key != null) &&
            (item1.services.alert_notification.instance_options.parameters == null ? true : (can(keys(jsondecode(item1.services.alert_notification.instance_options.parameters))) &&
            alltrue([for key in try(regexall("\"([^\"\\\\]+)\"\\s*:", jsonencode(jsondecode(item1.services.alert_notification.instance_options.parameters))), []) : !can(regex("(?i)(password|passwd|secret|token|credentials|apikey|privatekey)$", replace(key[0], "/[^a-zA-Z0-9]/", "")))]))) &&
            (item1.services.alert_notification.instance_options.labels == null ? true : (alltrue([for item6 in values(item1.services.alert_notification.instance_options.labels) : (item6 != null && ((item6 == null ? true : (alltrue([for item7 in item6 : (item7 != null && (true))])))))]))) &&
            (item1.services.alert_notification.instance_options.timeouts == null ? true : ((item1.services.alert_notification.instance_options.timeouts.create == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.services.alert_notification.instance_options.timeouts.create)))) &&
              (item1.services.alert_notification.instance_options.timeouts.update == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.services.alert_notification.instance_options.timeouts.update)))) &&
          (item1.services.alert_notification.instance_options.timeouts.delete == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.services.alert_notification.instance_options.timeouts.delete)))))))) &&
          ((item1.services.feature_flags.amount == null ? true : (item1.services.feature_flags.amount >= 1 &&
            item1.services.feature_flags.amount <= 2000000000 &&
            floor(item1.services.feature_flags.amount) == item1.services.feature_flags.amount)) &&
            (!(item1.services.feature_flags.instance_options.parameters != null && item1.services.feature_flags.instance_options.parameters_key != null) &&
              (item1.services.feature_flags.instance_options.parameters == null ? true : (can(keys(jsondecode(item1.services.feature_flags.instance_options.parameters))) &&
              alltrue([for key in try(regexall("\"([^\"\\\\]+)\"\\s*:", jsonencode(jsondecode(item1.services.feature_flags.instance_options.parameters))), []) : !can(regex("(?i)(password|passwd|secret|token|credentials|apikey|privatekey)$", replace(key[0], "/[^a-zA-Z0-9]/", "")))]))) &&
              (item1.services.feature_flags.instance_options.labels == null ? true : (alltrue([for item6 in values(item1.services.feature_flags.instance_options.labels) : (item6 != null && ((item6 == null ? true : (alltrue([for item7 in item6 : (item7 != null && (true))])))))]))) &&
              (item1.services.feature_flags.instance_options.timeouts == null ? true : ((item1.services.feature_flags.instance_options.timeouts.create == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.services.feature_flags.instance_options.timeouts.create)))) &&
                (item1.services.feature_flags.instance_options.timeouts.update == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.services.feature_flags.instance_options.timeouts.update)))) &&
            (item1.services.feature_flags.instance_options.timeouts.delete == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.services.feature_flags.instance_options.timeouts.delete))))))) &&
            (item1.services.feature_flags.dashboard_amount == null ? true : (item1.services.feature_flags.dashboard_amount >= 1 &&
              item1.services.feature_flags.dashboard_amount <= 2000000000 &&
            floor(item1.services.feature_flags.dashboard_amount) == item1.services.feature_flags.dashboard_amount)) &&
            (!(item1.services.feature_flags.subscription_options.parameters != null && item1.services.feature_flags.subscription_options.parameters_key != null) &&
              (item1.services.feature_flags.subscription_options.parameters == null ? true : (can(keys(jsondecode(item1.services.feature_flags.subscription_options.parameters))) &&
              alltrue([for key in try(regexall("\"([^\"\\\\]+)\"\\s*:", jsonencode(jsondecode(item1.services.feature_flags.subscription_options.parameters))), []) : !can(regex("(?i)(password|passwd|secret|token|credentials|apikey|privatekey)$", replace(key[0], "/[^a-zA-Z0-9]/", "")))]))) &&
              (item1.services.feature_flags.subscription_options.timeouts == null ? true : ((item1.services.feature_flags.subscription_options.timeouts.create == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.services.feature_flags.subscription_options.timeouts.create)))) &&
                (item1.services.feature_flags.subscription_options.timeouts.update == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.services.feature_flags.subscription_options.timeouts.update)))) &&
          (item1.services.feature_flags.subscription_options.timeouts.delete == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.services.feature_flags.subscription_options.timeouts.delete)))))))) &&
          ((item1.services.work_zone.amount == null ? true : (item1.services.work_zone.amount >= 1 &&
            item1.services.work_zone.amount <= 2000000000 &&
            floor(item1.services.work_zone.amount) == item1.services.work_zone.amount)) &&
            (!(item1.services.work_zone.subscription_options.parameters != null && item1.services.work_zone.subscription_options.parameters_key != null) &&
              (item1.services.work_zone.subscription_options.parameters == null ? true : (can(keys(jsondecode(item1.services.work_zone.subscription_options.parameters))) &&
              alltrue([for key in try(regexall("\"([^\"\\\\]+)\"\\s*:", jsonencode(jsondecode(item1.services.work_zone.subscription_options.parameters))), []) : !can(regex("(?i)(password|passwd|secret|token|credentials|apikey|privatekey)$", replace(key[0], "/[^a-zA-Z0-9]/", "")))]))) &&
              (item1.services.work_zone.subscription_options.timeouts == null ? true : ((item1.services.work_zone.subscription_options.timeouts.create == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.services.work_zone.subscription_options.timeouts.create)))) &&
                (item1.services.work_zone.subscription_options.timeouts.update == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.services.work_zone.subscription_options.timeouts.update)))) &&
          (item1.services.work_zone.subscription_options.timeouts.delete == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item1.services.work_zone.subscription_options.timeouts.delete)))))))) &&
          (alltrue([for item4 in values(item1.services.entitlements) : (item4 != null && ((item4 == null ? true : ((item4.amount == null ? true : (item4.amount >= 1 &&
            item4.amount <= 2000000000 &&
          floor(item4.amount) == item4.amount))))))])) &&
          (alltrue([for item4 in values(item1.services.instances) : (item4 != null && ((item4 == null ? true : (!(item4.parameters != null && item4.parameters_key != null) &&
            (item4.parameters == null ? true : (can(keys(jsondecode(item4.parameters))) &&
            alltrue([for key in try(regexall("\"([^\"\\\\]+)\"\\s*:", jsonencode(jsondecode(item4.parameters))), []) : !can(regex("(?i)(password|passwd|secret|token|credentials|apikey|privatekey)$", replace(key[0], "/[^a-zA-Z0-9]/", "")))]))) &&
            (item4.labels == null ? true : (alltrue([for item6 in values(item4.labels) : (item6 != null && ((item6 == null ? true : (alltrue([for item7 in item6 : (item7 != null && (true))])))))]))) &&
            (item4.timeouts == null ? true : ((item4.timeouts.create == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item4.timeouts.create)))) &&
              (item4.timeouts.update == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item4.timeouts.update)))) &&
          (item4.timeouts.delete == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item4.timeouts.delete))))))))))])) &&
          (alltrue([for item4 in values(item1.services.subscriptions) : (item4 != null && ((item4 == null ? true : (!(item4.parameters != null && item4.parameters_key != null) &&
            (item4.parameters == null ? true : (can(keys(jsondecode(item4.parameters))) &&
            alltrue([for key in try(regexall("\"([^\"\\\\]+)\"\\s*:", jsonencode(jsondecode(item4.parameters))), []) : !can(regex("(?i)(password|passwd|secret|token|credentials|apikey|privatekey)$", replace(key[0], "/[^a-zA-Z0-9]/", "")))]))) &&
            (item4.timeouts == null ? true : ((item4.timeouts.create == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item4.timeouts.create)))) &&
              (item4.timeouts.update == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item4.timeouts.update)))) &&
          (item4.timeouts.delete == null ? true : (can(regex("^([0-9]+(\\.[0-9]+)?(ns|us|ms|s|m|h))+$", item4.timeouts.delete))))))))))])) &&
          (alltrue([for item4 in item1.services.catalog : (item4 != null && (true))])) &&
          (alltrue([for item4 in values(item1.services.catalog_amounts) : (item4 != null && ((item4 == null ? true : (item4 >= 1 &&
            item4 <= 2000000000 &&
    floor(item4) == item4))))])))))))])))
    error_message = "A configuration attribute violates its documented type, enum, length, UUID, quota or timeout constraint."
  }
  # END GENERATED CONSTRAINTS

}

output "configuration" {
  value = var.configuration
}

locals {
  handoff_contracts = {
    for stage, env in var.configuration.environments : stage => {
      contract_version = 1
      account_type     = var.configuration.account_type
      project_name     = var.configuration.project_name
      stage            = stage
      subaccount = {
        name          = env.name, subdomain = env.subdomain, region = env.region,
        iaas_provider = env.iaas_provider, parent_id = env.parent_id, runtime = env.runtime
      }
      cloud_foundry = {
        enabled      = env.cloud_foundry.enabled, name = env.cloud_foundry.name,
        service_name = env.cloud_foundry.service_name, environment_type = env.cloud_foundry.environment_type,
        plan         = env.cloud_foundry.plan, landscape_label = env.cloud_foundry.landscape_label,
        parameters   = env.cloud_foundry.parameters, parameters_key = env.cloud_foundry.parameters_key
      }
    } if env.enabled && env.cloud_foundry.enabled
  }
}
output "handoff_fingerprints" {
  value = { for stage, contract in local.handoff_contracts : stage => sha256(jsonencode(contract)) }
}

# BEGIN GENERATED RAW INPUT
variable "raw_configuration" {
  type    = any
  default = null
  validation {
    condition = try((var.raw_configuration == null ? true : (length(setsubtract(toset(keys(var.raw_configuration)), toset(["schema_version", "account_type", "project_name", "service_catalog", "environments"]))) == 0 &&
      (try(var.raw_configuration.service_catalog, null) == null ? true : (alltrue([for raw1 in values(try(var.raw_configuration.service_catalog, null)) : (raw1 == null ? true : (length(setsubtract(toset(keys(raw1)), toset(["service_name", "plan_name", "amount", "plan_unique_identifier", "profiles", "instance", "subscription"]))) == 0 &&
        (try(raw1.instance, null) == null ? true : (length(setsubtract(toset(keys(try(raw1.instance, null))), toset(["name", "parameters", "parameters_key", "labels", "shared", "serviceplan_id", "use_plan_names", "required_platform", "timeouts"]))) == 0 &&
          true &&
        (try(try(raw1.instance, null).timeouts, null) == null ? true : (length(setsubtract(toset(keys(try(try(raw1.instance, null).timeouts, null))), toset(["create", "update", "delete"]))) == 0)))) &&
        (try(raw1.subscription, null) == null ? true : (length(setsubtract(toset(keys(try(raw1.subscription, null))), toset(["parameters", "parameters_key", "timeouts", "app_name"]))) == 0 &&
      (try(try(raw1.subscription, null).timeouts, null) == null ? true : (length(setsubtract(toset(keys(try(try(raw1.subscription, null).timeouts, null))), toset(["create", "update", "delete"]))) == 0))))))]))) &&
      (try(var.raw_configuration.environments, null) == null ? true : (alltrue([for raw1 in values(try(var.raw_configuration.environments, null)) : (raw1 == null ? true : (length(setsubtract(toset(keys(raw1)), toset(["enabled", "name", "subdomain", "description", "region", "iaas_provider", "runtime", "parent_id", "usage", "costcenter", "beta_enabled", "skip_auto_entitlement", "labels", "administrators_source", "administrators", "administrator_options", "role_assignments", "role_collections", "cloud_foundry", "services"]))) == 0 &&
        true &&
        (try(raw1.administrator_options, null) == null ? true : (length(setsubtract(toset(keys(try(raw1.administrator_options, null))), toset(["role_collection_name", "origin"]))) == 0)) &&
        (try(raw1.role_assignments, null) == null ? true : (alltrue([for raw3 in values(try(raw1.role_assignments, null)) : (raw3 == null ? true : (length(setsubtract(toset(keys(raw3)), toset(["role_collection_name", "role_collection_key", "user_name", "group_name", "attribute_name", "attribute_value", "origin"]))) == 0))]))) &&
        (try(raw1.role_collections, null) == null ? true : (alltrue([for raw3 in values(try(raw1.role_collections, null)) : (raw3 == null ? true : (length(setsubtract(toset(keys(raw3)), toset(["name", "description", "roles"]))) == 0 &&
        (try(raw3.roles, null) == null ? true : (alltrue([for raw5 in values(try(raw3.roles, null)) : (raw5 == null ? true : (length(setsubtract(toset(keys(raw5)), toset(["name", "role_template_name", "role_template_app_id"]))) == 0))])))))]))) &&
        (try(raw1.cloud_foundry, null) == null ? true : (length(setsubtract(toset(keys(try(raw1.cloud_foundry, null))), toset(["enabled", "name", "plan", "environment_type", "service_name", "landscape_label", "parameters", "parameters_key", "timeouts", "spaces"]))) == 0 &&
          (try(try(raw1.cloud_foundry, null).timeouts, null) == null ? true : (length(setsubtract(toset(keys(try(try(raw1.cloud_foundry, null).timeouts, null))), toset(["create", "update", "delete"]))) == 0)) &&
          (try(try(raw1.cloud_foundry, null).spaces, null) == null ? true : (alltrue([for raw4 in values(try(try(raw1.cloud_foundry, null).spaces, null)) : (raw4 == null ? true : (length(setsubtract(toset(keys(raw4)), toset(["name", "allow_ssh", "isolation_segment", "labels", "annotations", "managers", "developers", "member_origin", "roles", "legacy_manager", "legacy_developer"]))) == 0 &&
            true &&
            true &&
            (try(raw4.roles, null) == null ? true : (alltrue([for raw6 in values(try(raw4.roles, null)) : (raw6 == null ? true : (length(setsubtract(toset(keys(raw6)), toset(["type", "user", "username", "origin"]))) == 0))]))) &&
            (try(raw4.legacy_manager, null) == null ? true : (length(setsubtract(toset(keys(try(raw4.legacy_manager, null))), toset(["user", "username", "origin"]))) == 0)) &&
        (try(raw4.legacy_developer, null) == null ? true : (length(setsubtract(toset(keys(try(raw4.legacy_developer, null))), toset(["user", "username", "origin"]))) == 0))))]))))) &&
        (try(raw1.services, null) == null ? true : (length(setsubtract(toset(keys(try(raw1.services, null))), toset(["alert_notification", "feature_flags", "work_zone", "entitlements", "instances", "subscriptions", "catalog", "catalog_amounts"]))) == 0 &&
          (try(try(raw1.services, null).alert_notification, null) == null ? true : (length(setsubtract(toset(keys(try(try(raw1.services, null).alert_notification, null))), toset(["enabled", "plan", "instance", "amount", "plan_unique_identifier", "instance_options"]))) == 0 &&
            (try(try(try(raw1.services, null).alert_notification, null).instance_options, null) == null ? true : (length(setsubtract(toset(keys(try(try(try(raw1.services, null).alert_notification, null).instance_options, null))), toset(["name", "parameters", "parameters_key", "labels", "shared", "serviceplan_id", "use_plan_names", "required_platform", "timeouts"]))) == 0 &&
              true &&
          (try(try(try(try(raw1.services, null).alert_notification, null).instance_options, null).timeouts, null) == null ? true : (length(setsubtract(toset(keys(try(try(try(try(raw1.services, null).alert_notification, null).instance_options, null).timeouts, null))), toset(["create", "update", "delete"]))) == 0)))))) &&
          (try(try(raw1.services, null).feature_flags, null) == null ? true : (length(setsubtract(toset(keys(try(try(raw1.services, null).feature_flags, null))), toset(["enabled", "plan", "instance", "amount", "plan_unique_identifier", "instance_options", "dashboard", "dashboard_amount", "dashboard_plan_unique_identifier", "subscription_options"]))) == 0 &&
            (try(try(try(raw1.services, null).feature_flags, null).instance_options, null) == null ? true : (length(setsubtract(toset(keys(try(try(try(raw1.services, null).feature_flags, null).instance_options, null))), toset(["name", "parameters", "parameters_key", "labels", "shared", "serviceplan_id", "use_plan_names", "required_platform", "timeouts"]))) == 0 &&
              true &&
            (try(try(try(try(raw1.services, null).feature_flags, null).instance_options, null).timeouts, null) == null ? true : (length(setsubtract(toset(keys(try(try(try(try(raw1.services, null).feature_flags, null).instance_options, null).timeouts, null))), toset(["create", "update", "delete"]))) == 0)))) &&
            (try(try(try(raw1.services, null).feature_flags, null).subscription_options, null) == null ? true : (length(setsubtract(toset(keys(try(try(try(raw1.services, null).feature_flags, null).subscription_options, null))), toset(["parameters", "parameters_key", "timeouts"]))) == 0 &&
          (try(try(try(try(raw1.services, null).feature_flags, null).subscription_options, null).timeouts, null) == null ? true : (length(setsubtract(toset(keys(try(try(try(try(raw1.services, null).feature_flags, null).subscription_options, null).timeouts, null))), toset(["create", "update", "delete"]))) == 0)))))) &&
          (try(try(raw1.services, null).work_zone, null) == null ? true : (length(setsubtract(toset(keys(try(try(raw1.services, null).work_zone, null))), toset(["enabled", "plan", "amount", "plan_unique_identifier", "subscription_options"]))) == 0 &&
            (try(try(try(raw1.services, null).work_zone, null).subscription_options, null) == null ? true : (length(setsubtract(toset(keys(try(try(try(raw1.services, null).work_zone, null).subscription_options, null))), toset(["parameters", "parameters_key", "timeouts"]))) == 0 &&
          (try(try(try(try(raw1.services, null).work_zone, null).subscription_options, null).timeouts, null) == null ? true : (length(setsubtract(toset(keys(try(try(try(try(raw1.services, null).work_zone, null).subscription_options, null).timeouts, null))), toset(["create", "update", "delete"]))) == 0)))))) &&
          (try(try(raw1.services, null).entitlements, null) == null ? true : (alltrue([for raw4 in values(try(try(raw1.services, null).entitlements, null)) : (raw4 == null ? true : (length(setsubtract(toset(keys(raw4)), toset(["service_name", "plan_name", "amount", "plan_unique_identifier"]))) == 0))]))) &&
          (try(try(raw1.services, null).instances, null) == null ? true : (alltrue([for raw4 in values(try(try(raw1.services, null).instances, null)) : (raw4 == null ? true : (length(setsubtract(toset(keys(raw4)), toset(["name", "parameters", "parameters_key", "labels", "shared", "serviceplan_id", "use_plan_names", "required_platform", "timeouts", "offering", "plan"]))) == 0 &&
            true &&
          (try(raw4.timeouts, null) == null ? true : (length(setsubtract(toset(keys(try(raw4.timeouts, null))), toset(["create", "update", "delete"]))) == 0))))]))) &&
          (try(try(raw1.services, null).subscriptions, null) == null ? true : (alltrue([for raw4 in values(try(try(raw1.services, null).subscriptions, null)) : (raw4 == null ? true : (length(setsubtract(toset(keys(raw4)), toset(["parameters", "parameters_key", "timeouts", "app_name", "plan_name"]))) == 0 &&
          (try(raw4.timeouts, null) == null ? true : (length(setsubtract(toset(keys(try(raw4.timeouts, null))), toset(["create", "update", "delete"]))) == 0))))]))) &&
    true))))]))))), false)
    error_message = "YAML contains an unknown/read-only attribute or an invalid object shape."
  }
}
# END GENERATED RAW INPUT
