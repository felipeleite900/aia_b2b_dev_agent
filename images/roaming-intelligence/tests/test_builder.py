"""Tests for report builder — verify report assembly and template rendering."""

from unittest.mock import MagicMock

from src.config import ReportConfig
from src.report.builder import build_report


class TestBuildReport:
    """Verify build_report assembles sections into HTML via Jinja2 template."""

    def _make_config(self) -> ReportConfig:
        return ReportConfig(
            project="test-project",
            dataset="roaming_intelligence",
            report_bucket="test-bucket",
            refresh_date="2026-05-22",
        )

    def test_returns_html_string(self) -> None:
        bq = MagicMock()
        config = self._make_config()
        html = build_report(bq=bq, config=config)
        assert isinstance(html, str)
        assert "<html" in html

    def test_includes_refresh_date(self) -> None:
        bq = MagicMock()
        config = self._make_config()
        html = build_report(bq=bq, config=config)
        assert "2026-05-22" in html

    def test_includes_report_title(self) -> None:
        bq = MagicMock()
        config = self._make_config()
        html = build_report(bq=bq, config=config)
        assert "International Roaming Intelligence" in html
