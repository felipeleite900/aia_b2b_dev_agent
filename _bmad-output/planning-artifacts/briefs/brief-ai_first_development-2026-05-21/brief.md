---
title: "International Roaming Intelligence"
status: approved
created: 2026-05-21
updated: 2026-05-21
---

# Product Brief: International Roaming Intelligence

## Executive Summary

Carrier steering decisions -- which partner network a subscriber uses abroad -- are made monthly without visibility into how those networks actually perform. The data to change this already exists: Netscout probe data, treated and available in BigQuery, covering ~487 partner carriers across ~200 countries. No one consumes it today.

International Roaming Intelligence makes that data a daily operational tool for the steering team: quality KPIs and usage analytics per country and partner carrier, refreshed daily, so steering decisions are grounded in network performance rather than commercial terms or lagging complaint signals.

There is no technical moat here. The advantage is speed of execution and the direct feedback loop between data and the team that controls steering.

## The Problem

**Primary user: the carrier steering team.** They control which partner network subscribers land on in each roaming country -- a decision that directly shapes subscriber experience and roaming revenue.

Today they cannot answer basic questions with data:

- Which partner carrier delivers the best experience in a given country right now?
- Has a partner's quality degraded since the last review?
- Are subscribers on a steered-to carrier experiencing worse performance than alternatives?

Quality problems surface through subscriber complaints -- by then the damage is done. The monthly cycle means even known issues wait weeks for a steering adjustment.

## The Solution

A daily intelligence layer on top of the existing BigQuery dataset:

1. **Quality view** -- key network KPIs per country and partner carrier, refreshed daily. [ASSUMPTION: likely latency, throughput, packet loss, session success rate -- exact metrics depend on the treated BigQuery table schema.]

2. **Usage analytics** -- traffic volumes, session counts, subscriber counts per carrier and country, showing where roaming activity concentrates and shifts.

3. **Comparative ranking** -- partner carriers ranked by quality and usage within each country, making steering decisions visually obvious.

4. **Trend visibility** -- quality over time per carrier so the team spots degradation early. [ASSUMPTION: alerting on quality drops is a likely future need but may not be V1.]

Output format is open. [ASSUMPTION: a dashboard/BI tool (Looker, Metabase, or similar) is the most natural fit, but this could also be a lightweight web app or structured reports depending on team preference and available infrastructure.]

## Scope

**In (V1):**
- Daily-refreshed quality and usage KPIs per country and per partner carrier
- Comparative carrier ranking within each country
- Trend visibility (quality over time)
- Coverage of all ~200 countries and ~487 carriers present in the data

**Out (V1):**
- Real-time or sub-daily refresh [ASSUMPTION: daily is the target cadence; near-real-time is a future aspiration]
- Automated steering recommendations or actions -- this is a visibility tool, not an automation tool
- Subscriber-level drill-down [ASSUMPTION: the team works at country/carrier level]
- Alerting/notifications [ASSUMPTION: the team pulls data rather than being pushed alerts in V1]
- Integration with other teams' workflows (wholesale, commercial) [ASSUMPTION: V1 is built for the steering team; expansion is a future consideration, not a design constraint]

## Success Criteria

- The steering team reviews quality and usage data daily (or near-daily) instead of monthly.
- Steering decisions reference specific KPIs from the tool, not just commercial terms or complaint volume.
- Time from quality degradation to steering adjustment drops from weeks to days.
- [ASSUMPTION: measurable targets (e.g., "reduce degradation-to-action time from 30 days to 5 days") need baseline data to establish.]

## Risks and Open Questions

- **Schema unknown.** The BigQuery table's actual fields and granularity haven't been reviewed. This is the first thing to validate.
- **"Daily" feasibility.** How fresh is the data in BigQuery? If probes report with a lag, dashboards may show yesterday's or older data.
- **Tooling decision.** No BI tooling is currently in use. Standing up a visualization layer is part of the project.
- **Adoption risk.** Moving from monthly review to daily requires the team to change how they work, not just have access to a tool.

## Vision

If this works, daily visibility turns into shorter steering cycles, directly improving subscriber experience abroad. Over time this extends to alerting and anomaly detection, input to partner negotiations with hard quality data, and semi-automated steering recommendations based on quality thresholds. Long-term aspiration: steering decisions as close to real-time as the data allows, informed by quality, usage, and commercial factors together.
