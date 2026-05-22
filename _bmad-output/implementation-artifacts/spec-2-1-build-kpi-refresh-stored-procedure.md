---
title: 'Build KPI Refresh Stored Procedure'
type: 'feature'
created: '2026-05-22'
status: 'done'
baseline_commit: 'NO_VCS'
context:
  - 'docs/schema-mapping.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** No pipeline logic transforms raw session-level Netscout probe data into aggregated carrier KPIs. The `sp_refresh_carrier_kpis.sql` stub is empty. All downstream Epic 2 stories (composite scoring, degradation detection, curated output) are blocked until `stg_carrier_kpi_daily` is populated.

**Approach:** Implement `sp_refresh_carrier_kpis` as a BigQuery stored procedure that reads from the workbench source table, joins `ref_mcc_country` for country derivation, aggregates session-level rows to country/carrier/day grain, computes 4 raw KPIs + normalized 0-100 values + usage metrics, and writes to `stg_carrier_kpi_daily` using DELETE+INSERT idempotency. Logs execution to `stg_data_quality_log`.

## Boundaries & Constraints

**Always:**
- DELETE+INSERT on `refresh_date` partition — never MERGE.
- Aggregate `subscr_id` via COUNT(DISTINCT) only — never store raw (PII).
- Join `ref_mcc_country` on extracted MCC for country derivation.
- Log to `stg_data_quality_log` with step name, start/end timestamps, row count, status.
- Handle both `mcc_mnc` formats (hyphen-separated `"310-260"` and concatenated `"310260"`) — detect dynamically.
- Invert normalization for latency and packet loss (lower raw = higher normalized score).

**Ask First:**
- If `roaming_type` column values suggest non-international sessions exist, HALT — filtering may be needed.
- If `ref_mcc_country` table is empty or not loaded, HALT — country derivation will fail.

**Never:**
- Store raw `subscr_id` in any output table.
- Use MERGE for writes.
- Hardcode source project/dataset — use fully qualified table reference.
- Skip the observability log insert, even on zero-row results.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Happy path | Source has rows for refresh_date | Aggregated rows in stg_carrier_kpi_daily, log entry with row count | N/A |
| No source data | Zero rows match refresh_date filter | Zero rows inserted, log entry with row_count=0 and status='success' | N/A |
| MCC not in ref table | mcc_mnc yields MCC absent from ref_mcc_country | Row kept; country_name and country_code = NULL | Do not drop unmatched rows |
| All KPI columns NULL | Every session in a group has NULL KPI source columns | kpi_* = NULL, norm_* = NULL | Keep the row with usage metrics intact |
| Re-run same date | Proc called twice for same refresh_date | Second run deletes first result and re-inserts — identical output | Idempotent by design |

</frozen-after-approval>

## Code Map

- `stacks/roaming-intelligence/sql/sp_refresh_carrier_kpis.sql` — MODIFY: implement full stored procedure (currently stub)
- `stacks/roaming-intelligence/Pulumi.yaml:61-90` — REFERENCE: target table schema (stg_carrier_kpi_daily)
- `stacks/roaming-intelligence/Pulumi.yaml:133-151` — REFERENCE: log table schema (stg_data_quality_log)
- `stacks/roaming-intelligence/sql/seed/ref_mcc_country.csv` — REFERENCE: MCC-to-country lookup data
- `docs/schema-mapping.md` — REFERENCE: column transforms and KPI derivation formulas

## Tasks & Acceptance

**Execution:**
- [x] `stacks/roaming-intelligence/sql/sp_refresh_carrier_kpis.sql` — Implement CREATE OR REPLACE PROCEDURE with: (1) observability log start entry, (2) DELETE target partition, (3) INSERT aggregated KPIs from source joined to ref_mcc_country with mcc_mnc dynamic parsing, (4) compute norm_* via min-max normalization over available history (handle cold-start), (5) observability log end entry with row count

**Acceptance Criteria:**
- Given a refresh_date with source data, when the proc executes, then stg_carrier_kpi_daily contains one row per unique (country_code, carrier_name) with all 4 raw KPIs, 4 normalized KPIs, and 3 usage metrics populated
- Given the proc completes (success or zero rows), when stg_data_quality_log is queried, then an entry exists with step_name='sp_refresh_carrier_kpis', timestamps, row_count, and status
- Given the proc runs twice for the same date, when results are compared, then output is identical (idempotent)

## Design Notes

**Normalization approach:** Use min-max normalization over available historical data in `stg_carrier_kpi_daily` (up to 90-day trailing window). On cold-start (no history), use the current batch's range. For inverted KPIs (latency, packet loss): `norm = (1 - (val - min) / NULLIF(max - min, 0)) * 100`. When min = max, set norm to 50 (midpoint).

**MCC parsing:** Use `CASE WHEN CONTAINS_SUBSTR(mcc_mnc, '-') THEN SPLIT(...)[OFFSET(0)] ELSE SUBSTR(mcc_mnc, 1, 3) END`. Three-digit MCC is the ITU standard.

**is_steered:** Default FALSE for all rows. Manual tagging mechanism deferred to a future story.

## Verification

**Manual checks (if no CLI):**
- `sp_refresh_carrier_kpis.sql` is valid BigQuery SQL (no syntax errors)
- Procedure signature: `CREATE OR REPLACE PROCEDURE roaming_intelligence.sp_refresh_carrier_kpis(IN target_date DATE)`
- All 17 columns from stg_carrier_kpi_daily schema are populated in the INSERT
- DELETE+INSERT pattern used (no MERGE)
- `subscr_id` appears only inside COUNT(DISTINCT), never in output columns
- Log INSERT to stg_data_quality_log present at procedure start and end

## Suggested Review Order

**Input validation & guards**

- NULL input and empty ref table halt early with logged failure
  [`sp_refresh_carrier_kpis.sql:18`](../../stacks/roaming-intelligence/sql/sp_refresh_carrier_kpis.sql#L18)

**Core aggregation (entry point — start here)**

- Session-level → country/carrier/day grain with MCC dynamic parsing and LEFT JOIN
  [`sp_refresh_carrier_kpis.sql:60`](../../stacks/roaming-intelligence/sql/sp_refresh_carrier_kpis.sql#L60)

- 4 raw KPIs derived via AVG/SAFE_DIVIDE aggregation
  [`sp_refresh_carrier_kpis.sql:96`](../../stacks/roaming-intelligence/sql/sp_refresh_carrier_kpis.sql#L96)

- Usage metrics: traffic volume (COALESCE for partial NULL), session count, subscriber count
  [`sp_refresh_carrier_kpis.sql:114`](../../stacks/roaming-intelligence/sql/sp_refresh_carrier_kpis.sql#L114)

**Normalization**

- Min-max over 90-day trailing window, inverted for latency/packet loss, clamped [0,100]
  [`sp_refresh_carrier_kpis.sql:127`](../../stacks/roaming-intelligence/sql/sp_refresh_carrier_kpis.sql#L127)

**Observability & error handling**

- EXCEPTION block guarantees a completion log entry on failure
  [`sp_refresh_carrier_kpis.sql:172`](../../stacks/roaming-intelligence/sql/sp_refresh_carrier_kpis.sql#L172)

## Spec Change Log
