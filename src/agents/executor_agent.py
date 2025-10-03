"""
ExecutorAgent - MQTT-based device command execution agent

This module provides an ExecutorAgent class that connects to an MQTT broker
and executes device control commands by publishing to appropriate MQTT topics.
"""

import asyncio
import json
import logging
from typing import Optional, Dict, Any, List, Callable
from datetime import datetime

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
        
        self._client: Optional[aiomqtt.Client] = None
        self._connected = False
        self._execution_history: List[Dict[str, Any]] = []
        self._success_callback: Optional[Callable] = None
        self._error_callback: Optional[Callable] = None
        
        # Device type to topic mapping
        self._device_mappings = {
            "light": "light",
            "switch": "switch", 
            "thermostat": "thermostat",
            "fan": "fan",
            "lock": "lock",
            "sensor": "sensor",
            "camera": "camera",
            "alarm": "alarm"
        }
        
        logger.info(f"ExecutorAgent initialized - Broker: {broker_host}:{broker_port}, Base topic: {base_topic}")
    
    def set_success_callback(self, callback: Callable[[Dict[str, Any]], None]) -> None:
        """
        Set a callback for successful command executions.
        
        Args:
            callback: Function that takes the execution result as argument
        """
        self._success_callback = callback
    
    def set_error_callback(self, callback: Callable[[str, Exception, Dict[str, Any]], None]) -> None:
        """
        Set a callback for execution errors.
        
        Args:
            callback: Function that takes (error_type, exception, task) as arguments
        """
        self._error_callback = callback
    
    def add_device_mapping(self, device_type: str, topic_segment: str) -> None:
        """
        Add or update device type to topic mapping.
        
        Args:
            device_type (str): Device type (e.g., "light", "switch")
            topic_segment (str): MQTT topic segment for this device type
        """
        self._device_mappings[device_type] = topic_segment
        logger.info(f"Added device mapping: {device_type} -> {topic_segment}")
    
    def _parse_device_identifier(self, device: str) -> tuple[str, str]:
        """
        Parse device identifier into type and location.
        
        Args:
            device (str): Device identifier like "light.livingroom" or "thermostat.bedroom"
            
        Returns:
            tuple[str, str]: (device_type, location)
        """
        if '.' in device:
            device_type, location = device.split('.', 1)
        else:
            # If no dot, assume it's just the device type
            device_type = device
            location = "default"
        
        return device_type.lower(), location.lower()
    
    def _build_topic(self, device_type: str, location: str) -> str:
        """
        Build MQTT topic for device command.
        
        Args:
            device_type (str): Type of device
            location (str): Device location/room
            
        Returns:
            str: Complete MQTT topic path
        """
        # Map device type to topic segment
        topic_segment = self._device_mappings.get(device_type, device_type)
        
        # Build topic: home/light/livingroom/set
        topic = f"{self.base_topic}/{topic_segment}/{location}/set"
        return topic
    
    def _build_payload(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """
        Build JSON payload for device command.
        
        Args:
            task (dict): Task dictionary with action and parameters
            
        Returns:
            dict: JSON payload to send to device
        """
        payload = {
            "action": task.get("action"),
            "timestamp": datetime.now().isoformat(),
            "source": "executor_agent"
        }
        
        # Add value if present
        if "value" in task:
            payload["value"] = task["value"]
        
        # Add any additional parameters
        for key, value in task.items():
            if key not in ["device", "action", "value"]:
                payload[key] = value
        
        return payload
    
    async def connect(self) -> bool:
        """
        Connect to the MQTT broker.
        
        Returns:
            bool: True if connection successful, False otherwise
        """
        try:
            self._client = aiomqtt.Client(
                hostname=self.broker_host,
                port=self.broker_port,
                client_id=self.client_id
            )
            
            # Test connection
            async with self._client:
                self._connected = True
                logger.info(f"Successfully connected to MQTT broker at {self.broker_host}:{self.broker_port}")
                return True
                
        except Exception as e:
            logger.error(f"Failed to connect to MQTT broker: {e}")
            if self._error_callback:
                self._error_callback("connection_error", e, {})
            self._connected = False
            return False
    
    async def disconnect(self) -> None:
        """Disconnect from the MQTT broker."""
        if self._client:
            try:
                # Client will be closed when exiting context manager
                self._connected = False
                logger.info("Disconnected from MQTT broker")
            except Exception as e:
                logger.error(f"Error during disconnect: {e}")
    
    async def execute(self, task: Dict[str, Any]) -> bool:
        """
        Execute a device control task.
        
        Args:
            task (dict): Task dictionary with format:
                       {"device": "light.livingroom", "action": "set_brightness", "value": 40}
                       
        Returns:
            bool: True if execution successful, False otherwise
        """
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
            
            logger.info(f"Executing task: {task}")
            logger.debug(f"Publishing to topic: {topic}")
            logger.debug(f"Payload: {payload}")
            
            # Execute command via MQTT
            async with aiomqtt.Client(
                hostname=self.broker_host,
                port=self.broker_port,
                client_id=self.client_id
            ) as client:
                
                # Publish command
                await client.publish(topic, json.dumps(payload))
                
                # Record execution
                execution_record = {
                    "timestamp": datetime.now().isoformat(),
                    "task": task,
                    "topic": topic,
                    "payload": payload,
                    "status": "success"
                }
                
                self._execution_history.append(execution_record)
                
                # Keep history limited to last 100 executions
                if len(self._execution_history) > 100:
                    self._execution_history.pop(0)
                
                logger.info(f"✅ Successfully executed task for {task['device']}")
                
                # Call success callback
                if self._success_callback:
                    try:
                        if asyncio.iscoroutinefunction(self._success_callback):
                            await self._success_callback(execution_record)
                        else:
                            self._success_callback(execution_record)
                    except Exception as e:
                        logger.error(f"Error in success callback: {e}")
                
                return True
                
        except Exception as e:
            logger.error(f"❌ Failed to execute task {task}: {e}")
            
            # Record failed execution
            execution_record = {
                "timestamp": datetime.now().isoformat(),
                "task": task,
                "error": str(e),
                "status": "failed"
            }
            
            self._execution_history.append(execution_record)
            
            # Call error callback
            if self._error_callback:
                self._error_callback("execution_error", e, task)
            
            return False
    
    async def execute_batch(self, tasks: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Execute multiple tasks in batch.
        
        Args:
            tasks (List[dict]): List of task dictionaries
            
        Returns:
            dict: Batch execution results with success/failure counts
        """
        results = {
            "total": len(tasks),
            "successful": 0,
            "failed": 0,
            "results": []
        }
        
        logger.info(f"Executing batch of {len(tasks)} tasks")
        
        for i, task in enumerate(tasks):
            try:
                success = await self.execute(task)
                result = {
                    "task_index": i,
                    "task": task,
                    "success": success
                }
                
                if success:
                    results["successful"] += 1
                else:
                    results["failed"] += 1
                    
                results["results"].append(result)
                
            except Exception as e:
                logger.error(f"Error in batch execution for task {i}: {e}")
                results["failed"] += 1
                results["results"].append({
                    "task_index": i,
                    "task": task,
                    "success": False,
                    "error": str(e)
                })
        
        logger.info(f"Batch execution complete: {results['successful']}/{results['total']} successful")
        return results
    
    def get_execution_history(self, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Get recent execution history.
        
        Args:
            limit (int): Maximum number of records to return
            
        Returns:
            List[dict]: Recent execution records
        """
        return self._execution_history[-limit:]
    
    def get_stats(self) -> Dict[str, Any]:
        """
        Get executor agent statistics.
        
        Returns:
            dict: Agent statistics
        """
        total_executions = len(self._execution_history)
        successful = len([r for r in self._execution_history if r.get("status") == "success"])
        failed = total_executions - successful
        
        return {
            "connected": self._connected,
            "broker": f"{self.broker_host}:{self.broker_port}",
            "client_id": self.client_id,
            "base_topic": self.base_topic,
            "total_executions": total_executions,
            "successful_executions": successful,
            "failed_executions": failed,
            "success_rate": (successful / total_executions * 100) if total_executions > 0 else 0,
            "device_mappings": self._device_mappings
        }
    
    def clear_history(self) -> None:
        """Clear execution history."""
        self._execution_history.clear()
        logger.info("Execution history cleared")


# Example usage and testing
async def example_usage():
    """Example of how to use the ExecutorAgent."""
    print("=== ExecutorAgent Example ===")
    
    # Create executor agent
    executor = ExecutorAgent(
        broker_host="localhost",
        broker_port=1883,
        base_topic="home"
    )
    
    # Set up callbacks
    def success_callback(result: dict):
        print(f"✅ Command executed successfully: {result['task']['device']} -> {result['task']['action']}")
    
    def error_callback(error_type: str, exception: Exception, task: dict):
        print(f"❌ Execution failed ({error_type}): {task} -> {exception}")
    
    executor.set_success_callback(success_callback)
    executor.set_error_callback(error_callback)
    
    # Example tasks
    tasks = [
        {"device": "light.livingroom", "action": "set_brightness", "value": 40},
        {"device": "light.bedroom", "action": "turn_on", "value": True},
        {"device": "thermostat.main", "action": "set_temperature", "value": 22.5},
        {"device": "switch.kitchen", "action": "toggle"},
        {"device": "lock.front_door", "action": "lock", "value": True}
    ]
    
    print(f"Executing {len(tasks)} example tasks...")
    
    # Execute tasks
    for task in tasks:
        print(f"\n📤 Executing: {task}")
        success = await executor.execute(task)
        if success:
            print(f"   ✅ Published to MQTT successfully")
        else:
            print(f"   ❌ Execution failed")
    
    # Show statistics
    print(f"\n📊 Executor Statistics:")
    stats = executor.get_stats()
    print(json.dumps(stats, indent=2))
    
    # Show execution history
    print(f"\n📋 Recent Execution History:")
    history = executor.get_execution_history(limit=3)
    for record in history:
        print(f"  {record['timestamp']}: {record['task']['device']} -> {record['status']}")


async def test_batch_execution():
    """Test batch execution functionality."""
    print("\n=== Batch Execution Test ===")
    
    executor = ExecutorAgent()
    
    # Batch of tasks
    batch_tasks = [
        {"device": "light.living_room", "action": "set_brightness", "value": 75},
        {"device": "light.bedroom", "action": "set_color", "value": "#FF6B6B"},
        {"device": "thermostat.main", "action": "set_temperature", "value": 24.0},
        {"device": "fan.ceiling", "action": "set_speed", "value": 3}
    ]
    
    print(f"Executing batch of {len(batch_tasks)} tasks...")
    results = await executor.execute_batch(batch_tasks)
    
    print(f"\n📊 Batch Results:")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    # Run examples
    print("Running ExecutorAgent examples...")
    asyncio.run(example_usage())
    
    print("\n" + "="*50)
    asyncio.run(test_batch_execution())