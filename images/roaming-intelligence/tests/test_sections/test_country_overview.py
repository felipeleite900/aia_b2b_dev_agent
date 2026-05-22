"""Tests for country overview section."""

import pandas as pd

from src.report.sections.country_overview import generate_country_overview
from tests.fixtures.sample_data import country_quality_summary_df


class TestCountryOverviewHappyPath:
    """Test country overview with complete data."""

    def test_returns_html_string(self) -> None:
        html = generate_country_overview(country_quality_summary_df())
        assert isinstance(html, str)
        assert "<h2>Country Overview</h2>" in html

    def test_contains_all_countries(self) -> None:
        html = generate_country_overview(country_quality_summary_df())
        assert "United States" in html
        assert "United Kingdom" in html
        assert "France" in html
        assert "Germany" in html
        assert "Japan" in html

    def test_contains_table_headers(self) -> None:
        html = generate_country_overview(country_quality_summary_df())
        assert "Avg Quality" in html
        assert "Carriers" in html
        assert "Degraded" in html
        assert "Traffic (MB)" in html

    def test_sorted_by_score_descending(self) -> None:
        html = generate_country_overview(country_quality_summary_df())
        us_pos = html.index("United States")
        jp_pos = html.index("Japan")
        assert us_pos < jp_pos  # US (82.5) before Japan (66.0)

    def test_quality_color_bands(self) -> None:
        html = generate_country_overview(country_quality_summary_df())
        assert "#4CAF50" in html  # Green for high scores (US=82.5)


class TestCountryOverviewEmptyData:
    """Test country overview with empty DataFrame."""

    def test_empty_df(self) -> None:
        html = generate_country_overview(pd.DataFrame())
        assert "No country data available" in html

    def test_no_table_when_empty(self) -> None:
        html = generate_country_overview(pd.DataFrame())
        assert "<thead>" not in html
