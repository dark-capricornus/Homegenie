import asyncio
import importlib
import json
import sys
import logging
from httpx import AsyncClient, ASGITransport

# ensure repository root is on sys.path so `import src` works
sys.path.insert(0, r"D:\Homegenie")
logging.basicConfig(level=logging.INFO)

async def main():
    # init in-memory db
    settings_mod = importlib.import_module('src.core.settings_v2')
    settings_mod.settings_v2.POSTGRES_URL = 'sqlite+aiosqlite:///:memory:'
    db_v2 = importlib.import_module('src.core.db_v2')
    try:
        setattr(db_v2, "_engine", None)
        setattr(db_v2, "_async_session", None)
    except Exception:
        pass
    await db_v2.init_db()

    api_server = importlib.import_module('src.api.api_server')

    calls = []
    async def recording_execute(task):
        print('recording_execute called with:', task)
        calls.append(task)
        return True

    api_server.executor_agent._connected = True
    api_server.executor_agent.execute = recording_execute

    transport = ASGITransport(app=api_server.app)
    async with AsyncClient(transport=transport, base_url='http://testserver') as ac:
        # create schedule
        payload = {
            'name': 'fire-job',
            'delay_seconds': 1,
            'data': {'user_id': 'exec_user', 'task': {'device': 'light.exec', 'action': 'turn_on'}}
        }
        r = await ac.post('/schedules', json=payload)
        print('POST /schedules status:', r.status_code, r.text)
        created = r.json()
        job_id = created.get('id')
        print('created job id', job_id)
        print('scheduler_agent tasks after POST:', list(api_server.scheduler_agent._tasks.keys()))
        await asyncio.sleep(1.5)
        print('executor calls after sleep:', calls)
        print('scheduler_agent tasks after sleep:', list(api_server.scheduler_agent._tasks.keys()))
        rows = await db_v2.get_schedule_jobs(job_id=job_id)
        print('db rows:', rows)

if __name__ == '__main__':
    asyncio.run(main())
