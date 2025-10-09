"""
SensorAgent - MQTT-based sensor data collection agent (paho-mqtt version)

This module provides a SensorAgent class that connects to an MQTT broker,
subscribes to sensor state topics, and updates a ContextStore with the latest data.
"""

import asyncio
import json
import logging
import threading
import time
from typing import Optional, Callable, Any
from datetime import datetime

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("paho-mqtt not found. Installing...")
    import subprocess
    import sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "paho-mqtt"])
    import paho.mqtt.client as mqtt

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
        self._client: Optional[mqtt.Client] = None
        self._message_callback: Optional[Callable] = None
        self._error_callback: Optional[Callable] = None
        self._thread: Optional[threading.Thread] = None
        
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
    
    def _on_connect(self, client, userdata, flags, rc):
        """Callback for when the client receives a CONNACK response from the server."""
        if rc == 0:
            logger.info(f"✅ Connected to MQTT broker at {self.broker_host}:{self.broker_port}")
            # Subscribe to the topic pattern
            client.subscribe(self.topic_pattern)
            logger.info(f"🎯 Subscribed to topic pattern: {self.topic_pattern}")
        else:
            logger.error(f"❌ Failed to connect, return code {rc}")
            if self._error_callback:
                self._error_callback("connection_failed", Exception(f"Connection failed with code {rc}"))
    
    def _on_message(self, client, userdata, msg):
        """Callback for when a PUBLISH message is received from the server."""
        try:
            topic = msg.topic
            payload = msg.payload.decode('utf-8')
            
            logger.debug(f"📨 Received message on topic {topic}: {payload}")
            
            # Parse JSON payload
            try:
                parsed_data = json.loads(payload)
            except json.JSONDecodeError as e:
                logger.warning(f"⚠️ Invalid JSON in message from {topic}: {e}")
                if self._error_callback:
                    self._error_callback("json_decode_error", e)
                return
            
            # Add timestamp if not present
            if 'timestamp' not in parsed_data:
                parsed_data['timestamp'] = datetime.now().isoformat()
            
            # Update context store
            self.context_store.update_state(topic, parsed_data)
            logger.debug(f"📋 Updated state for {topic}")
            
            # Call custom message callback if set
            if self._message_callback:
                try:
                    self._message_callback(topic, parsed_data)
                except Exception as e:
                    logger.error(f"Error in message callback: {e}")
            
        except Exception as e:
            logger.error(f"Error processing message from {msg.topic}: {e}")
            if self._error_callback:
                self._error_callback("message_processing_error", e)
    
    def _on_disconnect(self, client, userdata, rc):
        """Callback for when the client disconnects from the broker."""
        if rc != 0:
            logger.warning(f"⚠️ Unexpected disconnection from broker (code {rc})")
        else:
            logger.info("📡 Disconnected from MQTT broker")
    
    def _on_subscribe(self, client, userdata, mid, granted_qos):
        """Callback for when the broker responds to a subscribe request."""
        logger.info(f"✅ Successfully subscribed to {self.topic_pattern}")
    
    def _run_mqtt_loop(self):
        """Run the MQTT client loop in a separate thread."""
        try:
            # Create MQTT client
            self._client = mqtt.Client()
            
            # Set callbacks
            self._client.on_connect = self._on_connect
            self._client.on_message = self._on_message
            self._client.on_disconnect = self._on_disconnect
            self._client.on_subscribe = self._on_subscribe
            
            # Connect to broker
            logger.info(f"🔌 Connecting to MQTT broker {self.broker_host}:{self.broker_port}...")
            self._client.connect(self.broker_host, self.broker_port, 60)
            
            # Start the loop
            self._client.loop_forever()
            
        except Exception as e:
            logger.error(f"❌ Error in MQTT loop: {e}")
            if self._error_callback:
                self._error_callback("mqtt_loop_error", e)
    
    async def start(self) -> None:
        """
        Start the sensor agent asynchronously.
        """
        if self._running:
            logger.warning("⚠️ SensorAgent is already running")
            return
        
        self._running = True
        logger.info("🚀 Starting SensorAgent...")
        
        try:
            # Start MQTT client in a separate thread
            self._thread = threading.Thread(target=self._run_mqtt_loop, daemon=True)
            self._thread.start()
            
            logger.info("✅ SensorAgent started successfully")
            
            # Keep the async loop running
            while self._running:
                await asyncio.sleep(1)
                
        except Exception as e:
            logger.error(f"❌ Error starting SensorAgent: {e}")
            self._running = False
            if self._error_callback:
                self._error_callback("start_error", e)
            raise
    
    def stop(self) -> None:
        """
        Stop the sensor agent.
        """
        logger.info("🛑 Stopping SensorAgent...")
        self._running = False
        
        if self._client:
            self._client.disconnect()
            self._client.loop_stop()
        
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=5)
        
        logger.info("✅ SensorAgent stopped")
    
    def is_running(self) -> bool:
        """
        Check if the sensor agent is running.
        
        Returns:
            bool: True if running, False otherwise
        """
        return self._running
    
    async def get_stats(self) -> dict:
        """
        Get statistics about the sensor agent.
        
        Returns:
            dict: Statistics including state count, running status, etc.
        """
        state_count = len(self.context_store)
        
        return {
            "running": self._running,
            "broker_host": self.broker_host,
            "broker_port": self.broker_port,
            "topic_pattern": self.topic_pattern,
            "client_id": self.client_id,
            "state_count": state_count,
            "connected": self._client.is_connected() if self._client else False,
        }


# Utility functions for backwards compatibility
async def create_sensor_agent(
    broker_host: str = "localhost",
    broker_port: int = 1883,
    topic_pattern: str = "home/+/+/state",
    context_store: Optional[ContextStore] = None
) -> SensorAgent:
    """
    Create and return a configured SensorAgent instance.
    
    Args:
        broker_host (str): MQTT broker hostname
        broker_port (int): MQTT broker port
        topic_pattern (str): MQTT topic pattern to subscribe to
        context_store (Optional[ContextStore]): ContextStore instance to use
    
    Returns:
        SensorAgent: Configured sensor agent instance
    """
    return SensorAgent(
        broker_host=broker_host,
        broker_port=broker_port,
        topic_pattern=topic_pattern,
        context_store=context_store
    )


if __name__ == "__main__":
    # Example usage
    async def main():
        # Create context store
        context = ContextStore()
        
        # Create and start sensor agent
        agent = SensorAgent(
            broker_host="localhost",
            broker_port=1883,
            topic_pattern="home/+/+/state",
            context_store=context
        )
        
        # Set up callbacks
        def on_message(topic: str, data: dict):
            print(f"Received: {topic} -> {data}")
        
        def on_error(error_type: str, error: Exception):
            print(f"Error ({error_type}): {error}")
        
        agent.set_message_callback(on_message)
        agent.set_error_callback(on_error)
        
        try:
            await agent.start()
        except KeyboardInterrupt:
            print("Stopping agent...")
            agent.stop()
    
    asyncio.run(main())