# Template promotion flow: from a person to production and back

How a template change travels, who or what acts at each step, how it is monitored, and how it is undone.
Companion to [PROMOTION-OVERVIEW.md](PROMOTION-OVERVIEW.md). Diagrams are Mermaid (GitHub renders them).

Legend used throughout: solid boxes exist today; **dashed boxes are planned or still demo-bypassed** (see the
shortcuts table in the overview).

## 1. End to end

```mermaid
flowchart LR
    P([Template author]) -->|branch + PR| SPR

    subgraph SB["harness-templates-sandbox (org TemplateSandbox)"]
        SPR[Sandbox PR]
        SCI["GitHub Actions checks<br/>yamllint, lint, classify, stable<br/>PR title check"]
        SM[Merge to main]
        GX1["Harness GitX<br/>registers the template<br/>in TemplateSandbox"]
        PS["Publish_Templates_Sandbox<br/>apply stable.yaml (sandbox)"]
        PR_["Promote_Templates_Sandbox_to_Prod<br/>lint, map org, open PR"]
        SPR --> SCI -->|green| SM
        SM --> GX1
        SM --> PS
        SM --> PR_
    end

    PR_ -->|"promote: templates at SHA"| PPR

    subgraph PD["harness-templates-prod (org InternalOps)"]
        PPR[Promotion PR]
        PCI["Actions checks +<br/>pr_validate_prod:<br/>Validate, AI review, Gate"]
        H{{"Human review<br/>and sign-off"}}
        PM[Merge to main]
        GX2["Harness GitX<br/>registers the template<br/>in InternalOps"]
        PP["publish_production<br/>apply stable.yaml (production)"]
        PPR --> PCI --> H -->|approve| PM
        PM --> GX2
        PM --> PP
    end

    PR_ -. "comment: promotion PR opened" .-> SPR
    PP -. "comment: released / failed" .-> SPR
    PP --> MON["Monitoring<br/>(section 5)"]
    H -->|decline| X(["Close the PR,<br/>nothing changes in prod"])
    SCI -->|red| FIX(["Author fixes<br/>the PR"])
```

Key rules the flow encodes:

- Nobody authors in the prod repo. Template content reaches prod only through a `promote: templates at <sha>` PR
  opened by the sandbox pipeline. The promotion is identified by the sandbox commit SHA.
- Nothing auto-merges. `auto_merge` is off; the human merge in prod is the release sign-off.
- Moving a **stable** marker is its own PR in prod (never in the same PR as the template that introduced the
  version), so each revert is clean.
- Harness **GitX** registers the files; our own `stable.yaml` + `set_stable.sh` decide which version is stable.

## 2. One promotion over time

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Author
    participant GH as GitHub (sandbox repo)
    participant CI as GitHub Actions
    participant HS as Harness (TemplateSandbox)
    participant PP as Promote pipeline
    participant GP as GitHub (prod repo)
    actor Own as Template owner
    participant HP as Harness (InternalOps)

    Dev->>GH: open PR (edit or add a version file)
    GH->>CI: lint, classify, stable, title
    CI-->>GH: pass/fail + label bugfix|minor|major
    Dev->>GH: merge (after review)
    GH->>HS: push to main: GitX registers/updates template
    GH->>HS: Publish_Templates_Sandbox applies stable (retries until GitX has registered it)
    GH->>PP: push trigger with the commit SHA
    PP->>PP: lint, rewrite orgIdentifier to InternalOps
    PP->>GP: open "promote: templates at SHA"
    PP-->>GH: comment on the sandbox PR: promotion PR opened + link
    GP->>GP: Actions checks + pr_validate_prod (Validate, AI review, Gate)
    Own->>GP: review the diff, the AI review and the Gate
    alt approve
        Own->>GP: merge
        GP->>HP: push to main: GitX registers/updates template
        GP->>HP: publish_production applies stable.yaml
        HP-->>GH: comment on the sandbox PR: released to production (or failed)
    else decline
        Own->>GP: close the PR (production untouched)
    end
```

## 3. What the checks decide

Every change to a template file is classified from the diff, and each class has hard limits. A violation fails the
PR in sandbox and again in prod.

```mermaid
flowchart TD
    A[Changed template file] --> B{"Git<br/>status"}
    B -->|Modified in place| C["BUGFIX<br/>inputs unchanged<br/>structure unchanged<br/>downstream pins unchanged"]
    B -->|New version file| D{"Same major<br/>as the latest?"}
    B -->|Deleted| E{"Where?"}
    B -->|Moved only| R["RELOCATION<br/>same content, new path<br/>not a promotion"]
    D -->|"yes: v1.0 to v1.1"| F["MINOR<br/>only downstream pin<br/>versions change;<br/>inputs and structure identical"]
    D -->|"no: v1.x to v2.0"| G["MAJOR<br/>needs migration notes in<br/>docs/migrations/<br/>pipeline templates: new<br/>identifier instead"]
    E -->|"sandbox, never<br/>reached production"| H["Retire allowed"]
    E -->|"prod, or reached<br/>production"| I["Rejected"]
    C --> Z{"Lint rules<br/>pass?"}
    F --> Z
    G --> Z
    R --> Z
    Z -->|"image tag is an account variable<br/>account vars in required.yaml<br/>no org or project references<br/>exact pins, pipeline templates<br/>follow stable"| OK(["PR can merge"])
    Z -->|otherwise| NO(["PR fails"])
```

Demo of the failing side: sandbox PR #16 (inputs changed in place + hard-coded image).

## 4. Bad paths

```mermaid
flowchart TD
    subgraph CAUGHT_AUTO["Caught by automation"]
        A1["Input added to an<br/>existing version,<br/>hard-coded image tag,<br/>stable moved to<br/>different inputs"] --> A2["Actions check<br/>fails in sandbox"]
        A2 --> A3["Author fixes or<br/>opens a new MAJOR"]
    end
    subgraph CAUGHT_HUMAN["Valid but wrong"]
        B1["Bugfix that passes every rule<br/>e.g. trivy exit-code 0,<br/>so the scan never fails"] --> B2["Merges in sandbox,<br/>rehearsed in TemplateSandbox"]
        B2 --> B3["Promotion PR<br/>in prod"]
        B3 --> B4{"AI review<br/>and owner"}
        B4 -->|spots it| B5["Close the PR,<br/>revert in sandbox"]
        B4 -->|misses it| B6["Merged: see<br/>rollback, section 6"]
    end
    subgraph DIRECT["Bypassing the pipeline"]
        C1["Hand-written change<br/>in the prod repo"] --> C2["promote: title rule fails<br/>templates and stable<br/>in one PR fails<br/>CODEOWNERS needs<br/>platform and template owners"]
    end
```

Demo of the middle path: sandbox PR #17 (`--exit-code 0`) and the resulting promotion PR in prod.

## 5. After promotion: feedback and monitoring

```mermaid
flowchart LR
    M[Promotion merged in prod] --> PP[publish_production run]
    PP -->|always| C1["Comment on the original<br/>sandbox PR: released or<br/>failed, with run link"]
    PP --> GXS["Template shows the<br/>new commit in InternalOps<br/>(GitX git details)"]
    PP --> ST["stable.yaml applied<br/>(retry until<br/>GitX registers)"]
    GXS --> V["Harness Referenced By:<br/>consumers see the update"]
    V -.-> W["Canary pipelines in prod<br/>(runner is a stub today)"]
    W -.-> AL["Alert or auto-open revert PR<br/>on canary or consumer<br/>failures"]
    style W stroke-dasharray: 5 5
    style AL stroke-dasharray: 5 5
```

What exists today: the run result and the two comments on the sandbox PR, the template's git details in Harness
(commit id, file path), and the consumer registry (`registry/consumers.yaml`) for finding API callers that
*Referenced By* cannot see. What does **not** exist yet (dashed): the canary runner (`scripts/run_canaries.sh` is a
fail-closed stub, bypassed by `SKIP_CANARY`) and any automatic reaction to consumer failures after release.

## 6. Rollback

Pick the row by *how far the change got*.

```mermaid
flowchart TD
    S{"How far did<br/>it get?"} -->|"Open PR, red or wrong"| R1["Fix or close<br/>the PR"]
    S -->|"Merged in sandbox only"| R2["Revert PR in sandbox<br/>(a new commit; the next<br/>promotion carries the revert)"]
    S -->|"Promotion PR open in prod"| R3["Close it without merging,<br/>prod untouched"]
    S -->|"Promotion merged in prod"| T{"What was<br/>it?"}
    T -->|"In-place bugfix"| R4["Revert the promotion PR<br/>in prod; GitX re-syncs<br/>the file in place"]
    T -->|"New version, stable not moved"| R5["Nothing consumes it<br/>unless pinned. Leave it,<br/>or revert the file and delete<br/>the version in Harness<br/>(GitX does not sync deletes)"]
    T -->|"Stable marker moved"| R6["Revert the stable PR;<br/>publish re-applies the<br/>previous marker; no<br/>consumer PRs needed"]
    R4 --> V["Verify: template git details<br/>show the revert commit,<br/>the sandbox PR gets a<br/>new released comment"]
    R6 --> V
```

Notes:

- **Stable is the consumer lever.** Pipeline templates follow stable, so moving stable back is the fast rollback;
  step and stage templates are pinned by consumers and are unaffected until a consumer changes its pin.
- **GitX does not delete.** Removing a version file from Git leaves the registered version in Harness. Delete
  non-stable versions first; the stable version cannot be deleted while others exist (the UI and API both refuse),
  and the last remaining version can be.
- **Reverts are ordinary PRs.** They go through the same checks. A revert that restores content classifies as a
  bugfix like the original change.
- **The CODEOWNERS sign-off still applies** to a revert of a promotion; there is no emergency bypass in this demo.

## 7. Who does what

| Step | Actor | Where it runs |
|---|---|---|
| Author, open PR | Template author | GitHub (sandbox repo) |
| Lint, classify, stable, title, label | GitHub Actions | GitHub |
| Register template | Harness GitX (org webhook) | Harness, org `TemplateSandbox` / `InternalOps` |
| Apply `stable.yaml` | `Publish_Templates_Sandbox` / `publish_production` + `set_stable.sh` | Harness, project `Template_Promotion_Management` |
| Open promotion PR, map org | `Promote_Templates_Sandbox_to_Prod` | Harness |
| Validate, AI review, Gate | `pr_validate_prod` | Harness, reported to GitHub as checks |
| Release sign-off | Platform + template owners | GitHub review/merge |
| Report back on the sandbox PR | `scripts/promotion_status.py` | both publish/promote pipelines |
| Account variables, roles, service accounts | `harness-account-iacm` | OpenTofu workspaces |
