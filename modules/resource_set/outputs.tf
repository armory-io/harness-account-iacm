output "resource_group" {
  value = harness_platform_resource_group.this.identifier
}
output "roles" {
  value = [harness_platform_roles.ro.identifier, harness_platform_roles.rw.identifier]
}
