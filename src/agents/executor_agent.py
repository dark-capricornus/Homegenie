"""
ExecutorAgent - MQTT-based device command execution agent (paho-mqtt version)

This module provides an ExecutorAgent class that connects to an MQTT broker
and executes device control commands by publishing to appropriate MQTT topics.
"""

import asyncio
import json
import logging
import threading
import os
from typing import Optional, Dict, Any, List
from datetime import datetime

import httpx

try:
    import paho.mqtt.client as mqtt
except ImportError:
    import sys
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "paho-mqtt"])
    import paho.mqtt.client as mqtt

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class ExecutorAgent:
    """
    MQTT-based device command execution agent.
    
    Connects to MQTT broker and executes device control commands by publishing
    JSON payloads to appropriate device control topics.
    """
    
    def __init__(
        self,
        broker_host: str = "localhost",
        broker_port: int = 1883,
        client_id: Optional[str] = None,
        base_topic: str = "home",
        context_store=None  # For two-phase state reconciliation
    ):
        """
        Initialize the ExecutorAgent.
        
        Args:
            broker_host (str): MQTT broker hostname
            broker_port (int): MQTT broker port
            client_id (Optional[str]): MQTT client ID
            base_topic (str): Base topic for device commands (default: "home")
            context_store: ContextStore instance for state tracking
        """
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.base_topic = base_topic
        self.client_id = client_id or f"executor_agent_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        self.context_store = context_store  # For two-phase state
        
        self._client: Optional[mqtt.Client] = None
        self._connected = False
        self._lock = threading.Lock()
        
        # Device Registry
        self.devices: Dict[str, Any] = {}
        self._load_devices()
        
        logger.info(f"ExecutorAgent initialized - Broker: {broker_host}:{broker_port}, Base topic: {base_topic}")

    def _load_devices(self) -> None:
        """Load device configuration from config/devices.json."""
        config_path = os.path.join(os.getcwd(), "config", "devices.json")
        try:
            if os.path.exists(config_path):
                with open(config_path, "r") as f:
                    devices_list = json.load(f)
                    # Index by ID for fast lookup
                    self.devices = {d["id"]: d for d in devices_list if d.get("enabled", True)}
                logger.info(f"Loaded {len(self.devices)} devices from {config_path}")
            else:
                logger.debug(f"No device config found at {config_path}")
                self.devices = {}
        except Exception as e:
            logger.error(f"Failed to load device config: {e}")
            self.devices = {}
    
    def _on_connect(self, client, userdata, flags, rc):
        """Callback for when the client receives a CONNACK response from the server."""
        if rc == 0:
            logger.info(f"✅ ExecutorAgent connected to MQTT broker at {self.broker_host}:{self.broker_port}")
            self._connected = True
        else:
            logger.error(f"❌ ExecutorAgent failed to connect, return code {rc}")
            self._connected = False
    
    def _on_disconnect(self, client, userdata, rc):
        """Callback for when the client disconnects from the broker."""
        self._connected = False
        if rc != 0:
            logger.warning(f"⚠️ ExecutorAgent unexpected disconnection from broker (code {rc})")
        else:
            logger.info("📡 ExecutorAgent disconnected from MQTT broker")
    
    def _on_publish(self, client, userdata, mid):
        """Callback for when a message is published."""
        logger.debug(f"📤 Message published with ID: {mid}")
    
    async def connect(self) -> bool:
        """
        Connect to the MQTT broker.
        
        Returns:
            bool: True if connected successfully, False otherwise
        """
        with self._lock:
            if self._connected:
                logger.debug("Already connected to MQTT broker")
                return True
            
            try:
                # Create MQTT client
                self._client = mqtt.Client()
                
                # Set callbacks
                self._client.on_connect = self._on_connect
                self._client.on_disconnect = self._on_disconnect
                self._client.on_publish = self._on_publish
                
                # Connect to broker
                logger.info(f"🔌 ExecutorAgent connecting to MQTT broker {self.broker_host}:{self.broker_port}...")
                self._client.connect(self.broker_host, self.broker_port, 60)
                
                # Start the network loop in a separate thread
                self._client.loop_start()
                
                # Wait for connection (up to 5 seconds)
                for _ in range(50):  # 5 seconds with 0.1s intervals
                    if self._connected:
                        break
                    await asyncio.sleep(0.1)
                
                if not self._connected:
                    logger.error("❌ Failed to connect within timeout")
                    return False
                
                logger.info("✅ ExecutorAgent connected successfully")
                return True
                
            except Exception as e:
                logger.error(f"❌ Error connecting to MQTT broker: {e}")
                self._connected = False
                return False
    
    async def disconnect(self):
        """Disconnect from the MQTT broker."""
        with self._lock:
            if self._client and self._connected:
                self._client.loop_stop()
                self._client.disconnect()
                self._connected = False
                logger.info("📡 ExecutorAgent disconnected")
    
    def _build_command_topic(self, device_type: str, location: str) -> str:
        """
        Build the MQTT topic for device commands.
        
        Args:
            device_type (str): Type of device (e.g., "light", "thermostat")
            location (str): Device location (e.g., "living_room", "bedroom")
            
        Returns:
            str: MQTT topic for device commands
        """
        # Use '/set' topic so device simulators listening on '.../set' receive commands
        return f"{self.base_topic}/{device_type}/{location}/set"
    
    def _parse_device_id(self, device_id: str) -> tuple[str, str]:
        """
        Parse device ID into device type and location.
        
        Args:
            device_id (str): Device ID in format "type.location"
            
        Returns:
            tuple: (device_type, location)
        """
        if '.' in device_id:
            device_type, location = device_id.split('.', 1)
        else:
            # Fallback for devices without type prefix
            device_type = "device"
            location = device_id
        
        return device_type, location
    
    def _build_command_payload(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """
        Build the command payload from a task specification.
        
        Args:
            task (Dict[str, Any]): Task specification
            
        Returns:
            Dict[str, Any]: Command payload for MQTT
        """
        action = task.get("action", "")
        device_id = task.get("device", "")
        
        # Base command structure
        command = {
            "timestamp": datetime.now().isoformat(),
            "source": "executor_agent",
            "device": device_id,
            "action": action
        }
        
        # Map common actions to device commands and set 'value' consistently so simulators
        # that expect {'action': '...', 'value': ...} will understand the payload.
        if action == "turn_on":
            command.update({"value": True})
        elif action == "turn_off":
            command.update({"value": False})
        elif action == "toggle":
            command.update({"value": "toggle"})
        elif action == "set_brightness":
            command.update({"value": task.get("value", 50)})
        elif action == "set_color":
            command.update({"value": task.get("value", "white")})
        elif action == "set_temperature":
            command.update({"value": task.get("value", 22.0)})
        elif action == "lock":
            command.update({"value": True})
        elif action == "unlock":
            command.update({"value": False})
        elif action == "set_speed":
            command.update({"value": task.get("value", 1)})
        else:
            # Generic action - include all task parameters (except device/action) and mirror a 'value' when obvious
            for key, value in task.items():
                if key not in ["device", "action"]:
                    command[key] = value
            if "value" not in command and any(k in command for k in ("brightness", "target_temperature", "speed", "color", "locked")):
                # map common param to value for compat
                for k in ("brightness", "target_temperature", "speed", "color", "locked"):
                    if k in command:
                        command["value"] = command[k]
                        break
        
        return command
    
    async def execute(self, task: Dict[str, Any]) -> bool:
        """
        Execute a device control task via configured protocol (MQTT or HTTP).
        
        Args:
            task (Dict[str, Any]): Task specification with device, action, and parameters
            
        Returns:
            bool: True if command was dispatched successfully, False otherwise
        """
        device_id = task.get("device", "")
        action = task.get("action", "")
        value = task.get("value")
        
        if not device_id:
            logger.error("❌ No device specified in task")
            return False
        
        # TWO-PHASE STATE: Write commanded state ONLY (status = pending)
        # ExecutorAgent NEVER confirms success - only SensorAgent does
        if self.context_store:
            try:
                await self.context_store.async_update_commanded_state(
                    device_id, action, value, timeout_seconds=5.0
                )
                logger.debug(f"📝 Commanded state written for {device_id}: {action}={value} (pending)")
            except Exception as e:
                logger.error(f"Failed to write commanded state: {e}")
            
        # Look up device config or fallback
        device_config = self.devices.get(device_id)
        if not device_config:
             # Fallback: assume MQTT with default topic structure
             # Warn but proceed for backward compatibility
             logger.warning(f"⚠️ Device {device_id} not found in config, falling back to default MQTT logic")
             device_type, location = self._parse_device_id(device_id)
             protocol = "mqtt"
             # Fallback topic
             topic = self._build_command_topic(device_type, location)
             http_url = None
        else:
            protocol = device_config.get("protocol", "mqtt")
            topic = device_config.get("topic")
            http_url = device_config.get("command_url")

        # Prepare payload
        payload = self._build_command_payload(task)
        
        try:
            if protocol == "mqtt":
                return await self._execute_mqtt(device_id, topic, payload, device_config)
            elif protocol == "http":
                return await self._execute_http(device_id, http_url, payload, device_config)
            else:
                logger.error(f"❌ Unknown protocol '{protocol}' for device {device_id}")
                return False
                
        except Exception as e:
            logger.error(f"❌ Error executing task for {device_id}: {e}")
            return False

    async def _execute_mqtt(self, device_id: str, topic: Optional[str], payload: Dict[str, Any], config: Optional[Dict[str, Any]]) -> bool:
        """Helper to execute MQTT command."""
        # Ensure topic exists
        if not topic:
             # Should have been generated in fallback, but double check
             device_type, location = self._parse_device_id(device_id)
             topic = self._build_command_topic(device_type, location)

        # Ensure we're connected
        if not self._connected:
            logger.info("🔌 Not connected, attempting to connect...")
            if not await self.connect():
                logger.error("❌ Failed to connect to MQTT broker")
                return False

        payload_json = json.dumps(payload)
        logger.info(f"🚀 [MQTT] Dispatching to {topic}: {payload_json}")
        
        with self._lock:
            if self._client and self._connected:
                qos = config.get("qos", 1) if config else 1
                retain = config.get("retain", False) if config else False
                
                result = self._client.publish(topic, payload_json, qos=qos, retain=retain)
                
                if result.rc == mqtt.MQTT_ERR_SUCCESS:
                    logger.info(f"✅ MQTT Command sent for {device_id}")
                    return True
                else:
                    logger.error(f"❌ Failed to publish command: {result.rc}")
                    return False
            else:
                return False

    async def _execute_http(self, device_id: str, url: Optional[str], payload: Dict[str, Any], config: Optional[Dict[str, Any]]) -> bool:
        """Helper to execute HTTP command."""
        if not url:
            logger.error(f"❌ No command_url configured for HTTP device {device_id}")
            return False
            
        timeout = config.get("timeout", 3.0) if config else 3.0
        method = config.get("method", "POST") if config else "POST"
        
        logger.info(f"🚀 [HTTP] Dispatching to {url}: {payload}")
        
        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                if method.upper() == "POST":
                    response = await client.post(url, json=payload)
                else:
                    # Fallback or other methods if needed
                    response = await client.request(method, url, json=payload)
                
                if response.status_code >= 200 and response.status_code < 300:
                    logger.info(f"✅ HTTP Command sent for {device_id} (Status: {response.status_code})")
                    return True
                else:
                    logger.warning(f"⚠️ HTTP Command failed for {device_id} (Status: {response.status_code}): {response.text}")
                    return False
        except Exception as e:
            logger.error(f"❌ HTTP Request failed for {device_id}: {e}")
            return False
    
    async def execute_batch(self, tasks: List[Dict[str, Any]]) -> List[bool]:
        """
        Execute multiple tasks in sequence.
        
        Args:
            tasks (List[Dict[str, Any]]): List of task specifications
            
        Returns:
            List[bool]: Results for each task
        """
        results = []
        
        for i, task in enumerate(tasks):
            logger.info(f"📋 Executing task {i+1}/{len(tasks)}")
            result = await self.execute(task)
            results.append(result)
            
            # Small delay between commands to avoid overwhelming devices
            if i < len(tasks) - 1:
                await asyncio.sleep(0.1)
        
        successful = sum(results)
        logger.info(f"📊 Batch execution completed: {successful}/{len(tasks)} successful")
        
        return results
    
    def is_connected(self) -> bool:
        """
        Check if the agent is connected to the MQTT broker.
        
        Returns:
            bool: True if connected, False otherwise
        """
        return self._connected
    
    async def get_status(self) -> Dict[str, Any]:
        """
        Get the current status of the executor agent.
        
        Returns:
            Dict[str, Any]: Status information
        """
        return {
            "connected": self._connected,
            "broker_host": self.broker_host,
            "broker_port": self.broker_port,
            "base_topic": self.base_topic,
            "client_id": self.client_id,
            "timestamp": datetime.now().isoformat()
        }


# Utility functions for common device operations
async def create_executor_agent(
    broker_host: str = "localhost",
    broker_port: int = 1883,
    auto_connect: bool = True
) -> ExecutorAgent:
    """
    Create and optionally connect an ExecutorAgent instance.
    
    Args:
        broker_host (str): MQTT broker hostname
        broker_port (int): MQTT broker port
        auto_connect (bool): Whether to automatically connect
    
    Returns:
        ExecutorAgent: Configured executor agent instance
    """
    agent = ExecutorAgent(broker_host=broker_host, broker_port=broker_port)
    
    if auto_connect:
        await agent.connect()
    
    return agent


async def quick_device_command(
    device_id: str,
    action: str,
    broker_host: str = "localhost",
    **kwargs
) -> bool:
    """
    Execute a quick device command without managing agent lifecycle.
    
    Args:
        device_id (str): Device ID (e.g., "light.living_room")
        action (str): Action to perform (e.g., "turn_on", "set_brightness")
        broker_host (str): MQTT broker hostname
        **kwargs: Additional parameters for the command
    
    Returns:
        bool: True if command was executed successfully
    """
    agent = ExecutorAgent(broker_host=broker_host)
    
    try:
        if not await agent.connect():
            return False
        
        task = {"device": device_id, "action": action}
        task.update(kwargs)
        
        return await agent.execute(task)
        
    finally:
        await agent.disconnect()


if __name__ == "__main__":
    # Example usage
    async def main():
        # Create and connect executor agent
        agent = ExecutorAgent(broker_host="localhost", broker_port=1883)
        await agent.connect()
        
        # Example tasks
        tasks = [
            {"device": "light.living_room", "action": "turn_on"},
            {"device": "light.living_room", "action": "set_brightness", "value": 75},
            {"device": "thermostat.main", "action": "set_temperature", "value": 22.0},
            {"device": "lock.front_door", "action": "lock"}
        ]
        
        # Execute tasks
        for task in tasks:
            success = await agent.execute(task)
            print(f"Task {task}: {'✅' if success else '❌'}")
        
        # Disconnect
        await agent.disconnect()
    
    asyncio.run(main())