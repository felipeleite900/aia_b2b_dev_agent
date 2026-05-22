---
title: 'Build Historical Backfill Procedure'
type: 'feature'
created: '2026-05-22'
status: 'done'
route: 'one-shot'
baseline_commit: '659635c'
---

## Intent

**Problem:** No mechanism exists for initial 90-day data load or recovery of missed dates. The daily pipeline processes one date at a time.

**Approach:** Implement `sp_backfill_historical(start_date, end_date)` that loops oldest-first, calling the full pipeline chain (refresh → composite → degradation → quality checks) per date with continue-on-error semantics. Curate views run once after all dates complete. Failed dates are logged individually and can be re-run.

## Suggested Review Order

- Date loop with per-date EXCEPTION handler (continue-on-error)
  [`sp_backfill_historical.sql:50`](../../stacks/roaming-intelligence/sql/backfill/sp_backfill_historical.sql#L50)

- Curate called once after loop with separate failure tracking
  [`sp_backfill_historical.sql:76`](../../stacks/roaming-intelligence/sql/backfill/sp_backfill_historical.sql#L76)

- Summary log: dates processed/failed + curate status reflected
  [`sp_backfill_historical.sql:90`](../../stacks/roaming-intelligence/sql/backfill/sp_backfill_historical.sql#L90)
