---
title: 'Request Datahub Access for Source Data'
type: 'chore'
created: '2026-05-22'
status: 'deferred'  # 2026-05-22: workbench access already granted; Datahub pattern N/A per Story 1.2 OQ-1 resolution
context:
  - 'ssot/infrastructure/bigquery-enterprise-datahub.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The pipeline service accounts cannot query Netscout source data in BigQuery. Without IAM bindings via the Datahub access config, all stored procedures in Epic 2 will fail with permission errors in both bi-stg and bi-srv.

**Approach:** Create `terraform/bi/roaming-intelligence.json` following the Datahub access pattern, listing both environment service accounts and the required `ent_*` dataset names identified in Story 1.2. Submit as a PR to `telus/tf-infra-cio-datahub-bilayer`.

## Boundaries & Constraints

**Always:**
- Include both `bi-stg` and `bi-srv` service accounts — binding only one causes cross-env failures.
- List datasets explicitly in the `enterprise.datasets` array — no wildcards.
- Follow the exact JSON structure from the Datahub access docs (service_account, service_accounts, resources with landing/work/enterprise sections).
- Dataset names must come from validated Story 1.2 findings (schema-mapping.md), not guesses.

**Ask First:**
- If Story 1.2 is not complete (OQ-1 unresolved), HALT — dataset names are unknown.
- If the source data is NOT via `ent_*` Datahub tables (direct access pattern), HALT — this story may be unnecessary.
- If additional datasets beyond the primary Netscout source are needed (e.g., reference tables for steering rules), HALT and discuss scope.

**Never:**
- Do not guess dataset names — they must come from validated schema discovery.
- Do not modify any files in the project repo itself — this is an external PR to `telus/tf-infra-cio-datahub-bilayer`.
- Do not merge the PR — it requires CODEOWNERS review and Terraform apply.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Standard Datahub access | Source is ent_* tables, datasets identified | JSON config with both SAs and dataset list | N/A |
| Multiple source datasets | Netscout data spans 2+ ent_* datasets | All datasets listed in enterprise.datasets array | N/A |
| Story 1.2 incomplete | OQ-1 unresolved, no schema-mapping.md | HALT — cannot determine datasets | Ask human to complete 1.2 first |
| Non-Datahub source | Data accessed directly, not via ent_* | Story is N/A — document and close | Notify human, skip PR |

</frozen-after-approval>

## Code Map

- `docs/schema-mapping.md` — REFERENCE: source table location and dataset names (from Story 1.2)
- `terraform/bi/roaming-intelligence.json` — NEW: Datahub access config (created in external repo, drafted locally for review)
- `stacks/roaming-intelligence/environment.j2` — REFERENCE: service account email pattern

## Tasks & Acceptance

**Execution:**
- [ ] Verify Story 1.2 completion — confirm `docs/schema-mapping.md` has OQ-1 resolved and source dataset names documented
- [ ] `terraform/bi/roaming-intelligence.json` — Draft the Datahub access JSON config locally at `docs/datahub-access-request.json` with: service_account name, both bi-stg and bi-srv SA emails, and enterprise.datasets array with validated ent_* dataset names
- [ ] Document PR instructions — add a "Datahub Access PR" section to `docs/schema-mapping.md` with the target repo, file path, and review process

**Acceptance Criteria:**
- Given the JSON config is drafted, when reviewed against the Datahub access template, then it contains both bi-stg and bi-srv service account emails and all required ent_* dataset names
- Given the PR instructions are documented, when the developer submits the PR to telus/tf-infra-cio-datahub-bilayer, then the file path and content are correct for CODEOWNERS review

## Design Notes

This is a **human-gated external PR**. The deliverable is a locally drafted JSON config and clear PR instructions. The developer must:
1. Verify dataset names from completed Story 1.2
2. Fill in actual GCP project IDs for service account emails
3. Submit the PR to the external repo
4. Wait for CODEOWNERS review + Terraform apply

The JSON draft lives at `docs/datahub-access-request.json` as a local reference — it gets copied into the external repo PR.

## Verification

**Manual checks (if no CLI):**
- `docs/datahub-access-request.json` exists and is valid JSON
- Both bi-stg and bi-srv service accounts are listed
- enterprise.datasets array contains the validated ent_* dataset names from schema-mapping.md
- No wildcards in the datasets array
