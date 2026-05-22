# Epic 5 Context: Governance & Compliance
<!-- Compiled from planning artifacts. -->

## Goal

Complete all mandatory governance gates for the International Roaming Intelligence data pipeline project: **DEP Review**, **DNTL Classification**, and **De-identification Standards assessment**. This epic ensures the pipeline meets TELUS Trust Model requirements, Privacy by Design principles, and Canadian data sovereignty obligations before production deployment.

Epic 5 runs in parallel with Epics 1–4 and carries no implementation code—only governance documentation tasks.

## Stories

**Story 5.1: DEP Review Assessment**
- Conduct Data Enablement Plan review for Netscout probe data processing
- Document complete data flow: Netscout → BigQuery → curated views → HTML report → GCS
- Update governance gate status from `Warned` to `Addressed` in governance-log.md
- Coordinate with Data Steward and DTO for review sign-off

**Story 5.2: DNTL Data Classification**
- Classify each data element in the pipeline under the DNTL framework (Do Not Touch, Not for LLM, Touch with Care, Low Risk)
- Confirm no subscriber-level PII in output (aggregated metrics only at carrier/country level)
- Validate Canadian data residency: all GCP resources in northamerica-northeast1/northeast2 per ADR-194
- Document classification decision and governance gate status update

**Story 5.3: De-identification Standards Review**
- Assess whether subscriber-level data is accessed during aggregation (FR-7 subscriber counts)
- Apply de-identification techniques at the aggregation boundary if needed
- Verify no individual subscriber data appears in staging or curated tables
- Confirm alignment with TELUS Insights de-id stack pattern
- Document assessment outcome and gate status update

## Requirements & Constraints

**Regulatory Framework**
- PIPEDA (federal baseline): meaningful consent, breach notification as soon as feasible
- Quebec Law 25: applies to any Quebec-resident data; DPO routing; PIA for cross-border transfer; granular consent; data portability; privacy by default
- DNTL: contractual layer requiring all data + processing in Canada; no Workspace APIs; Microsoft Exchange for DNTL workflows
- ADR-194 (GCP Assured Workloads): default for all TELUS GCP workloads (production + non-prod); both Canadian regions (northamerica-northeast1/northeast2); Assured Workload Canada Compliance Regime folder

**Data Characteristics**
- No direct PII in pipeline (names, contact info, IDs stripped at source)
- Aggregated metrics only: carrier names, country names, KPIs, usage counts at carrier/country/day grain
- Subscriber-level access only for aggregation: subscriber_count derived from raw data, never exposed in output
- No medical data, no health-related processing (not HIPAA/PHIPA-scoped)

**Governance Gates**
- DEP must be opened before pipeline reaches production
- No data processing changes without DEP scope expansion
- governance-log.md must track gate transitions: `Warned` → `Addressed` (per story acceptance criteria)
- DNTL status must be documented in Data Card (if applicable)
- De-id technique must be documented with DEP reference

**Cross-Epic Constraints**
- Does not block Epics 1–4 (runs in parallel)
- All pipeline data flow documentation (from Epics 1–4) must be available before DEP submission
- Architecture pivot to static HTML reports (not deployed web app) simplifies security scope: FR-16/17/18 no longer require IAP/Cloud Run auth, reducing DEP complexity

## Technical Decisions

**Privacy by Design Alignment**
- PbD Principle 1 (Proactive): governance gates prevent deployment without review
- PbD Principle 2 (Privacy as Default): no real PI in non-prod; synthetic data in bi-stg; real data only in bi-srv with FGAC
- PbD Principle 5 (End-to-End Security): de-id assessment ensures PI protection across pipeline stages

**Data Classification**
- Network performance metrics at aggregation boundary: **Internal** (TELUS-internal steering team only)
- Subscriber counts: classified as Touch with Care (quasi-identifier risk on aggregation); never exposed individually
- Country/carrier names, KPIs: Low Risk (public knowledge; anonymization-grade)

**Residency & Regional Constraints**
- All GCP resources: northamerica-northeast1 (Montréal, default) or northamerica-northeast2 (Toronto, secondary)
- No US regions (violates ADR-194 + Law 25 Section 17 cross-border PIA requirements)
- BigQuery datasets region-pinned; cross-region queries require explicit approval
- Bi-stg and bi-srv projects both inside Canada Compliance Regime folder (default via ADR-194)

**De-identification Technique**
- Subscriber_count aggregation: applies **data minimization** at column level
- No pseudonymization needed (data is aggregated, not individual-joinable)
- No synthetic data needed in pipeline (source data is already aggregated at Netscout probe level)
- If Law 25 cross-border applies: Section 17 PIA required for any data movement outside Quebec

**Non-Production Data Policy**
- Bi-stg and bi-wb: synthetic or de-identified data only (per DEP §8.13)
- No copy of landing/enterprise raw data into development environments
- Mock Netscout schema fixtures for unit tests (Faker-generated country/carrier names, randomized KPI values)

## Cross-Story Dependencies

**Story 5.1 → 5.2 → 5.3 (Sequential, not parallel)**
- DEP assessment (5.1) identifies data scope and processing steps → informs DNTL classification (5.2)
- DNTL classification (5.2) confirms aggregation boundary and PI handling → enables de-id assessment (5.3)
- De-id assessment (5.3) validates techniques and documents controls → DEP sign-off confirms all three gates addressed

**Dependency on Epics 1–4**
- Architecture decisions from Epic 4 (Cloud Workflows, Cloud Run, GCS bucket, gchat notifications): must be documented for DEP data flow
- Data model from Epic 2 (stg_* and crt_* tables, column schemas): must confirm no raw PI leakage
- Report sections from Epic 3 (HTML output, Plotly charts): must confirm no PI in exported data
- All schema decisions (from Epics 1–2): required for complete DNTL classification (which columns, which tables, which are aggregated)

**DEP Timing**
- DEP can be opened in parallel with Epics 1–4 (not a blocker)
- Turnaround ~1 month from submission to decision
- Must be approved before Story 4.4 (Promote to Production) proceeds
- Reference DEP ID in all subsequent PRs, Data Cards, and Model Cards
