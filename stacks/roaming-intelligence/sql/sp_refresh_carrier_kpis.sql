-- sp_refresh_carrier_kpis.sql
-- Step 1: Incremental load from raw source + KPI normalization
-- Reads: wb-tps-ia1-workbench-pr-641ea1.user_plane_staging.stg_user_plane
-- Writes: roaming_intelligence.stg_carrier_kpi_daily
-- Pattern: DELETE + INSERT on target partition (idempotent)
-- Observability: logs start/end to stg_data_quality_log
-- Implemented in: Story 2.1

CREATE OR REPLACE PROCEDURE `roaming_intelligence.sp_refresh_carrier_kpis`(IN target_date DATE)
BEGIN
  DECLARE v_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE v_row_count INT64 DEFAULT 0;
  DECLARE v_ref_count INT64 DEFAULT 0;

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
    (target_date, 'sp_refresh_carrier_kpis', v_start_time, NULL, NULL, 'running', 'Started KPI refresh');

  -- ────────────────────────────────────────────────────────────────────
  -- Guard: ref_mcc_country must not be empty
  -- ────────────────────────────────────────────────────────────────────
  SET v_ref_count = (SELECT COUNT(*) FROM `roaming_intelligence.ref_mcc_country`);
  IF v_ref_count = 0 THEN
    INSERT INTO `roaming_intelligence.stg_data_quality_log`
      (refresh_date, step_name, start_time, end_time, row_count, status, message)
    VALUES
      (target_date, 'sp_refresh_carrier_kpis', v_start_time, CURRENT_TIMESTAMP(),
       0, 'failed', 'ref_mcc_country table is empty — country derivation will fail');
    RAISE USING MESSAGE = 'ref_mcc_country table is empty — cannot derive country from MCC';
  END IF;

  -- ────────────────────────────────────────────────────────────────────
  -- Steps 2-5 wrapped in exception handler to guarantee completion log
  -- ────────────────────────────────────────────────────────────────────
  BEGIN

    -- ──────────────────────────────────────────────────────────────────
    -- Step 2: Delete existing partition data (idempotent)
    -- ──────────────────────────────────────────────────────────────────
    DELETE FROM `roaming_intelligence.stg_carrier_kpi_daily`
    WHERE refresh_date = target_date;

    -- ──────────────────────────────────────────────────────────────────
    -- Step 3: Insert aggregated KPIs from source joined to ref_mcc_country
    -- ──────────────────────────────────────────────────────────────────
    INSERT INTO `roaming_intelligence.stg_carrier_kpi_daily`
      (refresh_date, country_name, country_code, carrier_name, mcc, mnc, is_steered,
       kpi_latency_ms, kpi_throughput_kbps, kpi_packet_loss_pct, kpi_session_success_pct,
       norm_latency, norm_throughput, norm_packet_loss, norm_session_success,
       traffic_volume_mb, session_count, subscriber_count)
    WITH parsed_source AS (
      SELECT
        call_dt,
        -- Dynamic mcc_mnc parsing: handle both "310-260" and "310260" formats
        CASE
          WHEN CONTAINS_SUBSTR(mcc_mnc, '-') THEN SPLIT(mcc_mnc, '-')[OFFSET(0)]
          ELSE SUBSTR(mcc_mnc, 1, 3)
        END AS mcc,
        CASE
          WHEN CONTAINS_SUBSTR(mcc_mnc, '-') THEN SPLIT(mcc_mnc, '-')[OFFSET(1)]
          ELSE SUBSTR(mcc_mnc, 4)
        END AS mnc,
        visitd_plmn_nm,
        subscr_id,
        usr_pln_tot_rtt_usec_ms,
        usr_pln_dnld_effctv_bytes_cnt,
        usr_pln_dnld_actv_mlsec,
        usr_pln_dnld_rtrnsmttd_pkts_cnt,
        usr_pln_dnld_pkts_cnt,
        usr_pln_success_cnt,
        usr_pln_rqst_cnt,
        usr_pln_upld_effctv_bytes_cnt
      FROM `wb-tps-ia1-workbench-pr-641ea1.user_plane_staging.stg_user_plane`
      WHERE call_dt = target_date
    )
    SELECT
      ps.call_dt AS refresh_date,
      ref.country_name,
      ref.country_code,
      ps.visitd_plmn_nm AS carrier_name,
      ps.mcc,
      ps.mnc,
      FALSE AS is_steered,
      -- Raw KPIs (aggregated from session-level to country/carrier/day)
      AVG(ps.usr_pln_tot_rtt_usec_ms) AS kpi_latency_ms,
      SAFE_DIVIDE(
        SUM(ps.usr_pln_dnld_effctv_bytes_cnt),
        SUM(ps.usr_pln_dnld_actv_mlsec)
      ) * 8 AS kpi_throughput_kbps,
      SAFE_DIVIDE(
        SUM(ps.usr_pln_dnld_rtrnsmttd_pkts_cnt),
        SUM(ps.usr_pln_dnld_pkts_cnt)
      ) * 100 AS kpi_packet_loss_pct,
      SAFE_DIVIDE(
        SUM(ps.usr_pln_success_cnt),
        SUM(ps.usr_pln_rqst_cnt)
      ) * 100 AS kpi_session_success_pct,
      -- Normalized KPIs set to NULL; computed in step 4
      NULL AS norm_latency,
      NULL AS norm_throughput,
      NULL AS norm_packet_loss,
      NULL AS norm_session_success,
      -- Usage metrics
      SUM(
        COALESCE(ps.usr_pln_dnld_effctv_bytes_cnt, 0)
        + COALESCE(ps.usr_pln_upld_effctv_bytes_cnt, 0)
      ) / (1024.0 * 1024.0) AS traffic_volume_mb,
      SUM(ps.usr_pln_rqst_cnt) AS session_count,
      COUNT(DISTINCT ps.subscr_id) AS subscriber_count
    FROM parsed_source ps
    LEFT JOIN `roaming_intelligence.ref_mcc_country` ref
      ON ps.mcc = ref.mcc
    GROUP BY
      ps.call_dt,
      ref.country_name,
      ref.country_code,
      ps.visitd_plmn_nm,
      ps.mcc,
      ps.mnc;

    -- Capture row count from the INSERT
    SET v_row_count = @@row_count;

    -- ──────────────────────────────────────────────────────────────────
    -- Step 4: Normalize KPIs (min-max over trailing 90-day window)
    -- Cold-start safe: includes current day in the window.
    -- Inverted for latency and packet loss (lower raw = higher score).
    -- When min = max, returns 50 (midpoint). Clamped to [0, 100].
    -- ──────────────────────────────────────────────────────────────────
    UPDATE `roaming_intelligence.stg_carrier_kpi_daily` AS t
    SET
      t.norm_latency = CASE
        WHEN t.kpi_latency_ms IS NULL THEN NULL
        WHEN bounds.max_latency = bounds.min_latency THEN 50.0
        ELSE GREATEST(0.0, LEAST(100.0,
          (1.0 - SAFE_DIVIDE(t.kpi_latency_ms - bounds.min_latency, bounds.max_latency - bounds.min_latency)) * 100.0
        ))
      END,
      t.norm_throughput = CASE
        WHEN t.kpi_throughput_kbps IS NULL THEN NULL
        WHEN bounds.max_throughput = bounds.min_throughput THEN 50.0
        ELSE GREATEST(0.0, LEAST(100.0,
          SAFE_DIVIDE(t.kpi_throughput_kbps - bounds.min_throughput, bounds.max_throughput - bounds.min_throughput) * 100.0
        ))
      END,
      t.norm_packet_loss = CASE
        WHEN t.kpi_packet_loss_pct IS NULL THEN NULL
        WHEN bounds.max_packet_loss = bounds.min_packet_loss THEN 50.0
        ELSE GREATEST(0.0, LEAST(100.0,
          (1.0 - SAFE_DIVIDE(t.kpi_packet_loss_pct - bounds.min_packet_loss, bounds.max_packet_loss - bounds.min_packet_loss)) * 100.0
        ))
      END,
      t.norm_session_success = CASE
        WHEN t.kpi_session_success_pct IS NULL THEN NULL
        WHEN bounds.max_session_success = bounds.min_session_success THEN 50.0
        ELSE GREATEST(0.0, LEAST(100.0,
          SAFE_DIVIDE(t.kpi_session_success_pct - bounds.min_session_success, bounds.max_session_success - bounds.min_session_success) * 100.0
        ))
      END
    FROM (
      SELECT
        MIN(kpi_latency_ms) AS min_latency,
        MAX(kpi_latency_ms) AS max_latency,
        MIN(kpi_throughput_kbps) AS min_throughput,
        MAX(kpi_throughput_kbps) AS max_throughput,
        MIN(kpi_packet_loss_pct) AS min_packet_loss,
        MAX(kpi_packet_loss_pct) AS max_packet_loss,
        MIN(kpi_session_success_pct) AS min_session_success,
        MAX(kpi_session_success_pct) AS max_session_success
      FROM `roaming_intelligence.stg_carrier_kpi_daily`
      WHERE refresh_date BETWEEN DATE_SUB(target_date, INTERVAL 90 DAY) AND target_date
    ) AS bounds
    WHERE t.refresh_date = target_date;

    -- ──────────────────────────────────────────────────────────────────
    -- Step 5: Log completion
    -- ──────────────────────────────────────────────────────────────────
    INSERT INTO `roaming_intelligence.stg_data_quality_log`
      (refresh_date, step_name, start_time, end_time, row_count, status, message)
    VALUES
      (target_date, 'sp_refresh_carrier_kpis', v_start_time, CURRENT_TIMESTAMP(),
       v_row_count, 'success',
       CONCAT('Refreshed ', CAST(v_row_count AS STRING), ' carrier-KPI rows'));

  EXCEPTION WHEN ERROR THEN
    -- Log failure so the "running" entry is not orphaned
    INSERT INTO `roaming_intelligence.stg_data_quality_log`
      (refresh_date, step_name, start_time, end_time, row_count, status, message)
    VALUES
      (target_date, 'sp_refresh_carrier_kpis', v_start_time, CURRENT_TIMESTAMP(),
       v_row_count, 'failed', @@error.message);
    RAISE;
  END;

END;
