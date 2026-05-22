-- sp_detect_degradation.sql
-- Step 3: Direction-aware 7-day trailing window degradation detection
-- Reads: roaming_intelligence.stg_carrier_kpi_daily
-- Writes: roaming_intelligence.stg_carrier_degradation_daily
-- Pattern: DELETE + INSERT on target partition (idempotent)
-- Observability: logs start/end to stg_data_quality_log
-- Implemented in: Story 2.3

CREATE OR REPLACE PROCEDURE `roaming_intelligence.sp_detect_degradation`(IN target_date DATE)
BEGIN
  DECLARE v_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE v_row_count INT64 DEFAULT 0;

  -- ────────────────────────────────────────────────────────────────────
  -- Input validation
  -- ────────────────────────────────────────────────────────────────────
  IF target_date IS NULL THEN
    RAISE USING MESSAGE = 'target_date must not be NULL';
  END IF;

  -- ────────────────────────────────────────────────────────────────────
  -- Step 1: Log start
  -- ────────────────────────────────────────────────────────────────────
  INSERT INTO `roaming_intelligence.stg_data_quality_log`
    (refresh_date, step_name, start_time, end_time, row_count, status, message)
  VALUES
    (target_date, 'sp_detect_degradation', v_start_time, NULL, NULL, 'running', 'Started degradation detection');

  -- ────────────────────────────────────────────────────────────────────
  -- Steps 2-4 wrapped in exception handler
  -- ────────────────────────────────────────────────────────────────────
  BEGIN

    -- ──────────────────────────────────────────────────────────────────
    -- Step 2: Delete existing partition data (idempotent)
    -- ──────────────────────────────────────────────────────────────────
    DELETE FROM `roaming_intelligence.stg_carrier_degradation_daily`
    WHERE refresh_date = target_date;

    -- ──────────────────────────────────────────────────────────────────
    -- Step 3: Insert degradation flags
    -- Compare current day KPIs against 7-day trailing average.
    -- Direction-aware: latency/packet_loss degrade upward (>1.2x),
    -- throughput/session_success degrade downward (<0.8x).
    -- Default threshold: 20%.
    -- ──────────────────────────────────────────────────────────────────
    INSERT INTO `roaming_intelligence.stg_carrier_degradation_daily`
      (refresh_date, country_name, country_code, carrier_name, mcc, mnc,
       degradation_flag, degradation_details)
    WITH current_day AS (
      SELECT
        refresh_date, country_name, country_code, carrier_name, mcc, mnc,
        kpi_latency_ms, kpi_throughput_kbps,
        kpi_packet_loss_pct, kpi_session_success_pct
      FROM `roaming_intelligence.stg_carrier_kpi_daily`
      WHERE refresh_date = target_date
    ),
    trailing_avg AS (
      SELECT
        country_code, carrier_name, mcc, mnc,
        AVG(kpi_latency_ms) AS avg_latency,
        AVG(kpi_throughput_kbps) AS avg_throughput,
        AVG(kpi_packet_loss_pct) AS avg_packet_loss,
        AVG(kpi_session_success_pct) AS avg_session_success,
        COUNT(*) AS trailing_days
      FROM `roaming_intelligence.stg_carrier_kpi_daily`
      WHERE refresh_date BETWEEN DATE_SUB(target_date, INTERVAL 7 DAY) AND DATE_SUB(target_date, INTERVAL 1 DAY)
      GROUP BY country_code, carrier_name, mcc, mnc
    ),
    comparison AS (
      SELECT
        c.refresh_date, c.country_name, c.country_code, c.carrier_name, c.mcc, c.mnc,
        -- Latency: higher is worse → degraded if current > avg * 1.2
        (c.kpi_latency_ms IS NOT NULL AND t.avg_latency IS NOT NULL
         AND c.kpi_latency_ms > t.avg_latency * 1.2) AS latency_degraded,
        -- Throughput: lower is worse → degraded if current < avg * 0.8
        (c.kpi_throughput_kbps IS NOT NULL AND t.avg_throughput IS NOT NULL
         AND c.kpi_throughput_kbps < t.avg_throughput * 0.8) AS throughput_degraded,
        -- Packet loss: higher is worse → degraded if current > avg * 1.2
        (c.kpi_packet_loss_pct IS NOT NULL AND t.avg_packet_loss IS NOT NULL
         AND c.kpi_packet_loss_pct > t.avg_packet_loss * 1.2) AS packet_loss_degraded,
        -- Session success: lower is worse → degraded if current < avg * 0.8
        (c.kpi_session_success_pct IS NOT NULL AND t.avg_session_success IS NOT NULL
         AND c.kpi_session_success_pct < t.avg_session_success * 0.8) AS session_success_degraded,
        -- Pass through values for JSON details
        c.kpi_latency_ms, t.avg_latency, t.trailing_days,
        c.kpi_throughput_kbps, t.avg_throughput,
        c.kpi_packet_loss_pct, t.avg_packet_loss,
        c.kpi_session_success_pct, t.avg_session_success
      FROM current_day c
      LEFT JOIN trailing_avg t
        ON c.country_code IS NOT DISTINCT FROM t.country_code
        AND c.carrier_name = t.carrier_name
        AND c.mcc IS NOT DISTINCT FROM t.mcc
        AND c.mnc IS NOT DISTINCT FROM t.mnc
    )
    SELECT
      refresh_date, country_name, country_code, carrier_name, mcc, mnc,
      -- Flag TRUE if any KPI degraded and trailing data exists
      (trailing_days IS NOT NULL
       AND (latency_degraded OR throughput_degraded
            OR packet_loss_degraded OR session_success_degraded)) AS degradation_flag,
      TO_JSON_STRING(STRUCT(
        STRUCT(
          kpi_latency_ms AS current,
          avg_latency AS avg_7d,
          latency_degraded AS degraded,
          'higher_is_worse' AS direction
        ) AS latency,
        STRUCT(
          kpi_throughput_kbps AS current,
          avg_throughput AS avg_7d,
          throughput_degraded AS degraded,
          'lower_is_worse' AS direction
        ) AS throughput,
        STRUCT(
          kpi_packet_loss_pct AS current,
          avg_packet_loss AS avg_7d,
          packet_loss_degraded AS degraded,
          'higher_is_worse' AS direction
        ) AS packet_loss,
        STRUCT(
          kpi_session_success_pct AS current,
          avg_session_success AS avg_7d,
          session_success_degraded AS degraded,
          'lower_is_worse' AS direction
        ) AS session_success,
        0.20 AS threshold,
        trailing_days
      )) AS degradation_details
    FROM comparison;

    SET v_row_count = @@row_count;

    -- ──────────────────────────────────────────────────────────────────
    -- Step 4: Log completion
    -- ──────────────────────────────────────────────────────────────────
    INSERT INTO `roaming_intelligence.stg_data_quality_log`
      (refresh_date, step_name, start_time, end_time, row_count, status, message)
    VALUES
      (target_date, 'sp_detect_degradation', v_start_time, CURRENT_TIMESTAMP(),
       v_row_count, 'success',
       CONCAT('Detected degradation for ', CAST(v_row_count AS STRING), ' carriers'));

  EXCEPTION WHEN ERROR THEN
    INSERT INTO `roaming_intelligence.stg_data_quality_log`
      (refresh_date, step_name, start_time, end_time, row_count, status, message)
    VALUES
      (target_date, 'sp_detect_degradation', v_start_time, CURRENT_TIMESTAMP(),
       v_row_count, 'failed', @@error.message);
    RAISE;
  END;

END;
