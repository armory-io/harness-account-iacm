variable "account_id" {
  type = string
}

variable "key" {
  description = "Resource set key (file name without .yaml). Prefixes every identifier the set creates."
  type        = string
}

variable "set" {
  description = "Parsed resource_sets/<key>.yaml"
  type = object({
    name        = string
    description = optional(string, "")
    orgs        = list(string)
    github_connectors = optional(map(object({
      name            = string
      url             = string
      connection_type = optional(string, "Account")
      application_id  = string
      installation_id = string
      private_key_ref = string
    })), {})
    vault_secret_managers = optional(map(object({
      name                     = string
      vault_url                = string
      renewal_interval_minutes = optional(number, 10)
      app_role_id              = string
      secret_id                = string
      base_path                = optional(string, "harness")
    })), {})
    access = object({
      rw = list(string)
      ro = list(string)
    })
  })
}
