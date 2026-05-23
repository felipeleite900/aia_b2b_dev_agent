---
title: "Set Up Bi-Layer Project Structure"
type: story
status: done
epic: "project-foundation-and-data-infrastructure"
product_type: data_pipeline
component_type: "infrastructure"
governance_gates: [dep, dntl, de_identification]
infrastructure_pattern: "bi-layer"
created: "2026-05-22"
updated: "2026-05-22"
---

# Story 1.1: Set Up Bi-Layer Project Structure

Status: done

## Story

As a data engineer,
I want the bi-layer monorepo structure forked from catalog templates with stacks/ and images/ pillars,
so that the team has a standard project foundation to build pipeline and report components on.

## Acceptance Criteria

1. **Given** the team's fork of the bi-layer monorepo exists, **When** the project structure is created, **Then** `stacks/roaming-intelligence/` contains a `Pulumi.yaml` forked from `scheduled_bq_multi_step_stored_proc` and an `environment.j2` with env-specific variables (bucket names, schedule, pause status)
2. **And** `images/roaming-intelligence/` contains a `Dockerfile`, `pyproject.toml`, `src/` directory structure, and `templates/` directory per the architecture spec
3. **And** `images/roaming-intelligence/sql/` directory exists for stored procedure source files
4. **And** all GCP resources are configured for `northamerica-northeast1`
5. **And** `environment.j2` includes Jinja `PROJECT_TYPE` switches for `bi-stg` and `bi-srv`

## Tasks / Subtasks

- [x] Task 1: Fork bi-layer stacks catalog template (AC: 1)
  - [x] 1.1 Create `stacks/roaming-intelligence/` directory
  - [x] 1.2 Fork `Pulumi.yaml` from `common_patterns/scheduled_bq_multi_step_stored_proc` template in `telus/bi-layer-docs`
  - [x] 1.3 Adapt the Pulumi.yaml variables block: set `process_nm: roaming_intelligence`, `location: northamerica-northeast1`, `schedule: 0 6 * * 1-5`, `time_zone: America/Toronto`
  - [x] 1.4 Add `pause_status` with Jinja switch: `false` for both `bi-stg` and `bi-srv` (architecture decision: both envs active)
  - [x] 1.5 Create `stacks/roaming-intelligence/sql/` directory with placeholder SQL files for all 5 stored procs + backfill

- [x] Task 2: Create `environment.j2` with env-specific variables (AC: 1, 5)
  - [x] 2.1 Define `PROJECT_TYPE` switches for `bi-stg` and `bi-srv`
  - [x] 2.2 Configure env-specific GCS bucket names (separate bucket per env for report output)
  - [x] 2.3 Configure env-specific schedule and pause_status variables
  - [x] 2.4 Configure env-specific service account, gchat secret, and image registry references

- [x] Task 3: Set up `images/roaming-intelligence/` directory structure (AC: 2, 3)
  - [x] 3.1 Create `images/roaming-intelligence/Dockerfile` — Python 3.12.4-slim base, layer-cached deps, src+templates copy
  - [x] 3.2 Create `images/roaming-intelligence/pyproject.toml` with deps: plotly, jinja2, google-cloud-bigquery, google-cloud-storage, structlog + dev deps
  - [x] 3.3 Create `images/roaming-intelligence/src/` directory with `__init__.py`
  - [x] 3.4 Create `images/roaming-intelligence/src/main.py` — entry point stub with structlog integration
  - [x] 3.5 Create `images/roaming-intelligence/src/config.py` — env config with dataclass, env var loading, defaults
  - [x] 3.6 Create `images/roaming-intelligence/src/bq_client.py` — BigQueryClient reading only crt_mv_* views
  - [x] 3.7 Create `images/roaming-intelligence/src/report/` — builder.py, charts.py, sections/ (6 section stubs)
  - [x] 3.8 Create `images/roaming-intelligence/src/gcs_upload.py` — GCS upload function
  - [x] 3.9 Create `images/roaming-intelligence/templates/` — base.html.j2 (TELUS-branded), section.html.j2
  - [x] 3.10 Create `images/roaming-intelligence/sql/` directory for stored procedure source files
  - [x] 3.11 Create `images/roaming-intelligence/tests/` — test_bq_client, test_builder, test_config, test_sections/, fixtures/sample_data

- [x] Task 4: Validate GCP region configuration (AC: 4)
  - [x] 4.1 Ensure `location: northamerica-northeast1` is set in Pulumi.yaml variables
  - [x] 4.2 Ensure all BQ dataset, Cloud Workflows, and Cloud Scheduler resources reference this location
  - [x] 4.3 Ensure Docker image registry references use `northamerica-northeast1-docker.pkg.dev`

## Dev Notes

### Critical Architecture Constraints

**Bi-layer monorepo pattern** — This project follows the two-pillar structure:
- `stacks/roaming-intelligence/` — Pulumi IaC (Cloud Workflows, Scheduler, BQ datasets/tables/views, IAM). This is the "what's around it" pillar.
- `images/roaming-intelligence/` — Application code (Python report generator container). This is the "what runs" pillar.
- **Never** put a `Dockerfile` in `stacks/` or a `Pulumi.yaml` in `images/`. (source: infrastructure/bi-layer-overview.md §2)

**Pulumi YAML + Jinja — NOT Pulumi-Python.** Bi-layer's CI is configured for YAML+Jinja only. Do not use Pulumi's Python SDK. (source: infrastructure/bi-layer-overview.md §7, engineering/pulumi-best-practices.md)

**Template forking, not hand-authoring.** Always start from `telus/bi-layer-docs` catalog templates. Hand-authored YAML drifts from platform-team conventions. The primary template for this project is `common_patterns/scheduled_bq_multi_step_stored_proc`. (source: infrastructure/bi-layer-overview.md §5)

**Region: `northamerica-northeast1` exclusively.** Canadian data sovereignty requirement. No US regions. (source: governance/canadian-data-sovereignty.md)

**Schedule convention:** `0 6 * * 1-5` (weekdays 06:00 ET), `time_zone: America/Toronto`. Active in both bi-stg and bi-srv per architecture decision (this diverges from the standard pattern of pausing stg). (source: architecture.md — Pipeline Architecture)

**Environment strategy:** Both `bi-stg` and `bi-srv` active. Separate GCS buckets per env. Jinja `PROJECT_TYPE` switch handles bucket name, schedule, and env-specific config. (source: architecture.md — Infrastructure & Deployment)

### Naming Conventions (Enforce from Day 1)

These conventions apply to ALL subsequent stories. Establishing them correctly here prevents drift:

| Convention | Pattern | Example |
|---|---|---|
| Dataset | `roaming_intelligence` | Single dataset for all tables |
| Layer prefix | `raw_`, `stg_`, `crt_` | `stg_carrier_kpi_daily`, `crt_mv_carrier_quality_summary` |
| Object prefix | `sp_`, `vw_`, `mv_`, `bq_` | `sp_refresh_carrier_kpis`, `crt_mv_country_quality_summary` |
| Combined | `{layer}_{type}_{descriptor}` | Views/MVs; procs use `sp_{descriptor}` (no layer prefix) |
| Columns | `snake_case` + `kpi_`/`norm_` domain prefix | `kpi_latency_ms`, `norm_throughput`, `composite_quality_score` |

(source: architecture.md — Implementation Patterns & Consistency Rules)

### Idempotent Writes Pattern

All stored procs MUST use `DELETE` + `INSERT` on the target partition. Never use `MERGE`. This is the project-wide convention for idempotency. (source: architecture.md — Process Patterns)

### Pipeline Step Chain (Context for Pulumi.yaml Structure)

The Pulumi.yaml will eventually define a 6-step Cloud Workflows chain. For this story, set up the skeleton structure that accommodates:
1. `step1_refresh_data` — BQ stored proc
2. `step2_compute_kpis` — BQ stored proc
3. `step3_detect_degradation` — BQ stored proc
4. `step4_quality_checks` — BQ stored proc
5. `step5_curate` — BQ stored proc
6. `step6_generate_report` — Cloud Run Job trigger

The monolithic stack pattern (inline `sourceContents`) is appropriate here — 1 workflow with 6 sequential steps. (source: infrastructure/cloud-workflows-orchestration.md §7)

### `${}` vs `$${}` — Critical Pulumi/Workflows Distinction

Inside inline `sourceContents` in Pulumi.yaml:
- `${variable}` = resolved at **Pulumi deploy time** (references Pulumi variables)
- `$${variable}` = resolved at **Cloud Workflows runtime** (loop vars, `sys.get_env`, step outputs)

Getting this wrong causes silent deploy-time errors or runtime failures. (source: infrastructure/cloud-workflows-orchestration.md §3.4)

### Python Dependencies (pyproject.toml)

Required dependencies for the report generation container:
- `plotly` — chart generation (use `graph_objects` only, NOT `plotly.express`)
- `jinja2` — HTML templating
- `google-cloud-bigquery` — BQ client
- `structlog` — structured logging with correlation IDs
- `google-cloud-storage` — GCS upload

Dev dependencies:
- `pytest`
- `ruff` — linting
- `mypy` — type checking

(source: architecture.md — Python Code Conventions, engineering/python-code-quality.md)

### Dockerfile Pattern

The Dockerfile should follow TELUS conventions:
- Use an official Python base image
- Copy `pyproject.toml` and install dependencies first (layer caching)
- Copy `src/` and `templates/` directories
- Set `main.py` as the entrypoint
- Pin the base image tag (no `:latest`)
- The container image lives in `images/roaming-intelligence/` and is deployed via the `images/` pillar's CI

(source: infrastructure/bi-layer-overview.md §2, engineering/cloud-native-patterns.md)

### Anti-Patterns to Avoid

- **Do NOT** create tables without a layer prefix (`stg_`, `crt_`)
- **Do NOT** use `camelCase` in BigQuery column names — everything is `snake_case`
- **Do NOT** hardcode GCP project IDs or bucket names — use Jinja variables
- **Do NOT** mix Plotly Express and Graph Objects
- **Do NOT** write to `crt_*` tables directly from raw — always go through staging
- **Do NOT** put IaC files in `images/` or application code in `stacks/`
- **Do NOT** use Pulumi-Python — bi-layer uses YAML+Jinja exclusively

(source: architecture.md — Enforcement Guidelines)

### What This Story Does NOT Include

- No BigQuery table creation (that's Story 1.4)
- No stored procedure implementation (that's Epic 2)
- No Datahub access request (that's Story 1.3)
- No Netscout schema validation (that's Story 1.2)
- No Cloud Workflows wiring (that's Story 4.1)
- No actual report generation code (that's Epic 3)

This story creates the **skeleton** — the correct directory layout, template files, and configuration stubs that all subsequent stories build upon.

### Project Structure Notes

The complete target directory structure (from architecture.md):

```
roaming-intelligence/
├── stacks/roaming-intelligence/
│   ├── Pulumi.yaml                            # Cloud Workflows, Scheduler, BQ resources, IAM
│   ├── environment.j2                         # Env-specific: bucket names, schedule, pause
│   └── sql/                                   # BQ stored proc source (referenced by Pulumi)
│       ├── sp_refresh_carrier_kpis.sql        # (placeholder — implemented in Story 2.1)
│       ├── sp_compute_composite_scores.sql    # (placeholder — implemented in Story 2.2)
│       ├── sp_detect_degradation.sql          # (placeholder — implemented in Story 2.3)
│       ├── sp_run_quality_checks.sql          # (placeholder — implemented in Story 2.4)
│       ├── sp_curate_output.sql               # (placeholder — implemented in Story 2.5)
│       └── backfill/
│           └── sp_backfill_historical.sql     # (placeholder — implemented in Story 2.6)
│
├── images/roaming-intelligence/
│   ├── Dockerfile
│   ├── pyproject.toml
│   ├── src/
│   │   ├── __init__.py
│   │   ├── main.py                            # Entry point: query BQ → generate HTML → upload GCS
│   │   ├── config.py                          # Env config: GCP project, bucket name, dataset
│   │   ├── bq_client.py                       # BigQuery query functions (reads crt_mv_* views)
│   │   ├── report/
│   │   │   ├── __init__.py
│   │   │   ├── builder.py                     # Orchestrates section generation, assembles final HTML
│   │   │   ├── sections/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── executive_summary.py
│   │   │   │   ├── country_overview.py
│   │   │   │   ├── carrier_rankings.py
│   │   │   │   ├── trend_charts.py
│   │   │   │   ├── usage_analytics.py
│   │   │   │   └── data_quality.py
│   │   │   └── charts.py                      # Shared Plotly graph_objects helpers
│   │   └── gcs_upload.py                      # Upload HTML to GCS bucket
│   ├── templates/
│   │   ├── base.html.j2                       # Jinja2 base: HTML structure, nav, embedded CSS
│   │   └── section.html.j2                    # Reusable section wrapper
│   └── tests/
│       ├── __init__.py
│       ├── test_bq_client.py
│       ├── test_builder.py
│       ├── test_sections/
│       │   ├── test_executive_summary.py
│       │   ├── test_carrier_rankings.py
│       │   ├── test_trend_charts.py
│       │   └── ...
│       └── fixtures/
│           └── sample_data.py
│
└── .github/                                   # CI (if applicable at fork level)
```

Alignment: This structure matches architecture.md §Project Structure exactly. No variances.

### References

- [architecture.md — Bi-Layer Monorepo Structure] — Complete directory tree definition
- [architecture.md — Implementation Patterns & Consistency Rules] — Naming conventions, idempotency, logging
- [architecture.md — Pipeline Architecture] — 6-step Cloud Workflows chain, monolithic stack pattern
- [architecture.md — Selected Technology Stack] — Full tech stack with rationale
- [epics.md — Story 1.1] — User story, acceptance criteria, BDD
- [epics.md — Additional Requirements] — Schedule, env strategy, template forking requirement
- (source: infrastructure/bi-layer-overview.md) — Two-pillar pattern, three environments, promotion flow, stacks catalog
- (source: infrastructure/cloud-workflows-orchestration.md) — Pulumi YAML structure, `${}` vs `$${}`convention, schedule/pause conventions
- (source: infrastructure/bigquery-enterprise-datahub.md) — Datahub layers, naming prefixes, access model
- (source: engineering/pulumi-best-practices.md) — Jinja+Pulumi single-responsibility split, env-aware behaviour
- (source: engineering/sql-best-practices.md §6) — Object naming prefixes (`sp_`, `vw_`, `mv_`, `bq_`)
- (source: engineering/python-project-structure.md) — Python project layout, pyproject.toml, Dockerfile
- (source: governance/canadian-data-sovereignty.md) — `northamerica-northeast1` requirement, no US regions

## Infrastructure Compliance

- **Bi-layer two-pillar structure**: `stacks/` for IaC, `images/` for application code. Never co-locate. (source: infrastructure/bi-layer-overview.md §2)
- **Template forking**: All Pulumi.yaml MUST be forked from `telus/bi-layer-docs` catalog templates, not hand-authored. (source: infrastructure/bi-layer-overview.md §5)
- **Pulumi YAML+Jinja only**: Not Pulumi-Python. Bi-layer CI expects YAML+Jinja. (source: infrastructure/bi-layer-overview.md §7)
- **Three environments**: Workbench (ephemeral), bi-stg (PR-driven), bi-srv (production). Jinja `PROJECT_TYPE` switches env-specific values. (source: infrastructure/bi-layer-overview.md §3)
- **Two-stage fork-and-PR promotion**: Stage 1 (team fork internal), Stage 2 (fork→upstream, triggers `pulumi up`). No self-approval on upstream PRs. (source: infrastructure/bi-layer-overview.md §4)
- **Canadian data residency**: All resources in `northamerica-northeast1`. No US regions permitted. (source: governance/canadian-data-sovereignty.md)
- **BigQuery naming**: Layer prefixes (`stg_`, `crt_`) + object type prefixes (`sp_`, `vw_`, `mv_`). (source: engineering/sql-best-practices.md §6)

## Governance Checklist

| Gate | Status | Required Action |
|------|--------|-----------------|
| DEP Review | Warned | Awaiting developer action — complete before implementation phase |
| DNTL Classification | Warned | Awaiting developer action — classify data under DNTL framework |
| De-identification Standards | Warned | Awaiting developer action — confirm no PII in pipeline (data is aggregated network metrics) |

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Change Log

- 2026-05-22: Story implemented — complete bi-layer project skeleton created with both stacks/ and images/ pillars, all tests passing (11/11)

### Completion Notes List

- Pulumi.yaml forked from `scheduled_bq_multi_step_stored_proc` pattern with 6-step workflow skeleton, Cloud Scheduler, BQ dataset, and IAM
- environment.j2 configures per-env: GCS buckets, Docker image tags, schedule, pause_status, gchat secrets, service accounts
- pause_status set to `false` for both bi-stg and bi-srv per architecture decision (both envs active)
- Python report generator skeleton: main.py entry point, config.py (env vars + dataclass), bq_client.py (crt_mv_* only), gcs_upload.py
- Report module: builder.py orchestrator, charts.py (graph_objects helpers), 6 section stubs matching architecture spec
- Jinja2 templates: base.html.j2 with TELUS branding, nav, embedded CSS; section.html.j2 wrapper
- SQL placeholders in stacks/ for all 5 stored procs + backfill
- 11 tests: 4 BQ client (verify crt_mv_* view queries), 3 builder (HTML output, template rendering), 4 config (env var loading, defaults, immutability)
- All files use type hints, structlog, and snake_case per architecture conventions

### File List

**New files (stacks/ pillar):**
- stacks/roaming-intelligence/Pulumi.yaml
- stacks/roaming-intelligence/environment.j2
- stacks/roaming-intelligence/sql/sp_refresh_carrier_kpis.sql
- stacks/roaming-intelligence/sql/sp_compute_composite_scores.sql
- stacks/roaming-intelligence/sql/sp_detect_degradation.sql
- stacks/roaming-intelligence/sql/sp_run_quality_checks.sql
- stacks/roaming-intelligence/sql/sp_curate_output.sql
- stacks/roaming-intelligence/sql/backfill/sp_backfill_historical.sql

**New files (images/ pillar):**
- images/roaming-intelligence/Dockerfile
- images/roaming-intelligence/pyproject.toml
- images/roaming-intelligence/src/__init__.py
- images/roaming-intelligence/src/main.py
- images/roaming-intelligence/src/config.py
- images/roaming-intelligence/src/bq_client.py
- images/roaming-intelligence/src/gcs_upload.py
- images/roaming-intelligence/src/report/__init__.py
- images/roaming-intelligence/src/report/builder.py
- images/roaming-intelligence/src/report/charts.py
- images/roaming-intelligence/src/report/sections/__init__.py
- images/roaming-intelligence/src/report/sections/executive_summary.py
- images/roaming-intelligence/src/report/sections/country_overview.py
- images/roaming-intelligence/src/report/sections/carrier_rankings.py
- images/roaming-intelligence/src/report/sections/trend_charts.py
- images/roaming-intelligence/src/report/sections/usage_analytics.py
- images/roaming-intelligence/src/report/sections/data_quality.py
- images/roaming-intelligence/templates/base.html.j2
- images/roaming-intelligence/templates/section.html.j2
- images/roaming-intelligence/tests/__init__.py
- images/roaming-intelligence/tests/test_bq_client.py
- images/roaming-intelligence/tests/test_builder.py
- images/roaming-intelligence/tests/test_config.py
- images/roaming-intelligence/tests/test_sections/__init__.py
- images/roaming-intelligence/tests/test_sections/test_executive_summary.py
- images/roaming-intelligence/tests/test_sections/test_carrier_rankings.py
- images/roaming-intelligence/tests/test_sections/test_trend_charts.py
- images/roaming-intelligence/tests/fixtures/sample_data.py

### Review Findings

**Decision-needed (resolved):**
- [x] [Review][Decision] AC3 spec contradiction — dismissed, `stacks/` placement is architecturally correct. Spec AC3 is a drafting error.
- [x] [Review][Decision] `sp_curate_output.sql` MV refresh pattern — dismissed, MV refresh is exempt from DELETE+INSERT mandate (architecturally correct).
- [x] [Review][Decision] `REFRESH_DATE` default — resolved: changed to yesterday to match pipeline's `CURRENT_DATE()-1`. [config.py:36]

**Patch (applied):**
- [x] [Review][Patch] Step 6 Cloud Run URL double-interpolation — fixed: flat Pulumi expression, no nested string literals. [Pulumi.yaml:105]
- [x] [Review][Patch] `pandas` missing from production deps — fixed: changed to `google-cloud-bigquery[pandas]`. [pyproject.toml:8]
- [x] [Review][Patch] Dockerfile `pip install .` before source — fixed: copy src/templates first, then install. [Dockerfile:4]
- [x] [Review][Patch] `_require_env` accepts empty strings — fixed: changed `is None` to `not value` check. [config.py:44]
- [x] [Review][Patch] `environment.j2` no `else` clause — fixed: added `else` with Jinja raise for all 5 variable blocks. [environment.j2]
- [x] [Review][Patch] `Pulumi.yaml` `pause_status` no `else` — fixed: added `else` with Jinja raise. [Pulumi.yaml:23]
- [x] [Review][Patch] `REFRESH_DATE` no format validation — fixed: added ISO date regex validation. [config.py:35-37]
- [x] [Review][Patch] Test inconsistency — fixed: added project/dataset assertion to `test_query_country_quality_summary`. [test_bq_client.py:35]

**Deferred:**
- [x] [Review][Defer] BQ `jobs.query` synchronous with no polling — long-running procs may return `jobComplete: false`. — deferred, workflow skeleton refined in Story 4.1
- [x] [Review][Defer] Step 6 Cloud Run Job result never inspected — pipeline succeeds even if report fails. — deferred, Story 4.1
- [x] [Review][Defer] `BigQueryClient._query_view` no error handling around query/to_dataframe. — deferred, expanded in Epic 3
- [x] [Review][Defer] `gcs_upload.py` has zero test coverage. — deferred, expanded later
- [x] [Review][Defer] `figure_to_html` CDN dependency — offline/egress-restricted reports won't render charts. — deferred, charts not implemented yet
- [x] [Review][Defer] `gchat_secret_id` defined in IaC but never wired into workflow or app. — deferred, Story 4.2
- [x] [Review][Defer] `pipeline_sa_bq_editor` grants `dataEditor` to orchestrator SA — overly broad. — deferred, refined in Story 1.4
- [x] [Review][Defer] `sql/backfill/sp_backfill_historical.sql` technically out of Story 1.1 scope. — deferred, reasonable structural placeholder
- [x] [Review][Defer] Layer/object prefix compliance cannot be verified — SQL stubs lack DDL bodies. — deferred, Epic 2
- [x] [Review][Defer] BQ query has no timeout configuration. — deferred, expanded later
