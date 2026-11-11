# SANDBOX = an org inside the SAME Harness account (single-account demo; a real setup uses a separate account).
# Account-level objects (roles, resource group, publisher service account) live only in accounts/production and are
# shared; this root manages just the sandbox org and the org-level variables, with sandbox running ahead of base.
provider "harness" {}

variable "account_id" {
  type = string
}

variable "org_id" {
  description = "Org identifier that plays the sandbox account"
  type        = string
  default     = "TemplateSandbox"
}

locals {
  base      = yamldecode(file("${path.module}/../../base/account_variables.yaml")).variables
  overrides = try(yamldecode(file("${path.module}/overrides.yaml")).overrides, {})
}

resource "terraform_data" "overrides_are_subset_of_base" {
  lifecycle {
    precondition {
      condition     = length(setsubtract(keys(local.overrides), keys(local.base))) == 0
      error_message = "overrides.yaml contains identifiers that are not in base/account_variables.yaml"
    }
  }
}

resource "harness_platform_organization" "sandbox" {
  identifier  = var.org_id
  name        = var.org_id
  description = "Sandbox for template authoring and canaries (promotes to the production org)"
  depends_on  = [terraform_data.overrides_are_subset_of_base]
}

resource "harness_platform_variables" "this" {
  for_each    = local.base
  org_id      = harness_platform_organization.sandbox.identifier
  identifier  = each.key
  name        = each.key
  description = each.value.description
  type        = "String"
  spec {
    value_type  = "FIXED"
    fixed_value = lookup(local.overrides, each.key, each.value.value)
  }
}

output "variable_identifiers" {
  value = sort(keys(harness_platform_variables.this))
}
