---
title: 'Create BigQuery Dataset and Core Table Definitions'
type: 'feature'
created: '2026-05-22'
status: 'done'
baseline_commit: 'NO_VCS'
context:
  - '_bmad-output/planning-artifacts/architecture.md'
  - 'docs/schema-mapping.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The pipeline stored procedures (Epic 2) need target tables to write to, and the report generator needs curated views to read from. No BigQuery table schemas exist yet. Additionally, OQ-1 revealed the source lacks a country column — MCC-to-country lookup is needed.

**Approach:** Add all staging table schemas, curated MV placeholders, an MCC-to-country reference table, and refined IAM bindings to the existing Pulumi.yaml. All tables partitioned by `refresh_date`.

## Boundaries & Constraints

**Always:**
- All tables in the `roaming_intelligence` dataset, `northamerica-northeast1`.
- Daily DATE partition on `refresh_date` for all staging and curated tables.
- Column names follow naming conventions: `snake_case`, `kpi_*` prefix for raw KPIs, `norm_*` for normalized.
- MCC-to-country reference table must include `mcc`, `country_name`, `country_code` (ISO 3166-1 alpha-2).
- IAM: `dataEditor` scoped to `roaming_intelligence` dataset only (not project-wide). `dataViewer` on source dataset if cross-project read is needed.

**Ask First:**
- If Pulumi YAML syntax for BigQuery table schemas differs from expected patterns, HALT.
- If the MCC reference table should be populated from an external source vs. static seed data, HALT.

**Never:**
- Do not implement stored procedures — that's Epic 2.
- Do not create curated MVs with actual SQL queries — use placeholder view definitions that return empty results.
- Do not use Pulumi-Python — YAML+Jinja only.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Clean deploy | No existing tables | All 9 tables + 1 reference table created | N/A |
| Redeploy | Tables exist from prior run | Pulumi detects no drift, no changes | N/A |
| Missing partition | Table created without partition | Deploy fails validation | Pulumi schema error |

</frozen-after-approval>

## Code Map

- `stacks/roaming-intelligence/Pulumi.yaml` — MODIFY: add BigQuery table resources, MCC reference table, refine IAM
- `stacks/roaming-intelligence/environment.j2` — REFERENCE: env-specific variables
- `docs/schema-mapping.md` — REFERENCE: confirmed column mappings from OQ-1

## Tasks & Acceptance

**Execution:**
- [x] `stacks/roaming-intelligence/Pulumi.yaml` — Add `stg_carrier_kpi_daily` table with all columns from schema mapping (refresh_date, country_name, country_code, carrier_name, mcc, mnc, is_steered, 4 raw KPIs, 4 normalized KPIs, 3 usage metrics), partitioned by refresh_date
- [x] `stacks/roaming-intelligence/Pulumi.yaml` — Add `stg_carrier_composite_daily` table (refresh_date, country_code, carrier_name, mcc, mnc, composite_quality_score), partitioned by refresh_date
- [x] `stacks/roaming-intelligence/Pulumi.yaml` — Add `stg_carrier_degradation_daily` table (refresh_date, country_code, carrier_name, mcc, mnc, degradation_flag, degradation_details), partitioned by refresh_date
- [x] `stacks/roaming-intelligence/Pulumi.yaml` — Add `stg_data_quality_log` table (refresh_date, step_name, start_time, end_time, row_count, status, message), partitioned by refresh_date
- [x] `stacks/roaming-intelligence/Pulumi.yaml` — Add 4 `crt_mv_*` placeholder view resources (carrier_quality_summary, country_quality_summary, carrier_quality_trend, carrier_usage_summary) returning empty result sets
- [x] `stacks/roaming-intelligence/Pulumi.yaml` — Add `ref_mcc_country` reference table (mcc STRING, country_name STRING, country_code STRING) for MCC-to-country lookup used by sp_refresh_carrier_kpis
- [x] `stacks/roaming-intelligence/Pulumi.yaml` — Refine IAM: scope `dataEditor` to `roaming_intelligence` dataset only; add `dataViewer` on source dataset for cross-project reads
- [x] `stacks/roaming-intelligence/sql/seed/ref_mcc_country.csv` — Create seed data CSV with MCC-to-country mappings (ITU MCC allocations)

**Acceptance Criteria:**
- Given the Pulumi stack is deployed, when BigQuery is queried, then all 4 staging tables and 4 curated view placeholders exist in the `roaming_intelligence` dataset with correct column schemas and `refresh_date` partitioning
- Given the reference table exists, when queried, then `ref_mcc_country` contains MCC-to-country mappings covering all ITU-allocated MCC codes
- Given IAM is configured, when the pipeline service account queries the dataset, then it has `dataEditor` on `roaming_intelligence` and read access to the source

## Spec Change Log


## Suggested Review Order

**Staging table schemas**

- Entry point: all 4 staging tables with partition config and column schemas derived from schema-mapping.md
  [`Pulumi.yaml:61`](../../stacks/roaming-intelligence/Pulumi.yaml#L61)

- Data quality log table — operational metadata schema for pipeline observability
  [`Pulumi.yaml:133`](../../stacks/roaming-intelligence/Pulumi.yaml#L133)

**Reference data**

- MCC-to-country reference table definition — unpartitioned, 3-column lookup
  [`Pulumi.yaml:157`](../../stacks/roaming-intelligence/Pulumi.yaml#L157)

- ITU MCC seed data — 236 entries covering all allocated country-level MCCs
  [`ref_mcc_country.csv:1`](../../stacks/roaming-intelligence/sql/seed/ref_mcc_country.csv#L1)

**Curated view placeholders**

- 4 placeholder views returning `SELECT 1 AS placeholder` — real queries added in Epic 2
  [`Pulumi.yaml:175`](../../stacks/roaming-intelligence/Pulumi.yaml#L175)

**IAM**

- Dataset-scoped dataEditor binding — verified scoping comment, dataViewer on source deferred to Story 1.3
  [`Pulumi.yaml:286`](../../stacks/roaming-intelligence/Pulumi.yaml#L286)

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Change Log
- 2026-05-22: Story implemented — 4 staging tables, 1 reference table, 4 curated view placeholders, IAM comment, and MCC seed CSV. Review: 0 patches, 4 deferrals (seed loading mechanism, maritime MCCs, partition expiration, source dataViewer IAM), 14 rejected.

### Review Findings

**Deferred:**
- [ ] Seed data loading mechanism — Pulumi creates table but doesn't populate; need bq load or DML (Epic 4)
- [ ] Maritime MCCs 901-999 — satellite/international allocations without ISO country codes
- [ ] Partition expiration policy — cost control TTL for staging tables
- [ ] dataViewer IAM on source dataset — blocked by Story 1.3 rework

**Rejected (14):** Duplicate MCCs (intentional per ITU), missing PK (BQ limitation), schema name mismatch (by design), country code ambiguity (consistent ISO), NOT NULL constraints (staging design), log partition (consistent), view placeholder docs (per spec), timezone handling (N/A), FLOAT/FLOAT64 alias (valid BQ), composite in kpi_daily (separate table), INTEGER/INT64 alias (valid BQ), MNC in ref table (MCC sufficient), curated schemas (Epic 2), extra country_name (beneficial consistency).
