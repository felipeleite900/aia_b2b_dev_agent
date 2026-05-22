"""Tests for executive summary section."""

import pandas as pd
import pytest

from src.report.sections.executive_summary import generate_executive_summary
from tests.fixtures.sample_data import (
    carrier_quality_summary_df,
    country_quality_summary_df,
    quality_log_df,
    quality_log_with_failure_df,
)


class TestExecutiveSummaryHappyPath:
    """Test executive summary with complete data."""

    def test_returns_html_string(self) -> None:
        html = generate_executive_summary(
            carrier_quality_summary_df(),
            country_quality_summary_df(),
            quality_log_df(),
            "2026-05-21",
        )
        assert isinstance(html, str)
        assert "<h2>Executive Summary</h2>" in html

    def test_contains_stat_cards(self) -> None:
        html = generate_executive_summary(
            carrier_quality_summary_df(),
            country_quality_summary_df(),
            quality_log_df(),
            "2026-05-21",
        )
        assert "Countries" in html
        assert "Carriers" in html
        assert "Avg Quality Score" in html
        assert "Degradation Alerts" in html

    def test_country_count(self) -> None:
        html = generate_executive_summary(
            carrier_quality_summary_df(),
            country_quality_summary_df(),
            quality_log_df(),
            "2026-05-21",
        )
        assert ">5<" in html  # 5 countries

    def test_carrier_count(self) -> None:
        html = generate_executive_summary(
            carrier_quality_summary_df(),
            country_quality_summary_df(),
            quality_log_df(),
            "2026-05-21",
        )
        assert ">15<" in html  # 15 carriers

    def test_degraded_count(self) -> None:
        html = generate_executive_summary(
            carrier_quality_summary_df(),
            country_quality_summary_df(),
            quality_log_df(),
            "2026-05-21",
        )
        assert ">3<" in html  # 3 degraded carriers

    def test_quality_checks_table(self) -> None:
        html = generate_executive_summary(
            carrier_quality_summary_df(),
            country_quality_summary_df(),
            quality_log_df(),
            "2026-05-21",
        )
        assert "Freshness" in html
        assert "Coverage" in html
        assert "Volume" in html
        assert "PASS" in html

    def test_degradation_alerts_list(self) -> None:
        html = generate_executive_summary(
            carrier_quality_summary_df(),
            country_quality_summary_df(),
            quality_log_df(),
            "2026-05-21",
        )
        assert "Verizon" in html
        assert "SFR" in html
        assert "O2 DE" in html


class TestExecutiveSummaryEmptyData:
    """Test executive summary with empty DataFrames."""

    def test_empty_carrier_df(self) -> None:
        html = generate_executive_summary(
            pd.DataFrame(),
            country_quality_summary_df(),
            quality_log_df(),
            "2026-05-21",
        )
        assert "No data available" in html

    def test_empty_quality_log(self) -> None:
        html = generate_executive_summary(
            carrier_quality_summary_df(),
            country_quality_summary_df(),
            pd.DataFrame(),
            "2026-05-21",
        )
        assert "No quality check results available" in html


class TestExecutiveSummaryNoDegradation:
    """Test executive summary when no carriers are degraded."""

    def test_no_degradation_message(self) -> None:
        df = carrier_quality_summary_df()
        df["degradation_flag"] = False
        html = generate_executive_summary(
            df,
            country_quality_summary_df(),
            quality_log_df(),
            "2026-05-21",
        )
        assert "No degradation alerts" in html


class TestExecutiveSummaryFailedChecks:
    """Test executive summary with failed quality checks."""

    def test_failed_check_highlighted(self) -> None:
        html = generate_executive_summary(
            carrier_quality_summary_df(),
            country_quality_summary_df(),
            quality_log_with_failure_df(),
            "2026-05-21",
        )
        assert "FAIL" in html
        assert "Coverage drop" in html
