output "variable_identifiers" {
  value = sort(keys(harness_platform_variables.this))
}
