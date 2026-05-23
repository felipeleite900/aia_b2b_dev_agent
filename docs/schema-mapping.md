# Netscout BigQuery Schema Mapping

> Story 1.2 deliverable. This document resolves OQ-1 (schema confirmation blocker) and feeds into Stories 2.1+ (pipeline implementation).

---

## Status

| Field | Value |
|---|---|
| OQ-1 Resolution | **RESOLVED** |
| Validated by | Felipe |
| Validation date | 2026-05-22 |
| Queries used | Manual schema inspection from BigQuery UI |

---

## Source Table

| Field | Value |
|---|---|
| Project | `wb-tps-ia1-workbench-pr-641ea1` |
| Dataset | `user_plane_staging` |
| Table(s) | `stg_user_plane` |
| Access pattern | **Workbench** (not `ent_*` Datahub — rework Story 1.3 for workbench access) |
| Partition column | `call_dt` (DATE) |
| Clustering columns | Unknown — verify in BigQuery |
| Approx total rows | TBD — run COUNT(*) |

---

## Data Grain

| Field | Value |
|---|---|
| Confirmed grain | **Per-subscriber, per-session, per-timestamp** (MUCH finer than country/carrier/day) |
| Grain evidence | Columns include `subscr_id` (INTEGER), `cal_tmstmp_tm` (TIMESTAMP), `call_time` (TIME), `direction` (STRING) |
| Duplicate groups found | N/A — grain is finer by design |
| Max rows per group | Many rows per carrier/day (one per subscriber session) |
| Additional dimensions | `subscr_id`, `cal_tmstmp_tm`, `call_time`, `apn_nm`, `direction`, `roaming_type` |
| Aggregation needed | **Yes** — `sp_refresh_carrier_kpis` must GROUP BY `call_dt`, derived-country (from MCC), `visitd_plmn_nm` and compute all KPIs as aggregations |

---

## Historical Depth

| Field | Value |
|---|---|
| Earliest date | TBD — run `MIN(call_dt)` |
| Latest date | TBD — run `MAX(call_dt)` |
| Total distinct dates | TBD — run `COUNT(DISTINCT call_dt)` |
| Calendar days spanned | TBD |
| Date gaps found | TBD — run Block 2 of validate_grain_and_coverage.sql with `call_dt` |
| Sufficient for 90-day backfill | TBD |
| Backfill readiness | TBD |

---

## Column Mapping

| # | Source Column | Source Type | Target Column | Target Type | Transform | Notes |
|---|---|---|---|---|---|---|
| 1 | `call_dt` | DATE | refresh_date | DATE | Direct | Partition key; GROUP BY dimension |
| 2 | `mcc_mnc` | STRING | country_name | STRING | MCC lookup → static MCC-to-country table | Split `mcc_mnc`, extract MCC, join to lookup |
| 3 | `mcc_mnc` | STRING | country_code | STRING | MCC lookup → ISO 3166-1 alpha-2 | Same lookup as country_name |
| 4 | `visitd_plmn_nm` | STRING | carrier_name | STRING | Direct | Visited PLMN name = carrier name |
| 5 | `mcc_mnc` | STRING | mcc | STRING | `SPLIT(mcc_mnc, '-')[OFFSET(0)]` or substring | Combined field — needs splitting |
| 6 | `mcc_mnc` | STRING | mnc | STRING | `SPLIT(mcc_mnc, '-')[OFFSET(1)]` or substring | Combined field — needs splitting |
| 7 | *(absent)* | — | is_steered | BOOL | Manual tagging | Not in source; default FALSE, manually set per carrier |
| 8 | `usr_pln_tot_rtt_usec_ms` | FLOAT | kpi_latency_ms | FLOAT64 | `AVG(usr_pln_tot_rtt_usec_ms)` per group | Already in milliseconds; aggregate across sessions |
| 9 | `usr_pln_dnld_effctv_bytes_cnt`, `usr_pln_dnld_actv_mlsec` | INTEGER | kpi_throughput_kbps | FLOAT64 | `SUM(bytes) / NULLIF(SUM(mlsec), 0) * 8` | bytes/ms → kbps: multiply by 8 (bits) and by 1000 (ms→s) / 1000 (b→kb) = *8 |
| 10 | `usr_pln_dnld_rtrnsmttd_pkts_cnt`, `usr_pln_dnld_pkts_cnt` | INTEGER | kpi_packet_loss_pct | FLOAT64 | `SUM(retransmitted) / NULLIF(SUM(total_pkts), 0) * 100` | Retransmit ratio as percentage |
| 11 | `usr_pln_success_cnt`, `usr_pln_rqst_cnt` | INTEGER | kpi_session_success_pct | FLOAT64 | `SUM(success) / NULLIF(SUM(request), 0) * 100` | Success/request ratio as percentage |
| 12 | `usr_pln_dnld_effctv_bytes_cnt`, `usr_pln_upld_effctv_bytes_cnt` | INTEGER | traffic_volume_mb | FLOAT64 | `SUM(dnld + upld) / (1024 * 1024)` | Bytes → MB |
| 13 | `usr_pln_rqst_cnt` | INTEGER | session_count | INT64 | `SUM(usr_pln_rqst_cnt)` per group | Total requests as session proxy |
| 14 | `subscr_id` | INTEGER | subscriber_count | INT64 | `COUNT(DISTINCT subscr_id)` per group | **PII column — aggregate only, never store raw** |

**Unmapped source columns:**
- `cal_tmstmp_tm` (TIMESTAMP) — full timestamp, useful for sub-daily analysis later
- `call_time` (TIME) — time component, not needed at daily grain
- `call_hour` (TIMESTAMP) — hourly bucket, not needed at daily grain
- `apn_nm` (STRING) — APN name, could be useful for future per-APN analysis
- `direction` (STRING) — up/down direction; KPI derivations above use download-specific columns. Consider whether upload metrics should also be tracked.
- `roaming_type` (STRING) — may need filtering to include only international roaming
- `usr_pln_upld_pkts_cnt` (INTEGER) — upload packets, used only if upload packet loss tracked separately
- `usr_pln_upld_actv_mlsec` (INTEGER) — upload active time, used only if upload throughput tracked separately
- `usr_pln_pk_rtt_usec_ms` (FLOAT) — peak RTT, could be useful as an additional KPI (max latency)
- `usr_pln_tot_ttfb_usec_ms` (FLOAT) — time to first byte total, could supplement latency KPI
- `usr_pln_ttfb_cnt` (INTEGER) — TTFB count, needed if using TTFB as latency alternative
- `usr_pln_upld_rtrnsmttd_pkts_cnt` (INTEGER) — upload retransmits, used only if upload packet loss tracked

**Derived columns (not sourced from Netscout — computed by pipeline stored procs):**
- `norm_latency`, `norm_throughput`, `norm_packet_loss`, `norm_session_success` — normalized 0-100 scale (Story 2.1)
- `composite_quality_score` — equal-weight average of normalized KPIs (Story 2.2)
- `degradation_flag`, `degradation_details` — 7-day trailing window detection (Story 2.3)

---

## KPI Availability Assessment

| KPI | Available | Source Column | Unit | Null Rate | Notes |
|---|---|---|---|---|---|
| Latency | **Yes (derived)** | `usr_pln_tot_rtt_usec_ms` | ms | TBD | AVG across sessions per carrier/country/day |
| Throughput | **Yes (derived)** | `usr_pln_dnld_effctv_bytes_cnt` / `usr_pln_dnld_actv_mlsec` | bytes/ms → kbps | TBD | Download throughput; multiply by 8 for kbps |
| Packet Loss | **Yes (derived)** | `usr_pln_dnld_rtrnsmttd_pkts_cnt` / `usr_pln_dnld_pkts_cnt` | ratio → % | TBD | Retransmit ratio as proxy for packet loss |
| Session Success Rate | **Yes (derived)** | `usr_pln_success_cnt` / `usr_pln_rqst_cnt` | ratio → % | TBD | Success/request ratio |

**Missing KPIs:** None — all 4 KPIs are derivable from source columns, though none are pre-computed. All require aggregation in `sp_refresh_carrier_kpis`.

---

## Steering Source (`is_steered`)

| Field | Value |
|---|---|
| Present in source data | **No** |
| Source column name | N/A |
| Source mechanism | **Manual tagging** |
| If absent, proposed approach | Default `FALSE` for all carriers. Maintain a manual steering-rules config (e.g., a BQ table or JSON config) that maps specific MCC/MNC pairs to `is_steered = TRUE`. Updated by the steering team as routing decisions change. |

---

## Data Quality Summary

TBD — run `validate_grain_and_coverage.sql` Block 3 against `stg_user_plane` with actual column names. Key columns to check:

| Column | Total Rows | NULL Count | NULL % | Assessment |
|---|---|---|---|---|
| `visitd_plmn_nm` (carrier) | TBD | TBD | TBD | |
| `call_dt` (date) | TBD | TBD | TBD | |
| `mcc_mnc` | TBD | TBD | TBD | Critical — needed for country derivation |
| `usr_pln_tot_rtt_usec_ms` (latency) | TBD | TBD | TBD | |
| `usr_pln_dnld_effctv_bytes_cnt` (throughput) | TBD | TBD | TBD | |
| `usr_pln_dnld_rtrnsmttd_pkts_cnt` (packet loss) | TBD | TBD | TBD | |
| `usr_pln_success_cnt` (session success) | TBD | TBD | TBD | |

---

## Country / Carrier Coverage

TBD — run Block 5 of `validate_grain_and_coverage.sql` with `visitd_plmn_nm` as carrier and derived country from `mcc_mnc`.

| Metric | Value |
|---|---|
| Distinct PLMN names | TBD |
| Distinct MCC/MNC pairs | TBD |
| Distinct dates | TBD |

---

## Additional Findings

- **PII present:** `subscr_id` (INTEGER) is a subscriber identifier. Must be aggregated away — never stored in `stg_*` or `crt_*` tables. Governance gates (DNTL, de-identification) must account for this.
- **`mcc_mnc` format unknown:** Need to verify delimiter — could be `"310-260"`, `"310260"`, or another format. Splitting logic in `sp_refresh_carrier_kpis` depends on this.
- **`direction` column:** KPI derivations above use download-specific columns only. Decision needed: track upload metrics separately, combine up+down, or download-only.
- **`roaming_type` column:** Values unknown. May need `WHERE roaming_type = 'international'` filter to exclude domestic sessions.
- **`usr_pln_pk_rtt_usec_ms`:** Peak RTT available as a bonus metric beyond the 4 required KPIs.

---

## Impact on Architecture

| Area | Changes Needed | Details |
|---|---|---|
| Column naming standard | **No** | Target column names remain as designed; transforms handle source differences |
| Pipeline design (`sp_refresh_carrier_kpis.sql`) | **Yes — significant** | Must aggregate from session-level to country/carrier/day grain. All KPIs derived via aggregation functions. Needs MCC→country lookup join. |
| Data model (`stg_carrier_kpi_daily`) | **No** | Target schema unchanged; aggregation happens in the stored proc |
| Backfill procedure (`sp_backfill_historical.sql`) | **TBD** | Depends on historical depth — verify ≥90 days available |
| Quality checks (`sp_run_quality_checks.sql`) | **No** | Checks operate on aggregated stg tables, not raw source |
| Datahub access (`tf-infra-cio-datahub-bilayer`) | **Yes — rework** | Source is workbench (`wb-tps-ia1-workbench-pr-641ea1`), not `ent_*` Datahub. Story 1.3 needs rework for workbench access pattern. |

---

## Sign-off

- [x] All 4 KPIs confirmed available (or mitigation documented)
- [x] Data grain confirmed and documented
- [ ] 90-day historical depth confirmed
- [x] Column mapping complete (all 14 source-mapped target columns; 7 derived columns documented separately)
- [x] Steering source identified or alternative proposed
- [ ] Data quality acceptable for pipeline use
- [x] Architecture impact assessed, no blockers for Story 2.1
- [x] OQ-1 status updated to **RESOLVED**
