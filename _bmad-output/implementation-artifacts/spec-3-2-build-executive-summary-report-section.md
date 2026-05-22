---
title: 'Build Executive Summary Report Section'
type: 'feature'
created: '2026-05-22'
status: 'done'
baseline_commit: '31b56d7'
context:
  - 'images/roaming-intelligence/src/report/builder.py'
  - 'images/roaming-intelligence/src/bq_client.py'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The report has no executive summary. Stakeholders opening the HTML report see an empty skeleton. The first section should give an at-a-glance view: data freshness, coverage stats, quality pulse, and degradation alerts — all in a few seconds of reading.

**Approach:** Implement `generate_executive_summary()` in `executive_summary.py` that consumes carrier/country summary DataFrames and quality log data to produce an HTML fragment with KPI stat cards and a degradation alert list. Wire it as the first section in `builder.py`. Add `query_quality_log()` to `bq_client.py` for the stg_data_quality_log exception.

## Boundaries & Constraints

**Always:**
- Section function signature: `def generate_executive_summary(carrier_df, country_df, quality_log_df, refresh_date) -> str`
- Return a plain HTML string (not a Plotly figure). Builder inserts it into the template.
- Use the `section.html.j2` template for wrapping (title + content).
- All data comes from DataFrames passed in — never instantiate BigQuery client inside a section.
- Follow existing code conventions: type hints, structlog, Google docstrings.

**Ask First:**
- If `stg_data_quality_log` schema doesn't support the quality check results needed, HALT.

**Never:**
- Import or call `bq_client` from within the section module.
- Use `plotly.express` — only `plotly.graph_objects` if charts are needed.
- Include PII in the output.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Happy path | All DataFrames populated | Stat cards + degradation list rendered | N/A |
| Empty carrier_df | No carrier data for date | "No data available" message instead of stats | Graceful fallback |
| No degraded carriers | degradation_flag all FALSE | "No degradation alerts" positive message | N/A |
| Quality checks failed | quality_log_df has 'fail' entries | Failed checks highlighted with warning styling | N/A |
| Empty quality_log_df | No log entries | Quality section shows "No check results available" | Graceful fallback |

</frozen-after-approval>

## Code Map

- `images/roaming-intelligence/src/report/sections/executive_summary.py` — MODIFY: implement generate_executive_summary()
- `images/roaming-intelligence/src/report/builder.py` — MODIFY: wire executive_summary as first section, import and call
- `images/roaming-intelligence/src/bq_client.py` — MODIFY: add query_quality_log() method for stg_data_quality_log
- `images/roaming-intelligence/tests/fixtures/sample_data.py` — MODIFY: add DataFrame fixtures for carrier_summary, country_summary, quality_log
- `images/roaming-intelligence/tests/test_sections/test_executive_summary.py` — MODIFY: implement tests

## Tasks & Acceptance

**Execution:**
- [x] `images/roaming-intelligence/src/bq_client.py` — Add `query_quality_log(refresh_date)` method that queries stg_data_quality_log filtered by refresh_date and step_name LIKE 'qc_%'
- [x] `images/roaming-intelligence/src/report/sections/executive_summary.py` — Implement generate_executive_summary() returning HTML with: (1) stat cards (country count, carrier count, avg composite score, degraded count), (2) quality check results table, (3) degradation alert list
- [x] `images/roaming-intelligence/src/report/builder.py` — Wire executive_summary as sections["executive-summary"], pass carrier_summary_df, country_summary_df, quality_log_df, config.refresh_date
- [x] `images/roaming-intelligence/tests/fixtures/sample_data.py` — Add carrier_quality_summary_df(), country_quality_summary_df(), quality_log_df() fixture functions returning pandas DataFrames
- [x] `images/roaming-intelligence/tests/test_sections/test_executive_summary.py` — Test happy path, empty data, no degradation, failed quality checks

**Acceptance Criteria:**
- Given carrier and country data, when generate_executive_summary() is called, then the returned HTML contains stat cards with country count, carrier count, average composite score, and degraded carrier count
- Given quality_log_df with 'fail' entries, when the section renders, then failed checks are visually distinct from passed checks
- Given empty carrier_df, when the section renders, then a "No data available" fallback message is shown instead of broken stats

## Design Notes

**Stat cards pattern:** Simple HTML `<div class="stat-card">` grid (2x2) with number + label. No Plotly chart needed for this section — it's a metrics dashboard, not a visualization.

**Quality log query:** `SELECT * FROM stg_data_quality_log WHERE refresh_date = @date AND step_name LIKE 'qc_%'` — returns the 3 quality check rows (freshness, coverage, volume) logged by sp_run_quality_checks.

**Degradation alerts:** Filter carrier_df where `degradation_flag == True`, show carrier name + country. Limit to top 10 with "and N more" if >10.

## Verification

**Commands:**
- `cd images/roaming-intelligence && python -m pytest tests/test_sections/test_executive_summary.py -v` — expected: all tests pass

**Manual checks (if no CLI):**
- generate_executive_summary() returns valid HTML string
- HTML contains no PII
- Empty DataFrame inputs produce graceful fallback, not exceptions

## Suggested Review Order

**Core section logic**

- Stat cards: country count, carrier count, avg composite, degradation count
  [`executive_summary.py:56`](../../images/roaming-intelligence/src/report/sections/executive_summary.py#L56)

- Quality checks table with pass/fail styling
  [`executive_summary.py:92`](../../images/roaming-intelligence/src/report/sections/executive_summary.py#L92)

- Degradation alerts: top 10 with overflow
  [`executive_summary.py:112`](../../images/roaming-intelligence/src/report/sections/executive_summary.py#L112)

**Integration**

- Builder wiring: queries data and passes to section
  [`builder.py:44`](../../images/roaming-intelligence/src/report/builder.py#L44)

- BQ client: parameterized query_quality_log for stg_data_quality_log
  [`bq_client.py:45`](../../images/roaming-intelligence/src/bq_client.py#L45)

**Tests**

- 11 tests across 4 classes: happy path, empty data, no degradation, failed checks
  [`test_executive_summary.py:1`](../../images/roaming-intelligence/tests/test_sections/test_executive_summary.py#L1)

## Spec Change Log
