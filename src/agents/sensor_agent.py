"""
SensorAgent - MQTT-based sensor data collection agent

This module provides a SensorAgent class that connects to an MQTT broker,
subscribes to sensor state topics, and updates a ContextStore with the latest data.
"""

import asyncio
import json
import logging
from typing import Optional, Callable, Any
from datetime import datetime

try:
    import aiomqtt
except ImportError:
    print("aiomqtt not found. Installing...")
    import subprocess
    import sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "aiomqtt"])
    import aiomqtt

from src.core.context_store import ContextStore


# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class SensorAgent:
    """
    MQTT-based sensor agent that collects device states and updates ContextStore.
    
    Connects to MQTT broker, subscribes to home sensor topics, parses JSON messages,
    and maintains latest device states in a thread-safe ContextStore.
    """
    
    def __init__(
        self, 
        broker_host: str = "localhost",
        broker_port: int = 1883,
        topic_pattern: str = "home/+/+/state",
        context_store: Optional[ContextStore] = None,
        client_id: Optional[str] = None
    ):
        """
        Initialize the SensorAgent.
        
        Args:
            broker_host (str): MQTT broker hostname
            broker_port (int): MQTT broker port
            topic_pattern (str): MQTT topic pattern to subscribe to
            context_store (Optional[ContextStore]): ContextStore instance to use
            client_id (Optional[str]): MQTT client ID
        """
        self.broker_host = broker_host
        self.broker_port = broker_port
        self.topic_pattern = topic_pattern
        if context_store is None:
            logger.warning("⚠️ No context_store provided, creating new one!")
            self.context_store = ContextStore()
        else:
            self.context_store = context_store
            logger.info(f"📦 Received context store with ID: {id(context_store)}")
        
        self.client_id = client_id or f"sensor_agent_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        self._running = False
        self._client: Optional[aiomqtt.Client] = None
        self._message_callback: Optional[Callable] = None
        self._error_callback: Optional[Callable] = None
        
        logger.info(f"SensorAgent initialized - Broker: {broker_host}:{broker_port}, Topic: {topic_pattern}")
    
    def set_message_callback(self, callback: Callable[[str, dict], None]) -> None:
        """
        Set a custom callback for processed messages.
        
        Args:
            callback: Function that takes (topic, parsed_data) as arguments
        """
        self._message_callback = callback
    
    def set_error_callback(self, callback: Callable[[str, Exception], None]) -> None:
        """
        Set a custom callback for error handling.
        
        Args:
            callback: Function that takes (error_type, exception) as arguments
        """
        self._error_callback = callback
    
    async def _handle_message(self, message: aiomqtt.Message) -> None:
        """
        Process incoming MQTT messages.
        
        Args:
            message: MQTT message object
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
            
            logger.info(f"📨 Received MQTT message on topic '{topic}': {payload}")
            
            # Parse JSON payload
            try:
                parsed_data = json.loads(payload)
            except json.JSONDecodeError as e:
                logger.warning(f"Failed to parse JSON from topic '{topic}': {e}")
                if self._error_callback:
                    self._error_callback("json_parse_error", e)
                return
            
            # Update context store
            await self.context_store.async_update_state(topic, parsed_data)
            logger.info(f"✅ Updated context store for topic '{topic}': {parsed_data}")
            
            # Debug: Check context store state after update
            topics_count = len(await self.context_store.async_get_topics())
            logger.info(f"🔍 Context store (ID:{id(self.context_store)}) now has {topics_count} topics")
            
            # Call custom message callback if set
            if self._message_callback:
                try:
                    if asyncio.iscoroutinefunction(self._message_callback):
                        await self._message_callback(topic, parsed_data)
                    else:
                        self._message_callback(topic, parsed_data)
                except Exception as e:
                    logger.error(f"Error in message callback: {e}")
                    if self._error_callback:
                        self._error_callback("callback_error", e)
            
        except Exception as e:
            logger.error(f"Error handling message: {e}")
            if self._error_callback:
                self._error_callback("message_handling_error", e)
    
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
            
            logger.info(f"Connecting to MQTT broker at {self.broker_host}:{self.broker_port}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to create MQTT client: {e}")
            if self._error_callback:
                self._error_callback("connection_error", e)
            return False
    
    async def disconnect(self) -> None:
        """Disconnect from the MQTT broker."""
        if self._client:
            try:
                # Client will be closed when exiting context manager
                logger.info("Disconnecting from MQTT broker")
            except Exception as e:
                logger.error(f"Error during disconnect: {e}")
        
        self._running = False
    
    async def start(self) -> None:
        """
        Start the sensor agent - connect to MQTT and begin message processing.
        
        This method runs continuously until stop() is called.
        """
        if self._running:
            logger.warning("SensorAgent is already running")
            return
        
        self._running = True
        logger.info("Starting SensorAgent...")
        
        while self._running:
            try:
                async with aiomqtt.Client(
                    hostname=self.broker_host,
                    port=self.broker_port,
                    client_id=self.client_id
                ) as client:
                    self._client = client
                    
                    # Subscribe to the topic pattern
                    await client.subscribe(self.topic_pattern)
                    logger.info(f"Subscribed to topic pattern: {self.topic_pattern}")
                    
                    # Process messages continuously
                    async with client.messages() as messages:
                        async for message in messages:
                            if not self._running:
                                break
                            await self._handle_message(message)
                        
            except aiomqtt.MqttError as e:
                logger.error(f"MQTT error: {e}")
                if self._error_callback:
                    self._error_callback("mqtt_error", e)
                
                if self._running:
                    logger.info("Attempting to reconnect in 5 seconds...")
                    await asyncio.sleep(5)
                    
            except Exception as e:
                logger.error(f"Unexpected error in SensorAgent: {e}")
                if self._error_callback:
                    self._error_callback("unexpected_error", e)
                
                if self._running:
                    logger.info("Restarting in 10 seconds...")
                    await asyncio.sleep(10)
        
        logger.info("SensorAgent stopped")
    
    def stop(self) -> None:
        """Stop the sensor agent."""
        logger.info("Stopping SensorAgent...")
        self._running = False
    
    def is_running(self) -> bool:
        """Check if the agent is currently running."""
        return self._running
    
    async def get_latest_states(self) -> dict:
        """
        Get all latest sensor states from the context store.
        
        Returns:
            dict: All current sensor states
        """
        return await self.context_store.async_dump()
    
    async def get_state(self, topic: str) -> Optional[Any]:
        """
        Get the latest state for a specific topic.
        
        Args:
            topic (str): The sensor topic to query
            
        Returns:
            Optional[Any]: Latest state data or None if not found
        """
        return await self.context_store.async_get_state(topic)
    
    def get_stats(self) -> dict:
        """
        Get agent statistics.
        
        Returns:
            dict: Agent statistics including connection status and topic count
        """
        return {
            "running": self._running,
            "broker": f"{self.broker_host}:{self.broker_port}",
            "topic_pattern": self.topic_pattern,
            "client_id": self.client_id,
            "stored_topics": len(self.context_store),
            "context_store_stats": self.context_store.dump() if self.context_store else {}
        }


# Example usage and testing
async def example_usage():
    """Example of how to use the SensorAgent."""
    print("=== SensorAgent Example ===")
    
    # Create context store and agent
    context_store = ContextStore()
    agent = SensorAgent(
        broker_host="localhost",
        broker_port=1883,
        topic_pattern="home/+/+/state",
        context_store=context_store
    )
    
    # Set up custom callbacks
    def message_callback(topic: str, data: dict):
        print(f"📩 New sensor data: {topic} -> {data}")
    
    def error_callback(error_type: str, exception: Exception):
        print(f"❌ Error ({error_type}): {exception}")
    
    agent.set_message_callback(message_callback)
    agent.set_error_callback(error_callback)
    
    # Start the agent (this would run continuously)
    print("Starting SensorAgent... (Press Ctrl+C to stop)")
    
    try:
        # In a real application, you might run this in a separate task
        # and have other code running concurrently
        await agent.start()
    except KeyboardInterrupt:
        print("\n🛑 Stopping agent...")
        agent.stop()
        
        # Show final stats
        print("\n📊 Final Statistics:")
        stats = agent.get_stats()
        print(json.dumps(stats, indent=2))


async def test_with_mock_data():
    """Test the agent with simulated MQTT messages."""
    print("=== Testing with Mock Data ===")
    
    context_store = ContextStore()
    
    # Simulate some sensor data updates
    test_data = [
        ("home/living_room/temperature/state", {"value": 22.5, "unit": "C", "timestamp": "2025-09-27T10:30:00"}),
        ("home/kitchen/light/state", {"state": "on", "brightness": 80, "color": "warm_white"}),
        ("home/bedroom/motion/state", {"detected": True, "confidence": 0.95, "timestamp": "2025-09-27T10:31:00"}),
        ("home/garage/door/state", {"status": "closed", "locked": True, "last_opened": "2025-09-26T18:45:00"})
    ]
    
    # Update context store with test data
    for topic, payload in test_data:
        await context_store.async_update_state(topic, payload)
        print(f"✅ Updated: {topic}")
    
    # Display all states
    print("\n📋 All Sensor States:")
    all_states = await context_store.async_dump()
    print(json.dumps(all_states, indent=2))
    
    # Query specific states
    print("\n🔍 Querying Specific States:")
    temp_state = await context_store.async_get_state("home/living_room/temperature/state")
    print(f"Living room temperature: {temp_state}")
    
    topics = await context_store.async_get_topics()
    print(f"All topics ({len(topics)}): {topics}")


if __name__ == "__main__":
    # Run test with mock data first
    print("Running mock data test...")
    asyncio.run(test_with_mock_data())
    
    print("\n" + "="*50 + "\n")
    
    # Uncomment to run the actual MQTT agent
    # Note: This requires an MQTT broker running on localhost:1883
    # asyncio.run(example_usage())