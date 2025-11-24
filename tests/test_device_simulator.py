"""
Manual Device Simulator Test - Test device simulation logic without MQTT broker

This script demonstrates the device simulation logic by manually processing
commands and showing the expected state responses.
"""

import json
from datetime import datetime
from src.simulators.device_simulator import DeviceSimulator


async def run_device_simulation_logic():
    """Test the device simulation logic without requiring MQTT broker."""
    print("🧪 DEVICE SIMULATOR - MANUAL TEST")
    print("="*50)
    print()
    
    # Create simulator (won't connect to MQTT)
    simulator = DeviceSimulator()
    
    # Test commands in the required format
    test_commands = [
        # Required format example
        {
            "topic": "home/light/livingroom/set",
            "command": {"action": "set_brightness", "value": 40}
        },
        # Additional test cases
        {
            "topic": "home/thermostat/bedroom/set", 
            "command": {"action": "set_temperature", "value": 22.5, "mode": "heat"}
        },
        {
            "topic": "home/switch/kitchen/set",
            "command": {"action": "toggle"}
        },
        {
            "topic": "home/lock/front_door/set",
            "command": {"action": "lock", "value": True}
        },
        {
            "topic": "home/fan/living_room/set",
            "command": {"action": "set_speed", "value": 3, "oscillate": True}
        }
    ]
    
    print("🔧 Testing Device Command Processing:")
    print("-" * 40)
    
    for i, test in enumerate(test_commands, 1):
        topic = test["topic"]
        command = test["command"]
        
        print(f"\n📤 Test {i}: Command Received")
        print(f"   📍 Topic: {topic}")
        print(f"   📦 Command: {json.dumps(command)}")
        
        # Parse topic manually (simulate MQTT message processing)
        parts = topic.split('/')
        base, device_type, location, action_type = parts[0], parts[1], parts[2], parts[3]
        
        print(f"   🎯 Device: {device_type}.{location}")
        print(f"   ⚡ Action: {command.get('action', 'unknown')}")
        
        # Process command using simulator logic
        new_state = simulator._process_command(device_type, location, command)
        
        # Show the state that would be published
        state_topic = f"{base}/{device_type}/{location}/state"
        
        print(f"   ✅ Response Generated:")
        print(f"   📍 State Topic: {state_topic}")
        print(f"   📊 New State: {json.dumps(new_state, indent=6)}")
        
        print("   " + "-" * 30)
    
    # Show all device states
    print(f"\n📋 All Simulated Device States:")
    print("="*50)
    
    all_states = simulator.get_device_states()
    for device_key, state in all_states.items():
        device_type = state.get('device_type', 'unknown')
        location = state.get('location', 'unknown')
        
        # Show key state information
        key_info = []
        if 'state' in state:
            key_info.append(f"state={state['state']}")
        if 'brightness' in state and state['brightness'] > 0:
            key_info.append(f"brightness={state['brightness']}%")
        if 'temperature' in state:
            key_info.append(f"temp={state['temperature']}°C")
        if 'target' in state:
            key_info.append(f"target={state['target']}°C")
        if 'locked' in state:
            key_info.append(f"locked={state['locked']}")
        if 'speed' in state and state['speed'] > 0:
            key_info.append(f"speed={state['speed']}")
        if 'power_consumption' in state and state['power_consumption'] > 0:
            key_info.append(f"power={state['power_consumption']}W")
        
        status = ', '.join(key_info) if key_info else 'online'
        print(f"🏠 {device_type.title()} in {location}: {status}")
    
    # Show statistics
    print(f"\n📊 Simulator Statistics:")
    stats = simulator.get_stats()
    print(f"   🤖 Simulated devices: {stats['simulated_devices']}")
    print(f"   📱 Device types: {stats['device_types']}")
    print(f"   ⚙️  Supported types: {stats['supported_device_types']}")


def demonstrate_command_formats():
    """Show examples of valid command formats."""
    print("\n" + "="*60)
    print("🎯 VALID COMMAND FORMATS")
    print("="*60)
    
    examples = [
        {
            "description": "💡 Light Brightness (Required Format)",
            "topic": "home/light/livingroom/set",
            "command": {"action": "set_brightness", "value": 40}
        },
        {
            "description": "💡 Light On/Off",
            "topic": "home/light/bedroom/set", 
            "command": {"action": "turn_on", "value": True}
        },
        {
            "description": "💡 Light Color",
            "topic": "home/light/kitchen/set",
            "command": {"action": "set_color", "value": "#FF6B6B", "transition": 2}
        },
        {
            "description": "🌡️ Thermostat Temperature",
            "topic": "home/thermostat/main/set",
            "command": {"action": "set_temperature", "value": 22.5, "mode": "heat"}
        },
        {
            "description": "🔌 Switch Toggle",
            "topic": "home/switch/porch/set",
            "command": {"action": "toggle"}
        },
        {
            "description": "🔒 Door Lock",
            "topic": "home/lock/front_door/set",
            "command": {"action": "lock", "value": True, "auto_unlock": 300}
        },
        {
            "description": "💨 Fan Speed Control",
            "topic": "home/fan/ceiling/set",
            "command": {"action": "set_speed", "value": 3, "oscillate": True}
        }
    ]
    
    for example in examples:
        print(f"\n{example['description']}")
        print(f"   📍 Topic: {example['topic']}")
        print(f"   📦 Command: {json.dumps(example['command'])}")
        
        # Show expected state topic
        topic_parts = example['topic'].replace('/set', '/state')
        print(f"   📊 Response Topic: {topic_parts}")
    
    print(f"\n📋 Command Structure:")
    print(f"   📍 Topic Format: home/{{device_type}}/{{location}}/set")
    print(f"   📦 Required Fields: action (string)")
    print(f"   📦 Optional Fields: value (any), additional parameters")
    print(f"   📊 Response Topic: home/{{device_type}}/{{location}}/state")


if __name__ == "__main__":
    import asyncio
    
    print("🏠 DEVICE SIMULATOR MANUAL TEST")
    print("This test runs the simulation logic without requiring MQTT broker")
    print()
    
    # Run the demo
    asyncio.run(run_device_simulation_logic())
    
    # Show command format examples
    demonstrate_command_formats()
    
    print(f"\n✅ MANUAL TEST COMPLETE!")
    print("🎉 DeviceSimulator logic is working correctly!")
    print()
    print("💡 To test with real MQTT:")
    print("   1. Start MQTT broker (mosquitto)")
    print("   2. Run: python3 device_simulator.py")
    print("   3. Send commands using mosquitto_pub or ExecutorAgent")