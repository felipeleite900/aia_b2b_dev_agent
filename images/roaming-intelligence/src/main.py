"""Entry point for the roaming intelligence report generator.

Pipeline step 6: Query curated BigQuery views → generate HTML report → upload to GCS.
Invoked as a Cloud Run Job by Cloud Workflows.
"""

import sys

import structlog

from src.bq_client import BigQueryClient
from src.config import load_config
from src.gcs_upload import upload_report
from src.report.builder import build_report

logger = structlog.get_logger()


def main() -> None:
    """Generate and upload the daily roaming intelligence report."""
    config = load_config()
    log = logger.bind(
        process="roaming_intelligence",
        refresh_date=config.refresh_date,
    )

    log.info("report_generation_started")

    bq = BigQueryClient(project=config.project, dataset=config.dataset)
    html = build_report(bq=bq, config=config)

    gcs_path = f"reports/{config.refresh_date}/roaming-intelligence.html"
    upload_report(
        bucket_name=config.report_bucket,
        destination_path=gcs_path,
        content=html,
    )

    log.info("report_generation_completed", gcs_path=gcs_path)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        logger.exception("report_generation_failed")
        sys.exit(1)
