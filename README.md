# harness-account-iacm

Manages the Harness **accounts themselves** with Harness IaCM (Terraform): account variables, RBAC roles, the
publish service account. It lives in, and runs from, the **production** account, and loads a shared **base**.

```
base/                      THE BASE. Canonical account variables (account_variables.yaml), roles (rbac.yaml), module
accounts/production/       root module: base + overrides.yaml (should be empty: production IS the base)
accounts/sandbox/          root module: base + overrides.yaml (sandbox runs ahead of base)
bootstrap/                 one-time: creates the IaCM workspaces (account_sandbox, account_production)
.harness/pipelines/        iacm-plan (every PR), iacm-promote (merge: sandbox -> canary -> sign-off -> production)
scripts/check_contract.py  templates repos' required variables must exist in base; overrides may not invent ids
```

## How "base -> production" works

1. **Identifier parity by construction.** Both account roots instantiate the same `base/` module over the same
   `account_variables.yaml`, so every identifier exists in both accounts. Overrides can change a *value*, never
   introduce an identifier (checked by a Terraform precondition and `check_contract.py`).
2. **Promotion = moving a value into base.** To bump Trivy: put the new value in `accounts/sandbox/overrides.yaml`
   (PR 1, applies to sandbox only; canaries run). Then move it into `base/account_variables.yaml` and delete the
   override (PR 2, platform owner approval). Merge applies sandbox (no-op), canaries, waits for sign-off, then
   applies production. Revert PR 2 to roll back.
3. **Why a variable change is gated like a bug fix:** it reaches every consumer's next run.

## Decisions to confirm
- Workspaces for **both** accounts live in the production account's IaCM; the sandbox workspace holds the *sandbox*
  admin service-account key as a secret. If you want strict separation, run a second IaCM instance in sandbox and
  split `iacm-promote` into two pipelines.
- `harness_platform_resource_group` is scoped to all TEMPLATE/VARIABLE resources for now; the design prefers
  specified resources.

## Local checks
```bash
for d in accounts/sandbox accounts/production bootstrap; do (cd $d && tofu init -backend=false && tofu validate); done
python scripts/check_contract.py ../harness-templates-sandbox ../harness-templates-prod
```
The IaCM stage/step YAML (`IACMTerraformPlugin`, `IACMApproval`) is unvalidated against a live account.
