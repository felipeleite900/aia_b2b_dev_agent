---
title: 'Build Curated Output Layer'
type: 'feature'
created: '2026-05-22'
status: 'done'
route: 'one-shot'
baseline_commit: '5077841'
---

## Intent

**Problem:** The report generator (Epic 3) has no data contract to consume. The 4 `crt_mv_*` views in Pulumi are placeholder `SELECT 1` queries.

**Approach:** Implement `sp_curate_output` to CREATE OR REPLACE 4 views that join all staging tables into the report contract: carrier quality summary, country quality summary, 90-day carrier trend, and carrier usage summary. Views are self-contained query definitions (MAX(refresh_date) for snapshots, CURRENT_DATE() - 90 days for trend). Carriers with <1% traffic share flagged via `is_minor_carrier`.

## Suggested Review Order

**Carrier quality summary (entry point — richest view, all 3 staging joins)**

- Latest snapshot: KPIs + composite + degradation + traffic share + minor carrier flag
  [`sp_curate_output.sql:42`](../../stacks/roaming-intelligence/sql/sp_curate_output.sql#L42)

**Country quality summary**

- Country-level aggregation with AVG composite, degraded carrier count
  [`sp_curate_output.sql:82`](../../stacks/roaming-intelligence/sql/sp_curate_output.sql#L82)

**Carrier quality trend**

- 90-day rolling window for trend charts, joins composite + degradation
  [`sp_curate_output.sql:120`](../../stacks/roaming-intelligence/sql/sp_curate_output.sql#L120)

**Carrier usage summary**

- Usage metrics with traffic share, reuses latest + total_traffic CTE pattern
  [`sp_curate_output.sql:148`](../../stacks/roaming-intelligence/sql/sp_curate_output.sql#L148)
