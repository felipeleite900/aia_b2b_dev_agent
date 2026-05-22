"""Section 2: Country Overview.

Sortable table of all countries with aggregate quality indicators.
(Implemented in Story 3.3)
"""

from __future__ import annotations

from html import escape
from typing import TYPE_CHECKING

import structlog

if TYPE_CHECKING:
    import pandas as pd

logger = structlog.get_logger()


def generate_country_overview(country_df: pd.DataFrame) -> str:
    """Generate the country overview HTML section.

    Args:
        country_df: Country quality summary (from crt_mv_country_quality_summary).

    Returns:
        HTML string with a sortable country table.
    """
    logger.info("generating_country_overview", country_count=len(country_df))

    if country_df.empty:
        return """
        <h2>Country Overview</h2>
        <p class="no-data">No country data available for this date.</p>
        """

    rows_html = ""
    for _, row in country_df.sort_values("avg_composite_score", ascending=False).iterrows():
        name = escape(str(row.get("country_name") or "Unknown"))
        code = escape(str(row.get("country_code") or ""))
        score = row.get("avg_composite_score")
        score_str = f"{score:.1f}" if score is not None and score == score else "N/A"
        carriers = int(row.get("carrier_count") or 0)
        degraded = int(row.get("degraded_carrier_count") or 0)
        traffic = row.get("total_traffic_mb") or 0
        sessions = int(row.get("total_sessions") or 0)

        # Color score by quality band
        if score is not None and score == score:
            color = "#4CAF50" if score >= 75 else "#FF9800" if score >= 50 else "#D32F2F"
        else:
            color = "var(--text-secondary)"

        degraded_badge = (
            f'<span style="color: #D32F2F; font-weight: 600;">{degraded}</span>'
            if degraded > 0
            else f'<span style="color: var(--telus-green);">{degraded}</span>'
        )

        rows_html += f"""<tr>
            <td><strong>{name}</strong> ({code})</td>
            <td style="color: {color}; font-weight: 600;">{score_str}</td>
            <td>{carriers}</td>
            <td>{degraded_badge}</td>
            <td>{traffic:,.0f}</td>
            <td>{sessions:,}</td>
        </tr>"""

    return f"""
    <h2>Country Overview</h2>
    <p class="section-description">Countries ranked by average composite quality score.</p>
    <div class="section-content">
        <table>
            <thead>
                <tr>
                    <th>Country</th>
                    <th>Avg Quality</th>
                    <th>Carriers</th>
                    <th>Degraded</th>
                    <th>Traffic (MB)</th>
                    <th>Sessions</th>
                </tr>
            </thead>
            <tbody>{rows_html}</tbody>
        </table>
    </div>
    """
