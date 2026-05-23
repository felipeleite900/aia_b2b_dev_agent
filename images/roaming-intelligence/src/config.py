"""Environment configuration for the report generator.

Reads GCP project, bucket name, dataset, and refresh date from
environment variables set by the Cloud Run Job runtime.
"""

import os
import re
from dataclasses import dataclass
from datetime import date, timedelta


@dataclass(frozen=True)
class ReportConfig:
    """Immutable configuration for a single report generation run."""

    project: str
    dataset: str
    report_bucket: str
    refresh_date: str


def load_config() -> ReportConfig:
    """Load configuration from environment variables.

    Returns:
        ReportConfig with all required settings.

    Raises:
        EnvironmentError: If required environment variables are missing.
    """
    refresh_date = _require_env(
        "REFRESH_DATE",
        default=(date.today() - timedelta(days=1)).isoformat(),
    )
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", refresh_date):
        msg = f"REFRESH_DATE must be YYYY-MM-DD format, got: {refresh_date!r}"
        raise EnvironmentError(msg)

    return ReportConfig(
        project=_require_env("GCP_PROJECT"),
        dataset=_require_env("DATASET", default="roaming_intelligence"),
        report_bucket=_require_env("REPORT_BUCKET"),
        refresh_date=refresh_date,
    )


def _require_env(key: str, *, default: str | None = None) -> str:
    """Get an environment variable or raise if missing and no default."""
    value = os.environ.get(key, default)
    if not value:
        msg = f"Required environment variable {key} is not set or is empty"
        raise EnvironmentError(msg)
    return value
