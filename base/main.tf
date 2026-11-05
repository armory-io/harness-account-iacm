locals {
  rbac = yamldecode(file("${path.module}/rbac.yaml"))
}

# ---- account variables -------------------------------------------------------------------------------
resource "harness_platform_variables" "this" {
  for_each    = var.variables
  identifier  = each.key
  name        = each.key
  description = each.value.description
  type        = "String"
  spec {
    value_type  = "FIXED"
    fixed_value = each.value.value
  }
}

# ---- RBAC --------------------------------------------------------------------------------------------
resource "harness_platform_roles" "this" {
  for_each             = local.rbac.roles
  identifier           = each.key
  name                 = each.value.name
  permissions          = each.value.permissions
  allowed_scope_levels = ["account"]
}

# [Verify] resource filter shape. Standard Practice prefers specified resources over "all"; start with
# all TEMPLATE/VARIABLE resources at account scope and narrow once identifiers are stable.
resource "harness_platform_resource_group" "templates_and_variables" {
  account_id           = var.account_id
  identifier           = "templates_and_variables"
  name                 = "Templates and Variables"
  allowed_scope_levels = ["account"]
  included_scopes {
    filter     = "EXCLUDING_CHILD_SCOPES"
    account_id = var.account_id
  }
  resource_filter {
    include_all_resources = false
    resources {
      resource_type = "TEMPLATE"
    }
    resources {
      resource_type = "VARIABLE"
    }
  }
}

resource "harness_platform_service_account" "publisher" {
  account_id  = var.account_id
  identifier  = var.publisher_service_account
  name        = var.publisher_service_account
  email       = "${var.publisher_service_account}@example.invalid"
  description = "Only identity that writes templates, moves stable, edits plugin-version variables. No delete."
}

resource "harness_platform_role_assignments" "publisher" {
  resource_group_identifier = harness_platform_resource_group.templates_and_variables.identifier
  role_identifier           = harness_platform_roles.this["template_publisher"].identifier
  principal {
    identifier = harness_platform_service_account.publisher.identifier
    type       = "SERVICE_ACCOUNT"
  }
}

resource "harness_platform_role_assignments" "extra" {
  for_each = {
    for pair in flatten([
      for role, ps in var.role_assignments : [for p in ps : { key = "${role}-${p.identifier}", role = role, p = p }]
    ]) : pair.key => pair
  }
  resource_group_identifier = harness_platform_resource_group.templates_and_variables.identifier
  role_identifier           = harness_platform_roles.this[each.value.role].identifier
  principal {
    identifier = each.value.p.identifier
    type       = each.value.p.type
  }
}
