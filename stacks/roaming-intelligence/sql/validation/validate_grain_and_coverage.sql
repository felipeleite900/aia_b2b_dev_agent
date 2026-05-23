-- validate_grain_and_coverage.sql
-- Story 1.2: Netscout BigQuery grain, coverage, and quality validation
-- Purpose: Run these queries after explore_source_schema.sql to confirm the
--          data grain, date range, completeness, and coverage assumptions
--          required by the roaming intelligence pipeline.
-- Usage:   Replace <SOURCE_PROJECT>, <SOURCE_DATASET>, <SOURCE_TABLE> with
--          actual values. Replace dimension column names (country, carrier,
--          report_date) with actual names discovered during schema exploration.
--          Run each block independently.
-- Path:    stacks/roaming-intelligence/sql/validation/validate_grain_and_coverage.sql

-- ============================================================================
-- BLOCK 1: Grain confirmation — Is the data unique at country/carrier/day?
-- ============================================================================
-- What it checks:
--   Groups by the assumed grain (country, carrier, date) and counts rows per
--   group. If any group has more than 1 row, the true grain is finer than
--   country/carrier/day (e.g., hourly, per-interface, per-technology).
-- What to look for:
--   - If max_rows_per_group = 1, the grain IS country/carrier/day.
--   - If max_rows_per_group > 1, inspect the groups with duplicates to
--     identify the additional dimension(s) that distinguish rows.
--   - Record the result in docs/schema-mapping.md "Data Grain" section.
-- IMPORTANT: Replace column names with actual discovered names.

WITH
  -- grain_check: count rows per assumed grain
  grain_check AS (
    SELECT
      country,
      carrier,
      report_date,
      COUNT(*) AS row_count
    FROM `<SOURCE_PROJECT>.<SOURCE_DATASET>.<SOURCE_TABLE>`
    GROUP BY 1, 2, 3
  )

SELECT
  COUNT(*) AS total_groups,
  SUM(CASE WHEN row_count = 1 THEN 1 ELSE 0 END) AS unique_groups,
  SUM(CASE WHEN row_count > 1 THEN 1 ELSE 0 END) AS duplicate_groups,
  MAX(row_count) AS max_rows_per_group,
  AVG(row_count) AS avg_rows_per_group
FROM grain_check;

-- If duplicates exist, inspect a sample to find the extra dimension:
-- SELECT *
-- FROM `<SOURCE_PROJECT>.<SOURCE_DATASET>.<SOURCE_TABLE>`
-- WHERE country = (SELECT country FROM grain_check WHERE row_count > 1 LIMIT 1)
--   AND carrier = (SELECT carrier FROM grain_check WHERE row_count > 1 LIMIT 1)
--   AND report_date = (SELECT report_date FROM grain_check WHERE row_count > 1 LIMIT 1)
-- ORDER BY 1, 2, 3;


-- ============================================================================
-- BLOCK 2: Date range check — Min/max dates, distinct count, gap detection
-- ============================================================================
-- What it checks:
--   Determines the available date range, counts distinct dates, and identifies
--   any gaps in the daily sequence (missing dates).
-- What to look for:
--   - Earliest and latest dates to confirm historical depth.
--   - expected_days vs actual_distinct_dates: a mismatch reveals gaps.
--   - Gap details show specific missing dates for investigation.
-- IMPORTANT: Replace report_date with the actual date column name.
-- If the date column is TIMESTAMP or DATETIME, wrap it with CAST(... AS DATE)
-- in all references below to avoid implicit truncation issues.

WITH
  -- date_stats: basic date range statistics
  date_stats AS (
    SELECT
      MIN(report_date) AS earliest_date,
      MAX(report_date) AS latest_date,
      COUNT(DISTINCT report_date) AS actual_distinct_dates,
      DATE_DIFF(MAX(report_date), MIN(report_date), DAY) + 1 AS expected_days
    FROM `<SOURCE_PROJECT>.<SOURCE_DATASET>.<SOURCE_TABLE>`
  ),

  -- all_dates: generate the complete date sequence between min and max
  all_dates AS (
    SELECT date_val
    FROM date_stats,
    UNNEST(
      GENERATE_DATE_ARRAY(earliest_date, latest_date, INTERVAL 1 DAY)
    ) AS date_val
  ),

  -- source_dates: distinct dates actually present in the data
  source_dates AS (
    SELECT DISTINCT report_date AS date_val
    FROM `<SOURCE_PROJECT>.<SOURCE_DATASET>.<SOURCE_TABLE>`
  ),

  -- missing_dates: dates in the expected range but absent from the data
  missing_dates AS (
    SELECT a.date_val AS missing_date
    FROM all_dates a
    LEFT JOIN source_dates s ON a.date_val = s.date_val
    WHERE s.date_val IS NULL
  )

SELECT
  ds.earliest_date,
  ds.latest_date,
  ds.actual_distinct_dates,
  ds.expected_days,
  ds.expected_days - ds.actual_distinct_dates AS gap_count,
  ARRAY_AGG(m.missing_date IGNORE NULLS ORDER BY m.missing_date) AS missing_dates_list
FROM date_stats ds
LEFT JOIN missing_dates m ON TRUE
GROUP BY 1, 2, 3, 4;


-- ============================================================================
-- BLOCK 3: NULL / completeness analysis — Per-column NULL rate
-- ============================================================================
-- What it checks:
--   For every column, counts total rows, NULL values, and computes the
--   NULL percentage. Identifies columns with significant missing data.
-- What to look for:
--   - Dimension columns (country, carrier, date) should have 0% NULLs.
--   - KPI columns with high NULL rates may indicate conditional population
--     (e.g., only populated for certain technologies or timeframes).
--   - Columns with 100% NULLs are effectively unused.
--   - Record findings in docs/schema-mapping.md "Column Mapping" Notes.
-- IMPORTANT: Replace column names with actual discovered names. Add or remove
--            columns as needed based on Block 1 of explore_source_schema.sql.

SELECT
  COUNT(*) AS total_rows,

  -- Dimension columns
  COUNTIF(country IS NULL) AS country_nulls,
  ROUND(SAFE_DIVIDE(COUNTIF(country IS NULL), COUNT(*)) * 100, 2) AS country_null_pct,

  COUNTIF(carrier IS NULL) AS carrier_nulls,
  ROUND(SAFE_DIVIDE(COUNTIF(carrier IS NULL), COUNT(*)) * 100, 2) AS carrier_null_pct,

  COUNTIF(report_date IS NULL) AS report_date_nulls,
  ROUND(SAFE_DIVIDE(COUNTIF(report_date IS NULL), COUNT(*)) * 100, 2) AS report_date_null_pct,

  COUNTIF(mcc IS NULL) AS mcc_nulls,
  ROUND(SAFE_DIVIDE(COUNTIF(mcc IS NULL), COUNT(*)) * 100, 2) AS mcc_null_pct,

  COUNTIF(mnc IS NULL) AS mnc_nulls,
  ROUND(SAFE_DIVIDE(COUNTIF(mnc IS NULL), COUNT(*)) * 100, 2) AS mnc_null_pct,

  -- KPI columns (replace with actual column names)
  COUNTIF(kpi_latency IS NULL) AS latency_nulls,
  ROUND(SAFE_DIVIDE(COUNTIF(kpi_latency IS NULL), COUNT(*)) * 100, 2) AS latency_null_pct,

  COUNTIF(kpi_throughput IS NULL) AS throughput_nulls,
  ROUND(SAFE_DIVIDE(COUNTIF(kpi_throughput IS NULL), COUNT(*)) * 100, 2) AS throughput_null_pct,

  COUNTIF(kpi_packet_loss IS NULL) AS packet_loss_nulls,
  ROUND(SAFE_DIVIDE(COUNTIF(kpi_packet_loss IS NULL), COUNT(*)) * 100, 2) AS packet_loss_null_pct,

  COUNTIF(kpi_session_success IS NULL) AS session_success_nulls,
  ROUND(SAFE_DIVIDE(COUNTIF(kpi_session_success IS NULL), COUNT(*)) * 100, 2) AS session_success_null_pct

FROM `<SOURCE_PROJECT>.<SOURCE_DATASET>.<SOURCE_TABLE>`;


-- ============================================================================
-- BLOCK 4: Historical depth — Confirm at least 90 days for backfill
-- ============================================================================
-- What it checks:
--   Verifies whether the source table contains at least 90 days of historical
--   data from the latest available date, which is the minimum required for
--   the sp_backfill_historical.sql initial load (Story 2.6).
-- What to look for:
--   - days_of_history >= 90: sufficient for backfill.
--   - days_of_history < 90: backfill window must be reduced, or an
--     alternative data source is needed.
--   - daily_row_volume: helps estimate backfill cost and duration.
--   - Record result in docs/schema-mapping.md "Historical Depth" section.

WITH
  -- depth_stats: compute history span and daily volume
  depth_stats AS (
    SELECT
      MIN(report_date) AS earliest_date,
      MAX(report_date) AS latest_date,
      COUNT(DISTINCT report_date) AS distinct_dates,
      DATE_DIFF(MAX(report_date), MIN(report_date), DAY) + 1 AS days_of_history,
      COUNT(*) AS total_rows
    FROM `<SOURCE_PROJECT>.<SOURCE_DATASET>.<SOURCE_TABLE>`
  )

SELECT
  earliest_date,
  latest_date,
  distinct_dates,
  days_of_history,
  total_rows,
  ROUND(total_rows / NULLIF(distinct_dates, 0), 0) AS avg_daily_row_volume,
  CASE
    WHEN distinct_dates >= 90 THEN 'PASS: Sufficient for 90-day backfill'
    ELSE CONCAT(
      'FAIL: Only ',
      CAST(distinct_dates AS STRING),
      ' distinct dates available (need 90; calendar span = ',
      CAST(days_of_history AS STRING),
      ' days)'
    )
  END AS backfill_readiness
FROM depth_stats;


-- ============================================================================
-- BLOCK 5: Country / carrier coverage — Distinct counts and top 20 by volume
-- ============================================================================
-- What it checks:
--   Counts distinct countries and carriers, then lists the top 20 by row
--   count to understand data distribution and identify dominant markets.
-- What to look for:
--   - Total distinct countries: confirms international scope.
--   - Row count distribution: heavily skewed = a few large markets dominate.
--   - Check for TELUS home-network data vs roaming-partner data.
--   - Carrier names: look for inconsistencies (e.g., "Vodafone" vs
--     "Vodafone UK" vs "vodafone").

-- 5a: Summary counts
SELECT
  COUNT(DISTINCT country) AS distinct_countries,
  COUNT(DISTINCT carrier) AS distinct_carriers,
  COUNT(DISTINCT CONCAT(country, '|', carrier)) AS distinct_country_carrier_pairs,
  COUNT(*) AS total_rows
FROM `<SOURCE_PROJECT>.<SOURCE_DATASET>.<SOURCE_TABLE>`;

-- 5b: Top 20 countries by row count
SELECT
  country,
  COUNT(DISTINCT carrier) AS carriers_in_country,
  COUNT(DISTINCT report_date) AS date_coverage,
  COUNT(*) AS row_count,
  MIN(report_date) AS earliest_date,
  MAX(report_date) AS latest_date
FROM `<SOURCE_PROJECT>.<SOURCE_DATASET>.<SOURCE_TABLE>`
GROUP BY 1
ORDER BY row_count DESC
LIMIT 20;

-- 5c: Top 20 carriers by row count
SELECT
  country,
  carrier,
  mcc,
  mnc,
  COUNT(DISTINCT report_date) AS date_coverage,
  COUNT(*) AS row_count,
  MIN(report_date) AS earliest_date,
  MAX(report_date) AS latest_date
FROM `<SOURCE_PROJECT>.<SOURCE_DATASET>.<SOURCE_TABLE>`
GROUP BY 1, 2, 3, 4
ORDER BY row_count DESC
LIMIT 20;
