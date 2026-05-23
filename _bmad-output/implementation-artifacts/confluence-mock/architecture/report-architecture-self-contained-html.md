---
title: "Report Architecture: Self-Contained HTML"
type: architecture-decision
source_artifact: "architecture.md"
created: "2026-05-22"
updated: "2026-05-22"
---

# Report Architecture: Self-Contained HTML

**Format:** Single self-contained HTML file. All charts (Plotly JS), data, and styling embedded. No external CDN dependencies. Shareable via email, Slack, or direct GCS link.

**Report Sections:**
1. **Executive Summary** — Data freshness, coverage stats, degradation alerts, quality check flags
2. **Country Overview** — Sortable table of all countries with aggregate quality indicator
3. **Carrier Rankings by Country** — Per-country carriers ranked by composite score, individual KPIs visible, steered-to carrier flagged
4. **Trend Charts** — Plotly interactive line charts: up to 90-day KPI trends per carrier
5. **Usage Analytics** — Traffic volume, session count, subscriber count per carrier; <1% carriers grouped as "Other"
6. **Data Quality** — Freshness check, coverage validation, volume anomaly flags

**Output Location:** GCS bucket, date-versioned path: `reports/{YYYY-MM-DD}/roaming-intelligence.html`. Separate buckets per environment.

**Technology:** Python + Plotly `graph_objects` (never Express) + Jinja2 templates. Container runs as Cloud Run Job.

**Data Contract:** Report reads ONLY from `crt_mv_*` curated views — never from `stg_*` tables. Exception: `stg_data_quality_log` for pipeline metadata in executive summary and data quality sections.
