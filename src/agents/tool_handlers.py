"""
Tool Handlers — Binds tool definitions to actual execution logic.

Called once at startup to connect the ToolRegistry tools to the
ExecutorAgent, ContextStore, and other services.
"""
from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

from src.agents.tool_registry import ToolRegistry

logger = logging.getLogger(__name__)


def bind_handlers(
    registry: ToolRegistry,
    executor_agent: Any,
    context_store: Any,
    scheduler: Any = None,
    db_module: Any = None,
) -> None:
    """Bind live handler functions to each tool in the registry."""

    # ── control_device ─────────────────────────────────────────────────
    async def handle_control_device(
        device_id: str, action: str, value: Optional[str] = None
    ) -> Dict[str, Any]:
        task: Dict[str, Any] = {"device": device_id, "action": action}
        # Coerce value to appropriate type
        if value is not None and value != "":
            # Try numeric
            try:
                task["value"] = float(value) if "." in value else int(value)
            except (ValueError, TypeError):
                # Boolean
                if value.lower() in ("true", "on"):
                    task["value"] = True
                elif value.lower() in ("false", "off"):
                    task["value"] = False
                else:
                    task["value"] = value
        elif action == "turn_on":
            task["value"] = True
        elif action == "turn_off":
            task["value"] = False

        success = await executor_agent.execute(task)
        return {
            "success": success,
            "device_id": device_id,
            "action": action,
            "value": task.get("value"),
        }

    # ── query_device ───────────────────────────────────────────────────
    async def handle_query_device(device_id: str) -> Dict[str, Any]:
        # Try new-format topic first, then legacy
        state = None
        for topic in [f"devices/{device_id}/observed", f"home/{device_id.replace('.', '/')}/state"]:
            try:
                state = await context_store.async_get_state(topic)
                if state is not None:
                    break
            except Exception:
                continue

        if state is None:
            return {"error": f"Device '{device_id}' not found or has no state."}

        # Return a clean summary
        if isinstance(state, dict):
            return {"device_id": device_id, "state": state}
        return {"device_id": device_id, "state": {"value": state}}

    # ── list_devices ───────────────────────────────────────────────────
    async def handle_list_devices(
        room: Optional[str] = None, type: Optional[str] = None
    ) -> Dict[str, Any]:
        try:
            topics = await context_store.async_get_topics()
        except Exception:
            return {"devices": [], "error": "Could not read device list."}

        device_ids: List[str] = []
        for key in topics:
            if key.startswith("devices/") and key.endswith("/observed"):
                did = key.replace("devices/", "").replace("/observed", "")
                device_ids.append(did)

        # Legacy fallback
        if not device_ids:
            for key in topics:
                parts = key.split("/")
                if len(parts) >= 4 and parts[0] == "home" and parts[-1] == "state":
                    device_ids.append(f"{parts[1]}.{parts[2]}")

        # Filter
        if room:
            room_lower = room.lower().replace(" ", "_")
            device_ids = [d for d in device_ids if room_lower in d.lower()]
        if type:
            type_lower = type.lower()
            device_ids = [d for d in device_ids if d.split(".")[0].lower() == type_lower]

        return {"devices": sorted(set(device_ids)), "count": len(device_ids)}

    # ── batch_control ─────────────────────────────────────────────────
    async def handle_batch_control(
        action: str,
        room: Optional[str] = None,
        type: Optional[str] = None,
        exclude: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Apply an action to all devices matching the room/type filter."""
        # Build device list from context store
        try:
            topics = await context_store.async_get_topics()
        except Exception:
            return {"error": "Could not read device list."}

        device_ids: List[str] = []
        for key in topics:
            if key.startswith("devices/") and key.endswith("/observed"):
                device_ids.append(key.replace("devices/", "").replace("/observed", ""))
        # Legacy fallback
        if not device_ids:
            for key in topics:
                parts = key.split("/")
                if len(parts) >= 4 and parts[0] == "home" and parts[-1] == "state":
                    device_ids.append(f"{parts[1]}.{parts[2]}")

        # Filter by room
        if room:
            room_lower = room.lower().replace(" ", "_")
            device_ids = [d for d in device_ids if room_lower in d.lower()]
        # Filter by type
        if type:
            type_lower = type.lower()
            device_ids = [d for d in device_ids if d.split(".")[0].lower() == type_lower]
        # Exclude non-controllable sensors for on/off actions
        if action in ("turn_on", "turn_off", "toggle"):
            device_ids = [d for d in device_ids if not d.startswith("sensor.")]
        # Exclude specific devices
        if exclude:
            excluded = {e.strip().lower() for e in exclude.split(",")}
            device_ids = [d for d in device_ids if d.lower() not in excluded]

        if not device_ids:
            scope = []
            if room:
                scope.append(f"room '{room}'")
            if type:
                scope.append(f"type '{type}'")
            return {"error": f"No devices found for {' '.join(scope) or 'the given filter'}."}

        # Execute action on all matched devices
        results = []
        for did in device_ids:
            task: Dict[str, Any] = {"device": did, "action": action}
            if action == "turn_on":
                task["value"] = True
            elif action == "turn_off":
                task["value"] = False
            success = await executor_agent.execute(task)
            results.append({"device_id": did, "success": success})

        succeeded = sum(1 for r in results if r["success"])
        return {
            "success": succeeded > 0,
            "action": action,
            "total": len(results),
            "succeeded": succeeded,
            "devices": [r["device_id"] for r in results],
        }

    # ── create_schedule ────────────────────────────────────────────────
    async def handle_create_schedule(
        device_id: str,
        action: str,
        time: str,
        value: Optional[str] = None,
        recurring: Optional[bool] = False,
    ) -> Dict[str, Any]:
        if scheduler is None:
            return {"error": "Scheduler not available."}
        try:
            schedule_entry = {
                "device_id": device_id,
                "action": action,
                "time": time,
                "value": value,
                "recurring": recurring,
            }
            # Scheduler.add_entry if available
            if hasattr(scheduler, "add_entry"):
                await scheduler.add_entry(schedule_entry)
            return {"success": True, "schedule": schedule_entry}
        except Exception as e:
            return {"error": str(e)}

    # ── create_rule ────────────────────────────────────────────────────
    async def handle_create_rule(
        name: str,
        trigger_device: str,
        trigger_condition: str,
        action_device: str,
        action: str,
        value: Optional[str] = None,
    ) -> Dict[str, Any]:
        rule_content = {
            "conditions": [
                {"device": trigger_device, "condition": trigger_condition}
            ],
            "outcome": {
                "type": "command",
                "metadata": {
                    "device_id": action_device,
                    "command": action,
                    "value": value,
                },
            },
        }
        if db_module:
            try:
                await db_module.create_rule(
                    name=name,
                    content=rule_content,
                    priority=5,
                    created_by="agent",
                )
                return {"success": True, "rule_name": name}
            except Exception as e:
                return {"error": str(e)}
        return {"success": True, "rule_name": name, "note": "Rule stored in memory only (no DB)."}

    # ── respond_to_user (passthrough — handled by the agent loop) ─────
    async def handle_respond(message: str) -> Dict[str, Any]:
        return {"message": message}

    # ── ask_clarification (passthrough) ───────────────────────────────
    async def handle_clarification(
        question: str, options: Optional[list] = None
    ) -> Dict[str, Any]:
        return {"question": question, "options": options}

    # ── Bind all ──────────────────────────────────────────────────────
    bindings = {
        "control_device": handle_control_device,
        "query_device": handle_query_device,
        "list_devices": handle_list_devices,
        "batch_control": handle_batch_control,
        "create_schedule": handle_create_schedule,
        "create_rule": handle_create_rule,
        "respond_to_user": handle_respond,
        "ask_clarification": handle_clarification,
    }
    for name, handler in bindings.items():
        tool = registry.get(name)
        if tool:
            tool.handler = handler
            logger.info(f"Bound handler for tool '{name}'")
        else:
            logger.warning(f"Tool '{name}' not found in registry — skipping bind")
