import asyncio
import importlib

import pytest


@pytest.mark.asyncio
async def test_init_and_save_contextsnapshot(tmp_path):
    """Quick integration-style test for src.core.db_v2 using in-memory sqlite.

    This test is intentionally non-destructive and does not require a running
    Postgres instance. It sets the module settings to use an async sqlite
    engine, resets the module-level engine/session state, initializes the DB
    and writes a sample snapshot.
    """
    # Import here so tests can run without touching settings at module import time
    from src.core import db_v2
    # Import the same settings_v2 instance used by db_v2 to ensure we update
    # the object that _get_engine() reads from.
    from src.core.settings_v2 import settings_v2

    # Configure an in-memory async sqlite URL for testing
    settings_v2.POSTGRES_URL = "sqlite+aiosqlite:///:memory:"

    # Reset any cached engine/session so _get_engine recreates for sqlite
    try:
        setattr(db_v2, "_engine", None)
        setattr(db_v2, "_async_session", None)
    except Exception:
        # If internals differ, best-effort reset
        pass

    class DummyContextStore:
        def dump(self):
            return {"states": {"test/topic/state": {"state": "on"}}}

    # Initialize DB (should create tables in-memory)
    await db_v2.init_db()

    # Save a snapshot and ensure an integer id is returned
    snapshot_id = await db_v2.save_context_snapshot(DummyContextStore())
    assert isinstance(snapshot_id, int)

    # Test memory entry persistence
    mem_id = await db_v2.save_memory_entry("test_user", "device_command", {"device": "light.living_room", "action": "turn_on"})
    assert isinstance(mem_id, int)

    # Test schedule job persistence
    job = {"name": "morning_routine", "cron": "0 7 * * *", "enabled": True, "data": {"routine": "goodmorning"}}
    job_id = await db_v2.save_schedule_job(job)
    assert isinstance(job_id, int)

    # Test device metadata upsert
    dev_id = await db_v2.upsert_device_metadata("light.living_room", "light", "living_room", {"capabilities": ["brightness","color"]})
    assert isinstance(dev_id, int)
