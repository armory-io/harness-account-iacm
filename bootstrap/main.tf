# Run ONCE by hand (or from a break-glass pipeline) in the account that hosts IaCM (production).
# Creates one IaCM workspace per managed account. Each workspace points at accounts/<env>/ in this repo and
# carries the TARGET account's id and API key (a Harness secret identifier, never a literal).
terraform {
  required_providers {
    harness = {
      source  = "harness/harness"
      version = "~> 0.38"
    }
  }
}

provider "harness" {}

variable "org_id" {
  type    = string
  default = "default"
}
variable "project_id" {
  type    = string
  default = "platform_iacm"
}
variable "repository" {
  type    = string
  default = "harness-account-iacm"
}
variable "repository_connector" {
  type    = string
  default = "account.iacm_repo_github"
}
variable "targets" {
  description = "env => { account_id, api_key_secret }"
  type = map(object({
    account_id     = string
    api_key_secret = string
  }))
}

resource "harness_platform_workspace" "this" {
  for_each                = var.targets
  identifier              = "account_${each.key}"
  name                    = "account-${each.key}"
  org_id                  = var.org_id
  project_id              = var.project_id
  provisioner_type        = "terraform"
  provisioner_version     = "1.5.7"
  repository              = var.repository
  repository_branch       = "main"
  repository_path         = "accounts/${each.key}"
  repository_connector    = var.repository_connector
  cost_estimation_enabled = false

  terraform_variable {
    key        = "account_id"
    value      = each.value.account_id
    value_type = "string"
  }
  environment_variable {
    key        = "HARNESS_ACCOUNT_ID"
    value      = each.value.account_id
    value_type = "string"
  }
  environment_variable {
    key        = "HARNESS_PLATFORM_API_KEY"
    value      = each.value.api_key_secret
    value_type = "secret"
  }
}
