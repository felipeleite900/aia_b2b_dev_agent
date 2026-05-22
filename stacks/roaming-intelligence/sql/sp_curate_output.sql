-- sp_curate_output.sql
-- Step 5: Create/replace curated views from staging tables
-- Reads: roaming_intelligence.stg_carrier_kpi_daily, stg_carrier_composite_daily, stg_carrier_degradation_daily
-- Writes: roaming_intelligence.crt_mv_* views (CREATE OR REPLACE VIEW)
-- Pattern: Idempotent DDL — views are query definitions, always return fresh data
-- Observability: logs start/end to stg_data_quality_log
-- Implemented in: Story 2.5

CREATE OR REPLACE PROCEDURE `roaming_intelligence.sp_curate_output`(IN target_date DATE)
BEGIN
  DECLARE v_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE v_view_count INT64 DEFAULT 0;

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
    (target_date, 'sp_curate_output', v_start_time, NULL, NULL, 'running', 'Started curated view refresh');

  -- ────────────────────────────────────────────────────────────────────
  -- Steps 2-5 wrapped in exception handler
  -- ────────────────────────────────────────────────────────────────────
  BEGIN

    -- ──────────────────────────────────────────────────────────────────
    -- View 1: crt_mv_carrier_quality_summary
    -- Latest snapshot per carrier: KPIs + composite score + degradation
    -- + traffic share with <1% minor carrier flag.
    -- ──────────────────────────────────────────────────────────────────
    CREATE OR REPLACE VIEW `roaming_intelligence.crt_mv_carrier_quality_summary` AS
    WITH latest AS (
      SELECT MAX(refresh_date) AS max_date
      FROM `roaming_intelligence.stg_carrier_kpi_daily`
    ),
    total_traffic AS (
      SELECT SUM(traffic_volume_mb) AS total_mb
      FROM `roaming_intelligence.stg_carrier_kpi_daily`
      WHERE refresh_date = (SELECT max_date FROM latest)
    )
    SELECT
      k.refresh_date,
      k.country_name, k.country_code, k.carrier_name, k.mcc, k.mnc, k.is_steered,
      k.kpi_latency_ms, k.kpi_throughput_kbps, k.kpi_packet_loss_pct, k.kpi_session_success_pct,
      k.norm_latency, k.norm_throughput, k.norm_packet_loss, k.norm_session_success,
      c.composite_quality_score,
      d.degradation_flag, d.degradation_details,
      k.traffic_volume_mb, k.session_count, k.subscriber_count,
      SAFE_DIVIDE(k.traffic_volume_mb, tt.total_mb) * 100 AS traffic_share_pct,
      SAFE_DIVIDE(k.traffic_volume_mb, tt.total_mb) < 0.01 AS is_minor_carrier
    FROM `roaming_intelligence.stg_carrier_kpi_daily` k
    CROSS JOIN latest
    CROSS JOIN total_traffic tt
    LEFT JOIN `roaming_intelligence.stg_carrier_composite_daily` c
      ON k.refresh_date = c.refresh_date
      AND k.carrier_name = c.carrier_name
      AND k.mcc IS NOT DISTINCT FROM c.mcc
      AND k.mnc IS NOT DISTINCT FROM c.mnc
    LEFT JOIN `roaming_intelligence.stg_carrier_degradation_daily` d
      ON k.refresh_date = d.refresh_date
      AND k.carrier_name = d.carrier_name
      AND k.mcc IS NOT DISTINCT FROM d.mcc
      AND k.mnc IS NOT DISTINCT FROM d.mnc
    WHERE k.refresh_date = latest.max_date;

    SET v_view_count = v_view_count + 1;

    -- ──────────────────────────────────────────────────────────────────
    -- View 2: crt_mv_country_quality_summary
    -- Country-level aggregation: avg scores, carrier counts, totals.
    -- ──────────────────────────────────────────────────────────────────
    CREATE OR REPLACE VIEW `roaming_intelligence.crt_mv_country_quality_summary` AS
    WITH latest AS (
      SELECT MAX(refresh_date) AS max_date
      FROM `roaming_intelligence.stg_carrier_kpi_daily`
    )
    SELECT
      k.refresh_date,
      k.country_name, k.country_code,
      COUNT(*) AS carrier_count,
      AVG(c.composite_quality_score) AS avg_composite_score,
      SUM(IF(d.degradation_flag, 1, 0)) AS degraded_carrier_count,
      AVG(k.kpi_latency_ms) AS avg_latency_ms,
      AVG(k.kpi_throughput_kbps) AS avg_throughput_kbps,
      AVG(k.kpi_packet_loss_pct) AS avg_packet_loss_pct,
      AVG(k.kpi_session_success_pct) AS avg_session_success_pct,
      SUM(k.traffic_volume_mb) AS total_traffic_mb,
      SUM(k.session_count) AS total_sessions,
      SUM(k.subscriber_count) AS total_subscribers
    FROM `roaming_intelligence.stg_carrier_kpi_daily` k
    CROSS JOIN latest
    LEFT JOIN `roaming_intelligence.stg_carrier_composite_daily` c
      ON k.refresh_date = c.refresh_date
      AND k.carrier_name = c.carrier_name
      AND k.mcc IS NOT DISTINCT FROM c.mcc
      AND k.mnc IS NOT DISTINCT FROM c.mnc
    LEFT JOIN `roaming_intelligence.stg_carrier_degradation_daily` d
      ON k.refresh_date = d.refresh_date
      AND k.carrier_name = d.carrier_name
      AND k.mcc IS NOT DISTINCT FROM d.mcc
      AND k.mnc IS NOT DISTINCT FROM d.mnc
    WHERE k.refresh_date = latest.max_date
    GROUP BY k.refresh_date, k.country_name, k.country_code;

    SET v_view_count = v_view_count + 1;

    -- ──────────────────────────────────────────────────────────────────
    -- View 3: crt_mv_carrier_quality_trend
    -- 90-day history per carrier for trend charts.
    -- ──────────────────────────────────────────────────────────────────
    CREATE OR REPLACE VIEW `roaming_intelligence.crt_mv_carrier_quality_trend` AS
    SELECT
      k.refresh_date,
      k.country_name, k.country_code, k.carrier_name, k.mcc, k.mnc,
      k.kpi_latency_ms, k.kpi_throughput_kbps, k.kpi_packet_loss_pct, k.kpi_session_success_pct,
      k.norm_latency, k.norm_throughput, k.norm_packet_loss, k.norm_session_success,
      c.composite_quality_score,
      d.degradation_flag
    FROM `roaming_intelligence.stg_carrier_kpi_daily` k
    LEFT JOIN `roaming_intelligence.stg_carrier_composite_daily` c
      ON k.refresh_date = c.refresh_date
      AND k.carrier_name = c.carrier_name
      AND k.mcc IS NOT DISTINCT FROM c.mcc
      AND k.mnc IS NOT DISTINCT FROM c.mnc
    LEFT JOIN `roaming_intelligence.stg_carrier_degradation_daily` d
      ON k.refresh_date = d.refresh_date
      AND k.carrier_name = d.carrier_name
      AND k.mcc IS NOT DISTINCT FROM d.mcc
      AND k.mnc IS NOT DISTINCT FROM d.mnc
    WHERE k.refresh_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY);

    SET v_view_count = v_view_count + 1;

    -- ──────────────────────────────────────────────────────────────────
    -- View 4: crt_mv_carrier_usage_summary
    -- Latest usage metrics per carrier with traffic share and minor flag.
    -- ──────────────────────────────────────────────────────────────────
    CREATE OR REPLACE VIEW `roaming_intelligence.crt_mv_carrier_usage_summary` AS
    WITH latest AS (
      SELECT MAX(refresh_date) AS max_date
      FROM `roaming_intelligence.stg_carrier_kpi_daily`
    ),
    total_traffic AS (
      SELECT SUM(traffic_volume_mb) AS total_mb
      FROM `roaming_intelligence.stg_carrier_kpi_daily`
      WHERE refresh_date = (SELECT max_date FROM latest)
    )
    SELECT
      k.refresh_date,
      k.country_name, k.country_code, k.carrier_name, k.mcc, k.mnc, k.is_steered,
      k.traffic_volume_mb, k.session_count, k.subscriber_count,
      SAFE_DIVIDE(k.traffic_volume_mb, tt.total_mb) * 100 AS traffic_share_pct,
      SAFE_DIVIDE(k.traffic_volume_mb, tt.total_mb) < 0.01 AS is_minor_carrier
    FROM `roaming_intelligence.stg_carrier_kpi_daily` k
    CROSS JOIN latest
    CROSS JOIN total_traffic tt
    WHERE k.refresh_date = latest.max_date;

    SET v_view_count = v_view_count + 1;

    -- ──────────────────────────────────────────────────────────────────
    -- Step 5: Log completion
    -- ──────────────────────────────────────────────────────────────────
    INSERT INTO `roaming_intelligence.stg_data_quality_log`
      (refresh_date, step_name, start_time, end_time, row_count, status, message)
    VALUES
      (target_date, 'sp_curate_output', v_start_time, CURRENT_TIMESTAMP(),
       v_view_count, 'success',
       CONCAT('Created/replaced ', CAST(v_view_count AS STRING), ' curated views'));

  EXCEPTION WHEN ERROR THEN
    INSERT INTO `roaming_intelligence.stg_data_quality_log`
      (refresh_date, step_name, start_time, end_time, row_count, status, message)
    VALUES
      (target_date, 'sp_curate_output', v_start_time, CURRENT_TIMESTAMP(),
       v_view_count, 'failed', @@error.message);
    RAISE;
  END;

END;
