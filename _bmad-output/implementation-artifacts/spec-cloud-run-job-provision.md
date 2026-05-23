---
title: 'Provision Cloud Run Job in Pulumi'
type: 'bugfix'
created: '2026-05-23'
status: 'done'
baseline_commit: 'add80a3'
context:
  - '{project-root}/ssot/engineering/pulumi-best-practices.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `Pulumi.yaml` workflow step6 calls a Cloud Run Job at `${process_nm}-report:run` (line 275), and `report_image` is defined (line 29), but no `gcp:cloudrunv2:Job` resource exists in the `resources:` block. The pipeline would 404 at step6. Additionally, `process_nm` = `roaming_intelligence` (underscores) produces an invalid Cloud Run name — Cloud Run requires `[a-z][a-z0-9-]*`.

**Approach:** Add a `job_nm` variable with the kebab-case name, define the `gcp:cloudrunv2:Job` resource with env vars matching `images/roaming-intelligence/src/config.py`, fix the workflow step6 URL to reference `${job_nm}`, and add `roles/run.invoker` IAM for the builder SA.

## Boundaries & Constraints

**Always:** Match env vars exactly to what `config.py:load_config()` expects (`GCP_PROJECT`, `DATASET`, `REPORT_BUCKET`). Use `{{ builder }}` SA from `environment.j2` consistently.

**Ask First:** If GCS bucket (`${report_bucket}`) also needs provisioning in this stack.

**Never:** Modify the Python container code, change the `process_nm` variable (used by BigQuery), or add resources beyond the Cloud Run Job + its IAM.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| `pulumi up` (happy) | All vars resolved from environment.j2 | Cloud Run Job created, workflow step6 URL matches job name | N/A |
| Job name validation | `job_nm = roaming-intelligence-report` | Passes Cloud Run `[a-z][a-z0-9-]*` constraint | Pulumi rejects invalid names at plan time |

</frozen-after-approval>

## Code Map

- `stacks/roaming-intelligence/Pulumi.yaml` -- Target file: variables, resources, and workflow sourceContents
- `stacks/roaming-intelligence/environment.j2` -- Provides `report_image`, `report_bucket`, `builder` SA (read-only)
- `images/roaming-intelligence/src/config.py` -- Defines env var contract: `GCP_PROJECT`, `DATASET`, `REPORT_BUCKET`, `REFRESH_DATE`

## Tasks & Acceptance

**Execution:**
- [x] `stacks/roaming-intelligence/Pulumi.yaml` -- Add `job_nm: roaming-intelligence-report` to `variables:` section
- [x] `stacks/roaming-intelligence/Pulumi.yaml` -- Add `report_job` resource of type `gcp:cloudrunv2:Job` with container env vars (`GCP_PROJECT`, `DATASET`, `REPORT_BUCKET`), `serviceAccount: {{ builder }}`, `maxRetries: 1`, in `resources:` block before the workflow
- [x] `stacks/roaming-intelligence/Pulumi.yaml` -- Fix workflow step6 URL: replace `${process_nm}-report` with `${job_nm}` in the `step6_generate_report` step
- [x] `stacks/roaming-intelligence/Pulumi.yaml` -- Add `gcp:cloudrunv2:JobIamMember` resource granting `roles/run.invoker` to `serviceAccount:{{ builder }}` on the report job

**Acceptance Criteria:**
- Given the Pulumi YAML is rendered, when `pulumi preview` runs, then the Cloud Run Job resource appears in the plan with name `roaming-intelligence-report`
- Given step6 in the workflow, when the URL is resolved, then it references `roaming-intelligence-report` (no underscores)
- Given the Cloud Run Job resource, when its container spec is inspected, then env vars `GCP_PROJECT`, `DATASET`, `REPORT_BUCKET` are set to the correct Pulumi variable references
- Given the IAM binding, when the builder SA is checked, then it has `roles/run.invoker` on the report job

## Verification

**Manual checks (if no CLI):**
- Inspect rendered `Pulumi.yaml` for valid Cloud Run Job resource with correct name, env vars, SA, and IAM
- Confirm workflow step6 URL uses `${report_job.name}` not `${process_nm}-report`

## Suggested Review Order

- Cloud Run Job resource: name, image, env vars, SA, maxRetries
  [`Pulumi.yaml:222`](../../stacks/roaming-intelligence/Pulumi.yaml#L222)

- Kebab-case variable fixing the underscore naming bug
  [`Pulumi.yaml:32`](../../stacks/roaming-intelligence/Pulumi.yaml#L32)

- Workflow step6 URL now references `${report_job.name}` (also creates Pulumi dependency)
  [`Pulumi.yaml:301`](../../stacks/roaming-intelligence/Pulumi.yaml#L301)

- IAM binding granting `roles/run.invoker` to the builder SA
  [`Pulumi.yaml:426`](../../stacks/roaming-intelligence/Pulumi.yaml#L426)
