-- sp_compute_composite_scores.sql
-- Step 2: Equal-weight composite scoring from normalized KPIs
-- Reads: roaming_intelligence.stg_carrier_kpi_daily
-- Writes: roaming_intelligence.stg_carrier_composite_daily
-- Pattern: DELETE + INSERT on target partition (idempotent)
-- Observability: logs start/end to stg_data_quality_log
-- Implemented in: Story 2.2

CREATE OR REPLACE PROCEDURE `roaming_intelligence.sp_compute_composite_scores`(IN target_date DATE)
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
    (target_date, 'sp_compute_composite_scores', v_start_time, NULL, NULL, 'running', 'Started composite scoring');

  -- ────────────────────────────────────────────────────────────────────
  -- Steps 2-4 wrapped in exception handler
  -- ────────────────────────────────────────────────────────────────────
  BEGIN

    -- ──────────────────────────────────────────────────────────────────
    -- Step 2: Delete existing partition data (idempotent)
    -- ──────────────────────────────────────────────────────────────────
    DELETE FROM `roaming_intelligence.stg_carrier_composite_daily`
    WHERE refresh_date = target_date;

    -- ──────────────────────────────────────────────────────────────────
    -- Step 3: Insert composite scores
    -- Equal-weight average of available (non-NULL) normalized KPIs.
    -- If all 4 norm_* are NULL, composite_quality_score = NULL.
    -- ──────────────────────────────────────────────────────────────────
    INSERT INTO `roaming_intelligence.stg_carrier_composite_daily`
      (refresh_date, country_name, country_code, carrier_name, mcc, mnc,
       composite_quality_score)
    SELECT
      refresh_date,
      country_name,
      country_code,
      carrier_name,
      mcc,
      mnc,
      SAFE_DIVIDE(
        COALESCE(norm_latency, 0) + COALESCE(norm_throughput, 0)
        + COALESCE(norm_packet_loss, 0) + COALESCE(norm_session_success, 0),
        (IF(norm_latency IS NOT NULL, 1, 0) + IF(norm_throughput IS NOT NULL, 1, 0)
         + IF(norm_packet_loss IS NOT NULL, 1, 0) + IF(norm_session_success IS NOT NULL, 1, 0))
      ) AS composite_quality_score
    FROM `roaming_intelligence.stg_carrier_kpi_daily`
    WHERE refresh_date = target_date;

    SET v_row_count = @@row_count;

    -- ──────────────────────────────────────────────────────────────────
    -- Step 4: Log completion
    -- ──────────────────────────────────────────────────────────────────
    INSERT INTO `roaming_intelligence.stg_data_quality_log`
      (refresh_date, step_name, start_time, end_time, row_count, status, message)
    VALUES
      (target_date, 'sp_compute_composite_scores', v_start_time, CURRENT_TIMESTAMP(),
       v_row_count, 'success',
       CONCAT('Computed ', CAST(v_row_count AS STRING), ' composite scores'));

  EXCEPTION WHEN ERROR THEN
    INSERT INTO `roaming_intelligence.stg_data_quality_log`
      (refresh_date, step_name, start_time, end_time, row_count, status, message)
    VALUES
      (target_date, 'sp_compute_composite_scores', v_start_time, CURRENT_TIMESTAMP(),
       v_row_count, 'failed', @@error.message);
    RAISE;
  END;

END;
