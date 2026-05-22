"""Tests for trend charts section."""

import pandas as pd

from src.report.sections.trend_charts import generate_trend_charts
from tests.fixtures.sample_data import carrier_quality_trend_df


class TestTrendChartsHappyPath:
    """Test trend charts with complete data."""

    def test_returns_html_string(self) -> None:
        html = generate_trend_charts(carrier_quality_trend_df())
        assert isinstance(html, str)
        assert "<h2>Trend Charts</h2>" in html

    def test_contains_plotly_divs(self) -> None:
        html = generate_trend_charts(carrier_quality_trend_df())
        assert "plotly" in html.lower()

    def test_contains_all_kpi_charts(self) -> None:
        html = generate_trend_charts(carrier_quality_trend_df())
        assert "Composite Quality Score" in html
        assert "Latency" in html
        assert "Throughput" in html
        assert "Packet Loss" in html
        assert "Session Success Rate" in html

    def test_contains_carrier_names(self) -> None:
        html = generate_trend_charts(carrier_quality_trend_df())
        assert "AT&amp;T" in html or "AT\\u0026T" in html  # escaped in HTML or JSON
        assert "T-Mobile US" in html
        assert "Verizon" in html


class TestTrendChartsEmptyData:
    """Test trend charts with empty DataFrame."""

    def test_empty_df(self) -> None:
        html = generate_trend_charts(pd.DataFrame())
        assert "No trend data available" in html

    def test_no_plotly_when_empty(self) -> None:
        html = generate_trend_charts(pd.DataFrame())
        assert "plotly" not in html.lower()
