"""
ContextStore - Thread-safe storage for device states

This module provides a ContextStore class that safely stores and manages
the latest device states in a dictionary with proper asyncio and thread safety.
"""

import asyncio
import threading
import json
from typing import Dict, Any, Optional
from datetime import datetime, timezone, timedelta

try:
    from src.core import db_async as db
except ImportError:
    db = None


class ContextStore:
    """
    A thread-safe and asyncio-safe storage for device states.
    
    Stores the latest state for each device topic and provides safe
    concurrent access through locks.
    """
    
    def __init__(self):
        """Initialize the ContextStore with empty state and locks."""
        self._states: Dict[str, Any] = {}
        self._lock = threading.Lock()  # For thread safety
        self._async_lock = asyncio.Lock()  # For asyncio safety
        self._last_updated: Dict[str, datetime] = {}
        self._subscribers = []  # List of callbacks: (topic, payload) -> None

    def subscribe(self, callback):
        """Add a subscriber callback."""
        with self._lock:
            if callback not in self._subscribers:
                self._subscribers.append(callback)

    def unsubscribe(self, callback):
        """Remove a subscriber callback."""
        with self._lock:
            if callback in self._subscribers:
                self._subscribers.remove(callback)

    def _notify(self, topic: str, payload: Any):
        """Notify all subscribers of a change."""
        # Work on a copy to avoid deadlocks or modification during iteration
        with self._lock:
            subs = list(self._subscribers)
        
        for sub in subs:
            try:
                sub(topic, payload)
            except Exception as e:
                # We don't want one bad subscriber to break others
                pass

    def update_state(self, topic: str, payload: Any) -> None:
        """
        Update the state for a given topic in a thread-safe manner.
        
        Args:
            topic (str): The device topic/identifier
            payload (Any): The state payload to store
        """
        with self._lock:
            self._states[topic] = payload
            self._last_updated[topic] = datetime.now(timezone.utc)
        self._notify(topic, payload)
    
    async def async_update_state(self, topic: str, payload: Any) -> None:
        """
        Async version of update_state for asyncio contexts.
        
        Args:
            topic (str): The device topic/identifier
            payload (Any): The state payload to store
        """
        async with self._async_lock:
            self._states[topic] = payload
            self._last_updated[topic] = datetime.now(timezone.utc)
        self._notify(topic, payload)

    def update_probe_status(self, name: str, status: str, state: Optional[Dict[str, Any]] = None, error: Optional[str] = None, last_seen: Optional[datetime] = None) -> None:
        """
        Update the status of a probe.
        
        Args:
            name (str): Name of the probe
            status (str): "online" or "offline"
            state (Optional[Dict]): The state data retrieved (if successful)
            error (Optional[str]): Error message (if failed)
            last_seen (Optional[datetime]): Timestamp of last successful probe
        """
        payload: Dict[str, Any] = {
            "status": status,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        if state is not None:
            payload["state"] = state
        if error is not None:
            payload["error"] = error
        if last_seen is not None:
            payload["last_seen"] = last_seen.isoformat()
            
        self.update_state(f"probes/{name}", payload)

    async def async_update_probe_status(self, name: str, status: str, state: Optional[Dict[str, Any]] = None, error: Optional[str] = None, last_seen: Optional[datetime] = None) -> None:
        """Async version of update_probe_status."""
        payload: Dict[str, Any] = {
            "status": status,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        if state is not None:
            payload["state"] = state
        if error is not None:
            payload["error"] = error
        if last_seen is not None:
            payload["last_seen"] = last_seen.isoformat()
            
        await self.async_update_state(f"probes/{name}", payload)
    
    async def async_update_commanded_state(self, device_id: str, action: str, value: Any, timeout_seconds: float = 5.0) -> None:
        """
        ExecutorAgent writes commanded state ONLY (status = pending).
        ExecutorAgent NEVER confirms success - only SensorAgent does.
        
        Args:
            device_id: Device identifier (e.g., "light.living_room")
            action: Action being commanded (e.g., "turn_on", "set_brightness")
            value: Value for the action
            timeout_seconds: Timeout for command confirmation
        """
        key = f"devices/{device_id}/commanded"
        now = datetime.now(timezone.utc)
        payload = {
            "action": action,
            "value": value,
            "status": "pending",
            "timestamp": now.isoformat(),
            "timeout_at": (now + timedelta(seconds=timeout_seconds)).isoformat()
        }
        await self.async_update_state(key, payload)
    
    async def async_update_observed_state(self, device_id: str, state: Dict[str, Any]) -> None:
        """
        SensorAgent writes observed state ONLY and reconciles with commanded.
        SensorAgent is the SOLE authority for confirming success/failure.
        
        Args:
            device_id: Device identifier
            state: Observed state from device
        """
        obs_key = f"devices/{device_id}/observed"
        await self.async_update_state(obs_key, {
            **state,
            "last_seen": datetime.now(timezone.utc).isoformat()
        })
        
        # 1. NEW: Record energy history if power_consumption is present
        power = state.get("power_consumption")
        if power is not None and db:
            # We don't await to avoid slowing down the state update loop
            asyncio.create_task(db.record_energy_sample(device_id, float(power)))

        # 2. Reconcile: mark commanded as confirmed if match
        cmd_key = f"devices/{device_id}/commanded"
        commanded = await self.async_get_state(cmd_key)
        if commanded and commanded.get("status") == "pending":
            # Check if observed state matches commanded intent
            if self._states_match(commanded, state):
                commanded["status"] = "confirmed"
                commanded["confirmed_at"] = datetime.now(timezone.utc).isoformat()
                await self.async_update_state(cmd_key, commanded)
    
    def _states_match(self, commanded: Dict[str, Any], observed: Dict[str, Any]) -> bool:
        """
        Check if observed state matches commanded intent.
        
        Args:
            commanded: Commanded state with action/value
            observed: Observed state from device
            
        Returns:
            True if states match (command was confirmed)
        """
        action = commanded.get("action")
        cmd_value = commanded.get("value")
        
        # Simple matching logic - can be enhanced
        if action == "turn_on":
            return observed.get("state") == "on" or observed.get("power") == True
        elif action == "turn_off":
            return observed.get("state") == "off" or observed.get("power") == False
        elif action == "set_brightness":
            # Allow small tolerance for brightness
            obs_brightness = observed.get("brightness", observed.get("value"))
            if obs_brightness is not None and cmd_value is not None:
                return abs(float(obs_brightness) - float(cmd_value)) < 0.05  # 5% tolerance
        elif action == "set_temperature":
            obs_temp = observed.get("temperature", observed.get("target", observed.get("value")))
            if obs_temp is not None and cmd_value is not None:
                return abs(float(obs_temp) - float(cmd_value)) < 0.5  # 0.5 degree tolerance
        elif action == "lock":
            return observed.get("locked") == True or observed.get("state") == "locked"
        elif action == "unlock":
            return observed.get("locked") == False or observed.get("state") == "unlocked"
        
        # Default: no match
        return False
    
    async def async_check_timeouts(self) -> None:
        """
        Background task to mark timed-out commands as failed.
        Should be called periodically (e.g., every 1 second).
        """
        from src.core.time_utils import utc_now, parse_iso_timestamp
        
        now = utc_now()  # ✅ Always UTC-aware
        async with self._async_lock:
            for key, value in list(self._states.items()):
                if "/commanded" in key and isinstance(value, dict) and value.get("status") == "pending":
                    timeout_str = value.get("timeout_at")
                    if timeout_str:
                        try:
                            timeout_dt = parse_iso_timestamp(timeout_str)  # ✅ Always UTC-aware
                            if now > timeout_dt:  # ✅ Safe comparison
                                value["status"] = "failed"
                                value["error"] = "timeout"
                                value["failed_at"] = now.isoformat()
                                self._states[key] = value
                        except Exception:
                            pass  # Skip invalid timestamps
    
    def get_state(self, topic: str) -> Optional[Any]:
        """
        Get the current state for a given topic in a thread-safe manner.
        
        Args:
            topic (str): The device topic/identifier
            
        Returns:
            Optional[Any]: The current state or None if topic doesn't exist
        """
        with self._lock:
            return self._states.get(topic)
    
    async def async_get_state(self, topic: str) -> Optional[Any]:
        """
        Async version of get_state for asyncio contexts.
        
        Args:
            topic (str): The device topic/identifier
            
        Returns:
            Optional[Any]: The current state or None if topic doesn't exist
        """
        async with self._async_lock:
            return self._states.get(topic)
    
    def dump(self) -> Dict[str, Any]:
        """
        Dump all current states in a thread-safe manner.
        
        Returns:
            Dict[str, Any]: A copy of all current states
        """
        with self._lock:
            return {
                'states': dict(self._states),
                'last_updated': {
                    topic: timestamp.isoformat() 
                    for topic, timestamp in self._last_updated.items()
                },
                'total_topics': len(self._states)
            }
    
    async def async_dump(self) -> Dict[str, Any]:
        """
        Async version of dump for asyncio contexts.
        
        Returns:
            Dict[str, Any]: A copy of all current states with metadata
        """
        async with self._async_lock:
            return {
                'states': dict(self._states),
                'last_updated': {
                    topic: timestamp.isoformat() 
                    for topic, timestamp in self._last_updated.items()
                },
                'total_topics': len(self._states)
            }
    
    def dump_json(self, indent: int = 2) -> str:
        """
        Dump all states as a JSON string.
        
        Args:
            indent (int): JSON indentation level
            
        Returns:
            str: JSON representation of all states
        """
        data = self.dump()
        return json.dumps(data, indent=indent, default=str)
    
    async def async_dump_json(self, indent: int = 2) -> str:
        """
        Async version of dump_json for asyncio contexts.
        
        Args:
            indent (int): JSON indentation level
            
        Returns:
            str: JSON representation of all states
        """
        data = await self.async_dump()
        return json.dumps(data, indent=indent, default=str)
    
    def clear(self) -> None:
        """Clear all stored states in a thread-safe manner."""
        with self._lock:
            self._states.clear()
            self._last_updated.clear()
    
    async def async_clear(self) -> None:
        """Async version of clear for asyncio contexts."""
        async with self._async_lock:
            self._states.clear()
            self._last_updated.clear()
    
    def get_topics(self) -> list[str]:
        """
        Get a list of all topics currently stored.
        
        Returns:
            list[str]: List of all topic names
        """
        with self._lock:
            return list(self._states.keys())
    
    async def async_get_topics(self) -> list[str]:
        """
        Async version of get_topics for asyncio contexts.
        
        Returns:
            list[str]: List of all topic names
        """
        async with self._async_lock:
            return list(self._states.keys())
    
    def __len__(self) -> int:
        """Return the number of stored states."""
        with self._lock:
            return len(self._states)
    
    def __contains__(self, topic: str) -> bool:
        """Check if a topic exists in the store."""
        with self._lock:
            return topic in self._states
    
    def __repr__(self) -> str:
        """String representation of the ContextStore."""
        with self._lock:
            return f"ContextStore(topics={len(self._states)})"


# Example usage and testing
if __name__ == "__main__":
    import asyncio
    
    # Synchronous usage example
    def sync_example():
        print("=== Synchronous Usage Example ===")
        store = ContextStore()
        
        # Update some device states
        store.update_state("living_room/temperature", {"value": 22.5, "unit": "C"})
        store.update_state("kitchen/light", {"state": "on", "brightness": 80})
        store.update_state("bedroom/motion", {"detected": True, "timestamp": "2025-09-27T10:30:00"})
        
        # Get specific states
        temp = store.get_state("living_room/temperature")
        print(f"Living room temperature: {temp}")
        
        # Check if topic exists
        if "kitchen/light" in store:
            light_state = store.get_state("kitchen/light")
            print(f"Kitchen light: {light_state}")
        
        # Dump all states
        print(f"\nAll states ({len(store)} topics):")
        print(store.dump_json())
    
    # Asynchronous usage example
    async def async_example():
        print("\n=== Asynchronous Usage Example ===")
        store = ContextStore()
        
        # Update states asynchronously
        await store.async_update_state("garage/door", {"status": "closed", "locked": True})
        await store.async_update_state("security/alarm", {"armed": True, "zones": ["main", "perimeter"]})
        
        # Get states asynchronously
        door_state = await store.async_get_state("garage/door")
        print(f"Garage door: {door_state}")
        
        # Get all topics
        topics = await store.async_get_topics()
        print(f"All topics: {topics}")
        
        # Dump all states asynchronously
        print("\nAll async states:")
        json_dump = await store.async_dump_json()
        print(json_dump)
    
    # Run examples
    sync_example()
    asyncio.run(async_example())