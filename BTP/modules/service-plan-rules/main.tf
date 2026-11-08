terraform { required_version = ">= 1.9.0, < 2.0.0" }

# Shared by the legacy DEV baseline and generic services. Pure rules also allow
# explicit-ID identity regressions to be tested without deferred API lookups.
variable "actual" {
  type = object({
    name      = string, offering_name = string, ready = bool,
    shareable = bool, supported_platforms = set(string)
  })
}
variable "offering" { type = string }
variable "plan" { type = string }
variable "shared" { type = bool }
variable "required_platform" { type = string }

output "valid" {
  value = (
    var.actual.name == var.plan && var.actual.offering_name == var.offering &&
    var.actual.ready && (var.shared != true || var.actual.shareable) &&
    (var.required_platform == null ? true : contains(var.actual.supported_platforms, var.required_platform))
  )
}
