"""Section 1: Executive Summary.

Displays data freshness timestamp, country/carrier coverage stats,
degradation alerts, and data quality flags.
(Implemented in Story 3.2)
"""

from __future__ import annotations

from html import escape
from typing import TYPE_CHECKING

import structlog

if TYPE_CHECKING:
    import pandas as pd

logger = structlog.get_logger()


def generate_executive_summary(
    carrier_df: pd.DataFrame,
    country_df: pd.DataFrame,
    quality_log_df: pd.DataFrame,
    refresh_date: str,
) -> str:
    """Generate the executive summary HTML section.

    Args:
        carrier_df: Carrier quality summary (from crt_mv_carrier_quality_summary).
        country_df: Country quality summary (from crt_mv_country_quality_summary).
        quality_log_df: Quality check results (from stg_data_quality_log, qc_* rows).
        refresh_date: Report date string (YYYY-MM-DD).

    Returns:
        HTML string with stat cards, quality check results, and degradation alerts.
    """
    logger.info("generating_executive_summary", refresh_date=refresh_date)

    stat_cards = _build_stat_cards(carrier_df, country_df)
    quality_table = _build_quality_checks(quality_log_df)
    degradation_alerts = _build_degradation_alerts(carrier_df)

    return f"""
    <h2>Executive Summary</h2>
    <p class="section-description">Report date: {refresh_date}</p>
    <div class="section-content">
        {stat_cards}
        {quality_table}
        {degradation_alerts}
    </div>
    """


def _build_stat_cards(carrier_df: pd.DataFrame, country_df: pd.DataFrame) -> str:
    """Build the 2x2 stat card grid."""
    if carrier_df.empty:
        return '<p class="no-data">No data available for this date.</p>'

    country_count = len(country_df) if not country_df.empty else 0
    carrier_count = len(carrier_df)

    avg_score = carrier_df["composite_quality_score"].mean()
    import pandas as _pd
    avg_score_str = "N/A" if _pd.isna(avg_score) else f"{avg_score:.1f}"

    degraded_count = 0
    if "degradation_flag" in carrier_df.columns:
        degraded_count = int(carrier_df["degradation_flag"].fillna(False).sum())

    return f"""
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1.5rem;">
        <div class="stat-card" style="background: var(--bg-light); padding: 1rem; border-radius: 4px; text-align: center;">
            <div style="font-size: 2rem; font-weight: 700; color: var(--telus-purple);">{country_count}</div>
            <div style="font-size: 0.875rem; color: var(--text-secondary);">Countries</div>
        </div>
        <div class="stat-card" style="background: var(--bg-light); padding: 1rem; border-radius: 4px; text-align: center;">
            <div style="font-size: 2rem; font-weight: 700; color: var(--telus-purple);">{carrier_count}</div>
            <div style="font-size: 0.875rem; color: var(--text-secondary);">Carriers</div>
        </div>
        <div class="stat-card" style="background: var(--bg-light); padding: 1rem; border-radius: 4px; text-align: center;">
            <div style="font-size: 2rem; font-weight: 700; color: var(--telus-purple);">{avg_score_str}</div>
            <div style="font-size: 0.875rem; color: var(--text-secondary);">Avg Quality Score</div>
        </div>
        <div class="stat-card" style="background: var(--bg-light); padding: 1rem; border-radius: 4px; text-align: center;">
            <div style="font-size: 2rem; font-weight: 700; color: {'#D32F2F' if degraded_count > 0 else 'var(--telus-green)'};">{degraded_count}</div>
            <div style="font-size: 0.875rem; color: var(--text-secondary);">Degradation Alerts</div>
        </div>
    </div>
    """


def _build_quality_checks(quality_log_df: pd.DataFrame) -> str:
    """Build the quality check results table."""
    if quality_log_df.empty:
        return '<p class="no-data">No quality check results available.</p>'

    rows_html = ""
    for _, row in quality_log_df.iterrows():
        status = str(row.get("status") or "")
        step = str(row.get("step_name") or "").replace("qc_", "").replace("_", " ").title()
        message = escape(str(row.get("message") or ""))
        style = 'color: #D32F2F; font-weight: 600;' if status == "fail" else 'color: var(--telus-green); font-weight: 600;'
        rows_html += f"<tr><td>{escape(step)}</td><td style='{style}'>{escape(status.upper())}</td><td>{message}</td></tr>"

    return f"""
    <h3 style="margin: 1rem 0 0.5rem;">Data Quality Checks</h3>
    <table>
        <thead><tr><th>Check</th><th>Status</th><th>Details</th></tr></thead>
        <tbody>{rows_html}</tbody>
    </table>
    """


def _build_degradation_alerts(carrier_df: pd.DataFrame) -> str:
    """Build the degradation alert list."""
    if carrier_df.empty or "degradation_flag" not in carrier_df.columns:
        return ""

    degraded = carrier_df[carrier_df["degradation_flag"].fillna(False)]

    if degraded.empty:
        return '<p style="color: var(--telus-green); margin-top: 1rem;"><strong>No degradation alerts</strong> — all carriers within normal thresholds.</p>'

    alerts = degraded.head(10)
    items = ""
    for _, row in alerts.iterrows():
        carrier = escape(str(row.get("carrier_name") or "Unknown"))
        country = escape(str(row.get("country_name") or "Unknown"))
        items += f"<li><strong>{carrier}</strong> ({country})</li>"

    remaining = len(degraded) - 10
    overflow = f"<li><em>and {remaining} more...</em></li>" if remaining > 0 else ""

    return f"""
    <h3 style="margin: 1rem 0 0.5rem; color: #D32F2F;">Degradation Alerts ({len(degraded)})</h3>
    <ul style="padding-left: 1.5rem;">{items}{overflow}</ul>
    """
