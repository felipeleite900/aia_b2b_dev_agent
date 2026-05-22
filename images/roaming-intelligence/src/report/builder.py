"""Report builder — orchestrates section generation and assembles final HTML.

Each section module returns a Plotly figure or HTML fragment.
Builder assembles them into the Jinja2 base template.
Sections are independent — they don't call each other.
(source: architecture.md — Report Boundary)
"""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

import structlog
from jinja2 import Environment, FileSystemLoader

if TYPE_CHECKING:
    from src.bq_client import BigQueryClient
    from src.config import ReportConfig

logger = structlog.get_logger()

TEMPLATE_DIR = Path(__file__).resolve().parent.parent.parent / "templates"


def build_report(bq: BigQueryClient, config: ReportConfig) -> str:
    """Build the complete HTML report from curated data.

    Args:
        bq: BigQuery client for reading curated views.
        config: Report configuration (dates, project, etc.).

    Returns:
        Complete HTML string ready for GCS upload.
    """
    env = Environment(
        loader=FileSystemLoader(str(TEMPLATE_DIR)),
        autoescape=True,
    )
    template = env.get_template("base.html.j2")

    # Section generation — each section is independent
    carrier_summary_df = bq.query_carrier_quality_summary()
    country_summary_df = bq.query_country_quality_summary()
    quality_log_df = bq.query_quality_log(config.refresh_date)

    sections: dict[str, str] = {}

    # Story 3.2: Executive Summary
    from src.report.sections.executive_summary import generate_executive_summary

    sections["executive-summary"] = generate_executive_summary(
        carrier_df=carrier_summary_df,
        country_df=country_summary_df,
        quality_log_df=quality_log_df,
        refresh_date=config.refresh_date,
    )

    # Story 3.3: Country Overview
    from src.report.sections.country_overview import generate_country_overview

    sections["country-overview"] = generate_country_overview(
        country_df=country_summary_df,
    )

    # Story 3.5: Trend Charts
    from src.report.sections.trend_charts import generate_trend_charts

    trend_df = bq.query_carrier_quality_trend()
    sections["trends"] = generate_trend_charts(trend_df=trend_df)

    # Story 3.4: Carrier Rankings
    from src.report.sections.carrier_rankings import generate_carrier_rankings

    sections["carrier-rankings"] = generate_carrier_rankings(
        carrier_df=carrier_summary_df,
    )

    html = template.render(
        refresh_date=config.refresh_date,
        sections=sections,
    )

    logger.info("report_built", section_count=len(sections))
    return html
