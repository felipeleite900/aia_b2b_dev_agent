"""Section 5: Usage Analytics.

Traffic volume, session count, subscriber count per carrier.
Traffic share percentages with <1% carriers grouped under "Other".
(Implemented in Story 3.6)
"""

from __future__ import annotations

from html import escape
from typing import TYPE_CHECKING

import plotly.graph_objects as go
import structlog

from src.report.charts import create_base_figure, figure_to_html

if TYPE_CHECKING:
    import pandas as pd

logger = structlog.get_logger()


def generate_usage_analytics(usage_df: pd.DataFrame) -> str:
    """Generate the usage analytics HTML section.

    Args:
        usage_df: Carrier usage summary (from crt_mv_carrier_usage_summary).

    Returns:
        HTML string with usage table and traffic share pie chart.
    """
    logger.info("generating_usage_analytics", carrier_count=len(usage_df))

    if usage_df.empty:
        return """
        <h2>Usage Analytics</h2>
        <p class="no-data">No usage data available for this date.</p>
        """

    table_html = _build_usage_table(usage_df)
    pie_html = _build_traffic_share_chart(usage_df)

    return f"""
    <h2>Usage Analytics</h2>
    <p class="section-description">Traffic volume, sessions, and subscriber counts per carrier. Carriers with &lt;1% traffic share grouped as "Other".</p>
    <div class="section-content">
        {pie_html}
        {table_html}
    </div>
    """


def _build_usage_table(usage_df: pd.DataFrame) -> str:
    """Build the usage metrics table sorted by traffic volume."""
    sorted_df = usage_df.sort_values("traffic_volume_mb", ascending=False)

    rows_html = ""
    for _, row in sorted_df.iterrows():
        name = escape(str(row.get("carrier_name") or "Unknown"))
        country = escape(str(row.get("country_code") or ""))
        traffic = row.get("traffic_volume_mb") or 0
        sessions = int(row.get("session_count") or 0)
        subscribers = int(row.get("subscriber_count") or 0)
        share = row.get("traffic_share_pct") or 0
        is_minor = row.get("is_minor_carrier", False)

        minor_style = ' style="color: var(--text-secondary); font-style: italic;"' if is_minor else ""

        rows_html += f"""<tr{minor_style}>
            <td>{name} ({country})</td>
            <td>{traffic:,.0f}</td>
            <td>{sessions:,}</td>
            <td>{subscribers:,}</td>
            <td>{share:.1f}%</td>
        </tr>"""

    return f"""
    <table>
        <thead>
            <tr><th>Carrier</th><th>Traffic (MB)</th><th>Sessions</th><th>Subscribers</th><th>Share</th></tr>
        </thead>
        <tbody>{rows_html}</tbody>
    </table>
    """


def _build_traffic_share_chart(usage_df: pd.DataFrame) -> str:
    """Build a Plotly pie chart of traffic share, grouping <1% as Other."""
    major = usage_df[~usage_df.get("is_minor_carrier", False).fillna(False)]
    minor = usage_df[usage_df.get("is_minor_carrier", False).fillna(False)]

    labels = [str(r.get("carrier_name", "Unknown")) for _, r in major.iterrows()]
    values = [float(r.get("traffic_volume_mb") or 0) for _, r in major.iterrows()]

    if not minor.empty:
        labels.append("Other (<1% share)")
        values.append(float(minor["traffic_volume_mb"].sum()))

    if not values:
        return ""

    fig = create_base_figure("Traffic Share by Carrier")
    fig.add_trace(go.Pie(
        labels=labels,
        values=values,
        textinfo="label+percent",
        hovertemplate="%{label}: %{value:,.0f} MB (%{percent})<extra></extra>",
    ))
    fig.update_layout(height=400, showlegend=False)

    return f'<div style="margin-bottom: 1.5rem;">{figure_to_html(fig)}</div>'
