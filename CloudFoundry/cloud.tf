
terraform {
  cloud {
    organization = "sap-ai-landing-zone"

    workspaces {
      name = "sap-cloudfoundry"
    }
  }
}
