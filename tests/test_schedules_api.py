import asyncio
import pytest
import pytest_asyncio
import json
from datetime import datetime, timedelta

from httpx import AsyncClient
from httpx import ASGITransport

import importlib
# Import the db_v2 module so static checkers and test code can reference it directly
from src.core import db_v2 as db_v2  # type: ignore

# We'll import settings_v2 and db_v2 inside fixtures to control import order


@pytest.fixture(scope="module")
def anyio_backend():
    return "asyncio"


@pytest_asyncio.fixture
async def init_sqlite_db(monkeypatch):
    """Configure an in-memory async sqlite DB for db_v2 and initialize tables."""
    # Use in-memory aiosqlite for tests
    settings_mod = importlib.import_module('src.core.settings_v2')
    settings_mod.settings_v2.POSTGRES_URL = "sqlite+aiosqlite:///:memory:"

    # Import db_v2 and reset its engine/session so it will build an engine using our test URL
    db_v2_mod = importlib.import_module('src.core.db_v2')
    # Reset internals if already created in this process (use setattr to avoid static attribute-access issues)
    try:
        setattr(db_v2_mod, "_engine", None)
        setattr(db_v2_mod, "_async_session", None)
    except Exception:
        pass

    # Expose db_v2 and settings_v2 to the test module globals for access
    globals()['db_v2'] = db_v2_mod
    globals()['settings_v2'] = settings_mod.settings_v2

    # Initialize tables (will create engine/session based on our in-memory sqlite URL)
    await db_v2_mod.init_db()
    yield


@pytest_asyncio.fixture
async def test_client(init_sqlite_db, monkeypatch):
    """Create an AsyncClient for the FastAPI app and patch executor to avoid MQTT calls."""
    # Patch executor_agent.execute to be a no-op coroutine so scheduled jobs don't hit MQTT
    async def fake_execute(task):
        # pretend to succeed
        return True

    # Mark executor as connected to avoid connect attempts
    # Import the FastAPI app module inside the event loop context so asyncio.get_event_loop() works
    import importlib
    api_server = importlib.import_module('src.api.api_server')

    try:
        api_server.executor_agent._connected = True
        api_server.executor_agent.execute = fake_execute
    except Exception:
        pass

    # Create the client which will run app startup (lifespan) and therefore scheduler_agent.start()
    transport = ASGITransport(app=api_server.app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as ac:
        # expose the imported module to tests via globals so test functions can reference it
        globals()['api_server'] = api_server
        yield ac


@pytest.mark.asyncio
async def test_post_get_delete_schedule(test_client):
    # Ensure no schedules initially
    r = await test_client.get("/schedules")
    assert r.status_code == 200
    body = r.json()
    assert isinstance(body.get("schedules"), list)

    # Create a schedule
    payload = {
        "name": "test-job",
        "delay_seconds": 60,
        "data": {"user_id": "test_user", "task": {"device": "light.test", "action": "turn_on"}}
    }
    r = await test_client.post("/schedules", json=payload)
    assert r.status_code == 200
    created = r.json()
    assert "id" in created
    job_id = created["id"]

    # GET should return the schedule (enabled)
    r = await test_client.get("/schedules")
    assert r.status_code == 200
    body = r.json()
    schedules = body.get("schedules", [])
    assert any(s.get("id") == job_id for s in schedules)

    # DELETE the schedule
    r = await test_client.delete(f"/schedules/{job_id}")
    assert r.status_code == 200
    resp = r.json()
    assert resp.get("cancelled") is True

    # After delete, GET should NOT include the schedule (we only list enabled jobs)
    r = await test_client.get("/schedules")
    assert r.status_code == 200
    body = r.json()
    schedules = body.get("schedules", [])
    assert not any(s.get("id") == job_id for s in schedules)

    # But the DB record should still exist and be disabled
    rows = await db_v2.get_schedule_jobs(job_id=job_id)
    assert rows and rows[0].enabled is False


@pytest.mark.asyncio
async def test_scheduler_loads_jobs_on_startup(init_sqlite_db, monkeypatch):
    # Create a job directly in DB before app startup
    job = {
        "name": "startup-job",
        "data": {"user_id": "startup_user", "task": {"device": "light.start", "action": "turn_on"}},
        "next_run": None
    }
    job_id = await db_v2.save_schedule_job(job)

    # Now start the app in a client; scheduler_agent.start should load the job
    import importlib
    api_server = importlib.import_module('src.api.api_server')
    transport = ASGITransport(app=api_server.app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as ac:
        # patch executor to avoid MQTT
        async def fake_execute(task):
            return True
        api_server.executor_agent._connected = True
        api_server.executor_agent.execute = fake_execute

        # give the lifespan a moment to start and load jobs
        await asyncio.sleep(0.1)

        # SchedulerAgent should have scheduled tasks for enabled jobs that have run_at/delay
        # Note: since this job has no next_run or delay it's not scheduled immediately, but it should still be present in DB
        rows = await db_v2.get_schedule_jobs(job_id=job_id)
        assert rows and rows[0].id == job_id

        # Now ensure that scheduler_agent.list_jobs returns the job
        listed = await api_server.scheduler_agent.list_jobs()
        assert any(getattr(r, 'id', None) == job_id for r in listed)

        # Clean up: delete job
        await api_server.scheduler_agent.cancel_job(job_id)
    rows = await db_v2.get_schedule_jobs(job_id=job_id)
    assert rows and rows[0].enabled is False