# Resource sets

One YAML file here = one **resource set**. Merging it to `main` creates, in the production account and in one
apply:

1. the resources: GitHub connectors and Vault secret managers (account scope). Templates are not managed here; GitX owns them.
2. a resource group `rs_<key>` that lists exactly those identifiers (no "all resources", no type-wide entries)
3. roles `rs_<key>_rw` and `rs_<key>_ro`
4. the bindings, created last: each `access.rw` / `access.ro` user group -> role, on that group, in each org in `orgs`

```
Group X -> rs_<key> -> rs_<key>_rw
Group Y -> rs_<key> -> rs_<key>_ro
```

Account-scope resources are invisible until a binding points at a group listing them. The resource group is the only
grant; no default or all-users binding is created. `orgs` decides where the bindings exist.

Add a set: `resource_sets/<key>.yaml`, one commit. Secrets are referenced (`private_key_ref`, `secret_id`), never
inlined. Applied by `.harness/pipelines/iacm-resource-sets.yaml`; a plan that deletes anything stops the run.

## Open items
- [Verify] an org-scope role assignment can reference the account-scope group and role, and that the result reaches
  only the listed identifiers. Also check no existing broad binding (e.g. an all-connectors role) already exposes them.
- More connector kinds (AWS, GCP, Azure KV) need a new block in `modules/resource_set`; Vault auth is AppRole only.
- Roles carry `core_connector_*` only. Add `core_secret_*` if a set should also manage secrets.
- No push trigger is defined yet for the pipeline, and the plan-JSON hand-off in the destroy check is unverified.
