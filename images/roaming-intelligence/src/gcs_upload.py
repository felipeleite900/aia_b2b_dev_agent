"""Upload generated HTML report to GCS.

Output path convention: reports/{YYYY-MM-DD}/roaming-intelligence.html
Separate bucket per environment (bi-stg / bi-srv).
"""

import structlog
from google.cloud import storage

logger = structlog.get_logger()


def upload_report(
    bucket_name: str,
    destination_path: str,
    content: str,
) -> str:
    """Upload HTML content to a GCS bucket.

    Args:
        bucket_name: Target GCS bucket name (env-specific).
        destination_path: Object path within the bucket.
        content: HTML string to upload.

    Returns:
        The gs:// URI of the uploaded object.
    """
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(destination_path)
    blob.upload_from_string(content, content_type="text/html")

    uri = f"gs://{bucket_name}/{destination_path}"
    logger.info("report_uploaded", uri=uri, size_bytes=len(content.encode()))
    return uri
