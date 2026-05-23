---
title: "PRD Quality Review — International Roaming Intelligence"
prd: "prd-ai_first_development-2026-05-21/prd.md"
reviewer: "PRD Quality Review Agent"
review-date: 2026-05-21
---

# PRD Quality Review: International Roaming Intelligence

## Overall Verdict

This PRD is well above average for an internal tool: the thesis is clear, scope is honest, and assumptions are indexed. The main weaknesses are (1) the composite quality score remains an unresolved black box that could block FR-5, FR-9, and FR-10 at implementation time, and (2) several "testable consequences" describe UI appearance rather than verifiable system behavior, making QA sign-off ambiguous. It is ready to hand to architecture and engineering with two mandatory resolutions before stories are written.

---

## Dimension 1: Decision-Readiness

**Verdict: Adequate**

**Findings:**

- [HIGH] The Composite Quality Score (defined in §3 and driving FR-5, FR-9, FR-10) has no weighting scheme — it is deferred to "implementation with steering team input" (OQ-4 / Assumptions Index). This is not a minor gap: every ranking, comparison, and degradation flag depends on this score. A PM or engineering lead cannot sign off on the ranking feature without knowing whether the score is a simple average, a regressed model output, or a team-configured weighting. The decision needs to be made or a fallback default must be declared in the PRD. Fix: Add a default weighting (e.g., equal weights across the four KPIs) as the v1 baseline, with a note that the steering team can reconfigure it post-launch. This converts the open question into a tagged assumption with a working answer.

- [MEDIUM] OQ-2 (upstream data freshness / actual arrival cadence) is flagged but carries no escalation owner or discovery deadline. Two NFRs (08:00 ET target, 36-hour staleness threshold) and one success metric (SM-2) are directly contingent on this answer. If the upstream data arrives at 06:00 ET, the whole pipeline design holds; if it arrives at 10:00 ET, the 08:00 target is impossible. Fix: Add a discovery owner and date to OQ-2, and include a contingency branch: "If data arrives after 07:00 ET, the refresh target shifts to 12:00 ET."

- [LOW] The success metrics (§7) are directionally sound and include counter-metrics (rare and appreciated), but SM-1 ("3x per week") and SM-2 ("≤ 5 business days") both acknowledge missing baselines. This is fine for v1 drafts, but a decision-maker cannot evaluate whether these targets are ambitious or trivial. Flag this for the first retrospective gate.

**What works:** Trade-offs are surfaced clearly: real-time vs. daily (Non-Goals §5), alerting deferred with an explicit rationale, automation excluded with a reasoned justification. The decision-maker can act on those.

---

## Dimension 2: Substance Over Theater

**Verdict: Strong**

**Findings:**

- [LOW] The persona section (§2) is functional but edging toward theater. The "Jobs To Be Done" are valid and grounded in the actual workflow (UJ-1 through UJ-3 validate them), but the persona itself ("carrier steering analyst") has no detail that would differentiate a UI or data model decision. For a ~10-user internal tool, this is acceptable — the team likely knows the user personally — but the persona adds no information that couldn't be inferred from the JTBDs alone. It is not harmful, but it is not load-bearing.

- [LOW] The Vision (§1) paragraph is genuinely useful: it explains the actual gap (monthly reviews, lagging complaint signals, unused probe data) and the mechanism of value (turning data into a daily operational tool). This is not theater. No trim needed.

- [PASS] NFRs (§8) are scoped to the actual risk surface: performance, reliability, data residency, and security. There are no aspirational NFRs pasted from a template (e.g., "99.999% uptime," "WCAG 2.1 AA"). This is appropriate for an internal tool.

---

## Dimension 3: Strategic Coherence

**Verdict: Strong**

**Findings:**

- [PASS] The PRD has a clear thesis: the steering team is making decisions on monthly-lagging commercial signals when daily network performance data already exists in BigQuery unused. Every feature group — pipeline (FR-1 to FR-3), quality views (FR-4 to FR-6), usage analytics (FR-7 to FR-8), ranking (FR-9 to FR-10), trends (FR-11 to FR-12), data quality (FR-13 to FR-15), and the web app (FR-16 to FR-18) — directly serves either the "see quality" or "trust the data" halves of that thesis. Nothing is orphaned.

- [LOW] FR-10 (side-by-side carrier comparison) is slightly forward of the thesis. The core use case is "choose the best carrier in a country"; head-to-head comparison implies the user already has two candidates in mind. This is a reasonable extension but could be deferred to v2 if scope pressure arises. It is not incoherent — just the furthest feature from the MVP core.

- [PASS] Non-Goals (§5) are tightly coupled to the thesis. Each non-goal names the feature excluded and a rationale tied to the strategic position ("visibility, not automation"). This is unusually clean.

---

## Dimension 4: Done-ness Clarity

**Verdict: Adequate**

**Findings:**

- [HIGH] FR-5 consequence: "The currently steered-to carrier is visually distinguished." This is a UI description, not a testable system behavior. An engineer cannot write an acceptance test against "visually distinguished." Fix: Restate as a system behavior — e.g., "The carrier currently designated as the active steering target for the selected country is tagged with a `is_steered` flag in the API response and rendered with a distinct visual indicator in the UI." The test is then: given carrier X is the active steering target for country Y, the API returns `is_steered: true` for X and `false` for all others.

- [HIGH] FR-10 consequence: "Differences highlighted where one carrier outperforms another on a KPI. [ASSUMPTION: 'outperforms' thresholds to be determined.]" An unresolved threshold on a testable consequence means no acceptance test can be written. Fix: Define a default rule — e.g., "A carrier outperforms another on a KPI if its value exceeds the other's by more than 10% (configurable)." Tag as an assumption with a default rather than leaving it open.

- [MEDIUM] FR-12 consequence: "A carrier is flagged when any KPI degrades by more than a configurable percentage over a 7-day trailing window." The direction of "degrades" is ambiguous for each KPI: higher latency is worse, higher throughput is better. Fix: Specify direction per KPI — e.g., "Latency and Packet Loss: flagged when value increases by > threshold%; Throughput and Session Success Rate: flagged when value decreases by > threshold%."

- [MEDIUM] FR-8 consequence: "Carriers with < 1% share are grouped under 'Other' to reduce visual noise." This is a reasonable UX choice, but it has a testable implication that is not stated: "Other" must still be queryable or expandable, otherwise the analyst cannot discover a new carrier entering the market at <1%. Flag this design question for UX.

- [PASS] Most FR consequences are genuinely testable (FR-1 idempotency, FR-2 scaling, FR-3 log fields, FR-13 staleness threshold, FR-14 coverage diff, FR-15 volume threshold). The pipeline FRs are notably cleaner than the UI FRs.

---

## Dimension 5: Scope Honesty

**Verdict: Strong**

**Findings:**

- [PASS] The Assumptions Index (§12) is complete, indexed, and cross-referenced to FRs and open questions. This is the strongest section in the PRD. Fifteen assumptions are tagged with their source location and consequence. This is rare and genuinely useful.

- [PASS] Out-of-Scope items (§6.2) each name the reason for deferral and, where relevant, the v2 trigger condition. "Deferred to v2 when usage patterns clarify what's worth alerting on" is an actionable deferral criterion, not a vague punt.

- [MEDIUM] One implicit assumption is missing from the index: that the BigQuery Enterprise Datahub access request (§9, "access must be requested via PR to `telus/tf-infra-cio-datahub-bilayer`") is not blocking implementation. If the PR is not approved before the pipeline is built, FR-1 through FR-3 are blocked. This should be an explicit assumption with an owner. Fix: Add to §12: "[ASSUMPTION] BigQuery Datahub access: PR to `telus/tf-infra-cio-datahub-bilayer` is submitted and approved before pipeline development begins. Owner: [team lead]."

- [LOW] The 90-day historical backfill scope (§6.2) assumes 90 days is sufficient for trend analysis. FR-11 supports configurable windows up to 90 days, which means 90 days of history is exactly the minimum needed for the longest trend window. If the backfill is incomplete for any carrier, the 90-day trend view will show gaps on day one of launch. This should be flagged as a launch-blocking data quality item.

---

## Dimension 6: Downstream Usability

**Verdict: Adequate**

**Findings:**

- [HIGH] The composite quality score definition is not extractable by architecture or a story writer. §3 defines it as "a weighted aggregate of individual Quality KPIs" but the weights are TBD. Architecture cannot design the aggregation layer, and a story writer cannot write an acceptance criterion, until the weighting logic is resolved. This is the same gap as Dimension 1's high finding — it is critical across multiple downstream consumers.

- [MEDIUM] Feature groups 4.2 through 4.4 overlap significantly in responsibility. FR-5 (carrier breakdown ranked by composite score), FR-9 (multi-dimensional ranking), and FR-10 (side-by-side comparison) could be interpreted as one UI view with multiple sort modes or as three separate views/components. A UX designer or architect cannot determine the component boundary from the PRD alone. Fix: Add a UI topology note (similar to the NOTE FOR PM in §4.7) indicating whether these features are tabs, toggles, or separate routes.

- [MEDIUM] The User Journeys (§2.4) are the strongest source-extraction targets for stories, but they are in §2 rather than cross-referenced per FR. A story writer working from FR-9 or FR-10 must search back to UJ-1 to understand the context. Fix: Add a "Realizes UJ-X" tag to FR-9 and FR-10 (currently missing from Feature 4.4's header, though the feature description says "Realizes UJ-1, UJ-2").

- [PASS] The governance INFO tags (§4.1, §4.3) and dependency citations (§9) with explicit source paths are excellent for architecture extraction. An architect can trace exactly which infrastructure patterns to follow.

- [PASS] The web app section (§4.7) correctly excludes technology stack decisions with an explicit note. This is the right boundary for a PRD.

---

## Dimension 7: Shape Fit

**Verdict: Strong**

**Findings:**

- [PASS] The PRD is correctly sized for a single-team, ~10-user internal tool. It does not include: enterprise SLA tiers, multi-region failover, localization, accessibility compliance (WCAG), API versioning strategy, or other enterprise PRD furniture. Every section earns its place.

- [PASS] The non-goals section explicitly excludes platform thinking ("Not a multi-team platform," "Not a data ingestion platform"). This is exactly right for an internal tool — it avoids over-engineering the scope.

- [PASS] The web app NFRs (< 3s page load, < 500ms interactions) are calibrated to an internal analytical tool with <10 concurrent users, not a consumer product. No artificial SLO inflation.

- [LOW] The PRD does not address operational handoff or ownership: who is responsible for the daily pipeline when it fails at 07:45 ET? For a ~10-user internal tool with a daily operational dependency, a brief on-call / escalation note is appropriate. This is not a PRD requirement per se, but its absence will generate a question during sprint planning. Suggest adding a single sentence to §8 (Reliability): "Pipeline failure notifications route to [team channel/on-call rotation]; the last successful refresh remains available and the UI displays the staleness warning."

---

## Mechanical Notes

1. **Assumption cross-referencing:** Assumptions in §3 (Glossary) are tagged inline but not all appear in §12 (Assumptions Index). Specifically, "Composite Quality Score weights TBD" appears in §3 and is indexed in §12 — consistent. "MCC/MNC available in source data" appears in FR-6 and is indexed in §12 — consistent. This is well-maintained; preserve the discipline as FRs evolve.

2. **OQ numbering gap:** Open questions in §11 are numbered OQ-1 through OQ-5 implicitly (by sequence), but the Assumptions Index references OQ-1, OQ-2, OQ-3, OQ-4, OQ-5 without the OQ label being present in §11. Add OQ-N labels to §11 to make cross-references unambiguous.

3. **FR-12 / FR-15 threshold consistency:** FR-12 uses a 7-day trailing window for degradation; FR-15 uses a 14-day rolling average for volume anomalies. Both are reasonable, but the different windows should be documented as a deliberate design choice (degradation = recent signal, volume baseline = longer stability window) to avoid a future "why are these different?" question.

4. **"Bi-layer" references:** §4.7 and §9 reference "bi-layer Cloud Run" as an infrastructure pattern. The source document (`infrastructure/bi-layer-overview.md`) is cited, but a one-line definition in the Glossary (§3) would help any reviewer unfamiliar with TELUS infrastructure terminology interpret the deployment model.

5. **Version tagging:** The PRD status is "draft." Recommend adding a "Ready for Architecture" status gate to distinguish "draft under review" from "draft approved for downstream use." The PRD is close to the latter.
