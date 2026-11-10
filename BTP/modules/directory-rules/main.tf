# Provider-free inventory checks, including reliable tests with multiple rows.
terraform { required_version = ">= 1.9.0, < 2.0.0" }
variable "project_id" { type = string }
variable "name" { type = string }
variable "managed_id" {
  type        = string
  default     = ""
  description = "Actual ID at the fixed resource address, verified by the mandatory HCP state preflight; empty on first creation."
}
variable "inventory" {
  type = list(object({
    id          = string
    name        = string
    project_ids = set(string)
  }))
}
output "unique" {
  value = (
    (var.managed_id == "" || contains([for directory in var.inventory : directory.id], var.managed_id)) &&
    alltrue([for directory in var.inventory :
      directory.id == var.managed_id || (lower(directory.name) != lower(var.name) && !contains(directory.project_ids, var.project_id))
    ])
  )
}
