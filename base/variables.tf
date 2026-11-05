variable "account_id" {
  description = "Target Harness account identifier"
  type        = string
}

variable "variables" {
  description = "Account variables to manage: identifier => { description, value }"
  type = map(object({
    description = string
    value       = string
  }))
}

variable "publisher_service_account" {
  description = "Identifier of the service account that is the only writer of templates/variables in this account"
  type        = string
  default     = "template_publisher"
}

variable "role_assignments" {
  description = "Extra assignments: role key from rbac.yaml => list of { identifier, type } (USER_GROUP | SERVICE_ACCOUNT)"
  type = map(list(object({
    identifier = string
    type       = string
  })))
  default = {}
}
