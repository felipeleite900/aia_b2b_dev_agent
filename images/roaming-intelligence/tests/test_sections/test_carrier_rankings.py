"""Tests for carrier rankings section."""

import pandas as pd

from src.report.sections.carrier_rankings import generate_carrier_rankings
from tests.fixtures.sample_data import carrier_quality_summary_df


class TestCarrierRankingsHappyPath:
    """Test carrier rankings with complete data."""

    def test_returns_html_string(self) -> None:
        html = generate_carrier_rankings(carrier_quality_summary_df())
        assert isinstance(html, str)
        assert "<h2>Carrier Rankings</h2>" in html

    def test_contains_all_countries_as_sections(self) -> None:
        html = generate_carrier_rankings(carrier_quality_summary_df())
        assert "United States" in html
        assert "United Kingdom" in html
        assert "France" in html
        assert "Germany" in html
        assert "Japan" in html

    def test_contains_carrier_names(self) -> None:
        html = generate_carrier_rankings(carrier_quality_summary_df())
        assert "AT&amp;T" in html  # html escaped
        assert "Vodafone UK" in html
        assert "NTT Docomo" in html

    def test_steered_carrier_badge(self) -> None:
        html = generate_carrier_rankings(carrier_quality_summary_df())
        assert "STEERED" in html

    def test_degraded_carrier_badge(self) -> None:
        html = generate_carrier_rankings(carrier_quality_summary_df())
        assert "DEGRADED" in html

    def test_kpi_columns_present(self) -> None:
        html = generate_carrier_rankings(carrier_quality_summary_df())
        assert "Latency" in html
        assert "Throughput" in html
        assert "Packet Loss" in html
        assert "Session Success" in html

    def test_ranked_by_score(self) -> None:
        html = generate_carrier_rankings(carrier_quality_summary_df())
        # AT&T (steered, highest score in US) should appear before T-Mobile US
        us_section = html[html.index("United States"):]
        att_pos = us_section.index("AT&amp;T")
        tmobile_pos = us_section.index("T-Mobile US")
        assert att_pos < tmobile_pos


class TestCarrierRankingsEmptyData:
    """Test carrier rankings with empty DataFrame."""

    def test_empty_df(self) -> None:
        html = generate_carrier_rankings(pd.DataFrame())
        assert "No carrier data available" in html
