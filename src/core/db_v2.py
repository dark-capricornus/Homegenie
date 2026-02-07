"""Compatibility wrapper for the async DB implementation.

This module provides a lightweight compatibility layer named `db_v2` that
delegates to `src.core.db_async` where appropriate and provides no-op
or NotImplemented placeholders for functions that are outside the scope of
the lightweight replacement. The goal is to ensure imports of `db_v2`
across the codebase don't fail while we migrate to the new implementation.
"""
from typing import Any, Dict, Optional
from datetime import datetime
import logging

try:
    from src.core import db_async as _impl
except Exception:
    _impl = None

logger = logging.getLogger(__name__)


async def init_db(url: Optional[str] = None) -> None:
    if not _impl:
        raise RuntimeError("DB async implementation not available")
    return await _impl.init_db(url)


async def upsert_device_state(device_id: str, state: Dict[str, Any], name: Optional[str] = None, device_type: Optional[str] = None):
    if not _impl:
        raise RuntimeError("DB async implementation not available")
    return await _impl.upsert_device_state(device_id, state, name=name, device_type=device_type)


async def get_device_by_device_id(device_id: str):
    if not _impl:
        return None
    return await _impl.get_device_by_device_id(device_id)


async def get_device_by_topic(topic: str):
    if not _impl:
        return None
    return await _impl.get_device_by_topic(topic)


async def list_devices():
    if not _impl:
        return {}
    return await _impl.list_devices()


async def save_context_snapshot(context_store) -> Optional[int]:
    if not _impl:
        # return a synthetic id for compatibility
        return int(datetime.utcnow().timestamp() * 1000)
    # Delegate to implementation if present
    return await _impl.save_context_snapshot(context_store)


async def upsert_device_metadata(device_id: str, *args, **kwargs) -> Optional[int]:
    """Compatibility wrapper for upserting device metadata.

    Accept multiple legacy calling forms for compatibility:
    - upsert_device_metadata(device_id, metadata_dict)
    - upsert_device_metadata(device_id, device_type, location, metadata_dict)
    """
    if not _impl:
        return int(datetime.utcnow().timestamp() * 1000)

    # Normalize metadata from possible legacy args
    metadata = None
    if 'metadata' in kwargs and isinstance(kwargs['metadata'], dict):
        metadata = kwargs['metadata']
    elif len(args) == 1 and isinstance(args[0], dict):
        metadata = args[0]
    else:
        # try to extract legacy (device_type, location, metadata) safely
        try:
            la = list(args)
            if len(la) >= 3 and isinstance(la[2], dict):
                device_type = la[0]
                location = la[1]
                metadata = la[2]
                # also surface device_type/location into metadata if not present
                if 'type' not in metadata:
                    metadata['type'] = device_type
                if 'location' not in metadata:
                    metadata['location'] = location
        except Exception:
            pass
        if metadata is None:
            # nothing sensible provided; return an empty metadata map
            metadata = {}

    try:
        if hasattr(_impl, 'upsert_device_metadata'):
            return await _impl.upsert_device_metadata(device_id, metadata)
    except Exception:
        logger.exception("upsert_device_metadata delegate failed")
    return int(datetime.utcnow().timestamp() * 1000)


# The following functions are part of the original db_v2 surface but are
# not implemented in db_async. Provide minimal placeholders so callers
# that attempt to use them will get a clear error or no-op behavior.
async def save_schedule_job(job: dict) -> Optional[int]:
    if _impl and hasattr(_impl, 'save_schedule_job'):
        try:
            jid = await _impl.save_schedule_job(job)
            # ensure we return an int or None
            return int(jid) if jid is not None else None
        except Exception:
            logger.exception("save_schedule_job delegate failed")
            return None
    raise NotImplementedError("save_schedule_job not implemented in this compatibility layer")


async def get_schedule_jobs(job_id: Optional[int] = None, user_id: Optional[str] = None) -> list:
    if _impl and hasattr(_impl, 'get_schedule_jobs'):
        try:
            jobs = await _impl.get_schedule_jobs(job_id=job_id, user_id=user_id)
            # normalize to a plain list for callers
            return list(jobs) if jobs is not None else []
        except Exception:
            logger.exception("get_schedule_jobs delegate failed")
            return []
    raise NotImplementedError("get_schedule_jobs not implemented in this compatibility layer")


async def update_schedule_job_enabled(job_id: int, enabled: bool) -> bool:
    if _impl and hasattr(_impl, 'update_schedule_job_enabled'):
        try:
            return await _impl.update_schedule_job_enabled(job_id, enabled)
        except Exception:
            logger.exception("update_schedule_job_enabled delegate failed")
            return False
    raise NotImplementedError("update_schedule_job_enabled not implemented in this compatibility layer")


async def save_memory_entry(user_id: str, entry_type: str, data: dict) -> Optional[int]:
    # Best-effort persistence for memory entries to avoid breaking callers.
    try:
        if _impl and hasattr(_impl, 'save_memory_entry'):
            entry = {"user_id": user_id, "type": entry_type, "value": data}
            mid = await _impl.save_memory_entry(entry)
            return int(mid) if mid is not None else None
    except Exception:
        logger.exception("save_memory_entry failed or not implemented; ignoring")
    return None


__all__ = [
    'init_db',
    'upsert_device_state',
    'get_device_by_device_id',
    'get_device_by_topic',
    'list_devices',
    'save_context_snapshot',
    'save_schedule_job',
    'get_schedule_jobs',
    'update_schedule_job_enabled',
    'save_memory_entry',
]
