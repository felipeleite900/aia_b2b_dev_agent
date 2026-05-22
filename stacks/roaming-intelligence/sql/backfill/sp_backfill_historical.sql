-- sp_backfill_historical.sql
-- One-time or recovery backfill: iterates a date range calling the full
-- pipeline chain (refresh → composite → degradation → quality → curate)
-- for each date in sequence.
-- Reads: wb-tps-ia1-workbench-pr-641ea1.user_plane_staging.stg_user_plane (via sub-procs)
-- Writes: roaming_intelligence.stg_* and crt_mv_* (via sub-procs)
-- Observability: logs overall start/end to stg_data_quality_log
-- Implemented in: Story 2.6

CREATE OR REPLACE PROCEDURE `roaming_intelligence.sp_backfill_historical`(
  IN start_date DATE,
  IN end_date DATE
)
BEGIN
  DECLARE v_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE v_current_date DATE;
  DECLARE v_dates_processed INT64 DEFAULT 0;
  DECLARE v_dates_failed INT64 DEFAULT 0;
  DECLARE v_curate_failed BOOL DEFAULT FALSE;

  -- ────────────────────────────────────────────────────────────────────
  -- Input validation
  -- ────────────────────────────────────────────────────────────────────
  IF start_date IS NULL OR end_date IS NULL THEN
    RAISE USING MESSAGE = 'start_date and end_date must not be NULL';
  END IF;
  IF start_date > end_date THEN
    RAISE USING MESSAGE = 'start_date must be <= end_date';
  END IF;

  -- ────────────────────────────────────────────────────────────────────
  -- Log backfill start
  -- ────────────────────────────────────────────────────────────────────
  INSERT INTO `roaming_intelligence.stg_data_quality_log`
    (refresh_date, step_name, start_time, end_time, row_count, status, message)
  VALUES
    (end_date, 'sp_backfill_historical', v_start_time, NULL, NULL, 'running',
     CONCAT('Backfill started: ', CAST(start_date AS STRING), ' to ', CAST(end_date AS STRING)));

  -- ────────────────────────────────────────────────────────────────────
  -- Iterate each date in range, oldest first
  -- ────────────────────────────────────────────────────────────────────
  SET v_current_date = start_date;

  WHILE v_current_date <= end_date DO

    -- Run the full pipeline chain for this date.
    -- Each sub-proc has its own EXCEPTION handler and logs individually.
    -- If a sub-proc fails, we catch it here, log the date as failed,
    -- and continue to the next date so one bad date doesn't block all.
    BEGIN
      CALL `roaming_intelligence.sp_refresh_carrier_kpis`(v_current_date);
      CALL `roaming_intelligence.sp_compute_composite_scores`(v_current_date);
      CALL `roaming_intelligence.sp_detect_degradation`(v_current_date);
      CALL `roaming_intelligence.sp_run_quality_checks`(v_current_date);
      -- Curate views are CREATE OR REPLACE (idempotent DDL),
      -- only needs to run once after all dates are loaded.
      -- Skip per-date curate call; run once after the loop.
      SET v_dates_processed = v_dates_processed + 1;
    EXCEPTION WHEN ERROR THEN
      SET v_dates_failed = v_dates_failed + 1;
      INSERT INTO `roaming_intelligence.stg_data_quality_log`
        (refresh_date, step_name, start_time, end_time, row_count, status, message)
      VALUES
        (v_current_date, 'sp_backfill_historical', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(),
         0, 'failed',
         CONCAT('Date ', CAST(v_current_date AS STRING), ' failed: ', @@error.message));
    END;

    SET v_current_date = DATE_ADD(v_current_date, INTERVAL 1 DAY);
  END WHILE;

  -- ────────────────────────────────────────────────────────────────────
  -- Run curate once after all dates are loaded
  -- (views use MAX(refresh_date) / CURRENT_DATE(), so one call suffices)
  -- ────────────────────────────────────────────────────────────────────
  BEGIN
    CALL `roaming_intelligence.sp_curate_output`(end_date);
  EXCEPTION WHEN ERROR THEN
    SET v_curate_failed = TRUE;
    INSERT INTO `roaming_intelligence.stg_data_quality_log`
      (refresh_date, step_name, start_time, end_time, row_count, status, message)
    VALUES
      (end_date, 'sp_backfill_historical', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(),
       0, 'warning', CONCAT('Curate step failed: ', @@error.message));
  END;

  -- ────────────────────────────────────────────────────────────────────
  -- Log backfill completion
  -- ────────────────────────────────────────────────────────────────────
  INSERT INTO `roaming_intelligence.stg_data_quality_log`
    (refresh_date, step_name, start_time, end_time, row_count, status, message)
  VALUES
    (end_date, 'sp_backfill_historical', v_start_time, CURRENT_TIMESTAMP(),
     v_dates_processed + v_dates_failed,
     IF(v_dates_failed = 0 AND NOT v_curate_failed, 'success', 'warning'),
     CONCAT('Backfill complete: ', CAST(v_dates_processed AS STRING), ' dates processed, ',
            CAST(v_dates_failed AS STRING), ' failed (',
            CAST(start_date AS STRING), ' to ', CAST(end_date AS STRING), ')'));

END;
