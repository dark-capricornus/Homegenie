"""
Tool Registry — Structured tool/function definitions for the HomeGenie agent.

Each tool is a capability the LLM can invoke with typed parameters.
The registry provides:
  - JSON schemas for LLM function-calling / tool-use prompts
  - Execution dispatch (tool name → async handler)
  - Parameter validation
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any, Callable, Awaitable, Dict, List, Optional

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Data types
# ---------------------------------------------------------------------------
@dataclass
class ToolParam:
    name: str
    type: str  # "string" | "number" | "boolean" | "array"
    description: str
    required: bool = True
    enum: Optional[List[str]] = None


@dataclass
class Tool:
    name: str
    description: str
    parameters: List[ToolParam] = field(default_factory=list)
    handler: Optional[Callable[..., Awaitable[Dict[str, Any]]]] = None

    def schema(self) -> Dict[str, Any]:
        """Return an OpenAI-compatible function schema."""
        props: Dict[str, Any] = {}
        required: List[str] = []
        for p in self.parameters:
            entry: Dict[str, Any] = {"type": p.type, "description": p.description}
            if p.enum:
                entry["enum"] = p.enum
            props[p.name] = entry
            if p.required:
                required.append(p.name)
        return {
            "name": self.name,
            "description": self.description,
            "parameters": {
                "type": "object",
                "properties": props,
                "required": required,
            },
        }


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------
class ToolRegistry:
    """Central registry of all tools the agent can invoke."""

    def __init__(self) -> None:
        self._tools: Dict[str, Tool] = {}

    def register(self, tool: Tool) -> None:
        self._tools[tool.name] = tool

    def get(self, name: str) -> Optional[Tool]:
        return self._tools.get(name)

    @property
    def tools(self) -> List[Tool]:
        return list(self._tools.values())

    def schemas(self) -> List[Dict[str, Any]]:
        """All tool schemas, ready for an LLM system prompt."""
        return [t.schema() for t in self._tools.values()]

    async def execute(self, name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
        tool = self._tools.get(name)
        if not tool:
            return {"error": f"Unknown tool: {name}"}
        if not tool.handler:
            return {"error": f"Tool '{name}' has no handler"}
        try:
            return await tool.handler(**arguments)
        except TypeError as e:
            return {"error": f"Invalid arguments for '{name}': {e}"}
        except Exception as e:
            logger.error(f"Tool '{name}' execution failed: {e}", exc_info=True)
            return {"error": str(e)}


# ---------------------------------------------------------------------------
# Built-in tool definitions (handlers are bound at startup by the API server)
# ---------------------------------------------------------------------------

CONTROL_DEVICE = Tool(
    name="control_device",
    description="Control a smart home device (turn on/off, set brightness, temperature, color, speed, lock/unlock).",
    parameters=[
        ToolParam("device_id", "string", "Device identifier, e.g. 'light.living_room'"),
        ToolParam("action", "string", "Action to perform",
                  enum=["turn_on", "turn_off", "set_brightness", "set_temperature",
                        "set_color", "set_speed", "lock", "unlock", "toggle"]),
        ToolParam("value", "string", "Optional value (brightness 0-100, temperature, color name, etc.)",
                  required=False),
    ],
)

QUERY_DEVICE = Tool(
    name="query_device",
    description="Query the current state of a device or sensor (power, temperature, brightness, lock status, etc.).",
    parameters=[
        ToolParam("device_id", "string", "Device identifier to query"),
    ],
)

LIST_DEVICES = Tool(
    name="list_devices",
    description="List all available devices, optionally filtered by room or type.",
    parameters=[
        ToolParam("room", "string", "Filter by room name", required=False),
        ToolParam("type", "string", "Filter by device type (light, thermostat, lock, sensor, switch)",
                  required=False),
    ],
)

CREATE_SCHEDULE = Tool(
    name="create_schedule",
    description="Schedule a device action for a specific time or recurring pattern.",
    parameters=[
        ToolParam("device_id", "string", "Device to schedule"),
        ToolParam("action", "string", "Action to schedule"),
        ToolParam("time", "string", "When to execute (ISO time, e.g. '22:00', or cron-like '0 22 * * *')"),
        ToolParam("value", "string", "Optional value for the action", required=False),
        ToolParam("recurring", "boolean", "Whether this repeats daily", required=False),
    ],
)

CREATE_RULE = Tool(
    name="create_rule",
    description="Create an automation rule (e.g. 'when motion detected in hallway, turn on hallway light').",
    parameters=[
        ToolParam("name", "string", "Human-readable rule name"),
        ToolParam("trigger_device", "string", "Device that triggers the rule"),
        ToolParam("trigger_condition", "string", "Condition (e.g. 'motion_detected', 'temperature > 25')"),
        ToolParam("action_device", "string", "Device to act on"),
        ToolParam("action", "string", "Action to perform"),
        ToolParam("value", "string", "Optional value", required=False),
    ],
)

BATCH_CONTROL = Tool(
    name="batch_control",
    description=(
        "Control multiple devices at once. Use this when the user says "
        "'all devices in <room>', 'all lights', 'everything in kitchen', etc. "
        "Filters by room AND/OR device type, then applies the action to every match."
    ),
    parameters=[
        ToolParam("action", "string", "Action to perform on all matching devices",
                  enum=["turn_on", "turn_off", "lock", "unlock", "toggle"]),
        ToolParam("room", "string", "Room to filter by (e.g. 'kitchen', 'bedroom'). Omit for all rooms.",
                  required=False),
        ToolParam("type", "string", "Device type to filter (e.g. 'light', 'fan'). Omit for all types.",
                  required=False),
        ToolParam("exclude", "string", "Comma-separated device IDs to skip (e.g. 'thermostat.kitchen')",
                  required=False),
    ],
)

RESPOND_TO_USER = Tool(
    name="respond_to_user",
    description="Send a text response to the user. Use this for questions, confirmations, or status updates.",
    parameters=[
        ToolParam("message", "string", "The message to display to the user"),
    ],
)

ASK_CLARIFICATION = Tool(
    name="ask_clarification",
    description="Ask the user to clarify an ambiguous request (e.g. which room, which device).",
    parameters=[
        ToolParam("question", "string", "The clarifying question to ask"),
        ToolParam("options", "array", "Suggested options for the user to pick from", required=False),
    ],
)


def build_default_registry() -> ToolRegistry:
    """Create a registry with all built-in tools (handlers not yet bound)."""
    registry = ToolRegistry()
    for tool in [CONTROL_DEVICE, QUERY_DEVICE, LIST_DEVICES, BATCH_CONTROL,
                 CREATE_SCHEDULE, CREATE_RULE, RESPOND_TO_USER, ASK_CLARIFICATION]:
        registry.register(tool)
    return registry
