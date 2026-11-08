terraform { required_version = ">= 1.9.0, < 2.0.0" }
variable "environments" { type = any }
variable "account_type" { type = string }
variable "catalog" {
  type = list(object({ region = string, iaas_provider = string, environment = string, supports_trial = bool }))
}
locals {
  candidates = {
    for stage, env in var.environments : stage => distinct([
      for row in var.catalog : row.region
      if(env.region == null || row.region == env.region) &&
      (env.iaas_provider == null || row.iaas_provider == env.iaas_provider) &&
      row.environment == env.runtime &&
      (var.account_type != "trial" || row.supports_trial)
    ]) if env.enabled
  }
}

output "regions" {
  value = { for stage, candidates in local.candidates : stage => try(one(candidates), null) }
  precondition {
    condition     = alltrue([for candidates in values(local.candidates) : length(candidates) == 1])
    error_message = "Region/IaaS/runtime/profile combination is unavailable or ambiguous in btp_regions. Specify one actual region; no first-match fallback."
  }
}
