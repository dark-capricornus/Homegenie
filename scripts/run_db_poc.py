import os
import asyncio

# On Windows, the default ProactorEventLoop is not compatible with psycopg async; use the
# SelectorEventLoopPolicy for compatibility. See psycopg docs for details.
try:
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
except Exception:
    # Not on Windows or policy already set
    pass

# ensure env vars for db connection
os.environ['POSTGRES_URL'] = os.environ.get('POSTGRES_URL', 'postgresql+psycopg://homegenie:changeme@localhost:5432/homegenie_db')
os.environ['ENABLE_POSTGRES_MIGRATION'] = 'true'

from src.core import db_v2
from src.core.context_store import ContextStore

async def main():
    print('Initializing DB...')
    try:
        await db_v2.init_db()
    except Exception as e:
        print('init_db error:', e)
        return

    cs = ContextStore()
    # Optionally populate cs with a small state
    try:
        sid = await db_v2.save_context_snapshot(cs)
        print('Saved snapshot id:', sid)
    except Exception as e:
        print('save_context_snapshot error:', e)

if __name__ == '__main__':
    asyncio.run(main())
