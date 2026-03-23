"""
ReActAgent — Observe-Think-Act reasoning loop for HomeGenie.

Replaces the one-shot planner with a multi-step agent that can:
  1. Classify intent and extract entities via structured tool calling
  2. Execute tools (control_device, query_device, etc.)
  3. Observe results and decide the next step
  4. Handle disambiguation ("which room?") with slot filling
  5. Decompose complex goals into sub-tasks

The LLM is prompted to respond with a JSON action at each step.
Max iterations prevent runaway loops.
"""
from __future__ import annotations

import json
import os
import re
import asyncio
import logging
from typing import Any, Callable, Awaitable, Dict, List, Optional
from datetime import datetime

from src.agents.tool_registry import ToolRegistry
from src.agents.conversation import ConversationManager

logger = logging.getLogger(__name__)

MAX_ITERATIONS = 6
AGENT_TIMEOUT = float(os.getenv("AGENT_TIMEOUT", "90.0"))


def _build_system_prompt(
    device_list: List[str],
    tool_schemas: List[Dict[str, Any]],
    conversation_context: str,
) -> str:
    """Build the system prompt that turns the LLM into a ReAct agent."""
    tools_desc = json.dumps(tool_schemas, indent=2)
    devices = ", ".join(device_list) if device_list else "(no devices loaded yet)"

    return f"""You are HomeGenie, an intelligent home automation agent.

## Available devices
{devices}

## Conversation context
{conversation_context if conversation_context else "No prior context."}

## Available tools
{tools_desc}

## How to respond
You MUST respond with a single JSON object (no markdown, no extra text).

If you need to use a tool:
{{"thought": "<brief reasoning>", "tool": "<tool_name>", "arguments": {{...}}}}

If you are done (all actions complete, or you just need to reply to the user):
{{"thought": "<brief reasoning>", "tool": "respond_to_user", "arguments": {{"message": "<your response>"}}}}

If the user's request is ambiguous (e.g. "the light" when multiple exist):
{{"thought": "<reasoning>", "tool": "ask_clarification", "arguments": {{"question": "...", "options": [...]}}}}

## Rules
- When the user says "it", "that", "the same one", refer to the conversation context for the last-mentioned device.
- For composite goals like "goodnight" or "movie time", decompose into multiple tool calls — you will get multiple turns.
- After each tool call you'll see the result. Decide if you need another action or can respond.
- Always use device IDs from the device list (e.g. "light.living_room"), not free-form names.
- If a device_id is ambiguous (multiple matches), use ask_clarification.
- NEVER invent devices that aren't in the list.
- JSON only. No markdown fences."""


class ReActAgent:
    """
    Multi-step reasoning agent with tool calling.

    Flow per request:
        1. Build system prompt with tools + device list + conversation context
        2. Send user message to LLM
        3. Parse JSON → extract tool call
        4. Execute tool → append result
        5. Loop back to step 2 (with updated history) until LLM emits
           respond_to_user / ask_clarification or max iterations reached.
    """

    def __init__(
        self,
        tool_registry: ToolRegistry,
        conversation: ConversationManager,
        llm_caller: Callable[..., Awaitable[Any]],
        context_store: Any = None,
    ) -> None:
        self.tools = tool_registry
        self.conversation = conversation
        self.llm_caller = llm_caller
        self.context_store = context_store

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    async def process(
        self,
        user_message: str,
        user_id: str,
        device_list: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """
        Process a user message through the ReAct loop.

        Returns:
            {
                "response": str,           # text to show the user
                "actions_taken": [...],     # list of tool calls executed
                "iterations": int,
            }
        """
        # Record user message
        self.conversation.add_message(user_id, "user", user_message)

        # Check for pending slot-fill (disambiguation follow-up)
        slot = self.conversation.get_pending_slot(user_id)
        if slot and slot.original_intent:
            # User is answering a disambiguation question — inject context
            user_message = (
                f"(Answering: {slot.pending_question}) "
                f"User chose: {user_message}. "
                f"Original request: {json.dumps(slot.original_intent)}"
            )
            self.conversation.clear_slot(user_id)

        # Build device list from context store
        if device_list is None:
            device_list = await self._get_device_list()

        # ── Fast path: simple commands without LLM (~0ms vs ~20-40s) ──
        fast_results = self._try_fast_match(user_message, device_list)
        if fast_results is not None:
            actions = []
            responses = []
            for fast in (fast_results if isinstance(fast_results, list) else [fast_results]):
                tool_name = fast["tool"]
                arguments = fast["arguments"]
                result = await self.tools.execute(tool_name, arguments)
                self._update_entities(user_id, tool_name, arguments)
                actions.append({"tool": tool_name, "arguments": arguments,
                                "result": result, "iteration": 0})

                device_id = arguments.get("device_id", "device")
                friendly = self._friendly_name(device_id)

                if tool_name == "query_device":
                    # Format query result in human-readable form
                    if "error" in result:
                        responses.append(f"couldn't read {friendly}: {result['error']}")
                    else:
                        state = result.get("state", {})
                        responses.append(f"{friendly}: {self._format_state(state)}")
                elif tool_name == "list_devices":
                    devices = result.get("devices", [])
                    count = result.get("count", len(devices))
                    room = arguments.get("room")
                    if room:
                        room_friendly = room.replace("_", " ")
                        device_names = ", ".join(d.replace(".", " ").replace("_", " ") for d in devices)
                        responses.append(f"{count} device(s) in {room_friendly}: {device_names}")
                    else:
                        responses.append(f"{count} device(s) total: {', '.join(devices[:10])}")
                else:
                    action = arguments.get("action", "")
                    action_past = {
                        "turn_on": "turned on", "turn_off": "turned off",
                        "lock": "locked", "unlock": "unlocked", "toggle": "toggled",
                        "set_brightness": "brightness set for",
                        "set_temperature": "temperature set for",
                    }.get(action, action)
                    if result.get("success"):
                        responses.append(f"{friendly} {action_past}")
                    else:
                        responses.append(f"failed to {action} {friendly}: {result.get('error', 'unknown')}")

            response = "Done — " + ", ".join(responses) + "." if responses else "Done."
            self.conversation.add_message(user_id, "assistant", response)
            return {"response": response, "actions_taken": actions, "iterations": 0}

        # Build context
        conv_context = self.conversation.build_context_block(user_id)
        system_prompt = _build_system_prompt(
            device_list, self.tools.schemas(), conv_context
        )

        # Assemble message history for the LLM
        history = self.conversation.get_history(user_id, last_n=8)
        messages = [{"role": "system", "content": system_prompt}]
        messages.extend(history)

        actions_taken: List[Dict[str, Any]] = []
        final_response = ""
        iterations = 0

        try:
            result = await asyncio.wait_for(
                self._react_loop(
                    messages, user_id, device_list, actions_taken
                ),
                timeout=AGENT_TIMEOUT,
            )
            final_response = result["response"]
            iterations = result["iterations"]
        except asyncio.TimeoutError:
            logger.warning(f"ReAct loop timed out for user {user_id}")
            final_response = "Sorry, that took too long. Please try a simpler command."
            iterations = MAX_ITERATIONS

        # Record assistant response
        self.conversation.add_message(user_id, "assistant", final_response)

        return {
            "response": final_response,
            "actions_taken": actions_taken,
            "iterations": iterations,
        }

    # ------------------------------------------------------------------
    # Core loop
    # ------------------------------------------------------------------
    async def _react_loop(
        self,
        messages: List[Dict[str, str]],
        user_id: str,
        device_list: List[str],
        actions_taken: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        for iteration in range(1, MAX_ITERATIONS + 1):
            # Call LLM
            raw = await self._call_llm(messages)
            parsed = self._parse_response(raw)

            if parsed is None:
                # LLM returned unparseable output — treat as final response
                return {"response": str(raw) if raw else "I couldn't process that.", "iterations": iteration}

            thought = parsed.get("thought", "")
            tool_name = parsed.get("tool", "")
            arguments = parsed.get("arguments", {})

            logger.info(f"[ReAct i={iteration}] thought={thought[:80]} tool={tool_name}")

            # Terminal tools — we're done
            if tool_name == "respond_to_user":
                msg = arguments.get("message", "Done.")
                return {"response": msg, "iterations": iteration}

            if tool_name == "ask_clarification":
                question = arguments.get("question", "Could you clarify?")
                options = arguments.get("options")
                # Save slot so the next user message is treated as an answer
                self.conversation.set_pending_slot(
                    user_id, question, options,
                    original_intent={"thought": thought},
                )
                return {"response": question, "iterations": iteration}

            # Execute tool
            result = await self.tools.execute(tool_name, arguments)
            actions_taken.append({
                "tool": tool_name,
                "arguments": arguments,
                "result": result,
                "iteration": iteration,
            })

            # Update entity memory based on the tool call
            self._update_entities(user_id, tool_name, arguments)

            # Record for conversation history
            call_summary = json.dumps({"tool": tool_name, **arguments})
            result_summary = json.dumps(result)
            self.conversation.add_message(user_id, "tool_call", call_summary)
            self.conversation.add_message(user_id, "tool_result", result_summary)

            # Append observation to LLM messages for the next iteration
            messages.append({"role": "assistant", "content": json.dumps(parsed)})
            messages.append({
                "role": "user",
                "content": f"Tool result: {result_summary}\nDecide: do you need another action, or respond to the user?",
            })

        # Max iterations reached
        if actions_taken:
            return {
                "response": f"Done. Executed {len(actions_taken)} action(s).",
                "iterations": MAX_ITERATIONS,
            }
        return {"response": "I wasn't able to complete that request.", "iterations": MAX_ITERATIONS}

    # ------------------------------------------------------------------
    # LLM calling
    # ------------------------------------------------------------------
    async def _call_llm(self, messages: List[Dict[str, str]]) -> Any:
        """Call the LLM via the provided async caller."""
        payload = {"messages": messages, "temperature": 0.1}
        try:
            return await self.llm_caller(payload)
        except Exception as e:
            logger.error(f"LLM call failed: {e}")
            return None

    # ------------------------------------------------------------------
    # Response parsing
    # ------------------------------------------------------------------
    def _parse_response(self, raw: Any) -> Optional[Dict[str, Any]]:
        """Extract a JSON dict with {thought, tool, arguments} from the LLM output."""
        if raw is None:
            return None

        text: str
        if isinstance(raw, dict):
            # Already parsed (Ollama adapter returns dict sometimes)
            if "tool" in raw:
                return raw
            text = raw.get("content", raw.get("text", json.dumps(raw)))
        elif isinstance(raw, str):
            text = raw
        else:
            text = str(raw)

        # Strip markdown code fences
        if "```json" in text:
            text = text.split("```json", 1)[1].split("```", 1)[0].strip()
        elif "```" in text:
            text = text.split("```", 1)[1].split("```", 1)[0].strip()

        # Try to parse JSON
        for candidate in [text, text.strip()]:
            try:
                obj = json.loads(candidate)
                if isinstance(obj, dict) and "tool" in obj:
                    return obj
                # Maybe the LLM wrapped it in a list
                if isinstance(obj, list) and obj and isinstance(obj[0], dict):
                    return self._convert_legacy_plan(obj)
            except (json.JSONDecodeError, ValueError):
                continue

        # Last resort: regex extract JSON object
        match = re.search(r'\{[^{}]*"tool"\s*:\s*"[^"]+?"[^{}]*\}', text, re.DOTALL)
        if match:
            try:
                return json.loads(match.group(0))
            except (json.JSONDecodeError, ValueError):
                pass

        logger.warning(f"Could not parse ReAct response: {text[:200]}")
        return None

    def _convert_legacy_plan(self, plan: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Convert an old-style [{device, action}] plan to a tool call."""
        if plan and "device" in plan[0]:
            first = plan[0]
            return {
                "thought": f"Executing plan with {len(plan)} step(s)",
                "tool": "control_device",
                "arguments": {
                    "device_id": first.get("device", ""),
                    "action": first.get("action", "turn_on"),
                    "value": str(first.get("value", "")) if first.get("value") is not None else None,
                },
            }
        return {"thought": "Unknown format", "tool": "respond_to_user",
                "arguments": {"message": "I couldn't understand the plan format."}}

    # ------------------------------------------------------------------
    # Entity tracking
    # ------------------------------------------------------------------
    def _update_entities(self, user_id: str, tool_name: str, args: Dict[str, Any]) -> None:
        if tool_name == "control_device":
            device_id = args.get("device_id", "")
            parts = device_id.split(".", 1)
            self.conversation.update_entities(
                user_id,
                device_id=device_id,
                device_type=parts[0] if parts else None,
                room=parts[1] if len(parts) > 1 else None,
                action=args.get("action"),
            )
        elif tool_name == "query_device":
            device_id = args.get("device_id", "")
            parts = device_id.split(".", 1)
            self.conversation.update_entities(
                user_id,
                device_id=device_id,
                device_type=parts[0] if parts else None,
                room=parts[1] if len(parts) > 1 else None,
            )

    # ------------------------------------------------------------------
    # Fast path — regex-based intent matching without LLM
    # ------------------------------------------------------------------
    _ACTION_PATTERNS = [
        # (regex, action, needs_value)
        (re.compile(r"\b(turn\s+on|switch\s+on|enable)\b", re.I), "turn_on", False),
        (re.compile(r"\b(turn\s+off|switch\s+off|disable)\b", re.I), "turn_off", False),
        (re.compile(r"\block\b", re.I), "lock", False),
        (re.compile(r"\bunlock\b", re.I), "unlock", False),
        (re.compile(r"\b(dim|set\s*(?:\w+\s+)*brightness|brightness)\b", re.I), "set_brightness", True),
        (re.compile(r"\b(set\s*(?:\w+\s+)*(?:temp(?:erature)?|thermostat)|temperature\s+to|thermostat\s+to)\b", re.I), "set_temperature", True),
        (re.compile(r"\btoggle\b", re.I), "toggle", False),
        (re.compile(r"\b(open)\b", re.I), "turn_on", False),
        (re.compile(r"\b(close)\b", re.I), "turn_off", False),
    ]

    _QUERY_PATTERNS = [
        re.compile(r"\b(what\s+is|what's)\b.*\b(temperature|temp|status|state|value|reading|level)\b", re.I),
        re.compile(r"\b(is\s+the|is\s+my)\b.*\b(on|off|locked|unlocked|open|closed|running)\b", re.I),
        re.compile(r"\b(status|state|reading|check)\b.*\bof\b", re.I),
        re.compile(r"\b(check|get|show|read|tell\s+me)\b.*\b(temperature|temp|humidity|status|state|power|energy)\b", re.I),
        re.compile(r"\bhow\s+(hot|cold|warm|cool)\b", re.I),
    ]

    _LIST_PATTERNS = [
        re.compile(r"\b(what|which|list|show|get)\b.*\bdevices?\b.*\b(in|for|of)\b", re.I),
        re.compile(r"\b(what|which)\b.*\b(in\s+the|in\s+my)\b.*\b(room|bedroom|kitchen|living|bathroom|hallway|garage|backyard|porch)\b", re.I),
        re.compile(r"\blist\b.*\b(all|every)?\s*devices?\b", re.I),
        re.compile(r"\bhow\s+many\s+devices?\b", re.I),
    ]

    _PREFERRED_TYPES = {
        "turn_on": {"light", "switch", "fan", "media"},
        "turn_off": {"light", "switch", "fan", "media"},
        "lock": {"lock"},
        "unlock": {"lock"},
        "toggle": {"light", "switch", "fan"},
        "set_brightness": {"light"},
        "set_temperature": {"thermostat"},
    }

    # All known device types for explicit-mention detection
    _DEVICE_TYPES = {"light", "lock", "fan", "switch", "sensor", "thermostat", "media"}

    def _fuzzy_match_device(
        self, text: str, device_list: List[str], preferred: Optional[set] = None
    ) -> tuple:
        """Find the best matching device from text. Returns (device_id, score)."""
        # Detect if user explicitly mentions a device type (e.g. "sensor", "light")
        explicit_type = None
        for dt in self._DEVICE_TYPES:
            if dt in text:
                explicit_type = dt
                break

        best_device: Optional[str] = None
        best_score = 0
        for did in device_list:
            tokens = did.replace(".", " ").replace("_", " ").lower().split()
            score = sum(1 for t in tokens if t in text)
            dev_type = did.split(".")[0] if "." in did else ""

            # Strong bonus if user explicitly said this device type
            if explicit_type and dev_type == explicit_type:
                score += 3
            # Weaker bonus for action-preferred types
            elif preferred and dev_type in preferred:
                score += 2

            if score > best_score:
                best_score = score
                best_device = did
        return best_device, best_score

    def _try_fast_match(
        self, message: str, device_list: List[str]
    ) -> Optional[Any]:
        """
        Attempt to match commands without LLM.
        Returns a tool call dict, a list of dicts (multi-step), or None.
        """
        msg_lower = message.lower().strip()

        # ── Scene / routine detection ────────────────────────────────
        scene_result = self._try_scene_match(msg_lower, device_list)
        if scene_result is not None:
            return scene_result

        # ── Check for compound commands ("X and Y") ──────────────────
        # Split on " and " or " then " to detect multi-step
        compound_splits = re.split(r"\b(?:and|then|also)\b", msg_lower, flags=re.I)
        if len(compound_splits) >= 2:
            parts = [p.strip() for p in compound_splits if p.strip()]
            results = []
            for part in parts:
                r = self._match_single(part, device_list)
                if r is not None:
                    results.append(r)
            if results:
                return results if len(results) > 1 else results[0]

        # ── Single command or query ──────────────────────────────────
        return self._match_single(msg_lower, device_list)

    def _try_scene_match(
        self, msg_lower: str, device_list: List[str]
    ) -> Optional[List[Dict[str, Any]]]:
        """Match common scene/routine keywords and return a batch of tool calls."""
        # Scene definitions: keyword → list of (action, device_type_filter)
        scenes = {
            "goodnight": [
                ("turn_off", {"light"}),
                ("lock", {"lock"}),
            ],
            "good night": [
                ("turn_off", {"light"}),
                ("lock", {"lock"}),
            ],
            "i'm going to bed": [
                ("turn_off", {"light"}),
                ("lock", {"lock"}),
            ],
            "going to sleep": [
                ("turn_off", {"light"}),
                ("lock", {"lock"}),
            ],
            "good morning": [
                ("turn_on", {"light"}),
                ("unlock", {"lock"}),
            ],
            "i'm home": [
                ("turn_on", {"light"}),
                ("unlock", {"lock"}),
            ],
            "leaving home": [
                ("turn_off", {"light"}),
                ("turn_off", {"fan"}),
                ("turn_off", {"media"}),
                ("lock", {"lock"}),
            ],
            "movie time": [
                ("turn_off", {"light"}),
                ("turn_on", {"media"}),
            ],
            "movie mode": [
                ("turn_off", {"light"}),
                ("turn_on", {"media"}),
            ],
        }

        matched_scene = None
        for keyword, actions in scenes.items():
            if keyword in msg_lower:
                matched_scene = (keyword, actions)
                break

        if matched_scene is None:
            return None

        keyword, scene_actions = matched_scene
        results = []
        for action, type_filter in scene_actions:
            # Find ALL matching devices of this type
            for did in device_list:
                dev_type = did.split(".")[0] if "." in did else ""
                if dev_type in type_filter:
                    results.append({
                        "tool": "control_device",
                        "arguments": {"device_id": did, "action": action},
                    })

        if results:
            logger.info(f"[FastMatch] SCENE '{keyword}' → {len(results)} actions")
            return results
        return None

    def _match_single(
        self, msg_lower: str, device_list: List[str]
    ) -> Optional[Dict[str, Any]]:
        """Match a single command or query from text."""

        # ── List devices detection ────────────────────────────────────
        # Skip if the message contains query-specific keywords (temperature, status, etc.)
        _query_keywords = {"temperature", "temp", "humidity", "status", "state", "locked",
                           "unlocked", "on", "off", "power", "energy", "brightness", "reading"}
        has_query_keyword = any(kw in msg_lower for kw in _query_keywords)
        for pattern in self._LIST_PATTERNS:
            if pattern.search(msg_lower) and not has_query_keyword:
                # Extract room name from the message
                room = None
                room_names = ["bedroom", "kitchen", "living_room", "living room", "bathroom",
                              "hallway", "garage", "backyard", "front_porch", "front porch",
                              "back_entry", "back entry", "front_entry", "front entry", "outdoor"]
                for rn in room_names:
                    if rn.replace("_", " ") in msg_lower or rn in msg_lower:
                        room = rn.replace(" ", "_")
                        break
                logger.info(f"[FastMatch] LIST '{msg_lower}' → list_devices room={room}")
                return {"tool": "list_devices", "arguments": {"room": room}}

        # ── Query detection ──────────────────────────────────────────
        for pattern in self._QUERY_PATTERNS:
            if pattern.search(msg_lower):
                # Determine query-preferred types based on what's being asked
                if any(w in msg_lower for w in ("temp", "thermostat", "hot", "cold", "warm", "cool", "heat")):
                    query_preferred = {"thermostat"}
                elif any(w in msg_lower for w in ("humidity", "moisture")):
                    query_preferred = {"sensor"}
                elif any(w in msg_lower for w in ("power", "energy", "watt")):
                    query_preferred = {"power", "sensor"}
                else:
                    query_preferred = {"sensor", "thermostat"}
                best_device, score = self._fuzzy_match_device(msg_lower, device_list, query_preferred)
                if best_device and score > 0:
                    logger.info(f"[FastMatch] QUERY '{msg_lower}' → query_device {best_device} (score={score})")
                    return {"tool": "query_device", "arguments": {"device_id": best_device}}
                return None  # No device matched, fall through to LLM

        # ── Action detection ─────────────────────────────────────────
        matched_action: Optional[str] = None
        needs_value = False
        for pattern, action, nv in self._ACTION_PATTERNS:
            if pattern.search(msg_lower):
                matched_action = action
                needs_value = nv
                break
        if matched_action is None:
            return None

        preferred = self._PREFERRED_TYPES.get(matched_action, set())
        best_device, best_score = self._fuzzy_match_device(msg_lower, device_list, preferred)

        if best_device is None or best_score == 0:
            return None

        value = None
        if needs_value:
            numbers = re.findall(r"\d+\.?\d*", msg_lower)
            value = numbers[0] if numbers else None

        logger.info(f"[FastMatch] '{msg_lower}' → {matched_action} {best_device} (score={best_score})")

        args: Dict[str, Any] = {
            "device_id": best_device,
            "action": matched_action,
        }
        if value is not None:
            args["value"] = value

        return {"tool": "control_device", "arguments": args}

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------
    @staticmethod
    def _friendly_name(device_id: str) -> str:
        """Convert device_id to human-friendly name.
        'lock.front_entry' → 'front entry lock'
        'light.living_room' → 'living room light'
        'thermostat.bedroom' → 'bedroom thermostat'
        """
        parts = device_id.split(".", 1)
        if len(parts) == 2:
            dev_type = parts[0]
            location = parts[1].replace("_", " ")
            return f"{location} {dev_type}"
        return device_id.replace(".", " ").replace("_", " ")

    @staticmethod
    def _format_state(state: Any) -> str:
        """Format a device state dict into a human-readable string."""
        if not isinstance(state, dict):
            return str(state)

        # Pick the most meaningful fields
        parts = []
        # On/off
        for key in ("on", "is_on", "status"):
            if key in state:
                val = state[key]
                if isinstance(val, bool):
                    parts.append("on" if val else "off")
                elif isinstance(val, str) and val.lower() in ("on", "off", "true", "false"):
                    parts.append(val.lower())
                else:
                    parts.append(f"{key}={val}")
        # Lock
        if "locked" in state:
            parts.append("locked" if state["locked"] else "unlocked")
        # Temperature
        for key in ("temperature", "temp", "current_temp"):
            if key in state:
                parts.append(f"{state[key]}°")
        # Brightness
        if "brightness" in state:
            parts.append(f"brightness {state['brightness']}%")
        # Battery
        if "battery" in state:
            parts.append(f"battery {state['battery']}%")
        # Power
        for key in ("power", "watts", "wattage"):
            if key in state:
                parts.append(f"{state[key]}W")
        # Humidity
        if "humidity" in state:
            parts.append(f"humidity {state['humidity']}%")
        # Online
        if "online" in state:
            parts.append("online" if state["online"] else "offline")
        # Name
        if "name" in state and not parts:
            parts.append(state["name"])

        if parts:
            return ", ".join(parts)

        # Fallback: if no known keys, show a simple value or first few fields
        if "value" in state:
            return str(state["value"])
        # Show first 3 keys
        items = [(k, v) for k, v in state.items() if k not in ("timestamp", "ts", "last_seen", "last_access")]
        return ", ".join(f"{k}={v}" for k, v in items[:4])

    async def _get_device_list(self) -> List[str]:
        """Extract device IDs from the context store."""
        if self.context_store is None:
            return []
        try:
            topics = await self.context_store.async_get_topics()
            devices = sorted(set(
                k.split("/")[1]
                for k in topics
                if k.startswith("devices/") and "/observed" in k
            ))
            if devices:
                return devices
            # Legacy format fallback
            return sorted(set(
                f"{k.split('/')[1]}.{k.split('/')[2]}"
                for k in topics
                if k.startswith("home/") and k.endswith("/state") and len(k.split("/")) >= 4
            ))
        except Exception as e:
            logger.warning(f"Failed to get device list: {e}")
            return []
