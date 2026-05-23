# Input Reconciliation — Product Brief

**Input:** brief.md
**Gaps found:** 4

## Gaps

- **Adoption risk & change management**: The brief explicitly flags "adoption risk" in its Risks section, noting that "moving from monthly review to daily requires the team to change how they work, not just have access to a tool." The PRD translates this into soft success metrics (SM-1: 3x/week review adoption) but does not expose adoption risk as a first-class concern or outline a change management/onboarding strategy. The PRD defines what the tool does but not how the team will be coached to use it differently.

- **Vision for long-term competitive leverage**: The brief's Vision section articulates a multi-phase escalation — "over time this extends to alerting and anomaly detection, input to partner negotiations with hard quality data, and semi-automated steering recommendations." The PRD's roadmap is narrower: it defers alerting to v2 and explicitly excludes automated recommendations "indefinitely." The PRD loses the brief's forward momentum and the vision that data quality becomes a negotiation tool with partners.

- **Commercial stakeholder alignment**: The brief distinguishes between data visibility for the steering team and future expansion to "wholesale, commercial" teams, framing this as a design constraint. The PRD mentions this in Non-Goals and Integration notes but does not address how v1 decisions (KPI weighting, data presentation) might constrain later commercial use. No guidance on designing the data model or composite score to remain useful if wholesale/commercial teams adopt it later.

- **Grounding steering decisions in network performance, not complaints**: The brief emphasizes the shift from "complaint signals" and "commercial terms" to "network performance" as the core value prop. The PRD focuses on enabling the decision (delivering KPIs) but softens the "why" — it does not emphasize that the tool is meant to *replace* complaint-driven and commercially-motivated steering, making the shift explicit in success criteria or tone.

## Qualitative Drops

- **Urgency and pain clarity**: The brief's framing ("quality problems surface through subscriber complaints — by then the damage is done") is direct and visceral. The PRD abstracts this into Jobs To Be Done and user journeys, which are clearer for implementation but lose the emotional pull that justifies daily review cycles instead of monthly ones.

- **Competitive simplicity**: The brief states plainly "there is no technical moat here. The advantage is speed of execution." The PRD repeats this but embeds it in a long Vision section, obscuring it. For internal stakeholders, the message that *speed and feedback loops* are the moat (not sophisticated ML or real-time processing) is softer in the PRD.

- **Data-as-a-tool framing**: The brief calls this "a daily intelligence layer on top of the existing BigQuery dataset" — emphasizing that no new data ingestion is required, just consumption of what already exists. The PRD foregrounds the web application and pipeline, downplaying the simplicity that the data already exists and is "treated and available."
