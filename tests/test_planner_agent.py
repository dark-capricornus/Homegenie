import os
import asyncio
import pytest

from src.agents.planner_agent import PlannerAgent

@pytest.mark.asyncio
async def test_heuristic_fallback_simple_goal():
    # Ensure LLM disabled
    os.environ.pop('LLM_ENABLED', None)
    p = PlannerAgent(context_store=None, memory_fetcher=None, llm_client=None)

    tasks = await p.plan("turn on the lights", user_id="user1")
    assert isinstance(tasks, list)
    assert any(t.get('action') in ('turn_on', 'set_brightness') for t in tasks)


@pytest.mark.asyncio
async def test_fake_llm_sync_client():
    os.environ['LLM_ENABLED'] = 'true'

    def fake_llm(payload):
        # Return a structured plan
        return [{"device": "light.fake", "action": "turn_off"}]

    p = PlannerAgent(context_store=None, memory_fetcher=None, llm_client=fake_llm)
    tasks = await p.plan("please turn off lights", user_id="user2")
    assert isinstance(tasks, list)
    assert tasks and tasks[0]['device'] == 'light.fake'

    os.environ.pop('LLM_ENABLED', None)


@pytest.mark.asyncio
async def test_fake_llm_async_client():
    os.environ['LLM_ENABLED'] = 'true'

    async def fake_llm_async(payload):
        await asyncio.sleep(0)
        return [{"device": "light.async", "action": "set_brightness", "value": 30}]

    p = PlannerAgent(context_store=None, memory_fetcher=None, llm_client=fake_llm_async)
    tasks = await p.plan("dim the lights", user_id="user3")
    assert isinstance(tasks, list)
    assert tasks and tasks[0]['device'] == 'light.async'

    os.environ.pop('LLM_ENABLED', None)


@pytest.mark.asyncio
async def test_empty_goal_validation():
    os.environ.pop('LLM_ENABLED', None)
    p = PlannerAgent(context_store=None, memory_fetcher=None, llm_client=None)
    tasks = await p.plan("", user_id="user4")
    # Should return a sensible fallback (non-empty)
    assert isinstance(tasks, list)
    assert len(tasks) > 0
