"""Feature-flagged migration API endpoints (v2).

Endpoints here are only included when `ENABLE_POSTGRES_MIGRATION` flag is enabled.
They intentionally provide explicit triggers for migration operations (no automatic
background migration).
"""
from __future__ import annotations

from fastapi import APIRouter, HTTPException

from src.core.feature_flags import flags
from src.core.settings_v2 import settings_v2


router = APIRouter()


@router.post("/v2/migrate/contextstore")
async def migrate_contextstore_handler():
    """Trigger saving current in-memory ContextStore into Postgres.

    This endpoint is intentionally guarded by the feature flag. It will return
    HTTP 403 if the flag is disabled, and 400 if Postgres isn't configured.
    """
    if not flags.ENABLE_POSTGRES_MIGRATION:
        raise HTTPException(status_code=403, detail="Postgres migration disabled by feature flag")

    if not settings_v2.POSTGRES_URL:
        raise HTTPException(status_code=400, detail="Postgres not configured (POSTGRES_URL missing)")

    # Import lazily to avoid circular imports during app startup
    try:
        from src.core import db_async as db_v2
        # context_store is created in api_server and imported here to capture current state
        from src.api.api_server import context_store
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal import error: {e}")

    try:
        # Initialize tables if necessary
        await db_v2.init_db()
        snapshot_id = await db_v2.save_context_snapshot(context_store)
        return {"status": "ok", "snapshot_id": snapshot_id}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save snapshot: {e}")


__all__ = ["router"]
