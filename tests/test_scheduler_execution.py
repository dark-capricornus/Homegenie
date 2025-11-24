import asyncio
import importlib
import pytest
import pytest_asyncio
from httpx import AsyncClient
from httpx import ASGITransport

# Ensure db_v2 name exists for static checkers and test assertions
from src.core import db_v2 as db_v2  # type: ignore


@pytest.fixture(scope="module")
def anyio_backend():
    return "asyncio"


@pytest_asyncio.fixture
async def init_sqlite_db(monkeypatch):
    # configure in-memory sqlite for db_v2
    settings_mod = importlib.import_module('src.core.settings_v2')
    settings_mod.settings_v2.POSTGRES_URL = "sqlite+aiosqlite:///:memory:"

    db_v2_mod = importlib.import_module('src.core.db_v2')
    try:
        setattr(db_v2_mod, "_engine", None)
        setattr(db_v2_mod, "_async_session", None)
    except Exception:
        pass

    globals()['db_v2'] = db_v2_mod
    globals()['settings_v2'] = settings_mod.settings_v2

    await db_v2_mod.init_db()
    yield


@pytest_asyncio.fixture
async def client(init_sqlite_db):
    api_server = importlib.import_module('src.api.api_server')

    # Prepare a list to record executor calls
    calls = []

    async def recording_execute(task):
        calls.append(task)
        return True

    # patch executor agent to use the recording execute
    api_server.executor_agent._connected = True
    api_server.executor_agent.execute = recording_execute

    transport = ASGITransport(app=api_server.app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as ac:
        globals()['api_server'] = api_server
        globals()['executor_calls'] = calls
        yield ac


@pytest.mark.asyncio
async def test_scheduler_fires_and_disables_job(client):
    # Create schedule with short delay (1 second)
    payload = {
        "name": "fire-job",
        "delay_seconds": 1,
        "data": {"user_id": "exec_user", "task": {"device": "light.exec", "action": "turn_on"}}
    }

    r = await client.post("/schedules", json=payload)
    assert r.status_code == 200
    created = r.json()
    job_id = created.get('id')
    assert job_id is not None

    # wait enough time for the job to fire
    await asyncio.sleep(1.5)

    # check executor was called once
    calls = globals().get('executor_calls', [])
    assert len(calls) == 1
    fired_task = calls[0]
    assert fired_task.get('task', {}).get('device') == 'light.exec' or fired_task.get('device') == 'light.exec'

    # ensure job now disabled in DB
    rows = await db_v2.get_schedule_jobs(job_id=job_id)
    assert rows and rows[0].enabled is False
