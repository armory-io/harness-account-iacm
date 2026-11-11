# Harness onboarding & promotion: how we SHOULD operate

Four repos implementing *Harness Account-Level Template Promotion: Standard Practice (DRAFT)*.

| Repo | Account | Role |
|---|---|---|
| `harness-templates-sandbox` | sandbox | Author + test templates; hosts the promotion pipeline |
| `harness-templates-prod` | production | Receives promoted templates by PR; publishes + moves stable |
| `harness-account-iacm` | production (IaCM) | Account variables, RBAC, service accounts for **both** accounts, base + overrides |
| (the design) | Confluence | Policy these repos encode |

```
 PR (label bugfix|minor|major)           Variable bump (plugin/tool version)
        │ CI: lint, classify, stable            │ CI: contract, validate, plan
        ▼                                       ▼
 harness-templates-sandbox  ── merge ──►  publish-sandbox: register, stable, canaries
        │                                       │          harness-account-iacm
        │ promote-templates (input: SHA)        │          accounts/sandbox ──► apply sandbox
        │  gate on canary → lint → AI review    │                │ canary
        ▼                                       │                ▼ sign-off
 PR to harness-templates-prod (never auto-merged)│          base/ ──► apply production
        │ platform-owner approval = release     │
        ▼
 publish-production: register, apply stable.yaml, tag   (stable move = its own later PR)
```

## Demo script
1. **Bug fix (in place, no consumer action).** Edit `run_security_scan_v1.3.yaml` in sandbox, label `bugfix`.
   Show CI failing if you also touch an input. Merge → publish-sandbox → canary → promote.
2. **Plugin bump via variable.** Sandbox already carries `trivy_version: 0.58.0` as an override. Move it to
   `base/account_variables.yaml` (PR), watch sandbox → canary → sign-off → production. No template changed.
3. **Promote a MINOR chain.** Sandbox is ahead (step v1.3, stage v2.1, pipeline v1.1). Run the promote pipeline at
   the sandbox SHA. A PR appears in the prod repo; approve + merge. Then a second PR moves `standard_cd` stable
   to v1.1 (CI proves the inputs are identical).
4. **Breaking change.** Try changing an input on `standard_cd` v1.1→v1.2 and stable; CI refuses. The right path is
   `standard_cd_2` v1.0.
5. **Rollback.** Revert the stable PR in prod; publish re-applies the old marker. No consumer PRs.

## What was verified here vs. not
Verified locally: all repo CI scripts (positive and negative cases), YAML lint, `tofu validate` for
`register/`, both account roots and `bootstrap/` against the real Harness provider schema.
**Not verified (no Harness account):** any pipeline YAML running, IACM step types, the set-stable API call, the
Terraform template import behavior (design open item 7), the GitHub app promotion plugin. The three canary/consumer
scripts are fail-closed stubs. `armory-io/*` repo names, connector ids and secret ids are placeholders.

## Single-account demo mode

For the demo, "sandbox" is an org (`TemplateSandbox`) in the same Harness account as production (org `InternalOps`).
- `accounts/production` manages the account-level objects (variables, roles, resource group, publisher service account).
- `accounts/sandbox` manages only the sandbox org and org-level variables (base + overrides).
- Both workspaces point at the same account id; give each its own API key if you want sandbox unable to write to prod.
- Not demonstrated in this mode: account-variable divergence (account variables are shared, so the sandbox override only
  exists as an org-level variable), account-level isolation, and cross-account identifier parity.

## Demo-only: canary bypass

`iacm-promote` has a `SKIP_CANARY` input (default `false`). The canary runner is still a stub that fails closed, so
set `SKIP_CANARY=true` to reach the production approval and apply stages. The run prints a warning. `SKIP_APPROVAL` (see below) bypasses the sign-off separately. Remove the input when the canary runner is implemented.

## Demo shortcuts to undo before real use

Everything here exists only to make a single-person, single-account demo work. Track it; each item needs an owner
and a date before this is used for real.

| Shortcut | Why it exists | Do before real use |
|---|---|---|
| `prod_publish_key` is an admin key reused for the account IaCM workspaces, both prod and sandbox, the template publish/register pipelines, and passed as `HARNESS_TOKEN` to the `template_pr_review` AI agent | One key was quick to set up | **Rotate it**, move it to a dedicated non-admin service account with only template, variable, role and org rights; give sandbox, the prod publisher and the AI agent separate keys; the agent gets a view-only key. Planned: rotate after testing completes. |
| `SKIP_CANARY` input on `iacm-promote` | The canary runner is a fail-closed stub | Implement the runner, remove the input |
| `SKIP_APPROVAL` input on `iacm-promote` | The person who runs the pipeline cannot approve their own run | Remove the input |
| Approver group is `Harness_Account_Admins`; `template_consumer` goes to `_account_all_users` | The groups `_platform_owners` and `all_engineers` do not exist | Create dedicated groups and point both at them |
| One Harness account; sandbox is the org `TemplateSandbox` | Less setup | Separate accounts, so account-level isolation and variable divergence are real |
| GitHub App id and installation id are fixed pipeline variables in `pr_validate_prod` | Quick | Move to account variables |
| Old agents `template_pr_reviewer` and `plan_explainer` | Created with a placeholder image that does not exist | Delete or rebuild as `harnessAI` worker agents |
| `publish_production` has no push trigger | Org-scope template registration is not yet proven | Add the trigger once org-scope apply is verified |
| No branch protection on the template repos | Demo | Require `checks`, PR Title Checker, `pr_validate_prod-Gate`, and code-owner review |
