"""Section 4: Trend Charts.

Plotly interactive line charts per KPI showing carrier trends over time.
Uses crt_mv_carrier_quality_trend (up to 90 days).
(Implemented in Story 3.5)
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

_KPI_CONFIG = [
    ("composite_quality_score", "Composite Quality Score", "", True),
    ("kpi_latency_ms", "Latency", " ms", False),
    ("kpi_throughput_kbps", "Throughput", " kbps", True),
    ("kpi_packet_loss_pct", "Packet Loss", "%", False),
    ("kpi_session_success_pct", "Session Success Rate", "%", True),
]


def generate_trend_charts(trend_df: pd.DataFrame) -> str:
    """Generate the trend charts HTML section.

    Args:
        trend_df: Carrier quality trend data (from crt_mv_carrier_quality_trend).

    Returns:
        HTML string with interactive Plotly line charts per KPI.
    """
    logger.info("generating_trend_charts", row_count=len(trend_df))

    if trend_df.empty:
        return """
        <h2>Trend Charts</h2>
        <p class="no-data">No trend data available.</p>
        """

    charts_html = ""
    for col, title, suffix, higher_is_better in _KPI_CONFIG:
        if col not in trend_df.columns:
            continue
        charts_html += _build_kpi_trend_chart(trend_df, col, title, suffix)

    return f"""
    <h2>Trend Charts</h2>
    <p class="section-description">Daily KPI trends across all carriers (up to 90 days). Hover for details.</p>
    <div class="section-content">{charts_html}</div>
    """


def _build_kpi_trend_chart(
    trend_df: pd.DataFrame,
    kpi_col: str,
    title: str,
    suffix: str,
) -> str:
    """Build a single Plotly line chart for one KPI across all carriers."""
    fig = create_base_figure(title)

    carriers = sorted(trend_df["carrier_name"].dropna().unique())
    for carrier in carriers:
        carrier_data = trend_df[trend_df["carrier_name"] == carrier].sort_values("refresh_date")
        if carrier_data[kpi_col].isna().all():
            continue
        fig.add_trace(go.Scatter(
            x=carrier_data["refresh_date"],
            y=carrier_data[kpi_col],
            mode="lines+markers",
            name=carrier,
            hovertemplate=f"%{{x}}<br>{escape(carrier)}: %{{y:.1f}}{suffix}<extra></extra>",
            marker=dict(size=4),
            line=dict(width=2),
        ))

    fig.update_layout(
        xaxis_title="Date",
        yaxis_title=title,
        legend=dict(orientation="h", yanchor="bottom", y=-0.3),
        height=400,
    )

    return f'<div style="margin-bottom: 1.5rem;">{figure_to_html(fig)}</div>'
