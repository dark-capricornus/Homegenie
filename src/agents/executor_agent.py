"""
ExecutorAgent - MQTT-based device command execution agent (paho-mqtt version)

This module provides an ExecutorAgent class that connects to an MQTT broker
and executes device control commands by publishing to appropriate MQTT topics.
"""

import asyncio
import json
import logging
import threading
import time
from typing import Optional, Dict, Any, List, Callable
from datetime import datetime

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("paho-mqtt not found. Installing...")
    import subprocess
    import sys
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
        base_topic: str = "home"
    ):
        """
        Initialize the ExecutorAgent.
        
        Args:
            broker_host (str): MQTT broker hostname
            broker_port (int): MQTT broker port
            client_id (Optional[str]): MQTT client ID
            base_topic (str): Base topic for device commands (default: "home")
        """
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.base_topic = base_topic
        self.client_id = client_id or f"executor_agent_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        self._client: Optional[mqtt.Client] = None
        self._connected = False
        self._lock = threading.Lock()
        
        logger.info(f"ExecutorAgent initialized - Broker: {broker_host}:{broker_port}, Base topic: {base_topic}")
    
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
        return f"{self.base_topic}/{device_type}/{location}/command"
    
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
        
        # Map common actions to device commands
        if action == "turn_on":
            command.update({"state": "on"})
        elif action == "turn_off":
            command.update({"state": "off"})
        elif action == "toggle":
            command.update({"toggle": True})
        elif action == "set_brightness":
            command.update({"brightness": task.get("value", 50)})
        elif action == "set_color":
            command.update({"color": task.get("value", "white")})
        elif action == "set_temperature":
            command.update({"target_temperature": task.get("value", 22.0)})
        elif action == "lock":
            command.update({"locked": True})
        elif action == "unlock":
            command.update({"locked": False})
        elif action == "set_speed":
            command.update({"speed": task.get("value", 1)})
        else:
            # Generic action - include all task parameters
            for key, value in task.items():
                if key not in ["device", "action"]:
                    command[key] = value
        
        return command
    
    async def execute(self, task: Dict[str, Any]) -> bool:
        """
        Execute a device control task.
        
        Args:
            task (Dict[str, Any]): Task specification with device, action, and parameters
            
        Returns:
            bool: True if command was published successfully, False otherwise
        """
        try:
            # Ensure we're connected
            if not self._connected:
                logger.info("🔌 Not connected, attempting to connect...")
                if not await self.connect():
                    logger.error("❌ Failed to connect to MQTT broker")
                    return False
            
            # Parse device information
            device_id = task.get("device", "")
            if not device_id:
                logger.error("❌ No device specified in task")
                return False
            
            device_type, location = self._parse_device_id(device_id)
            
            # Build command topic and payload
            command_topic = self._build_command_topic(device_type, location)
            command_payload = self._build_command_payload(task)
            
            # Publish command
            payload_json = json.dumps(command_payload)
            
            logger.info(f"📤 Publishing command to {command_topic}: {payload_json}")
            
            with self._lock:
                if self._client and self._connected:
                    result = self._client.publish(command_topic, payload_json, qos=1)
                    
                    if result.rc == mqtt.MQTT_ERR_SUCCESS:
                        logger.info(f"✅ Command sent successfully for {device_id}")
                        return True
                    else:
                        logger.error(f"❌ Failed to publish command: {result.rc}")
                        return False
                else:
                    logger.error("❌ MQTT client not connected")
                    return False
            
        except Exception as e:
            logger.error(f"❌ Error executing task: {e}")
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