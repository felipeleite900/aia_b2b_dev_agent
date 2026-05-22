---
title: 'Build Country Overview Report Section'
type: 'feature'
created: '2026-05-22'
status: 'done'
route: 'one-shot'
baseline_commit: '7d07918'
---

## Intent

**Problem:** No country-level view exists in the report. Stakeholders need to quickly identify which countries have quality issues.

**Approach:** Implement `generate_country_overview()` rendering a table of countries sorted by avg composite quality score with color-coded bands (green/amber/red), carrier counts, degraded carrier counts, and traffic/session volumes.

## Suggested Review Order

- Country table with quality color bands and html.escape()
  [`country_overview.py:22`](../../images/roaming-intelligence/src/report/sections/country_overview.py#L22)

- Builder wiring
  [`builder.py:58`](../../images/roaming-intelligence/src/report/builder.py#L58)

- 7 tests: happy path (all countries, sort order, color bands) + empty data
  [`test_country_overview.py:1`](../../images/roaming-intelligence/tests/test_sections/test_country_overview.py#L1)
