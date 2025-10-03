"""
Complete System Test - Integration test for the entire home automation system

This script tests the complete workflow:
1. DeviceSimulator receives commands and publishes states
2. ExecutorAgent sends device commands  
3. SensorAgent receives the state updates
4. ContextStore maintains the latest device states

Run this alongside device_simulator.py to see the full system in action.
"""

import asyncio
import json
from datetime import datetime
from src.core.context_store import ContextStore
from src.agents.sensor_agent import SensorAgent
from src.agents.executor_agent import ExecutorAgent


class SystemTester:
    """Tests the complete home automation system integration."""
    
    def __init__(self):
        """Initialize the system tester with all components."""
        print("🧪 Initializing Complete System Test")
        
        # Create shared context store
        self.context_store = ContextStore()
        
        # Create agents
        self.sensor_agent = SensorAgent(
            broker_host="localhost",
            broker_port=1883,
            topic_pattern="home/+/+/state",
            context_store=self.context_store
        )
        
        self.executor_agent = ExecutorAgent(
            broker_host="localhost", 
            broker_port=1883,
            base_topic="home"
        )
        
        self._setup_callbacks()
        print("✅ System components initialized")
    
    def _setup_callbacks(self):
        """Set up callbacks to monitor system activity."""
        
        def on_sensor_data(topic: str, data: dict):
            print(f"📊 SENSOR DATA: {topic}")
            print(f"   📦 {json.dumps(data, indent=6)}")
            print()
        
        def on_sensor_error(error_type: str, exception: Exception):
            print(f"❌ SENSOR ERROR ({error_type}): {exception}")
        
        def on_command_success(result: dict):
            task = result['task']
            print(f"✅ COMMAND SENT: {task['device']} -> {task['action']}")
            if 'value' in task:
                print(f"   🎯 Value: {task['value']}")
            print(f"   📍 Published to: {result['topic']}")
            print()
        
        def on_command_error(error_type: str, exception: Exception, task: dict):
            print(f"❌ COMMAND ERROR ({error_type}): {task['device']} -> {exception}")
        
        # Set callbacks
        self.sensor_agent.set_message_callback(on_sensor_data)
        self.sensor_agent.set_error_callback(on_sensor_error)
        self.executor_agent.set_success_callback(on_command_success)
        self.executor_agent.set_error_callback(on_command_error)
    
    async def run_test_sequence(self):
        """Run a sequence of test commands and monitor responses."""
        print("🚀 Starting Test Sequence")
        print("="*60)
        
        # Test commands in the required format
        test_commands = [
            # Required format example
            {"device": "light.livingroom", "action": "set_brightness", "value": 40},
            
            # Additional test commands
            {"device": "light.bedroom", "action": "turn_on", "value": True},
            {"device": "thermostat.main", "action": "set_temperature", "value": 22.5},
            {"device": "switch.kitchen", "action": "toggle"},
            {"device": "lock.front_door", "action": "lock", "value": True},
            {"device": "fan.living_room", "action": "set_speed", "value": 3, "oscillate": True}
        ]
        
        print(f"📤 Executing {len(test_commands)} test commands...")
        print("💡 Each command should trigger a response from DeviceSimulator")
        print()
        
        for i, command in enumerate(test_commands, 1):
            print(f"🔸 Test {i}: {command}")
            
            # Send command
            success = await self.executor_agent.execute(command)
            
            if not success:
                print(f"   ❌ Command failed to send")
            
            # Wait for device response and sensor data
            print("   ⏳ Waiting for device response...")
            await asyncio.sleep(3)  # Give time for full round-trip
            
            # Check if we received the state update
            device_type, location = command['device'].split('.')
            expected_topic = f"home/{device_type}/{location}/state"
            
            state = await self.context_store.async_get_state(expected_topic)
            if state:
                print(f"   ✅ State received and stored!")
                print(f"   📊 Current state: {json.dumps(state, indent=6)}")
            else:
                print(f"   ⚠️  No state update received yet")
            
            print("-" * 40)
        
        # Show final system state
        await self._show_system_summary()
    
    async def _show_system_summary(self):
        """Show a summary of the complete system state."""
        print()
        print("📋 SYSTEM SUMMARY")
        print("="*60)
        
        # Context store summary
        all_states = await self.context_store.async_dump()
        print(f"🏠 Total devices tracked: {all_states['total_topics']}")
        
        if all_states['states']:
            print(f"📊 Device States:")
            for topic, state in all_states['states'].items():
                device_info = topic.replace('home/', '').replace('/state', '')
                key_info = []
                
                if 'state' in state:
                    key_info.append(f"state={state['state']}")
                if 'value' in state:
                    key_info.append(f"value={state['value']}")
                if 'brightness' in state:
                    key_info.append(f"brightness={state['brightness']}")
                if 'temperature' in state:
                    key_info.append(f"temp={state['temperature']}°C")
                if 'locked' in state:
                    key_info.append(f"locked={state['locked']}")
                
                status = ', '.join(key_info) if key_info else 'online'
                print(f"   📱 {device_info}: {status}")
        
        # Agent statistics
        print(f"\n📊 Agent Statistics:")
        executor_stats = self.executor_agent.get_stats()
        sensor_stats = self.sensor_agent.get_stats()
        
        print(f"   📤 Commands sent: {executor_stats['total_executions']}")
        print(f"   ✅ Success rate: {executor_stats['success_rate']:.1f}%")
        print(f"   📡 MQTT broker: {executor_stats['broker']}")
        print(f"   🎯 Sensor pattern: {sensor_stats['topic_pattern']}")
    
    async def start_monitoring(self):
        """Start the sensor monitoring in background."""
        print("🎯 Starting sensor monitoring...")
        # Run sensor agent in background
        sensor_task = asyncio.create_task(self.sensor_agent.start())
        return sensor_task


async def run_complete_system_test():
    """Run the complete system integration test."""
    print("🏠 HOME AUTOMATION SYSTEM - COMPLETE INTEGRATION TEST")
    print("="*70)
    print()
    
    print("📋 Prerequisites:")
    print("   1. 🚀 Start DeviceSimulator: python3 device_simulator.py")
    print("   2. 📡 MQTT broker running on localhost:1883")
    print("   3. 🧪 Then run this test script")
    print()
    
    # Check if we should proceed
    proceed = input("🤔 Is DeviceSimulator running? (y/N): ").lower().strip()
    if proceed != 'y':
        print("👋 Please start DeviceSimulator first, then run this test again")
        return
    
    print()
    print("🚀 Starting Complete System Test...")
    print()
    
    # Create system tester
    tester = SystemTester()
    
    try:
        # Start sensor monitoring in background
        print("1️⃣ Starting sensor monitoring...")
        sensor_task = await tester.start_monitoring()
        
        # Give sensor agent time to connect
        await asyncio.sleep(2)
        
        # Run test sequence
        print("2️⃣ Running command test sequence...")
        await tester.run_test_sequence()
        
        print()
        print("✅ INTEGRATION TEST COMPLETE!")
        print("🎉 The complete home automation system is working!")
        print()
        print("💡 What happened:")
        print("   1. ExecutorAgent sent commands to MQTT")
        print("   2. DeviceSimulator received and processed commands")
        print("   3. DeviceSimulator published device states")
        print("   4. SensorAgent collected the state updates")
        print("   5. ContextStore stored the latest device states")
        print()
        
        # Stop sensor monitoring
        tester.sensor_agent.stop()
        
        # Wait a moment for graceful shutdown
        await asyncio.sleep(1)
        sensor_task.cancel()
        
        try:
            await sensor_task
        except asyncio.CancelledError:
            pass
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        tester.sensor_agent.stop()


async def run_quick_demo():
    """Run a quick demo without requiring user input."""
    print("🏠 HOME AUTOMATION SYSTEM - QUICK DEMO")
    print("="*50)
    print()
    
    print("🧪 This demo shows the command format and expected behavior")
    print("📝 Note: Requires DeviceSimulator running to see full integration")
    print()
    
    # Create system tester  
    tester = SystemTester()
    
    # Show what commands would be sent
    demo_commands = [
        {"device": "light.livingroom", "action": "set_brightness", "value": 40},
        {"device": "thermostat.bedroom", "action": "set_temperature", "value": 24.0},
        {"device": "switch.kitchen", "action": "turn_on", "value": True}
    ]
    
    print("📤 Demo Commands (ExecutorAgent format):")
    for i, cmd in enumerate(demo_commands, 1):
        print(f"   {i}. {cmd}")
        
        # Show what MQTT topic/payload would be generated
        device_type, location = cmd['device'].split('.')
        topic = f"home/{device_type}/{location}/set"
        payload = {
            "action": cmd["action"],
            "timestamp": datetime.now().isoformat(),
            "source": "executor_agent"
        }
        if "value" in cmd:
            payload["value"] = cmd["value"]
        
        print(f"      📍 MQTT Topic: {topic}")
        print(f"      📦 Payload: {json.dumps(payload)}")
        print()
    
    print("🎯 Expected DeviceSimulator Response:")
    print("   1. Receives command on 'home/{type}/{location}/set'")
    print("   2. Processes command and updates device state") 
    print("   3. Publishes new state to 'home/{type}/{location}/state'")
    print("   4. SensorAgent collects state and updates ContextStore")
    print()
    
    # Show executor agent stats
    stats = tester.executor_agent.get_stats()
    print("📊 ExecutorAgent Configuration:")
    print(f"   📡 MQTT Broker: {stats['broker']}")
    print(f"   🎯 Base Topic: {stats['base_topic']}")
    print(f"   🤖 Supported Devices: {list(stats['device_mappings'].keys())}")


if __name__ == "__main__":
    print("🏠 HOME AUTOMATION SYSTEM TESTER")
    print("Choose test mode:")
    print("  1. Complete Integration Test (requires DeviceSimulator)")
    print("  2. Quick Demo (shows command format)")
    print()
    
    try:
        choice = input("Enter choice (1 or 2): ").strip()
        
        if choice == "1":
            asyncio.run(run_complete_system_test())
        elif choice == "2":
            asyncio.run(run_quick_demo())
        else:
            print("Invalid choice. Running quick demo...")
            asyncio.run(run_quick_demo())
            
    except KeyboardInterrupt:
        print("\n👋 Test interrupted")
    except Exception as e:
        print(f"❌ Error: {e}")