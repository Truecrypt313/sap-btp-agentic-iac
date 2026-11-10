# Read the actual repository binding, never manage/import the reference workspace.
locals {
  bootstrap_active = var.bootstrap_enabled && terraform.workspace == "sap-btp-project-bootstrap"
  repository       = "Truecrypt313/sap-btp-agentic-iac"
  github_account   = "Truecrypt313"
}
data "tfe_workspace" "vcs_reference" {
  count        = local.bootstrap_active ? 1 : 0
  organization = "sap-ai-landing-zone"
  name         = "sap-btp-core"
  lifecycle {
    postcondition {
      condition = try(
        length(self.vcs_repo) == 1 && self.vcs_repo[0].identifier == local.repository &&
        length(compact([self.vcs_repo[0].github_app_installation_id, self.vcs_repo[0].oauth_token_id])) == 1 &&
        ((self.vcs_repo[0].github_app_installation_id == null || self.vcs_repo[0].github_app_installation_id == "") ?
          can(regex("^ot-[A-Za-z0-9]{16}$", self.vcs_repo[0].oauth_token_id)) :
        can(regex("^ghain-[A-Za-z0-9]{16}$", self.vcs_repo[0].github_app_installation_id))), false
      )
      error_message = "sap-btp-core must use exactly one valid GitHub App or OAuth connection for Truecrypt313/sap-btp-agentic-iac; missing, foreign or ambiguous VCS bindings are forbidden."
    }
  }
}
locals {
  reference_vcs   = try(one(data.tfe_workspace.vcs_reference[0].vcs_repo), null)
  reference_app   = try(coalesce(local.reference_vcs.github_app_installation_id, ""), "")
  reference_oauth = try(coalesce(local.reference_vcs.oauth_token_id, ""), "")
  reference_valid = try(
    local.reference_vcs.identifier == local.repository &&
    ((local.reference_app != "") != (local.reference_oauth != "")) &&
    (local.reference_app != "" ? can(regex("^ghain-[A-Za-z0-9]{16}$", local.reference_app)) : can(regex("^ot-[A-Za-z0-9]{16}$", local.reference_oauth))), false
  )
}
data "tfe_github_app_installation" "repository" {
  count = local.bootstrap_active && local.reference_valid && local.reference_app != "" ? 1 : 0
  name  = local.github_account
  lifecycle {
    postcondition {
      # v0.83.0's name lookup alone is not a uniqueness check. Accept only the
      # precise internal ID already bound to the verified repository above.
      condition     = self.name == local.github_account && self.id == local.reference_app
      error_message = "GitHub App discovery must match the exact installation already used by sap-btp-core for this repository; do not select another installation by account name alone."
    }
  }
}
data "tfe_oauth_client" "repository" {
  count            = local.bootstrap_active && local.reference_valid && local.reference_oauth != "" ? 1 : 0
  organization     = "sap-ai-landing-zone"
  service_provider = "github"
  lifecycle {
    postcondition {
      condition     = self.oauth_token_id == local.reference_oauth && try(trimsuffix(self.http_url, "/") == "https://github.com", false)
      error_message = "OAuth must be the GitHub connection actually used by sap-btp-core for this repository; missing or ambiguous clients are forbidden."
    }
  }
}
locals {
  vcs_valid = local.reference_valid && (local.reference_app == "" ? try(
    data.tfe_oauth_client.repository[0].oauth_token_id == local.reference_oauth &&
    trimsuffix(data.tfe_oauth_client.repository[0].http_url, "/") == "https://github.com", false
    ) : try(
    data.tfe_github_app_installation.repository[0].id == local.reference_app &&
    data.tfe_github_app_installation.repository[0].name == local.github_account, false
  ))
  detected_vcs = {
    github_app_installation_id = try(data.tfe_github_app_installation.repository[0].id, null)
    oauth_token_id             = try(data.tfe_oauth_client.repository[0].oauth_token_id, null)
  }
}
