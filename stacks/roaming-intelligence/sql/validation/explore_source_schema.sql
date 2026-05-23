-- explore_source_schema.sql
-- Story 1.2: Netscout BigQuery schema discovery
-- Purpose: Run these queries against the Netscout source table(s) to discover
--          column names, data types, sample values, and KPI availability.
-- Usage:   Replace <SOURCE_PROJECT>, <SOURCE_DATASET>, <SOURCE_TABLE> with
--          actual values before executing. Run each block independently.
-- Path:    stacks/roaming-intelligence/sql/validation/explore_source_schema.sql

-- ============================================================================
-- BLOCK 1: INFORMATION_SCHEMA — Discover all columns, types, and descriptions
-- ============================================================================
-- What it checks:
--   Lists every column in the source table with its ordinal position, data
--   type, nullability, and column description (if populated).
-- What to look for:
--   - Columns that map to country, carrier, MCC, MNC, date dimensions.
--   - Columns that could hold the 4 assumed KPIs (latency, throughput,
--     packet loss, session success rate).
--   - Partition and clustering column candidates.
--   - Any columns with descriptions that clarify meaning or units.

SELECT
  table_catalog,
  table_schema,
  table_name,
  column_name,
  ordinal_position,
  is_nullable,
  data_type,
  description
FROM `<SOURCE_PROJECT>.<SOURCE_DATASET>.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS`
WHERE table_name = '<SOURCE_TABLE>'
ORDER BY ordinal_position;


-- ============================================================================
-- BLOCK 2: Sample data — Visual inspection of first 100 rows
-- ============================================================================
-- What it checks:
--   Retrieves a small sample of raw data for manual inspection.
-- What to look for:
--   - Actual values in dimension columns (country names vs codes, carrier
--     format, date format and granularity).
--   - KPI value ranges and units (e.g., latency in ms vs seconds, throughput
--     in kbps vs Mbps, percentages as 0-1 vs 0-100).
--   - Unexpected NULL patterns or placeholder values (e.g., "N/A", -1, 0).
--   - Whether the table is partitioned (look for _PARTITIONTIME or similar).
-- NOTE: Using SELECT * here intentionally for discovery; production queries
--       must use explicit column lists per sql-best-practices.md.

-- TIP: On large tables, add a partition filter to avoid a full scan:
--   WHERE report_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
-- If report_date is a TIMESTAMP, cast it: CAST(report_date AS DATE)
SELECT *
FROM `<SOURCE_PROJECT>.<SOURCE_DATASET>.<SOURCE_TABLE>`
ORDER BY report_date DESC
LIMIT 100;


-- ============================================================================
-- BLOCK 3: Distinct value counts — Cardinality of key dimension columns
-- ============================================================================
-- What it checks:
--   Counts distinct values for columns likely to represent country, carrier,
--   and MCC/MNC dimensions. Helps assess data breadth and detect encoding
--   issues (e.g., same country under multiple names).
-- What to look for:
--   - Expected number of countries (~200-250 for global coverage).
--   - Carrier count proportional to country coverage.
--   - MCC/MNC pair count consistent with ITU allocations.
--   - Any suspiciously low or high counts indicating data quality issues.
-- IMPORTANT: Replace the column names below with the actual column names
--            discovered in Block 1. The names used here are guesses.

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT country) AS distinct_countries,
  COUNT(DISTINCT carrier) AS distinct_carriers,
  COUNT(DISTINCT mcc) AS distinct_mcc,
  COUNT(DISTINCT mnc) AS distinct_mnc,
  COUNT(DISTINCT CONCAT(COALESCE(mcc, 'NULL'), '-', COALESCE(mnc, 'NULL'))) AS distinct_mcc_mnc_pairs
FROM `<SOURCE_PROJECT>.<SOURCE_DATASET>.<SOURCE_TABLE>`;

-- Alternate: If column names differ, use the discovered names from Block 1.
-- Common alternatives: country_name, country_code, operator, operator_name,
--                      network_name, plmn_id, mobile_country_code,
--                      mobile_network_code.


-- ============================================================================
-- BLOCK 4: KPI column scan — Find columns matching expected KPI keywords
-- ============================================================================
-- What it checks:
--   Searches INFORMATION_SCHEMA for columns whose names contain keywords
--   related to the 4 assumed KPIs:
--     1. Latency        (keywords: latency, delay, rtt, round_trip)
--     2. Throughput      (keywords: throughput, bandwidth, bitrate, speed, kbps, mbps)
--     3. Packet loss     (keywords: packet, loss, drop, error)
--     4. Session success (keywords: session, success, establish, setup, attach)
-- What to look for:
--   - Direct matches confirm KPI availability.
--   - Partial matches may reveal related metrics or aggregated columns.
--   - No matches for a KPI indicates it may be missing or named differently.
--   - Multiple matches may mean raw vs aggregated columns exist.

SELECT
  column_name,
  data_type,
  description,
  CASE
    WHEN LOWER(column_name) LIKE '%latency%'
      OR LOWER(column_name) LIKE '%delay%'
      OR LOWER(column_name) LIKE '%rtt%'
      OR LOWER(column_name) LIKE '%round_trip%'
      THEN 'LATENCY'
    WHEN LOWER(column_name) LIKE '%throughput%'
      OR LOWER(column_name) LIKE '%bandwidth%'
      OR LOWER(column_name) LIKE '%bitrate%'
      OR LOWER(column_name) LIKE '%speed%'
      OR LOWER(column_name) LIKE '%kbps%'
      OR LOWER(column_name) LIKE '%mbps%'
      THEN 'THROUGHPUT'
    WHEN LOWER(column_name) LIKE '%packet%'
      OR LOWER(column_name) LIKE '%loss%'
      OR LOWER(column_name) LIKE '%drop%'
      THEN 'PACKET_LOSS'
    WHEN LOWER(column_name) LIKE '%session%'
      OR LOWER(column_name) LIKE '%success%'
      OR LOWER(column_name) LIKE '%establish%'
      OR LOWER(column_name) LIKE '%setup%'
      OR LOWER(column_name) LIKE '%attach%'
      THEN 'SESSION_SUCCESS'
    WHEN LOWER(column_name) LIKE '%volume%'
      OR LOWER(column_name) LIKE '%traffic%'
      THEN 'TRAFFIC_VOLUME'
    WHEN LOWER(column_name) LIKE '%subscriber%'
      OR LOWER(column_name) LIKE '%count%'
      OR LOWER(column_name) LIKE '%sample%'
      THEN 'COUNT_METRIC'
    WHEN LOWER(column_name) LIKE '%steer%'
      OR LOWER(column_name) LIKE '%prefer%'
      OR LOWER(column_name) LIKE '%direct%'
      THEN 'STEERING'
    ELSE 'OTHER_CANDIDATE'
  END AS kpi_category
FROM `<SOURCE_PROJECT>.<SOURCE_DATASET>.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS`
WHERE table_name = '<SOURCE_TABLE>'
  AND (
    -- Latency keywords
    LOWER(column_name) LIKE '%latency%'
    OR LOWER(column_name) LIKE '%delay%'
    OR LOWER(column_name) LIKE '%rtt%'
    OR LOWER(column_name) LIKE '%round_trip%'
    -- Throughput keywords
    OR LOWER(column_name) LIKE '%throughput%'
    OR LOWER(column_name) LIKE '%bandwidth%'
    OR LOWER(column_name) LIKE '%bitrate%'
    OR LOWER(column_name) LIKE '%speed%'
    OR LOWER(column_name) LIKE '%kbps%'
    OR LOWER(column_name) LIKE '%mbps%'
    -- Packet loss keywords
    OR LOWER(column_name) LIKE '%packet%'
    OR LOWER(column_name) LIKE '%loss%'
    OR LOWER(column_name) LIKE '%drop%'
    -- Session success keywords
    OR LOWER(column_name) LIKE '%session%'
    OR LOWER(column_name) LIKE '%success%'
    OR LOWER(column_name) LIKE '%establish%'
    OR LOWER(column_name) LIKE '%setup%'
    OR LOWER(column_name) LIKE '%attach%'
    -- Volume / count keywords (supporting metrics)
    OR LOWER(column_name) LIKE '%volume%'
    OR LOWER(column_name) LIKE '%traffic%'
    OR LOWER(column_name) LIKE '%subscriber%'
    OR LOWER(column_name) LIKE '%count%'
    OR LOWER(column_name) LIKE '%sample%'
    -- Steering keywords
    OR LOWER(column_name) LIKE '%steer%'
    OR LOWER(column_name) LIKE '%prefer%'
    OR LOWER(column_name) LIKE '%direct%'
  )
ORDER BY kpi_category, column_name;
