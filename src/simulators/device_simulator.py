"""
Device Simulator - Mock IoT devices for testing home automation system

This module simulates IoT devices by:
1. Subscribing to control commands on "home/+/+/set" 
2. Processing received commands and printing them
3. Publishing fake device states to "home/+/+/state"
4. Simulating realistic device behaviors and responses
"""

# ===== CRITICAL: Windows asyncio fix =====
# Must be at the very top before any asyncio usage
import sys
if sys.platform.startswith("win"):
    import asyncio
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
# ==========================================

import asyncio
import os
import json
import logging
import random
from typing import Dict, Any, Optional
from datetime import datetime, timedelta

try:
    import aiomqtt
except ImportError:
    logger = logging.getLogger(__name__)
    logger.warning("aiomqtt not found. Installing...")
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
        broker_port: int = 1883
    ):
        """
        Initialize the device simulator.
        
        Args:
            broker_host (str): MQTT broker hostname
            broker_port (int): MQTT broker port  
        """
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.client_id = f"device_simulator_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
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
            
            logger.info(f"[SIM] Received command on {topic}: {payload}")
            
            # Parse topic
            base, device_type, location, action_type = self._parse_topic(topic)
            
            if action_type != "set":
                return  # Only process 'set' commands
            
            # Parse command JSON
            try:
                command = json.loads(payload)
            except json.JSONDecodeError as e:
                logger.warning(f"[SIM] Invalid JSON payload on {topic}: {e}")
                return
            
            device_key = f"{device_type}.{location}"
            logger.info(f"[SIM] Device: {device_key} - Action: {command.get('action', 'unknown')}")
            if 'value' in command:
                logger.info(f"[SIM] Value: {command['value']}")
            
            # Get response delay for this device type
            config = self._device_configs.get(device_type, self._device_configs["sensor"])
            delay = config["response_delay"]
            
            # Simulate processing delay
            await asyncio.sleep(delay)
            
            # Process command and update device state
            new_state = self._process_command(device_type, location, command)
            logger.info(f"[SIM] Updated device {device_key} to state={json.dumps(new_state)}")
            
            # Publish updated state
            state_topic = f"{base}/{device_type}/{location}/state"
            state_payload = json.dumps(new_state)
            
            logger.info(f"🚀 [TRACE] SIMULATOR PUBLISH STATE | Topic: {state_topic} | Payload: {state_payload}")

            async with aiomqtt.Client(hostname=self.broker_host, port=self.broker_port) as client:
                # Publish without retaining to avoid stale retained messages
                await client.publish(state_topic, state_payload, qos=1, retain=False)

            logger.info(f"[SIM] Published state on {state_topic}: {state_payload}")
            
        except Exception as e:
            logger.error(f"❌ [SIM] CRITICAL ERROR in handle_command: {e}", exc_info=True)
    
    async def _publish_periodic_states(self) -> None:
        """Publish periodic sensor updates for realistic simulation."""
        while self._running:
            try:
                # Update sensor devices with new readings
                # Topic format: home/{device_type}/{location}/state
                sensor_updates = [
                    ("home/temperature/living_room/state", {
                        "value": round(random.uniform(20.0, 25.0), 1),
                        "unit": "C",
                        "humidity": random.randint(40, 60),
                        "timestamp": datetime.now().isoformat()
                    }),
                    ("home/motion/bedroom/state", {
                        "detected": random.choice([True, False]),
                        "confidence": round(random.uniform(0.7, 0.98), 2),
                        "timestamp": datetime.now().isoformat()
                    }),
                    ("home/light_sensor/outdoor/state", {
                        "value": random.randint(10, 1000),
                        "unit": "lux", 
                        "is_dark": random.randint(10, 1000) < 50,
                        "timestamp": datetime.now().isoformat()
                    })
                ]
                
                async with aiomqtt.Client(
                    hostname=self.broker_host,
                    port=self.broker_port
                ) as client:
                    
                    for topic, state in sensor_updates:
                        # Publish periodic sensor updates without retain
                        await client.publish(topic, json.dumps(state), qos=1, retain=False)
                        logger.info(f"📊 Sensor Update: {topic} -> {state.get('value', 'N/A')}")
                
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
            logger.warning("⚠️  DeviceSimulator is already running")
            return
        
        self._running = True
        logger.info("🚀 Starting DeviceSimulator...")
        logger.info(f"📡 MQTT Broker: {self.broker_host}:{self.broker_port}")
        logger.info(f"🎯 Listening for commands on: home/+/+/set")
        logger.info(f"📊 Publishing states to: home/+/+/state")
        logger.info(f"🤖 Client ID: {self.client_id}")
        logger.info("")
        
        # Start periodic sensor updates in background
        sensor_task = asyncio.create_task(self._publish_periodic_states())
        
        while self._running:
            try:
                async with aiomqtt.Client(
                    hostname=self.broker_host,
                    port=self.broker_port
                ) as client:
                    
                    self._client = client

                    logger.info(f"[SIM] Connected to MQTT at {self.broker_host}:{self.broker_port}")

                    # Subscribe to device command topic - FIX: use correct pattern
                    await client.subscribe("home/+/+/set")
                    logger.info("[SIM] ✅ Subscribed to home/+/+/set")
                    
                    # Also subscribe to a legacy/alternate 'command' topic if present

                    try:
                        await client.subscribe("home/+/+/command")
                    except Exception:
                        pass
                    logger.info("[SIM] ✅ Subscribed to device commands")
                    logger.info("[SIM] 💡 Ready to simulate devices! Send commands to test...")
                    logger.info("[SIM] " + "-" * 60)

                    # Process incoming commands
                    async for message in client.messages:
                        if not self._running:
                            break
                        # Ensure concurrency: do not await the handler
                        asyncio.create_task(self._handle_command(message))
                        
            except aiomqtt.MqttError as e:
                logger.error(f"❌ MQTT error: {e}")
                if self._running:
                    logger.info("🔄 Attempting to reconnect in 5 seconds...")
                    await asyncio.sleep(5)
                    
            except Exception as e:
                logger.error(f"❌ Unexpected error: {e}")
                logger.error(f"Unexpected error in DeviceSimulator: {e}")
                if self._running:
                    await asyncio.sleep(10)
        
        # Cancel sensor task
        sensor_task.cancel()
        try:
            await sensor_task
        except asyncio.CancelledError:
            pass

        logger.info("🛑 DeviceSimulator stopped")

    def stop(self) -> None:
        """Stop the device simulator."""
        logger.info("🛑 Stopping DeviceSimulator...")
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


async def main() -> None:
    """CLI entrypoint for running the simulator.

    Reads MQTT_HOST and MQTT_PORT from the environment (defaults: localhost:1883).
    Runs until interrupted and attempts a clean shutdown.
    """
    host = os.environ.get('MQTT_HOST', 'localhost')
    port_str = os.environ.get('MQTT_PORT', '1883')
    try:
        port = int(port_str)
    except Exception:
        port = 1883

    logger.info('[SIM] Starting HomeGenie Device Simulator...')
    logger.info(f"[SIM] Broker: {host}:{port}")

    simulator = DeviceSimulator(broker_host=host, broker_port=port)
    try:
        await simulator.start()
    except KeyboardInterrupt:
        logger.info('\n[SIM] Received interrupt signal, shutting down...')
        simulator.stop()
    except Exception as e:
        logger.error(f"[SIM] Simulator error: {e}")
        simulator.stop()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info('\n[SIM] DeviceSimulator demo ended')