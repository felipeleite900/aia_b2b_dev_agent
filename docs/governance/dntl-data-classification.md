# DNTL Data Classification — International Roaming Intelligence

**Project:** International Roaming Intelligence (Carrier Steering)
**Assessment Date:** 2026-05-22
**Gate Status:** Addressed (pending sign-off)

---

## 1. Classification Summary

| Category | Elements | Count |
|----------|----------|-------|
| **Do Not Touch (DNT)** | None | 0 |
| **Not for LLM (NL)** | None | 0 |
| **Touch with Care (TWC)** | subscriber_id (source only), subscriber_count | 2 |
| **Low Risk (LR)** | All other pipeline data elements | 15+ |

**Overall Pipeline Classification: Internal — Touch with Care at aggregation boundary only.**

## 2. Element-by-Element Classification

### Source Data (read-only access)

| Element | Type | Classification | Justification |
|---------|------|---------------|---------------|
| subscriber_id | INTEGER | **TWC** | PII — subscriber identifier. Accessed ONLY for COUNT(DISTINCT) aggregation. Never stored in staging or curated tables. |
| mcc_mnc | STRING | LR | Public mobile network codes (ITU allocation) |
| visitd_plmn_nm | STRING | LR | Public carrier names |
| call_dt | DATE | LR | Date dimension — no subscriber attribution |
| KPI columns (latency, bytes, packets, etc.) | FLOAT/INT | LR | Network performance metrics — aggregated, no subscriber attribution |
| roaming_type | STRING | LR | Network classification tag |

### Pipeline Output (staging + curated)

| Element | Table(s) | Classification | Justification |
|---------|----------|---------------|---------------|
| country_name / country_code | All stg/crt | LR | Public geographic identifiers derived from MCC |
| carrier_name / mcc / mnc | All stg/crt | LR | Public PLMN identifiers |
| kpi_latency_ms, kpi_throughput_kbps, etc. | stg_carrier_kpi_daily | LR | Aggregated network metrics at carrier/country/day grain |
| norm_* (normalized KPIs) | stg_carrier_kpi_daily | LR | Derived from aggregated KPIs |
| composite_quality_score | stg_carrier_composite_daily | LR | Computed from normalized KPIs |
| degradation_flag / details | stg_carrier_degradation_daily | LR | Computed from KPI trends |
| traffic_volume_mb / session_count | stg_carrier_kpi_daily, crt_mv_* | LR | Aggregated volumes — no subscriber linkage |
| **subscriber_count** | stg_carrier_kpi_daily, crt_mv_* | **TWC** | COUNT(DISTINCT subscriber_id) per carrier/country/day — quasi-identifier risk in low-volume cells |
| is_steered | stg_carrier_kpi_daily | LR | Boolean operational flag |
| quality check results | stg_data_quality_log | LR | Pipeline metadata — no subscriber data |

## 3. Canadian Data Residency Validation

| Resource | Region | Compliant |
|----------|--------|-----------|
| Source BigQuery (workbench) | northamerica-northeast1 | Yes |
| Pipeline BigQuery (roaming_intelligence) | northamerica-northeast1 | Yes |
| GCS report buckets | northamerica-northeast1 | Yes |
| Cloud Run Job | northamerica-northeast1 | Yes |
| Cloud Workflows | northamerica-northeast1 | Yes |
| Cloud Scheduler | northamerica-northeast1 | Yes |

**ADR-194 Compliance:** All resources within Canada Compliance Regime folder. No US regions used.

## 4. DNTL Contractual Compliance

- No DNTL-classified data enters the pipeline (no direct customer PII, no contact info, no account data).
- subscriber_id is TWC — aggregated away before any data leaves the source query.
- No Workspace APIs or Google AI services used.
- No data export outside Canadian GCP regions.

## 5. Action Items

- [ ] Confirm TWC classification for subscriber_count with Data Steward
- [ ] Document in Data Card if applicable
- [ ] Update governance-log.md gate status
