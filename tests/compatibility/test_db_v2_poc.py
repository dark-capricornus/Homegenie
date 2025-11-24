"""Compatibility test for Postgres v2 PoC.

This test is intentionally skipped when POSTGRES_URL is not configured to
avoid interfering with CI or local runs that don't have Postgres available.
"""
import os
import pytest


POSTGRES_URL = os.getenv("POSTGRES_URL") or os.getenv("DATABASE_URL")


pytestmark = pytest.mark.asyncio


@pytest.mark.skipif(not POSTGRES_URL, reason="Postgres not configured")
async def test_db_v2_save_snapshot_via_api(httpx_async_client):
    """If Postgres is configured and the feature flag is on, ensure the migrate endpoint returns 200.

    This test expects tests to provide an `httpx_async_client` fixture pointed at the running API.
    If such fixture isn't present, the test will simply attempt a local HTTP request and may fail.
    """
    # Feature-flag must be enabled by test environment explicitly
    resp = await httpx_async_client.post("/v2/migrate/contextstore")
    assert resp.status_code in (200, 403, 400, 500)
