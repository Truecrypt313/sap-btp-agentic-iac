terraform { required_version = ">= 1.9.0, < 2.0.0" }
variable "environments" { type = any }
variable "regions" { type = map(string) }
variable "entitlements" { type = any }
variable "globalaccount_id" { type = string }
variable "global_catalog" { type = any }
variable "directory_catalog" { type = any }
variable "current_allocations" { type = any }
locals { stages = { for stage, entries in var.entitlements : stage => entries if length(entries) > 0 } }
locals {
  requests = merge({}, [
    for stage, entries in local.stages : {
      for key, entry in entries : "${stage}/${key}" => merge(entry, {
        stage  = stage
        region = var.regions[stage]
        parent = coalesce(var.environments[stage].parent_id, var.globalaccount_id)
      })
    }
  ]...)
  global_matches = {
    for id, request in local.requests : id => [
      for row in var.global_catalog : row
      if row.service_name == request.service_name && row.plan_name == request.plan_name &&
      (request.plan_unique_identifier == null || row.plan_unique_identifier == request.plan_unique_identifier)
    ]
  }
  parent_matches = {
    for id, request in local.requests : id => concat(
      [for row in local.global_matches[id] : { category = row.category, quota_remaining = row.quota_remaining } if request.parent == var.globalaccount_id],
      [for row in try(var.directory_catalog[request.parent], {}) : { category = row.category, quota_remaining = row.quota_remaining }
        if request.parent != var.globalaccount_id &&
        row.service_name == request.service_name && row.plan_name == request.plan_name &&
        row.plan_unique_identifier == try(one(local.global_matches[id]).plan_unique_identifier, "invalid")
      ]
    )
  }
  current_matches = {
    for id, request in local.requests : id => [
      for row in var.current_allocations[request.stage] : row
      if row.service_name == request.service_name && row.plan_name == request.plan_name &&
      row.plan_unique_identifier == try(one(local.global_matches[id]).plan_unique_identifier, "invalid")
    ]
  }
  current_amount     = { for id, rows in local.current_matches : id => sum(concat([0], [for row in rows : coalesce(row.quota_assigned, 0)])) }
  numeric_categories = ["SERVICE", "QUOTA_BASED_APPLICATION", "PLATFORM", "ENVIRONMENT"]
  quantities = {
    for id, request in local.requests : id => {
      budget  = "${request.parent}/${request.service_name}/${request.plan_name}/${try(coalesce(one(local.global_matches[id]).plan_unique_identifier, "auto"), "invalid")}"
      limited = contains(local.numeric_categories, try(one(local.parent_matches[id]).category, "")) || try(one(local.parent_matches[id]).category, "") == "ELASTIC_LIMITED"
      delta = try(one(local.parent_matches[id]).category, "") == "ELASTIC_LIMITED" ? (
        length(local.current_matches[id]) > 0 ? 0 : 1
      ) : max(coalesce(request.amount, local.current_amount[id]) - local.current_amount[id], 0)
      remaining = coalesce(try(one(local.parent_matches[id]).quota_remaining, null), 0)
    }
  }
  budgets = { for id, quantity in local.quantities : quantity.budget => quantity... if quantity.limited }
  request_valid = {
    for id, request in local.requests : id => (
      length(local.global_matches[id]) == 1 &&
      length(local.parent_matches[id]) == 1 &&
      (request.amount == null ? true : request.amount >= 1 && request.amount <= 2000000000 && floor(request.amount) == request.amount) &&
      contains(concat(local.numeric_categories, ["ELASTIC_SERVICE", "ELASTIC_LIMITED", "APPLICATION"]), try(one(local.parent_matches[id]).category, "")) &&
      try(anytrue([
        for dc in one(local.global_matches[id]).datacenter_information : dc.dc_region == request.region &&
        (var.environments[request.stage].iaas_provider == null || dc.dc_iaas_provider == var.environments[request.stage].iaas_provider)
      ]), false) &&
      (contains(local.numeric_categories, try(one(local.parent_matches[id]).category, "")) ? (
        request.amount != null || local.current_amount[id] > 0
      ) : request.amount == null)
    )
  }
  quota_valid = alltrue([
    for budget in values(local.budgets) : sum([for request in budget : request.delta]) <= budget[0].remaining
  ])
  valid = alltrue(values(local.request_valid)) && local.quota_valid
}

output "valid" {
  value = local.valid
  precondition {
    condition     = alltrue(values(local.request_valid))
    error_message = "An entitlement/plan is absent, ambiguous, not regionally available, unavailable in its parent directory, or has an invalid quota/category combination. No catalog fallback is allowed."
  }
  precondition {
    condition     = local.quota_valid
    error_message = "Combined positive quota deltas across environments exceed the actual parent/global remaining quota."
  }
}
