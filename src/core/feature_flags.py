"""Feature flags central module (non-destructive).

New features must be guarded by these flags. Defaults are conservative
and set to disabled for production-safety.

Usage:
    from src.core.feature_flags import flags
    if flags.ENABLE_POSTGRES_MIGRATION:
        ...
"""
from __future__ import annotations

import os
from dataclasses import dataclass


def _env_bool(name: str, default: bool = False) -> bool:
    val = os.getenv(name)
    if val is None:
        return default
    return val.lower() in ("1", "true", "yes", "on")


@dataclass(frozen=True)
class FeatureFlags:
    ENABLE_POSTGRES_MIGRATION: bool = _env_bool("ENABLE_POSTGRES_MIGRATION", False)
    ENABLE_REDIS_BRIDGE: bool = _env_bool("ENABLE_REDIS_BRIDGE", False)
    ENABLE_ALEXA_BRIDGE: bool = _env_bool("ENABLE_ALEXA_BRIDGE", False)
    ENABLE_GOOGLE_BRIDGE: bool = _env_bool("ENABLE_GOOGLE_BRIDGE", False)
    ENABLE_WS_BRIDGE: bool = _env_bool("ENABLE_WS_BRIDGE", False)


# Singleton flags object for import convenience
flags = FeatureFlags()


__all__ = ["flags"]
