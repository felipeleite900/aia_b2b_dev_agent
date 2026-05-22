# Epic 3 Context: Interactive Report Generation & Distribution

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Build the Python report generator that reads the four curated BigQuery views (`crt_mv_*`) and produces a single self-contained HTML report with interactive Plotly charts covering quality rankings, usage analytics, trend analysis, side-by-side carrier comparison, and data quality indicators. After this epic, reports can be generated manually via the Cloud Run Job container. The report replaces a deployed web application (architecture pivot), so it must deliver all analytical value in one shareable HTML file.

## Stories

- Story 3.1: Set Up Report Generator Container and Base Template
- Story 3.2: Build Executive Summary Report Section
- Story 3.3: Build Country Overview Report Section
- Story 3.4: Build Carrier Rankings Report Section
- Story 3.5: Build Trend Charts Report Section
- Story 3.6: Build Usage Analytics Report Section
- Story 3.7: Build Data Quality Report Section
- Story 3.8: Build GCS Upload and Report Output

## Requirements & Constraints

**Functional requirements delivered by this epic:**
- FR-4: Sortable country list with aggregate quality indicators.
- FR-5/FR-9: Carrier rankings by composite quality score with individual KPIs visible; steered-to carrier labeled distinctly.
- FR-6: Carrier detail drill-down showing 30-day daily KPI values and metadata (name, MCC/MNC, country).
- FR-7/FR-8: Usage metrics (traffic MB, sessions, subscribers) with traffic share percentages; carriers <1% grouped as "Other".
- FR-10: Side-by-side carrier comparison with aligned KPI columns; differences >10% flagged.
- FR-11: Trend charts with configurable time windows (7/14/30/90 days); default 30-day.
- FR-13/FR-14/FR-15: Data freshness display with 36-hour staleness warning, coverage validation, volume anomaly flags.
- FR-16: Access scoped via GCS IAM (no web auth layer).
- FR-17: Plotly built-in interactivity -- hover tooltips, zoom, pan.
- FR-18: Plotly native filtering plus client-side HTML table sorting via embedded JavaScript.

**Non-functional:**
- Single self-contained HTML file with no external CDN dependencies.
- All embedded CSS and JS inline.
- Report filename: `roaming-intelligence-{YYYY-MM-DD}.html`. GCS path: `reports/{YYYY-MM-DD}/`.
- No PII anywhere in the output.
- Canadian data residency: GCS buckets in `northamerica-northeast1` only.

## Technical Decisions

**Data contract -- the `crt_mv_*` views (produced by Epic 2):**
The Python report generator NEVER reads `stg_*` tables -- only these four curated views:

| View | Purpose |
|---|---|
| `crt_mv_carrier_quality_summary` | Per-carrier composite score, individual KPIs, degradation flags, metadata, `is_steered` |
| `crt_mv_country_quality_summary` | Per-country aggregate quality indicator, carrier count, total traffic |
| `crt_mv_carrier_quality_trend` | Up to 90 days of daily KPI values per carrier for trend charts |
| `crt_mv_carrier_usage_summary` | Traffic volume, session count, subscriber count, traffic share %; <1% tagged |

Exception: `stg_data_quality_log` is read by the executive summary and data quality sections for pipeline run metadata and quality check results.

**Python stack and conventions:**
- Plotly `graph_objects` only (never `plotly.express`).
- Jinja2 for HTML assembly: `base.html.j2` defines page structure/nav/CSS; `section.html.j2` wraps individual sections.
- `structlog` for structured logging with correlation IDs.
- Type hints required on all function signatures; Google-style docstrings.
- One function per report section. Sections return HTML/Plotly figures to `builder.py`; sections never call each other.
- `bq_client.py` is the single data-access layer -- all BigQuery queries go through it.
- Environment config (GCP project, bucket, dataset) from environment variables via `config.py`.

**Container and directory layout (already scaffolded):**
```
images/roaming-intelligence/
  Dockerfile, pyproject.toml
  src/main.py              -- entry point: query BQ -> generate sections -> assemble HTML -> upload GCS
  src/config.py            -- env config
  src/bq_client.py         -- reads crt_mv_* views
  src/gcs_upload.py        -- uploads to date-versioned GCS path
  src/report/builder.py    -- orchestrates assembly
  src/report/charts.py     -- shared Plotly graph_objects helpers
  src/report/sections/     -- one module per report section
  templates/               -- Jinja2 templates
  tests/                   -- pytest with fixtures/sample_data.py
```

**Dependencies (pinned in pyproject.toml):** `plotly`, `jinja2`, `google-cloud-bigquery`, `google-cloud-storage`, `structlog`.

**GCS upload:** Bucket name is environment-specific (bi-stg vs. bi-srv). Service account uses `roles/storage.objectCreator`. Upload returns the GCS link for pipeline notifications.

## Cross-Story Dependencies

- **Epic 2 -> Epic 3:** All stories depend on the `crt_mv_*` views being defined and populated. Use mock/fixture data for development; real data is available once Epic 2 stories 2.1-2.5 are complete.
- **Story 3.1 -> all other 3.x stories:** Container scaffold, `bq_client.py`, `builder.py`, and base templates must exist before section development.
- **Stories 3.2-3.7 -> 3.8:** GCS upload runs after all sections are assembled.
- **Epic 3 -> Epic 4:** Story 4.1 wires the report generator as step 6 of the Cloud Workflows chain. The container must be buildable and runnable independently.
