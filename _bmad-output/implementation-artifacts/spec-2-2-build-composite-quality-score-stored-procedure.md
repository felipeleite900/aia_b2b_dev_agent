---
title: 'Build Composite Quality Score Stored Procedure'
type: 'feature'
created: '2026-05-22'
status: 'done'
route: 'one-shot'
baseline_commit: '4e96597'
---

## Intent

**Problem:** No composite quality score exists for carrier comparison. Downstream reporting (Epic 3) needs a single 0-100 score per carrier/country/day that summarizes all four normalized KPIs.

**Approach:** Implement `sp_compute_composite_scores` as a BigQuery stored procedure that reads normalized KPIs from `stg_carrier_kpi_daily`, computes an equal-weight average of available (non-NULL) values, and writes to `stg_carrier_composite_daily` using DELETE+INSERT idempotency with observability logging and EXCEPTION handling.

## Suggested Review Order

- Entry point: composite score formula using SAFE_DIVIDE with COALESCE/IF for partial-NULL handling
  [`sp_compute_composite_scores.sql:55`](../../stacks/roaming-intelligence/sql/sp_compute_composite_scores.sql#L55)

- Procedure skeleton: input validation, logging, EXCEPTION block (same pattern as 2.1)
  [`sp_compute_composite_scores.sql:10`](../../stacks/roaming-intelligence/sql/sp_compute_composite_scores.sql#L10)
