"""Optional settings v2 which reads environment variables for new features.

This module is additive and does not replace existing `config/settings.py`.
It should be imported only when feature-flagged or by new `_v2` modules.
"""
from __future__ import annotations

import os
from typing import Optional


def getenv_str(key: str, default: Optional[str] = None) -> Optional[str]:
    # Return the environment value or the provided default. Keep Optional[str]
    return os.getenv(key, default)


class SettingsV2:
    POSTGRES_URL: Optional[str]
    POSTGRES_USER: Optional[str]
    POSTGRES_PASSWORD: Optional[str]
    POSTGRES_DB: Optional[str]
    POSTGRES_HOST: Optional[str]
    POSTGRES_PORT: Optional[str]

    API_HOST: Optional[str]
    API_PORT: Optional[str]

    ENABLE_POSTGRES_MIGRATION: bool

    def __init__(self) -> None:
        self.POSTGRES_USER = getenv_str("POSTGRES_USER")
        self.POSTGRES_PASSWORD = getenv_str("POSTGRES_PASSWORD")
        self.POSTGRES_DB = getenv_str("POSTGRES_DB")
        self.POSTGRES_HOST = getenv_str("POSTGRES_HOST", "localhost")
        self.POSTGRES_PORT = getenv_str("POSTGRES_PORT", "5432")

        # If POSTGRES_URL is set, prefer it
        self.POSTGRES_URL = getenv_str("POSTGRES_URL") or (
            f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
            if self.POSTGRES_USER and self.POSTGRES_PASSWORD and self.POSTGRES_DB else None
        )
        # Ensure API host/port are set; allow Optional typing for static checkers
        self.API_HOST = getenv_str("API_HOST", "localhost") or "localhost"
        self.API_PORT = getenv_str("API_PORT", "8080") or "8080"

        # Guard .lower() against None by falling back to string "false"
        self.ENABLE_POSTGRES_MIGRATION = (getenv_str("ENABLE_POSTGRES_MIGRATION", "false") or "false").lower() in ("1", "true", "yes")


settings_v2 = SettingsV2()


__all__ = ["settings_v2"]
