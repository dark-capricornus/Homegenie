"""
Lightweight Postgres-backed device persistence (clean implementation).

This module provides a Device SQLModel and a tiny async helper API used by
the FastAPI server to make Postgres the single source of truth for device
states. When POSTGRES_URL is not set, functions will raise or return empty
results as documented so the rest of the application can fallback to
ContextStore.
"""
from __future__ import annotations

from typing import Optional, Dict, Any
from datetime import datetime, timezone
import logging

from sqlmodel import SQLModel, Field, select
from sqlalchemy import Column
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.types import JSON as SAJSON

from src.core.settings_v2 import settings_v2

logger = logging.getLogger(__name__)


class Device(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    device_id: str = Field(index=True)
    name: Optional[str] = None
    device_type: Optional[str] = None
    current_state: dict = Field(sa_column=Column(SAJSON), default={})
    intent: Optional[dict] = Field(sa_column=Column(SAJSON), default={})
    status: str = Field(default="unknown")  # pending, confirmed, failed, unknown
    last_updated: Optional[datetime] = None


class ScheduleJob(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    cron: Optional[str] = None
    enabled: bool = True
    job_metadata: Optional[dict] = Field(sa_column=Column(SAJSON), default={})
    created_at: Optional[datetime] = None


class MemoryEntry(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    key: Optional[str] = None
    value: Optional[dict] = Field(sa_column=Column(SAJSON), default={})
    ts: Optional[datetime] = None


# Lazily initialized engine/session
_engine = None
_async_session = None


def _ensure_db():
    global _engine, _async_session
    if _engine and _async_session:
        return _engine, _async_session
    url = getattr(settings_v2, 'POSTGRES_URL', None)
    if not url:
        raise RuntimeError("Postgres URL not configured")
    _engine = create_async_engine(url, echo=False)
    _async_session = async_sessionmaker(_engine, class_=AsyncSession, expire_on_commit=False)
    return _engine, _async_session


async def init_db(url: Optional[str] = None) -> None:
    db_url = url or getattr(settings_v2, 'POSTGRES_URL', None)
    if not db_url:
        logger.debug("DB init skipped: POSTGRES_URL not configured")
        return
    engine, _ = _ensure_db()
    async with engine.begin() as conn:
        await conn.run_sync(SQLModel.metadata.create_all)


async def upsert_device_state(
    device_id: str, 
    state: Optional[Dict[str, Any]] = None, 
    intent: Optional[Dict[str, Any]] = None,
    status: Optional[str] = None,
    name: Optional[str] = None, 
    device_type: Optional[str] = None
):
    _, async_session = _ensure_db()
    async with async_session() as sess:
        res = await sess.execute(select(Device).where(Device.device_id == device_id))
        dev = res.scalar_one_or_none()
        now = datetime.now(timezone.utc)
        if not dev:
            dev = Device(
                device_id=device_id, 
                name=name or device_id, 
                device_type=device_type, 
                current_state=state or {},
                intent=intent or {},
                status=status or "unknown", 
                last_updated=now
            )
            sess.add(dev)
        else:
            if state is not None:
                dev.current_state = state
            if intent is not None:
                dev.intent = intent
            if status is not None:
                dev.status = status
            
            dev.last_updated = now
            if name:
                dev.name = name
            if device_type:
                dev.device_type = device_type
        await sess.commit()
        await sess.refresh(dev)
        return dev


async def get_device_by_device_id(device_id: str):
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        # No DB configured; return a synthetic job id so callers can continue
        return int(datetime.now(timezone.utc).timestamp() * 1000)
    async with async_session() as sess:
        res = await sess.execute(select(Device).where(Device.device_id == device_id))
        return res.scalar_one_or_none()


async def get_device_by_topic(topic: str):
    parts = topic.split('/')
    if len(parts) >= 4 and parts[0] == 'home' and parts[-1] == 'state':
        device_type = parts[1]
        location = parts[2]
        device_id = f"{device_type}.{location}"
        return await get_device_by_device_id(device_id)
    return None


async def list_devices():
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return {}
    async with async_session() as sess:
        res = await sess.execute(select(Device))
        devices = res.scalars().all()
        out = {}
        for d in devices:
            out[d.device_id] = {
                'device_id': d.device_id,
                'name': d.name,
                'type': d.device_type,
                'state': d.current_state or {},
                'last_updated': d.last_updated.isoformat() if d.last_updated else None
            }
        return out


async def save_context_snapshot(context_store) -> Optional[int]:
    """Optional hook - persist a lightweight snapshot of the in-memory context.

    This is intentionally a no-op placeholder so the API can call it when
    snapshotting is enabled. Implementing a full snapshot store is out of
    scope for this change.
    """
    # Attempt to initialize DB; if unavailable return a synthetic id so callers
    # that expect an identifier can continue to operate during tests/fallbacks.
    try:
        await init_db()
    except Exception:
        # No DB configured; return a synthetic timestamp id
        return int(datetime.now(timezone.utc).timestamp() * 1000)
    # For now, we don't persist a full snapshot. Return a lightweight id.
    return int(datetime.now(timezone.utc).timestamp() * 1000)


async def upsert_device_metadata(device_id: str, metadata: Dict[str, Any]) -> Optional[int]:
    """Store arbitrary metadata fields on the Device row (best-effort).

    This is used by tests and higher-level agents to persist device
    attributes. If DB not configured this is a no-op.
    """
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        # No DB configured; return synthetic id
        return int(datetime.now(timezone.utc).timestamp() * 1000)
    async with async_session() as sess:
        res = await sess.execute(select(Device).where(Device.device_id == device_id))
        dev = res.scalar_one_or_none()
        if not dev:
            dev = Device(device_id=device_id, name=metadata.get("name") or device_id, device_type=metadata.get("type"))
            sess.add(dev)
        # best-effort map
        if "name" in metadata:
            dev.name = metadata.get("name")
        if "type" in metadata:
            dev.device_type = metadata.get("type")
        await sess.commit()
        try:
            await sess.refresh(dev)
        except Exception:
            pass
    return int(getattr(dev, 'id', int(datetime.now(timezone.utc).timestamp() * 1000)))


async def save_memory_entry(entry: Dict[str, Any]) -> Optional[int]:
    """Persist a memory entry. This is a lightweight table for small entries."""
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        # No DB configured; return synthetic id
        return int(datetime.utcnow().timestamp() * 1000)
    async with async_session() as sess:
        me = MemoryEntry(key=entry.get("key"), value=entry.get("value"), ts=entry.get("ts") or datetime.now(timezone.utc))
        sess.add(me)
        await sess.commit()
        try:
            await sess.refresh(me)
        except Exception:
            pass
    return int(getattr(me, 'id', int(datetime.utcnow().timestamp() * 1000)))


async def save_schedule_job(job: Dict[str, Any]):
    """Create or update a schedule job record.

    Expected job dict minimal shape: {'id': optional, 'name': str, 'cron': str, 'enabled': bool, 'metadata': dict}
    """
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return None
    async with async_session() as sess:
        jid = job.get("id")
        if jid:
            res = await sess.execute(select(ScheduleJob).where(ScheduleJob.id == jid))
            sj = res.scalar_one_or_none()
            if sj:
                sj.name = job.get("name", sj.name)
                sj.cron = job.get("cron", sj.cron)
                sj.enabled = job.get("enabled", sj.enabled)
                sj.job_metadata = job.get("metadata", sj.job_metadata)
            else:
                sj = ScheduleJob(name=job.get("name", "unnamed"), cron=job.get("cron"), enabled=job.get("enabled", True), job_metadata=job.get("metadata", {}), created_at=datetime.now(timezone.utc))
                sess.add(sj)
        else:
            sj = ScheduleJob(name=job.get("name", "unnamed"), cron=job.get("cron"), enabled=job.get("enabled", True), job_metadata=job.get("metadata", {}), created_at=datetime.now(timezone.utc))
            sess.add(sj)
        await sess.commit()
        try:
            await sess.refresh(sj)
        except Exception:
            pass
    return getattr(sj, 'id', None)


async def get_schedule_jobs(job_id: Optional[int] = None, user_id: Optional[str] = None):
    """Return list of ScheduleJob models. Accepts optional job_id or user_id filters."""
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return []
    async with async_session() as sess:
        if job_id:
            res = await sess.execute(select(ScheduleJob).where(ScheduleJob.id == job_id))
            jobs = res.scalars().all()
        else:
            res = await sess.execute(select(ScheduleJob))
            jobs = res.scalars().all()
        if user_id:
            filtered = []
            for j in jobs:
                try:
                    if isinstance(j.job_metadata, dict) and j.job_metadata.get('user_id') == user_id:
                        filtered.append(j)
                except Exception:
                    continue
            return filtered
        return jobs


async def update_schedule_job_enabled(job_id: int, enabled: bool) -> bool:
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return False
    async with async_session() as sess:
        res = await sess.execute(select(ScheduleJob).where(ScheduleJob.id == job_id))
        sj = res.scalar_one_or_none()
        if not sj:
            return False
        sj.enabled = bool(enabled)
        await sess.commit()
        return True
