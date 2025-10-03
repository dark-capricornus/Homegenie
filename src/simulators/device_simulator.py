"""
Device Simulator - Mock IoT devices for testing home automation system

This module simulates IoT devices by:
1. Subscribing to control commands on "home/+/+/set" 
2. Processing received commands and printing them
3. Publishing fake device states to "home/+/+/state"
4. Simulating realistic device behaviors and responses
"""

import asyncio
import json
import logging
import random
from typing import Dict, Any, Optional
from datetime import datetime, timedelta

try:
    import aiomqtt
except ImportError:
    print("aiomqtt not found. Installing...")
    import subprocess
    import sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "aiomqtt"])
    import aiomqtt


# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DeviceSimulator:
    """
    Simulates multiple IoT devices for testing home automation system.
    
    Listens for commands on "home/+/+/set" topics and responds by:
    - Processing and displaying received commands
    - Publishing realistic device states to "home/+/+/state" topics
    - Simulating device behaviors (delays, state changes, etc.)
    """
    
    def __init__(
        self,
        broker_host: str = "localhost",
        broker_port: int = 1883,
        client_id: Optional[str] = None
    ):
        """
        Initialize the device simulator.
        
        Args:
            broker_host (str): MQTT broker hostname
            broker_port (int): MQTT broker port  
            client_id (Optional[str]): MQTT client ID
        """
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.client_id = client_id or f"device_simulator_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        self._running = False
        self._client: Optional[aiomqtt.Client] = None
        
        # Simulated device states
        self._device_states: Dict[str, Dict[str, Any]] = {}
        
        # Device behavior configurations
        self._device_configs = {
            "light": {
                "default_state": {"state": "off", "brightness": 0, "color": "white"},
                "state_keys": ["state", "brightness", "color", "power_consumption"],
                "response_delay": 0.5
            },
            "switch": {
                "default_state": {"state": "off", "power_consumption": 0},
                "state_keys": ["state", "power_consumption"],
                "response_delay": 0.2
            },
            "thermostat": {
                "default_state": {"temperature": 20.0, "target": 20.0, "mode": "auto"},
                "state_keys": ["temperature", "target", "mode", "humidity"],
                "response_delay": 1.0
            },
            "lock": {
                "default_state": {"locked": True, "battery": 100},
                "state_keys": ["locked", "battery", "last_access"],
                "response_delay": 0.8
            },
            "fan": {
                "default_state": {"state": "off", "speed": 0, "oscillate": False},
                "state_keys": ["state", "speed", "oscillate", "power_consumption"],
                "response_delay": 0.6
            },
            "sensor": {
                "default_state": {"value": 0, "unit": "unknown"},
                "state_keys": ["value", "unit", "timestamp", "battery"],
                "response_delay": 0.1
            }
        }
        
        logger.info(f"DeviceSimulator initialized - Broker: {broker_host}:{broker_port}")
    
    def _parse_topic(self, topic: str) -> tuple[str, str, str, str]:
        """
        Parse MQTT topic into components.
        
        Args:
            topic (str): MQTT topic like "home/light/livingroom/set"
            
        Returns:
            tuple: (base, device_type, location, action)
        """
        parts = topic.split('/')
        if len(parts) >= 4:
            return parts[0], parts[1], parts[2], parts[3]
        return "unknown", "unknown", "unknown", "unknown"
    
    def _get_device_key(self, device_type: str, location: str) -> str:
        """Generate device key for state storage."""
        return f"{device_type}.{location}"
    
    def _initialize_device_state(self, device_type: str, location: str) -> Dict[str, Any]:
        """
        Initialize default state for a device type.
        
        Args:
            device_type (str): Type of device (light, switch, etc.)
            location (str): Device location
            
        Returns:
            dict: Initial device state
        """
        config = self._device_configs.get(device_type, self._device_configs["sensor"])
        state = config["default_state"].copy()
        
        # Add common fields
        state.update({
            "timestamp": datetime.now().isoformat(),
            "device_type": device_type,
            "location": location,
            "online": True
        })
        
        # Add device-specific realistic values
        if device_type == "thermostat":
            state["humidity"] = random.randint(40, 60)
            state["temperature"] = round(random.uniform(18.0, 25.0), 1)
        elif device_type == "sensor":
            if "temperature" in location.lower():
                state.update({"value": round(random.uniform(18.0, 28.0), 1), "unit": "C"})
            elif "motion" in location.lower():
                state.update({"detected": False, "confidence": 0.0})
            elif "light" in location.lower():
                state.update({"value": random.randint(10, 1000), "unit": "lux"})
        elif device_type in ["light", "switch", "fan"]:
            state["power_consumption"] = 0.0
        elif device_type == "lock":
            state["battery"] = random.randint(70, 100)
            state["last_access"] = (datetime.now() - timedelta(hours=random.randint(1, 48))).isoformat()
        
        return state
    
    def _get_device_state(self, device_type: str, location: str) -> Dict[str, Any]:
        """Get current state of a device, initializing if needed."""
        device_key = self._get_device_key(device_type, location)
        
        if device_key not in self._device_states:
            self._device_states[device_key] = self._initialize_device_state(device_type, location)
        
        return self._device_states[device_key]
    
    def _process_command(self, device_type: str, location: str, command: Dict[str, Any]) -> Dict[str, Any]:
        """
        Process device command and update state.
        
        Args:
            device_type (str): Type of device
            location (str): Device location  
            command (dict): Command payload
            
        Returns:
            dict: Updated device state
        """
        state = self._get_device_state(device_type, location)
        action = command.get("action", "unknown")
        value = command.get("value")
        
        # Process different actions
        if action in ["turn_on", "on"]:
            state["state"] = "on"
            if device_type == "light":
                state["brightness"] = state.get("brightness", 50) or 50
                state["power_consumption"] = state["brightness"] * 0.8  # Watts
            elif device_type == "switch":
                state["power_consumption"] = random.uniform(5.0, 15.0)
            elif device_type == "fan":
                state["speed"] = state.get("speed", 2) or 2
                state["power_consumption"] = state["speed"] * 15.0
                
        elif action in ["turn_off", "off"]:
            state["state"] = "off"  
            if device_type in ["light", "switch", "fan"]:
                state["power_consumption"] = 0.0
            if device_type == "light":
                state["brightness"] = 0
            elif device_type == "fan":
                state["speed"] = 0
                
        elif action == "toggle":
            current_state = state.get("state", "off")
            new_state = "off" if current_state == "on" else "on"
            # Recursively process the toggle as turn_on/turn_off
            toggle_command = {"action": f"turn_{new_state}", "value": new_state == "on"}
            return self._process_command(device_type, location, toggle_command)
            
        elif action == "set_brightness" and device_type == "light":
            if value is not None:
                state["brightness"] = max(0, min(100, int(value)))
                state["state"] = "on" if state["brightness"] > 0 else "off"
                state["power_consumption"] = state["brightness"] * 0.8
                
        elif action == "set_color" and device_type == "light":
            if value is not None:
                state["color"] = value
                state["state"] = "on"  # Setting color turns light on
                
        elif action == "set_temperature" and device_type == "thermostat":
            if value is not None:
                state["target"] = float(value)
                state["mode"] = command.get("mode", "auto")
                
        elif action == "set_speed" and device_type == "fan":
            if value is not None:
                speed = max(0, min(5, int(value)))
                state["speed"] = speed
                state["state"] = "on" if speed > 0 else "off"
                state["power_consumption"] = speed * 15.0
                if "oscillate" in command:
                    state["oscillate"] = bool(command["oscillate"])
                    
        elif action in ["lock", "unlock"] and device_type == "lock":
            state["locked"] = action == "lock"
            state["last_access"] = datetime.now().isoformat()
            # Simulate battery drain
            state["battery"] = max(0, state["battery"] - random.uniform(0.1, 0.5))
        
        # Update timestamp
        state["timestamp"] = datetime.now().isoformat()
        
        return state
    
    async def _handle_command(self, message: aiomqtt.Message) -> None:
        """
        Handle incoming device command.
        
        Args:
            message: MQTT message with device command
        """
        try:
            topic = str(message.topic)
            # Handle different payload types safely
            if isinstance(message.payload, bytes):
                payload = message.payload.decode('utf-8')
            elif message.payload is None:
                payload = ""
            else:
                payload = str(message.payload)
            
            print(f"🔧 COMMAND RECEIVED:")
            print(f"   📍 Topic: {topic}")
            print(f"   📦 Payload: {payload}")
            
            # Parse topic
            base, device_type, location, action_type = self._parse_topic(topic)
            
            if action_type != "set":
                return  # Only process 'set' commands
            
            # Parse command JSON
            try:
                command = json.loads(payload)
            except json.JSONDecodeError as e:
                print(f"   ❌ Invalid JSON: {e}")
                return
            
            print(f"   🎯 Device: {device_type}.{location}")
            print(f"   ⚡ Action: {command.get('action', 'unknown')}")
            if 'value' in command:
                print(f"   📊 Value: {command['value']}")
            
            # Get response delay for this device type
            config = self._device_configs.get(device_type, self._device_configs["sensor"])
            delay = config["response_delay"]
            
            # Simulate processing delay
            await asyncio.sleep(delay)
            
            # Process command and update device state
            new_state = self._process_command(device_type, location, command)
            
            # Publish updated state
            state_topic = f"{base}/{device_type}/{location}/state"
            state_payload = json.dumps(new_state)
            
            async with aiomqtt.Client(
                hostname=self.broker_host,
                port=self.broker_port,
                client_id=f"{self.client_id}_publisher"
            ) as client:
                await client.publish(state_topic, state_payload)
            
            print(f"   ✅ State Published:")
            print(f"   📍 Topic: {state_topic}")
            print(f"   📦 New State: {json.dumps(new_state, indent=6)}")
            print()  # Add spacing
            
        except Exception as e:
            print(f"   ❌ Error processing command: {e}")
            logger.error(f"Error handling command: {e}")
    
    async def _publish_periodic_states(self) -> None:
        """Publish periodic sensor updates for realistic simulation."""
        while self._running:
            try:
                # Update sensor devices with new readings
                sensor_updates = [
                    ("home/living_room/temperature/state", {
                        "value": round(random.uniform(20.0, 25.0), 1),
                        "unit": "C",
                        "humidity": random.randint(40, 60),
                        "timestamp": datetime.now().isoformat()
                    }),
                    ("home/bedroom/motion/state", {
                        "detected": random.choice([True, False]),
                        "confidence": round(random.uniform(0.7, 0.98), 2),
                        "timestamp": datetime.now().isoformat()
                    }),
                    ("home/outdoor/light_sensor/state", {
                        "value": random.randint(10, 1000),
                        "unit": "lux", 
                        "is_dark": random.randint(10, 1000) < 50,
                        "timestamp": datetime.now().isoformat()
                    })
                ]
                
                async with aiomqtt.Client(
                    hostname=self.broker_host,
                    port=self.broker_port,
                    client_id=f"{self.client_id}_sensors"
                ) as client:
                    
                    for topic, state in sensor_updates:
                        await client.publish(topic, json.dumps(state))
                        print(f"📊 Sensor Update: {topic} -> {state.get('value', 'N/A')}")
                
                # Wait 30 seconds before next sensor update
                await asyncio.sleep(30)
                
            except Exception as e:
                logger.error(f"Error in periodic state updates: {e}")
                await asyncio.sleep(5)
    
    async def start(self) -> None:
        """
        Start the device simulator.
        
        Connects to MQTT broker, subscribes to command topics, and begins
        processing device commands and publishing states.
        """
        if self._running:
            print("⚠️  DeviceSimulator is already running")
            return
        
        self._running = True
        print("🚀 Starting DeviceSimulator...")
        print(f"   📡 MQTT Broker: {self.broker_host}:{self.broker_port}")
        print(f"   🎯 Listening for commands on: home/+/+/set")
        print(f"   📊 Publishing states to: home/+/+/state")
        print(f"   🤖 Client ID: {self.client_id}")
        print()
        
        # Start periodic sensor updates in background
        sensor_task = asyncio.create_task(self._publish_periodic_states())
        
        while self._running:
            try:
                async with aiomqtt.Client(
                    hostname=self.broker_host,
                    port=self.broker_port,
                    client_id=self.client_id
                ) as client:
                    
                    self._client = client
                    
                    # Subscribe to device command topic
                    await client.subscribe("home/+/+/set")
                    print("✅ Subscribed to device commands")
                    print("💡 Ready to simulate devices! Send commands to test...")
                    print("-" * 60)
                    
                    # Process incoming commands
                    async with client.messages() as messages:
                        async for message in messages:
                            if not self._running:
                                break
                            await self._handle_command(message)
                        
            except aiomqtt.MqttError as e:
                print(f"❌ MQTT error: {e}")
                if self._running:
                    print("🔄 Attempting to reconnect in 5 seconds...")
                    await asyncio.sleep(5)
                    
            except Exception as e:
                print(f"❌ Unexpected error: {e}")
                logger.error(f"Unexpected error in DeviceSimulator: {e}")
                if self._running:
                    await asyncio.sleep(10)
        
        # Cancel sensor task
        sensor_task.cancel()
        try:
            await sensor_task
        except asyncio.CancelledError:
            pass
        
        print("🛑 DeviceSimulator stopped")
    
    def stop(self) -> None:
        """Stop the device simulator."""
        print("🛑 Stopping DeviceSimulator...")
        self._running = False
    
    def is_running(self) -> bool:
        """Check if the simulator is running."""
        return self._running
    
    def get_device_states(self) -> Dict[str, Dict[str, Any]]:
        """Get all current simulated device states."""
        return self._device_states.copy()
    
    def get_stats(self) -> Dict[str, Any]:
        """Get simulator statistics."""
        return {
            "running": self._running,
            "broker": f"{self.broker_host}:{self.broker_port}",
            "client_id": self.client_id,
            "simulated_devices": len(self._device_states),
            "device_types": list(set(state.get("device_type", "unknown") for state in self._device_states.values())),
            "supported_device_types": list(self._device_configs.keys())
        }


# Example usage and testing
async def demo_device_simulator():
    """Demonstrate the device simulator."""
    print("=== Device Simulator Demo ===\n")
    
    # Create simulator
    simulator = DeviceSimulator()
    
    # Show initial stats
    print("📊 Initial Stats:")
    stats = simulator.get_stats()
    print(f"   🤖 Supported devices: {stats['supported_device_types']}")
    print()
    
    print("💡 The simulator will:")
    print("   1. 🎯 Listen for commands on 'home/+/+/set'")
    print("   2. 🖨️  Print received commands")  
    print("   3. 📊 Publish device states to 'home/+/+/state'")
    print("   4. 📡 Send periodic sensor updates")
    print()
    
    print("🧪 To test, run these commands in another terminal:")
    print("   mosquitto_pub -h localhost -t 'home/light/livingroom/set' \\")
    print('     -m \'{"action":"set_brightness","value":40}\'')
    print()
    print("   mosquitto_pub -h localhost -t 'home/thermostat/bedroom/set' \\")
    print('     -m \'{"action":"set_temperature","value":22.5}\'')
    print()
    
    try:
        # Start simulator (runs indefinitely)
        await simulator.start()
    except KeyboardInterrupt:
        print("\n🛑 Received interrupt signal")
        simulator.stop()


if __name__ == "__main__":
    # Run the device simulator
    try:
        asyncio.run(demo_device_simulator())
    except KeyboardInterrupt:
        print("\n👋 DeviceSimulator demo ended")