---
title: 'Build Data Quality Checks Stored Procedure'
type: 'feature'
created: '2026-05-22'
status: 'done'
route: 'one-shot'
baseline_commit: '62ee9c6'
---

## Intent

**Problem:** No automated quality gate validates the daily pipeline output. Without freshness, coverage, and volume checks, silent data issues propagate to reporting uncaught.

**Approach:** Implement `sp_run_quality_checks` with 3 checks logged to `stg_data_quality_log`: (1) freshness within 36h, (2) carrier coverage vs prior refresh (>20% drop = fail), (3) volume anomaly vs 14-day rolling average (<50% = fail). Summary row reports overall pass/fail count.

## Suggested Review Order

- Idempotent DELETE scoped to qc_* entries only — preserves other procs' logs
  [`sp_run_quality_checks.sql:48`](../../stacks/roaming-intelligence/sql/sp_run_quality_checks.sql#L48)

- Freshness check: TIMESTAMP_DIFF against 36h threshold
  [`sp_run_quality_checks.sql:54`](../../stacks/roaming-intelligence/sql/sp_run_quality_checks.sql#L54)

- Coverage check: current vs prior date row count with 20% tolerance
  [`sp_run_quality_checks.sql:73`](../../stacks/roaming-intelligence/sql/sp_run_quality_checks.sql#L73)

- Volume anomaly: daily sum vs AVG of per-day sums over prior 14 days, 50% threshold
  [`sp_run_quality_checks.sql:114`](../../stacks/roaming-intelligence/sql/sp_run_quality_checks.sql#L114)

- Summary log: pass/fail tally, status = 'warning' if any check failed
  [`sp_run_quality_checks.sql:150`](../../stacks/roaming-intelligence/sql/sp_run_quality_checks.sql#L150)
