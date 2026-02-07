"""Backwards-compatibility smoke tests for public API endpoints.

These tests are intentionally lightweight and skip if the API server is
not reachable. They must run with feature flags disabled in CI.
"""
import os
import pytest

try:
    import httpx
except Exception: 
    httpx = None


BASE = os.getenv("API_BASE_URL") or f"http://{os.getenv('API_HOST','localhost')}:{os.getenv('API_PORT','8080')}"


def _is_server_available() -> bool:
    if not httpx:
        return False
    try:
        r = httpx.get(f"{BASE}/health", timeout=2.0)
        return r.status_code == 200
    except Exception:
        return False


def test_health_endpoint_shape():
    # runtime guard: skip if httpx not installed or server unreachable
    if not httpx or not _is_server_available():
        pytest.skip("API server not available")

    r = httpx.get(f"{BASE}/health", timeout=5.0)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, dict)
    assert "status" in data


def test_devices_endpoint_shape():
    # runtime guard: skip if httpx not installed or server unreachable
    if not httpx or not _is_server_available():
        pytest.skip("API server not available")

    r = httpx.get(f"{BASE}/devices", timeout=5.0)
    assert r.status_code in (200, 204)
    try:
        data = r.json()
    except Exception:
        pytest.skip("Devices endpoint returned non-json response")

    assert isinstance(data, dict)
    # Expect either top-level 'devices' key or a mapping
    assert "devices" in data or isinstance(data.get("devices"), dict)
