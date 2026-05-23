# Dockerfile — International Roaming Intelligence Report Generator
# Runs as Cloud Run Job (Step 6 of the pipeline)
# Queries crt_mv_* views → generates HTML via Plotly + Jinja2 → uploads to GCS
# (source: infrastructure/bi-layer-overview.md §2, engineering/cloud-native-patterns.md)

FROM python:3.12.4-slim AS base

WORKDIR /app

# Copy source and templates
COPY pyproject.toml ./
COPY src/ ./src/
COPY templates/ ./templates/

# Install dependencies (source must be present for setuptools to find the package)
RUN pip install --no-cache-dir .

# Set entrypoint
ENTRYPOINT ["python", "-m", "src.main"]
