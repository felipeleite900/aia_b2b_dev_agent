"""Realistic mock data for testing — ~5 countries, ~15 carriers.

Provides sample DataFrames matching the crt_mv_* view schemas.
Used by test_bq_client.py and test_sections/*.
"""

import pandas as pd

SAMPLE_COUNTRIES = [
    {"country_name": "United States", "country_code": "US"},
    {"country_name": "United Kingdom", "country_code": "GB"},
    {"country_name": "France", "country_code": "FR"},
    {"country_name": "Germany", "country_code": "DE"},
    {"country_name": "Japan", "country_code": "JP"},
]

SAMPLE_CARRIERS = [
    {"carrier_name": "AT&T", "mcc": "310", "mnc": "410", "country_code": "US", "is_steered": True},
    {"carrier_name": "T-Mobile US", "mcc": "310", "mnc": "260", "country_code": "US", "is_steered": False},
    {"carrier_name": "Verizon", "mcc": "311", "mnc": "480", "country_code": "US", "is_steered": False},
    {"carrier_name": "Vodafone UK", "mcc": "234", "mnc": "15", "country_code": "GB", "is_steered": True},
    {"carrier_name": "EE", "mcc": "234", "mnc": "30", "country_code": "GB", "is_steered": False},
    {"carrier_name": "Three UK", "mcc": "234", "mnc": "20", "country_code": "GB", "is_steered": False},
    {"carrier_name": "Orange FR", "mcc": "208", "mnc": "01", "country_code": "FR", "is_steered": True},
    {"carrier_name": "SFR", "mcc": "208", "mnc": "10", "country_code": "FR", "is_steered": False},
    {"carrier_name": "Bouygues", "mcc": "208", "mnc": "20", "country_code": "FR", "is_steered": False},
    {"carrier_name": "T-Mobile DE", "mcc": "262", "mnc": "01", "country_code": "DE", "is_steered": True},
    {"carrier_name": "Vodafone DE", "mcc": "262", "mnc": "02", "country_code": "DE", "is_steered": False},
    {"carrier_name": "O2 DE", "mcc": "262", "mnc": "03", "country_code": "DE", "is_steered": False},
    {"carrier_name": "NTT Docomo", "mcc": "440", "mnc": "10", "country_code": "JP", "is_steered": True},
    {"carrier_name": "KDDI", "mcc": "440", "mnc": "50", "country_code": "JP", "is_steered": False},
    {"carrier_name": "SoftBank", "mcc": "440", "mnc": "20", "country_code": "JP", "is_steered": False},
]


def carrier_quality_summary_df() -> pd.DataFrame:
    """Sample carrier quality summary matching crt_mv_carrier_quality_summary schema."""
    rows = []
    country_map = {c["country_code"]: c["country_name"] for c in SAMPLE_COUNTRIES}

    for i, c in enumerate(SAMPLE_CARRIERS):
        rows.append({
            "refresh_date": "2026-05-21",
            "country_name": country_map.get(c["country_code"], "Unknown"),
            "country_code": c["country_code"],
            "carrier_name": c["carrier_name"],
            "mcc": c["mcc"],
            "mnc": c["mnc"],
            "is_steered": c["is_steered"],
            "kpi_latency_ms": 45.0 + i * 3,
            "kpi_throughput_kbps": 2500.0 - i * 100,
            "kpi_packet_loss_pct": 0.5 + i * 0.2,
            "kpi_session_success_pct": 98.0 - i * 0.3,
            "norm_latency": 85.0 - i * 2,
            "norm_throughput": 80.0 - i * 1.5,
            "norm_packet_loss": 90.0 - i * 2,
            "norm_session_success": 88.0 - i * 1,
            "composite_quality_score": 85.0 - i * 1.5,
            "degradation_flag": i in (2, 7, 11),  # Verizon, SFR, O2 DE degraded
            "degradation_details": None,
            "traffic_volume_mb": 5000.0 - i * 200,
            "session_count": 100000 - i * 5000,
            "subscriber_count": 50000 - i * 2000,
            "traffic_share_pct": 8.0 - i * 0.3,
            "is_minor_carrier": False,
        })
    return pd.DataFrame(rows)


def country_quality_summary_df() -> pd.DataFrame:
    """Sample country quality summary matching crt_mv_country_quality_summary schema."""
    rows = [
        {"refresh_date": "2026-05-21", "country_name": "United States", "country_code": "US",
         "carrier_count": 3, "avg_composite_score": 82.5, "degraded_carrier_count": 1,
         "avg_latency_ms": 48.0, "avg_throughput_kbps": 2400.0, "avg_packet_loss_pct": 0.7,
         "avg_session_success_pct": 97.7, "total_traffic_mb": 14100.0,
         "total_sessions": 285000, "total_subscribers": 142000},
        {"refresh_date": "2026-05-21", "country_name": "United Kingdom", "country_code": "GB",
         "carrier_count": 3, "avg_composite_score": 78.0, "degraded_carrier_count": 0,
         "avg_latency_ms": 55.0, "avg_throughput_kbps": 2100.0, "avg_packet_loss_pct": 1.3,
         "avg_session_success_pct": 96.5, "total_traffic_mb": 12300.0,
         "total_sessions": 255000, "total_subscribers": 126000},
        {"refresh_date": "2026-05-21", "country_name": "France", "country_code": "FR",
         "carrier_count": 3, "avg_composite_score": 74.5, "degraded_carrier_count": 1,
         "avg_latency_ms": 62.0, "avg_throughput_kbps": 1800.0, "avg_packet_loss_pct": 1.8,
         "avg_session_success_pct": 95.8, "total_traffic_mb": 10500.0,
         "total_sessions": 225000, "total_subscribers": 110000},
        {"refresh_date": "2026-05-21", "country_name": "Germany", "country_code": "DE",
         "carrier_count": 3, "avg_composite_score": 70.0, "degraded_carrier_count": 1,
         "avg_latency_ms": 68.0, "avg_throughput_kbps": 1500.0, "avg_packet_loss_pct": 2.3,
         "avg_session_success_pct": 95.0, "total_traffic_mb": 8700.0,
         "total_sessions": 195000, "total_subscribers": 94000},
        {"refresh_date": "2026-05-21", "country_name": "Japan", "country_code": "JP",
         "carrier_count": 3, "avg_composite_score": 66.0, "degraded_carrier_count": 0,
         "avg_latency_ms": 75.0, "avg_throughput_kbps": 1200.0, "avg_packet_loss_pct": 2.8,
         "avg_session_success_pct": 94.2, "total_traffic_mb": 6900.0,
         "total_sessions": 165000, "total_subscribers": 78000},
    ]
    return pd.DataFrame(rows)


def quality_log_df() -> pd.DataFrame:
    """Sample quality check log entries from stg_data_quality_log."""
    return pd.DataFrame([
        {"refresh_date": "2026-05-21", "step_name": "qc_freshness",
         "start_time": "2026-05-22T06:00:00", "end_time": "2026-05-22T06:00:01",
         "row_count": None, "status": "pass",
         "message": "Data for 2026-05-21 is within 36h freshness window"},
        {"refresh_date": "2026-05-21", "step_name": "qc_coverage",
         "start_time": "2026-05-22T06:00:01", "end_time": "2026-05-22T06:00:02",
         "row_count": 15, "status": "pass",
         "message": "Coverage stable — current: 15, prior (2026-05-20): 15"},
        {"refresh_date": "2026-05-21", "step_name": "qc_volume",
         "start_time": "2026-05-22T06:00:02", "end_time": "2026-05-22T06:00:03",
         "row_count": None, "status": "pass",
         "message": "Volume normal — current: 52500.00 MB, 14d avg: 51200.00 MB (102.5%)"},
    ])


def quality_log_with_failure_df() -> pd.DataFrame:
    """Quality log with one failed check for testing."""
    return pd.DataFrame([
        {"refresh_date": "2026-05-21", "step_name": "qc_freshness",
         "start_time": "2026-05-22T06:00:00", "end_time": "2026-05-22T06:00:01",
         "row_count": None, "status": "pass",
         "message": "Data for 2026-05-21 is within 36h freshness window"},
        {"refresh_date": "2026-05-21", "step_name": "qc_coverage",
         "start_time": "2026-05-22T06:00:01", "end_time": "2026-05-22T06:00:02",
         "row_count": 8, "status": "fail",
         "message": "Coverage drop — current: 8, prior (2026-05-20): 15 (53.3%)"},
        {"refresh_date": "2026-05-21", "step_name": "qc_volume",
         "start_time": "2026-05-22T06:00:02", "end_time": "2026-05-22T06:00:03",
         "row_count": None, "status": "pass",
         "message": "Volume normal — current: 52500.00 MB, 14d avg: 51200.00 MB (102.5%)"},
    ])
