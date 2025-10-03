"""
Test ExecutorAgent - Demo version that shows MQTT topics and payloads without requiring broker
"""

import asyncio
import json
from datetime import datetime
from src.agents.executor_agent import ExecutorAgent


class MockExecutorAgent(ExecutorAgent):
    """Mock version of ExecutorAgent that simulates MQTT publishing for testing."""
    
    async def execute(self, task: dict) -> bool:
        """Mock execute that shows what would be published to MQTT."""
        try:
            # Validate task format
            if not isinstance(task, dict):
                raise ValueError("Task must be a dictionary")
            
            if "device" not in task:
                raise ValueError("Task must contain 'device' field")
            
            if "action" not in task:
                raise ValueError("Task must contain 'action' field")
            
            # Parse device identifier
            device_type, location = self._parse_device_identifier(task["device"])
            
            # Build topic and payload
            topic = self._build_topic(device_type, location)
            payload = self._build_payload(task)
            
            print(f"🚀 MQTT Publish Simulation:")
            print(f"   📍 Topic: {topic}")
            print(f"   📦 Payload: {json.dumps(payload, indent=6)}")
            
            # Record successful execution
            execution_record = {
                "timestamp": datetime.now().isoformat(),
                "task": task,
                "topic": topic,
                "payload": payload,
                "status": "success"
            }
            
            self._execution_history.append(execution_record)
            
            # Keep history limited
            if len(self._execution_history) > 100:
                self._execution_history.pop(0)
            
            # Call success callback
            if self._success_callback:
                if asyncio.iscoroutinefunction(self._success_callback):
                    await self._success_callback(execution_record)
                else:
                    self._success_callback(execution_record)
            
            return True
            
        except Exception as e:
            print(f"❌ Task validation failed: {e}")
            
            # Record failed execution
            execution_record = {
                "timestamp": datetime.now().isoformat(),
                "task": task,
                "error": str(e),
                "status": "failed"
            }
            
            self._execution_history.append(execution_record)
            
            if self._error_callback:
                self._error_callback("execution_error", e, task)
            
            return False


async def demo_executor_agent():
    """Demonstrate ExecutorAgent functionality with mock MQTT."""
    print("=== ExecutorAgent Demo (Mock MQTT) ===\n")
    
    # Create mock executor
    executor = MockExecutorAgent(
        broker_host="localhost",
        broker_port=1883,
        base_topic="home"
    )
    
    # Set up callbacks
    def success_callback(result: dict):
        print(f"   ✅ Command executed: {result['task']['device']} -> {result['task']['action']}")
    
    def error_callback(error_type: str, exception: Exception, task: dict):
        print(f"   ❌ Failed: {task['device']} -> {exception}")
    
    executor.set_success_callback(success_callback)
    executor.set_error_callback(error_callback)
    
    # Demo tasks matching the required format
    tasks = [
        # Required format example
        {"device": "light.livingroom", "action": "set_brightness", "value": 40},
        
        # Additional examples
        {"device": "light.bedroom", "action": "turn_on", "value": True},
        {"device": "light.kitchen", "action": "set_color", "value": "#FF6B6B", "transition": 2},
        {"device": "thermostat.main", "action": "set_temperature", "value": 22.5, "mode": "heat"},
        {"device": "switch.porch", "action": "toggle"},
        {"device": "lock.front_door", "action": "lock", "value": True, "auto_unlock": 300},
        {"device": "fan.bedroom", "action": "set_speed", "value": 3, "oscillate": True}
    ]
    
    print(f"Executing {len(tasks)} demo tasks...\n")
    
    for i, task in enumerate(tasks, 1):
        print(f"📤 Task {i}: {task}")
        success = await executor.execute(task)
        print()  # Add spacing
        
        if i == 1:  # Show detailed explanation for first task
            print("   💡 This demonstrates the required task format:")
            print("      - device: 'light.livingroom' (type.location)")
            print("      - action: 'set_brightness' (command)")
            print("      - value: 40 (parameter)")
            print("      - Published to: 'home/light/livingroom/set'")
            print()
    
    # Show statistics
    print("📊 ExecutorAgent Statistics:")
    stats = executor.get_stats()
    print(json.dumps(stats, indent=2))
    
    print(f"\n📋 Execution History Summary:")
    history = executor.get_execution_history()
    for record in history[-3:]:  # Last 3 records
        status_icon = "✅" if record['status'] == 'success' else "❌"
        print(f"  {status_icon} {record['task']['device']} -> {record['task']['action']}")


async def demo_topic_mapping():
    """Demonstrate how device identifiers map to MQTT topics."""
    print("\n" + "="*60)
    print("=== Topic Mapping Examples ===\n")
    
    executor = MockExecutorAgent()
    
    device_examples = [
        "light.livingroom",
        "switch.kitchen", 
        "thermostat.bedroom",
        "lock.front_door",
        "fan.ceiling",
        "sensor.motion_hall",
        "camera.driveway"
    ]
    
    print("Device Identifier -> MQTT Topic Mapping:")
    print("-" * 50)
    
    for device in device_examples:
        device_type, location = executor._parse_device_identifier(device)
        topic = executor._build_topic(device_type, location)
        print(f"  {device:<20} -> {topic}")
    
    print(f"\nBase topic: '{executor.base_topic}'")
    print("Topic format: {base_topic}/{device_type}/{location}/set")


if __name__ == "__main__":
    # Run demos
    asyncio.run(demo_executor_agent())
    asyncio.run(demo_topic_mapping())