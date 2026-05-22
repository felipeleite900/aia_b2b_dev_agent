# Epic 2 Context: Daily Quality Intelligence Pipeline

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Build all SQL data transformation logic that turns raw Netscout session-level probe data into curated, queryable analytics tables. This covers KPI normalization, composite quality scoring, degradation detection, data quality validation, and the curated output layer. After this epic, the `crt_mv_*` views fulfill the data contract that the report generator (Epic 3) consumes, and tables can be queried directly for carrier steering decisions.

## Stories

- Story 2.1: Build KPI Refresh Stored Procedure
- Story 2.2: Build Composite Quality Score Stored Procedure
- Story 2.3: Build Degradation Detection Stored Procedure
- Story 2.4: Build Data Quality Checks Stored Procedure
- Story 2.5: Build Curated Output Layer
- Story 2.6: Build Historical Backfill Procedure

## Requirements & Constraints

Pipeline stored procs must deliver these capabilities:

- **Daily KPI refresh (FR-1, FR-2):** Incremental load of new/changed data per `refresh_date`. Full backfill mode for initial 90-day load and recovery.
- **KPI computation:** Four KPIs derived by aggregation -- `kpi_latency_ms`, `kpi_throughput_kbps`, `kpi_packet_loss_pct`, `kpi_session_success_pct` -- plus normalized 0-100 equivalents (`norm_*`). Latency and packet loss are inverted (lower raw = higher score).
- **Composite scoring (FR-5, FR-9):** `composite_quality_score` as equal-weight average of available normalized KPIs (0-100 FLOAT64). Gracefully handle missing KPIs.
- **Usage metrics (FR-7):** `traffic_volume_mb`, `session_count`, `subscriber_count` aggregated per carrier/country/day.
- **Degradation detection (FR-12):** Direction-aware 7-day trailing window comparison. Default threshold 20%. Output `degradation_flag` (BOOL) and `degradation_details` (JSON).
- **Data quality checks (FR-13, FR-14, FR-15):** Freshness within 36 hours, coverage diff vs. prior refresh, volume anomaly flagging at 50% of 14-day rolling average.
- **Curated output (FR-11):** `crt_mv_*` views join staging tables into the report contract. Trend data covers 90 days. Carriers with <1% traffic share tagged for "Other" grouping.
- **Observability (FR-3):** Every stored proc logs to `stg_data_quality_log` with step name, start/end time, row count, status.
- **Idempotency:** All procs use DELETE + INSERT on the `refresh_date` partition. Never MERGE.
- **Data residency:** All processing in `northamerica-northeast1`.
- **No PII in output:** `subscr_id` must be aggregated away (COUNT DISTINCT only), never stored in `stg_*` or `crt_*` tables.

Success metric: data quality checks pass on 95%+ of daily refreshes without manual intervention (SM-4).

## Technical Decisions

**Source table:** `wb-tps-ia1-workbench-pr-641ea1.user_plane_staging.stg_user_plane` (workbench table, NOT `ent_*` Datahub). Partitioned by `call_dt` (DATE). This is the table all Epic 2 stored procs query as their raw source.

**Source grain is per-subscriber, per-session, per-timestamp.** All procs must aggregate to country/carrier/day. GROUP BY `call_dt`, derived country (from `mcc_mnc`), and `visitd_plmn_nm`.

**Key source-to-target transforms (from schema mapping):**
- Country derived from `mcc_mnc` via MCC lookup to a static MCC-to-country reference table. The `mcc_mnc` delimiter format needs verification (could be `"310-260"` or `"310260"`).
- Carrier name: `visitd_plmn_nm` (direct).
- Latency: `AVG(usr_pln_tot_rtt_usec_ms)` -- already in ms.
- Throughput: `SUM(usr_pln_dnld_effctv_bytes_cnt) / NULLIF(SUM(usr_pln_dnld_actv_mlsec), 0) * 8` -- bytes/ms to kbps.
- Packet loss: `SUM(usr_pln_dnld_rtrnsmttd_pkts_cnt) / NULLIF(SUM(usr_pln_dnld_pkts_cnt), 0) * 100`.
- Session success: `SUM(usr_pln_success_cnt) / NULLIF(SUM(usr_pln_rqst_cnt), 0) * 100`.
- Traffic volume: `SUM(dnld + upld bytes) / (1024 * 1024)` -- bytes to MB.
- Subscriber count: `COUNT(DISTINCT subscr_id)` -- PII column, aggregate only.
- `is_steered`: not in source; default FALSE, manually maintained via config/lookup.

**`roaming_type` column:** May need filtering to international roaming only -- values not yet confirmed.

**Naming conventions:** Layer prefixes (`stg_`, `crt_`), proc prefix `sp_`, column prefixes `kpi_`/`norm_`, all snake_case. Dataset: `roaming_intelligence`.

**Normalization method:** Not prescribed yet. Recommended: min-max over trailing 90-day window per KPI, recalculated daily. Define during Story 2.1/2.2 implementation.

**SQL files live in:** `stacks/roaming-intelligence/sql/` (backfill in `sql/backfill/`).

**Pipeline step order enforced by Cloud Workflows (Epic 4):** refresh -> composite -> degradation -> quality checks -> curate. Within Epic 2, procs are built and tested independently.

## Cross-Story Dependencies

- **Epic 1 -> Epic 2:** Stories 2.1-2.6 require BigQuery dataset and table schemas from Story 1.4, and workbench access from Story 1.3 (reworked for workbench pattern per schema mapping findings).
- **Story 2.1 -> 2.2:** Composite scoring reads from `stg_carrier_kpi_daily` produced by 2.1.
- **Story 2.1 -> 2.3:** Degradation detection reads from `stg_carrier_kpi_daily` (needs 7+ days of history).
- **Stories 2.1-2.3 -> 2.4:** Quality checks run after the first three pipeline steps complete.
- **Stories 2.1-2.4 -> 2.5:** Curated output layer joins all staging tables.
- **Stories 2.1-2.5 -> 2.6:** Backfill calls the full pipeline chain for each date in a range.
- **Epic 2 -> Epic 3:** The `crt_mv_*` views are the sole data contract for the Python report generator. Python never reads `stg_*` tables.
- **Epic 2 -> Epic 4:** Cloud Workflows wires stored procs into the automated step chain.
