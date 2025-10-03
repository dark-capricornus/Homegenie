"""
Home Automation System Integration Example

This example demonstrates how ContextStore, SensorAgent, and ExecutorAgent
work together to create a complete home automation system.
"""

import asyncio
import json
from datetime import datetime
from src.core.context_store import ContextStore
from src.agents.sensor_agent import SensorAgent
from src.agents.executor_agent import ExecutorAgent


class HomeAutomationSystem:
    """
    Integrated home automation system combining sensor monitoring and device control.
    """
    
    def __init__(self, broker_host: str = "localhost", broker_port: int = 1883):
        """Initialize the home automation system."""
        self.broker_host = broker_host
        self.broker_port = broker_port
        
        # Shared context store for all agents
        self.context_store = ContextStore()
        
        # Initialize agents
        self.sensor_agent = SensorAgent(
            broker_host=broker_host,
            broker_port=broker_port,
            topic_pattern="home/+/+/state",
            context_store=self.context_store
        )
        
        self.executor_agent = ExecutorAgent(
            broker_host=broker_host,
            broker_port=broker_port,
            base_topic="home"
        )
        
        self._setup_callbacks()
        print(f"🏠 HomeAutomationSystem initialized")
        print(f"   📡 MQTT Broker: {broker_host}:{broker_port}")
        print(f"   📊 Shared ContextStore ready")
    
    def _setup_callbacks(self):
        """Set up callbacks for sensor and executor agents."""
        
        # Sensor callbacks
        def on_sensor_data(topic: str, data: dict):
            print(f"📊 Sensor Update: {topic}")
            print(f"   📦 Data: {json.dumps(data, indent=6)}")
        
        def on_sensor_error(error_type: str, exception: Exception):
            print(f"❌ Sensor Error ({error_type}): {exception}")
        
        # Executor callbacks  
        def on_command_success(result: dict):
            task = result['task']
            print(f"✅ Command Executed: {task['device']} -> {task['action']}")
            if 'value' in task:
                print(f"   🎯 Value: {task['value']}")
        
        def on_command_error(error_type: str, exception: Exception, task: dict):
            print(f"❌ Command Failed ({error_type}): {task['device']} -> {exception}")
        
        # Set callbacks
        self.sensor_agent.set_message_callback(on_sensor_data)
        self.sensor_agent.set_error_callback(on_sensor_error)
        self.executor_agent.set_success_callback(on_command_success)
        self.executor_agent.set_error_callback(on_command_error)
    
    async def execute_command(self, task: dict) -> bool:
        """Execute a device command."""
        return await self.executor_agent.execute(task)
    
    async def get_device_state(self, topic: str) -> dict:
        """Get current state of a device."""
        result = await self.context_store.async_get_state(topic)
        return result or {}
    
    async def get_all_states(self) -> dict:
        """Get all current device states."""
        result = await self.context_store.async_dump()
        return result or {}
    
    async def start_monitoring(self):
        """Start sensor monitoring (requires MQTT broker)."""
        print("🚀 Starting sensor monitoring...")
        await self.sensor_agent.start()
    
    def stop_monitoring(self):
        """Stop sensor monitoring."""
        print("🛑 Stopping sensor monitoring...")
        self.sensor_agent.stop()
    
    def get_system_stats(self) -> dict:
        """Get system statistics."""
        return {
            "sensor_agent": self.sensor_agent.get_stats(),
            "executor_agent": self.executor_agent.get_stats(),
            "context_store": {
                "total_devices": len(self.context_store),
                "stored_topics": list(self.context_store.get_topics())
            }
        }


async def demo_home_automation():
    """Demonstrate the integrated home automation system."""
    print("=== Home Automation System Demo ===\n")
    
    # Create the integrated system
    home_system = HomeAutomationSystem()
    
    print("\n1️⃣ Simulating Sensor Data Collection")
    print("-" * 40)
    
    # Simulate some sensor data being received
    sensor_data = [
        ("home/living_room/temperature/state", {
            "value": 22.5, 
            "unit": "C", 
            "humidity": 45,
            "timestamp": datetime.now().isoformat()
        }),
        ("home/kitchen/light/state", {
            "state": "on", 
            "brightness": 80, 
            "color": "warm_white",
            "power_consumption": 12.5
        }),
        ("home/bedroom/motion/state", {
            "detected": True, 
            "confidence": 0.95,
            "last_motion": datetime.now().isoformat()
        }),
        ("home/front_door/lock/state", {
            "locked": True,
            "battery": 85,
            "last_access": "2025-09-27T08:30:00"
        })
    ]
    
    # Add sensor data to context store
    for topic, data in sensor_data:
        await home_system.context_store.async_update_state(topic, data)
        print(f"📊 Collected: {topic}")
    
    print(f"\n📋 Current System State:")
    all_states = await home_system.get_all_states()
    print(f"   🏠 Total devices: {all_states['total_topics']}")
    for topic in all_states['states']:
        device_type = topic.split('/')[1]
        location = topic.split('/')[2]
        print(f"   📱 {device_type.title()} in {location}")
    
    print(f"\n2️⃣ Executing Device Commands")
    print("-" * 40)
    
    # Example commands using the required format
    commands = [
        {"device": "light.livingroom", "action": "set_brightness", "value": 40},
        {"device": "thermostat.bedroom", "action": "set_temperature", "value": 24.0},
        {"device": "lock.front_door", "action": "unlock", "value": False},
        {"device": "switch.porch", "action": "turn_on", "value": True}
    ]
    
    print("Executing commands using ExecutorAgent...")
    for cmd in commands:
        print(f"\n📤 Command: {cmd}")
        
        # For demo, we'll show what would be published
        device_type, location = cmd['device'].split('.')
        topic = f"home/{device_type}/{location}/set"
        payload = {
            "action": cmd["action"],
            "timestamp": datetime.now().isoformat(),
            "source": "executor_agent"
        }
        if "value" in cmd:
            payload["value"] = cmd["value"]
        
        print(f"   📍 MQTT Topic: {topic}")
        print(f"   📦 Payload: {json.dumps(payload, indent=6)}")
    
    print(f"\n3️⃣ Querying Device States")
    print("-" * 40)
    
    # Query specific device states
    temp_state = await home_system.get_device_state("home/living_room/temperature/state")
    if temp_state:
        print(f"🌡️  Living Room Temperature: {temp_state['value']}°{temp_state['unit']}")
        print(f"   💧 Humidity: {temp_state['humidity']}%")
    
    lock_state = await home_system.get_device_state("home/front_door/lock/state")
    if lock_state:
        status = "🔒 Locked" if lock_state['locked'] else "🔓 Unlocked"
        print(f"🚪 Front Door: {status}")
        print(f"   🔋 Battery: {lock_state['battery']}%")
    
    print(f"\n4️⃣ System Statistics")
    print("-" * 40)
    
    stats = home_system.get_system_stats()
    print(f"📊 System Stats:")
    print(f"   🏠 Total devices tracked: {stats['context_store']['total_devices']}")
    print(f"   📡 MQTT broker: {stats['sensor_agent']['broker']}")
    print(f"   📤 Commands executed: {stats['executor_agent']['total_executions']}")
    print(f"   ✅ Success rate: {stats['executor_agent']['success_rate']:.1f}%")


async def demo_automation_rules():
    """Demonstrate simple automation rules based on sensor data."""
    print(f"\n" + "="*60)
    print("=== Smart Automation Rules Demo ===\n")
    
    home_system = HomeAutomationSystem()
    
    # Simulate some conditions
    await home_system.context_store.async_update_state(
        "home/living_room/motion/state", 
        {"detected": True, "timestamp": datetime.now().isoformat()}
    )
    
    await home_system.context_store.async_update_state(
        "home/living_room/light/state",
        {"state": "off", "brightness": 0}
    )
    
    await home_system.context_store.async_update_state(
        "home/outdoor/light_sensor/state",
        {"lux": 15, "is_dark": True}  # It's dark outside
    )
    
    print("🤖 Smart Automation Rule: Motion-Activated Lighting")
    print("-" * 50)
    
    # Check conditions
    motion_state = await home_system.get_device_state("home/living_room/motion/state")
    light_state = await home_system.get_device_state("home/living_room/light/state")
    ambient_light = await home_system.get_device_state("home/outdoor/light_sensor/state")
    
    print(f"📊 Current Conditions:")
    print(f"   🚶 Motion detected: {motion_state['detected'] if motion_state else False}")
    print(f"   💡 Light status: {light_state['state'] if light_state else 'unknown'}")
    print(f"   🌙 Is dark outside: {ambient_light['is_dark'] if ambient_light else False}")
    
    # Apply automation rule
    if (motion_state and motion_state['detected'] and 
        light_state and light_state['state'] == 'off' and
        ambient_light and ambient_light['is_dark']):
        
        print(f"\n🎯 Automation Rule Triggered!")
        print(f"   ➡️  Motion detected in dark room with lights off")
        print(f"   🔧 Action: Turn on lights")
        
        # Execute automation command
        automation_command = {
            "device": "light.living_room",
            "action": "turn_on",
            "value": True,
            "brightness": 70,
            "reason": "motion_activated"
        }
        
        print(f"\n📤 Executing automation command:")
        print(f"   {automation_command}")
        
        # Show what would be published
        print(f"   📍 MQTT Topic: home/light/living_room/set")
        payload = {
            "action": "turn_on",
            "value": True,
            "brightness": 70,
            "reason": "motion_activated",
            "timestamp": datetime.now().isoformat(),
            "source": "executor_agent"
        }
        print(f"   📦 Payload: {json.dumps(payload, indent=6)}")
        
    else:
        print(f"\n💤 No automation rule triggered")


if __name__ == "__main__":
    # Run integrated demos
    asyncio.run(demo_home_automation())
    asyncio.run(demo_automation_rules())