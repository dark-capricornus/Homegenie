"""
PlannerAgent - Agentic Planner with LLM Integration

This module provides the PlannerAgent which converts natural language goals
into structured automation plans. It prioritizes LLM-based reasoning (OpenAI/Gemini compatible)
and falls back to a structured keyword-based matcher if the LLM is unavailable.

Interface:
    async def plan(self, goal: str, user_id: str | None, ...): -> list[dict]
"""
from __future__ import annotations

import os
import asyncio
import logging
import json
import re
from typing import Optional, Callable, List, Dict, Any
from datetime import datetime
import concurrent.futures

logger = logging.getLogger(__name__)

class PlannerAgent:
    def __init__(self, context_store=None, memory_fetcher: Optional[Callable] = None, llm_client: Optional[Callable] = None):
        """
        Args:
            context_store: Reference to ContextStore (in-memory)
            memory_fetcher: optional callable user_id -> list[history entries]
            llm_client: optional callable to forward requests to an LLM
        """
        self.context_store = context_store
        self.memory_fetcher = memory_fetcher
        # If llm_client is provided, we use it. 
        # Otherwise checking env vars for direct API usage could be added here.
        self.llm_client = llm_client
        self.llm_enabled = (os.getenv("LLM_ENABLED", "false").lower() in ("1", "true", "yes"))
        
        # AI Workload Isolation: ThreadPoolExecutor for CPU-bound LLM work
        # This prevents blocking the main asyncio loop during LLM inference
        self._llm_executor = concurrent.futures.ThreadPoolExecutor(
            max_workers=2,
            thread_name_prefix="llm_worker"
        )
        logger.info("PlannerAgent initialized with LLM workload isolation (ThreadPoolExecutor)")


    async def plan(self, goal: str, user_id: Optional[str] = None, context: Optional[Dict[str, Any]] = None, history: Optional[List[Dict[str, Any]]] = None) -> List[Dict[str, Any]]:
        """
        Generate a plan for the given goal.
        
        Returns:
            List of task dicts (e.g. [{"device": "light.main", "action": "turn_on"}]).
        """
        # 1. Gather Context
        if context is None and self.context_store is not None:
            try:
                context = await self.context_store.async_dump()
            except Exception:
                context = {}

        # 2. Try LLM Planning (with workload isolation)
        if self.llm_enabled and self.llm_client:
            try:
                # Run LLM in background thread pool with timeout
                # This prevents blocking the main asyncio loop
                loop = asyncio.get_running_loop()
                plan = await asyncio.wait_for(
                    loop.run_in_executor(
                        self._llm_executor,
                        self._llm_plan_sync,  # Synchronous version
                        goal, context, user_id
                    ),
                    timeout=10.0  # 10 second max for LLM response
                )
                if plan:
                    logger.info(f"✅ LLM plan generated for goal: {goal}")
                    return plan
            except asyncio.TimeoutError:
                logger.warning(f"⏱️ LLM timeout after 10s, falling back to structured planner")
            except Exception as e:
                logger.error(f"❌ LLM planning failed: {e}, falling back to structured planner")
        
        # 3. Fallback to Structured Rule Matcher (Improved Heuristic)
        return self._structured_fallback_plan(goal)


    def _llm_plan_sync(self, goal: str, context: Dict[str, Any], user_id: str | None) -> List[Dict[str, Any]]:
        """
        Synchronous LLM planning method for ThreadPoolExecutor.
        This runs in a background thread to avoid blocking the main asyncio loop.
        
        Use the LLM client to parse intent and generate strict JSON plan.
        """
        # Construct a prompt that enforces valid JSON output
        system_prompt = (
            "You are a Smart Home Agent. Your task is to convert user goals into a JSON execution plan.\n"
            "Available devices: " + json.dumps(list(context.get('states', {}).keys())) + "\n"
            "Output Format: JSON Array of objects with 'device', 'action', 'value' (optional).\n"
            "Example: [{'device': 'light.living_room', 'action': 'turn_on', 'value': true}]\n"
            "Do NOT output markdown, just the JSON."
        )
        
        payload = {
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": goal}
            ],
            "temperature": 0.1
        }
        
        logger.info(f"🧠 Asking LLM to plan (background thread): {goal}")
        
        # Call LLM client (blocking call, but we're in a thread pool)
        if callable(self.llm_client):
            response = self.llm_client(payload)
        else:
            return []
            
        # Parse response (assuming client returns dict with 'content' or direct string)
        content = response.get("content", "") if isinstance(response, dict) else str(response)
        
        # Clean markdown code blocks if present
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0].strip()
        elif "```" in content:
            content = content.split("```")[1].strip()
            
        try:
            plan = json.loads(content)
            if isinstance(plan, list):
                return plan
            elif isinstance(plan, dict) and "plan" in plan:
                return plan["plan"]
        except json.JSONDecodeError:
            logger.error(f"Failed to parse LLM response: {content}")
            
        return []


    def _structured_fallback_plan(self, goal: str) -> List[Dict[str, Any]]:
        """
        A robust keyword matcher that handles synonyms and common patterns without rigid if/else trees.
        """
        goal = goal.lower().strip()
        tasks = []
        
        # 1. Define Intent Patterns
        # (regex, [tasks])
        patterns = [
            (
                r"(goodnight|sleep|bedtime)", 
                [
                    {"device": "light.living_room", "action": "turn_off"},
                    {"device": "light.kitchen", "action": "turn_off"},
                    {"device": "light.bedroom", "action": "set_brightness", "value": 10},
                    {"device": "lock.front_door", "action": "lock"},
                    {"device": "thermostat.main", "action": "set_temperature", "value": 20.0}
                ]
            ),
            (
                r"(morning|wake up|rise)", 
                [
                    {"device": "light.bedroom", "action": "set_brightness", "value": 80},
                    {"device": "switch.coffee_maker", "action": "turn_on"},
                    {"device": "thermostat.main", "action": "set_temperature", "value": 22.0}
                ]
            ),
            (
                r"(party|entertainment|music)", 
                [
                    {"device": "light.living_room", "action": "set_color", "value": "purple"},
                    {"device": "light.kitchen", "action": "set_color", "value": "blue"},
                    {"device": "fan.living_room", "action": "set_speed", "value": 2}
                ]
            ),
            (
                r"(movie|cinema|watch)", 
                [
                     {"device": "light.living_room", "action": "set_brightness", "value": 15},
                     {"device": "light.kitchen", "action": "turn_off"},
                ]
            ),
            (
                r"(leave|leaving|away|out)", 
                [
                    {"device": "light.living_room", "action": "turn_off"}, 
                    {"device": "light.bedroom", "action": "turn_off"},
                    {"device": "thermostat.main", "action": "set_temperature", "value": 18.0},
                    {"device": "lock.front_door", "action": "lock"}
                ]
            )
        ]
        
        # Check high-level intents first
        for pattern, pattern_tasks in patterns:
            if re.search(pattern, goal):
                logger.info(f"⚡ Matched intent pattern: '{pattern}'")
                return pattern_tasks

        # 2. Dynamic Entity Extraction (Simple)
        # "turn on living room light" -> action: turn_on, target: light.living_room
        
        # Map actions
        action_map = {
            "on": "turn_on",
            "off": "turn_off",
            "lock": "lock",
            "unlock": "unlock",
            "open": "unlock",
            "close": "lock",
            "dim": "set_brightness",
            "brighten": "set_brightness",
            "set": "set"
        }
        
        detected_action = "turn_on" # default
        for word, act in action_map.items():
            if word in goal:
                detected_action = act
                break
        
        # Map devices (naive fuzzy match)
        device_map = {
            "living": "light.living_room",
            "kitchen": "light.kitchen",
            "bedroom": "light.bedroom",
            "coffee": "switch.coffee_maker",
            "thermostat": "thermostat.main",
            "ac": "thermostat.main",
            "heater": "thermostat.main",
            "door": "lock.front_door",
            "fan": "fan.living_room"
        }
        
        target_device = "light.living_room" # default default
        for keyword, dev_id in device_map.items():
            if keyword in goal:
                target_device = dev_id
                break
        
        # Value extraction
        value = None
        # Extract number
        numbers = re.findall(r"\d+", goal)
        if numbers:
            value = float(numbers[0])
            if detected_action == "set_brightness" and value > 1:
                # heuristic: if user says 50, they mean 50%
                pass
        else:
             if detected_action == "turn_on": value = True
             if detected_action == "turn_off": value = False
        
        task = {
            "device": target_device, 
            "action": detected_action,
            "reason": f"Dynamic match from '{goal}'"
        }
        if value is not None:
            task["value"] = value
            
        logger.info(f"🧩 Dynamic fallback planned: {task}")
        return [task]
