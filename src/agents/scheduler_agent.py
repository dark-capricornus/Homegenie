"""
SchedulerAgent - persistent scheduler backed by db_v2 and in-memory tasks

This agent provides basic scheduling features:
- schedule_job(job_dict) -> creates job in DB and schedules execution
- cancel_job(job_id) -> cancels in-memory task and disables job in DB
- list_jobs() -> returns jobs from DB

Behavior:
- On start, loads enabled jobs from DB and schedules pending ones.
- Execution model: supports `run_at` ISO timestamp or `delay_seconds` in job dict.
- For recurring cron jobs we store cron expression but do not implement a full cron runner in this patch.

"""
from __future__ import annotations

import asyncio
import logging
import typing
from typing import Optional, Dict, Any, Callable
from datetime import datetime, timezone, timedelta

from src.core import db_async as db_v2

logger = logging.getLogger(__name__)


class SchedulerAgent:
    def __init__(self, loop: Optional[asyncio.AbstractEventLoop] = None, executor: Optional[Callable] = None):
        # Do not bind to an event loop at import time; use the running loop when scheduling
        self.loop = loop
        self._tasks: Dict[int, asyncio.Task] = {}
        self._running = False
        # executor callable will be invoked with job data when job fires
        self.executor = executor

    async def start(self):
        if self._running:
            return
        self._running = True
        # Load jobs from DB and schedule
        try:
            jobs = await db_v2.get_schedule_jobs()
            for j in jobs:
                if j.enabled:
                    await self._schedule_db_job(j)
        except Exception as e:
            logger.warning(f"SchedulerAgent failed to load jobs on start: {e}")

    async def stop(self):
        self._running = False
        # cancel all tasks
        for job_id, task in list(self._tasks.items()):
            task.cancel()
        self._tasks.clear()

    async def schedule_job(self, job: Dict[str, Any]) -> Optional[int]:
        """Persist job and schedule it. Job may include run_at (ISO) or delay_seconds."""
        job_id = await db_v2.save_schedule_job(job)
        # fetch created job row
        try:
            jobs = await db_v2.get_schedule_jobs(job_id=job_id)
            if jobs:
                await self._schedule_db_job(jobs[0])
        except Exception:
            logger.debug("Could not fetch scheduled job row after save; continuing")
        if isinstance(job_id, int):
            return job_id
        if isinstance(job_id, str) and job_id.isdigit():
            return int(job_id)
        return -1

    async def _schedule_db_job(self, job_row):
        """Create an asyncio Task to execute the job when its run_at arrives."""
        job_id = int(job_row.id)
        if job_id in self._tasks:
            # avoid double-scheduling
            return

        # determine next run
        run_at = None
        if getattr(job_row, 'next_run', None):
            run_at = job_row.next_run
        else:
            # no explicit next_run; if data contains delay_seconds, compute
            try:
                data = job_row.data or {}
                delay = int(data.get('delay_seconds', 0))
                if delay > 0:
                    run_at = datetime.now(timezone.utc) + timedelta(seconds=delay)
            except Exception:
                run_at = None

        if run_at is None:
            # nothing to schedule now
            return

        # convert to timestamp
        now = datetime.now(timezone.utc)
        if isinstance(run_at, str):
            try:
                run_at = datetime.fromisoformat(run_at)
                if run_at.tzinfo is None:
                    run_at = run_at.replace(tzinfo=timezone.utc)
            except Exception:
                logger.warning(f"Invalid run_at for job {job_id}: {run_at}")
                return

        delay = (run_at - now).total_seconds()
        if delay < 0:
            # run in the past -> run immediately
            delay = 0

        async def _runner():
            try:
                logger.info(f"SchedulerAgent: job {job_id} will run after {delay} seconds (now={now}, run_at={run_at})")
                await asyncio.sleep(delay)
                logger.info(f"SchedulerAgent: job {job_id} is firing now")
                # When job fires, call executor if provided
                if self.executor:
                    await maybe_await(self.executor(job_row))
                else:
                    # Fallback: if no executor was wired (e.g., app lifespan didn't run),
                    # try to call the global executor_agent from the API server module.
                    try:
                        from src.api import api_server as api_mod
                        task = (job_row.data or {}).get('task')
                        if task and hasattr(api_mod, 'executor_agent'):
                            if not api_mod.executor_agent._connected:
                                await api_mod.executor_agent.connect()
                            await maybe_await(api_mod.executor_agent.execute(task))
                    except Exception:
                        logger.debug("No fallback executor available or fallback failed")
                # After run, mark disabled if not recurring
                await db_v2.update_schedule_job_enabled(job_id, False)
            except asyncio.CancelledError:
                logger.info(f"Job {job_id} cancelled before execution")
            except Exception as e:
                logger.error(f"Error running job {job_id}: {e}")
            finally:
                # cleanup
                self._tasks.pop(job_id, None)

        # Schedule the runner on the currently running event loop so tests using pytest-asyncio
        # (which provide their own loop) will execute tasks correctly.
        try:
            task = asyncio.get_running_loop().create_task(_runner())
        except RuntimeError:
            # Fallback: no running loop, create task using asyncio.create_task
            task = asyncio.create_task(_runner())
        self._tasks[job_id] = task

    async def cancel_job(self, job_id: int) -> bool:
        task = self._tasks.get(job_id)
        if task:
            task.cancel()
            self._tasks.pop(job_id, None)
        # disable in DB
        await db_v2.update_schedule_job_enabled(job_id, False)
        return True

    async def list_jobs(self, user_id: Optional[str] = None):
        return await db_v2.get_schedule_jobs(user_id=user_id)


async def maybe_await(result):
    if asyncio.iscoroutine(result):
        return await result
    return result
