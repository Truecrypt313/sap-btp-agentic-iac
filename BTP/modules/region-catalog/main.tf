terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "~> 1.27.0"
    }
  }
}
variable "environments" { type = any }
variable "account_type" { type = string }

data "btp_regions" "available" {}

module "rules" {
  source       = "../region-rules"
  environments = var.environments
  account_type = var.account_type
  catalog      = data.btp_regions.available.values
}
output "regions" { value = module.rules.regions }
