"""
PlannerAgent - LLM-capable planner with deterministic fallback

Interface:
    async def plan(self, goal: str, user_id: str | None, context: dict | None, history: list | None) -> list[dict]

The agent accepts an optional `llm_client` callable which, when provided
and when `LLM_ENABLED` is truthy in environment/settings, will be used to
generate structured plans. Otherwise a heuristic fallback is used.

PlannerAgent is designed to be imported and instantiated by `api_server`.
"""
from __future__ import annotations

import os
import asyncio
import logging
from typing import Optional, Callable, List, Dict, Any
from datetime import datetime

logger = logging.getLogger(__name__)


class PlannerAgent:
    def __init__(self, context_store=None, memory_fetcher: Optional[Callable] = None, llm_client: Optional[Callable] = None):
        """Create a PlannerAgent.

        Args:
            context_store: reference to ContextStore (in-memory)
            memory_fetcher: optional callable user_id -> list[history entries]
            llm_client: optional callable to forward requests to an LLM
        """
        self.context_store = context_store
        self.memory_fetcher = memory_fetcher
        self.llm_client = llm_client
        # LLM enabled if environment variable set and client provided
        self.llm_enabled = (os.getenv("LLM_ENABLED", "false").lower() in ("1", "true", "yes")) and (self.llm_client is not None)

    async def plan(self, goal: str, user_id: Optional[str] = None, context: Optional[Dict[str, Any]] = None, history: Optional[List[Dict[str, Any]]] = None) -> List[Dict[str, Any]]:
        """Return a structured plan for the goal.

        This will call an LLM client if configured; otherwise use a local
        deterministic fallback planner.
        """
        # Gather context if not provided
        if context is None and self.context_store is not None:
            try:
                context = await self.context_store.async_dump()
            except Exception:
                # fallback to sync
                context = self.context_store.dump() if self.context_store else {}

        # Gather history if not provided. Be careful: memory_fetcher may be None
        if history is None and (self.memory_fetcher is not None) and user_id:
            mem_fetcher = self.memory_fetcher
            try:
                # If memory_fetcher is blocking, run in executor
                if asyncio.iscoroutinefunction(mem_fetcher):
                    history = await mem_fetcher(user_id, 20)
                else:
                    history = await asyncio.get_event_loop().run_in_executor(None, lambda: mem_fetcher(user_id, 20))
            except Exception:
                try:
                    history = mem_fetcher(user_id, 20)
                except Exception:
                    history = []

        # If LLM is enabled, delegate to it
        if self.llm_enabled and (self.llm_client is not None):
            llm = self.llm_client
            try:
                # llm_client should accept a dict payload and return structured plan
                payload = {
                    "goal": goal,
                    "user_id": user_id,
                    "context": context,
                    "history": history
                }
                # Support both sync and async llm clients
                if asyncio.iscoroutinefunction(llm):
                    plan = await llm(payload)
                else:
                    plan = await asyncio.get_event_loop().run_in_executor(None, lambda: llm(payload))

                if isinstance(plan, list):
                    return plan
            except Exception as e:
                logger.warning(f"LLM planner failed, falling back to heuristic: {e}")

        # Deterministic fallback
        return self._heuristic_plan(goal, user_id, context, history)

    def _heuristic_plan(self, goal: str, user_id: Optional[str], context: Optional[Dict[str, Any]], history: Optional[List[Dict[str, Any]]]) -> List[Dict[str, Any]]:
        """Simplified rule-based planner copied/adapted from previous heuristic logic.

        Returns a list of task dicts suitable for ExecutorAgent.execute
        """
        goal_lower = (goal or "").lower()
        tasks: List[Dict[str, Any]] = []

        # Simple rule set
        if "goodnight" in goal_lower or "sleep" in goal_lower:
            tasks = [
                {"device": "light.bedroom", "action": "set_brightness", "value": 10},
                {"device": "light.living_room", "action": "turn_off", "value": False},
                {"device": "thermostat.main", "action": "set_temperature", "value": 20.0},
                {"device": "lock.front_door", "action": "lock", "value": True}
            ]
        elif "good morning" in goal_lower or "wake up" in goal_lower:
            tasks = [
                {"device": "light.bedroom", "action": "set_brightness", "value": 75},
                {"device": "thermostat.main", "action": "set_temperature", "value": 22.0},
                {"device": "switch.coffee_maker", "action": "turn_on", "value": True}
            ]
        elif "movie" in goal_lower or "watch" in goal_lower:
            tasks = [
                {"device": "light.living_room", "action": "set_brightness", "value": 20},
                {"device": "light.kitchen", "action": "turn_off", "value": False},
                {"device": "thermostat.main", "action": "set_temperature", "value": 21.0}
            ]
        elif "party" in goal_lower or "entertainment" in goal_lower:
            tasks = [
                {"device": "light.living_room", "action": "set_color", "value": "#FF6B6B"},
                {"device": "light.kitchen", "action": "set_color", "value": "#4ECDC4"},
                {"device": "fan.living_room", "action": "set_speed", "value": 2}
            ]
        elif "away" in goal_lower or "leaving" in goal_lower:
            tasks = [
                {"device": "light.living_room", "action": "turn_off", "value": False},
                {"device": "light.bedroom", "action": "turn_off", "value": False},
                {"device": "light.kitchen", "action": "turn_off", "value": False},
                {"device": "thermostat.main", "action": "set_temperature", "value": 18.0},
                {"device": "lock.front_door", "action": "lock", "value": True}
            ]
        else:
            # Generic heuristics
            if "light" in goal_lower:
                if "on" in goal_lower:
                    tasks = [{"device": "light.living_room", "action": "turn_on", "value": True}]
                elif "off" in goal_lower:
                    tasks = [{"device": "light.living_room", "action": "turn_off", "value": False}]
            elif "temperature" in goal_lower or "temp" in goal_lower:
                tasks = [{"device": "thermostat.main", "action": "set_temperature", "value": 22.0}]
            else:
                tasks = [{"device": "light.living_room", "action": "turn_on", "value": True, "reason": f"Unknown goal: {goal}"}]

        # Optionally personalize with history (very small heuristic)
        if history and isinstance(history, list):
            # If user often uses a specific brightness, prefer it
            for h in history[-5:]:
                data = h.get("data") if isinstance(h, dict) else None
                if data and data.get("action") == "set_brightness":
                    tasks = [{"device": "light.living_room", "action": "set_brightness", "value": data.get("value", 75)}]
                    break

        logger.info(f"Planned {len(tasks)} tasks for goal '{goal}' (LLM enabled={self.llm_enabled})")
        return tasks
