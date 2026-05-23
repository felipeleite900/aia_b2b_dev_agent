---
title: "Security and Access Model"
type: architecture-decision
source_artifact: "architecture.md"
created: "2026-05-22"
updated: "2026-05-22"
---

# Security and Access Model

**BigQuery Access:** Service account `bilayer-sa@{PROJECT_ID}.iam.gserviceaccount.com` with:
- `roles/bigquery.dataViewer` on source workbench dataset
- `roles/bigquery.dataEditor` on project-owned `roaming_intelligence` dataset

**GCS Report Bucket:** IAM-scoped.
- Pipeline service account: `roles/storage.objectCreator` (write)
- Steering team Google group: `roles/storage.objectViewer` (read)
- No public access

**Data Classification:** No PII in the pipeline. Aggregated network performance metrics at carrier/country level only. Classification: Internal.

**Data Residency:** All GCP resources in `northamerica-northeast1` (Montréal). Compliant with ADR-194 (Assured Workloads Canada Compliance Regime). No US regions.

**Subscriber Privacy:** `subscriber_id` accessed only for `COUNT(DISTINCT)` aggregation in `sp_refresh_carrier_kpis` — never stored in staging or curated tables. `subscriber_count` is the only derived quasi-identifier, classified as Touch with Care.
