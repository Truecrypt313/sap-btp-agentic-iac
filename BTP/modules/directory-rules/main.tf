# Provider-free inventory checks, including reliable tests with multiple rows.
terraform { required_version = ">= 1.9.0, < 2.0.0" }
variable "project_id" { type = string }
variable "name" { type = string }
variable "inventory" {
  type = list(object({
    name        = string
    project_ids = set(string)
  }))
}
output "unique" {
  value = alltrue([for directory in var.inventory :
    lower(directory.name) != lower(var.name) && !contains(directory.project_ids, var.project_id)
  ])
}
