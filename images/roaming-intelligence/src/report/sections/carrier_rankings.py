"""Section 3: Carrier Rankings by Country.

Per-country carriers ranked by composite score, individual KPIs visible,
steered-to carrier flagged with is_steered indicator.
(Implemented in Story 3.4)
"""

from __future__ import annotations

from html import escape
from typing import TYPE_CHECKING

import structlog

if TYPE_CHECKING:
    import pandas as pd

logger = structlog.get_logger()


def generate_carrier_rankings(carrier_df: pd.DataFrame) -> str:
    """Generate the carrier rankings HTML section.

    Args:
        carrier_df: Carrier quality summary (from crt_mv_carrier_quality_summary).

    Returns:
        HTML string with per-country carrier ranking tables.
    """
    logger.info("generating_carrier_rankings", carrier_count=len(carrier_df))

    if carrier_df.empty:
        return """
        <h2>Carrier Rankings</h2>
        <p class="no-data">No carrier data available for this date.</p>
        """

    countries = sorted(carrier_df["country_name"].dropna().unique())
    country_sections = ""

    for country in countries:
        country_carriers = carrier_df[carrier_df["country_name"] == country].sort_values(
            "composite_quality_score", ascending=False
        )
        country_sections += _build_country_table(country, country_carriers)

    return f"""
    <h2>Carrier Rankings</h2>
    <p class="section-description">Carriers ranked by composite quality score within each country. Steered-to carriers marked with a label.</p>
    <div class="section-content">{country_sections}</div>
    """


def _build_country_table(country: str, carriers_df: pd.DataFrame) -> str:
    """Build a ranking table for a single country."""
    rows_html = ""
    for rank, (_, row) in enumerate(carriers_df.iterrows(), 1):
        name = escape(str(row.get("carrier_name") or "Unknown"))
        score = row.get("composite_quality_score")
        score_str = f"{score:.1f}" if score is not None and score == score else "N/A"
        latency = row.get("kpi_latency_ms")
        throughput = row.get("kpi_throughput_kbps")
        packet_loss = row.get("kpi_packet_loss_pct")
        session_success = row.get("kpi_session_success_pct")
        is_steered = row.get("is_steered", False)
        degraded = row.get("degradation_flag", False)

        steered_badge = ' <span style="background: var(--telus-purple); color: white; padding: 1px 6px; border-radius: 3px; font-size: 0.75rem;">STEERED</span>' if is_steered else ""
        degraded_badge = ' <span style="background: #D32F2F; color: white; padding: 1px 6px; border-radius: 3px; font-size: 0.75rem;">DEGRADED</span>' if degraded else ""

        def _fmt(val: object, suffix: str = "") -> str:
            if val is None or val != val:  # NaN check
                return "N/A"
            return f"{val:.1f}{suffix}"

        rows_html += f"""<tr>
            <td>{rank}</td>
            <td>{name}{steered_badge}{degraded_badge}</td>
            <td style="font-weight: 600;">{score_str}</td>
            <td>{_fmt(latency, ' ms')}</td>
            <td>{_fmt(throughput, ' kbps')}</td>
            <td>{_fmt(packet_loss, '%')}</td>
            <td>{_fmt(session_success, '%')}</td>
        </tr>"""

    return f"""
    <h3 style="margin: 1.5rem 0 0.5rem;">{escape(country)}</h3>
    <table>
        <thead>
            <tr>
                <th>#</th>
                <th>Carrier</th>
                <th>Quality Score</th>
                <th>Latency</th>
                <th>Throughput</th>
                <th>Packet Loss</th>
                <th>Session Success</th>
            </tr>
        </thead>
        <tbody>{rows_html}</tbody>
    </table>
    """
