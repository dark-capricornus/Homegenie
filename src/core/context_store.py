"""
ContextStore - Thread-safe storage for device states

This module provides a ContextStore class that safely stores and manages
the latest device states in a dictionary with proper asyncio and thread safety.
"""

import asyncio
import threading
import json
from typing import Dict, Any, Optional
from datetime import datetime


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
    
    def update_state(self, topic: str, payload: Any) -> None:
        """
        Update the state for a given topic in a thread-safe manner.
        
        Args:
            topic (str): The device topic/identifier
            payload (Any): The state payload to store
        """
        with self._lock:
            self._states[topic] = payload
            self._last_updated[topic] = datetime.now()
    
    async def async_update_state(self, topic: str, payload: Any) -> None:
        """
        Async version of update_state for asyncio contexts.
        
        Args:
            topic (str): The device topic/identifier
            payload (Any): The state payload to store
        """
        async with self._async_lock:
            self._states[topic] = payload
            self._last_updated[topic] = datetime.now()
    
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