# Root module for the sandbox account. Loads the BASE and applies this account's overrides.
# Auth comes from the IaCM workspace environment (HARNESS_ACCOUNT_ID, HARNESS_PLATFORM_API_KEY);
# the key belongs to the TARGET account's admin service account, not the account running IaCM.
provider "harness" {}

variable "account_id" {
  type = string
}

locals {
  base      = yamldecode(file("${path.module}/../../base/account_variables.yaml")).variables
  overrides = try(yamldecode(file("${path.module}/overrides.yaml")).overrides, {})
}

# Overrides may only change values of identifiers the base defines (identifier parity).
resource "terraform_data" "overrides_are_subset_of_base" {
  lifecycle {
    precondition {
      condition     = length(setsubtract(keys(local.overrides), keys(local.base))) == 0
      error_message = "overrides.yaml contains identifiers that are not in base/account_variables.yaml"
    }
  }
}

module "account" {
  source     = "../../base"
  account_id = var.account_id
  variables = {
    for k, v in local.base : k => {
      description = v.description
      value       = lookup(local.overrides, k, v.value)
    }
  }
  role_assignments = try(yamldecode(file("${path.module}/role_assignments.yaml")), {})
  depends_on       = [terraform_data.overrides_are_subset_of_base]
}

output "variable_identifiers" {
  value = module.account.variable_identifiers
}
