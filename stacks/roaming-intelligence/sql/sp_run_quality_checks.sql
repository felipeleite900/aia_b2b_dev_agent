-- sp_run_quality_checks.sql
-- Step 4: Data quality checks — freshness, coverage, volume anomaly
-- Reads: roaming_intelligence.stg_carrier_kpi_daily
-- Writes: roaming_intelligence.stg_data_quality_log (check results only)
-- Pattern: DELETE check entries + INSERT (idempotent)
-- Observability: logs start/end to stg_data_quality_log
-- Implemented in: Story 2.4

CREATE OR REPLACE PROCEDURE `roaming_intelligence.sp_run_quality_checks`(IN target_date DATE)
BEGIN
  DECLARE v_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE v_current_count INT64 DEFAULT 0;
  DECLARE v_prior_count INT64 DEFAULT 0;
  DECLARE v_prior_date DATE;
  DECLARE v_current_volume FLOAT64 DEFAULT 0;
  DECLARE v_avg_14d_volume FLOAT64 DEFAULT 0;
  DECLARE v_checks_passed INT64 DEFAULT 0;
  DECLARE v_checks_failed INT64 DEFAULT 0;

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
    (target_date, 'sp_run_quality_checks', v_start_time, NULL, NULL, 'running', 'Started quality checks');

  -- ────────────────────────────────────────────────────────────────────
  -- Steps 2-5 wrapped in exception handler
  -- ────────────────────────────────────────────────────────────────────
  BEGIN

    -- ──────────────────────────────────────────────────────────────────
    -- Step 2: Delete previous check results for this date (idempotent)
    -- Only removes quality-check entries, not other procs' logs
    -- ──────────────────────────────────────────────────────────────────
    DELETE FROM `roaming_intelligence.stg_data_quality_log`
    WHERE refresh_date = target_date
      AND step_name IN ('qc_freshness', 'qc_coverage', 'qc_volume');

    -- ──────────────────────────────────────────────────────────────────
    -- Step 3a: Freshness check (FR-13)
    -- Data for target_date should be within 36 hours of current time.
    -- ──────────────────────────────────────────────────────────────────
    IF TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), TIMESTAMP(target_date), HOUR) <= 36 THEN
      SET v_checks_passed = v_checks_passed + 1;
      INSERT INTO `roaming_intelligence.stg_data_quality_log`
        (refresh_date, step_name, start_time, end_time, row_count, status, message)
      VALUES
        (target_date, 'qc_freshness', v_start_time, CURRENT_TIMESTAMP(), NULL, 'pass',
         CONCAT('Data for ', CAST(target_date AS STRING), ' is within 36h freshness window'));
    ELSE
      SET v_checks_failed = v_checks_failed + 1;
      INSERT INTO `roaming_intelligence.stg_data_quality_log`
        (refresh_date, step_name, start_time, end_time, row_count, status, message)
      VALUES
        (target_date, 'qc_freshness', v_start_time, CURRENT_TIMESTAMP(), NULL, 'fail',
         CONCAT('Data for ', CAST(target_date AS STRING), ' is stale — ',
                CAST(TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), TIMESTAMP(target_date), HOUR) AS STRING),
                'h old, exceeds 36h threshold'));
    END IF;

    -- ──────────────────────────────────────────────────────────────────
    -- Step 3b: Coverage check (FR-14)
    -- Compare carrier count for target_date vs prior refresh.
    -- Flag if current count drops >20% vs prior.
    -- ──────────────────────────────────────────────────────────────────
    SET v_current_count = (
      SELECT COUNT(*) FROM `roaming_intelligence.stg_carrier_kpi_daily`
      WHERE refresh_date = target_date
    );

    SET v_prior_date = (
      SELECT MAX(refresh_date) FROM `roaming_intelligence.stg_carrier_kpi_daily`
      WHERE refresh_date < target_date
    );

    IF v_prior_date IS NOT NULL THEN
      SET v_prior_count = (
        SELECT COUNT(*) FROM `roaming_intelligence.stg_carrier_kpi_daily`
        WHERE refresh_date = v_prior_date
      );
    END IF;

    IF v_prior_date IS NULL OR v_prior_count = 0 THEN
      SET v_checks_passed = v_checks_passed + 1;
      INSERT INTO `roaming_intelligence.stg_data_quality_log`
        (refresh_date, step_name, start_time, end_time, row_count, status, message)
      VALUES
        (target_date, 'qc_coverage', v_start_time, CURRENT_TIMESTAMP(), v_current_count, 'pass',
         CONCAT('No prior refresh to compare — current count: ', CAST(v_current_count AS STRING)));
    ELSEIF v_current_count >= v_prior_count * 0.8 THEN
      SET v_checks_passed = v_checks_passed + 1;
      INSERT INTO `roaming_intelligence.stg_data_quality_log`
        (refresh_date, step_name, start_time, end_time, row_count, status, message)
      VALUES
        (target_date, 'qc_coverage', v_start_time, CURRENT_TIMESTAMP(), v_current_count, 'pass',
         CONCAT('Coverage stable — current: ', CAST(v_current_count AS STRING),
                ', prior (', CAST(v_prior_date AS STRING), '): ', CAST(v_prior_count AS STRING)));
    ELSE
      SET v_checks_failed = v_checks_failed + 1;
      INSERT INTO `roaming_intelligence.stg_data_quality_log`
        (refresh_date, step_name, start_time, end_time, row_count, status, message)
      VALUES
        (target_date, 'qc_coverage', v_start_time, CURRENT_TIMESTAMP(), v_current_count, 'fail',
         CONCAT('Coverage drop — current: ', CAST(v_current_count AS STRING),
                ', prior (', CAST(v_prior_date AS STRING), '): ', CAST(v_prior_count AS STRING),
                ' (', CAST(ROUND(SAFE_DIVIDE(v_current_count, v_prior_count) * 100, 1) AS STRING), '%)'));
    END IF;

    -- ──────────────────────────────────────────────────────────────────
    -- Step 3c: Volume anomaly check (FR-15)
    -- Flag if daily total traffic volume < 50% of 14-day rolling average.
    -- ──────────────────────────────────────────────────────────────────
    SET v_current_volume = (
      SELECT COALESCE(SUM(traffic_volume_mb), 0)
      FROM `roaming_intelligence.stg_carrier_kpi_daily`
      WHERE refresh_date = target_date
    );

    SET v_avg_14d_volume = (
      SELECT AVG(daily_volume) FROM (
        SELECT SUM(traffic_volume_mb) AS daily_volume
        FROM `roaming_intelligence.stg_carrier_kpi_daily`
        WHERE refresh_date BETWEEN DATE_SUB(target_date, INTERVAL 14 DAY) AND DATE_SUB(target_date, INTERVAL 1 DAY)
        GROUP BY refresh_date
      )
    );

    IF v_avg_14d_volume IS NULL OR v_avg_14d_volume = 0 THEN
      SET v_checks_passed = v_checks_passed + 1;
      INSERT INTO `roaming_intelligence.stg_data_quality_log`
        (refresh_date, step_name, start_time, end_time, row_count, status, message)
      VALUES
        (target_date, 'qc_volume', v_start_time, CURRENT_TIMESTAMP(), NULL, 'pass',
         CONCAT('No 14-day baseline to compare — current volume: ',
                CAST(ROUND(v_current_volume, 2) AS STRING), ' MB'));
    ELSEIF v_current_volume >= v_avg_14d_volume * 0.5 THEN
      SET v_checks_passed = v_checks_passed + 1;
      INSERT INTO `roaming_intelligence.stg_data_quality_log`
        (refresh_date, step_name, start_time, end_time, row_count, status, message)
      VALUES
        (target_date, 'qc_volume', v_start_time, CURRENT_TIMESTAMP(), NULL, 'pass',
         CONCAT('Volume normal — current: ', CAST(ROUND(v_current_volume, 2) AS STRING),
                ' MB, 14d avg: ', CAST(ROUND(v_avg_14d_volume, 2) AS STRING), ' MB (',
                CAST(ROUND(SAFE_DIVIDE(v_current_volume, v_avg_14d_volume) * 100, 1) AS STRING), '%)'));
    ELSE
      SET v_checks_failed = v_checks_failed + 1;
      INSERT INTO `roaming_intelligence.stg_data_quality_log`
        (refresh_date, step_name, start_time, end_time, row_count, status, message)
      VALUES
        (target_date, 'qc_volume', v_start_time, CURRENT_TIMESTAMP(), NULL, 'fail',
         CONCAT('Volume anomaly — current: ', CAST(ROUND(v_current_volume, 2) AS STRING),
                ' MB, 14d avg: ', CAST(ROUND(v_avg_14d_volume, 2) AS STRING), ' MB (',
                CAST(ROUND(SAFE_DIVIDE(v_current_volume, v_avg_14d_volume) * 100, 1) AS STRING),
                '%), below 50% threshold'));
    END IF;

    -- ──────────────────────────────────────────────────────────────────
    -- Step 4: Log completion with summary
    -- ──────────────────────────────────────────────────────────────────
    INSERT INTO `roaming_intelligence.stg_data_quality_log`
      (refresh_date, step_name, start_time, end_time, row_count, status, message)
    VALUES
      (target_date, 'sp_run_quality_checks', v_start_time, CURRENT_TIMESTAMP(),
       v_checks_passed + v_checks_failed,
       IF(v_checks_failed = 0, 'success', 'warning'),
       CONCAT(CAST(v_checks_passed AS STRING), '/3 checks passed, ',
              CAST(v_checks_failed AS STRING), '/3 failed'));

  EXCEPTION WHEN ERROR THEN
    INSERT INTO `roaming_intelligence.stg_data_quality_log`
      (refresh_date, step_name, start_time, end_time, row_count, status, message)
    VALUES
      (target_date, 'sp_run_quality_checks', v_start_time, CURRENT_TIMESTAMP(),
       0, 'failed', @@error.message);
    RAISE;
  END;

END;
