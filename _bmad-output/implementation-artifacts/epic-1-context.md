# Epic 1 Context: Project Foundation & Data Infrastructure

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Establish the bi-layer project structure, validate the Netscout BigQuery data source, secure Datahub access, and provision all BigQuery datasets and table schemas so that pipeline development (Epic 2) can begin on a solid, correctly-configured foundation. Nothing in this epic transforms data; it ensures every prerequisite for data transformation is in place.

## Stories

- Story 1.1: Set Up Bi-Layer Project Structure
- Story 1.2: Validate Netscout BigQuery Schema
- Story 1.3: Request Datahub Access for Source Data
- Story 1.4: Create BigQuery Dataset and Core Table Definitions

## Requirements & Constraints

- All GCP resources must reside in `northamerica-northeast1` or `northamerica-northeast2` (Canadian data sovereignty).
- No PII enters the pipeline. Data is aggregated network performance metrics classified as Internal.
- Pipeline must be idempotent: all writes use DELETE + INSERT on the target `refresh_date` partition, never MERGE.
- Both `bi-stg` and `bi-srv` environments must be supported. Jinja `PROJECT_TYPE` switches env-specific config (bucket names, schedule, pause status) in `environment.j2`.
- Datahub access PR to `telus/tf-infra-cio-datahub-bilayer` must be merged and Terraform-applied before any pipeline stored proc can query `ent_*` source tables.
- Schema validation (OQ-1) is the highest-priority open question -- it unblocks all downstream pipeline work. The four assumed KPIs (latency, throughput, packet loss, session success rate) and the data grain (country/carrier/day) must be confirmed against the actual Netscout schema.

## Technical Decisions

**Project layout** follows the bi-layer monorepo pattern: `stacks/roaming-intelligence/` for Pulumi IaC and SQL source files; `images/roaming-intelligence/` for the Python report-generator container, templates, and tests.

**Starter templates**: fork `common_patterns/scheduled_bq_multi_step_stored_proc` and `big_query/*` from the bi-layer stacks catalog into the team's fork.

**BigQuery three-layer model**: raw (`ent_*` upstream, read-only) -> stg (staging work tables) -> crt (curated materialized views). Strict layer discipline enforced; no layer may be bypassed.

**Dataset**: `roaming_intelligence`.

**Staging tables** to provision: `stg_carrier_kpi_daily`, `stg_carrier_composite_daily`, `stg_carrier_degradation_daily`, `stg_data_quality_log`. **Curated MV placeholders**: `crt_mv_carrier_quality_summary`, `crt_mv_country_quality_summary`, `crt_mv_carrier_quality_trend`, `crt_mv_carrier_usage_summary`.

**Partitioning**: all tables daily date-partitioned by `refresh_date`.

**Naming conventions**: layer prefixes (`stg_`, `crt_`), object type prefixes (`sp_`, `vw_`, `mv_`), `snake_case` columns with `kpi_`/`norm_` domain prefixes.

**IAM**: pipeline service account gets `roles/bigquery.dataEditor` on project-owned datasets and `roles/bigquery.dataViewer` on source datasets. Datahub access JSON lists both `bi-stg` and `bi-srv` service accounts.

## Cross-Story Dependencies

- Story 1.2 (schema validation) should complete before Story 1.4 (table definitions) to confirm column mappings against the actual source.
- Story 1.3 (Datahub access) depends on Story 1.2 to identify the required `ent_*` dataset names.
- Story 1.4 depends on Story 1.1 (project structure) for the Pulumi stack to exist.
- All of Epic 2 (pipeline stored procs) is blocked until Stories 1.3 and 1.4 are complete.
- Epic 3 (report generator) depends on the `images/roaming-intelligence/` directory scaffolded in Story 1.1.
