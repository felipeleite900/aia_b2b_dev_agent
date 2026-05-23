---
title: "International Roaming Intelligence"
status: final
created: 2026-05-21
updated: 2026-05-21
---

# PRD: International Roaming Intelligence

## 0. Document Purpose

This PRD defines the requirements for a daily roaming intelligence platform serving the TELUS carrier steering team. It is structured around feature groups with nested functional requirements (FR-1 through FR-N), tagged assumptions indexed at the end, and Glossary-anchored vocabulary. The product brief (`briefs/brief-ai_first_development-2026-05-21/brief.md`) is the upstream input; this PRD builds on it without duplicating it. Downstream consumers: architecture, epics/stories, and the implementation team.

## 1. Vision

Carrier steering — choosing which partner network a TELUS subscriber uses when roaming abroad — is the single highest-leverage decision the steering team makes. It directly shapes subscriber experience and roaming revenue across ~200 countries and ~487 partner carriers. Today that decision is made monthly, grounded in commercial terms and lagging complaint signals rather than network performance data.

The data to change this already exists. Netscout probe data, treated and available in BigQuery, captures quality and usage metrics across the full partner carrier landscape. No one consumes it operationally. International Roaming Intelligence turns that data into a daily operational tool: quality KPIs, usage analytics, comparative carrier rankings, and trend visibility — delivered through a purpose-built web application the steering team uses to ground every steering decision in network performance.

There is no technical moat. The advantage is speed of execution and the direct feedback loop between data and the team that controls steering.

## 2. Target User

### 2.1 Primary Persona

The **carrier steering analyst** on the TELUS international roaming team. They decide which partner network subscribers land on in each roaming country. They work at the country/carrier level, reviewing performance periodically and adjusting steering rules. Currently constrained to monthly review cycles with limited data visibility.

### 2.2 Jobs To Be Done

- **Evaluate carrier quality before steering decisions** — "I need to see which partner carrier delivers the best experience in a given country right now, not last month."
- **Detect quality degradation early** — "I need to know when a partner's quality drops so I can react in days, not weeks."
- **Validate steering effectiveness** — "After I steer subscribers to a carrier, I need to see whether their experience actually improved."
- **Justify steering decisions with data** — "I need to show stakeholders that steering choices are grounded in network performance, not just commercial terms."

### 2.3 Non-Users (v1)

- **Wholesale/commercial teams** — they may benefit from this data eventually, but v1 is built for the steering team's operational workflow.
- **Subscribers** — no subscriber-facing surface.
- **Other engineering teams** — this is not a platform or shared service; it's a purpose-built tool.

### 2.4 Key User Journeys

- **UJ-1. Analyst reviews daily carrier quality before a steering decision.**
  Analyst opens the web app (authenticated via Google IAP). Selects a country from the country list. Sees partner carriers ranked by composite quality score. Drills into a specific carrier to see individual KPIs (latency, throughput, packet loss, session success rate). Compares against the currently steered-to carrier. Decides whether to adjust steering and documents the rationale.

- **UJ-2. Analyst spots a quality degradation trend.**
  Analyst opens the trend view for a country they recently adjusted steering for. Sees a 7-day quality trend for each carrier. Notices the steered-to carrier's latency has been climbing for 3 consecutive days. Switches to the comparative view to identify a better-performing alternative. Initiates a steering change.

- **UJ-3. Analyst validates data freshness and completeness.**
  Analyst opens the data quality dashboard. Sees the last refresh timestamp, coverage by country, and any countries or carriers with missing data in the latest refresh. Confirms the data is fresh enough to act on before making a steering decision.

## 3. Glossary

- **Partner Carrier** — A mobile network operator in a foreign country with whom TELUS has a roaming agreement. Subscribers connect to a Partner Carrier when roaming. ~487 across ~200 countries.
- **Carrier Steering** — The process of configuring which Partner Carrier a TELUS subscriber preferentially connects to when entering a roaming country. Controlled by the steering team.
- **Steering Rule** — A configured preference that directs subscribers to a specific Partner Carrier in a given country. Reviewed and adjusted by the steering team.
- **Quality KPI** — A network performance metric derived from Netscout probe data measuring the experience quality of a Partner Carrier. Includes Latency, Throughput, Packet Loss, and Session Success Rate. [ASSUMPTION: exact KPI set depends on BigQuery schema validation.]
- **Composite Quality Score** — A weighted aggregate of individual Quality KPIs for a given Partner Carrier in a given country, enabling ranking and comparison. V1 default: equal weight across all available KPIs (each KPI normalized 0–100, then averaged). [ASSUMPTION: equal-weight default; steering team may refine weights post-launch based on operational experience (OQ-4).]
- **Refresh Cycle** — The daily batch process that transforms raw Netscout probe data in BigQuery into curated analytics tables consumed by the web application.
- **Data Quality Check** — An automated validation that runs during each Refresh Cycle to detect missing countries, stale data, anomalous drops in carrier counts, or data completeness issues.

## 4. Features

### 4.1 Daily Data Pipeline

**Description:** An automated daily batch pipeline that transforms raw Netscout probe data in BigQuery into curated analytics tables. The pipeline runs on a daily schedule via Cloud Workflows, refreshing Quality KPIs and usage metrics for all Partner Carriers across all countries. Realizes UJ-1, UJ-2.

[INFO] DEP review applies — data processing described in this section requires DEP assessment before implementation. (source: governance/data-enablement-plan.md)

[INFO] DNTL classification pending — classify data sensitivity before architecture decisions. Canadian region required: northamerica-northeast1 / northamerica-northeast2. (source: governance/dntl-classification.md)

**Functional Requirements:**

#### FR-1: Daily data refresh

The system refreshes all Quality KPIs and usage metrics from Netscout probe data in BigQuery on a daily schedule.

**Consequences (testable):**
- Curated analytics tables are updated by 08:00 ET daily. [ASSUMPTION: 08:00 ET target allows for overnight processing; actual feasibility depends on upstream data arrival time.]
- Each refresh covers all countries and Partner Carriers present in the source data.
- The refresh is idempotent — re-running the same day's pipeline produces identical results.

#### FR-2: Incremental processing

The pipeline processes only new or changed data since the last successful refresh, not the full historical dataset.

**Consequences (testable):**
- Pipeline execution time scales with daily data volume, not total historical volume.
- A full backfill mode exists for initial load and recovery. [ASSUMPTION: backfill is a one-time or rare operation.]

#### FR-3: Pipeline observability

The pipeline emits structured logs and metrics for each run.

**Consequences (testable):**
- Each run records: start time, end time, rows processed, countries covered, carriers covered, success/failure status.
- Failed runs are logged with error context sufficient for debugging.

### 4.2 Quality KPI View

**Description:** The primary analytical view showing network quality metrics per country and per Partner Carrier. The steering team uses this to compare carrier performance and make informed steering decisions. Realizes UJ-1.

**Functional Requirements:**

#### FR-4: Country-level quality summary

The system displays a list of countries with an aggregate quality indicator for each.

**Consequences (testable):**
- All countries with roaming data in the latest refresh are listed.
- Each country shows a summary quality indicator derived from its Partner Carriers' performance.

#### FR-5: Carrier-level quality breakdown

For a selected country, the system displays all Partner Carriers ranked by Composite Quality Score with individual Quality KPIs visible.

**Consequences (testable):**
- Partner Carriers are ranked by Composite Quality Score, highest first.
- Individual KPIs displayed: Latency (ms), Throughput (kbps), Packet Loss (%), Session Success Rate (%). [ASSUMPTION: these are the available KPIs; actual set depends on BigQuery schema.]
- The currently steered-to carrier is identified by a distinct label or badge in the carrier list (e.g., "STEERED" tag). The API response includes a boolean `is_steered` field per carrier. [ASSUMPTION: steering rule data is available or can be manually tagged.]

#### FR-6: Carrier detail drill-down

The system allows drilling into a specific Partner Carrier to see detailed KPI values, historical data points, and metadata.

**Consequences (testable):**
- Detail view shows the last 30 days of daily KPI values for the selected carrier.
- Metadata includes: carrier name, MCC/MNC codes, country. [ASSUMPTION: MCC/MNC available in source data.]

### 4.3 Usage Analytics

**Description:** Traffic volume and subscriber activity metrics per country and Partner Carrier, showing where roaming activity concentrates and shifts. Realizes UJ-1.

**Functional Requirements:**

#### FR-7: Usage metrics per carrier per country

The system displays usage metrics alongside quality metrics for each Partner Carrier.

**Consequences (testable):**
- Metrics displayed: traffic volume (MB), session count, unique subscriber count. [ASSUMPTION: subscriber-level granularity exists in aggregated form without exposing individual subscriber data.]
- Usage metrics are from the same Refresh Cycle as Quality KPIs.

#### FR-8: Usage share visualization

The system shows each Partner Carrier's share of total roaming traffic within a country.

**Consequences (testable):**
- Traffic share displayed as percentage of country total.
- Carriers with < 1% share are grouped under "Other" to reduce visual noise.

[INFO] De-identification standards apply — if subscriber-level data is used in aggregation, ensure de-identification assessment is complete before implementation. (source: governance/de-identification-standards.md)

### 4.4 Comparative Carrier Ranking

**Description:** Partner Carriers ranked by quality and usage within each country, making steering decisions visually obvious. Realizes UJ-1, UJ-2.

**Functional Requirements:**

#### FR-9: Multi-dimensional ranking

The system supports ranking Partner Carriers by individual KPIs, Composite Quality Score, or usage volume.

**Consequences (testable):**
- User can sort the carrier list by any single KPI, by Composite Quality Score, or by traffic volume.
- Default sort is by Composite Quality Score.

#### FR-10: Side-by-side carrier comparison

The system allows selecting two or more Partner Carriers for direct side-by-side comparison.

**Consequences (testable):**
- Comparison view shows selected carriers' KPIs in aligned columns.
- For each KPI, the carrier with the better value is indicated (lower is better for Latency and Packet Loss; higher is better for Throughput and Session Success Rate). A difference exceeding 10% of the worse value is flagged as significant. [ASSUMPTION: 10% significance threshold; tunable.]

### 4.5 Trend Visibility

**Description:** Quality over time per carrier so the team spots degradation early. Realizes UJ-2.

**Functional Requirements:**

#### FR-11: Time-series quality trends

The system displays Quality KPI trends over configurable time windows.

**Consequences (testable):**
- Default view: 30-day trend for each KPI.
- Configurable windows: 7, 14, 30, 90 days.
- Trend lines rendered per Partner Carrier within a country.

#### FR-12: Degradation indicators

The system flags carriers whose quality has degraded beyond a threshold over a trailing window.

**Consequences (testable):**
- A carrier is flagged when any KPI worsens by more than a configurable percentage over a 7-day trailing window. Degradation direction per KPI: Latency increases > threshold = degradation; Throughput decreases > threshold = degradation; Packet Loss increases > threshold = degradation; Session Success Rate decreases > threshold = degradation. [ASSUMPTION: default threshold 20%; configurable by the steering team.]
- Degradation flags are visible on both the country summary and carrier detail views.

### 4.6 Data Quality Monitoring

**Description:** Automated validation running during each Refresh Cycle to ensure the data is trustworthy before the steering team acts on it. Realizes UJ-3.

**Functional Requirements:**

#### FR-13: Freshness check

The system validates that the latest data is within an acceptable staleness window.

**Consequences (testable):**
- The web app displays the timestamp of the last successful Refresh Cycle.
- If data is older than 36 hours, a staleness warning is displayed prominently. [ASSUMPTION: 36-hour threshold; upstream data arrival cadence not yet confirmed.]

#### FR-14: Coverage validation

The system checks that the expected set of countries and carriers is present in each refresh.

**Consequences (testable):**
- Countries or carriers present in the prior refresh but missing in the current refresh are flagged.
- A coverage summary (countries covered, carriers covered, missing entities) is visible on the data quality view.

#### FR-15: Anomaly detection on volumes

The system flags statistically significant drops in data volumes that could indicate upstream pipeline issues.

**Consequences (testable):**
- A daily carrier-country pair with traffic volume below 50% of its 14-day rolling average is flagged. [ASSUMPTION: 50% threshold; tunable.]
- Anomalies are surfaced on the data quality dashboard and optionally in the main views as data confidence indicators.

### 4.7 Web Application

**Description:** A purpose-built web application serving as the steering team's daily operational tool. Deployed on bi-layer Cloud Run. Realizes UJ-1, UJ-2, UJ-3.

**Functional Requirements:**

#### FR-16: Authenticated access

The application is accessible only to authorized users.

**Consequences (testable):**
- Authentication via Google Identity-Aware Proxy (IAP). [ASSUMPTION: IAP is the standard internal-tool auth mechanism on bi-layer Cloud Run.]
- Unauthorized requests receive HTTP 403.

#### FR-17: Responsive data views

The application renders country, carrier, and trend views with sub-second interactivity.

**Consequences (testable):**
- Page load (initial) completes in < 3 seconds.
- Filter, sort, and drill-down interactions complete in < 500ms.
- Application reads from pre-computed BigQuery materialized views or cached aggregations, not raw tables.

#### FR-18: Filter and search

The application supports filtering and searching across countries and carriers.

**Consequences (testable):**
- User can filter by country name, region, or carrier name.
- Search is case-insensitive substring match with results updating as the user types.

**Notes:**
- [NOTE FOR PM] Technology stack for the web app (framework, frontend/backend split) is an architecture decision, not a PRD concern. The PRD scopes the capability; architecture decides the implementation.

## 5. Non-Goals (Explicit)

- **Not a real-time monitoring tool.** Daily refresh is the target cadence; sub-daily or real-time is a future aspiration, not a v1 design constraint.
- **Not an automation platform.** This is a visibility tool. Automated steering recommendations or actions are explicitly out of scope.
- **Not a subscriber-level analytics tool.** The steering team works at country/carrier level. Subscriber-level drill-down is out of scope.
- **Not an alerting/notification system (v1).** The team pulls data rather than being pushed alerts. [NON-GOAL for MVP — alerting on quality drops is a likely v2 need.]
- **Not a multi-team platform.** v1 is built for the steering team. Expansion to wholesale, commercial, or other teams is not a design constraint.
- **Not a data ingestion platform.** The Netscout probe data already exists in BigQuery. This project consumes it; it does not own the ingestion pipeline.

## 6. MVP Scope

### 6.1 In Scope

- Daily-refreshed quality and usage KPIs per country and per Partner Carrier
- Composite quality scoring and comparative carrier ranking within each country
- Trend visibility (quality over time) with configurable windows
- Data quality monitoring: freshness, coverage, volume anomaly detection
- Purpose-built web application with authentication, filtering, and responsive views
- Coverage of all ~200 countries and ~487 carriers present in the data
- Pipeline observability (structured logs, run metrics)

### 6.2 Out of Scope for MVP

- **Sub-daily or real-time refresh** — daily is the target cadence. Deferred to v2 pending demonstrated need and upstream data freshness validation.
- **Alerting and notifications** — the team pulls data in v1. Deferred to v2 when usage patterns clarify what's worth alerting on. [NOTE FOR PM] This is the most likely v2 feature; design the data quality checks to be alert-ready.
- **Automated steering recommendations** — v1 is visibility, not automation. Deferred indefinitely; requires significant trust in data quality and model accuracy.
- **Integration with other teams' workflows** — v1 is for the steering team only.
- **Historical backfill beyond 90 days** — initial load covers 90 days of history. [ASSUMPTION: 90 days is sufficient for trend analysis; more can be backfilled later.]
- **Mobile-optimized views** — desktop-first for the steering team's workflow.
- **Export/download functionality** — steering decisions happen in the tool, not in spreadsheets. Deferred unless the team requests it.

## 7. Success Metrics

**Primary**

- **SM-1**: The steering team reviews quality and usage data at least 3x per week (up from monthly). Validates FR-4, FR-5, FR-7. [ASSUMPTION: 3x/week is a reasonable adoption target; baseline is monthly.]
- **SM-2**: Time from quality degradation to steering adjustment drops from weeks to ≤ 5 business days. Validates FR-11, FR-12. [ASSUMPTION: 5-day target; baseline data needed to confirm.]

**Secondary**

- **SM-3**: ≥ 80% of steering decisions reference specific KPIs from the tool within 3 months of launch. Validates FR-5, FR-9, FR-10.
- **SM-4**: Data quality checks pass on ≥ 95% of daily refreshes without manual intervention. Validates FR-13, FR-14, FR-15.

**Counter-metrics (do not optimize)**

- **SM-C1**: Steering change frequency — optimizing for more frequent changes is not the goal. The tool should enable *better* decisions, not *more* decisions. Counterbalances SM-1.
- **SM-C2**: Pipeline compute cost — should not grow disproportionately to data volume. Counterbalances FR-2.

## 8. Cross-Cutting NFRs

- **Performance:** Pre-computed aggregations ensure sub-second query response. Pipeline completes daily refresh within 2 hours of data availability. [ASSUMPTION: 2-hour processing window.]
- **Reliability:** Pipeline failures do not corrupt existing data; the last successful refresh remains available. Retry logic on transient failures (BigQuery slot contention, network hiccups).
- **Observability:** Structured logging for pipeline runs. Application-level request metrics (latency, error rate). Data quality metrics exposed in the web app.
- **Data residency:** All data processing and storage in `northamerica-northeast1` or `northamerica-northeast2` per TELUS Canadian data sovereignty requirements. (source: governance/canadian-data-sovereignty.md)
- **Security:** No PII in the pipeline or application. Network performance data only. Access scoped to the steering team via Google IAP.

## 9. Integration and Dependencies

- **Netscout probe data in BigQuery** — the primary data source. Schema validation is the first implementation task. [ASSUMPTION: data is already treated and available; no additional ingestion work required.]
- **BigQuery Enterprise Datahub** — if Netscout data is served via Datahub `ent_*` tables, access must be requested via PR to `telus/tf-infra-cio-datahub-bilayer`. (source: infrastructure/bigquery-enterprise-datahub.md)
- **Cloud Workflows** — daily orchestration of the data pipeline. Follows bi-layer patterns. (source: infrastructure/cloud-workflows-orchestration.md)
- **Cloud Run (bi-layer)** — hosts the web application. Sync ≤ 5s profile fits bi-layer. (source: infrastructure/bi-layer-overview.md)
- **Google IAP** — authentication for the web application.

## 10. Data Governance

- **Classification:** Internal. Network performance metrics aggregated at the carrier/country level. No subscriber PII.
- **DNTL:** Pending classification. [ASSUMPTION: data is likely "Low Risk" under DNTL since it contains aggregated network performance metrics, not personal information. Formal classification required before implementation.]
- **De-identification:** Not expected to apply — no personal information in the data pipeline. If subscriber counts are derived from individual-level data, de-identification assessment required at the aggregation layer.
- **DEP:** Required. Data processing of TELUS network data requires DEP assessment.

## 11. Open Questions

1. **OQ-1: What is the BigQuery table schema for the treated Netscout probe data?** This is the single highest-priority item — it determines which KPIs are available and how the data model is structured.
2. **OQ-2: How fresh is the data in BigQuery?** If probes report with a lag, the "daily" dashboard may show data that is 24-48 hours old. What is the actual upstream data arrival cadence?
3. **OQ-3: Is steering rule data available programmatically?** FR-5 calls for highlighting the currently steered-to carrier. If steering rules aren't queryable, this becomes manual tagging.
4. **OQ-4: What are the appropriate weights for the Composite Quality Score?** V1 uses equal weighting as default. The steering team should refine weights post-launch based on which KPIs correlate most with subscriber experience.
5. **OQ-5: What is the expected user count?** Sizing the Cloud Run instance and BigQuery materialized view refresh strategy depends on concurrent user load. [ASSUMPTION: < 10 concurrent users given team size.]

## 12. Assumptions Index

- **[ASSUMPTION] KPI set** (§3, FR-5): Latency, Throughput, Packet Loss, Session Success Rate are assumed available. Depends on BigQuery schema validation (OQ-1).
- **[ASSUMPTION] Composite Quality Score equal-weight default** (§3): V1 uses equal weight across normalized KPIs. Steering team refines post-launch (OQ-4).
- **[ASSUMPTION] Daily refresh target 08:00 ET** (FR-1): Feasibility depends on upstream data arrival time (OQ-2).
- **[ASSUMPTION] Incremental processing** (FR-2): Backfill is a rare operation.
- **[ASSUMPTION] MCC/MNC codes** (FR-6): Available in source data.
- **[ASSUMPTION] Subscriber counts aggregated** (FR-7): Aggregated form available without exposing individual subscriber data.
- **[ASSUMPTION] Steered-to carrier identification** (FR-5): Steering rule data available or can be manually tagged (OQ-3).
- **[ASSUMPTION] Degradation threshold 20%** (FR-12): Default; configurable by steering team.
- **[ASSUMPTION] Staleness threshold 36 hours** (FR-13): Upstream data arrival cadence not yet confirmed (OQ-2).
- **[ASSUMPTION] Volume anomaly threshold 50%** (FR-15): Of 14-day rolling average; tunable.
- **[ASSUMPTION] Google IAP for auth** (FR-16): Standard internal-tool auth on bi-layer Cloud Run.
- **[ASSUMPTION] 90-day historical backfill** (§6.2): Sufficient for trend analysis.
- **[ASSUMPTION] DNTL Low Risk** (§10): Aggregated network performance metrics, no PII. Formal classification required.
- **[ASSUMPTION] < 10 concurrent users** (OQ-5): Based on steering team size.
- **[ASSUMPTION] 2-hour processing window** (§8 NFRs): For daily pipeline completion.
- **[ASSUMPTION] Datahub access PR approved before pipeline build** (§9): If Netscout data is served via Datahub `ent_*` tables, the access-request PR to `telus/tf-infra-cio-datahub-bilayer` must be merged before FR-1 through FR-3 can be implemented.
- **[ASSUMPTION] Comparison significance threshold 10%** (FR-10): Of the worse value between two carriers; tunable.
