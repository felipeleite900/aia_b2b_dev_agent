---
title: 'Build Degradation Detection Stored Procedure'
type: 'feature'
created: '2026-05-22'
status: 'done'
route: 'one-shot'
baseline_commit: 'd40b7f5'
---

## Intent

**Problem:** No mechanism detects when carrier KPIs worsen significantly compared to recent history. Without degradation flags, the reporting layer (Epic 3) cannot highlight carriers requiring steering attention.

**Approach:** Implement `sp_detect_degradation` as a BigQuery stored procedure that compares each carrier's current-day raw KPIs against a 7-day trailing average using direction-aware 20% thresholds. Outputs `degradation_flag` (BOOL) and `degradation_details` (JSON with per-KPI breakdown) to `stg_carrier_degradation_daily`.

## Suggested Review Order

**Core detection logic**

- 7-day trailing average CTE, direction-aware threshold comparisons (higher_is_worse / lower_is_worse)
  [`sp_detect_degradation.sql:60`](../../stacks/roaming-intelligence/sql/sp_detect_degradation.sql#L60)

- LEFT JOIN with IS NOT DISTINCT FROM for NULL-safe carrier matching
  [`sp_detect_degradation.sql:89`](../../stacks/roaming-intelligence/sql/sp_detect_degradation.sql#L89)

**Output**

- degradation_flag: TRUE if any KPI breaches AND trailing data exists
  [`sp_detect_degradation.sql:100`](../../stacks/roaming-intelligence/sql/sp_detect_degradation.sql#L100)

- JSON details with per-KPI current/avg/degraded/direction + trailing_days for consumer disambiguation
  [`sp_detect_degradation.sql:104`](../../stacks/roaming-intelligence/sql/sp_detect_degradation.sql#L104)
