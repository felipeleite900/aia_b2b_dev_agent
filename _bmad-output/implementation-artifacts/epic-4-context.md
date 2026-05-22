# Epic 4 Context: Pipeline Orchestration & Operational Readiness

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Wire the already-built stored procedures (Epic 2) and report generator container (Epic 3) into an end-to-end automated pipeline by completing the Cloud Workflows step chain, configuring Cloud Scheduler for weekday runs, adding gchat success/failure notifications, running the 90-day historical backfill in bi-stg, validating the full pipeline, and promoting to production in bi-srv. After this epic, the steering team receives daily automated reports without manual intervention.

## Stories

- Story 4.1: Wire Cloud Workflows Step Chain
- Story 4.2: Configure Cloud Scheduler and gchat Notifications
- Story 4.3: Run Historical Backfill and Validate End-to-End in bi-stg
- Story 4.4: Promote to Production (bi-srv)

## Requirements & Constraints

**Functional requirements completed by this epic:**
- FR-1 (scheduling): Daily automated refresh of all Quality KPIs. Curated tables updated by 08:00 ET daily.
- FR-3 (end-to-end observability): Structured logs per run -- start time, end time, rows processed, countries/carriers covered, success/failure status. Leverages `stg_data_quality_log` written by each stored proc.

**Non-functional requirements:**
- NFR-1: Pipeline completes daily refresh within 2 hours of data availability.
- NFR-2: Pipeline failures do not corrupt existing data; last successful refresh and report remain available. Retry logic on transient BigQuery failures.
- Canadian data residency: All resources in `northamerica-northeast1`.

**Schedule:** `0 6 * * 1-5` (weekdays 06:00 ET), `time_zone: America/Toronto`. Both bi-stg and bi-srv active (`pause_status: false`).

**Environment-specific config (from `environment.j2`):**
- GCS buckets: `roaming-intelligence-reports-stg` / `roaming-intelligence-reports-srv`
- gchat secrets: `ROAMING_INTELLIGENCE_GCHAT_STG` / `ROAMING_INTELLIGENCE_GCHAT_SRV`
- Service account: `bilayer-sa@{PROJECT_ID}.iam.gserviceaccount.com`

## Technical Decisions

**Workflow step chain (6 sequential steps):**
Steps 1-5 call BigQuery stored procs via `googleapis.bigquery.v2.jobs.query`. Step 6 triggers the Cloud Run Job via `http.post` with OAuth2 auth. The chain is already scaffolded in `Pulumi.yaml` -- this epic completes the wiring.

| Step | Stored Proc / Action | Target |
|---|---|---|
| step1_refresh_data | `sp_refresh_carrier_kpis` | `stg_carrier_kpi_daily` |
| step2_compute_kpis | `sp_compute_composite_scores` | `stg_carrier_composite_daily` |
| step3_detect_degradation | `sp_detect_degradation` | `stg_carrier_degradation_daily` |
| step4_quality_checks | `sp_run_quality_checks` | `stg_data_quality_log` |
| step5_curate | `sp_curate_output` | `crt_mv_*` views |
| step6_generate_report | Cloud Run Job (Python) | GCS HTML report |

**Known deferred items to resolve in this epic:**
- BQ `jobs.query` synchronous call with no polling -- long-running procs may return `jobComplete: false`. Story 4.1 must add async polling or use the `jobs.insert` + `jobs.get` pattern.
- Step 6 Cloud Run Job result is never inspected -- pipeline currently succeeds even if report generation fails. Story 4.1 must add result checking.
- `gchat_secret_id` is defined in IaC but not wired into the workflow. Story 4.2 wires it.
- `ref_mcc_country.csv` seed data has no automated loading mechanism. Address during Story 4.3 validation.

**Runtime expression escaping:** Use `$${...}` for Workflows runtime expressions inside `sourceContents` (Pulumi YAML requires double-dollar escaping).

**Error handling:** Fail-fast -- any step failure stops the chain and fires a gchat notification via `aia_gchat_workflow` with the failed step name and error context. Success notification includes the GCS report link.

**Scheduler authentication:** `oauthToken` against the Workflow Executions API, using the bi-layer service account.

## Cross-Story Dependencies

- **Epic 2 -> Story 4.1:** All five stored procedures must be deployed and individually tested before wiring the step chain.
- **Epic 3 -> Story 4.1:** The report generator container must be buildable and runnable as a Cloud Run Job before step 6 can be wired.
- **Story 4.1 -> Story 4.2:** The workflow must exist before the scheduler and notifications can target it.
- **Story 4.2 -> Story 4.3:** Scheduler and notifications must be configured before end-to-end validation.
- **Story 4.3 -> Story 4.4:** Full validation in bi-stg (including backfill, manual pipeline run, report inspection, and notification testing) must pass before promoting to bi-srv.
- **Story 4.4:** Stage 2 PR (fork/main -> upstream/main) triggers `pulumi up bi-srv`. Steering team needs `roles/storage.objectViewer` on the production GCS bucket.
