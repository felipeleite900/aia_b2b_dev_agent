"""Shared Plotly graph_objects helpers for report sections.

All chart generation uses plotly.graph_objects — NOT plotly.express.
(source: architecture.md — Python Code Conventions)
"""

from __future__ import annotations

import plotly.graph_objects as go


def create_base_figure(title: str) -> go.Figure:
    """Create a consistently styled base figure.

    Args:
        title: Chart title.

    Returns:
        A Plotly Figure with standard layout settings.
    """
    fig = go.Figure()
    fig.update_layout(
        title=title,
        template="plotly_white",
        font=dict(family="Arial, sans-serif"),
        margin=dict(l=60, r=30, t=60, b=40),
    )
    return fig


def figure_to_html(fig: go.Figure) -> str:
    """Convert a Plotly figure to an embeddable HTML div.

    Args:
        fig: Plotly figure to convert.

    Returns:
        HTML string with the chart div (no full page wrapper).
    """
    return fig.to_html(full_html=False, include_plotlyjs="cdn")
