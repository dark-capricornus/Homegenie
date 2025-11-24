import os
import pytest_asyncio
import httpx


@pytest_asyncio.fixture
async def httpx_async_client():
    """Provide an async httpx client pointed at the API base URL.

    Uses API_BASE_URL or API_HOST/API_PORT env vars; falls back to http://localhost:8000.
    """
    base = os.getenv("API_BASE_URL") or f"http://{os.getenv('API_HOST','localhost')}:{os.getenv('API_PORT','8000')}"
    async with httpx.AsyncClient(base_url=base) as client:
        yield client
