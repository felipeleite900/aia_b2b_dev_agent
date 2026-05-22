# DEP Review Assessment — International Roaming Intelligence

**Project:** International Roaming Intelligence (Carrier Steering)
**Product Type:** Data Pipeline
**Assessment Date:** 2026-05-22
**Assessor:** Pipeline Development Team
**Gate Status:** Addressed (pending Data Steward/DTO sign-off)

---

## 1. Processing Purpose

Aggregate Netscout network probe data (session-level metrics) into daily carrier/country quality KPIs for the TELUS international roaming carrier steering team. The pipeline produces an automated HTML report ranking carriers by quality scores to inform steering decisions.

## 2. Data Flow

```
Source: wb-tps-ia1-workbench-pr-641ea1.user_plane_staging.stg_user_plane
  ↓ (BigQuery stored procedure — sp_refresh_carrier_kpis)
  ↓ Aggregates session-level data to country/carrier/day grain
  ↓ subscriber_id used ONLY for COUNT(DISTINCT) — never stored in output
  ↓
Staging: roaming_intelligence.stg_carrier_kpi_daily
  ↓ → sp_compute_composite_scores → stg_carrier_composite_daily
  ↓ → sp_detect_degradation → stg_carrier_degradation_daily
  ↓ → sp_run_quality_checks → stg_data_quality_log
  ↓ → sp_curate_output → crt_mv_* views (report data contract)
  ↓
Output: Python report generator (Cloud Run Job)
  ↓ Reads ONLY crt_mv_* views — never stg_* tables
  ↓ Produces self-contained HTML with Plotly charts
  ↓
Destination: GCS bucket (reports/{YYYY-MM-DD}/roaming-intelligence.html)
  ↓ Access via GCS IAM — no web auth layer
  ↓ Steering team has roles/storage.objectViewer
```

## 3. Data Elements Processed

| Element | Classification | Handling |
|---------|---------------|----------|
| subscriber_id (source) | Touch with Care | Aggregated to COUNT(DISTINCT) — never stored in output |
| mcc_mnc (source) | Low Risk | Split into MCC/MNC, joined to public ref table for country derivation |
| carrier_name (visitd_plmn_nm) | Low Risk | Public PLMN names — directly included |
| country_name / country_code | Low Risk | Derived from MCC via public ITU reference |
| KPI metrics (latency, throughput, etc.) | Internal | Aggregated network performance — no subscriber attribution |
| traffic_volume_mb, session_count | Internal | Aggregated at country/carrier/day grain |
| subscriber_count | Touch with Care | COUNT(DISTINCT subscriber_id) per group — quasi-identifier risk mitigated by aggregation grain |

## 4. Privacy Impact

- **Direct PII:** None in output. subscriber_id accessed during aggregation only (COUNT DISTINCT), never stored.
- **Quasi-identifiers:** subscriber_count per carrier/country/day could theoretically identify individuals in very small populations (e.g., 1 subscriber for a carrier in a country). Mitigated by the reporting grain (daily aggregation across all sessions).
- **Cross-referencing risk:** Low. Carrier/country names are public. KPI values are network metrics, not subscriber attributes.

## 5. Data Residency

- All GCP resources in `northamerica-northeast1` (Montréal).
- Source table, BigQuery datasets, GCS buckets, Cloud Run, Cloud Workflows — all in-region.
- No cross-border data movement.
- Compliant with ADR-194 (Assured Workloads Canada Compliance Regime).

## 6. Architecture Security Scope

- **No web application:** Architecture pivot to static HTML report eliminates IAP/Cloud Run auth concerns.
- **Access control:** GCS IAM only. No public URLs, no anonymous access.
- **Service account:** `bilayer-sa@{PROJECT_ID}.iam.gserviceaccount.com` with scoped roles (dataEditor on dataset, objectCreator on bucket).

## 7. Action Items

- [ ] Submit DEP to Data Steward with this assessment
- [ ] Obtain DTO review and sign-off
- [ ] Record DEP ID in governance-log.md
- [ ] Reference DEP ID in all subsequent PRs
