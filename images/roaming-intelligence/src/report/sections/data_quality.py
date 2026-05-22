"""Section 6: Data Quality.

Freshness check result, coverage validation, volume anomaly flags.
Reads from stg_data_quality_log (same exception as executive summary).
(Implemented in Story 3.7)
"""

from __future__ import annotations

from html import escape
from typing import TYPE_CHECKING

import structlog

if TYPE_CHECKING:
    import pandas as pd

logger = structlog.get_logger()


def generate_data_quality(quality_log_df: pd.DataFrame, refresh_date: str) -> str:
    """Generate the data quality HTML section.

    Args:
        quality_log_df: Quality check results (from stg_data_quality_log, qc_* rows).
        refresh_date: Report date string (YYYY-MM-DD).

    Returns:
        HTML string with detailed quality check results.
    """
    logger.info("generating_data_quality", refresh_date=refresh_date)

    if quality_log_df.empty:
        return """
        <h2>Data Quality</h2>
        <p class="no-data">No quality check results available for this date.</p>
        """

    pass_count = int((quality_log_df["status"] == "pass").sum())
    fail_count = int((quality_log_df["status"] == "fail").sum())
    total = pass_count + fail_count

    overall_color = "var(--telus-green)" if fail_count == 0 else "#D32F2F"
    overall_label = "All Checks Passed" if fail_count == 0 else f"{fail_count} Check(s) Failed"

    checks_html = ""
    for _, row in quality_log_df.iterrows():
        step = str(row.get("step_name") or "").replace("qc_", "").replace("_", " ").title()
        status = str(row.get("status") or "")
        message = escape(str(row.get("message") or ""))
        start = str(row.get("start_time") or "")
        end = str(row.get("end_time") or "")

        if status == "pass":
            icon = "&#10003;"  # checkmark
            bg = "#E8F5E9"
            border_color = "#4CAF50"
        else:
            icon = "&#10007;"  # cross
            bg = "#FFEBEE"
            border_color = "#D32F2F"

        checks_html += f"""
        <div style="border-left: 4px solid {border_color}; background: {bg}; padding: 0.75rem 1rem; margin-bottom: 0.75rem; border-radius: 0 4px 4px 0;">
            <div style="font-weight: 600;">{icon} {escape(step)} — <span style="text-transform: uppercase;">{escape(status)}</span></div>
            <div style="font-size: 0.875rem; margin-top: 0.25rem;">{message}</div>
            <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 0.25rem;">
                {escape(start)} → {escape(end)}
            </div>
        </div>
        """

    return f"""
    <h2>Data Quality</h2>
    <p class="section-description">Pipeline quality checks for {escape(refresh_date)}.</p>
    <div class="section-content">
        <div style="text-align: center; margin-bottom: 1rem;">
            <span style="font-size: 1.25rem; font-weight: 700; color: {overall_color};">{overall_label}</span>
            <span style="color: var(--text-secondary);"> ({pass_count}/{total})</span>
        </div>
        {checks_html}
    </div>
    """
