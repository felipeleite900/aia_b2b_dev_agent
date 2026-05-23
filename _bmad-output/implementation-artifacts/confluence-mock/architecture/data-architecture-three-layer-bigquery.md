---
title: "Data Architecture: Three-Layer BigQuery Pipeline"
type: architecture-decision
source_artifact: "architecture.md"
created: "2026-05-22"
updated: "2026-05-22"
---

# Data Architecture: Three-Layer BigQuery Pipeline

**Data Model: Three-Layer BigQuery Pipeline**
- **Layer 1 — Raw source**: Netscout probe data in BigQuery workbench (`wb-tps-ia1-workbench-pr-641ea1.user_plane_staging.stg_user_plane`). Read-only, owned by upstream.
- **Layer 2 — Work/staging tables**: Intermediate results from each pipeline step (normalized KPIs, per-carrier-per-country aggregations). Written by stored procs during pipeline execution. Prefixed `stg_`.
- **Layer 3 — Curated output**: Final views consumed by the report generator. Includes composite quality scores, degradation flags, data quality indicators, usage analytics. Prefixed `crt_mv_`. This is the contract between the pipeline and the report.

**Partitioning Strategy:** Daily date-partitioned by `refresh_date`. Each pipeline run writes to a single partition. Rerunning the same day overwrites the partition — idempotency by design (FR-1). Backfill overwrites specific date partitions without affecting other dates.

**Composite Quality Score:** Computed in a BigQuery stored procedure. Equal-weight average of normalized KPIs (each KPI scaled 0-100). Stored as a column (`composite_quality_score`) in the curated carrier-level table.

**Historical Retention:** 90 days in curated tables. Aligns with the maximum trend window (FR-11).

**Dataset:** `roaming_intelligence`

**Staging Tables:** `stg_carrier_kpi_daily`, `stg_carrier_composite_daily`, `stg_carrier_degradation_daily`, `stg_data_quality_log`

**Curated Views:** `crt_mv_carrier_quality_summary`, `crt_mv_country_quality_summary`, `crt_mv_carrier_quality_trend`, `crt_mv_carrier_usage_summary`
