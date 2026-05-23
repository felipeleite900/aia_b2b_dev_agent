---
title: "Pipeline Architecture: Monolithic Cloud Workflows Stack"
type: architecture-decision
source_artifact: "architecture.md"
created: "2026-05-22"
updated: "2026-05-22"
---

# Pipeline Architecture: Monolithic Cloud Workflows Stack

**Composition Pattern:** Single `Pulumi.yaml` with inline `sourceContents` defining the Cloud Workflows step chain. Appropriate for 1 workflow with 5-6 sequential steps.

**Pipeline Step Chain:**
1. `step1_refresh_data` — Incremental load: BQ stored proc reads new/changed raw data, writes to staging tables
2. `step2_compute_kpis` — Composite quality score from normalized KPIs
3. `step3_detect_degradation` — Direction-aware threshold checks per KPI over 7-day trailing window
4. `step4_quality_checks` — Freshness validation, coverage diff, volume anomaly detection
5. `step5_curate` — Write curated views from staging tables
6. `step6_generate_report` — Trigger Cloud Run Job: Python container queries curated views, generates HTML, writes to GCS

**Report Generation Step:** Cloud Run Job triggered as the final Cloud Workflows step. Clean separation: SQL handles all data transformation (steps 1-5), Python handles presentation (step 6).

**Error Handling:** Fail-fast. If any step fails, the workflow stops and sends a Google Chat alert via `aia_gchat_workflow`. Last successful curated data and report remain available.

**Schedule:** `0 6 * * 1-5` — weekdays at 06:00 ET. Active in both `bi-stg` and `bi-srv`.

**Async BQ Polling:** Steps 1-5 use `jobs.insert` + poll sub-workflow (`run_bq_proc`) to handle long-running stored procedures. Each job is polled every 10 seconds until completion.
