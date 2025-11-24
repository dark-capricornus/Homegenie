"""
Manual Device Simulator Script - moved out of tests so pytest won't collect it.
This can be run directly: python scripts/device_simulator_manual.py
"""

import json
from datetime import datetime
from src.simulators.device_simulator import DeviceSimulator


async def run_device_simulation_demo():
    """Run the simulation demo (async)"""
    print("🧪 DEVICE SIMULATOR - MANUAL TEST")
    print("="*50)
    print()

    # Create simulator (won't connect to MQTT)
    simulator = DeviceSimulator()

    # Test commands in the required format
    test_commands = [
        {
            "topic": "home/light/livingroom/set",
            "command": {"action": "set_brightness", "value": 40}
        },
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

        parts = topic.split('/')
        base, device_type, location, action_type = parts[0], parts[1], parts[2], parts[3]

        print(f"   🎯 Device: {device_type}.{location}")
        print(f"   ⚡ Action: {command.get('action', 'unknown')}")

        new_state = simulator._process_command(device_type, location, command)

        state_topic = f"{base}/{device_type}/{location}/state"

        print(f"   ✅ Response Generated:")
        print(f"   📍 State Topic: {state_topic}")
        print(f"   📊 New State: {json.dumps(new_state, indent=6)}")

        print("   " + "-" * 30)

    print(f"\n📋 All Simulated Device States:")
    print("="*50)

    all_states = simulator.get_device_states()
    for device_key, state in all_states.items():
        device_type = state.get('device_type', 'unknown')
        location = state.get('location', 'unknown')

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

    print(f"\n📊 Simulator Statistics:")
    stats = simulator.get_stats()
    print(f"   🤖 Simulated devices: {stats['simulated_devices']}")
    print(f"   📱 Device types: {stats['device_types']}")
    print(f"   ⚙️  Supported types: {stats['supported_device_types']}")


if __name__ == "__main__":
    import asyncio
    asyncio.run(run_device_simulation_demo())
