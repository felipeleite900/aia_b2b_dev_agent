---
title: 'Validate Netscout BigQuery Schema'
type: 'chore'
created: '2026-05-22'
status: 'done'
# OQ-1 resolved 2026-05-22: source is workbench table stg_user_plane, session-level grain, all 4 KPIs derivable
baseline_commit: 'NO_VCS'
context:
  - '_bmad-output/planning-artifacts/architecture.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The entire pipeline (Epics 2–4) assumes four KPIs (latency, throughput, packet loss, session success rate) exist in Netscout probe data at country/carrier/day grain, but no one has confirmed the actual BigQuery schema. OQ-1 is the single highest-priority blocker.

**Approach:** Create discovery SQL queries to explore the Netscout source tables, run them against BigQuery, and produce a schema mapping document that maps every source column to a target column. Flag gaps and provide mitigations.

## Boundaries & Constraints

**Always:**
- Map source columns to target names using the established naming conventions (`kpi_*`, `norm_*`, `snake_case`).
- Document findings in `docs/schema-mapping.md` — this is the project's authoritative source-to-target reference.
- Confirm data grain (country/carrier/day) and historical depth (need 90 days for backfill).
- Identify whether `is_steered` comes from the source data or requires a separate lookup/manual tagging.

**Ask First:**
- If any of the 4 assumed KPIs are missing, HALT and present mitigation options before proceeding.
- If the source data is not via `ent_*` Datahub tables (different access pattern), HALT and discuss.
- If data grain is finer or coarser than country/carrier/day, HALT — this changes the pipeline design.

**Never:**
- Do not modify stored procedure SQL stubs — that's Epic 2.
- Do not create or provision BigQuery resources — that's Story 1.4.
- Do not submit the Datahub access PR — that's Story 1.3.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| All 4 KPIs present | Source has latency, throughput, packet_loss, session_success columns | Schema mapping doc with direct 1:1 mappings | N/A |
| KPI missing | Source lacks one or more of the 4 assumed KPIs | Flag in mapping doc with mitigation options (derive, proxy, or drop) | HALT for human decision |
| Finer grain than expected | Source is at session level, not daily aggregate | Note in mapping; aggregation logic needed in sp_refresh | HALT — pipeline design impact |
| No `is_steered` in source | Field not present in Netscout data | Document absence; propose manual tagging or steering-rule join | HALT for human decision |
| Insufficient history | Less than 90 days available | Document available range; adjust backfill scope | Note in mapping doc |

</frozen-after-approval>

## Code Map

- `docs/schema-mapping.md` — NEW: authoritative source-to-target column mapping document
- `stacks/roaming-intelligence/sql/validation/` — NEW: discovery queries for schema exploration
- `stacks/roaming-intelligence/sql/validation/explore_source_schema.sql` — NEW: INFORMATION_SCHEMA query + sample data query
- `stacks/roaming-intelligence/sql/validation/validate_grain_and_coverage.sql` — NEW: grain check, date range, country/carrier counts
- `images/roaming-intelligence/src/bq_client.py` — REFERENCE: defines target view column names (read-only)

## Tasks & Acceptance

**Execution:**
- [x] `stacks/roaming-intelligence/sql/validation/explore_source_schema.sql` — Create discovery queries: INFORMATION_SCHEMA lookup for source table(s), sample rows, distinct value counts for key dimensions
- [x] `stacks/roaming-intelligence/sql/validation/validate_grain_and_coverage.sql` — Create validation queries: grain confirmation (GROUP BY country/carrier/date), date range check, NULL/completeness analysis per column
- [x] `docs/schema-mapping.md` — Create schema mapping document with: source table location, column-by-column mapping (source name → target name → type → notes), data grain confirmation, `is_steered` source, KPI availability assessment, historical depth, and OQ-1 resolution summary

**Acceptance Criteria:**
- Given the validation queries are run against BigQuery, when the schema mapping document is complete, then every target column in `stg_carrier_kpi_daily` has a confirmed source or a documented gap with mitigation
- Given the mapping document exists, when OQ-1 is reviewed, then the data grain, KPI availability, and `is_steered` source are all resolved with findings

## Design Notes

This is a **human-in-the-loop discovery task**. The developer must run the validation queries against BigQuery (via BQ console, `bq` CLI, or workbench). The queries are the scaffolding; the mapping document is the deliverable.

The schema mapping document becomes the source of truth for Story 2.1 (`sp_refresh_carrier_kpis`) — it defines the exact SELECT/column mapping the stored proc will use.

## Verification

**Manual checks (if no CLI):**
- `docs/schema-mapping.md` exists with all sections populated (no TBDs)
- Every target column in architecture.md's column naming standard has a mapping entry
- OQ-1 status is documented as resolved

## Suggested Review Order

**Schema discovery queries**

- Entry point: INFORMATION_SCHEMA column discovery + KPI keyword scan with categorized CASE
  [`explore_source_schema.sql:22`](../../stacks/roaming-intelligence/sql/validation/explore_source_schema.sql#L22)

- Sample data with partition filter tip and deterministic ORDER BY
  [`explore_source_schema.sql:51`](../../stacks/roaming-intelligence/sql/validation/explore_source_schema.sql#L51)

- Dimension cardinality with NULL-safe CONCAT for MCC/MNC pairs
  [`explore_source_schema.sql:72`](../../stacks/roaming-intelligence/sql/validation/explore_source_schema.sql#L72)

**Data validation queries**

- Grain confirmation: GROUP BY assumed dimensions, count duplicates
  [`validate_grain_and_coverage.sql:28`](../../stacks/roaming-intelligence/sql/validation/validate_grain_and_coverage.sql#L28)

- Date gap detection with GENERATE_DATE_ARRAY and IGNORE NULLS
  [`validate_grain_and_coverage.sql:70`](../../stacks/roaming-intelligence/sql/validation/validate_grain_and_coverage.sql#L70)

- NULL completeness with SAFE_DIVIDE guards
  [`validate_grain_and_coverage.sql:129`](../../stacks/roaming-intelligence/sql/validation/validate_grain_and_coverage.sql#L129)

- Historical depth: uses distinct_dates (not calendar span) for 90-day check
  [`validate_grain_and_coverage.sql:179`](../../stacks/roaming-intelligence/sql/validation/validate_grain_and_coverage.sql#L179)

**Schema mapping template**

- Column mapping table: 14 source-mapped targets + derived columns note
  [`schema-mapping.md:63`](../../docs/schema-mapping.md#L63)

- Sign-off checklist gates OQ-1 resolution
  [`schema-mapping.md:186`](../../docs/schema-mapping.md#L186)

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Change Log
- 2026-05-22: Story implemented — discovery SQL, validation SQL, and schema mapping template created. 12 review patches applied (SAFE_DIVIDE, IGNORE NULLS, steering keywords, derived-column docs, historical depth fix).

### Review Findings

**Patch (applied):**
- [x] Added CASE branches for TRAFFIC_VOLUME, COUNT_METRIC, STEERING categories in KPI scan
- [x] Added steering keywords (%steer%, %prefer%, %direct%) to Block 4 WHERE clause
- [x] Replaced division with SAFE_DIVIDE in all NULL completeness calculations
- [x] Added COALESCE wrappers for NULL mcc/mnc in CONCAT
- [x] Added IGNORE NULLS to ARRAY_AGG in date gap detection
- [x] Changed backfill check to use distinct_dates instead of calendar span
- [x] Added partition filter and ORDER BY tips to sample data query
- [x] Added TIMESTAMP/DATE cast warning to date range block
- [x] Added derived columns note (norm_*, composite, degradation) to schema-mapping.md
- [x] Clarified sign-off wording for 14 source-mapped + 7 derived columns
- [x] Disambiguated Block 3 file reference in schema-mapping.md

**Deferred:**
- [x] validation/ directory not in architecture.md project structure
- [x] Placeholder syntax uses angle brackets instead of @variable or REPLACE_ME_ convention
