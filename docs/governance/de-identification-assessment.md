# De-identification Standards Assessment — International Roaming Intelligence

**Project:** International Roaming Intelligence (Carrier Steering)
**Assessment Date:** 2026-05-22
**Gate Status:** Addressed (pending sign-off)

---

## 1. Assessment Scope

Evaluate whether subscriber-level data is adequately de-identified throughout the pipeline, with focus on the aggregation boundary where raw session data (containing subscriber_id) is transformed into carrier/country/day aggregates.

## 2. Subscriber Data Access Points

| Stage | subscriber_id Access | Controls |
|-------|---------------------|----------|
| Source query (sp_refresh_carrier_kpis) | Yes — used in `COUNT(DISTINCT subscr_id)` | SQL aggregation only; column never appears in SELECT output or INSERT column list |
| Staging tables (stg_*) | No — subscriber_count is the aggregated result | INTEGER count at carrier/country/day grain |
| Curated views (crt_mv_*) | No — reads from staging tables only | Views never reference source table |
| HTML report | No — displays subscriber_count as a number | No drill-down to individual level |
| GCS output | No — static HTML file | No query interface to decompose aggregates |

## 3. Aggregation Boundary Analysis

**Where aggregation happens:** `sp_refresh_carrier_kpis.sql`, line ~94:
```sql
COUNT(DISTINCT ps.subscr_id) AS subscriber_count
```

**GROUP BY dimensions:** `call_dt` (date), `country_code`, `country_name`, `carrier_name`, `mcc`, `mnc`

**Minimum group size risk:** A carrier/country/day combination with very few subscribers (e.g., subscriber_count = 1) could theoretically identify an individual's network usage patterns. However:
- The pipeline does not expose subscriber_id or any linkable attribute
- subscriber_count is a single integer — no additional attributes to cross-reference
- The report is Internal-only (steering team access via GCS IAM)
- Risk is informational, not actionable without additional data sources

## 4. De-identification Technique Applied

| Technique | Applied | Details |
|-----------|---------|---------|
| **Data Minimization** | Yes | subscriber_id accessed only for COUNT(DISTINCT); never stored in output |
| **Aggregation** | Yes | All metrics aggregated to carrier/country/day grain — no individual records |
| **Suppression** | Not needed | No cells suppressed; low-count risk mitigated by access controls |
| **Pseudonymization** | Not needed | No individual-level data in output to pseudonymize |
| **K-anonymity** | Not formally applied | Aggregation grain provides de facto group-level anonymity; formal k-anonymity not required for Internal-classified aggregated network metrics |

## 5. TELUS Insights De-id Stack Alignment

| Principle | Alignment |
|-----------|-----------|
| Data minimization at source | Yes — only required columns selected from source |
| Aggregation before storage | Yes — stg_carrier_kpi_daily contains only aggregated data |
| No PII in derived layers | Yes — curated views and HTML report contain zero PII |
| Access-controlled output | Yes — GCS IAM with scoped roles |
| Audit trail | Yes — stg_data_quality_log tracks all pipeline executions |

## 6. Non-Production Data Policy

| Environment | Data Policy | Status |
|-------------|-------------|--------|
| bi-stg | Real source data acceptable (aggregated at query time; no PII stored) | Compliant |
| Unit tests | Synthetic mock data (Faker-generated in sample_data.py) | Compliant |
| bi-wb (workbench) | Source table is read-only; pipeline writes to separate dataset | Compliant |

## 7. Conclusion

**De-identification status: ADEQUATE.**

The pipeline applies data minimization and aggregation at the source query boundary. subscriber_id is never stored in any output table, view, or report. The only derived value (subscriber_count) is an integer count at carrier/country/day grain, classified as Touch with Care. No additional de-identification techniques (pseudonymization, suppression, k-anonymity) are required given the Internal classification and access-controlled distribution.

## 8. Action Items

- [ ] Confirm assessment with Data Steward
- [ ] Reference in DEP submission
- [ ] Update governance-log.md gate status
