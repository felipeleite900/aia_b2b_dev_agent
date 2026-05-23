# Deferred Work

## Deferred from: code review of 1-1-set-up-bi-layer-project-structure (2026-05-22)

- BQ `jobs.query` synchronous with no polling — long-running procs may return `jobComplete: false`. Refined in Story 4.1.
- Step 6 Cloud Run Job result never inspected — pipeline succeeds even if report fails. Story 4.1.
- `BigQueryClient._query_view` no error handling around query/to_dataframe. Expanded in Epic 3.
- `gcs_upload.py` has zero test coverage. Expanded later.
- `figure_to_html` CDN dependency — offline/egress-restricted reports won't render charts. Charts not implemented yet.
- `gchat_secret_id` defined in IaC but never wired into workflow or app. Story 4.2.
- `pipeline_sa_bq_editor` grants `dataEditor` to orchestrator SA — overly broad. Refined in Story 1.4.
- `sql/backfill/sp_backfill_historical.sql` technically out of Story 1.1 scope. Reasonable structural placeholder.
- Layer/object prefix compliance cannot be verified — SQL stubs lack DDL bodies. Epic 2.
- BQ query has no timeout configuration. Expanded later.

## Deferred from: code review of 1-2-validate-netscout-bigquery-schema (2026-05-22)

- `stacks/roaming-intelligence/sql/validation/` directory not documented in architecture.md project structure. Update architecture.md when finalizing project layout.
- Validation SQL placeholder syntax uses `<SOURCE_TABLE>` angle brackets which produce confusing BQ parse errors. Consider `@variable` DECLARE blocks or `REPLACE_ME_` prefix convention for future validation scripts.

## Deferred from: code review of 1-4-create-bigquery-dataset-and-core-table-definitions (2026-05-22)

- `ref_mcc_country.csv` seed data has no automated loading mechanism — Pulumi creates the table but doesn't populate it. Need a `bq load` step or DML seed script. Address when wiring pipeline (Epic 4).
- Maritime/satellite MCCs 901-999 missing from `ref_mcc_country.csv`. These are international/satellite allocations without ISO country codes. Add if roaming data includes satellite sessions.
- No partition expiration policy on staging tables. Consider adding `expirationMs` or TTL for cost control in a future operational story.
- `dataViewer` IAM on source dataset not implemented — depends on Story 1.3 rework to determine workbench access pattern. Add IAM binding once 1.3 resolves access model.

## Deferred: Story 1-3 — Request Datahub Access for Source Data (2026-05-22)

- **Status:** Deferred — original premise invalidated by Story 1.2 findings.
- **Reason:** OQ-1 resolved: source is workbench table `wb-tps-ia1-workbench-pr-641ea1.user_plane_staging.stg_user_plane`, not `ent_*` Datahub. The Datahub access JSON config / PR flow does not apply.
- **Resolution:** Workbench cross-project access is already granted — bi-layer SA can query the source dataset. No action needed.
- **If revisited:** Should future data sources require `ent_*` Datahub tables, create a new story following the Datahub access pattern in `ssot/infrastructure/bigquery-enterprise-datahub.md`.

## Deferred from: code review of 2-1-build-kpi-refresh-stored-procedure (2026-05-22)

- `roaming_type` column filter absent — values unknown, needs data investigation. If domestic sessions exist in source, KPIs will be contaminated. Run `SELECT DISTINCT roaming_type FROM stg_user_plane LIMIT 20` to confirm whether filtering is needed.
- Malformed `mcc_mnc` values (shorter than 4 chars, empty strings) silently produce garbage MCC/MNC. Low risk if source data is clean, but no defensive validation exists in the parsed_source CTE.
- `ref_mcc_country` table has no uniqueness constraint on `mcc` — future duplicate entries would fan out JOIN rows. Current CSV seed data is clean.
- `session_count` column name is misleading — it's `SUM(usr_pln_rqst_cnt)` (total requests), not a count of sessions. Schema mapping doc calls it "Total requests as session proxy."
- `AVG(latency)` excludes NULLs silently — if most sessions lack RTT measurements, the latency KPI represents only a subset. No coverage metric exists to surface this.

## Deferred from: code review of cloud-run-job-provision (2026-05-23)

- Workflow step6 uses v1 Cloud Run API path to trigger a v2 Job — may need migration to v2 endpoint or `googleapis.run.v2` connector. Verify v1 compatibility in both bi-stg and bi-srv.
- Workflow step6 fires-and-forgets: `http.post` to `:run` returns 200 on acceptance, not completion. Add polling loop (like `run_bq_proc`) to wait for execution terminal state.
- `report_gcs_path` date arithmetic broken: `text.right_pad` pads right (not left), and `sys.now().day - 1` yields 0 on 1st of month. Replace with proper date formatting.
- No `REFRESH_DATE` env var passed to Cloud Run Job — relies on Python default (yesterday). For backfill/late runs, pass explicit date from workflow via HTTP body override.
- No explicit resource limits or timeout on Cloud Run Job container. Set `memory`, `cpu`, and `timeout` once report size/complexity is known.
- Verify workflow execution SA is `{{ builder }}` — if workflow runs under a different SA, the `roles/run.invoker` IAM binding targets the wrong principal.
