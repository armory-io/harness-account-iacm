# One resource set = the resources, the resource group that selects exactly them, a RW and an RO role, and the
# bindings of user groups to those roles. All in one apply, so a set can never exist half-bound.
locals {
  p              = replace(var.key, "-", "_")
  ro_permissions = ["core_connector_view", "core_connector_access"]
  rw_permissions = concat(local.ro_permissions, ["core_connector_edit", "core_connector_create", "core_connector_delete"])
}

# ---- resources (account scope) -----------------------------------------------------------------------
resource "harness_platform_connector_github" "this" {
  for_each        = var.set.github_connectors
  identifier      = each.key
  name            = each.value.name
  url             = each.value.url
  connection_type = each.value.connection_type
  credentials {
    http {
      github_app {
        application_id  = each.value.application_id
        installation_id = each.value.installation_id
        private_key_ref = each.value.private_key_ref
      }
    }
  }
  api_authentication {
    github_app {
      application_id  = each.value.application_id
      installation_id = each.value.installation_id
      private_key_ref = each.value.private_key_ref
    }
  }
}

resource "harness_platform_connector_vault" "this" {
  for_each                 = var.set.vault_secret_managers
  identifier               = each.key
  name                     = each.value.name
  vault_url                = each.value.vault_url
  renewal_interval_minutes = each.value.renewal_interval_minutes
  app_role_id              = each.value.app_role_id
  secret_id                = each.value.secret_id
  base_path                = each.value.base_path
  use_vault_agent          = false
  read_only                = true
  default                  = false
}

# ---- resource group: ONLY this set's identifiers ------------------------------------------------------
# Account-scope resources are invisible to everyone until a binding points at a group that lists them by identifier.
# No include_all_resources, no type-wide entries. Depends on the resources so it never names identifiers that do not exist.
resource "harness_platform_resource_group" "this" {
  account_id           = var.account_id
  identifier           = "rs_${local.p}"
  name                 = "Resource set: ${var.set.name}"
  description          = var.set.description
  allowed_scope_levels = ["account", "organization"]

  included_scopes {
    filter     = "EXCLUDING_CHILD_SCOPES"
    account_id = var.account_id
  }

  resource_filter {
    include_all_resources = false
    # Secret managers are CONNECTOR resources in RBAC, so one CONNECTOR entry covers both.
    resources {
      resource_type = "CONNECTOR"
      identifiers = concat(
        [for k, r in harness_platform_connector_github.this : r.identifier],
        [for k, r in harness_platform_connector_vault.this : r.identifier],
      )
    }
  }
}

# ---- roles: generated RW / RO ------------------------------------------------------------------------
resource "harness_platform_roles" "ro" {
  identifier           = "rs_${local.p}_ro"
  name                 = "Resource set ${var.set.name}: read only"
  allowed_scope_levels = ["account", "organization"]
  permissions          = local.ro_permissions
}

resource "harness_platform_roles" "rw" {
  identifier           = "rs_${local.p}_rw"
  name                 = "Resource set ${var.set.name}: read write"
  allowed_scope_levels = ["account", "organization"]
  permissions          = local.rw_permissions
}

# ---- bindings: user group -> RG -> role, one per listed org, created after both exist ---------------------
# The org list decides where the binding exists; the resource group decides what it reaches.
# [Verify] an org-scope assignment may reference the account-scope group and role this way.
locals {
  bindings = {
    for b in flatten([
      for org in var.set.orgs : concat(
        [for g in var.set.access.rw : { key = "${org}/rw/${g}", org = org, group = g, role = harness_platform_roles.rw.identifier }],
        [for g in var.set.access.ro : { key = "${org}/ro/${g}", org = org, group = g, role = harness_platform_roles.ro.identifier }],
      )
    ]) : b.key => b
  }
}

resource "harness_platform_role_assignments" "this" {
  for_each                  = local.bindings
  org_id                    = each.value.org
  resource_group_identifier = harness_platform_resource_group.this.identifier
  role_identifier           = each.value.role
  principal {
    identifier  = each.value.group
    type        = "USER_GROUP"
    scope_level = "account"
  }
}
