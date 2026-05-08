import logging
import asyncio
from typing import Dict, Any, List, Optional
from datetime import datetime

logger = logging.getLogger(__name__)

class ShadowSecurityAgent:
    """
    Shadow Security Agent for AI Policy-Ghosting.
    
    Evaluates proposed device commands against safety policies and maintains
     a 'Ghost State' for predictive visualization.
    """
    
    def __init__(self, context_store):
        self.context_store = context_store
        # Safety Policies
        self.policies = {
            "thermostat": {
                "max_temp": 32.0,
                "min_temp": 16.0
            },
            "light": {
                "max_brightness": 100,
                "min_brightness": 0
            },
            "lock": {
                "restricted_locations": ["front_door", "garage_door"],
                "night_lock_only": False # If True, would restrict unlocking at night
            }
        }

    async def evaluate_task(self, task: Dict[str, Any]) -> Dict[str, Any]:
        print(f"DEBUG ShadowAgent: evaluate_task called for {task.get('device')}")
        device_id = task.get("device", "")
        action = task.get("action", "")
        value = task.get("value")
        
        device_type = device_id.split('.')[0] if '.' in device_id else "unknown"
        
        report = {
            "device": device_id,
            "action": action,
            "safe": True,
            "violations": [],
            "safety_score": 1.0,
            "timestamp": datetime.now().isoformat()
        }

        # Policy Checks
        if device_type == "thermostat" and action == "set_temperature":
            max_t = self.policies["thermostat"]["max_temp"]
            min_t = self.policies["thermostat"]["min_temp"]
            if float(value) > max_t:
                report["safe"] = False
                report["violations"].append(f"Temperature {value} exceeds safety limit of {max_t}")
                report["safety_score"] = 0.2
            elif float(value) < min_t:
                report["safe"] = False
                report["violations"].append(f"Temperature {value} is below safety limit of {min_t}")
                report["safety_score"] = 0.5

        if device_type == "lock" and action == "unlock":
            # Example of a contextual policy
            current_hour = datetime.now().hour
            if current_hour >= 22 or current_hour <= 6:
                report["safe"] = False
                report["violations"].append("Unlocking restricted during night hours (Shadow Policy)")
                report["safety_score"] = 0.3

        # Update Ghost State
        ghost_payload = {
            "predicted_state": value if value is not None else action,
            "safety_report": report,
            "is_shadow_prediction": True
        }
        print(f"DEBUG ShadowAgent: Updating ghost state for {device_id}")
        await self.context_store.async_update_ghost_state(device_id, ghost_payload)
        
        if not report["safe"]:
            logger.warning(f"ALERT: SHADOW SECURITY ALERT: {device_id} -> {report['violations']}")
        
        return report
