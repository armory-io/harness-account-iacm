# Resource sets: every resource_sets/<key>.yaml becomes resources + resource group + RW/RO roles + bindings in one
# apply. Production only; adding a set is a single commit (one YAML file). See resource_sets/README.md.
locals {
  resource_sets = {
    for f in fileset("${path.module}/../../resource_sets", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/../../resource_sets/${f}"))
  }
}

module "resource_set" {
  for_each   = local.resource_sets
  source     = "../../modules/resource_set"
  account_id = var.account_id
  key        = each.key
  set        = each.value
}
