"""Tests for BigQuery client — mock BQ responses, verify query construction."""

from unittest.mock import MagicMock, patch

from src.bq_client import BigQueryClient


class TestBigQueryClient:
    """Verify BigQueryClient reads only from crt_mv_* views."""

    def test_query_carrier_quality_summary_uses_correct_view(self) -> None:
        with patch("src.bq_client.bigquery.Client") as mock_bq:
            mock_client = MagicMock()
            mock_bq.return_value = mock_client
            mock_client.query.return_value.to_dataframe.return_value = MagicMock()

            client = BigQueryClient(project="test-project", dataset="roaming_intelligence")
            client.query_carrier_quality_summary()

            query_arg = mock_client.query.call_args[0][0]
            assert "crt_mv_carrier_quality_summary" in query_arg
            assert "test-project.roaming_intelligence" in query_arg

    def test_query_country_quality_summary_uses_correct_view(self) -> None:
        with patch("src.bq_client.bigquery.Client") as mock_bq:
            mock_client = MagicMock()
            mock_bq.return_value = mock_client
            mock_client.query.return_value.to_dataframe.return_value = MagicMock()

            client = BigQueryClient(project="test-project", dataset="roaming_intelligence")
            client.query_country_quality_summary()

            query_arg = mock_client.query.call_args[0][0]
            assert "crt_mv_country_quality_summary" in query_arg
            assert "test-project.roaming_intelligence" in query_arg

    def test_query_carrier_quality_trend_uses_correct_view(self) -> None:
        with patch("src.bq_client.bigquery.Client") as mock_bq:
            mock_client = MagicMock()
            mock_bq.return_value = mock_client
            mock_client.query.return_value.to_dataframe.return_value = MagicMock()

            client = BigQueryClient(project="test-project", dataset="roaming_intelligence")
            client.query_carrier_quality_trend()

            query_arg = mock_client.query.call_args[0][0]
            assert "crt_mv_carrier_quality_trend" in query_arg

    def test_query_carrier_usage_summary_uses_correct_view(self) -> None:
        with patch("src.bq_client.bigquery.Client") as mock_bq:
            mock_client = MagicMock()
            mock_bq.return_value = mock_client
            mock_client.query.return_value.to_dataframe.return_value = MagicMock()

            client = BigQueryClient(project="test-project", dataset="roaming_intelligence")
            client.query_carrier_usage_summary()

            query_arg = mock_client.query.call_args[0][0]
            assert "crt_mv_carrier_usage_summary" in query_arg
