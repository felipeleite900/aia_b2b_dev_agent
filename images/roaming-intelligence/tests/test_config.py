"""Tests for config module — verify env var loading and defaults."""

import os
from unittest.mock import patch

import pytest

from src.config import ReportConfig, load_config


class TestLoadConfig:
    """Verify configuration loading from environment variables."""

    def test_loads_all_required_vars(self) -> None:
        env = {
            "GCP_PROJECT": "test-project",
            "REPORT_BUCKET": "test-bucket",
            "DATASET": "roaming_intelligence",
            "REFRESH_DATE": "2026-05-22",
        }
        with patch.dict(os.environ, env, clear=True):
            config = load_config()

        assert config.project == "test-project"
        assert config.report_bucket == "test-bucket"
        assert config.dataset == "roaming_intelligence"
        assert config.refresh_date == "2026-05-22"

    def test_uses_default_dataset(self) -> None:
        env = {"GCP_PROJECT": "p", "REPORT_BUCKET": "b"}
        with patch.dict(os.environ, env, clear=True):
            config = load_config()
        assert config.dataset == "roaming_intelligence"

    def test_raises_on_missing_required_var(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            with pytest.raises(EnvironmentError, match="GCP_PROJECT"):
                load_config()

    def test_raises_on_empty_required_var(self) -> None:
        env = {"GCP_PROJECT": "", "REPORT_BUCKET": "b"}
        with patch.dict(os.environ, env, clear=True):
            with pytest.raises(EnvironmentError, match="GCP_PROJECT"):
                load_config()

    def test_raises_on_invalid_refresh_date_format(self) -> None:
        env = {"GCP_PROJECT": "p", "REPORT_BUCKET": "b", "REFRESH_DATE": "not-a-date"}
        with patch.dict(os.environ, env, clear=True):
            with pytest.raises(EnvironmentError, match="YYYY-MM-DD"):
                load_config()

    def test_config_is_immutable(self) -> None:
        config = ReportConfig(
            project="p", dataset="d", report_bucket="b", refresh_date="2026-01-01"
        )
        with pytest.raises(AttributeError):
            config.project = "other"  # type: ignore[misc]
