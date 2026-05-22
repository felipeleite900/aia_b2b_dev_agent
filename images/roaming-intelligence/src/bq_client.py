"""BigQuery client for reading curated materialized views.

Reads only from crt_mv_* views — never from stg_* or raw_* tables.
This is the data boundary between the SQL pipeline and the Python report.
(source: architecture.md — Architectural Boundaries)
"""

from __future__ import annotations

from typing import TYPE_CHECKING

import structlog
from google.cloud import bigquery

if TYPE_CHECKING:
    import pandas as pd

logger = structlog.get_logger()


class BigQueryClient:
    """Read-only client for curated roaming intelligence views."""

    def __init__(self, project: str, dataset: str) -> None:
        self._client = bigquery.Client(project=project)
        self._dataset = dataset
        self._project = project

    def query_carrier_quality_summary(self) -> pd.DataFrame:
        """Read crt_mv_carrier_quality_summary."""
        return self._query_view("crt_mv_carrier_quality_summary")

    def query_country_quality_summary(self) -> pd.DataFrame:
        """Read crt_mv_country_quality_summary."""
        return self._query_view("crt_mv_country_quality_summary")

    def query_carrier_quality_trend(self) -> pd.DataFrame:
        """Read crt_mv_carrier_quality_trend."""
        return self._query_view("crt_mv_carrier_quality_trend")

    def query_carrier_usage_summary(self) -> pd.DataFrame:
        """Read crt_mv_carrier_usage_summary."""
        return self._query_view("crt_mv_carrier_usage_summary")

    def query_quality_log(self, refresh_date: str) -> pd.DataFrame:
        """Read quality check results from stg_data_quality_log.

        Exception to the crt_mv_* boundary: executive summary and data quality
        sections need pipeline metadata from the quality log.

        Args:
            refresh_date: Date string (YYYY-MM-DD) to filter results.

        Returns:
            DataFrame with quality check rows for the given date.
        """
        query = (
            f"SELECT * FROM `{self._project}.{self._dataset}.stg_data_quality_log` "
            "WHERE refresh_date = @refresh_date AND step_name LIKE 'qc_%'"
        )
        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("refresh_date", "DATE", refresh_date),
            ]
        )
        log = logger.bind(view="stg_data_quality_log", refresh_date=refresh_date)
        log.info("bq_query_started")
        df = self._client.query(query, job_config=job_config).to_dataframe()
        log.info("bq_query_completed", row_count=len(df))
        return df

    def _query_view(self, view_name: str) -> pd.DataFrame:
        """Execute a SELECT * on a curated view and return as DataFrame."""
        query = f"SELECT * FROM `{self._project}.{self._dataset}.{view_name}`"
        log = logger.bind(view=view_name)
        log.info("bq_query_started")
        df = self._client.query(query).to_dataframe()
        log.info("bq_query_completed", row_count=len(df))
        return df
