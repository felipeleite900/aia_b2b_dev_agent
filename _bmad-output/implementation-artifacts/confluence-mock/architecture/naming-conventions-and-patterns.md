---
title: "Naming Conventions and Implementation Patterns"
type: architecture-decision
source_artifact: "architecture.md"
created: "2026-05-22"
updated: "2026-05-22"
---

# Naming Conventions and Implementation Patterns

## Data Warehouse Layers

| Prefix | Layer | Purpose |
|---|---|---|
| `raw_` / `ent_*` | Raw | Source data (upstream, read-only) |
| `stg_` | Staging | Intermediate pipeline outputs |
| `crt_` | Curated | Final output contract for report |

## Object Type Prefixes

- `sp_` — stored procedures
- `vw_` — views
- `mv_` — materialized views

## Column Naming

All columns `snake_case`. KPI columns: `kpi_` prefix for raw, `norm_` prefix for normalized (0-100).

## Process Patterns

**Idempotent Writes:** All stored procs use `DELETE` + `INSERT` on the target partition (not `MERGE`).

**Pipeline Logging:** Each stored proc logs to `stg_data_quality_log`: step name, start time, end time, row count, status.

**Error Propagation:** Cloud Workflows step failures propagate to gchat via `aia_gchat_workflow`.

**Python Conventions:** `snake_case`, `structlog`, type hints, Google-style docstrings, `plotly.graph_objects` only.

## Anti-Patterns

- Creating tables without a layer prefix
- Using `camelCase` in BigQuery column names
- Writing to `crt_*` directly from raw — always go through staging
- Hardcoding GCP project IDs or bucket names
- Mixing Plotly Express and Graph Objects
