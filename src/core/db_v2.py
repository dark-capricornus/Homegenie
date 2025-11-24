"""Postgres v2 minimal PoC for ContextStore snapshots.

This module is additive and guarded by feature flags. It provides a small
SQLModel model and helper functions to initialize the DB and save a
ContextStore snapshot as a JSON blob. It's intentionally minimal and
intended for local testing behind the `ENABLE_POSTGRES_MIGRATION` flag.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional
import json

from sqlmodel import SQLModel, Field, select
from sqlalchemy import Column
from sqlalchemy.sql import expression
from sqlalchemy.types import JSON as SAJSON
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

from src.core.settings_v2 import settings_v2
from sqlmodel import select


# Driver selection: prefer asyncpg if available, otherwise try psycopg (binary)
_PREFERRED_DRIVER: str | None = None
try:
    import asyncpg  # type: ignore
    _PREFERRED_DRIVER = "asyncpg"
except Exception:
    try:
        import psycopg  # type: ignore
        _PREFERRED_DRIVER = "psycopg"
    except Exception:
        _PREFERRED_DRIVER = None


class ContextSnapshot(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    # store the snapshot as a JSON column
    data: dict = Field(sa_column=Column(SAJSON))


class MemoryEntry(SQLModel, table=True):
    """Durable memory/history entries for MemoryAgent."""
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: Optional[str] = Field(index=True, default=None)
    entry_type: Optional[str] = Field(default=None)
    data: dict = Field(sa_column=Column(SAJSON))
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class ScheduleJob(SQLModel, table=True):
    """Persistent schedule/job representation for SchedulerAgent."""
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    cron: Optional[str] = None
    next_run: Optional[datetime] = None
    enabled: bool = Field(default=True)
    data: dict = Field(sa_column=Column(SAJSON), default={})
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class DeviceMetadata(SQLModel, table=True):
    """Device metadata table for static device info and capabilities."""
    id: Optional[int] = Field(default=None, primary_key=True)
    device_id: str = Field(index=True)
    device_type: Optional[str] = None
    location: Optional[str] = None
    # use `meta` to avoid shadowing SQLAlchemy/SQLModel internals (metadata)
    meta: dict = Field(sa_column=Column(SAJSON), default={})
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


_engine = None
_async_session: Optional[async_sessionmaker] = None


def _get_engine():
    global _engine, _async_session
    if _engine is None:
        if not settings_v2.POSTGRES_URL:
            raise RuntimeError("Postgres URL not configured in settings_v2")

        url = settings_v2.POSTGRES_URL
        # If the URL explicitly asks for asyncpg but asyncpg not installed, try psycopg
        if "+asyncpg" in url and _PREFERRED_DRIVER == "psycopg":
            url = url.replace("+asyncpg", "+psycopg")

        # If no explicit driver, and psycopg preferred, use psycopg scheme
        if "+" not in url and _PREFERRED_DRIVER == "psycopg":
            # transform postgresql:// -> postgresql+psycopg://
            if url.startswith("postgresql://"):
                url = url.replace("postgresql://", "postgresql+psycopg://", 1)

        _engine = create_async_engine(url, echo=False, future=True)
        # Use the async_sessionmaker for async engines/sessions
        _async_session = async_sessionmaker(_engine, class_=AsyncSession, expire_on_commit=False)

    return _engine


async def init_db() -> None:
    """Create tables (no-op if already present)."""
    engine = _get_engine()
    # Use SQLModel metadata to create tables
    async with engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.create_all)


async def save_context_snapshot(context_store) -> int:
    """Save a snapshot of the provided ContextStore to Postgres.

    Returns the created snapshot id.
    """
    if not settings_v2.POSTGRES_URL:
        raise RuntimeError("Postgres not configured")

    # Ensure engine/session exists
    engine = _get_engine()
    assert _async_session is not None

    # Get JSON-serializable dump
    try:
        data = context_store.dump()
    except Exception:
        # Fallback to async dump if needed
        data = await context_store.async_dump()

    async with _async_session() as session:
        snapshot = ContextSnapshot(data=data)
        session.add(snapshot)
        await session.commit()
        await session.refresh(snapshot)
        # snapshot.id may be Optional[int] according to type checkers;
        # assert it's present after commit/refresh so static checkers and
        # runtime both have a clear contract.
        assert snapshot.id is not None, "snapshot.id was not set by the database"
        return int(snapshot.id)


async def save_memory_entry(user_id: str, entry_type: str, data: dict) -> int:
    """Persist a MemoryAgent entry to Postgres. Returns the created id."""
    if not settings_v2.POSTGRES_URL:
        raise RuntimeError("Postgres not configured")

    engine = _get_engine()
    assert _async_session is not None

    async with _async_session() as session:
        entry = MemoryEntry(user_id=user_id, entry_type=entry_type, data=data)
        session.add(entry)
        await session.commit()
        await session.refresh(entry)
        assert entry.id is not None
        return int(entry.id)


async def get_memory_entries(user_id: str, limit: int = 50) -> list:
    """Return recent memory entries for a user (most recent first)."""
    if not settings_v2.POSTGRES_URL:
        return []

    engine = _get_engine()
    assert _async_session is not None

    async with _async_session() as session:
        # Use the table column expression to produce a SQLAlchemy ClauseElement
        # so static type checkers (and SQLAlchemy) accept the .desc() call.
        # Use getattr to retrieve the SQLAlchemy descriptor for the column;
        # getattr returns Any so static checkers won't complain about missing
        # attributes on the class object.
        created_col = getattr(MemoryEntry, "created_at")
        res = await session.execute(
            select(MemoryEntry).where(MemoryEntry.user_id == user_id).order_by(created_col.desc()).limit(limit)
        )
        return res.scalars().all()


async def save_schedule_job(job: dict) -> int:
    """Persist a schedule/job dictionary to Postgres. Returns the created id."""
    if not settings_v2.POSTGRES_URL:
        raise RuntimeError("Postgres not configured")

    engine = _get_engine()
    assert _async_session is not None

    async with _async_session() as session:
        sj = ScheduleJob(
            name=job.get("name", "unnamed"),
            cron=job.get("cron"),
            next_run=job.get("next_run"),
            enabled=bool(job.get("enabled", True)),
            data=job.get("data", {}),
        )
        session.add(sj)
        await session.commit()
        await session.refresh(sj)
        assert sj.id is not None
        return int(sj.id)


async def get_schedule_jobs(job_id: Optional[int] = None, user_id: Optional[str] = None) -> list:
    """Return schedule jobs; filter by job_id or user_id if provided."""
    if not settings_v2.POSTGRES_URL:
        return []

    engine = _get_engine()
    assert _async_session is not None

    async with _async_session() as session:
        q = select(ScheduleJob)
        if job_id:
            q = q.where(ScheduleJob.id == int(job_id))
        if user_id:
            # assume data may contain owner/user info; use SQLAlchemy JSON traversal
            # Use the JSON column expression `ScheduleJob.data['user_id'].astext == user_id`.
            try:
                q = q.where(ScheduleJob.data["user_id"].astext == user_id)
            except Exception:
                # Fallback to a safe SQL expression if the backend doesn't support JSON operators
                # Use a constant false expression so the filter yields no rows.
                q = q.where(expression.false())
        res = await session.execute(q)
        return res.scalars().all()


async def update_schedule_job_enabled(job_id: int, enabled: bool) -> None:
    """Update the enabled flag for a schedule job."""
    if not settings_v2.POSTGRES_URL:
        return

    engine = _get_engine()
    assert _async_session is not None

    async with _async_session() as session:
        res = await session.execute(select(ScheduleJob).where(ScheduleJob.id == int(job_id)))
        row = res.scalars().first()
        if not row:
            return
        row.enabled = bool(enabled)
        session.add(row)
        await session.commit()



async def upsert_device_metadata(device_id: str, device_type: Optional[str], location: Optional[str], metadata: dict) -> int:
    """Insert or update device metadata record. Returns id."""
    if not settings_v2.POSTGRES_URL:
        raise RuntimeError("Postgres not configured")

    engine = _get_engine()
    assert _async_session is not None

    async with _async_session() as session:
        # Try to find existing
        res = await session.execute(
            select(DeviceMetadata).where(DeviceMetadata.device_id == device_id)
        )
        existing = res.scalars().first()

        if existing:
            existing.device_type = device_type
            existing.location = location
            existing.meta = metadata
            session.add(existing)
            await session.commit()
            await session.refresh(existing)
            return int(existing.id)
        else:
            dm = DeviceMetadata(device_id=device_id, device_type=device_type, location=location, meta=metadata)
            session.add(dm)
            await session.commit()
            await session.refresh(dm)
            assert dm.id is not None
            return int(dm.id)


__all__ = ["ContextSnapshot", "init_db", "save_context_snapshot"]
