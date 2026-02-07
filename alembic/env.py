import asyncio
import os
import sys
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.engine.url import make_url
from sqlalchemy.ext.asyncio import create_async_engine

from alembic import context

# Ensure src is importable for local runs
repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
src_path = os.path.join(repo_root, 'src')
if src_path not in sys.path:
    sys.path.insert(0, src_path)

# On Windows, the default ProactorEventLoop is incompatible with psycopg async
# connections used by SQLAlchemy/psycopg in some environments. Force the
# SelectorEventLoop policy when running migrations on Windows so psycopg can
# create async connections successfully.
if sys.platform == "win32":
    try:
        import asyncio as _asyncio
        from asyncio import WindowsSelectorEventLoopPolicy as _WinPolicy

        _asyncio.set_event_loop_policy(_WinPolicy())
    except Exception:
        # Best-effort; if this fails, migrations may still run in a different env
        pass

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Interpret the config file for Python logging.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

from typing import Optional
from sqlmodel import SQLModel

# Import application's models so they are in metadata
# (db_v2 defines ContextSnapshot as table=True)
try:
    import src.core.db_async as db_v2  # noqa: F401
except Exception:
    # If import fails, we'll still use SQLModel.metadata if available
    db_v2 = None

target_metadata = SQLModel.metadata


def get_url() -> Optional[str]:
    # Prefer explicit env var
    url = os.getenv('POSTGRES_URL')
    if url:
        return url

    # Fallback to settings_v2 in repo
    try:
        from src.core.settings_v2 import settings_v2
        return getattr(settings_v2, 'POSTGRES_URL', None)
    except Exception:
        return None


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = get_url()
    if not url:
        raise RuntimeError('POSTGRES_URL not configured for offline migrations')

    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode (async)."""
    url = get_url()
    if not url:
        raise RuntimeError('POSTGRES_URL not configured for online migrations')

    # Alembic wants a sync engine for connection then run migrations in sync context
    connectable = create_async_engine(url, poolclass=pool.NullPool)

    async def do_run():
        async with connectable.connect() as connection:
            await connection.run_sync(do_run_migrations)

    asyncio.run(do_run())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
