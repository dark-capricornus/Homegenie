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

from sqlmodel import SQLModel, Field, select, delete
from sqlalchemy import Column
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.types import JSON as SAJSON

from src.core.settings_v2 import settings_v2

logger = logging.getLogger(__name__)


class Device(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    device_id: str = Field(index=True, unique=True)
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
    next_run: Optional[datetime] = None
    enabled: bool = True
    data: Optional[dict] = Field(sa_column=Column(SAJSON), default={})
    created_at: Optional[datetime] = None


class RuleTable(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    priority: int = 1
    enabled: bool = True
    content: dict = Field(sa_column=Column(SAJSON), default={})
    created_at: Optional[datetime] = None
    last_triggered: Optional[datetime] = None


class MemoryEntry(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    key: Optional[str] = None
    value: Optional[dict] = Field(sa_column=Column(SAJSON), default={})
    ts: Optional[datetime] = None


class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(index=True, unique=True)
    email: Optional[str] = Field(index=True)
    hashed_password: str
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class Integration(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    platform: str = Field(index=True, unique=True)  # google_home, alexa, zigbee, matter, custom_mqtt
    name: str
    is_configured: bool = Field(default=False)
    config: dict = Field(sa_column=Column(SAJSON), default={})
    device_count: int = Field(default=0)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: Optional[datetime] = None


class EnergyHistory(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    device_id: str = Field(index=True)
    power_watts: float
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc), index=True)


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
        try:
            res = await sess.execute(select(Device).where(Device.device_id == device_id))
            dev = res.scalars().first()
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
        except Exception as e:
            await sess.rollback()
            logger.error(f"Failed to upsert device {device_id}: {e}")
            raise


async def get_device_by_device_id(device_id: str):
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        # No DB configured; return a synthetic job id so callers can continue
        return int(datetime.now(timezone.utc).timestamp() * 1000)
    async with async_session() as sess:
        res = await sess.execute(select(Device).where(Device.device_id == device_id))
        return res.scalars().first()


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
        dev = res.scalars().first()
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
        return int(datetime.now(timezone.utc).timestamp() * 1000)
    async with async_session() as sess:
        me = MemoryEntry(key=entry.get("key"), value=entry.get("value"), ts=entry.get("ts") or datetime.now(timezone.utc))
        sess.add(me)
        await sess.commit()
        try:
            await sess.refresh(me)
        except Exception:
            pass
    return int(getattr(me, 'id', int(datetime.now(timezone.utc).timestamp() * 1000)))


async def get_memory_entries(limit: int = 1000) -> list:
    """Retrieve persisted memory entries, most recent first."""
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return []
    async with async_session() as sess:
        result = await sess.execute(
            select(MemoryEntry).order_by(MemoryEntry.ts.desc()).limit(limit)
        )
        return list(result.scalars().all())


async def save_schedule_job(job: Dict[str, Any]):
    """Create or update a schedule job record.

    Expected job dict minimal shape: {'id': optional, 'name': str, 'cron': str, 'enabled': bool, 'metadata': dict}
    """
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return None
    async with async_session() as sess:
        try:
            jid = job.get("id")
            job_data = job.get("data", job.get("metadata", {}))
            if jid:
                res = await sess.execute(select(ScheduleJob).where(ScheduleJob.id == jid))
                sj = res.scalar_one_or_none()
                if sj:
                    sj.name = job.get("name", sj.name)
                    sj.cron = job.get("cron", sj.cron)
                    sj.enabled = job.get("enabled", sj.enabled)
                    sj.data = job_data if job_data else sj.data
                else:
                    sj = ScheduleJob(name=job.get("name", "unnamed"), cron=job.get("cron"), enabled=job.get("enabled", True), data=job_data, created_at=datetime.now(timezone.utc))
                    sess.add(sj)
            else:
                sj = ScheduleJob(name=job.get("name", "unnamed"), cron=job.get("cron"), enabled=job.get("enabled", True), data=job_data, created_at=datetime.now(timezone.utc))
                sess.add(sj)
            await sess.commit()
            await sess.refresh(sj)
            return getattr(sj, 'id', None)
        except Exception as e:
            await sess.rollback()
            logger.error(f"Failed to save schedule job: {e}")
            return None


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
                    if isinstance(j.data, dict) and j.data.get('user_id') == user_id:
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


async def get_rules(rule_id: Optional[int] = None):
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return []
    async with async_session() as sess:
        if rule_id:
            res = await sess.execute(select(RuleTable).where(RuleTable.id == rule_id))
            return res.scalars().all()
        else:
            res = await sess.execute(select(RuleTable))
            return res.scalars().all()


async def save_rule(rule: Dict[str, Any]):
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return None
    async with async_session() as sess:
        try:
            rid = rule.get("id")
            if rid:
                res = await sess.execute(select(RuleTable).where(RuleTable.id == rid))
                rt = res.scalar_one_or_none()
                if rt:
                    rt.name = rule.get("name", rt.name)
                    rt.priority = rule.get("priority", rt.priority)
                    rt.enabled = rule.get("enabled", rt.enabled)
                    rt.content = rule.get("content", rt.content)
                else:
                    rt = RuleTable(
                        name=rule.get("name", "unnamed"),
                        priority=rule.get("priority", 1),
                        enabled=rule.get("enabled", True),
                        content=rule.get("content", {}),
                        created_at=datetime.now(timezone.utc)
                    )
                    sess.add(rt)
            else:
                rt = RuleTable(
                    name=rule.get("name", "unnamed"),
                    priority=rule.get("priority", 1),
                    enabled=rule.get("enabled", True),
                    content=rule.get("content", {}),
                    created_at=datetime.now(timezone.utc)
                )
                sess.add(rt)
            await sess.commit()
            await sess.refresh(rt)
            return getattr(rt, 'id', None)
        except Exception as e:
            await sess.rollback()
            logger.error(f"Failed to save rule: {e}")
            return None


async def delete_rule(rule_id: int) -> bool:
    """Deletes an automation rule by id."""
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return False
    async with async_session() as sess:
        try:
            res = await sess.execute(select(RuleTable).where(RuleTable.id == rule_id))
            rt = res.scalar_one_or_none()
            if rt:
                await sess.execute(delete(RuleTable).where(RuleTable.id == rule_id))
                await sess.commit()
                return True
            return False
        except Exception as e:
            logger.error(f"Failed to delete rule: {e}")
            await sess.rollback()
            return False


async def get_user_by_username(username: str) -> Optional[User]:
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return None
    async with async_session() as sess:
        res = await sess.execute(select(User).where(User.username == username))
        return res.scalars().first()


async def create_user(user: User) -> User:
    _, async_session = _ensure_db()
    async with async_session() as sess:
        try:
            sess.add(user)
            await sess.commit()
            await sess.refresh(user)
            return user
        except Exception as e:
            await sess.rollback()
            logger.error(f"Failed to create user: {e}")
            raise


async def record_energy_sample(device_id: str, watts: float) -> Optional[int]:
    """Records a single power consumption reading."""
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return None
    async with async_session() as sess:
        try:
            sample = EnergyHistory(device_id=device_id, power_watts=float(watts))
            sess.add(sample)
            await sess.commit()
            await sess.refresh(sample)
            return sample.id
        except Exception:
            await sess.rollback()
            # Suppress errors to avoid breaking the core state update loop
            return None


async def get_energy_history(device_id: Optional[str] = None, start_date: Optional[datetime] = None, end_date: Optional[datetime] = None):
    """Retrieves power consumption history, optionally filtered by device and time range."""
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return []
    async with async_session() as sess:
        try:
            stmt = select(EnergyHistory)
            if device_id:
                stmt = stmt.where(EnergyHistory.device_id == device_id)
            if start_date:
                stmt = stmt.where(EnergyHistory.timestamp >= start_date)
            if end_date:
                stmt = stmt.where(EnergyHistory.timestamp <= end_date)
            
            stmt = stmt.order_by(EnergyHistory.timestamp.asc())
            res = await sess.execute(stmt)
            return res.scalars().all()
        except Exception as e:
            logger.error(f"Failed to fetch energy history: {e}")
            return []


SUPPORTED_PLATFORMS = [
    {"platform": "google_home", "name": "Google Home"},
    {"platform": "alexa", "name": "Amazon Alexa"},
    {"platform": "zigbee", "name": "Zigbee"},
    {"platform": "matter", "name": "Matter"},
    {"platform": "custom_mqtt", "name": "Custom MQTT"},
]


async def list_integrations():
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return [{"platform": p["platform"], "name": p["name"], "is_configured": False, "device_count": 0, "config": {}} for p in SUPPORTED_PLATFORMS]
    async with async_session() as sess:
        res = await sess.execute(select(Integration))
        rows = {r.platform: r for r in res.scalars().all()}
        result = []
        for p in SUPPORTED_PLATFORMS:
            if p["platform"] in rows:
                r = rows[p["platform"]]
                result.append({
                    "platform": r.platform,
                    "name": r.name,
                    "is_configured": r.is_configured,
                    "device_count": r.device_count,
                    "config": r.config or {},
                })
            else:
                result.append({"platform": p["platform"], "name": p["name"], "is_configured": False, "device_count": 0, "config": {}})
        return result


async def get_integration(platform: str):
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return None
    async with async_session() as sess:
        res = await sess.execute(select(Integration).where(Integration.platform == platform))
        return res.scalars().first()


async def upsert_integration(platform: str, config: Dict[str, Any]) -> bool:
    valid_platforms = {p["platform"] for p in SUPPORTED_PLATFORMS}
    if platform not in valid_platforms:
        return False
    try:
        _, async_session = _ensure_db()
    except RuntimeError:
        return False
    async with async_session() as sess:
        try:
            res = await sess.execute(select(Integration).where(Integration.platform == platform))
            row = res.scalars().first()
            now = datetime.now(timezone.utc)
            name = next((p["name"] for p in SUPPORTED_PLATFORMS if p["platform"] == platform), platform)
            if row:
                row.config = config
                row.is_configured = True
                row.updated_at = now
            else:
                row = Integration(platform=platform, name=name, is_configured=True, config=config, created_at=now)
                sess.add(row)
            await sess.commit()
            return True
        except Exception as e:
            await sess.rollback()
            logger.error(f"Failed to upsert integration {platform}: {e}")
            return False
